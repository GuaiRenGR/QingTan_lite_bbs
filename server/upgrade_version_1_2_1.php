<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

function version_1_2_1_column_exists(PDO $pdo, $table, $column)
{
    $stmt = $pdo->prepare("SHOW COLUMNS FROM {$table} LIKE ?");
    $stmt->execute([$column]);
    return (bool)$stmt->fetch();
}
try {
    $pdo = Database::pdo();
    $threads = Database::table('threads');
    $versions = Database::table('app_versions');

    if (!version_1_2_1_column_exists($pdo, $threads, 'sensitive_labels_json')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `sensitive_labels_json` VARCHAR(255) DEFAULT NULL AFTER `images_json`");
    }

    $notes = implode("\n", [
        '1. 恢复兼容性更好的文件选择方式，修复歌词无法上传',
        '2. 图片帖子支持敏感内容标签、警告和屏蔽设置',
        '3. HTTPS 连接默认开启',
        '4. 音乐进度条显示预加载进度',
    ]);
    $existing = Database::fetch(
        "SELECT id FROM {$versions} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.2.1', 27]
    );
    if ($existing) {
        Database::execute(
            "UPDATE {$versions} SET title = ?, content = ?, status = 1 WHERE id = ?",
            ['版本 1.2.1', $notes, $existing['id']]
        );
    } else {
        Database::execute(
            "INSERT INTO {$versions} (`platform`,`version`,`build_number`,`force_update`,`title`,`content`,`download_url`,`status`,`created_at`) VALUES (?,?,?,?,?,?,?,?,?)",
            ['all', '1.2.1', 27, 0, '版本 1.2.1', $notes, '', 1, now()]
        );
    }

    echo '<p>版本 1.2.1+27 已记录</p><h2 style="color:green">升级完成</h2>';
} catch (Throwable $e) {
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
