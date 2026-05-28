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
        ['1.1.2', 2007]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$table}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all',
                '1.1.2',
                2007,
                0,
                '版本 1.1.2',
                implode("\n", [
                    '1. 评论输入框支持插入表情包（B站+QQ表情）',
                    '2. 新增管理中心，管理员可查看、封禁、删除、新增用户',
                    '3. 被封禁用户主页显示封禁标识',
                    '4. 修复深色模式下卡片/文字颜色不适配的问题',
                    '5. 图片查看器底部添加翻页按钮，适配桌面端',
                    '6. 设置中新增HTTPS连接选项（实验性）',
                    '7. 首页切换回时自动无感刷新',
                    '8. 服务端配置目录访问保护',
                ]),
                '',
                1,
                $now,
            ]
        );

        echo '<h2>版本 1.1.2+7 已添加</h2>';
    } else {
        echo '<h2>版本 1.1.2+7 已存在</h2>';
    }

    echo '<p style="color:red;">安全建议：请删除 upgrade_version_1_1_2.php。</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
