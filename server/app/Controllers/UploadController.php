<?php

namespace App\Controllers;

class UploadController
{
    public static function media()
    {
        $user = \Auth::requireLogin();

        $type = \Request::str('type', 'image');
        if (!in_array($type, ['image', 'music', 'video', 'attachment'], true)) {
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
        } else {
            if ($size > intval($config['max_music_size'])) {
                \Response::json(422, '音乐不能超过 ' . intval($config['max_music_size'] / 1024 / 1024) . 'MB');
            }
        }

        $tmp = $file['tmp_name'];
        $originalName = $file['name'];

        $mime = self::detectMime($tmp, $originalName);

        if ($type === 'image') {
            if (!in_array($mime, [
                'image/jpeg',
                'image/png',
                'image/gif',
                'image/webp',
            ], true)) {
                \Response::json(422, '不支持的图片格式');
            }
        }

        // 附件类型不做 MIME 检查

        if ($type === 'music') {
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
        }

        if ($type === 'video') {
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

            $uploadType = $type === 'image' ? 'images' : ($type === 'video' ? 'video' : ($type === 'attachment' ? 'attachments' : 'music'));

            $result = $service->upload(
                $tmp,
                $originalName,
                $uploadType,
                $mime
            );

            $attachments = \Database::table('attachments');

            $baseUrl = 'http://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

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

            $fileUrl = $baseUrl . '/index.php?route=file/resolve&id=' . \Database::lastInsertId();

            \Database::execute(
                "UPDATE {$attachments} SET file_url = ? WHERE id = ?",
                [$fileUrl, \Database::lastInsertId()]
            );

            \Response::success([
                'id' => (int)\Database::lastInsertId(),
                'type' => $type,
                'url' => $fileUrl,
                'share_url' => $result['share_url'],
                'name' => $result['name'],
                'size' => $result['size'],
                'mime' => $mime,
                'onedrive_item_id' => $result['item_id'],
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
            'mp4'  => 'video/mp4',
            'webm' => 'video/webm',
            'mov'  => 'video/quicktime',
            'avi'  => 'video/x-msvideo',
            'mkv'  => 'video/x-matroska',
        ];

        return $map[$ext] ?? 'application/octet-stream';
    }
}
