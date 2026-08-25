<?php

namespace App\Controllers;

class UploadController
{
    public static function media()
    {
        $user = \Auth::requireLogin();

        $type = $_POST['type'] ?? $_GET['type'] ?? \Request::str('type', 'image');
        if (!is_string($type)) {
            $type = 'image';
        }
        $type = trim($type);
        if (!in_array($type, ['image', 'music', 'lyrics', 'video', 'attachment', 'chatlog'], true)) {
            $type = 'image';
        }

        if (empty($_FILES['file'])) {
            \Response::json(422, '请选择文件');
        }

        $file = $_FILES['file'];

        if ($file['error'] !== UPLOAD_ERR_OK) {
            \Response::json(422, '文件上传失败，错误码：' . $file['error']);
        }

        $config = require FX_ROOT . '/config/onedrive.php';

        $size = intval($file['size']);

        if ($type === 'image') {
            if ($size > intval($config['max_image_size'])) {
                \Response::json(422, '图片不能超过 ' . intval($config['max_image_size'] / 1024 / 1024) . 'MB');
            }
        } elseif ($type === 'video') {
            if ($size > intval($config['max_video_size'])) {
                \Response::json(422, '视频不能超过 ' . intval($config['max_video_size'] / 1024 / 1024) . 'MB');
            }
        } elseif ($type === 'attachment') {
            // 管理员上传附件不限制大小
        } elseif ($type === 'chatlog') {
            if ($size > 4 * 1024 * 1024) {
                \Response::json(422, '聊天记录文件不能超过 4MB');
            }
        } elseif ($type === 'lyrics') {
            if ($size > 2 * 1024 * 1024) {
                \Response::json(422, '歌词文件不能超过 2MB');
            }
        } else {
            if ($size > intval($config['max_music_size'])) {
                \Response::json(422, '音乐不能超过 ' . intval($config['max_music_size'] / 1024 / 1024) . 'MB');
            }
        }

        $tmp = $file['tmp_name'];
        $originalName = $file['name'];

        $mime = self::detectMime($tmp, $originalName);

        if ($type === 'chatlog') {
            if (strtolower(pathinfo($originalName, PATHINFO_EXTENSION)) !== 'json') {
                \Response::json(422, '聊天记录文件扩展名必须为 .json');
            }
            if (!in_array($mime, ['application/json', 'text/plain', 'application/octet-stream'], true)) {
                \Response::json(422, '聊天记录必须是 JSON 文件');
            }
            $document = json_decode((string)file_get_contents($tmp), true);
            if (!is_array($document) || json_last_error() !== JSON_ERROR_NONE) {
                \Response::json(422, '聊天记录 JSON 格式错误');
            }
            $chatLogError = self::validateChatLog($document);
            if ($chatLogError !== null) {
                \Response::json(422, $chatLogError);
            }
        }

        if ($type === 'image') {
            if (!in_array($mime, [
                'image/jpeg',
                'image/png',
                'image/gif',
                'image/webp',
            ], true)) {
                \Response::json(422, '不支持的图片格式');
            }
        } elseif ($type === 'music') {
            if (!in_array($mime, [
                'audio/mpeg',
                'audio/mp4',
                'audio/aac',
                'audio/wav',
                'audio/ogg',
                'audio/flac',
                'application/octet-stream',
            ], true)) {
                \Response::json(422, '不支持的音乐格式');
            }
        } elseif ($type === 'lyrics') {
            if (!in_array($mime, [
                'text/plain',
                'application/octet-stream',
            ], true)) {
                \Response::json(422, '仅支持 LRC 歌词文件');
            }
            if (strtolower(pathinfo($originalName, PATHINFO_EXTENSION)) !== 'lrc') {
                \Response::json(422, '歌词文件扩展名必须为 .lrc');
            }
        } elseif ($type === 'video') {
            if (!in_array($mime, [
                'video/mp4',
                'video/webm',
                'video/quicktime',
                'video/x-msvideo',
                'video/x-matroska',
                'application/octet-stream',
            ], true)) {
                \Response::json(422, '不支持的视频格式');
            }
        }

        try {
            $service = new \OneDriveService();

            $uploadType = $type === 'image'
                ? 'images'
                : ($type === 'video'
                    ? 'video'
                    : (($type === 'attachment' || $type === 'chatlog') ? 'attachments' : 'music'));

            $result = $service->upload(
                $tmp,
                $originalName,
                $uploadType,
                $mime
            );

            $attachments = \Database::table('attachments');

            \Database::execute(
                "INSERT INTO {$attachments}
                (`user_id`,`object_type`,`object_id`,`file_name`,`file_path`,`file_url`,`file_type`,`file_size`,`onedrive_item_id`,`status`,`created_at`)
                VALUES (?,NULL,NULL,?,?,?,?,?,?,1,?)",
                [
                    $user['id'],
                    $originalName,
                    $result['path'],
                    '',
                    $mime,
                    $size,
                    $result['item_id'],
                    now(),
                ]
            );

            $attachmentId = (int)\Database::lastInsertId();
            $relativeFileUrl = '/index.php?route=file/resolve&id=' . $attachmentId;

            \Database::execute(
                "UPDATE {$attachments} SET file_url = ? WHERE id = ?",
                [$relativeFileUrl, $attachmentId]
            );
            $attRow = \Database::fetch("SELECT * FROM {$attachments} WHERE id = ?", [$attachmentId]);
            record_sync_operation('attachments', $attachmentId, 'insert', $attRow);

            $fileUrl = request_origin() . $relativeFileUrl;

            $music = null;
            if ($type === 'music') {
                $music = MusicLibraryController::createFromUpload(
                    (int)$user['id'],
                    $attachmentId,
                    $fileUrl,
                    $originalName,
                    [
                        'lyrics_url' => \Request::str('lyrics_url'),
                        'cover_url' => \Request::str('cover_url'),
                        'title' => \Request::str('title'),
                        'artist' => \Request::str('artist'),
                    ]
                );
            }

            \Response::success([
                'id' => $attachmentId,
                'type' => $type,
                'url' => $fileUrl,
                'share_url' => $result['share_url'],
                'name' => $result['name'],
                'size' => $result['size'],
                'mime' => $mime,
                'onedrive_item_id' => $result['item_id'],
                'music' => $music ? MusicLibraryController::serialize($music) : null,
                'music_uuid' => $music['uuid'] ?? null,
            ], '上传成功');

        } catch (\Throwable $e) {
            log_error($e->getMessage());

            \Response::json(500, '转存 OneDrive 失败：' . $e->getMessage());
        }
    }

