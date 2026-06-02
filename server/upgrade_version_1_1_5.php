<?php
/**
 * 升级脚本 v1.1.5
 * - users 表添加 permissions 字段（单独权限覆盖）
 * - users 表添加 badge_name / badge_color / verify_level（兼容旧版升级）
 * - 记录版本号
 */

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

    // 1. users.permissions 列
    $col = $pdo->query("SHOW COLUMNS FROM `{$prefix}users` LIKE 'permissions'")->fetch();
    if (!$col) {
        $pdo->exec("ALTER TABLE `{$prefix}users` ADD COLUMN `permissions` TEXT DEFAULT NULL AFTER `verify_level`");
        echo "<p>✓ users.permissions 列已添加</p>";
    } else {
        echo "<p>· users.permissions 列已存在</p>";
    }

    // 2. users.badge_name 列（兼容从旧版直接升级）
    $col = $pdo->query("SHOW COLUMNS FROM `{$prefix}users` LIKE 'badge_name'")->fetch();
    if (!$col) {
        $pdo->exec("ALTER TABLE `{$prefix}users` ADD COLUMN `badge_name` VARCHAR(10) DEFAULT NULL AFTER `bio`");
        echo "<p>✓ users.badge_name 列已添加</p>";
    } else {
        echo "<p>· users.badge_name 列已存在</p>";
    }

    // 3. users.badge_color 列
    $col = $pdo->query("SHOW COLUMNS FROM `{$prefix}users` LIKE 'badge_color'")->fetch();
    if (!$col) {
        $pdo->exec("ALTER TABLE `{$prefix}users` ADD COLUMN `badge_color` VARCHAR(20) DEFAULT NULL AFTER `badge_name`");
        echo "<p>✓ users.badge_color 列已添加</p>";
    } else {
        echo "<p>· users.badge_color 列已存在</p>";
    }

    // 4. users.verify_level 列
    $col = $pdo->query("SHOW COLUMNS FROM `{$prefix}users` LIKE 'verify_level'")->fetch();
    if (!$col) {
        $pdo->exec("ALTER TABLE `{$prefix}users` ADD COLUMN `verify_level` TINYINT NOT NULL DEFAULT 0 AFTER `badge_color`");
        echo "<p>✓ users.verify_level 列已添加</p>";
    } else {
        echo "<p>· users.verify_level 列已存在</p>";
    }

    // 5. 版本记录
    $table = Database::table('app_versions');
    $existing = Database::fetch(
        "SELECT id FROM {$table} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.1.5', 10]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$table}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all', '1.1.5', 10, 0, '版本 1.1.5',
                implode("\n", [
                    '1. 下载管理新增"打开文件夹"功能',
                    '2. 登录设备显示真实设备名（需重新登录）',
                    '3. 底部导航"发现"改为"工具"页',
                    '4. 管理中心：用户权限编辑、帖子管理',
                    '5. B 站风格视频播放器（手势控制）',
                    '6. Toast 新增"查看下载"按钮',
                    '7. 检查更新自动适配平台下载',
                ]),
                '', 1, $now,
            ]
        );
        echo "<p>✓ 版本 1.1.5+10 已记录</p>";
    } else {
        echo "<p>· 版本 1.1.5+10 已存在</p>";
    }

    echo '<h2 style="color:green;">升级完成！</h2>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_version_1_1_5.php。</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
