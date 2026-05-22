<?php

namespace App\Controllers;

class ThreadActionController
{
    public static function like()
    {
        self::toggleLike(true);
    }

    public static function unlike()
    {
        self::toggleLike(false);
    }

    public static function favorite()
    {
        self::toggleFavorite(true);
    }

    public static function unfavorite()
    {
        self::toggleFavorite(false);
    }

    public static function share()
    {
        $threadId = \Request::int('thread_id');

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $shares = \Database::table('shares');

        $thread = \Database::fetch(
            "SELECT id, user_id FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        $viewer = \Auth::user();
        $userId = $viewer ? (int)$viewer['id'] : null;

        \Database::execute(
            "UPDATE {$threads} SET share_count = share_count + 1 WHERE id = ?",
            [$threadId]
        );

        \Database::execute(
            "INSERT INTO {$shares}
            (`user_id`, `thread_id`, `ip`, `created_at`)
            VALUES (?, ?, ?, ?)",
            [
                $userId,
                $threadId,
                $_SERVER['REMOTE_ADDR'] ?? '',
                now(),
            ]
        );

        add_content_daily_stat(
            'thread',
            $threadId,
            (int)$thread['user_id'],
            'share_count',
            1
        );

        $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
            ? 'https'
            : 'http';

        $host = $_SERVER['HTTP_HOST'] ?? '';

        $shareUrl = $scheme . '://' . $host . '/#/thread/' . $threadId;

        \Response::success([
            'share_url' => $shareUrl,
        ], '转发成功');
    }

    private static function toggleLike($like)
    {
        $user = \Auth::requireLogin();
        $threadId = \Request::int('thread_id');

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $likes = \Database::table('likes');

        $thread = \Database::fetch(
            "SELECT id, user_id FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        \Database::begin();

        try {
            $exists = \Database::fetch(
                "SELECT id FROM {$likes}
                 WHERE user_id = ? AND object_type = 'thread' AND object_id = ?
                 LIMIT 1",
                [$user['id'], $threadId]
            );

            if ($like) {
                if (!$exists) {
                    \Database::execute(
                        "INSERT INTO {$likes}
                        (`user_id`, `object_type`, `object_id`, `created_at`)
                        VALUES (?, 'thread', ?, ?)",
                        [$user['id'], $threadId, now()]
                    );

                    \Database::execute(
                        "UPDATE {$threads}
                         SET like_count = like_count + 1
                         WHERE id = ?",
                        [$threadId]
                    );

                    add_content_daily_stat(
                        'thread',
                        $threadId,
                        (int)$thread['user_id'],
                        'like_count',
                        1
                    );

                    // 创建点赞通知
                    if ((int)$user['id'] !== (int)$thread['user_id']) {
                        $threads2 = \Database::table('threads');
                        $threadInfo = \Database::fetch(
                            "SELECT title FROM {$threads2} WHERE id = ? LIMIT 1",
                            [$threadId]
                        );
                        $threadTitle = $threadInfo['title'] ?? '帖子';

                        \App\Controllers\NotificationController::create(
                            (int)$thread['user_id'],
                            'like',
                            '赞了我的帖子',
                            ($user['nickname'] ?? '用户') . ' 赞了「' . $threadTitle . '」',
                            [
                                'thread_id' => $threadId,
                                'from_user_id' => (int)$user['id'],
                            ]
                        );
                    }
                }

                $message = '点赞成功';
            } else {
                if ($exists) {
                    \Database::execute(
                        "DELETE FROM {$likes}
                         WHERE user_id = ? AND object_type = 'thread' AND object_id = ?",
                        [$user['id'], $threadId]
                    );

                    \Database::execute(
                        "UPDATE {$threads}
                         SET like_count = IF(like_count > 0, like_count - 1, 0)
                         WHERE id = ?",
                        [$threadId]
                    );
                }

                $message = '已取消点赞';
            }

            $countRow = \Database::fetch(
                "SELECT like_count FROM {$threads} WHERE id = ? LIMIT 1",
                [$threadId]
            );

            \Database::commit();

            \Response::success([
                'is_liked' => $like,
                'like_count' => (int)($countRow['like_count'] ?? 0),
            ], $message);

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, $like ? '点赞失败' : '取消点赞失败');
        }
    }

    private static function toggleFavorite($favorite)
    {
        $user = \Auth::requireLogin();
        $threadId = \Request::int('thread_id');

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $favorites = \Database::table('favorites');

        $thread = \Database::fetch(
            "SELECT id, user_id FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        \Database::begin();

        try {
            $exists = \Database::fetch(
                "SELECT id FROM {$favorites}
                 WHERE user_id = ? AND object_type = 'thread' AND object_id = ?
                 LIMIT 1",
                [$user['id'], $threadId]
            );

            if ($favorite) {
                if (!$exists) {
                    \Database::execute(
                        "INSERT INTO {$favorites}
                        (`user_id`, `object_type`, `object_id`, `created_at`)
                        VALUES (?, 'thread', ?, ?)",
                        [$user['id'], $threadId, now()]
                    );

                    \Database::execute(
                        "UPDATE {$threads}
                         SET favorite_count = favorite_count + 1
                         WHERE id = ?",
                        [$threadId]
                    );

                    add_content_daily_stat(
                        'thread',
                        $threadId,
                        (int)$thread['user_id'],
                        'favorite_count',
                        1
                    );
                }

                $message = '收藏成功';
            } else {
                if ($exists) {
                    \Database::execute(
                        "DELETE FROM {$favorites}
                         WHERE user_id = ? AND object_type = 'thread' AND object_id = ?",
                        [$user['id'], $threadId]
                    );

                    \Database::execute(
                        "UPDATE {$threads}
                         SET favorite_count = IF(favorite_count > 0, favorite_count - 1, 0)
                         WHERE id = ?",
                        [$threadId]
                    );
                }

                $message = '已取消收藏';
            }

            $countRow = \Database::fetch(
                "SELECT favorite_count FROM {$threads} WHERE id = ? LIMIT 1",
                [$threadId]
            );

            \Database::commit();

            \Response::success([
                'is_favorited' => $favorite,
                'favorite_count' => (int)($countRow['favorite_count'] ?? 0),
            ], $message);

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, $favorite ? '收藏失败' : '取消收藏失败');
        }
    }
}
