<?php

namespace App\Controllers;

class UploadController
{
    public static function media()
    {
        $user = \Auth::requireLogin();

        $type = \Request::str('type', 'image');
        $type = $type === 'music' ? 'music' : 'image';

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
        } else {
            if ($size > intval($config['max_music_size'])) {
                \Response::json(422, '音乐不能超过 ' . intval($config['max_music_size'] / 1024 / 1024) . 'MB');
            }
        }

        $tmp = $file['tmp_name'];
        $originalName = $file['name'];

        $mime = self::detectMime($tmp);

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

        try {
            $service = new \OneDriveService();

            $result = $service->upload(
                $tmp,
                $originalName,
                $type === 'image' ? 'images' : 'music',
                $mime
            );

            $attachments = \Database::table('attachments');

            \Database::execute(
                "INSERT INTO {$attachments}
                (`user_id`,`object_type`,`object_id`,`file_name`,`file_path`,`file_url`,`file_type`,`file_size`,`status`,`created_at`)
                VALUES (?,NULL,NULL,?,?,?,?,?,1,?)",
                [
                    $user['id'],
                    $originalName,
                    $result['path'],
                    $result['file_url'],
                    $mime,
                    $size,
                    now(),
                ]
            );

            \Response::success([
                'id' => (int)\Database::lastInsertId(),
                'type' => $type,
                'url' => $result['file_url'],
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

    private static function detectMime($file)
    {
        if (function_exists('finfo_open')) {
            $finfo = finfo_open(FILEINFO_MIME_TYPE);
            $mime = finfo_file($finfo, $file);
            finfo_close($finfo);

            if ($mime) {
                return $mime;
            }
        }

        return mime_content_type($file) ?: 'application/octet-stream';
    }
}
