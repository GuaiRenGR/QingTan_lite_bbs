<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

try {
    $versions = Database::table('app_versions');
    $notes = implode("\n", [
        '1. 我的歌单新增全部播放',
        '2. 工具页新增网易云音乐搜索和播放',
        '3. 支持服务端发现、缓存、测速和手动切换服务器',
        '4. 修复二次编辑帖子时原始图片可能被误删',
        '5. Android 文件选择兼容更多第三方文件管理器',
    ]);
    $existing = Database::fetch(
        "SELECT id FROM {$versions} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.2.0', 26]
    );
    if ($existing) {
        Database::execute(
            "UPDATE {$versions} SET title = ?, content = ?, status = 1 WHERE id = ?",
            ['版本 1.2.0', $notes, $existing['id']]
        );
    } else {
        Database::execute(
            "INSERT INTO {$versions} (`platform`,`version`,`build_number`,`force_update`,`title`,`content`,`download_url`,`status`,`created_at`) VALUES (?,?,?,?,?,?,?,?,?)",
            ['all', '1.2.0', 26, 0, '版本 1.2.0', $notes, '', 1, now()]
        );
    }
    echo '<p>版本 1.2.0+26 已记录</p><h2 style="color:green">升级完成</h2>';
} catch (Throwable $e) {
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
