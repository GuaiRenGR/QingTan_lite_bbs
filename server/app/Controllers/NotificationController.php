<?php

namespace App\Controllers;

class NotificationController
{
    public static function list()
    {
        $user = \Auth::requireLogin();
        $type = \Request::str('type');
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(max(1, \Request::int('page_size', 20)), 50);
        $offset = ($page - 1) * $pageSize;

        $notifications = \Database::table('notifications');
        $reads = \Database::table('notification_reads');
        $users = \Database::table('users');

        $where = "(n.user_id = ? OR (n.user_id = 0 AND n.type = 'system'))";
        $params = [(int)$user['id'], (int)$user['id']];

        if ($type) {
            $where .= " AND n.type = ?";
            $params[] = $type;
        }

        $sql = "
            SELECT n.*,
                   CASE WHEN n.user_id = 0 THEN COALESCE(r.is_read, 0) ELSE n.is_read END AS is_read
            FROM {$notifications} n
            LEFT JOIN {$reads} r ON r.notification_id = n.id AND r.user_id = ?
            WHERE {$where}
            ORDER BY n.created_at DESC
            LIMIT {$offset}, {$pageSize}
        ";

        $rows = \Database::fetchAll($sql, $params);

        // 解析 data JSON 并补充触发者信息
        foreach ($rows as &$row) {
            $data = json_decode($row['data'] ?? '{}', true);
            $row['data'] = $data ?: [];

            if (!empty($data['from_user_id'])) {
                $fromUser = \Database::fetch(
                    "SELECT id, nickname, avatar FROM {$users} WHERE id = ? LIMIT 1",
                    [(int)$data['from_user_id']]
                );
                $row['from_user'] = $fromUser ?: null;
            }
        }

        \Response::success([
            'list' => $rows,
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($rows) >= $pageSize,
        ]);
    }

    public static function unreadCount()
    {
        $user = \Auth::requireLogin();
        $notifications = \Database::table('notifications');
        $settings = \Database::table('notification_settings');
        $reads = \Database::table('notification_reads');

        $types = ['reply', 'mention', 'like', 'system'];
        $counts = [];

        foreach ($types as $t) {
            // 检查免打扰
            $dnd = \Database::fetch(
                "SELECT dnd FROM {$settings} WHERE user_id = ? AND type = ? LIMIT 1",
                [(int)$user['id'], $t]
            );

            if ($dnd && (int)$dnd['dnd'] === 1) {
                $counts[$t] = 0;
                continue;
            }

            if ($t === 'system') {
                $row = \Database::fetch(
                    "SELECT COUNT(*) AS cnt FROM {$notifications} n
                     LEFT JOIN {$reads} r ON r.notification_id = n.id AND r.user_id = ?
                     WHERE (n.user_id = ? OR n.user_id = 0) AND n.type = ?
                       AND CASE WHEN n.user_id = 0 THEN COALESCE(r.is_read, 0) ELSE n.is_read END = 0",
                    [(int)$user['id'], (int)$user['id'], $t]
                );
            } else {
                $row = \Database::fetch(
                    "SELECT COUNT(*) AS cnt FROM {$notifications}
                     WHERE user_id = ? AND type = ? AND is_read = 0",
                    [(int)$user['id'], $t]
                );
            }

            $counts[$t] = (int)($row['cnt'] ?? 0);
        }

        $counts['total'] = array_sum($counts);

        \Response::success($counts);
    }

