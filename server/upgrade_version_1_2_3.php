<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

try {
    $versions = Database::table('app_versions');
    $notes = implode("\n", [
        '1. 完善 X 信息流用户名、头像、展开文本、时间显示及帖子交互',
        '2. 音乐使用持久播放缓存，拖动后缓存进度不再回退',
        '3. 修复拖动音乐进度后歌词无法继续自动滚动',
        '4. 软件名称统一为“轻坛”',
    ]);
    $existing = Database::fetch(
        "SELECT id FROM {$versions} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.2.3', 29]
    );
    if ($existing) {
        Database::execute(
            "UPDATE {$versions} SET title = ?, content = ?, status = 1 WHERE id = ?",
            ['版本 1.2.3', $notes, $existing['id']]
        );
    } else {
        Database::execute(
            "INSERT INTO {$versions} (`platform`,`version`,`build_number`,`force_update`,`title`,`content`,`download_url`,`status`,`created_at`) VALUES (?,?,?,?,?,?,?,?,?)",
            ['all', '1.2.3', 29, 0, '版本 1.2.3', $notes, '', 1, now()]
        );
    }

    echo '<p>版本 1.2.3+29 已记录</p><h2 style="color:green">升级完成</h2>';
} catch (Throwable $e) {
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
