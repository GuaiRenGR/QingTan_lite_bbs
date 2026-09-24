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

function request_origin()
{
    $forwardedProto = strtolower(trim(explode(',', $_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')[0]));
    $scheme = $forwardedProto === 'https'
        || (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        ? 'https'
        : 'http';
    $forwardedHost = trim(explode(',', $_SERVER['HTTP_X_FORWARDED_HOST'] ?? '')[0]);
    $host = $forwardedHost !== '' ? $forwardedHost : ($_SERVER['HTTP_HOST'] ?? 'localhost');

    return $scheme . '://' . $host;
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

function normalize_forum_media_url($url)
{
    $url = trim((string)$url);

    if (preg_match('#^/index\.php\?route=file/resolve&id=\d+$#', $url)) {
        return request_origin() . $url;
    }

    return validate_remote_url($url) ? $url : '';
}

function extract_img_tags($content)
{
    $content = (string)$content;

    preg_match_all('/\[img=((?:https?:\/\/|\/)[^\]\s]+)\]/i', $content, $matches);

    return array_values(array_filter(array_map('normalize_forum_media_url', $matches[1] ?? [])));
}

function sanitize_forum_content($content)
{
    $content = (string)$content;

    $content = strip_dangerous_html($content);

    $content = preg_replace_callback('/\[img=([^\]]+)\]/i', function ($m) {
        $url = normalize_forum_media_url($m[1]);

        if ($url === '') {
            return '';
        }

        return '[img=' . $url . ']';
    }, $content);

    $content = preg_replace_callback('/\[video=([^\]]+)\]/i', function ($m) {
        $url = normalize_forum_media_url($m[1]);

        if ($url === '') {
            return '';
        }

        return '[video=' . $url . ']';
    }, $content);

    $content = preg_replace_callback('/\[music=([^\]]+)\]/i', function ($m) {
        $values = preg_split('/[,|]/', $m[1], 2);
        $source = trim($values[0] ?? '');
        if (preg_match('/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i', $source)) {
            return '[music=' . strtolower($source) . ']';
        }
        $url = normalize_forum_media_url($source);

        if ($url === '') {
            return '';
        }

        $lyricsUrl = normalize_forum_media_url($values[1] ?? '');
        return $lyricsUrl === ''
            ? '[music=' . $url . ']'
            : '[music=' . $url . ',' . $lyricsUrl . ']';
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

if (!function_exists('load_server_config')) {
    function load_server_config()
    {
        static $config = null;
        if ($config === null) {
            $file = FX_ROOT . '/config/servers.php';
            if (!file_exists($file)) {
                return null;
            }
            $config = require $file;
        }
        return $config;
    }
}

if (!function_exists('record_sync_operation')) {
    function record_sync_operation($tableName, $rowId, $opType, $rowData = null, $oldData = null)
    {
        $config = load_server_config();
        if (!$config) {
            return;
        }

        $logTable = Database::table('sync_operation_log');
        if ($rowData === null && $opType !== 'delete' && (int)$rowId > 0) {
            $safeTable = Database::table($tableName);
            try {
                $rowData = Database::fetch("SELECT * FROM {$safeTable} WHERE id = ? LIMIT 1", [(int)$rowId]);
            } catch (Throwable $e) {
                log_error('[SyncSnapshot] ' . $e->getMessage());
            }
        }
        if ($opType === 'delete' && $rowData === null && is_array($oldData)) {
            $rowData = $oldData;
        }
        // Bulk operations without a row snapshot cannot be replayed safely.
        if ((int)$rowId <= 0 && $rowData === null) {
            return;
        }

        Database::execute(
            "INSERT INTO {$logTable}
             (`server_id`, `src_op_id`, `op_type`, `table_name`, `row_id`, `row_data`, `old_data`, `created_at`)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $config['server_id'],
                0,
                $opType,
                $tableName,
                (int)$rowId,
                $rowData ? json_encode($rowData, JSON_UNESCAPED_UNICODE) : null,
                $oldData ? json_encode($oldData, JSON_UNESCAPED_UNICODE) : null,
                now(),
            ]
        );

        $logId = (int)Database::lastInsertId();

        Database::execute(
            "UPDATE {$logTable} SET src_op_id = ? WHERE id = ?",
            [$logId, $logId]
        );
    }
}

if (!function_exists('apply_sync_operation')) {
    function apply_sync_operation($op)
    {
        $table = Database::table($op['table_name']);
        $rowData = json_decode($op['row_data'] ?? '', true);

        try {
            switch ($op['op_type']) {
                case 'insert':
                    if (!$rowData) return false;
                    $columns = array_keys($rowData);
                    $placeholders = array_fill(0, count($columns), '?');
                    $sql = "INSERT IGNORE INTO {$table} (`"
                         . implode('`,`', $columns)
                         . "`) VALUES (" . implode(',', $placeholders) . ")";
                    Database::execute($sql, array_values($rowData));
                    return true;

                case 'update':
                    if (!$rowData) return false;
                    $sets = [];
                    $params = [];
                    foreach ($rowData as $col => $val) {
                        if ($col === 'id') continue;
                        $sets[] = "`{$col}` = ?";
                        $params[] = $val;
                    }
                    $params[] = $op['row_id'];
                    $sql = "UPDATE IGNORE {$table} SET " . implode(', ', $sets)
                         . " WHERE id = ?";
                    Database::execute($sql, $params);
                    return true;

                case 'delete':
                    Database::execute(
                        "DELETE FROM {$table} WHERE id = ?",
                        [$op['row_id']]
                    );
                    return true;
            }
        } catch (\Throwable $e) {
            log_error('[SyncApply] ' . $e->getMessage()
                . ' | table=' . $op['table_name']
                . ' | op=' . $op['op_type']
                . ' | row_id=' . $op['row_id']);
        }
        return false;
    }
}

if (!function_exists('sync_get_unsynced_ops')) {
    function sync_get_unsynced_ops($limit = 100, $peerServerId = null)
    {
        $config = load_server_config();
        if (!$config) return [];

        $logTable = Database::table('sync_operation_log');

        $limit = (int)$limit;
        $delivery = Database::table('sync_operation_delivery');
        if ($peerServerId !== null) {
            try {
                return Database::fetchAll(
                    "SELECT l.id, l.server_id, l.src_op_id, l.op_type, l.table_name, l.row_id, l.row_data, l.created_at
                     FROM {$logTable} l
                     LEFT JOIN {$delivery} d ON d.operation_id = l.id AND d.peer_server_id = ?
                     WHERE d.operation_id IS NULL
                     ORDER BY l.id ASC LIMIT {$limit}",
                    [(int)$peerServerId]
                );
            } catch (Throwable $e) {
                // Older installations can continue syncing until migration.
            }
        }
        return Database::fetchAll(
            "SELECT id, server_id, src_op_id, op_type, table_name, row_id, row_data, created_at
             FROM {$logTable} WHERE synced_at IS NULL ORDER BY id ASC LIMIT {$limit}"
        );
    }
}

if (!function_exists('sync_mark_synced')) {
    function sync_mark_synced(array $ids)
    {
        if (empty($ids)) return;

        $logTable = Database::table('sync_operation_log');
        $placeholders = implode(',', array_fill(0, count($ids), '?'));

        Database::execute(
            "UPDATE {$logTable} SET synced_at = ? WHERE id IN ({$placeholders})",
            array_merge([now()], $ids)
        );
    }

    if (!function_exists('sync_mark_delivered')) {
        function sync_mark_delivered($peerServerId, array $ids)
        {
            if (empty($ids)) return;
            $delivery = Database::table('sync_operation_delivery');
            try {
                foreach ($ids as $id) {
                    Database::execute(
                        "INSERT IGNORE INTO {$delivery} (operation_id, peer_server_id, delivered_at) VALUES (?, ?, ?)",
                        [(int)$id, (int)$peerServerId, now()]
                    );
                }
            } catch (Throwable $e) {
                return;
            }
            $config = load_server_config();
            $required = max(0, count($config['servers'] ?? []) - 1);
            if ($required > 0) {
                $logTable = Database::table('sync_operation_log');
                foreach ($ids as $id) {
                    $count = Database::fetch(
                        "SELECT COUNT(*) AS c FROM {$delivery} WHERE operation_id = ?",
                        [(int)$id]
                    );
                    if ((int)($count['c'] ?? 0) >= $required) {
                        Database::execute("UPDATE {$logTable} SET synced_at = ? WHERE id = ?", [now(), (int)$id]);
                    }
                }
            }
        }
    }
}

if (!function_exists('sync_receive_ops')) {
    function sync_receive_ops($sourceServerId, array $operations)
    {
        $logTable = Database::table('sync_operation_log');

        $applied = 0;
        $skipped = 0;
        $failed = 0;

        foreach ($operations as $op) {
            $exists = Database::fetch(
                "SELECT id, synced_at FROM {$logTable} WHERE server_id = ? AND src_op_id = ? LIMIT 1",
                [$op['server_id'], $op['src_op_id']]
            );

            if ($exists) {
                if (!empty($exists['synced_at'])) {
                    $skipped++;
                    continue;
                }
                $ok = apply_sync_operation($op);
                if ($ok) Database::execute("UPDATE {$logTable} SET synced_at = ? WHERE id = ?", [now(), $exists['id']]);
                if ($ok) $applied++;
                if (!$ok) $failed++;
                continue;
            }

            Database::execute(
                "INSERT INTO {$logTable}
                 (`server_id`, `src_op_id`, `op_type`, `table_name`, `row_id`, `row_data`, `created_at`, `synced_at`)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    $op['server_id'],
                    $op['src_op_id'],
                    $op['op_type'],
                    $op['table_name'],
                    $op['row_id'],
                    $op['row_data'],
                    $op['created_at'],
                    null,
                ]
            );

            if (apply_sync_operation($op)) {
                Database::execute("UPDATE {$logTable} SET synced_at = ? WHERE server_id = ? AND src_op_id = ?", [now(), $op['server_id'], $op['src_op_id']]);
                $applied++;
            } else {
                $failed++;
            }
        }

        return ['applied' => $applied, 'skipped' => $skipped, 'failed' => $failed];
    }
}

if (!function_exists('sync_push_to_peer')) {
    function sync_push_to_peer($peerUrl, $syncToken)
    {
        $config = load_server_config();
        if (!$config) return ['pushed' => 0, 'success' => false];

        $peerId = 0;
        foreach (($config['servers'] ?? []) as $peer) {
            if (rtrim((string)($peer['url'] ?? ''), '/') === rtrim((string)$peerUrl, '/')) {
                $peerId = (int)($peer['id'] ?? 0);
                break;
            }
        }
        $operations = sync_get_unsynced_ops($config['sync']['batch_size'], $peerId > 0 ? $peerId : null);
        if (empty($operations)) {
            return ['pushed' => 0, 'success' => true];
        }

        $payload = json_encode([
            'source_server_id' => $config['server_id'],
            'operations' => $operations,
        ]);

        $ch = curl_init(rtrim($peerUrl, '/') . '/index.php?route=sync/receive');
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $payload,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Sync-Token: ' . $syncToken,
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => $config['sync']['timeout'],
            CURLOPT_CONNECTTIMEOUT => 10,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        $body = json_decode((string)$response, true);
        if ($httpCode >= 200 && $httpCode < 300 && is_array($body) && (int)($body['code'] ?? 1) === 0) {
            $opIds = array_column($operations, 'id');
            if ($peerId > 0) sync_mark_delivered($peerId, $opIds);
            return ['pushed' => count($operations), 'success' => true];
        }

        log_error('[SyncPush] HTTP=' . $httpCode . ' | error=' . $error . ' | peer=' . $peerUrl);
        return ['pushed' => 0, 'success' => false];
    }
}

if (!function_exists('sync_pull_from_peer')) {
    function sync_pull_from_peer($peerUrl, $syncToken, $lastSyncOpId = 0)
    {
        $config = load_server_config();
        if (!$config) return ['pulled' => 0, 'success' => false];

        $ch = curl_init(rtrim($peerUrl, '/') . '/index.php?route=sync/pull');
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query([
                'server_id' => $config['server_id'],
                'after_id'  => $lastSyncOpId,
            ]),
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/x-www-form-urlencoded',
                'Sync-Token: ' . $syncToken,
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => $config['sync']['timeout'],
            CURLOPT_CONNECTTIMEOUT => 10,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        $body = json_decode((string)$response, true);
        if ($httpCode < 200 || $httpCode >= 300 || !is_array($body) || (int)($body['code'] ?? 1) !== 0) {
            log_error('[SyncPull] HTTP=' . $httpCode . ' | error=' . $error . ' | peer=' . $peerUrl);
            return ['pulled' => 0, 'success' => false];
        }

        $data = $body;
        $operations = $data['data']['operations'] ?? [];

        if (empty($operations)) {
            return [
                'pulled' => 0,
                'success' => true,
                'max_id' => (int)($data['data']['max_id'] ?? 0),
            ];
        }

        $result = sync_receive_ops($config['server_id'], $operations);

        return [
            'pulled'  => $result['applied'],
            'skipped' => $result['skipped'],
            'success' => true,
            'max_id' => (int)($data['data']['max_id'] ?? 0),
        ];
    }
}

if (!function_exists('sync_run_all')) {
    function sync_run_all()
    {
        $config = load_server_config();
        if (!$config) return ['error' => 'servers.php not found'];

        $results = [];
        $syncToken = $config['sync']['sync_token'] ?? '';

        foreach ($config['servers'] as $peer) {
            if ($peer['id'] === $config['server_id']) {
                continue;
            }

            $peerUrl = $peer['url'];

            $pushResult = sync_push_to_peer($peerUrl, $syncToken);

            $statusTable = Database::table('sync_server_status');
            $row = Database::fetch(
                "SELECT last_sync_op_id FROM {$statusTable} WHERE server_id = ? LIMIT 1",
                [$peer['id']]
            );
            $lastSyncId = $row ? (int)$row['last_sync_op_id'] : 0;

            $pullResult = sync_pull_from_peer($peerUrl, $syncToken, $lastSyncId);

            if (($pullResult['max_id'] ?? 0) > $lastSyncId) {
                Database::execute(
                    "UPDATE {$statusTable} SET last_sync_op_id = ?, last_sync_at = ?, status = 'active', updated_at = ? WHERE server_id = ?",
                    [(int)$pullResult['max_id'], now(), now(), (int)$peer['id']]
                );
            }

            Database::execute(
                "INSERT INTO {$statusTable}
                 (`server_id`, `server_url`, `server_name`, `last_sync_at`, `last_sync_op_id`, `status`, `created_at`, `updated_at`)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                 ON DUPLICATE KEY UPDATE
                   `server_url` = VALUES(`server_url`),
                   `server_name` = VALUES(`server_name`),
                   `last_sync_at` = VALUES(`last_sync_at`),
                   `status` = VALUES(`status`),
                   `updated_at` = VALUES(`updated_at`)",
                [$peer['id'], $peerUrl, $peer['name'], now(), (int)($pullResult['max_id'] ?? $lastSyncId), ($pushResult['success'] && $pullResult['success']) ? 'active' : 'offline', now(), now()]
            );

            $results[$peer['id']] = [
                'push' => $pushResult,
                'pull' => $pullResult,
            ];
        }

        return $results;
    }
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

        $thumbUrl = '/index.php?route=file/resolve&id=' . $attachmentId;

        return [
            'attachment_id' => $attachmentId,
            'url' => $thumbUrl,
            'width' => $newW,
            'height' => $newH,
        ];
    }
}

if (!function_exists('get_image_dimensions')) {
    function get_image_dimensions($imageUrl)
    {
        $imageUrl = trim((string)$imageUrl);
        if ($imageUrl === '') {
            return null;
        }

        $resolvedUrl = '';
        if (preg_match('#^/index\.php\?route=file/resolve&id=(\d+)$#', $imageUrl, $matches)) {
            $attachments = Database::table('attachments');
            $attachment = Database::fetch(
                "SELECT onedrive_item_id, file_url FROM {$attachments} WHERE id = ? AND status = 1 LIMIT 1",
                [(int)$matches[1]]
            );

            if ($attachment && !empty($attachment['onedrive_item_id'])) {
                try {
                    $service = new OneDriveService();
                    $resolvedUrl = $service->getFileUrl($attachment['onedrive_item_id']);
                } catch (\Throwable $e) {
                    log_error('[ImageDimensions] ' . $e->getMessage());
                }
            }

            if ($resolvedUrl === '' && $attachment) {
                $resolvedUrl = normalize_forum_media_url($attachment['file_url'] ?? '');
            }
        } else {
            $resolvedUrl = normalize_forum_media_url($imageUrl);
        }

        if ($resolvedUrl === '') {
            return null;
        }

        $imageData = false;
        if (function_exists('curl_init')) {
            $curl = curl_init($resolvedUrl);
            curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($curl, CURLOPT_FOLLOWLOCATION, true);
            curl_setopt($curl, CURLOPT_CONNECTTIMEOUT, 10);
            curl_setopt($curl, CURLOPT_TIMEOUT, 30);
            $imageData = curl_exec($curl);
            $statusCode = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
            curl_close($curl);
            if ($statusCode < 200 || $statusCode >= 300) {
                $imageData = false;
            }
        }

        if ($imageData === false) {
            $imageData = @file_get_contents($resolvedUrl);
        }
        if ($imageData === false) {
            return null;
        }

        $size = @getimagesizefromstring($imageData);
        if (!$size || (int)$size[0] <= 0 || (int)$size[1] <= 0) {
            return null;
        }

        return [
            'width' => (int)$size[0],
            'height' => (int)$size[1],
        ];
    }
}
