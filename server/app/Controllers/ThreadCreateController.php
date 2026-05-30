<?php

namespace App\Controllers;

class ThreadCreateController
{
    public static function create()
    {
        $user = \Auth::requireLogin();

        $forumId = \Request::int('forum_id', 0);
        $title = trim(\Request::str('title'));
        $content = \Request::input('content', '');
        $mode = \Request::str('mode', 'article');

        $musicUrl = trim(\Request::str('music_url'));
        $musicName = trim(\Request::str('music_name'));

        $imageUrls = parse_json_array_input(\Request::input('image_urls', []));
        $attachmentIds = parse_json_array_input(\Request::input('attachment_ids', []));
        $tagNames = \Request::input('tags', []);
        $requestedVisibility = \Request::str('visibility', 'public');

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

        if ($title === '' || mb_strlen($title) < 2 || mb_strlen($title) > 80) {
            \Response::json(422, '标题长度需为 2-80 个字符');
        }

        $content = sanitize_forum_content($content);

        if ($content === '' && empty($imageUrls)) {
            \Response::json(422, '请输入帖子内容或上传图片');
        }

        $remoteImages = extract_forum_img_urls($content);

        if ($mode === 'image' && empty($imageUrls) && empty($remoteImages)) {
            \Response::json(422, '图片模式至少需要上传图片或插入远程图片');
        }

        $allImages = array_values(array_unique(array_merge($imageUrls, $remoteImages)));

        $cover = '';

        if (!empty($allImages[0])) {
            $thumb = generate_thumbnail($allImages[0], $user['id']);
            $cover = $thumb ? $thumb['url'] : $allImages[0];
        }

        if ($musicUrl !== '' && !validate_remote_url($musicUrl)) {
            \Response::json(422, '音乐地址必须是远程 URL');
        }

        $summarySource = preg_replace('/\[markdown\]([\s\S]*?)\[\/markdown\]/i', '$1', $content);
        $summarySource = preg_replace('/\[img=https?:\/\/[^\]\s]+\]/i', '', $summarySource);
        $summary = make_summary($summarySource, 120);

        // 确定帖子可见性
        $visibility = 'public';
        if ($requestedVisibility === 'private' && \SiteSetting::isAdmin($user)) {
            $visibility = 'private';
        } elseif (\SiteSetting::isReviewRequired() && !\SiteSetting::isReviewer($user)) {
            $visibility = 'pending';
        }

        $threads = \Database::table('threads');
        $attachments = \Database::table('attachments');

        \Database::begin();

        try {
            \Database::execute(
                "INSERT INTO {$threads}
                (`forum_id`, `user_id`, `title`, `content`, `summary`, `cover`,
                 `mode`, `images_json`, `music_url`, `music_name`,
                 `view_count`, `reply_count`, `like_count`, `favorite_count`, `share_count`,
                 `is_top`, `is_digest`, `status`, `visibility`, `created_at`, `updated_at`)
                VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 0, 0, 1, ?, ?, ?)",
                [
                    $forumId,
                    $user['id'],
                    $title,
                    $content,
                    $summary,
                    $cover,
                    $mode,
                    json_encode($allImages, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
                    $musicUrl,
                    $musicName,
                    $visibility,
                    now(),
                    now(),
                ]
            );

            $threadId = (int)\Database::lastInsertId();

            if (!empty($attachmentIds)) {
                $ids = array_values(array_filter(array_map('intval', $attachmentIds)));

                if (!empty($ids)) {
                    $placeholders = implode(',', array_fill(0, count($ids), '?'));

                    \Database::execute(
                        "UPDATE {$attachments}
                         SET object_type = 'thread', object_id = ?
                         WHERE user_id = ?
                           AND id IN ({$placeholders})",
                        array_merge([$threadId, $user['id']], $ids)
                    );
                }
            }

            sync_thread_tags($threadId, $tagNames);

            \Database::commit();

            \Response::success([
                'id' => $threadId,
                'thread_id' => $threadId,
            ], '发布成功');

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, '发布失败');
        }
    }
}
