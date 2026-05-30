<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

try {
    $pdo = Database::pdo();
    $config = require FX_ROOT . '/config/database.php';
    $prefix = $config['prefix'] ?? '';

    $now = date('Y-m-d H:i:s');

    // 1. site_settings 表
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `{$prefix}site_settings` (
            `key` VARCHAR(50) NOT NULL,
            `value` TEXT DEFAULT NULL,
            `updated_at` DATETIME DEFAULT NULL,
            PRIMARY KEY (`key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ");
    echo "<p>✓ site_settings 表已创建</p>";

    // 2. audit_log 表
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `{$prefix}audit_log` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `thread_id` BIGINT UNSIGNED NOT NULL,
            `action` VARCHAR(20) NOT NULL,
            `reviewer_id` BIGINT UNSIGNED NOT NULL,
            `remark` VARCHAR(255) DEFAULT NULL,
            `created_at` DATETIME NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_thread_id` (`thread_id`),
            KEY `idx_reviewer_id` (`reviewer_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ");
    echo "<p>✓ audit_log 表已创建</p>";

    // 3. threads.visibility 列
    $col = $pdo->query("SHOW COLUMNS FROM `{$prefix}threads` LIKE 'visibility'")->fetch();
    if (!$col) {
        $pdo->exec("ALTER TABLE `{$prefix}threads` ADD COLUMN `visibility` VARCHAR(20) NOT NULL DEFAULT 'public' AFTER `status`");
        echo "<p>✓ threads.visibility 列已添加</p>";
    } else {
        echo "<p>· threads.visibility 列已存在</p>";
    }

    // 4. 审核员用户组
    $pdo->prepare("INSERT IGNORE INTO `{$prefix}user_groups`
        (`id`, `name`, `type`, `permissions`, `min_score`, `max_score`, `status`)
        VALUES (50, '审核员', 'moderator', '{\"review\":true}', 0, 999999999, 1)")
        ->execute();
    echo "<p>✓ 审核员用户组 (group_id=50)</p>";

    // 5. 默认设置
    $pdo->prepare("INSERT IGNORE INTO `{$prefix}site_settings` (`key`, `value`, `updated_at`) VALUES (?, ?, ?)")
        ->execute(['require_review', '0', $now]);
    echo "<p>✓ 默认设置 require_review=0</p>";

    // 6. 版本记录
    $table = Database::table('app_versions');
    $existing = Database::fetch(
        "SELECT id FROM {$table} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.1.3', 8]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$table}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all', '1.1.3', 2008, 0, '版本 1.1.3',
                implode("\n", [
                    '1. 帖子新增状态标签（待审核/公开/私有/已锁定）',
                    '2. 新增审核员用户组',
                    '3. 管理中心新增审核功能（可开关）',
                    '4. 管理员可发布私有帖子',
                    '5. 创作中心支持全部/近7天/昨日数据切换',
                    '6. 修复签到连续天数显示错误',
                    '7. 修复消息红点始终显示的问题',
                ]),
                '', 1, $now,
            ]
        );
        echo "<p>✓ 版本 1.1.3+8</p>";
    }

    echo '<h2 style="color:green;">升级完成！</h2>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_version_1_1_3.php。</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
