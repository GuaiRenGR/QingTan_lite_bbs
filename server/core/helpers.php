<?php

function now()
{
    return date('Y-m-d H:i:s');
}

function today()
{
    return date('Y-m-d');
}

function client_ip()
{
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ip = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0];
        return trim($ip);
    }

    return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
}

function safe_text($str)
{
    return htmlspecialchars((string)$str, ENT_QUOTES, 'UTF-8');
}

function strip_dangerous_html($html)
{
    $html = (string)$html;

    $html = preg_replace('/<script\b[^>]*>(.*?)<\/script>/is', '', $html);
    $html = preg_replace('/<iframe\b[^>]*>(.*?)<\/iframe>/is', '', $html);
    $html = preg_replace('/on\w+="[^"]*"/i', '', $html);
    $html = preg_replace("/on\w+='[^']*'/i", '', $html);
    $html = preg_replace('/javascript:/i', '', $html);

    return $html;
}

function make_summary($content, $length = 120)
{
    $text = (string)$content;

    // 移除 BBCode 标签：[img=...] [video=...] [music=...] [url=...]...[/url] [hide]...[/hide]
    $text = preg_replace('/\[img=[^\]]*\]/i', '', $text);
    $text = preg_replace('/\[video=[^\]]*\]/i', '', $text);
    $text = preg_replace('/\[music=[^\]]*\]/i', '', $text);
    $text = preg_replace('/\[url=[^\]]*\][\s\S]*?\[\/url\]/i', '', $text);
    $text = preg_replace('/\[hide\][\s\S]*?\[\/hide\]/i', '', $text);
    $text = preg_replace('/\[\/?[a-zA-Z]+[^\]]*\]/', '', $text);

    $text = trim(strip_tags($text));

    if (function_exists('mb_substr')) {
        return mb_substr($text, 0, $length, 'UTF-8');
    }
    return substr($text, 0, $length);
}

function random_token($length = 32)
{
    if (function_exists('random_bytes')) {
        return bin2hex(random_bytes($length));
    }

    return bin2hex(openssl_random_pseudo_bytes($length));
}

function log_error($message)
{
    $dir = FX_ROOT . '/runtime/logs';

    if (!is_dir($dir)) {
        @mkdir($dir, 0755, true);
    }

    $file = $dir . '/error-' . date('Ymd') . '.log';

    @file_put_contents(
        $file,
        '[' . now() . '] ' . $message . "\n",
        FILE_APPEND
    );
}

function validate_remote_url($url)
{
    $url = trim((string)$url);

    if (!$url) {
        return false;
    }

    if (!filter_var($url, FILTER_VALIDATE_URL)) {
        return false;
    }

    $scheme = parse_url($url, PHP_URL_SCHEME);

    return in_array(strtolower($scheme), ['http', 'https'], true);
}

function extract_img_tags($content)
{
    $content = (string)$content;

    preg_match_all('/\[img=(https?:\/\/[^\]\s]+)\]/i', $content, $matches);

    return $matches[1] ?? [];
}

function sanitize_forum_content($content)
{
    $content = (string)$content;

    $content = strip_dangerous_html($content);

    $content = preg_replace_callback('/\[img=([^\]]+)\]/i', function ($m) {
        $url = trim($m[1]);

        if (!validate_remote_url($url)) {
            return '';
        }

        return '[img=' . $url . ']';
    }, $content);

    $content = preg_replace_callback('/\[video=([^\]]+)\]/i', function ($m) {
        $url = trim($m[1]);

        if (!validate_remote_url($url)) {
            return '';
        }

        return '[video=' . $url . ']';
    }, $content);

    $content = preg_replace_callback('/\[music=([^\]]+)\]/i', function ($m) {
        $url = trim($m[1]);

        if (!validate_remote_url($url)) {
            return '';
        }

        return '[music=' . $url . ']';
    }, $content);

    $content = preg_replace_callback('/\[url=([^\]]+)\]([\s\S]*?)\[\/url\]/i', function ($m) {
        $url = trim($m[1]);
        $text = trim($m[2]);

        if (!validate_remote_url($url)) {
            return $text;
        }

        if ($text === '') {
            $text = $url;
        }

        return '[url=' . $url . ']' . $text . '[/url]';
    }, $content);

    // 保留 hide 标签，但清理空内容
    $content = preg_replace_callback('/\[hide\]([\s\S]*?)\[\/hide\]/i', function ($m) {
        $text = trim($m[1]);

        if ($text === '') {
            return '';
        }

        return '[hide]' . $text . '[/hide]';
    }, $content);

    return trim($content);
}

