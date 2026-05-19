<?php

namespace App\Controllers;

class LikeController
{
    public static function likeThread()
    {
        $user = \Auth::requireLogin();
        $threadId = \Request::int('id');

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $likes = \Database::table('likes');

        $thread = \Database::fetch(
            "SELECT id FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        \Database::begin();

        try {
            $exists = \Database::fetch(
                "SELECT id FROM {$likes} WHERE user_id = ? AND object_type = 'thread' AND object_id = ? LIMIT 1",
                [$user['id'], $threadId]
            );

            if (!$exists) {
                \Database::execute(
                    "INSERT INTO {$likes}
                    (`user_id`,`object_type`,`object_id`,`created_at`)
                    VALUES (?,'thread',?,?)",
                    [$user['id'], $threadId, now()]
                );

                \Database::execute(
                    "UPDATE {$threads} SET like_count = like_count + 1 WHERE id = ?",
                    [$threadId]
                );
            }

            \Database::commit();

            \Response::success(null, '点赞成功');

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, '点赞失败');
        }
    }

    public static function unlikeThread()
    {
        $user = \Auth::requireLogin();
        $threadId = \Request::int('id');

        $threads = \Database::table('threads');
        $likes = \Database::table('likes');

        \Database::begin();

        try {
            $stmt = \Database::pdo()->prepare(
                "DELETE FROM {$likes} WHERE user_id = ? AND object_type = 'thread' AND object_id = ?"
            );
            $stmt->execute([$user['id'], $threadId]);

            if ($stmt->rowCount() > 0) {
                \Database::execute(
                    "UPDATE {$threads} SET like_count = GREATEST(like_count - 1, 0) WHERE id = ?",
                    [$threadId]
                );
            }

            \Database::commit();

            \Response::success(null, '取消点赞成功');

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, '取消点赞失败');
        }
    }
}
