<?php

namespace App\Controllers;

class RecommendController
{
    public static function threads()
    {
        $viewer = \Auth::user();

        $page = max(1, \Request::int('page', 1));
        $pageSize = min(30, max(1, \Request::int('page_size', 20)));
        $channel = \Request::input('channel', 'recommend');
        $offset = ($page - 1) * $pageSize;

        $threads = \Database::table('threads');
        $users = \Database::table('users');

        $userId = $viewer ? (int)$viewer['id'] : 0;

        if ($channel === 'latest') {
            self::latest($threads, $users, $offset, $pageSize);
            return;
        }

        if ($channel === 'hot') {
            self::hot($threads, $users, $offset, $pageSize);
            return;
        }

        if ($channel === 'digest') {
            self::digest($threads, $users, $offset, $pageSize);
            return;
        }

        // Default: recommend algorithm
        self::recommend($threads, $users, $userId, $offset, $pageSize);
    }

    private static function latest($threads, $users, $offset, $pageSize)
    {
        $rows = \Database::fetchAll(
            "SELECT
                t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.mode,
                t.images_json, t.view_count, t.like_count, t.favorite_count,
                t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                u.nickname AS author_name, u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE t.status = 1 AND t.visibility = 'public'
             ORDER BY t.is_top DESC, t.created_at DESC
             LIMIT {$offset}, {$pageSize}"
        );

        self::respond($rows, $pageSize);
    }

    private static function hot($threads, $users, $offset, $pageSize)
    {
        $rows = \Database::fetchAll(
            "SELECT
                t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.mode,
                t.images_json, t.view_count, t.like_count, t.favorite_count,
                t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                u.nickname AS author_name, u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE t.status = 1 AND t.visibility = 'public'
             ORDER BY t.is_top DESC,
               (t.view_count + t.like_count * 5 + t.reply_count * 3) DESC,
               t.created_at DESC
             LIMIT {$offset}, {$pageSize}"
        );

        self::respond($rows, $pageSize);
    }

    private static function digest($threads, $users, $offset, $pageSize)
    {
        $rows = \Database::fetchAll(
            "SELECT
                t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.mode,
                t.images_json, t.view_count, t.like_count, t.favorite_count,
                t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                u.nickname AS author_name, u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE t.status = 1 AND t.visibility = 'public' AND t.is_digest = 1
             ORDER BY t.is_top DESC, t.created_at DESC
             LIMIT {$offset}, {$pageSize}"
        );

        self::respond($rows, $pageSize);
    }

