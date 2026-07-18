<?php

namespace App\Controllers;

class PostController
{
    public static function list()
    {
        $threadId = \Request::int('thread_id');
        $page = max(1, \Request::int('page', 1));
        $pageSize = min(max(1, \Request::int('page_size', 20)), 50);
        $offset = ($page - 1) * $pageSize;

        if ($threadId <= 0) {
            \Response::json(422, '主题 ID 错误');
        }

        $posts = \Database::table('posts');
        $users = \Database::table('users');

        $sql = "
            SELECT p.*, u.nickname, u.avatar, u.level
            FROM {$posts} p
            LEFT JOIN {$users} u ON u.id = p.user_id
            WHERE p.thread_id = ? AND p.status = 1
            ORDER BY p.floor ASC
            LIMIT {$offset}, {$pageSize}
        ";

        $rows = \Database::fetchAll($sql, [$threadId]);

        \Response::success([
            'list' => $rows,
            'page' => $page,
            'page_size' => $pageSize,
            'has_more' => count($rows) >= $pageSize,
        ]);
    }

    public static function create()
    {
        $user = \Auth::requireLogin();

        $threadId = \Request::int('thread_id');
        $parentId = \Request::int('parent_id');
        $content = \Request::input('content', '');

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $content = sanitize_forum_content($content);

        if ($content === '') {
            \Response::json(422, '请输入评论内容');
        }

        if (mb_strlen(strip_tags($content)) > 5000) {
            \Response::json(422, '评论内容过长');
        }

        $threads = \Database::table('threads');
        $posts = \Database::table('posts');

        $thread = \Database::fetch(
            "SELECT id, user_id, title FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        // 如果是回复某条评论，验证父评论存在
        $parentPost = null;
        if ($parentId > 0) {
            $parentPost = \Database::fetch(
                "SELECT p.id, p.user_id, u.nickname
                 FROM {$posts} p
                 LEFT JOIN " . \Database::table('users') . " u ON u.id = p.user_id
                 WHERE p.id = ? AND p.thread_id = ? AND p.status = 1
                 LIMIT 1",
                [$parentId, $threadId]
            );
        }

        \Database::begin();

        try {
            $floorRow = \Database::fetch(
                "SELECT MAX(floor) AS max_floor FROM {$posts} WHERE thread_id = ?",
                [$threadId]
            );

            $floor = (int)($floorRow['max_floor'] ?? 0) + 1;

            \Database::execute(
                "INSERT INTO {$posts}
                (`thread_id`, `user_id`, `parent_id`, `content`, `floor`, `like_count`, `status`, `created_at`, `updated_at`)
                VALUES (?, ?, ?, ?, ?, 0, 1, ?, ?)",
                [
                    $threadId,
                    $user['id'],
                    $parentId > 0 ? $parentId : null,
                    $content,
                    $floor,
                    now(),
                    now(),
                ]
            );

            $postId = (int)\Database::lastInsertId();
            $newPost = \Database::fetch("SELECT * FROM {$posts} WHERE id = ?", [$postId]);
            record_sync_operation('posts', $postId, 'insert', $newPost);

            \Database::execute(
                "UPDATE {$threads}
                 SET reply_count = reply_count + 1,
                      updated_at = ?
                 WHERE id = ?",
                [
                    now(),
                    $threadId,
                ]
            );
            $updatedThread = \Database::fetch("SELECT * FROM {$threads} WHERE id = ?", [$threadId]);
            record_sync_operation('threads', $threadId, 'update', $updatedThread);

            add_content_daily_stat(
                'thread',
                $threadId,
                (int)$thread['user_id'],
                'reply_count',
                1
            );

            $threadTitle = $thread['title'] ?? '帖子';
            $nickname = $user['nickname'] ?: ($user['username'] ?? '用户');

            // 通知帖子作者（如果评论者不是帖子作者）
            if ((int)$user['id'] !== (int)$thread['user_id']) {
                \App\Controllers\NotificationController::create(
                    (int)$thread['user_id'],
                    'reply',
                    '回复了我的帖子',
                    $nickname . ' 回复了「' . $threadTitle . '」',
                    [
                        'thread_id' => $threadId,
                        'post_id' => $postId,
                        'from_user_id' => (int)$user['id'],
                    ]
                );
            }

            // 通知被回复的评论作者（如果回复了某条评论，且评论者不是该评论作者）
            if ($parentPost && (int)$user['id'] !== (int)$parentPost['user_id']) {
                \App\Controllers\NotificationController::create(
                    (int)$parentPost['user_id'],
                    'reply',
                    '回复了我的评论',
                    $nickname . ' 在「' . $threadTitle . '」中回复了你的评论',
                    [
                        'thread_id' => $threadId,
                        'post_id' => $postId,
                        'from_user_id' => (int)$user['id'],
                    ]
                );
            }

            \Database::commit();

            \Response::success([
                'id' => $postId,
                'post_id' => $postId,
                'thread_id' => $threadId,
                'content' => $content,
                'floor' => $floor,
                'created_at' => now(),
                'author' => [
                    'id' => (int)$user['id'],
                    'nickname' => $user['nickname'] ?? $user['username'] ?? '用户',
                    'avatar' => $user['avatar'] ?? '',
                ],
            ], '评论成功');

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, '评论失败');
        }
    }

