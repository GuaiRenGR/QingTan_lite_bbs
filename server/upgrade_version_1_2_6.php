<?php

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

header('Content-Type: text/html; charset=utf-8');

function v126ColumnExists(PDO $pdo, $table, $column)
{
    $stmt = $pdo->prepare("SHOW COLUMNS FROM {$table} LIKE ?");
    $stmt->execute([$column]);
    return (bool)$stmt->fetch(PDO::FETCH_ASSOC);
}

function v126IndexExists(PDO $pdo, $table, $index)
{
    $stmt = $pdo->prepare("SHOW INDEX FROM {$table} WHERE Key_name = ?");
    $stmt->execute([$index]);
    return (bool)$stmt->fetch(PDO::FETCH_ASSOC);
}

try {
    $pdo = Database::pdo();

    $messages = Database::table('messages');
    if (!v126ColumnExists($pdo, $messages, 'message_type')) {
        $pdo->exec("ALTER TABLE {$messages} ADD `message_type` VARCHAR(16) NOT NULL DEFAULT 'text' AFTER `sender_id`");
    }
    if (!v126ColumnExists($pdo, $messages, 'image_url')) {
        $pdo->exec("ALTER TABLE {$messages} ADD `image_url` TEXT DEFAULT NULL AFTER `content`");
    }
    if (!v126ColumnExists($pdo, $messages, 'reply_to_id')) {
        $pdo->exec("ALTER TABLE {$messages} ADD `reply_to_id` BIGINT UNSIGNED DEFAULT NULL AFTER `image_url`");
    }
    if (!v126IndexExists($pdo, $messages, 'idx_reply_to')) {
        $pdo->exec("ALTER TABLE {$messages} ADD KEY `idx_reply_to` (`reply_to_id`)");
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
        if (!v126ColumnExists($pdo, $attachments, $column)) $pdo->exec("ALTER TABLE {$attachments} {$sql}");
    }
    if (!v126IndexExists($pdo, $attachments, 'idx_object')) {
        $pdo->exec("ALTER TABLE {$attachments} ADD KEY `idx_object` (`object_type`, `object_id`)");
    }

    $reads = Database::table('notification_reads');
    $pdo->exec("CREATE TABLE IF NOT EXISTS {$reads} (
        `notification_id` BIGINT UNSIGNED NOT NULL,
        `user_id` BIGINT UNSIGNED NOT NULL,
        `is_read` TINYINT NOT NULL DEFAULT 1,
        `read_at` DATETIME NOT NULL,
        PRIMARY KEY (`notification_id`, `user_id`),
        KEY `idx_notification_reads_user` (`user_id`, `read_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $playlists = Database::table('music_playlists');
    if (!v126ColumnExists($pdo, $playlists, 'public_id')) {
        $pdo->exec("ALTER TABLE {$playlists} ADD `public_id` INT UNSIGNED DEFAULT NULL AFTER `default_key`");
    }
    if (!v126IndexExists($pdo, $playlists, 'uk_public_id')) {
        $pdo->exec("ALTER TABLE {$playlists} ADD UNIQUE KEY `uk_public_id` (`public_id`)");
    }
    $playlistRows = $pdo->query("SELECT id FROM {$playlists} WHERE public_id IS NULL OR public_id = 0")->fetchAll(PDO::FETCH_ASSOC);
    foreach ($playlistRows as $row) {
        do {
            $publicId = random_int(100000000, 999999999);
            $check = $pdo->prepare("SELECT id FROM {$playlists} WHERE public_id = ? LIMIT 1");
            $check->execute([$publicId]);
        } while ($check->fetch(PDO::FETCH_ASSOC));
        $update = $pdo->prepare("UPDATE {$playlists} SET public_id = ? WHERE id = ?");
        $update->execute([$publicId, $row['id']]);
    }

    $versions = Database::table('app_versions');
    $notes = implode("\n", [
        '1. 音乐播放器支持网易云音乐双语歌词、搜索封面加载和多歌单，保留原有“我喜欢”歌单。',
        '2. 新增上传进度、上传管理、暂停/继续续传；管理员可选择直传 OneDrive 或服务器上传。',
        '3. 管理中心新增数据库备份下载、AI 审核设置、小红书大字报生成器和系统通知发布。',
        '4. 私信支持时间、表情、图片、长按引用；聊天图片与帖子文件分开保存。',
        '5. 评论回复最多折叠一层，修复锁定帖子可见、评论表情光标错位等问题。',
    ]);
    $existing = Database::fetch("SELECT id FROM {$versions} WHERE version = ? AND build_number = ? LIMIT 1", ['1.2.6', 32]);
    if ($existing) {
        Database::execute("UPDATE {$versions} SET title = ?, content = ?, status = 1 WHERE id = ?", ['版本 1.2.6', $notes, $existing['id']]);
    } else {
        Database::execute("INSERT INTO {$versions} (`platform`,`version`,`build_number`,`force_update`,`title`,`content`,`download_url`,`status`,`created_at`) VALUES (?,?,?,?,?,?,?,?,?)", ['all', '1.2.6', 32, 0, '版本 1.2.6', $notes, '', 1, now()]);
    }

    echo '<h2>升级成功</h2><p>1.2.6 服务端字段、歌单公开 ID、通知已读表和版本记录已准备完成，请立即删除此升级脚本。</p>';
} catch (Throwable $e) {
    http_response_code(500);
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
