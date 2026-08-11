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

        $threads = \Database::table('threads');
        $users = \Database::table('users');

        $userId = $viewer ? (int)$viewer['id'] : 0;

        // 客户端传来的已展示帖子 ID，用于去重
        $excludeIds = \Request::input('exclude_ids', []);
        if (!is_array($excludeIds)) $excludeIds = [];
        $excludeIds = array_filter(array_map('intval', $excludeIds));

        if ($channel === 'latest') {
            self::latest($threads, $users, $page, $pageSize, $excludeIds, $userId);
            return;
        }

        if ($channel === 'hot') {
            self::hot($threads, $users, $page, $pageSize, $excludeIds, $userId);
            return;
        }

        if ($channel === 'digest') {
            self::digest($threads, $users, $page, $pageSize, $excludeIds, $userId);
            return;
        }

        // Default: recommend algorithm
        self::recommend($threads, $users, $userId, $page, $pageSize, $excludeIds);
    }

    private static function latest($threads, $users, $page, $pageSize, $excludeIds, $userId)
    {
        $offset = ($page - 1) * $pageSize;
        $exclude = self::buildExcludeClause($excludeIds);

        $rows = \Database::fetchAll(
            "SELECT
                t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.cover_width, t.cover_height, t.mode,
                t.images_json, t.sensitive_labels_json, t.view_count, t.like_count, t.favorite_count,
                t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                u.nickname AS author_name, u.username AS author_username, u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE t.status = 1 AND t.visibility = 'public' {$exclude}
             ORDER BY t.is_top DESC, t.created_at DESC
             LIMIT {$offset}, {$pageSize}"
        );

        self::respond($rows, $pageSize, $userId);
    }

    private static function hot($threads, $users, $page, $pageSize, $excludeIds, $userId)
    {
        $offset = ($page - 1) * $pageSize;
        $exclude = self::buildExcludeClause($excludeIds);

        $rows = \Database::fetchAll(
            "SELECT
                t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.cover_width, t.cover_height, t.mode,
                t.images_json, t.sensitive_labels_json, t.view_count, t.like_count, t.favorite_count,
                t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                u.nickname AS author_name, u.username AS author_username, u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE t.status = 1 AND t.visibility = 'public' {$exclude}
             ORDER BY t.is_top DESC,
               (t.view_count + t.like_count * 5 + t.reply_count * 3) DESC,
               t.created_at DESC
             LIMIT {$offset}, {$pageSize}"
        );

        self::respond($rows, $pageSize, $userId);
    }

    private static function digest($threads, $users, $page, $pageSize, $excludeIds, $userId)
    {
        $offset = ($page - 1) * $pageSize;
        $exclude = self::buildExcludeClause($excludeIds);

        $rows = \Database::fetchAll(
            "SELECT
                t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.cover_width, t.cover_height, t.mode,
                t.images_json, t.sensitive_labels_json, t.view_count, t.like_count, t.favorite_count,
                t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                u.nickname AS author_name, u.username AS author_username, u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE t.status = 1 AND t.visibility = 'public' AND t.is_digest = 1 {$exclude}
             ORDER BY t.is_top DESC, t.created_at DESC
             LIMIT {$offset}, {$pageSize}"
        );

        self::respond($rows, $pageSize, $userId);
    }

    private static function recommend($threads, $users, $userId, $page, $pageSize, $excludeIds)
    {
        $stats = \Database::table('content_stats_daily');
        $histories = \Database::table('histories');
        $startDate = date('Y-m-d', strtotime('-6 day'));
        $exclude = self::buildExcludeClause($excludeIds);

        // 取 3 倍候选量
        $candidateLimit = $pageSize * 3;
        $offset = ($page - 1) * $pageSize;

        // 构建用户兴趣画像
        $interestMap = $userId > 0 ? self::buildInterestMap($userId) : [];

        if ($userId > 0) {
            $rows = \Database::fetchAll(
                "SELECT
                    t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.cover_width, t.cover_height, t.mode,
                    t.images_json, t.sensitive_labels_json, t.view_count, t.like_count, t.favorite_count,
                    t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                    u.nickname AS author_name, u.username AS author_username, u.avatar AS author_avatar,
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
                 WHERE t.status = 1 AND t.visibility = 'public' {$exclude}
                 GROUP BY t.id
                 ORDER BY t.is_top DESC, t.created_at DESC
                 LIMIT {$offset}, {$candidateLimit}",
                [$startDate, $userId]
            );
        } else {
            $rows = \Database::fetchAll(
                "SELECT
                    t.id, t.forum_id, t.user_id, t.title, t.summary, t.cover, t.cover_width, t.cover_height, t.mode,
                    t.images_json, t.sensitive_labels_json, t.view_count, t.like_count, t.favorite_count,
                    t.share_count, t.reply_count, t.is_top, t.is_digest, t.created_at,
                    u.nickname AS author_name, u.username AS author_username, u.avatar AS author_avatar,
                    NULL AS history_id,
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
                 WHERE t.status = 1 AND t.visibility = 'public' {$exclude}
                 GROUP BY t.id
                 ORDER BY t.is_top DESC, t.created_at DESC
                 LIMIT {$offset}, {$candidateLimit}",
                [$startDate]
            );
        }

        // 加权随机抽取
        $weighted = [];
        foreach ($rows as $row) {
            $baseScore =
                (int)$row['recent_views'] * 1 +
                (int)$row['recent_likes'] * 5 +
                (int)$row['recent_favorites'] * 8 +
                (int)$row['recent_shares'] * 10 +
                (int)$row['recent_replies'] * 6;

            // 新鲜度：72 小时内帖子有时间衰减加成
            $hoursOld = (time() - strtotime($row['created_at'])) / 3600;
            $freshness = max(0, 72 - $hoursOld) * 0.5;

            // 新鲜度随机因子：让新帖子有更多曝光机会
            $randomFactor = 0.5 + lcg_value() * 1.5; // [0.5, 2.0]
            $freshnessRandom = $freshness * $randomFactor;

            // 兴趣加成
            $forumId = (int)$row['forum_id'];
            $interestBoost = isset($interestMap[$forumId]) ? $interestMap[$forumId] : 1.0;

            // 已浏览降权
            $viewedPenalty = isset($row['history_id']) ? 0.3 : 1.0;

            $finalWeight = ($baseScore + $freshnessRandom + 1) * $interestBoost * $viewedPenalty;

            $weighted[] = [
                'row' => $row,
                'weight' => max(0.01, $finalWeight),
            ];
        }

        // 置顶帖单独处理（始终排在最前）
        $topped = [];
        $normal = [];
        foreach ($weighted as $item) {
            if ((int)$item['row']['is_top'] === 1) {
                $topped[] = $item;
            } else {
                $normal[] = $item;
            }
        }

        // 对非置顶帖做加权随机抽取
        $sampled = self::weightedSample($normal, $pageSize - count($topped));
        $result = array_merge($topped, $sampled);

        $resultRows = array_map(fn($item) => $item['row'], $result);
        self::respond($resultRows, $pageSize, $userId);
    }

    /**
     * 用户兴趣画像：从交互历史中提取 forum 偏好
     * 返回 forum_id => 权重 (1.0 ~ 2.0)
     */
    private static function buildInterestMap(int $userId): array
    {
        $threads = \Database::table('threads');
        $likes = \Database::table('likes');
        $favorites = \Database::table('favorites');
        $histories = \Database::table('histories');

        // 统计用户交互过的帖子所属板块
        $rows = \Database::fetchAll(
            "SELECT t.forum_id, COUNT(*) AS cnt
             FROM (
                 SELECT object_id AS thread_id FROM {$likes} WHERE user_id = ? AND object_type = 'thread'
                 UNION ALL
                 SELECT object_id FROM {$favorites} WHERE user_id = ? AND object_type = 'thread'
                 UNION ALL
                 SELECT object_id FROM {$histories} WHERE user_id = ? AND object_type = 'thread'
             ) u
             INNER JOIN {$threads} t ON t.id = u.thread_id
             WHERE t.forum_id > 0
             GROUP BY t.forum_id
             ORDER BY cnt DESC
             LIMIT 10",
            [$userId, $userId, $userId]
        );

        if (empty($rows)) return [];

        $maxCnt = (int)$rows[0]['cnt'];
        $map = [];

        foreach ($rows as $row) {
            $cnt = (int)$row['cnt'];
            $fid = (int)$row['forum_id'];
            // 线性映射到 [1.0, 2.0]
            $map[$fid] = 1.0 + ($cnt / $maxCnt);
        }

        return $map;
    }

    /**
     * 加权随机抽取（指数分布法）
     * key = -ln(rand) / weight，按 key 升序取前 N 个
     */
    private static function weightedSample(array $items, int $n): array
    {
        if (count($items) <= $n) return $items;

        foreach ($items as &$item) {
            $rand = lcg_value();
            if ($rand < 1e-10) $rand = 1e-10;
            $item['_key'] = -log($rand) / $item['weight'];
        }
        unset($item);

        usort($items, fn($a, $b) => $a['_key'] <=> $b['_key']);

        return array_slice($items, 0, $n);
    }

    /**
     * 构建排除已展示帖子的 WHERE 子句
     */
    private static function buildExcludeClause(array $excludeIds): string
    {
        if (empty($excludeIds)) return '';

        $ids = implode(',', $excludeIds);
        return " AND t.id NOT IN ({$ids})";
    }

    private static function respond($rows, $pageSize, $userId = 0)
    {
        $likedIds = [];
        if ($userId > 0 && !empty($rows)) {
            $threadIds = array_values(array_filter(array_map(
                fn($row) => (int)($row['id'] ?? 0),
                $rows
            )));
            if (!empty($threadIds)) {
                $likes = \Database::table('likes');
                $idList = implode(',', $threadIds);
                $likedRows = \Database::fetchAll(
                    "SELECT object_id FROM {$likes}
                     WHERE user_id = ? AND object_type = 'thread'
                       AND object_id IN ({$idList})",
                    [$userId]
                );
                $likedIds = array_fill_keys(
                    array_map('intval', array_column($likedRows, 'object_id')),
                    true
                );
            }
        }

        $list = array_map(function ($row) use ($likedIds) {
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

            $sensitiveLabels = json_decode($row['sensitive_labels_json'] ?? '[]', true);

            return [
                'id' => (int)$row['id'],
                'forum_id' => (int)$row['forum_id'],
                'user_id' => (int)$row['user_id'],
                'title' => $row['title'],
                'summary' => $row['summary'] ?? '',
                'cover' => $row['cover'] ?? '',
                'cover_width' => (int)($row['cover_width'] ?? 0),
                'cover_height' => (int)($row['cover_height'] ?? 0),
                'mode' => $row['mode'] ?? 'article',
                'sensitive_labels' => is_array($sensitiveLabels) ? array_values($sensitiveLabels) : [],
                'like_count' => (int)$row['like_count'],
                'favorite_count' => (int)$row['favorite_count'],
                'share_count' => (int)$row['share_count'],
                'reply_count' => (int)$row['reply_count'],
                'view_count' => (int)$row['view_count'],
                'is_top' => (int)($row['is_top'] ?? 0),
                'is_digest' => (int)($row['is_digest'] ?? 0),
                'created_at' => $row['created_at'],
                'author_name' => $row['author_name'] ?: '用户',
                'author_username' => $row['author_username'] ?: '',
                'author_avatar' => $row['author_avatar'] ?: '',
                'is_liked' => isset($likedIds[(int)$row['id']]),
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
