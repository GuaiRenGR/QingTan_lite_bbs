<?php

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

header('Content-Type: text/html; charset=utf-8');

try {
    $pdo = Database::pdo();
    $table = Database::table('notification_reads');
    $pdo->exec("CREATE TABLE IF NOT EXISTS {$table} (
        `notification_id` BIGINT UNSIGNED NOT NULL,
        `user_id` BIGINT UNSIGNED NOT NULL,
        `is_read` TINYINT NOT NULL DEFAULT 1,
        `read_at` DATETIME NOT NULL,
        PRIMARY KEY (`notification_id`, `user_id`),
        KEY `idx_notification_reads_user` (`user_id`, `read_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    echo '<h2>升级成功</h2><p>系统通知广播和已读记录表已准备完成，请立即删除此脚本。</p>';
} catch (Throwable $e) {
    http_response_code(500);
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
