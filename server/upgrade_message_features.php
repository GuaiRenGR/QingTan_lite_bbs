<?php

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

header('Content-Type: text/html; charset=utf-8');

try {
    $pdo = Database::pdo();
    $table = Database::table('messages');

    $columns = [];
    $rows = $pdo->query("SHOW COLUMNS FROM {$table}")->fetchAll(PDO::FETCH_ASSOC);
    foreach ($rows as $row) {
        $columns[strtolower((string)$row['Field'])] = true;
    }

    if (!isset($columns['message_type'])) {
        $pdo->exec("ALTER TABLE {$table} ADD COLUMN `message_type` VARCHAR(16) NOT NULL DEFAULT 'text' AFTER `sender_id`");
    }
    if (!isset($columns['image_url'])) {
        $pdo->exec("ALTER TABLE {$table} ADD COLUMN `image_url` TEXT DEFAULT NULL AFTER `content`");
    }
    if (!isset($columns['reply_to_id'])) {
        $pdo->exec("ALTER TABLE {$table} ADD COLUMN `reply_to_id` BIGINT UNSIGNED DEFAULT NULL AFTER `image_url`");
    }

    $indexes = $pdo->query("SHOW INDEX FROM {$table}")->fetchAll(PDO::FETCH_ASSOC);
    $hasReplyIndex = false;
    foreach ($indexes as $index) {
        if (strtolower((string)$index['Key_name']) === 'idx_reply_to') {
            $hasReplyIndex = true;
            break;
        }
    }
    if (!$hasReplyIndex) {
        $pdo->exec("ALTER TABLE {$table} ADD KEY `idx_reply_to` (`reply_to_id`)");
    }

    echo '<h2>升级成功</h2><p>私信图片、引用消息字段已准备完成，请立即删除此脚本。</p>';
} catch (Throwable $e) {
    http_response_code(500);
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
