<?php

namespace App\Controllers;

class GroupController
{
    private static function user()
    {
        return \Auth::requireLogin();
    }

    private static function tables()
    {
        return [
            'groups' => \Database::table('chat_groups'),
            'members' => \Database::table('chat_group_members'),
            'conversations' => \Database::table('conversations'),
            'messages' => \Database::table('messages'),
            'users' => \Database::table('users'),
        ];
    }

    public static function list()
    {
        $user = self::user();
        $t = self::tables();
        $rows = \Database::fetchAll(
            "SELECT g.id, g.group_no, g.name, g.owner_id, g.created_at,
                    c.id AS conversation_id, c.last_message_at, c.last_message_preview,
                    (SELECT COUNT(*) FROM {$t['members']} gm2 WHERE gm2.group_id = g.id) AS member_count,
                    (SELECT COUNT(*) FROM {$t['messages']} m WHERE m.conversation_id = c.id AND m.sender_id != ? AND m.is_read = 0) AS unread_count
             FROM {$t['groups']} g
             INNER JOIN {$t['members']} gm ON gm.group_id = g.id AND gm.user_id = ?
             INNER JOIN {$t['conversations']} c ON c.group_id = g.id
             ORDER BY c.last_message_at DESC, g.id DESC",
            [(int)$user['id'], (int)$user['id']]
        );
        foreach ($rows as &$row) {
            $row['id'] = (int)$row['id'];
            $row['conversation_id'] = (int)$row['conversation_id'];
            $row['member_count'] = (int)$row['member_count'];
            $row['unread_count'] = (int)$row['unread_count'];
            $row['is_group'] = true;
        }
        \Response::success(['list' => $rows]);
    }

    public static function create()
    {
        $user = self::user();
        if ((int)($user['group_id'] ?? 0) !== 99) {
            \Response::json(403, '仅管理员可以创建群聊', null, 403);
        }
        $name = trim(\Request::str('name'));
        if ($name === '' || mb_strlen($name) > 80) {
            \Response::json(422, '群名称不能为空且不能超过 80 个字符');
        }
        $t = self::tables();
        for ($attempt = 0; $attempt < 12; $attempt++) {
            $number = str_pad((string)random_int(10000000, 99999999), 8, '0', STR_PAD_LEFT);
            if (\Database::fetch("SELECT id FROM {$t['groups']} WHERE group_no = ? LIMIT 1", [$number])) continue;
            \Database::begin();
            try {
                \Database::execute("INSERT INTO {$t['groups']} (group_no, name, owner_id, created_at) VALUES (?, ?, ?, ?)", [$number, $name, (int)$user['id'], now()]);
                $groupId = (int)\Database::lastInsertId();
                \Database::execute("INSERT INTO {$t['conversations']} (user_a_id, user_b_id, group_id, last_message_at, last_message_preview, created_at) VALUES (0, 0, ?, NULL, NULL, ?)", [$groupId, now()]);
                $conversationId = (int)\Database::lastInsertId();
                \Database::execute("INSERT INTO {$t['members']} (group_id, user_id, role, joined_at) VALUES (?, ?, 'owner', ?)", [$groupId, (int)$user['id'], now()]);
                \Database::commit();
                \Response::success(['id' => $groupId, 'group_no' => $number, 'name' => $name, 'conversation_id' => $conversationId], '群聊创建成功');
            } catch (\Throwable $e) {
                \Database::rollback();
                throw $e;
            }
        }
        \Response::json(500, '群号生成失败，请重试', null, 500);
    }

    public static function join()
    {
        $user = self::user();
        $number = trim(\Request::str('group_no'));
        if (!preg_match('/^\d{8}$/', $number)) \Response::json(422, '群聊编号必须是 8 位数字');
        $t = self::tables();
        $group = \Database::fetch("SELECT g.*, c.id AS conversation_id FROM {$t['groups']} g INNER JOIN {$t['conversations']} c ON c.group_id = g.id WHERE g.group_no = ? LIMIT 1", [$number]);
        if (!$group) \Response::json(404, '群聊不存在');
        \Database::execute("INSERT IGNORE INTO {$t['members']} (group_id, user_id, role, joined_at) VALUES (?, ?, 'member', ?)", [(int)$group['id'], (int)$user['id'], now()]);
        \Response::success(['id' => (int)$group['id'], 'group_no' => $group['group_no'], 'name' => $group['name'], 'conversation_id' => (int)$group['conversation_id']], '已加入群聊');
    }