if (!function_exists('today_date')) {
    function today_date()
    {
        return date('Y-m-d');
    }
}

if (!function_exists('add_content_daily_stat')) {
    function add_content_daily_stat($objectType, $objectId, $userId, $field, $delta = 1)
    {
        $allowed = [
            'view_count',
            'like_count',
            'favorite_count',
            'share_count',
            'reply_count',
        ];

        if (!in_array($field, $allowed, true)) {
            return;
        }

        $objectType = (string)$objectType;
        $objectId = (int)$objectId;
        $userId = (int)$userId;
        $delta = (int)$delta;

        if ($objectId <= 0 || $userId <= 0 || $delta === 0) {
            return;
        }

        $table = Database::table('content_stats_daily');
        $date = today_date();
        $now = now();

        Database::execute(
            "INSERT INTO {$table}
            (`object_type`, `object_id`, `user_id`, `stat_date`, `{$field}`, `created_at`, `updated_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              `{$field}` = `{$field}` + VALUES(`{$field}`),
              `updated_at` = VALUES(`updated_at`)",
            [
                $objectType,
                $objectId,
                $userId,
                $date,
                $delta,
                $now,
                $now,
            ]
        );
    }
}

if (!function_exists('record_thread_history')) {
    function record_thread_history($userId, $threadId)
    {
        $userId = (int)$userId;
        $threadId = (int)$threadId;

        if ($userId <= 0 || $threadId <= 0) {
            return;
        }

        $histories = Database::table('histories');

        Database::execute(
            "INSERT INTO {$histories}
            (`user_id`, `object_type`, `object_id`, `last_viewed_at`, `view_count`)
            VALUES (?, 'thread', ?, ?, 1)
            ON DUPLICATE KEY UPDATE
              `last_viewed_at` = VALUES(`last_viewed_at`),
              `view_count` = `view_count` + 1",
            [
                $userId,
                $threadId,
                now(),
            ]
        );
    }
}

function parse_json_array_input($value)
{
    if (is_array($value)) {
        return $value;
    }

    if (is_string($value) && $value !== '') {
        $json = json_decode($value, true);

        if (is_array($json)) {
            return $json;
        }
    }

    return [];
}

if (!function_exists('extract_forum_img_urls')) {
    function extract_forum_img_urls($content)
    {
        $content = (string)$content;

        preg_match_all('/\[img=(https?:\/\/[^\]\s]+)\]/i', $content, $matches);

        if (empty($matches[1])) {
            return [];
        }

        $urls = [];

        foreach ($matches[1] as $url) {
            $url = trim($url);

            if ($url !== '' && validate_remote_url($url)) {
                $urls[] = $url;
            }
        }

        return array_values(array_unique($urls));
    }
}

if (!function_exists('normalize_tag_name')) {
    function normalize_tag_name($name)
    {
        $name = trim((string)$name);
        $name = preg_replace('/\s+/u', '', $name);
        $name = mb_substr($name, 0, 20);

        return $name;
    }
}

if (!function_exists('sync_thread_tags')) {
    function sync_thread_tags($threadId, $tagNames)
    {
        $threadId = (int)$threadId;

        if ($threadId <= 0) {
            return [];
        }

        if (!is_array($tagNames)) {
            $tagNames = [];
        }

        $cleanNames = [];

        foreach ($tagNames as $name) {
            $name = normalize_tag_name($name);

            if ($name !== '') {
                $cleanNames[] = $name;
            }
        }

        $cleanNames = array_values(array_unique($cleanNames));
        $cleanNames = array_slice($cleanNames, 0, 5);

        $tags = Database::table('tags');
        $threadTags = Database::table('thread_tags');

        Database::execute(
            "DELETE FROM {$threadTags} WHERE thread_id = ?",
            [$threadId]
        );

        $result = [];

        foreach ($cleanNames as $name) {
            Database::execute(
                "INSERT INTO {$tags}
                (`name`, `use_count`, `created_at`)
                VALUES (?, 1, ?)
                ON DUPLICATE KEY UPDATE `use_count` = `use_count` + 1",
                [
                    $name,
                    now(),
                ]
            );

            $tag = Database::fetch(
                "SELECT id, name FROM {$tags} WHERE name = ? LIMIT 1",
                [$name]
            );

            if (!$tag) {
                continue;
            }

            Database::execute(
                "INSERT IGNORE INTO {$threadTags}
                (`thread_id`, `tag_id`, `created_at`)
                VALUES (?, ?, ?)",
                [
                    $threadId,
                    $tag['id'],
                    now(),
                ]
            );

            $result[] = [
                'id' => (int)$tag['id'],
                'name' => $tag['name'],
            ];
        }

        return $result;
    }
}

if (!function_exists('get_thread_tags')) {
    function get_thread_tags($threadId)
    {
        $threadId = (int)$threadId;

        if ($threadId <= 0) {
            return [];
        }

        $tags = Database::table('tags');
        $threadTags = Database::table('thread_tags');

        $rows = Database::fetchAll(
            "SELECT tg.id, tg.name
             FROM {$threadTags} tt
             INNER JOIN {$tags} tg ON tg.id = tt.tag_id
             WHERE tt.thread_id = ?
             ORDER BY tt.id ASC",
            [$threadId]
        );

        return array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'name' => $row['name'],
            ];
        }, $rows);
    }
}

if (!function_exists('generate_thumbnail')) {
    function generate_thumbnail($imageUrl, $userId, $targetWidth = 480)
    {
        $imageData = @file_get_contents($imageUrl);
        if ($imageData === false) {
            return null;
        }

        $src = @imagecreatefromstring($imageData);
        if (!$src) {
            return null;
        }

        $srcW = imagesx($src);
        $srcH = imagesy($src);

        if ($srcW <= 0 || $srcH <= 0) {
            imagedestroy($src);
            return null;
        }

        $ratio = $srcH / $srcW;
        $newW = $targetWidth;
        $newH = (int)round($targetWidth * $ratio);

        $dst = imagecreatetruecolor($newW, $newH);
        imagealphablending($dst, false);
        imagesavealpha($dst, true);
        imagecopyresampled($dst, $src, 0, 0, 0, 0, $newW, $newH, $srcW, $srcH);
        imagedestroy($src);

        $tmpFile = tempnam(sys_get_temp_dir(), 'thumb_');
        imagejpeg($dst, $tmpFile, 85);
        imagedestroy($dst);

        try {
            $service = new OneDriveService();
            $result = $service->upload($tmpFile, 'thumbnail.jpg', 'images', 'image/jpeg');
        } catch (\Throwable $e) {
            @unlink($tmpFile);
            log_error('缩略图上传失败: ' . $e->getMessage());
            return null;
        }

        $attachments = Database::table('attachments');

        Database::execute(
            "INSERT INTO {$attachments}
            (`user_id`,`object_type`,`object_id`,`file_name`,`file_path`,`file_url`,`file_type`,`file_size`,`onedrive_item_id`,`status`,`created_at`)
            VALUES (?,NULL,NULL,?,?,?,?,?,?,1,?)",
            [
                $userId,
                'thumbnail.jpg',
                $result['path'],
                '',
                'image/jpeg',
                filesize($tmpFile),
                $result['item_id'],
                now(),
            ]
        );

        $attachmentId = (int)Database::lastInsertId();

        @unlink($tmpFile);

        $baseUrl = 'https://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');
        $thumbUrl = $baseUrl . '/index.php?route=file/resolve&id=' . $attachmentId;

        return [
            'attachment_id' => $attachmentId,
            'url' => $thumbUrl,
        ];
    }
}
