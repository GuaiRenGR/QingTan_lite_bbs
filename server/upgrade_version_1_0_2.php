<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

try {
    $pdo = Database::pdo();
    $table = Database::table('app_versions');

    $now = date('Y-m-d H:i:s');

    // Check if version already exists
    $existing = Database::fetch(
        "SELECT id FROM {$table} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.0.2', 2]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$table}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all',
                '1.0.2',
                2,
                0,
                '版本 1.0.2',
                '1. 修复发帖后崩溃问题\n2. 恢复首页顶部栏\n3. 修复标签页刷新问题\n4. 下拉刷新改为圆形动画\n5. 移除首页"关注"标签\n6. 使用系统字体\n7. 修复创作中心统计数据\n8. 新增视频播放支持',
                '',
                1,
                $now,
            ]
        );

        echo '<h2>版本 1.0.2+2 已添加</h2>';
    } else {
        echo '<h2>版本 1.0.2+2 已存在</h2>';
    }

    echo '<p>请删除 upgrade_version_1_0_2.php</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
