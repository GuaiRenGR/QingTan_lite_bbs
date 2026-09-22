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
        $endpoint = substr($base, -11) === '/completions' ? $base : $base . '/completions';
        $key = trim((string)\SiteSetting::get('ai_review_api_key', ''));
        $model = trim((string)\SiteSetting::get('ai_review_model', '')) ?: 'gpt-4o-mini';
        $prompt = "审核下面的帖子，只返回JSON对象，不要Markdown：{\"approved\":true或false,\"reason\":\"不超过100字\"}。标题：" .
            mb_substr((string)$title, 0, 200) . "\n正文：" . mb_substr(strip_tags((string)$content), 0, 6000);

        $payload = json_encode([
            'model' => $model,
            'temperature' => 0,
            'max_tokens' => 160,
            'enable_thinking' => false,
            'response_format' => ['type' => 'json_object'],
            'messages' => [
                ['role' => 'system', 'content' => '你是内容审核器。仅输出合法JSON。'],
                ['role' => 'user', 'content' => $prompt],
            ],
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

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
        $text = $response['choices'][0]['message']['content'] ?? '';
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
}