    private static function recommend($threads, $users, $userId, $offset, $pageSize)
    {
        $stats = \Database::table('content_stats_daily');
        $histories = \Database::table('histories');
        $startDate = date('Y-m-d', strtotime('-6 day'));

        if ($userId > 0) {
            $rows = \Database::fetchAll(
                "SELECT
                    t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.mode,
                    t.images_json, t.view_count, t.like_count, t.favorite_count,
                    t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                    u.nickname AS author_name, u.avatar AS author_avatar,
                    h.id AS history_id,
                    COALESCE(SUM(s.view_count), 0) AS recent_views,
                    COALESCE(SUM(s.like_count), 0) AS recent_likes,
                    COALESCE(SUM(s.favorite_count), 0) AS recent_favorites,
                    COALESCE(SUM(s.share_count), 0) AS recent_shares,
                    COALESCE(SUM(s.reply_count), 0) AS recent_replies
                 FROM {$threads} t
                 LEFT JOIN {$users} u ON u.id = t.user_id
                 LEFT JOIN {$stats} s
                   ON s.object_type = 'thread'
                  AND s.object_id = t.id
                  AND s.stat_date >= ?
                 LEFT JOIN {$histories} h
                   ON h.user_id = ?
                  AND h.object_type = 'thread'
                  AND h.object_id = t.id
                 WHERE t.status = 1 AND t.visibility = 'public'
                 GROUP BY t.id
                 ORDER BY
                   t.is_top DESC,
                   (
                     COALESCE(SUM(s.view_count), 0) * 1 +
                     COALESCE(SUM(s.like_count), 0) * 5 +
                     COALESCE(SUM(s.favorite_count), 0) * 8 +
                     COALESCE(SUM(s.share_count), 0) * 10 +
                     COALESCE(SUM(s.reply_count), 0) * 6 +
                     GREATEST(0, 72 - TIMESTAMPDIFF(HOUR, t.created_at, NOW())) * 0.5
                   ) * IF(h.id IS NULL, 1, 0.35) DESC,
                   t.created_at DESC
                 LIMIT {$offset}, {$pageSize}",
                [
                    $startDate,
                    $userId,
                ]
            );
        } else {
            $rows = \Database::fetchAll(
                "SELECT
                    t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.mode,
                    t.images_json, t.view_count, t.like_count, t.favorite_count,
                    t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                    u.nickname AS author_name, u.avatar AS author_avatar,
                    COALESCE(SUM(s.view_count), 0) AS recent_views,
                    COALESCE(SUM(s.like_count), 0) AS recent_likes,
                    COALESCE(SUM(s.favorite_count), 0) AS recent_favorites,
                    COALESCE(SUM(s.share_count), 0) AS recent_shares,
                    COALESCE(SUM(s.reply_count), 0) AS recent_replies
                 FROM {$threads} t
                 LEFT JOIN {$users} u ON u.id = t.user_id
                 LEFT JOIN {$stats} s
                   ON s.object_type = 'thread'
                  AND s.object_id = t.id
                  AND s.stat_date >= ?
                 WHERE t.status = 1 AND t.visibility = 'public'
                 GROUP BY t.id
                 ORDER BY
                   t.is_top DESC,
                   (
                     COALESCE(SUM(s.view_count), 0) * 1 +
                     COALESCE(SUM(s.like_count), 0) * 5 +
                     COALESCE(SUM(s.favorite_count), 0) * 8 +
                     COALESCE(SUM(s.share_count), 0) * 10 +
                     COALESCE(SUM(s.reply_count), 0) * 6 +
                     GREATEST(0, 72 - TIMESTAMPDIFF(HOUR, t.created_at, NOW())) * 0.5
                   ) DESC,
                   t.created_at DESC
                 LIMIT {$offset}, {$pageSize}",
                [
                    $startDate,
                ]
            );
        }

        self::respond($rows, $pageSize);
    }

    private static function respond($rows, $pageSize)
    {
        $list = array_map(function ($row) {
            $images = [];

            if (!empty($row['images_json'])) {
                $decoded = json_decode($row['images_json'], true);
                if (is_array($decoded)) {
                    $images = $decoded;
                }
            }

            if (empty($row['cover']) && !empty($images[0])) {
                $row['cover'] = $images[0];
            }

            return [
                'id' => (int)$row['id'],
                'forum_id' => (int)$row['forum_id'],
                'user_id' => (int)$row['user_id'],
                'title' => $row['title'],
                'summary' => $row['summary'] ?? '',
                'cover' => $row['cover'] ?? '',
                'mode' => $row['mode'] ?? 'article',
                'like_count' => (int)$row['like_count'],
                'favorite_count' => (int)$row['favorite_count'],
                'share_count' => (int)$row['share_count'],
                'reply_count' => (int)$row['reply_count'],
                'view_count' => (int)$row['view_count'],
                'is_top' => (int)($row['is_top'] ?? 0),
                'is_digest' => (int)($row['is_digest'] ?? 0),
                'created_at' => $row['created_at'],
                'author_name' => $row['author_name'] ?: '用户',
                'author_avatar' => $row['author_avatar'] ?: '',
            ];
        }, $rows);

        \Response::success([
            'list' => $list,
            'page' => max(1, \Request::int('page', 1)),
            'page_size' => $pageSize,
            'has_more' => count($list) >= $pageSize,
        ]);
    }
}
