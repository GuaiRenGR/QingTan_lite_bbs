<?php

namespace App\Controllers;

class ThreadManageController
{
    public static function update()
    {
        $user = \Auth::requireLogin();

        $threadId = \Request::int('thread_id');
        $title = trim(\Request::input('title', ''));
        $content = trim(\Request::input('content', ''));
        $mode = \Request::input('mode', 'article');
        $forumId = \Request::int('forum_id', 0);
        $tagNames = \Request::input('tags', []);

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        if ($title === '') {
            \Response::json(422, '请输入标题');
        }

        if ($content === '') {
            \Response::json(422, '请输入正文');
        }

        if (!in_array($mode, ['article', 'image'], true)) {
            $mode = 'article';
        }

        if (!is_array($tagNames)) {
            $tagNames = [];
        }

        $tagNames = array_slice($tagNames, 0, 5);

        if ($forumId <= 0) {
            $forumId = ForumController::defaultId();
        }

        $threads = \Database::table('threads');

        $thread = \Database::fetch(
            "SELECT id, user_id
             FROM {$threads}
             WHERE id = ? AND status = 1
             LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        if ((int)$thread['user_id'] !== (int)$user['id']) {
            \Response::json(403, '无权编辑该帖子');
        }

        $content = sanitize_forum_content($content);

        $remoteImages = extract_forum_img_urls($content);

        $imageUrls = \Request::input('image_urls', []);

        if (!is_array($imageUrls)) {
            $imageUrls = [];
        }

        $imageUrls = array_values(array_filter(array_map('trim', $imageUrls)));

        if ($mode === 'image' && empty($imageUrls) && empty($remoteImages)) {
            \Response::json(422, '图片模式至少需要上传图片或插入远程图片');
        }

        $allImages = array_values(array_unique(array_merge($imageUrls, $remoteImages)));
        $cover = !empty($allImages[0]) ? $allImages[0] : '';

        $summary = mb_substr(strip_tags(preg_replace('/\[[^\]]+\]/', '', $content)), 0, 120);

        \Database::execute(
            "UPDATE {$threads}
             SET forum_id = ?,
                 title = ?,
                 content = ?,
                 summary = ?,
                 mode = ?,
                 cover = ?,
                 images_json = ?,
                 updated_at = ?
             WHERE id = ?",
            [
                $forumId,
                $title,
                $content,
                $summary,
                $mode,
                $cover,
                json_encode($allImages, JSON_UNESCAPED_UNICODE),
                now(),
                $threadId,
            ]
        );

        sync_thread_tags($threadId, $tagNames);

        \Response::success([
            'thread_id' => $threadId,
        ], '保存成功');
    }

    public static function delete()
    {
        $user = \Auth::requireLogin();

        $threadId = \Request::int('thread_id');

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');

        $thread = \Database::fetch(
            "SELECT id, user_id
             FROM {$threads}
             WHERE id = ? AND status = 1
             LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        if ((int)$thread['user_id'] !== (int)$user['id']) {
            \Response::json(403, '无权删除该帖子');
        }

        \Database::execute(
            "UPDATE {$threads}
             SET status = 0,
                 deleted_at = ?
             WHERE id = ?",
            [
                now(),
                $threadId,
            ]
        );

        \Response::success(null, '已删除');
    }

    public static function report()
    {
        $user = \Auth::user();

        $threadId = \Request::int('thread_id');
        $reason = trim(\Request::input('reason', ''));

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        if ($reason === '') {
            $reason = '用户举报';
        }

        $reports = \Database::table('reports');

        \Database::execute(
            "INSERT INTO {$reports}
             (`user_id`, `object_type`, `object_id`, `reason`, `status`, `created_at`)
             VALUES (?, 'thread', ?, ?, 0, ?)",
            [
                $user ? (int)$user['id'] : null,
                $threadId,
                $reason,
                now(),
            ]
        );

        \Response::success(null, '举报已提交');
    }
}
