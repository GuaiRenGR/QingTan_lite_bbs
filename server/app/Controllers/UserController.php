<?php

namespace App\Controllers;

class UserController
{
    public static function profile()
    {
        $userId = \Request::int('id');

        if ($userId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        $users = \Database::table('users');
        $threads = \Database::table('threads');
        $posts = \Database::table('posts');
        $favorites = \Database::table('favorites');
        $follows = \Database::table('user_follows');

        $user = \Database::fetch(
            "SELECT
                id,
                username,
                nickname,
                email,
                avatar,
                space_cover,
                bio,
                badge_name,
                badge_color,
                verify_level,
                level,
                score,
                status,
                created_at
             FROM {$users}
             WHERE id = ?
             LIMIT 1",
            [$userId]
        );

        if (!$user) {
            \Response::json(404, '用户不存在');
        }

        $viewer = \Auth::user();
        $viewerId = $viewer ? (int)$viewer['id'] : 0;

        $threadCount = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$threads} WHERE user_id = ? AND status = 1",
            [$userId]
        );

        $postCount = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$posts} WHERE user_id = ? AND status = 1",
            [$userId]
        );

        $favoriteCount = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$favorites} WHERE user_id = ? AND object_type = 'thread'",
            [$userId]
        );

        $followersCount = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$follows} WHERE following_id = ?",
            [$userId]
        );

        $followingCount = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$follows} WHERE follower_id = ?",
            [$userId]
        );

        $isFollowing = false;

        if ($viewerId > 0 && $viewerId !== $userId) {
            $follow = \Database::fetch(
                "SELECT id FROM {$follows} WHERE follower_id = ? AND following_id = ? LIMIT 1",
                [$viewerId, $userId]
            );

            $isFollowing = $follow ? true : false;
        }

        \Response::success([
            'id' => (int)$user['id'],
            'username' => $user['username'],
            'nickname' => $user['nickname'],
            'email' => $viewerId === $userId ? $user['email'] : null,
            'avatar' => $user['avatar'] ?: '',
            'space_cover' => $user['space_cover'] ?: '',
            'bio' => $user['bio'] ?: '',
            'badge_name' => $user['badge_name'] ?: '',
            'badge_color' => $user['badge_color'] ?: '',
            'verify_level' => (int)($user['verify_level'] ?? 0),
            'level' => (int)$user['level'],
            'score' => (int)$user['score'],
            'status' => (int)$user['status'],
            'created_at' => $user['created_at'],
            'thread_count' => (int)($threadCount['c'] ?? 0),
            'post_count' => (int)($postCount['c'] ?? 0),
            'favorite_count' => (int)($favoriteCount['c'] ?? 0),
            'followers_count' => (int)($followersCount['c'] ?? 0),
            'following_count' => (int)($followingCount['c'] ?? 0),
            'is_self' => $viewerId > 0 && $viewerId === $userId,
            'is_following' => $isFollowing,
        ]);
    }

    public static function follow()
    {
        $viewer = \Auth::requireLogin();
        $targetUserId = \Request::int('user_id');

        if ($targetUserId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        if ((int)$viewer['id'] === $targetUserId) {
            \Response::json(422, '不能关注自己');
        }

        $users = \Database::table('users');
        $follows = \Database::table('user_follows');

        $target = \Database::fetch(
            "SELECT id FROM {$users} WHERE id = ? AND status = 1 LIMIT 1",
            [$targetUserId]
        );

        if (!$target) {
            \Response::json(404, '用户不存在');
        }

        \Database::begin();

        try {
            $exists = \Database::fetch(
                "SELECT id FROM {$follows} WHERE follower_id = ? AND following_id = ? LIMIT 1",
                [$viewer['id'], $targetUserId]
            );

            if (!$exists) {
                \Database::execute(
                    "INSERT INTO {$follows}
                    (`follower_id`, `following_id`, `created_at`)
                    VALUES (?, ?, ?)",
                    [$viewer['id'], $targetUserId, now()]
                );
                $followId = (int)\Database::lastInsertId();
                record_sync_operation('user_follows', $followId, 'insert');
            }

            \Database::commit();

            \Response::success(null, '关注成功');

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, '关注失败');
        }
    }

    public static function unfollow()
    {
        $viewer = \Auth::requireLogin();
        $targetUserId = \Request::int('user_id');

        if ($targetUserId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        $follows = \Database::table('user_follows');

        \Database::execute(
            "DELETE FROM {$follows} WHERE follower_id = ? AND following_id = ?",
            [$viewer['id'], $targetUserId]
        );
        record_sync_operation('user_follows', 0, 'delete');

        \Response::success(null, '已取消关注');
    }

    public static function threads()
    {
        $userId = \Request::int('user_id');
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(max(1, \Request::int('page_size', 20)), 50);
        $offset = ($page - 1) * $pageSize;

        if ($userId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        $threads = \Database::table('threads');

        $viewer = \Auth::user();
        $viewerId = $viewer ? (int)$viewer['id'] : 0;
        $isSelf = $viewerId === $userId;

        $visibilityWhere = $isSelf ? '' : " AND visibility = 'public'";

        $rows = \Database::fetchAll(
            "SELECT
                id,
                id AS thread_id,
                forum_id,
                user_id,
                title,
                summary,
                cover,
                view_count,
                reply_count,
                like_count,
                favorite_count,
                is_top,
                is_digest,
                visibility,
                created_at
             FROM {$threads}
             WHERE user_id = ? AND status = 1 {$visibilityWhere}
             ORDER BY created_at DESC
             LIMIT {$offset}, {$pageSize}",
            [$userId]
        );

        \Response::success([
            'list' => self::formatList($rows),
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($rows) >= $pageSize,
        ]);
    }

    public static function posts()
    {
        $userId = \Request::int('user_id');
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(max(1, \Request::int('page_size', 20)), 50);
        $offset = ($page - 1) * $pageSize;

        if ($userId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        $posts = \Database::table('posts');
        $threads = \Database::table('threads');

        $rows = \Database::fetchAll(
            "SELECT
                p.id AS post_id,
                p.thread_id,
                p.content,
                p.floor,
                p.created_at,
                t.id,
                t.title,
                t.summary,
                t.cover,
                t.reply_count,
                t.like_count,
                t.favorite_count
             FROM {$posts} p
             INNER JOIN {$threads} t ON t.id = p.thread_id
             WHERE p.user_id = ?
               AND p.status = 1
               AND t.status = 1
             ORDER BY p.created_at DESC
             LIMIT {$offset}, {$pageSize}",
            [$userId]
        );

        \Response::success([
            'list' => self::formatList($rows),
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($rows) >= $pageSize,
        ]);
    }

    public static function favorites()
    {
        $userId = \Request::int('user_id');
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(max(1, \Request::int('page_size', 20)), 50);
        $offset = ($page - 1) * $pageSize;

        if ($userId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        $favorites = \Database::table('favorites');
        $threads = \Database::table('threads');

        $rows = \Database::fetchAll(
            "SELECT
                f.id AS favorite_id,
                f.created_at AS favorite_at,
                t.id,
                t.id AS thread_id,
                t.forum_id,
                t.user_id,
                t.title,
                t.summary,
                t.cover,
                t.view_count,
                t.reply_count,
                t.like_count,
                t.favorite_count,
                t.created_at
             FROM {$favorites} f
             INNER JOIN {$threads} t ON t.id = f.object_id
             WHERE f.user_id = ?
               AND f.object_type = 'thread'
               AND t.status = 1
             ORDER BY f.created_at DESC
             LIMIT {$offset}, {$pageSize}",
            [$userId]
        );

        \Response::success([
            'list' => self::formatList($rows),
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($rows) >= $pageSize,
        ]);
    }

    private static function formatList($rows)
    {
        return array_map(function ($row) {
            return [
                'id' => isset($row['id']) ? (int)$row['id'] : 0,
                'thread_id' => isset($row['thread_id']) ? (int)$row['thread_id'] : (int)($row['id'] ?? 0),
                'title' => $row['title'] ?? '无标题',
                'summary' => $row['summary'] ?? '',
                'content' => isset($row['content']) ? make_summary($row['content'], 80) : '',
                'cover' => $row['cover'] ?? '',
                'reply_count' => (int)($row['reply_count'] ?? 0),
                'like_count' => (int)($row['like_count'] ?? 0),
                'favorite_count' => (int)($row['favorite_count'] ?? 0),
                'created_at' => $row['created_at'] ?? '',
            ];
        }, $rows);
    }
}
