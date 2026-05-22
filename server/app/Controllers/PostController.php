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
            "SELECT id, user_id FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
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
                (`thread_id`, `user_id`, `content`, `floor`, `like_count`, `status`, `created_at`, `updated_at`)
                VALUES (?, ?, ?, ?, 0, 1, ?, ?)",
                [
                    $threadId,
                    $user['id'],
                    $content,
                    $floor,
                    now(),
                    now(),
                ]
            );

            $postId = (int)\Database::lastInsertId();

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

            add_content_daily_stat(
                'thread',
                $threadId,
                (int)$thread['user_id'],
                'reply_count',
                1
            );

            // 创建回复通知
            if ((int)$user['id'] !== (int)$thread['user_id']) {
                $threads2 = \Database::table('threads');
                $threadInfo = \Database::fetch(
                    "SELECT title FROM {$threads2} WHERE id = ? LIMIT 1",
                    [$threadId]
                );
                $threadTitle = $threadInfo['title'] ?? '帖子';

                \App\Controllers\NotificationController::create(
                    (int)$thread['user_id'],
                    'reply',
                    '回复了我的帖子',
                    $user['nickname'] ?? '用户' . ' 回复了「' . $threadTitle . '」',
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
}
