<?php

namespace App\Controllers;

class ThreadController
{
    public static function detail()
    {
        $id = \Request::int('id');

        if ($id <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $users = \Database::table('users');
        $forums = \Database::table('forums');

        $sql = "
            SELECT
                t.*,
                u.nickname,
                u.avatar,
                u.level,
                u.score,
                f.name AS forum_name
            FROM {$threads} t
            LEFT JOIN {$users} u ON u.id = t.user_id
            LEFT JOIN {$forums} f ON f.id = t.forum_id
            WHERE t.id = ? AND t.status = 1
            LIMIT 1
        ";

        $thread = \Database::fetch($sql, [$id]);

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        \Database::execute(
            "UPDATE {$threads} SET view_count = view_count + 1 WHERE id = ?",
            [$id]
        );

        $thread['view_count'] = (int)$thread['view_count'] + 1;

        $data = [
            'id' => (int)$thread['id'],
            'forum_id' => (int)$thread['forum_id'],
            'user_id' => (int)$thread['user_id'],
            'type' => $thread['type'],
            'title' => $thread['title'],
            'summary' => $thread['summary'],
            'content' => $thread['content'],
            'cover' => $thread['cover'],
            'view_count' => (int)$thread['view_count'],
            'reply_count' => (int)$thread['reply_count'],
            'like_count' => (int)$thread['like_count'],
            'favorite_count' => (int)$thread['favorite_count'],
            'is_top' => (int)$thread['is_top'],
            'is_digest' => (int)$thread['is_digest'],
            'is_closed' => (int)$thread['is_closed'],
            'created_at' => $thread['created_at'],
            'user' => [
                'id' => (int)$thread['user_id'],
                'nickname' => $thread['nickname'] ?: '匿名用户',
                'avatar' => $thread['avatar'] ?: '',
                'level' => (int)$thread['level'],
                'score' => (int)$thread['score'],
            ],
            'forum' => [
                'id' => (int)$thread['forum_id'],
                'name' => $thread['forum_name'] ?: '社区',
            ],
        ];

        \Response::success($data);
    }

    public static function create()
    {
        $user = \Auth::requireLogin();

        if ((int)$user['status'] !== 1) {
            \Response::json(403, '账号状态异常');
        }

        $forumId = \Request::int('forum_id');
        $title = \Request::str('title');
        $content = trim((string)\Request::input('content'));
        $cover = \Request::str('cover');
        $type = \Request::str('type', 'normal');

        if ($forumId <= 0) {
            \Response::json(422, '请选择版块');
        }

        if (mb_strlen($title, 'UTF-8') < 5 || mb_strlen($title, 'UTF-8') > 80) {
            \Response::json(422, '标题需为 5-80 字');
        }

        if (mb_strlen(strip_tags($content), 'UTF-8') < 5) {
            \Response::json(422, '正文内容太短');
        }

        $forums = \Database::table('forums');
        $threads = \Database::table('threads');
        $users = \Database::table('users');
        $scoreLogs = \Database::table('score_logs');

        $forum = \Database::fetch(
            "SELECT * FROM {$forums} WHERE id = ? AND status = 1 LIMIT 1",
            [$forumId]
        );

        if (!$forum) {
            \Response::json(404, '版块不存在');
        }

        $safeContent = strip_dangerous_html($content);
        $summary = make_summary($safeContent);
        $status = (int)$forum['need_audit'] === 1 ? 2 : 1;

        \Database::begin();

        try {
            $now = now();

            \Database::execute(
                "INSERT INTO {$threads}
                (`forum_id`,`user_id`,`type`,`title`,`summary`,`content`,`cover`,`status`,`last_reply_at`,`created_at`,`updated_at`)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                [
                    $forumId,
                    $user['id'],
                    $type,
                    $title,
                    $summary,
                    $safeContent,
                    $cover ?: null,
                    $status,
                    $now,
                    $now,
                    $now
                ]
            );

            $threadId = \Database::lastInsertId();

            \Database::execute(
                "UPDATE {$forums} SET thread_count = thread_count + 1, today_count = today_count + 1 WHERE id = ?",
                [$forumId]
            );

            \Database::execute(
                "UPDATE {$users} SET score = score + 5 WHERE id = ?",
                [$user['id']]
            );

            $newUser = \Database::fetch("SELECT score FROM {$users} WHERE id = ?", [$user['id']]);

            \Database::execute(
                "INSERT INTO {$scoreLogs}
                (`user_id`,`action`,`amount`,`balance`,`remark`,`created_at`)
                VALUES (?,?,?,?,?,?)",
                [$user['id'], 'create_thread', 5, $newUser['score'], '发布主题奖励', $now]
            );

            \Database::commit();

            \Response::success([
                'id' => (int)$threadId,
                'status' => $status,
            ], $status === 1 ? '发帖成功' : '发帖成功，等待审核');

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, '发帖失败');
        }
    }
}
