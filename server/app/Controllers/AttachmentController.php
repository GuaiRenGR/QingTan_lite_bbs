<?php

namespace App\Controllers;

class AttachmentController
{
    public static function delete()
    {
        $user = \Auth::requireLogin();

        $id = \Request::int('id');
        $url = \Request::str('url');

        if ($id <= 0 && empty($url)) {
            \Response::json(422, '参数错误');
        }

        $attachments = \Database::table('attachments');

        if ($id > 0) {
            $row = \Database::fetch(
                "SELECT * FROM {$attachments} WHERE id = ? AND user_id = ? AND status = 1 LIMIT 1",
                [$id, $user['id']]
            );
        } else {
            $row = \Database::fetch(
                "SELECT * FROM {$attachments} WHERE file_url = ? AND user_id = ? AND status = 1 LIMIT 1",
                [$url, $user['id']]
            );
        }

        if (!$row) {
            \Response::json(404, '附件不存在');
        }

        if (!empty($row['onedrive_item_id'])) {
            try {
                $service = new \OneDriveService();
                $service->deleteFile($row['onedrive_item_id']);
            } catch (\Throwable $e) {
                log_error('OneDrive 删除失败 [' . $row['onedrive_item_id'] . ']: ' . $e->getMessage());
            }
        }

        \Database::execute(
            "UPDATE {$attachments} SET status = 0 WHERE id = ?",
            [$row['id']]
        );

        \Response::success(null, '已删除');
    }

    public static function info()
    {
        $id = \Request::int('id');

        if ($id <= 0) {
            \Response::json(422, '参数错误');
        }

        $attachments = \Database::table('attachments');

        $row = \Database::fetch(
            "SELECT id, file_name, file_size, file_type, file_url FROM {$attachments} WHERE id = ? AND status = 1 LIMIT 1",
            [$id]
        );

        if (!$row) {
            \Response::json(404, '附件不存在');
        }

        \Response::success([
            'id' => (int)$row['id'],
            'name' => $row['file_name'],
            'size' => (int)$row['file_size'],
            'type' => $row['file_type'],
            'url' => $row['file_url'],
        ]);
    }
}
