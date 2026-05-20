<?php

namespace App\Controllers;

class SearchController
{
    public static function threads()
    {
        $keyword = trim(\Request::input('keyword', ''));
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(30, max(1, \Request::int('page_size', 20)));
        $offset = ($page - 1) * $pageSize;

        if ($keyword === '') {
            \Response::json(422, '请输入搜索关键词');
        }

        if (mb_strlen($keyword) > 50) {
            \Response::json(422, '关键词过长');
        }

        $viewer = \Auth::user();

        $threads = \Database::table('threads');
        $users = \Database::table('users');
        $searchLogs = \Database::table('search_logs');

        \Database::execute(
            "INSERT INTO {$searchLogs}
            (`user_id`, `keyword`, `ip`, `created_at`)
            VALUES (?, ?, ?, ?)",
            [
                $viewer ? (int)$viewer['id'] : null,
                $keyword,
                $_SERVER['REMOTE_ADDR'] ?? '',
                now(),
            ]
        );

        $tags = \Database::table('tags');
        $threadTags = \Database::table('thread_tags');

        $like = '%' . $keyword . '%';

        $rows = \Database::fetchAll(
            "SELECT
                t.id,
                t.forum_id,
                t.user_id,
                t.title,
                t.summary,
                t.cover,
                t.mode,
                t.view_count,
                t.like_count,
                t.favorite_count,
                t.share_count,
                t.reply_count,
                t.created_at,
                u.nickname AS author_name,
                u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             LEFT JOIN {$threadTags} tt ON tt.thread_id = t.id
             LEFT JOIN {$tags} tg ON tg.id = tt.tag_id
             WHERE t.status = 1
               AND (
                    t.title LIKE ?
                 OR t.summary LIKE ?
                 OR t.content LIKE ?
                 OR tg.name LIKE ?
               )
             GROUP BY t.id
             ORDER BY
               CASE WHEN t.title LIKE ? THEN 0 ELSE 1 END,
               t.like_count DESC,
               t.created_at DESC
             LIMIT {$offset}, {$pageSize}",
            [
                $like,
                $like,
                $like,
                $like,
                $like,
            ]
        );

        $list = array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'forum_id' => (int)$row['forum_id'],
                'user_id' => (int)$row['user_id'],
                'title' => $row['title'],
                'summary' => $row['summary'] ?? '',
                'cover' => $row['cover'] ?? '',
                'mode' => $row['mode'] ?? 'article',
                'view_count' => (int)$row['view_count'],
                'like_count' => (int)$row['like_count'],
                'favorite_count' => (int)$row['favorite_count'],
                'share_count' => (int)$row['share_count'],
                'reply_count' => (int)$row['reply_count'],
                'created_at' => $row['created_at'],
                'author_name' => $row['author_name'] ?: '用户',
                'author_avatar' => $row['author_avatar'] ?: '',
            ];
        }, $rows);

        \Response::success([
            'keyword' => $keyword,
            'list' => $list,
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($list) >= $pageSize,
        ]);
    }

    public static function hot()
    {
        $searchLogs = \Database::table('search_logs');

        $rows = \Database::fetchAll(
            "SELECT keyword, COUNT(*) AS count
             FROM {$searchLogs}
             WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
             GROUP BY keyword
             ORDER BY count DESC, MAX(id) DESC
             LIMIT 20"
        );

        $list = array_map(function ($row) {
            return [
                'keyword' => $row['keyword'],
                'count' => (int)$row['count'],
            ];
        }, $rows);

        \Response::success([
            'list' => $list,
        ]);
    }
}
