<?php

define('FX_ROOT', __DIR__);
$config = require FX_ROOT . '/config/database.php';

$dsn = sprintf(
    'mysql:host=%s;port=%s;dbname=%s;charset=%s',
    $config['host'],
    $config['port'],
    $config['database'],
    $config['charset'] ?? 'utf8mb4'
);

$pdo = new PDO($dsn, $config['username'], $config['password'], [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

$prefix = $config['prefix'];

echo '<pre>';
echo "=== 轻坛 v1.1.0 数据迁移 ===\n\n";

// 辅助函数：检查列是否存在
function column_exists($pdo, $table, $column)
{
    $stmt = $pdo->prepare("SHOW COLUMNS FROM {$table} LIKE ?");
    $stmt->execute([$column]);
    return $stmt->fetch() ? true : false;
}

// === 1. posts 表：添加 parent_id 列（评论回复功能） ===
$posts = "`{$prefix}posts`";
if (!column_exists($pdo, $posts, 'parent_id')) {
    try {
        $pdo->exec("ALTER TABLE {$posts} ADD `parent_id` BIGINT UNSIGNED DEFAULT NULL AFTER `user_id`");
        echo "[OK] posts 表添加 parent_id 列\n";
    } catch (Throwable $e) {
        echo "[失败] posts.parent_id: " . $e->getMessage() . "\n";
    }
} else {
    echo "[跳过] posts.parent_id 已存在\n";
}

// === 2. 创建新表 ===
$sqls = [];

$sqls[] = "
CREATE TABLE IF NOT EXISTS `{$prefix}conversations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_a_id` BIGINT UNSIGNED NOT NULL,
  `user_b_id` BIGINT UNSIGNED NOT NULL,
  `last_message_at` DATETIME DEFAULT NULL,
  `last_message_preview` VARCHAR(100) DEFAULT NULL,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pair` (`user_a_id`, `user_b_id`),
  KEY `idx_user_a` (`user_a_id`, `last_message_at`),
  KEY `idx_user_b` (`user_b_id`, `last_message_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
";

$sqls[] = "
CREATE TABLE IF NOT EXISTS `{$prefix}messages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `conversation_id` BIGINT UNSIGNED NOT NULL,
  `sender_id` BIGINT UNSIGNED NOT NULL,
  `content` TEXT NOT NULL,
  `is_read` TINYINT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_conv_time` (`conversation_id`, `created_at`),
  KEY `idx_sender` (`sender_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
";

$sqls[] = "
CREATE TABLE IF NOT EXISTS `{$prefix}notification_settings` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `dnd` TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_type` (`user_id`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
";

foreach ($sqls as $sql) {
    try {
        $pdo->exec($sql);
        echo "[OK] 表创建成功\n";
    } catch (Throwable $e) {
        echo "[跳过] " . $e->getMessage() . "\n";
    }
}

echo "\n迁移完成。建议删除此文件。";
echo '</pre>';
