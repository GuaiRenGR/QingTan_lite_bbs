<?php

namespace App\Controllers;

class MessageController
{
    public static function conversations()
    {
        $user = \Auth::requireLogin();
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(max(1, \Request::int('page_size', 20)), 50);
        $offset = ($page - 1) * $pageSize;
        $userId = (int)$user['id'];

        $conv = \Database::table('conversations');
        $users = \Database::table('users');

        $sql = "
            SELECT c.*,
                   CASE WHEN c.user_a_id = ? THEN c.user_b_id ELSE c.user_a_id END AS other_user_id
            FROM {$conv} c
            WHERE c.user_a_id = ? OR c.user_b_id = ?
            ORDER BY c.last_message_at DESC
            LIMIT {$offset}, {$pageSize}
        ";

        $rows = \Database::fetchAll($sql, [$userId, $userId, $userId]);

        $result = [];
        foreach ($rows as $row) {
            $otherUserId = (int)$row['other_user_id'];
            $otherUser = \Database::fetch(
                "SELECT id, nickname, avatar FROM {$users} WHERE id = ? LIMIT 1",
                [$otherUserId]
            );

            // 未读消息数
            $messages = \Database::table('messages');
            $unread = \Database::fetch(
                "SELECT COUNT(*) AS cnt FROM {$messages}
                 WHERE conversation_id = ? AND sender_id != ? AND is_read = 0",
                [(int)$row['id'], $userId]
            );

            $result[] = [
                'id' => (int)$row['id'],
                'other_user' => $otherUser ?: [
                    'id' => $otherUserId,
                    'nickname' => '用户',
                    'avatar' => '',
                ],
                'last_message' => $row['last_message_preview'] ?? '',
                'last_message_at' => $row['last_message_at'] ?? '',
                'unread_count' => (int)($unread['cnt'] ?? 0),
            ];
        }

        \Response::success([
            'list' => $result,
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($rows) >= $pageSize,
        ]);
    }

    public static function messages()
    {
        $user = \Auth::requireLogin();
        $conversationId = \Request::int('conversation_id');
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(max(1, \Request::int('page_size', 30)), 100);
        $offset = ($page - 1) * $pageSize;

        if ($conversationId <= 0) {
            \Response::json(422, '会话 ID 错误');
        }

        // 验证当前用户是否属于该会话
        $conv = \Database::table('conversations');
        $conversation = \Database::fetch(
            "SELECT * FROM {$conv} WHERE id = ? AND (user_a_id = ? OR user_b_id = ?) LIMIT 1",
            [$conversationId, (int)$user['id'], (int)$user['id']]
        );

        if (!$conversation) {
            \Response::json(404, '会话不存在');
        }

        $messages = \Database::table('messages');
        $users = \Database::table('users');

        $sql = "
            SELECT m.*
            FROM {$messages} m
            WHERE m.conversation_id = ?
            ORDER BY m.created_at DESC
            LIMIT {$offset}, {$pageSize}
        ";

        $rows = \Database::fetchAll($sql, [$conversationId]);

        // 补充发送者信息
        foreach ($rows as &$row) {
            $sender = \Database::fetch(
                "SELECT id, nickname, avatar FROM {$users} WHERE id = ? LIMIT 1",
                [(int)$row['sender_id']]
            );
            $row['sender'] = $sender ?: null;
            $row['is_mine'] = (int)$row['sender_id'] === (int)$user['id'];
        }

        \Response::success([
            'list' => $rows,
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($rows) >= $pageSize,
        ]);
    }

    public static function send()
    {
        $user = \Auth::requireLogin();
        $toUserId = \Request::int('to_user_id');
        $content = \Request::str('content');

        if ($toUserId <= 0) {
            \Response::json(422, '接收用户 ID 错误');
        }

        if ($toUserId === (int)$user['id']) {
            \Response::json(422, '不能给自己发私信');
        }

        if ($content === '') {
            \Response::json(422, '请输入消息内容');
        }

        if (mb_strlen($content) > 2000) {
            \Response::json(422, '消息内容过长');
        }

        // 验证目标用户存在
        $users = \Database::table('users');
        $toUser = \Database::fetch(
            "SELECT id, nickname FROM {$users} WHERE id = ? AND status = 1 LIMIT 1",
            [$toUserId]
        );

        if (!$toUser) {
            \Response::json(404, '用户不存在');
        }

        $conv = \Database::table('conversations');
        $messages = \Database::table('messages');
        $userId = (int)$user['id'];

        // 规范化：确保 user_a_id < user_b_id
        $aId = min($userId, $toUserId);
        $bId = max($userId, $toUserId);

        \Database::begin();

        try {
            // 查找或创建会话
            $conversation = \Database::fetch(
                "SELECT id FROM {$conv} WHERE user_a_id = ? AND user_b_id = ? LIMIT 1",
                [$aId, $bId]
            );

            if ($conversation) {
                $conversationId = (int)$conversation['id'];
            } else {
                \Database::execute(
                    "INSERT INTO {$conv}
                    (`user_a_id`, `user_b_id`, `last_message_at`, `last_message_preview`, `created_at`)
                     VALUES (?, ?, ?, ?, ?)",
                    [$aId, $bId, now(), mb_substr($content, 0, 100), now()]
                );
                $conversationId = (int)\Database::lastInsertId();
                record_sync_operation('conversations', $conversationId, 'insert');
            }

            // 插入消息
            \Database::execute(
                "INSERT INTO {$messages}
                (`conversation_id`, `sender_id`, `content`, `is_read`, `created_at`)
                 VALUES (?, ?, ?, 0, ?)",
                [$conversationId, $userId, $content, now()]
            );

            $messageId = (int)\Database::lastInsertId();
            $newMsg = \Database::fetch("SELECT * FROM {$messages} WHERE id = ?", [$messageId]);
            record_sync_operation('messages', $messageId, 'insert', $newMsg);

            // 更新会话
            \Database::execute(
                "UPDATE {$conv}
                 SET `last_message_at` = ?, `last_message_preview` = ?
                 WHERE id = ?",
                [now(), mb_substr($content, 0, 100), $conversationId]
            );
            record_sync_operation('conversations', $conversationId, 'update');

            \Database::commit();

            \Response::success([
                'id' => $messageId,
                'conversation_id' => $conversationId,
                'content' => $content,
                'created_at' => now(),
            ], '发送成功');

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, '发送失败');
        }
    }

    public static function unreadCount()
    {
        $user = \Auth::requireLogin();
        $userId = (int)$user['id'];

        $conv = \Database::table('conversations');
        $messages = \Database::table('messages');

        $sql = "
            SELECT COUNT(*) AS cnt
            FROM {$messages} m
            INNER JOIN {$conv} c ON c.id = m.conversation_id
            WHERE (c.user_a_id = ? OR c.user_b_id = ?)
              AND m.sender_id != ?
              AND m.is_read = 0
        ";

        $row = \Database::fetch($sql, [$userId, $userId, $userId]);

        \Response::success([
            'unread_count' => (int)($row['cnt'] ?? 0),
        ]);
    }

    public static function markRead()
    {
        $user = \Auth::requireLogin();
        $conversationId = \Request::int('conversation_id');

        if ($conversationId <= 0) {
            \Response::json(422, '会话 ID 错误');
        }

        $messages = \Database::table('messages');

        \Database::execute(
            "UPDATE {$messages} SET is_read = 1
             WHERE conversation_id = ? AND sender_id != ? AND is_read = 0",
            [$conversationId, (int)$user['id']]
        );
        record_sync_operation('messages', 0, 'update');

        \Response::success(null, '已标记已读');
    }
}
