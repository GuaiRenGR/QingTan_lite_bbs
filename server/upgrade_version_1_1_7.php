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
        ['1.1.7', 22]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$table}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all',
                '1.1.7',
                22,
                0,
                '版本 1.1.7',
                implode("\n", [
                    '1. 修复上传图片地址异常和图片无法显示',
                    '2. 修复回复、点赞通知全部显示为未读',
                    '3. 音乐播放列表支持退出后保留',
                    '4. 修复管理中心帖子列表为空',
                    '5. 权限管理与铭牌设置拆分',
                    '6. 修复编辑用户时未加载当前铭牌',
                    '7. 支持在隐藏内容中嵌入其他 BBCode',
                    '8. 修复链接、Markdown 等内容的额外空白',
                    '9. 发帖编辑器不再直接渲染图片代码',
                ]),
                '',
                1,
                now(),
            ]
        );
        echo '<p>✓ 版本 1.1.7+22 已记录</p>';
    } else {
        echo '<p>· 版本 1.1.7+22 已存在</p>';
    }

    echo '<h2 style="color:green;">升级完成！</h2>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_version_1_1_7.php。</p>';
} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
