<?php

namespace App\Controllers;

class CreatorController
{
    public static function summary()
    {
        $user = \Auth::requireLogin();

        $threads = \Database::table('threads');
        $stats = \Database::table('content_stats_daily');

        $total = \Database::fetch(
            "SELECT
                COUNT(*) AS thread_count,
                COALESCE(SUM(view_count), 0) AS total_views,
                COALESCE(SUM(like_count), 0) AS total_likes,
                COALESCE(SUM(share_count), 0) AS total_shares,
                COALESCE(SUM(favorite_count), 0) AS total_favorites,
                COALESCE(SUM(reply_count), 0) AS total_replies
             FROM {$threads}
             WHERE user_id = ? AND status = 1",
            [$user['id']]
        );

        $startDate = date('Y-m-d', strtotime('-6 day'));
        $yesterday = date('Y-m-d', strtotime('-1 day'));

        $dailyRows = \Database::fetchAll(
            "SELECT
                stat_date,
                COALESCE(SUM(view_count), 0) AS view_count,
                COALESCE(SUM(like_count), 0) AS like_count,
                COALESCE(SUM(share_count), 0) AS share_count,
                COALESCE(SUM(favorite_count), 0) AS favorite_count,
                COALESCE(SUM(reply_count), 0) AS reply_count
             FROM {$stats}
             WHERE user_id = ?
               AND object_type = 'thread'
               AND stat_date >= ?
             GROUP BY stat_date
             ORDER BY stat_date ASC",
            [
                $user['id'],
                $startDate,
            ]
        );

        $dailyMap = [];

        foreach ($dailyRows as $row) {
            $dailyMap[$row['stat_date']] = [
                'date' => $row['stat_date'],
                'view_count' => (int)$row['view_count'],
                'like_count' => (int)$row['like_count'],
                'share_count' => (int)$row['share_count'],
                'favorite_count' => (int)$row['favorite_count'],
                'reply_count' => (int)$row['reply_count'],
            ];
        }

        $last7Days = [];

        for ($i = 6; $i >= 0; $i--) {
            $date = date('Y-m-d', strtotime("-{$i} day"));

            $last7Days[] = $dailyMap[$date] ?? [
                'date' => $date,
                'view_count' => 0,
                'like_count' => 0,
                'share_count' => 0,
                'favorite_count' => 0,
                'reply_count' => 0,
            ];
        }

        $yesterdayData = $dailyMap[$yesterday] ?? [
            'date' => $yesterday,
            'view_count' => 0,
            'like_count' => 0,
            'share_count' => 0,
            'favorite_count' => 0,
            'reply_count' => 0,
        ];

        \Response::success([
            'total' => [
                'thread_count' => (int)$total['thread_count'],
                'view_count' => (int)$total['total_views'],
                'like_count' => (int)$total['total_likes'],
                'share_count' => (int)$total['total_shares'],
                'favorite_count' => (int)$total['total_favorites'],
                'reply_count' => (int)$total['total_replies'],
            ],
            'yesterday' => $yesterdayData,
            'last_7_days' => $last7Days,
        ]);
    }

    public static function threads()
    {
        $user = \Auth::requireLogin();

        $page = max(1, \Request::int('page', 1));
        $pageSize = min(30, max(1, \Request::int('page_size', 20)));
        $offset = ($page - 1) * $pageSize;

        $threads = \Database::table('threads');

        $rows = \Database::fetchAll(
            "SELECT
                id,
                title,
                cover,
                mode,
                view_count,
                like_count,
                favorite_count,
                share_count,
                reply_count,
                created_at,
                updated_at
             FROM {$threads}
             WHERE user_id = ?
               AND status = 1
             ORDER BY created_at DESC
             LIMIT {$offset}, {$pageSize}",
            [$user['id']]
        );

        $list = array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'title' => $row['title'],
                'cover' => $row['cover'] ?? '',
                'mode' => $row['mode'] ?? 'article',
                'view_count' => (int)$row['view_count'],
                'like_count' => (int)$row['like_count'],
                'favorite_count' => (int)$row['favorite_count'],
                'share_count' => (int)$row['share_count'],
                'reply_count' => (int)$row['reply_count'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at'],
            ];
        }, $rows);

        \Response::success([
            'list' => $list,
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($list) >= $pageSize,
        ]);
    }
}
