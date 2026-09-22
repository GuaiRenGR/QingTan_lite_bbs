<?php

namespace App\Controllers;

class FileController
{
    public static function resolve()
    {
        $id = \Request::int('id');

        if ($id <= 0) {
            \Response::json(422, '参数错误');
        }

        $attachments = \Database::table('attachments');

        $row = \Database::fetch(
            "SELECT file_path, file_type, file_name, onedrive_item_id FROM {$attachments} WHERE id = ? AND status = 1 LIMIT 1",
            [$id]
        );

        if (!$row) {
            \Response::json(404, '文件不存在');
        }

        if ($row && !empty($row['file_path'])) {
            $localPath = FX_ROOT . '/' . ltrim((string)$row['file_path'], '/\\');
            if (is_file($localPath)) {
                header('Content-Type: ' . ($row['file_type'] ?: 'application/octet-stream'));
                header('Content-Length: ' . (string)filesize($localPath));
                header('Content-Disposition: inline; filename="' . rawurlencode((string)$row['file_name']) . '"');
                readfile($localPath);
                exit;
            }
        }

        try {
            $service = new \OneDriveService();
            $url = $service->getFileUrl($row['onedrive_item_id']);

            header('Location: ' . $url);
            exit;

        } catch (\Throwable $e) {
            log_error($e->getMessage());

            \Response::json(500, '获取文件失败');
        }
    }
}