    public static function like()
    {
        self::togglePostLike(true);
    }

    public static function delete()
    {
        $user = \Auth::requireLogin();
        $postId = \Request::int('post_id');

        if ($postId <= 0) {
            \Response::json(422, '评论 ID 错误');
        }

        $posts = \Database::table('posts');
        $threads = \Database::table('threads');

        $post = \Database::fetch(
            "SELECT p.*, t.user_id AS thread_user_id
             FROM {$posts} p
             INNER JOIN {$threads} t ON t.id = p.thread_id
             WHERE p.id = ? AND p.status = 1 AND t.status = 1
             LIMIT 1",
            [$postId]
        );

        if (!$post) {
            \Response::json(404, '评论不存在');
        }

        $userId = (int)$user['id'];
        $canDelete = $userId === (int)$post['user_id']
            || $userId === (int)$post['thread_user_id']
            || \SiteSetting::isAdmin($user);

        if (!$canDelete) {
            \Response::json(403, '无权删除该评论');
        }

        \Database::begin();

        try {
            \Database::execute(
                "UPDATE {$posts} SET status = 0, updated_at = ? WHERE id = ?",
                [now(), $postId]
            );
            $deletedPost = \Database::fetch(
                "SELECT * FROM {$posts} WHERE id = ?",
                [$postId]
            );
            record_sync_operation('posts', $postId, 'update', $deletedPost);

            \Database::execute(
                "UPDATE {$threads}
                 SET reply_count = GREATEST(reply_count - 1, 0), updated_at = ?
                 WHERE id = ?",
                [now(), (int)$post['thread_id']]
            );
            $updatedThread = \Database::fetch(
                "SELECT * FROM {$threads} WHERE id = ?",
                [(int)$post['thread_id']]
            );
            record_sync_operation(
                'threads',
                (int)$post['thread_id'],
                'update',
                $updatedThread
            );

            \Database::commit();

            \Response::success([
                'post_id' => $postId,
                'reply_count' => (int)($updatedThread['reply_count'] ?? 0),
            ], '评论已删除');
        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());
            \Response::json(500, '删除评论失败');
        }
    }

    public static function unlike()
    {
        self::togglePostLike(false);
    }

    private static function togglePostLike($like)
    {
        $user = \Auth::requireLogin();
        $postId = \Request::int('post_id');

        if ($postId <= 0) {
            \Response::json(422, '评论 ID 错误');
        }

        $posts = \Database::table('posts');
        $likes = \Database::table('likes');

        $post = \Database::fetch(
            "SELECT id, user_id, thread_id FROM {$posts} WHERE id = ? AND status = 1 LIMIT 1",
            [$postId]
        );

        if (!$post) {
            \Response::json(404, '评论不存在');
        }

        \Database::begin();

        try {
            $exists = \Database::fetch(
                "SELECT id FROM {$likes}
                 WHERE user_id = ? AND object_type = 'post' AND object_id = ?
                 LIMIT 1",
                [$user['id'], $postId]
            );

            if ($like) {
                if (!$exists) {
                    \Database::execute(
                        "INSERT INTO {$likes}
                        (`user_id`, `object_type`, `object_id`, `created_at`)
                         VALUES (?, 'post', ?, ?)",
                        [$user['id'], $postId, now()]
                    );
                    $likeId = (int)\Database::lastInsertId();
                    record_sync_operation('likes', $likeId, 'insert');

                    \Database::execute(
                        "UPDATE {$posts} SET like_count = like_count + 1 WHERE id = ?",
                        [$postId]
                    );
                    $updatedPost = \Database::fetch("SELECT * FROM {$posts} WHERE id = ?", [$postId]);
                    record_sync_operation('posts', $postId, 'update', $updatedPost);

                    // 通知评论作者
                    if ((int)$user['id'] !== (int)$post['user_id']) {
                        \App\Controllers\NotificationController::create(
                            (int)$post['user_id'],
                            'like',
                            '赞了我的评论',
                            ($user['nickname'] ?? '用户') . ' 赞了你的评论',
                            [
                                'thread_id' => (int)$post['thread_id'],
                                'post_id' => $postId,
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
                         WHERE user_id = ? AND object_type = 'post' AND object_id = ?",
                        [$user['id'], $postId]
                    );
                    if ($exists) record_sync_operation('likes', (int)$exists['id'], 'delete');

                    \Database::execute(
                        "UPDATE {$posts} SET like_count = GREATEST(like_count - 1, 0) WHERE id = ?",
                        [$postId]
                    );
                    $updatedPost = \Database::fetch("SELECT * FROM {$posts} WHERE id = ?", [$postId]);
                    record_sync_operation('posts', $postId, 'update', $updatedPost);
                }

                $message = '已取消点赞';
            }

            $countRow = \Database::fetch(
                "SELECT like_count FROM {$posts} WHERE id = ? LIMIT 1",
                [$postId]
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
}
