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

        $isAdmin = (int)($user['group_id'] ?? 0) === 99;

        if (!$isAdmin && (int)$thread['user_id'] !== (int)$user['id']) {
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
        $cover = '';

        if (!empty($allImages[0])) {
            self::deleteOldCoverThumb($threadId);

            $thumb = generate_thumbnail($allImages[0], $user['id']);
            $cover = $thumb ? $thumb['url'] : $allImages[0];
        }

        $summary = make_summary($content);

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

        $updatedThread = \Database::fetch("SELECT * FROM {$threads} WHERE id = ?", [$threadId]);
        record_sync_operation('threads', $threadId, 'update', $updatedThread);

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
            "SELECT id, user_id, images_json, content
             FROM {$threads}
             WHERE id = ? AND status = 1
             LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        $isAdmin = (int)($user['group_id'] ?? 0) === 99;

        if (!$isAdmin && (int)$thread['user_id'] !== (int)$user['id']) {
            \Response::json(403, '无权删除该帖子');
        }

        self::cleanupOneDriveFiles($threadId, $thread);
        self::deleteOldCoverThumb($threadId);

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
        record_sync_operation('threads', $threadId, 'delete', null, $thread);

        \Response::success(null, '已删除');
    }

    private static function cleanupOneDriveFiles($threadId, $thread)
    {
        try {
            $attachments = \Database::table('attachments');
            $posts = \Database::table('posts');

            $postIds = \Database::fetchAll(
                "SELECT id FROM {$posts} WHERE thread_id = ?",
                [$threadId]
            );
            $postIdList = array_column($postIds, 'id');

            $placeholders = implode(',', array_fill(0, count($postIdList), '?'));
            $params = array_merge([$threadId], $postIdList);

            if ($postIdList) {
                $rows = \Database::fetchAll(
                    "SELECT onedrive_item_id, file_url FROM {$attachments}
                     WHERE onedrive_item_id IS NOT NULL AND onedrive_item_id != ''
                       AND (
                           (object_type = 'thread' AND object_id = ?)
                           OR (object_type = 'post' AND object_id IN ({$placeholders}))
                       )",
                    $params
                );
            } else {
                $rows = \Database::fetchAll(
                    "SELECT onedrive_item_id, file_url FROM {$attachments}
                     WHERE onedrive_item_id IS NOT NULL AND onedrive_item_id != ''
                       AND object_type = 'thread' AND object_id = ?",
                    [$threadId]
                );
            }

            $itemIds = [];
            foreach ($rows as $row) {
                if (!empty($row['onedrive_item_id'])) {
                    $itemIds[$row['onedrive_item_id']] = true;
                }
            }

            if (empty($itemIds)) {
                return;
            }

            $service = new \OneDriveService();

            foreach (array_keys($itemIds) as $itemId) {
                try {
                    $service->deleteFile($itemId);
                } catch (\Throwable $e) {
                    log_error('OneDrive 删除失败 [' . $itemId . ']: ' . $e->getMessage());
                }
            }

        } catch (\Throwable $e) {
            log_error('清理帖子附件失败 [thread=' . $threadId . ']: ' . $e->getMessage());
        }
    }

    private static function deleteOldCoverThumb($threadId)
    {
        $threads = \Database::table('threads');
        $attachments = \Database::table('attachments');

        $old = \Database::fetch(
            "SELECT cover FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$old || empty($old['cover'])) {
            return;
        }

        $coverUrl = $old['cover'];
        if (preg_match('/[?&]id=(\d+)/', $coverUrl, $m)) {
            $attachmentId = (int)$m[1];

            $att = \Database::fetch(
                "SELECT id, onedrive_item_id FROM {$attachments} WHERE id = ? AND status = 1 LIMIT 1",
                [$attachmentId]
            );

            if ($att) {
                if (!empty($att['onedrive_item_id'])) {
                    try {
                        $service = new \OneDriveService();
                        $service->deleteFile($att['onedrive_item_id']);
                    } catch (\Throwable $e) {
                        log_error('删除旧缩略图失败 [' . $att['onedrive_item_id'] . ']: ' . $e->getMessage());
                    }
                }

                \Database::execute(
                    "UPDATE {$attachments} SET status = 0 WHERE id = ?",
                    [$attachmentId]
                );
            }
        }
    }

    public static function toggleDigest()
    {
        $user = \Auth::requireLogin();

        if ((int)($user['group_id'] ?? 0) !== 99) {
            \Response::json(403, '无权操作');
        }

        $threadId = \Request::int('thread_id');

        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');

        $thread = \Database::fetch(
            "SELECT id, is_digest FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        $newVal = (int)$thread['is_digest'] === 1 ? 0 : 1;

        \Database::execute(
            "UPDATE {$threads} SET is_digest = ? WHERE id = ?",
            [$newVal, $threadId]
        );
        $updatedThread = \Database::fetch("SELECT * FROM {$threads} WHERE id = ?", [$threadId]);
        record_sync_operation('threads', $threadId, 'update', $updatedThread);

        \Response::success([
            'is_digest' => $newVal,
        ], $newVal ? '已设为精华' : '已取消精华');
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
        $reportId = (int)\Database::lastInsertId();
        $reportRow = \Database::fetch("SELECT * FROM {$reports} WHERE id = ?", [$reportId]);
        record_sync_operation('reports', $reportId, 'insert', $reportRow);

        \Response::success(null, '举报已提交');
    }
}