    private static function member($userId, $conversationId)
    {
        $t = self::tables();
        $conversation = \Database::fetch("SELECT * FROM {$t['conversations']} WHERE id = ? AND group_id IS NOT NULL LIMIT 1", [$conversationId]);
        if (!$conversation) return [null, null];
        $member = \Database::fetch("SELECT * FROM {$t['members']} WHERE group_id = ? AND user_id = ? LIMIT 1", [(int)$conversation['group_id'], $userId]);
        return [$conversation, $member];
    }

    public static function messages()
    {
        $user = self::user();
        $conversationId = \Request::int('conversation_id');
        [$conversation, $member] = self::member((int)$user['id'], $conversationId);
        if (!$conversation || !$member) \Response::json(404, '群聊不存在或你不是群成员', null, 404);
        $t = self::tables();
        \Database::execute("DELETE FROM {$t['messages']} WHERE conversation_id = ? AND created_at < ?", [$conversationId, date('Y-m-d H:i:s', time() - 30 * 86400)]);
        $page = max(1, \Request::int('page', 1));
        $size = min(max(1, \Request::int('page_size', 30)), 100);
        $offset = ($page - 1) * $size;
        $rows = \Database::fetchAll("SELECT m.*, u.nickname AS sender_nickname, u.avatar AS sender_avatar FROM {$t['messages']} m LEFT JOIN {$t['users']} u ON u.id = m.sender_id WHERE m.conversation_id = ? ORDER BY m.created_at DESC LIMIT {$offset}, {$size}", [$conversationId]);
        foreach ($rows as &$row) {
            $row['is_mine'] = (int)$row['sender_id'] === (int)$user['id'];
            $row['sender'] = ['id' => (int)$row['sender_id'], 'nickname' => $row['sender_nickname'] ?? '', 'avatar' => $row['sender_avatar'] ?? ''];
        }
        \Response::success(['list' => $rows, 'page' => $page, 'page_size' => $size, 'has_more' => count($rows) >= $size]);
    }

    public static function send()
    {
        $user = self::user();
        $conversationId = \Request::int('conversation_id');
        [$conversation, $member] = self::member((int)$user['id'], $conversationId);
        if (!$conversation || !$member) \Response::json(404, '群聊不存在或你不是群成员', null, 404);
        $type = \Request::str('message_type', 'text');
        $content = \Request::str('content');
        $image = \Request::str('image_url');
        $reply = \Request::int('reply_to_id');
        if (!in_array($type, ['text', 'image'], true)) \Response::json(422, '消息类型无效');
        if (($type === 'text' && $content === '') || ($type === 'image' && $image === '')) \Response::json(422, '消息内容不能为空');
        if (mb_strlen($content) > 2000) \Response::json(422, '消息内容过长');
        $t = self::tables();
        \Database::execute("INSERT INTO {$t['messages']} (conversation_id, sender_id, message_type, content, image_url, reply_to_id, is_read, created_at) VALUES (?, ?, ?, ?, ?, ?, 0, ?)", [$conversationId, (int)$user['id'], $type, $content, $image ?: null, $reply > 0 ? $reply : null, now()]);
        $id = (int)\Database::lastInsertId();
        \Database::execute("UPDATE {$t['conversations']} SET last_message_at = ?, last_message_preview = ? WHERE id = ?", [now(), $type === 'image' ? '图片' : mb_substr($content, 0, 100), $conversationId]);
        \Response::success(['id' => $id, 'conversation_id' => $conversationId, 'message_type' => $type, 'content' => $content, 'image_url' => $image, 'reply_to_id' => $reply > 0 ? $reply : null, 'created_at' => now()]);
    }

    public static function read()
    {
        $user = self::user();
        $conversationId = \Request::int('conversation_id');
        [$conversation, $member] = self::member((int)$user['id'], $conversationId);
        if (!$conversation || !$member) \Response::json(404, '群聊不存在', null, 404);
        $messages = \Database::table('messages');
        \Database::execute("UPDATE {$messages} SET is_read = 1 WHERE conversation_id = ? AND sender_id != ?", [$conversationId, (int)$user['id']]);
        \Response::success(null, '已读');
    }
}
