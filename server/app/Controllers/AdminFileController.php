<?php

namespace App\Controllers;

class AdminFileController
{
    private static function requireAdmin()
    {
        $user = \Auth::requireLogin();
        if (!\SiteSetting::isAdmin($user)) {
            \Response::json(403, '无管理员权限');
        }
        return $user;
    }

    public static function index()
    {
        self::requireAdmin();

        $folderId = max(0, \Request::int('folder_id'));
        $attachments = \Database::table('attachments');
        $folders = \Database::table('attachment_folders');
        $users = \Database::table('users');

        if ($folderId > 0) {
            $folder = \Database::fetch(
                "SELECT id FROM {$folders} WHERE id = ? AND status = 1 LIMIT 1",
                [$folderId]
            );
            if (!$folder) {
                \Response::json(404, '文件夹不存在');
            }
        }

        $folderRows = \Database::fetchAll(
            "SELECT f.id, f.name, f.created_at, COUNT(a.id) AS file_count
             FROM {$folders} f
             LEFT JOIN {$attachments} a
               ON a.folder_id = f.id
              AND a.status = 1
              AND (a.file_type IS NULL OR a.file_type NOT LIKE 'image/%')
              AND a.file_path NOT LIKE '%/images/%'
             WHERE f.status = 1
             GROUP BY f.id, f.name, f.created_at
             ORDER BY f.name ASC, f.id ASC"
        );

        $fileRows = \Database::fetchAll(
            "SELECT a.id, a.folder_id, a.user_id, a.file_name, a.file_url,
                    a.file_type, a.file_size, a.created_at,
                    COALESCE(u.nickname, u.username, '用户') AS uploader_name
             FROM {$attachments} a
             LEFT JOIN {$users} u ON u.id = a.user_id
             WHERE a.status = 1
               AND COALESCE(a.folder_id, 0) = ?
               AND (a.file_type IS NULL OR a.file_type NOT LIKE 'image/%')
               AND a.file_path NOT LIKE '%/images/%'
             ORDER BY a.created_at DESC, a.id DESC
             LIMIT 500",
            [$folderId]
        );

        $folderList = array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'name' => $row['name'],
                'file_count' => (int)$row['file_count'],
                'created_at' => $row['created_at'],
            ];
        }, $folderRows);

        $fileList = array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'folder_id' => (int)($row['folder_id'] ?? 0),
                'user_id' => (int)$row['user_id'],
                'name' => $row['file_name'],
                'url' => $row['file_url'],
                'type' => $row['file_type'] ?? '',
                'size' => (int)$row['file_size'],
                'uploader_name' => $row['uploader_name'],
                'created_at' => $row['created_at'],
            ];
        }, $fileRows);

        \Response::success([
            'folder_id' => $folderId,
            'folders' => $folderList,
            'files' => $fileList,
        ]);
    }

    public static function createFolder()
    {
        $user = self::requireAdmin();
        $name = trim(\Request::str('name'));

        if ($name === '' || mb_strlen($name, 'UTF-8') > 50) {
            \Response::json(422, '文件夹名称需为 1-50 个字符');
        }
        if (preg_match('/[\\\/\x00-\x1F]/u', $name)) {
            \Response::json(422, '文件夹名称包含无效字符');
        }

        $folders = \Database::table('attachment_folders');
        $existing = \Database::fetch(
            "SELECT id FROM {$folders} WHERE name = ? AND status = 1 LIMIT 1",
            [$name]
        );
        if ($existing) {
            \Response::json(409, '同名文件夹已存在');
        }

        \Database::execute(
            "INSERT INTO {$folders} (`name`, `created_by`, `status`, `created_at`)
             VALUES (?, ?, 1, ?)",
            [$name, $user['id'], now()]
        );
        $folderId = (int)\Database::lastInsertId();
        $row = \Database::fetch("SELECT * FROM {$folders} WHERE id = ?", [$folderId]);
        record_sync_operation('attachment_folders', $folderId, 'insert', $row);

        \Response::success([
            'id' => $folderId,
            'name' => $name,
        ], '文件夹已创建');
    }

    public static function move()
    {
        self::requireAdmin();

        $id = \Request::int('id');
        $folderId = max(0, \Request::int('folder_id'));
        if ($id <= 0) {
            \Response::json(422, '附件 ID 错误');
        }

        $attachments = \Database::table('attachments');
        $folders = \Database::table('attachment_folders');

        $row = \Database::fetch(
            "SELECT * FROM {$attachments}
             WHERE id = ? AND status = 1
               AND (file_type IS NULL OR file_type NOT LIKE 'image/%')
               AND file_path NOT LIKE '%/images/%'
             LIMIT 1",
            [$id]
        );
        if (!$row) {
            \Response::json(404, '附件不存在');
        }

        if ($folderId > 0) {
            $folder = \Database::fetch(
                "SELECT id FROM {$folders} WHERE id = ? AND status = 1 LIMIT 1",
                [$folderId]
            );
            if (!$folder) {
                \Response::json(404, '目标文件夹不存在');
            }
        }

        \Database::execute(
            "UPDATE {$attachments} SET folder_id = ? WHERE id = ?",
            [$folderId > 0 ? $folderId : null, $id]
        );
        $updated = \Database::fetch("SELECT * FROM {$attachments} WHERE id = ?", [$id]);
        record_sync_operation('attachments', $id, 'update', $updated, $row);

        \Response::success(null, '附件已移动');
    }

    public static function delete()
    {
        self::requireAdmin();

        $id = \Request::int('id');
        if ($id <= 0) {
            \Response::json(422, '附件 ID 错误');
        }

        $attachments = \Database::table('attachments');
        $row = \Database::fetch(
            "SELECT * FROM {$attachments}
             WHERE id = ? AND status = 1
               AND (file_type IS NULL OR file_type NOT LIKE 'image/%')
               AND file_path NOT LIKE '%/images/%'
             LIMIT 1",
            [$id]
        );
        if (!$row) {
            \Response::json(404, '附件不存在');
        }

        if (!empty($row['onedrive_item_id'])) {
            $service = new \OneDriveService();
            $service->deleteFile($row['onedrive_item_id']);
        }

        \Database::execute(
            "UPDATE {$attachments} SET status = 0 WHERE id = ?",
            [$id]
        );
        record_sync_operation('attachments', $id, 'delete', null, $row);

        \Response::success(null, '附件已删除');
    }
}
