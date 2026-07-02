<?php

namespace App\Controllers;

class HistoryController
{
    public static function list()
    {
        $user = \Auth::requireLogin();

        $page = max(1, \Request::int('page', 1));
        $pageSize = min(50, max(1, \Request::int('page_size', 20)));
        $offset = ($page - 1) * $pageSize;

        $histories = \Database::table('histories');
        $threads = \Database::table('threads');
        $users = \Database::table('users');

        $rows = \Database::fetchAll(
            "SELECT
                h.object_id,
                h.last_viewed_at,
                h.view_count AS history_view_count,
                t.id,
                t.title,
                t.summary,
                t.cover,
                t.mode,
                t.like_count,
                t.view_count,
                t.is_top,
                t.is_digest,
                t.created_at,
                u.nickname AS author_name,
                u.avatar AS author_avatar
             FROM {$histories} h
             INNER JOIN {$threads} t ON t.id = h.object_id
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE h.user_id = ?
               AND h.object_type = 'thread'
               AND t.status = 1
             ORDER BY h.last_viewed_at DESC
             LIMIT {$offset}, {$pageSize}",
            [$user['id']]
        );

        $list = array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'title' => $row['title'],
                'summary' => $row['summary'] ?? '',
                'cover' => $row['cover'] ?? '',
                'mode' => $row['mode'] ?? 'article',
                'like_count' => (int)$row['like_count'],
                'view_count' => (int)$row['view_count'],
                'is_top' => (int)($row['is_top'] ?? 0),
                'is_digest' => (int)($row['is_digest'] ?? 0),
                'history_view_count' => (int)$row['history_view_count'],
                'last_viewed_at' => $row['last_viewed_at'],
                'created_at' => $row['created_at'],
                'author_name' => $row['author_name'] ?: '用户',
                'author_avatar' => $row['author_avatar'] ?: '',
            ];
        }, $rows);

        \Response::success([
            'list' => $list,
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($list) >= $pageSize,
        ]);
    }

    public static function delete()
    {
        $user = \Auth::requireLogin();

        $threadId = \Request::int('thread_id');

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $histories = \Database::table('histories');

        \Database::execute(
            "DELETE FROM {$histories}
             WHERE user_id = ?
                AND object_type = 'thread'
                AND object_id = ?",
            [
                $user['id'],
                $threadId,
            ]
        );
        record_sync_operation('histories', 0, 'delete');

        \Response::success(null, '已删除');
    }

    public static function clear()
    {
        $user = \Auth::requireLogin();

        $histories = \Database::table('histories');

        \Database::execute(
            "DELETE FROM {$histories}
             WHERE user_id = ?
                AND object_type = 'thread'",
            [$user['id']]
        );
        record_sync_operation('histories', 0, 'delete');

        \Response::success(null, '历史记录已清空');
    }
}
