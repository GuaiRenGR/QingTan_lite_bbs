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

    $existing = Database::fetch(
        "SELECT id FROM {$table} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.1.1', 6]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$table}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all',
                '1.1.1',
                6,
                0,
                '版本 1.1.1',
                implode("\n", [
                    '1. 管理员可上传附件，帖子中以卡片形式展示',
                    '2. 帖子封面自动生成缩略图，节省流量',
                    '3. 图片管理模式优化，支持插入和删除',
                    '4. 消息页面无感刷新',
                    '5. 修复关于软件界面图标显示问题',
                ]),
                '',
                1,
                $now,
            ]
        );

        echo '<h2>版本 1.1.1+6 已添加</h2>';
    } else {
        echo '<h2>版本 1.1.1+6 已存在</h2>';
    }

    echo '<p style="color:red;">安全建议：请删除 upgrade_version_1_1_1.php。</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
