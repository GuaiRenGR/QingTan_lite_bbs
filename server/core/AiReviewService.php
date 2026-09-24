<?php

class AiReviewService
{
    public static function enabled()
    {
        return \SiteSetting::get('ai_review_enabled', '0') === '1'
            && trim((string)\SiteSetting::get('ai_review_base_url', '')) !== ''
            && trim((string)\SiteSetting::get('ai_review_api_key', '')) !== '';
    }

    public static function review($title, $content)
    {
        $base = rtrim(trim((string)\SiteSetting::get('ai_review_base_url', '')), '/');
        $apiType = trim((string)\SiteSetting::get('ai_review_api_type', 'completions'));
        if (!in_array($apiType, ['completions', 'responses'], true)) {
            $apiType = 'completions';
        }
        $suffix = '/' . $apiType;
        $endpoint = substr($base, -strlen($suffix)) === $suffix ? $base : $base . $suffix;
        $key = trim((string)\SiteSetting::get('ai_review_api_key', ''));
        $model = trim((string)\SiteSetting::get('ai_review_model', '')) ?: 'gpt-4o-mini';
        $prompt = "请审核下面的帖子，并严格按照审核规则判断是否可以公开发布。\n"
            . "审核规则：\n"
            . "1. 不得包含色情、淫秽、露骨性描写、色情交易或引导未成年人接触色情的内容。\n"
            . "2. 不得包含违反中华人民共和国法律法规的内容，包括煽动违法犯罪、传授犯罪方法、诈骗、赌博、毒品、暴力恐怖、极端主义、侵犯他人隐私或人身安全等。\n"
            . "3. 不得包含危害国家安全、破坏国家统一、煽动民族仇恨或歧视、侮辱诽谤他人、恶意造谣以及明显违法的政治或社会内容。\n"
            . "4. 不得包含针对未成年人的性剥削、诱导、伤害或其他危险内容。\n"
            . "5. 不得包含恶意广告、钓鱼链接、木马病毒、批量引流、垃圾信息或明显欺诈内容。\n"
            . "6. 对正常的新闻、法律咨询、历史讨论、文学创作、医学或安全教育等内容，不因提及敏感词就直接判定违规；只有内容本身构成违法、有害或明确违反上述规则时才拒绝。\n"
            . "7. 帖子正文可能包含BBCode标记（如[b]、[quote]、[url]、[img]等）、链接和图片标签。忽略BBCode语法本身，不要因为出现图片或链接标记就判定违规；重点审核用户可见的文字内容。链接或图片地址本身通常无需审核，只有当正文明确利用它们实施诈骗、传播恶意程序或其他违法行为时才判定违规。\n"
            . "输出要求：只返回一个合法JSON对象，不要Markdown、解释或额外文字，格式必须为："
            . "{\"approved\":true或false,\"reason\":\"不超过100字的简短原因\"}。"
            . "approved为true表示允许公开，false表示拒绝公开。\n"
            . "标题：" . mb_substr((string)$title, 0, 200)
            . "\n正文：" . mb_substr(strip_tags((string)$content), 0, 6000);

        if ($apiType === 'responses') {
            $payload = json_encode([
                'model' => $model,
                'max_output_tokens' => 160,
                'input' => [
                    ['role' => 'system', 'content' => [['type' => 'input_text', 'text' => '你是一个谨慎、客观的中文社区内容审核器。严格执行用户给出的审核规则，只输出合法JSON。']]],
                    ['role' => 'user', 'content' => [['type' => 'input_text', 'text' => $prompt]]],
                ],
                'text' => ['format' => ['type' => 'json_object']],
            ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        } else {
            $payload = json_encode([
                'model' => $model,
                'temperature' => 0,
                'max_tokens' => 160,
                'enable_thinking' => false,
                'response_format' => ['type' => 'json_object'],
                'messages' => [
                    ['role' => 'system', 'content' => '你是一个谨慎、客观的中文社区内容审核器。严格执行用户给出的审核规则，只输出合法JSON。'],
                    ['role' => 'user', 'content' => $prompt],
                ],
            ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }

        $ch = curl_init($endpoint);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 25,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Authorization: Bearer ' . $key],
            CURLOPT_POSTFIELDS => $payload,
        ]);
        $raw = curl_exec($ch);
        $error = curl_error($ch);
        $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($raw === false || $status < 200 || $status >= 300) {
            throw new \RuntimeException('AI审核请求失败' . ($error ? ': ' . $error : ''));
        }
        $response = json_decode($raw, true);
        $text = $apiType === 'responses'
            ? self::responseText($response)
            : ($response['choices'][0]['message']['content'] ?? '');
        $result = json_decode(trim((string)$text), true);
        if (!is_array($result)) {
            throw new \RuntimeException('AI审核返回格式错误');
        }
        $approved = filter_var($result['approved'] ?? $result['status'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $reason = trim((string)($result['reason'] ?? ''));
        if (mb_strlen($reason, 'UTF-8') > 100) {
            $reason = mb_substr($reason, 0, 100, 'UTF-8');
        }
        return ['approved' => $approved, 'reason' => $reason];
    }

    private static function responseText($response)
    {
        if (!is_array($response)) {
            return '';
        }
        if (isset($response['output_text']) && is_string($response['output_text'])) {
            return $response['output_text'];
        }
        $text = '';
        foreach (($response['output'] ?? []) as $item) {
            foreach (($item['content'] ?? []) as $content) {
                if (isset($content['text']) && is_string($content['text'])) {
                    $text .= $content['text'];
                }
            }
        }
        return $text;
    }
}
