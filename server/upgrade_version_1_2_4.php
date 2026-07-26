<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

try {
    $versions = Database::table('app_versions');
    $notes = implode("\n", [
        '1. 音乐播放器新增封面动态取色、高级模糊、动态背景与音频律动',
        '2. 新增正在播放模糊封面背景，默认模糊强度 40、背景调暗 0.4',
        '3. 模糊封面背景默认开启，并与默认关闭的动态背景、音频律动互斥',
        '4. 播放、进度和翻页等播放器控件跟随当前音乐封面取色',
        '5. 修复深色播放器背景下歌词、歌曲名、时间和进度条难以辨认',
        '6. 新增六种可持久化主题色，包含 MD3 经典蓝',
        '7. 完善 X 信息流点赞状态、显示更多、观看次数和时间布局',
        '8. 修复设置首帧、Android 导航栏、评论菜单颜色和浏览历史显示',
        '9. 删除音乐与视频自动播放设置项',
    ]);
    $existing = Database::fetch(
        "SELECT id FROM {$versions} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.2.4', 30]
    );
    if ($existing) {
        Database::execute(
            "UPDATE {$versions} SET title = ?, content = ?, status = 1 WHERE id = ?",
            ['版本 1.2.4', $notes, $existing['id']]
        );
    } else {
        Database::execute(
            "INSERT INTO {$versions} (`platform`,`version`,`build_number`,`force_update`,`title`,`content`,`download_url`,`status`,`created_at`) VALUES (?,?,?,?,?,?,?,?,?)",
            ['all', '1.2.4', 30, 0, '版本 1.2.4', $notes, '', 1, now()]
        );
    }

    echo '<p>版本 1.2.4+30 已记录</p><h2 style="color:green">升级完成</h2>';
} catch (Throwable $e) {
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
