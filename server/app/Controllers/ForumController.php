<?php

namespace App\Controllers;

class ForumController
{
    public static function list()
    {
        $forums = \Database::table('forums');

        $rows = \Database::fetchAll(
            "SELECT * FROM {$forums} WHERE status = 1 ORDER BY sort_order ASC, id ASC"
        );

        \Response::success($rows);
    }

    public static function detail()
    {
        $id = \Request::int('id');

        if ($id <= 0) {
            \Response::json(422, '版块 ID 错误');
        }

        $forums = \Database::table('forums');

        $forum = \Database::fetch(
            "SELECT * FROM {$forums} WHERE id = ? AND status = 1 LIMIT 1",
            [$id]
        );

        if (!$forum) {
            \Response::json(404, '版块不存在');
        }

        \Response::success($forum);
    }

    public static function threads()
    {
        $forumId = \Request::int('id');
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(max(1, \Request::int('page_size', 20)), 50);
        $offset = ($page - 1) * $pageSize;

        $threads = \Database::table('threads');
        $users = \Database::table('users');

        $sql = "
            SELECT t.*, u.nickname, u.avatar
            FROM {$threads} t
            LEFT JOIN {$users} u ON u.id = t.user_id
            WHERE t.forum_id = ? AND t.status = 1
            ORDER BY t.is_top DESC, t.last_reply_at DESC, t.created_at DESC
            LIMIT {$offset}, {$pageSize}
        ";

        $rows = \Database::fetchAll($sql, [$forumId]);

        \Response::success([
            'list' => $rows,
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($rows) >= $pageSize,
        ]);
    }
}
