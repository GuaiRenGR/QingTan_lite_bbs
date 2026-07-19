<?php

namespace App\Controllers;

class ThreadReadController
{
    public static function detail()
    {
        $threadId = \Request::int('id');

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $users = \Database::table('users');
        $posts = \Database::table('posts');
        $likes = \Database::table('likes');
        $favorites = \Database::table('favorites');

        \Database::execute(
            "UPDATE {$threads} SET view_count = view_count + 1 WHERE id = ?",
            [$threadId]
        );
        record_sync_operation('threads', $threadId, 'update');

        $thread = \Database::fetch(
            "SELECT
                t.*,
                u.id AS author_id,
                u.nickname AS author_name,
                u.username AS author_username,
                u.avatar AS author_avatar,
                u.badge_name AS author_badge_name,
                u.badge_color AS author_badge_color,
                u.verify_level AS author_verify_level
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE t.id = ? AND t.status = 1
             LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        $viewer = \Auth::user();
        $viewerId = $viewer ? (int)$viewer['id'] : 0;

        // 可见性检查
        $visibility = $thread['visibility'] ?? 'public';
        $isOwner = $viewerId > 0 && $viewerId === (int)$thread['user_id'];
        $isViewerReviewer = $viewer && \SiteSetting::isReviewer($viewer);
        $isViewerAdmin = $viewer && \SiteSetting::isAdmin($viewer);

        if ($visibility === 'private' && !$isOwner && !$isViewerAdmin) {
            \Response::json(404, '帖子不存在');
        }

        if ($visibility === 'pending' && !$isOwner && !$isViewerReviewer) {
            \Response::json(404, '帖子不存在');
        }

        if ($visibility === 'locked' && !$isOwner && !$isViewerReviewer) {
            \Response::json(404, '帖子不存在');
        }

        $isLiked = false;
        $isFavorited = false;

        if ($viewerId > 0) {
            $liked = \Database::fetch(
                "SELECT id FROM {$likes}
                 WHERE user_id = ? AND object_type = 'thread' AND object_id = ?
                 LIMIT 1",
                [$viewerId, $threadId]
            );

            $fav = \Database::fetch(
                "SELECT id FROM {$favorites}
                 WHERE user_id = ? AND object_type = 'thread' AND object_id = ?
                 LIMIT 1",
                [$viewerId, $threadId]
            );

            $isLiked = $liked ? true : false;
            $isFavorited = $fav ? true : false;
        }

        add_content_daily_stat(
            'thread',
            $threadId,
            (int)$thread['user_id'],
            'view_count',
            1
        );

        if ($viewerId > 0) {
            record_thread_history($viewerId, $threadId);
        }

        $canViewHidden = false;

        if ($viewerId > 0) {
            if ($viewerId === (int)$thread['user_id']) {
                $canViewHidden = true;
            } else {
                $reply = \Database::fetch(
                    "SELECT id
                     FROM {$posts}
                     WHERE thread_id = ?
                       AND user_id = ?
                       AND status = 1
                     LIMIT 1",
                    [
                        $threadId,
                        $viewerId,
                    ]
                );

                $canViewHidden = $reply ? true : false;
            }
        }

        $commentRows = \Database::fetchAll(
            "SELECT
                p.*,
                u.nickname AS author_name,
                u.avatar AS author_avatar,
                u.badge_name AS author_badge_name,
                u.badge_color AS author_badge_color,
                u.verify_level AS author_verify_level
             FROM {$posts} p
             LEFT JOIN {$users} u ON u.id = p.user_id
             WHERE p.thread_id = ? AND p.status = 1
             ORDER BY p.created_at ASC
             LIMIT 300",
            [$threadId]
        );

        // 获取当前用户已点赞的评论 ID
        $likedPostIds = [];
        if ($viewerId > 0 && !empty($commentRows)) {
            $postIds = array_column($commentRows, 'id');
            $placeholders = implode(',', array_fill(0, count($postIds), '?'));
            $likedRows = \Database::fetchAll(
                "SELECT object_id FROM {$likes}
                 WHERE user_id = ? AND object_type = 'post' AND object_id IN ({$placeholders})",
                array_merge([$viewerId], $postIds)
            );
            $likedPostIds = array_map('intval', array_column($likedRows, 'object_id'));
        }

        $images = [];

        if (!empty($thread['images_json'])) {
            $decoded = json_decode($thread['images_json'], true);
            if (is_array($decoded)) {
                $images = array_values(array_filter($decoded, 'validate_remote_url'));
            }
        }

        if (empty($images)) {
            $images = extract_img_tags($thread['content'] ?? '');
        }

        \Response::success([
            'thread' => [
                'id' => (int)$thread['id'],
                'thread_id' => (int)$thread['id'],
                'dv_code' => $thread['dv_code'] ?? '',
                'forum_id' => (int)$thread['forum_id'],
                'user_id' => (int)$thread['user_id'],
                'title' => $thread['title'],
                'content' => $thread['content'],
                'summary' => $thread['summary'] ?? '',
                'cover' => $thread['cover'] ?? '',
                'mode' => $thread['mode'] ?? 'article',
                'images' => $images,
                'music_url' => $thread['music_url'] ?? '',
                'music_name' => $thread['music_name'] ?? '',
                'view_count' => (int)($thread['view_count'] ?? 0),
                'reply_count' => (int)($thread['reply_count'] ?? 0),
                'like_count' => (int)($thread['like_count'] ?? 0),
                'favorite_count' => (int)($thread['favorite_count'] ?? 0),
                'share_count' => (int)($thread['share_count'] ?? 0),
                'is_liked' => $isLiked,
                'is_favorited' => $isFavorited,
                'is_owner' => $isOwner,
                'is_admin' => $isViewerAdmin,
                'visibility' => $visibility,
                'can_view_hidden' => $canViewHidden,
                'tags' => get_thread_tags($thread['id']),
                'created_at' => $thread['created_at'],
                'author' => [
                    'id' => (int)$thread['author_id'],
                    'nickname' => $thread['author_name'] ?: '用户',
                    'username' => $thread['author_username'] ?: '',
                    'avatar' => $thread['author_avatar'] ?: '',
                    'badge_name' => $thread['author_badge_name'] ?: '',
                    'badge_color' => $thread['author_badge_color'] ?: '',
                    'verify_level' => (int)($thread['author_verify_level'] ?? 0),
                ],
            ],
            'posts' => array_map(function ($row) use (
                $likedPostIds,
                $viewerId,
                $isViewerAdmin,
                $isOwner
            ) {
                return [
                    'id' => (int)$row['id'],
                    'thread_id' => (int)$row['thread_id'],
                    'user_id' => (int)$row['user_id'],
                    'parent_id' => $row['parent_id'] ? (int)$row['parent_id'] : null,
                    'content' => $row['content'],
                    'floor' => (int)$row['floor'],
                    'like_count' => (int)($row['like_count'] ?? 0),
                    'is_liked' => in_array((int)$row['id'], $likedPostIds),
                    'can_delete' => $viewerId > 0 && (
                        $viewerId === (int)$row['user_id']
                        || $isOwner
                        || $isViewerAdmin
                    ),
                    'created_at' => $row['created_at'],
                    'author' => [
                        'id' => (int)$row['user_id'],
                        'nickname' => $row['author_name'] ?: '用户',
                        'avatar' => $row['author_avatar'] ?: '',
                        'badge_name' => $row['author_badge_name'] ?: '',
                        'badge_color' => $row['author_badge_color'] ?: '',
                        'verify_level' => (int)($row['author_verify_level'] ?? 0),
                    ],
                ];
            }, $commentRows),
        ]);
    }

    /**
     * 通过 DV 码获取帖子详情（转发到 detail，设置 id 参数）
     */
    public static function detailByDv()
    {
        $dvCode = trim(\Request::str('dv_code'));

        if (!\DvCode::isLookupSafe($dvCode)) {
            \Response::json(422, 'DV 码格式错误');
        }

        $threadId = self::findThreadIdByDv($dvCode);

        if ($threadId <= 0) {
            \Response::json(404, '帖子不存在');
        }

        $_GET['id'] = $threadId;
        self::detail();
    }

    public static function embed()
    {
        $dvCode = trim(\Request::str('dv_code'));
        if (!\DvCode::isLookupSafe($dvCode)) {
            \Response::json(422, 'DV 码格式错误');
        }

        $threadId = self::findThreadIdByDv($dvCode);
        if ($threadId <= 0) {
            \Response::json(404, '帖子不存在');
        }

        $threads = \Database::table('threads');
        $users = \Database::table('users');
        $thread = \Database::fetch(
            "SELECT t.id, t.user_id, t.dv_code, t.title, t.content, t.cover,
                    t.visibility, t.status, t.created_at,
                    COALESCE(u.nickname, u.username, '用户') AS author_name
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE t.id = ? AND t.status = 1
             LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        $viewer = \Auth::user();
        $viewerId = $viewer ? (int)$viewer['id'] : 0;
        $isOwner = $viewerId > 0 && $viewerId === (int)$thread['user_id'];
        $isReviewer = $viewer && \SiteSetting::isReviewer($viewer);
        $isAdmin = $viewer && \SiteSetting::isAdmin($viewer);
        $visibility = $thread['visibility'] ?? 'public';

        if ($visibility === 'private' && !$isOwner && !$isAdmin) {
            \Response::json(404, '帖子不存在');
        }
        if (in_array($visibility, ['pending', 'locked'], true) && !$isOwner && !$isReviewer) {
            \Response::json(404, '帖子不存在');
        }

        \Response::success([
            'id' => (int)$thread['id'],
            'dv_code' => $thread['dv_code'],
            'title' => $thread['title'],
            'summary' => make_summary($thread['content'], 100),
            'cover' => $thread['cover'] ?? '',
            'author_name' => $thread['author_name'],
            'created_at' => $thread['created_at'],
        ]);
    }

    private static function findThreadIdByDv($dvCode)
    {
        $threads = \Database::table('threads');
        $thread = \Database::fetch(
            "SELECT id FROM {$threads}
             WHERE BINARY dv_code = ? AND status = 1
             LIMIT 1",
            [$dvCode]
        );
        if ($thread) {
            return (int)$thread['id'];
        }

        try {
            $aliases = \Database::table('thread_dv_aliases');
            $alias = \Database::fetch(
                "SELECT t.id
                 FROM {$aliases} a
                 INNER JOIN {$threads} t ON t.id = a.thread_id
                 WHERE BINARY a.dv_code = ? AND t.status = 1
                 LIMIT 1",
                [$dvCode]
            );
            return $alias ? (int)$alias['id'] : 0;
        } catch (\Throwable $e) {
            return 0;
        }
    }

    public static function following()
    {
        $user = \Auth::requireLogin();

        $page = max(1, \Request::int('page', 1));
        $pageSize = min(30, max(1, \Request::int('page_size', 20)));
        $offset = ($page - 1) * $pageSize;

        $threads = \Database::table('threads');
        $users = \Database::table('users');
        $follows = \Database::table('user_follows');

        $rows = \Database::fetchAll(
            "SELECT
                t.id,
                t.forum_id,
                t.user_id,
                t.title,
                t.summary,
                t.cover,
                t.mode,
                t.images_json,
                t.like_count,
                t.favorite_count,
                t.reply_count,
                t.share_count,
                t.created_at,
                u.nickname AS author_name,
                u.avatar AS author_avatar
             FROM {$threads} t
             INNER JOIN {$follows} f ON f.following_id = t.user_id
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE f.follower_id = ?
               AND t.status = 1 AND t.visibility = 'public'
             ORDER BY t.created_at DESC
             LIMIT {$offset}, {$pageSize}",
            [
                $user['id'],
            ]
        );

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
                'like_count' => (int)($row['like_count'] ?? 0),
                'favorite_count' => (int)($row['favorite_count'] ?? 0),
                'reply_count' => (int)($row['reply_count'] ?? 0),
                'share_count' => (int)($row['share_count'] ?? 0),
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
}
