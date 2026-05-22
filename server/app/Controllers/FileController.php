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
            "SELECT onedrive_item_id FROM {$attachments} WHERE id = ? AND status = 1 LIMIT 1",
            [$id]
        );

        if (!$row || empty($row['onedrive_item_id'])) {
            \Response::json(404, '文件不存在');
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
