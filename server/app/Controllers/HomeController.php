<?php

namespace App\Controllers;

class HomeController
{
    public static function feed()
    {
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(max(1, \Request::int('page_size', 20)), 50);
        $channel = \Request::str('channel', 'recommend');
        $offset = ($page - 1) * $pageSize;

        $threads = \Database::table('threads');
        $users = \Database::table('users');
        $forums = \Database::table('forums');

        $where = "t.status = 1 AND t.visibility = 'public'";
        $params = [];

        if ($channel === 'digest') {
            $where .= " AND t.is_digest = 1";
        } elseif ($channel === 'image') {
            $where .= " AND t.cover IS NOT NULL AND t.cover <> ''";
        }

        if ($channel === 'hot') {
            $order = "
                (t.view_count * 0.2
                + t.reply_count * 0.3
                + t.like_count * 0.3
                + t.favorite_count * 0.4
                + t.share_count * 0.2
                + IF(t.is_digest = 1, 20, 0)) DESC
            ";
        } elseif ($channel === 'latest') {
            $order = "t.created_at DESC";
        } else {
            $order = "
                t.is_top DESC,
                (t.view_count * 0.2
                + t.reply_count * 0.3
                + t.like_count * 0.3
                + t.favorite_count * 0.4
                + IF(t.is_digest = 1, 20, 0)) DESC,
                t.created_at DESC
            ";
        }

        $sql = "
            SELECT
                t.*,
                u.nickname,
                u.avatar,
                f.name AS forum_name
            FROM {$threads} t
            LEFT JOIN {$users} u ON u.id = t.user_id
            LEFT JOIN {$forums} f ON f.id = t.forum_id
            WHERE {$where}
            ORDER BY {$order}
            LIMIT {$offset}, {$pageSize}
        ";

        $rows = \Database::fetchAll($sql, $params);

        $list = array_map(function ($row) {
            return self::formatThread($row);
        }, $rows);

        \Response::success([
            'list' => $list,
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($list) >= $pageSize,
        ]);
    }

    private static function formatThread($row)
    {
        return [
            'id' => (int)$row['id'],
            'forum_id' => (int)$row['forum_id'],
            'user_id' => (int)$row['user_id'],
            'type' => $row['type'],
            'title' => $row['title'],
            'summary' => $row['summary'],
            'content' => '',
            'cover' => $row['cover'],
            'sensitive_labels' => is_array(json_decode($row['sensitive_labels_json'] ?? '[]', true))
                ? array_values(json_decode($row['sensitive_labels_json'], true))
                : [],
            'view_count' => (int)$row['view_count'],
            'reply_count' => (int)$row['reply_count'],
            'like_count' => (int)$row['like_count'],
            'favorite_count' => (int)$row['favorite_count'],
            'is_top' => (int)$row['is_top'],
            'is_digest' => (int)$row['is_digest'],
            'created_at' => $row['created_at'],
            'user' => [
                'id' => (int)$row['user_id'],
                'nickname' => $row['nickname'] ?: '匿名用户',
                'avatar' => $row['avatar'] ?: '',
            ],
            'forum' => [
                'id' => (int)$row['forum_id'],
                'name' => $row['forum_name'] ?: '社区',
            ],
        ];
    }
}
