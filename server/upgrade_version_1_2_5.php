<?php

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

header('Content-Type: text/html; charset=utf-8');

function version_1_2_5_column_exists(PDO $pdo, $tableName, $column)
{
    $stmt = $pdo->prepare("SHOW COLUMNS FROM {$tableName} LIKE ?");
    $stmt->execute([$column]);
    return $stmt->fetch() !== false;
}

try {
    $pdo = Database::pdo();

    $uploadController = FX_ROOT . '/app/Controllers/UploadController.php';
    $uploadControllerSource = file_exists($uploadController)
        ? (string)file_get_contents($uploadController)
        : '';
    if (strpos($uploadControllerSource, "'chatlog'") === false) {
        throw new RuntimeException('请先完整覆盖新版 server 文件，再执行升级脚本。');
    }

    $attachments = Database::table('attachments');
    $attachmentColumns = [
        'object_type' => "ADD `object_type` VARCHAR(30) DEFAULT NULL AFTER `user_id`",
        'object_id' => "ADD `object_id` BIGINT UNSIGNED DEFAULT NULL AFTER `object_type`",
        'file_path' => "ADD `file_path` VARCHAR(1000) DEFAULT NULL AFTER `file_name`",
        'file_url' => "ADD `file_url` VARCHAR(1000) NOT NULL DEFAULT '' AFTER `file_path`",
        'file_type' => "ADD `file_type` VARCHAR(100) DEFAULT NULL AFTER `file_url`",
        'file_size' => "ADD `file_size` BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER `file_type`",
        'onedrive_item_id' => "ADD `onedrive_item_id` VARCHAR(255) DEFAULT NULL AFTER `file_size`",
    ];
    foreach ($attachmentColumns as $column => $sql) {
        if (!version_1_2_5_column_exists($pdo, $attachments, $column)) {
            $pdo->exec("ALTER TABLE {$attachments} {$sql}");
            echo '<p>✓ attachments.' . htmlspecialchars($column, ENT_QUOTES, 'UTF-8') . ' 已添加</p>';
        }
    }

    $indexStatement = $pdo->prepare("SHOW INDEX FROM {$attachments} WHERE Key_name = ?");
    $indexStatement->execute(['idx_object']);
    if (!$indexStatement->fetch()) {
        $pdo->exec("ALTER TABLE {$attachments} ADD KEY `idx_object` (`object_type`, `object_id`)");
        echo '<p>✓ attachments.idx_object 索引已添加</p>';
    }

    $versions = Database::table('app_versions');
    $notes = implode("\n", [
        '1. 新增可编辑的聊天记录 BBCode，聊天记录 JSON 文件保存至 OneDrive',
        '2. 支持文字、图片、引用消息和两层聊天记录嵌套，单条记录最多 100 条消息',
        '3. 聊天记录使用可展开的 QQ 风格卡片显示，内容不参与帖子封面生成',
        '4. 服务端增加聊天记录 JSON 格式、消息类型、数量和嵌套层级校验',
    ]);
    $existing = Database::fetch(
        "SELECT id FROM {$versions} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.2.5', 31]
    );
    if ($existing) {
        Database::execute(
            "UPDATE {$versions} SET title = ?, content = ?, status = 1 WHERE id = ?",
            ['版本 1.2.5', $notes, $existing['id']]
        );
    } else {
        Database::execute(
            "INSERT INTO {$versions} (`platform`,`version`,`build_number`,`force_update`,`title`,`content`,`download_url`,`status`,`created_at`) VALUES (?,?,?,?,?,?,?,?,?)",
            ['all', '1.2.5', 31, 0, '版本 1.2.5', $notes, '', 1, now()]
        );
    }

    echo '<h2>升级成功</h2><p>聊天记录附件字段和版本记录已完成升级。请立即删除此升级脚本。</p>';
} catch (Throwable $e) {
    http_response_code(500);
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
