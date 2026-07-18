<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

try {
    $table = Database::table('app_versions');
    $existing = Database::fetch(
        "SELECT id FROM {$table} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.1.6', 21]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$table}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all',
                '1.1.6',
                21,
                0,
                '版本 1.1.6',
                implode("\n", [
                    '1. 新增全局音乐播放器、播放列表和上一曲/下一曲',
                    '2. 支持从帖子音乐卡片进入播放器并后台播放',
                    '3. 修复管理员附件上传入口不显示',
                    '4. 修复音乐封面和文件名显示',
                    '5. 修复私信对话页面渲染失败',
                    '6. 修复首页私信未读数量角标',
                    '7. 修复帖子分享链接',
                ]),
                '',
                1,
                now(),
            ]
        );
        echo '<p>✓ 版本 1.1.6+21 已记录</p>';
    } else {
        echo '<p>· 版本 1.1.6+21 已存在</p>';
    }

    echo '<h2 style="color:green;">升级完成！</h2>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_version_1_1_6.php。</p>';
} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