    public static function markRead()
    {
        $user = \Auth::requireLogin();
        $id = \Request::int('id');
        $type = \Request::str('type');
        $all = \Request::int('all');

        $notifications = \Database::table('notifications');
        $reads = \Database::table('notification_reads');

        if ($id > 0) {
            $item = \Database::fetch("SELECT user_id FROM {$notifications} WHERE id = ? LIMIT 1", [$id]);
            if ($item && (int)$item['user_id'] === 0) {
                \Database::execute(
                    "INSERT INTO {$reads} (`notification_id`, `user_id`, `is_read`, `read_at`) VALUES (?, ?, 1, ?)
                     ON DUPLICATE KEY UPDATE is_read = 1, read_at = VALUES(read_at)",
                    [$id, (int)$user['id'], now()]
                );
            } else {
                \Database::execute(
                    "UPDATE {$notifications} SET is_read = 1 WHERE id = ? AND user_id = ?",
                    [$id, (int)$user['id']]
                );
            }
            record_sync_operation('notifications', $id, 'update');
        } elseif ($type) {
            \Database::execute(
                "UPDATE {$notifications} SET is_read = 1 WHERE user_id = ? AND type = ? AND is_read = 0",
                [(int)$user['id'], $type]
            );
            if ($type === 'system') {
                \Database::execute(
                    "INSERT INTO {$reads} (`notification_id`, `user_id`, `is_read`, `read_at`)
                     SELECT id, ?, 1, ? FROM {$notifications} WHERE user_id = 0 AND type = ?
                     ON DUPLICATE KEY UPDATE is_read = 1, read_at = VALUES(read_at)",
                    [(int)$user['id'], now(), $type]
                );
            }
            record_sync_operation('notifications', 0, 'update');
        } elseif ($all) {
            \Database::execute(
                "UPDATE {$notifications} SET is_read = 1 WHERE user_id = ? AND is_read = 0",
                [(int)$user['id']]
            );
            \Database::execute(
                "INSERT INTO {$reads} (`notification_id`, `user_id`, `is_read`, `read_at`)
                 SELECT id, ?, 1, ? FROM {$notifications} WHERE user_id = 0 AND type = 'system'
                 ON DUPLICATE KEY UPDATE is_read = 1, read_at = VALUES(read_at)",
                [(int)$user['id'], now()]
            );
            record_sync_operation('notifications', 0, 'update');
        }

        \Response::success(null, '已标记已读');
    }

    public static function getDnd()
    {
        $user = \Auth::requireLogin();
        $settings = \Database::table('notification_settings');

        $rows = \Database::fetchAll(
            "SELECT type, dnd FROM {$settings} WHERE user_id = ?",
            [(int)$user['id']]
        );

        $result = [];
        foreach (['reply', 'mention', 'like', 'system'] as $t) {
            $result[$t] = 0;
        }
        foreach ($rows as $row) {
            $result[$row['type']] = (int)$row['dnd'];
        }

        \Response::success($result);
    }

    public static function setDnd()
    {
        $user = \Auth::requireLogin();
        $type = \Request::str('type');
        $dnd = \Request::int('dnd');

        if (!in_array($type, ['reply', 'mention', 'like', 'system'])) {
            \Response::json(422, '无效的通知类型');
        }

        $settings = \Database::table('notification_settings');

        \Database::execute(
            "INSERT INTO {$settings} (`user_id`, `type`, `dnd`)
             VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE `dnd` = VALUES(`dnd`)",
            [(int)$user['id'], $type, $dnd ? 1 : 0]
        );
        record_sync_operation('notification_settings', 0, 'update');

        \Response::success(null, $dnd ? '已开启免打扰' : '已关闭免打扰');
    }

    // 创建通知的静态方法，供其他控制器调用
    public static function create($userId, $type, $title, $content = '', $data = [])
    {
        if ((int)$userId <= 0) return;

        // 检查免打扰
        $settings = \Database::table('notification_settings');
        $dnd = \Database::fetch(
            "SELECT dnd FROM {$settings} WHERE user_id = ? AND type = ? LIMIT 1",
            [(int)$userId, $type]
        );

        if ($dnd && (int)$dnd['dnd'] === 1) return;

        $notifications = \Database::table('notifications');

        \Database::execute(
            "INSERT INTO {$notifications}
            (`user_id`, `type`, `title`, `content`, `data`, `is_read`, `created_at`)
             VALUES (?, ?, ?, ?, ?, 0, ?)",
            [
                (int)$userId,
                $type,
                $title,
                $content,
                json_encode($data, JSON_UNESCAPED_UNICODE),
                now(),
            ]
        );
        $notifId = (int)\Database::lastInsertId();
        record_sync_operation('notifications', $notifId, 'insert');
    }
}