    private static function detectMime($file, $originalName)
    {
        if (function_exists('finfo_open')) {
            $finfo = \finfo_open(FILEINFO_MIME_TYPE);
            if ($finfo) {
                $mime = \finfo_file($finfo, $file);
                \finfo_close($finfo);
                if ($mime && $mime !== 'application/octet-stream') {
                    return $mime;
                }
            }
        }

        if (function_exists('mime_content_type')) {
            $mime = \mime_content_type($file);
            if ($mime && $mime !== 'application/octet-stream') {
                return $mime;
            }
        }

        $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
        if ($ext === '') {
            $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        }
        $map = [
            'jpg'  => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png'  => 'image/png',
            'gif'  => 'image/gif',
            'webp' => 'image/webp',
            'mp3'  => 'audio/mpeg',
            'm4a'  => 'audio/mp4',
            'aac'  => 'audio/aac',
            'wav'  => 'audio/wav',
            'ogg'  => 'audio/ogg',
            'flac' => 'audio/flac',
            'lrc' => 'text/plain',
            'mp4'  => 'video/mp4',
            'webm' => 'video/webm',
            'mov'  => 'video/quicktime',
            'avi'  => 'video/x-msvideo',
            'mkv'  => 'video/x-matroska',
            'json' => 'application/json',
        ];

        return $map[$ext] ?? 'application/octet-stream';
    }

    private static function validateChatLog($document, $depth = 0)
    {
        if ($depth > 2) {
            return '聊天记录最多嵌套两层';
        }
        if (($document['schema'] ?? '') !== 'qingtan.chatlog' || (int)($document['version'] ?? 0) !== 1) {
            return '不支持的聊天记录格式';
        }
        if (!isset($document['messages']) || !is_array($document['messages'])) {
            return '聊天记录缺少消息列表';
        }
        if (count($document['messages']) > 100) {
            return '一条聊天记录最多包含100条消息';
        }

        foreach ($document['messages'] as $message) {
            if (!is_array($message)) {
                return '聊天记录消息格式错误';
            }
            $type = (string)($message['type'] ?? '');
            if (!in_array($type, ['text', 'image', 'quote', 'chatlog'], true)) {
                return '聊天记录包含未知消息类型';
            }
            if (trim((string)($message['nickname'] ?? '')) === '' || trim((string)($message['sender'] ?? '')) === '') {
                return '聊天记录消息缺少昵称或发送人';
            }
            if ($type === 'image' && trim((string)($message['image_url'] ?? '')) === '') {
                return '图片消息缺少图片地址';
            }
            if ($type === 'quote' && !is_array($message['quote'] ?? null)) {
                return '引用消息缺少引用内容';
            }
            if ($type === 'chatlog') {
                if ($depth >= 2 || !is_array($message['chatlog'] ?? null)) {
                    return '聊天记录最多嵌套两层';
                }
                $nestedError = self::validateChatLog($message['chatlog'], $depth + 1);
                if ($nestedError !== null) {
                    return $nestedError;
                }
            }
        }

        return null;
    }
}
