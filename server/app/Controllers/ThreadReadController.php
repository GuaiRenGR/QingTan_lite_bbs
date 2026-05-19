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

        $thread = \Database::fetch(
            "SELECT
                t.*,
                u.id AS author_id,
                u.nickname AS author_name,
                u.username AS author_username,
                u.avatar AS author_avatar
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

        $commentRows = \Database::fetchAll(
            "SELECT
                p.*,
                u.nickname AS author_name,
                u.avatar AS author_avatar
             FROM {$posts} p
             LEFT JOIN {$users} u ON u.id = p.user_id
             WHERE p.thread_id = ? AND p.status = 1
             ORDER BY p.created_at ASC
             LIMIT 300",
            [$threadId]
        );

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
                'created_at' => $thread['created_at'],
                'author' => [
                    'id' => (int)$thread['author_id'],
                    'nickname' => $thread['author_name'] ?: '用户',
                    'username' => $thread['author_username'] ?: '',
                    'avatar' => $thread['author_avatar'] ?: '',
                ],
            ],
            'posts' => array_map(function ($row) {
                return [
                    'id' => (int)$row['id'],
                    'thread_id' => (int)$row['thread_id'],
                    'user_id' => (int)$row['user_id'],
                    'content' => $row['content'],
                    'floor' => (int)$row['floor'],
                    'created_at' => $row['created_at'],
                    'author' => [
                        'id' => (int)$row['user_id'],
                        'nickname' => $row['author_name'] ?: '用户',
                        'avatar' => $row['author_avatar'] ?: '',
                    ],
                ];
            }, $commentRows),
        ]);
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
               AND t.status = 1
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
