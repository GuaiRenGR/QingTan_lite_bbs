<?php

define('FX_ROOT', __DIR__);
$config = require FX_ROOT . '/config/database.php';

$dsn = sprintf(
    'mysql:host=%s;port=%s;dbname=%s;charset=%s',
    $config['host'],
    $config['port'],
    $config['database'],
    $config['charset'] ?? 'utf8mb4'
);

$pdo = new PDO($dsn, $config['username'], $config['password'], [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

$prefix = $config['prefix'];

echo '<pre>';
echo "=== ForumX Lite 版本更新 ===\n\n";

$version = '1.0.4';
$buildNumber = 4;

try {
    $stmt = $pdo->prepare(
        "INSERT INTO `{$prefix}app_versions`
         (`platform`, `version`, `build_number`, `title`, `content`, `download_url`, `force_update`, `status`, `created_at`)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );

    $stmt->execute([
        'all',
        $version,
        $buildNumber,
        '发现新版本 v' . $version,
        '1. 新增头像上传功能\n2. 修正编辑资料入口\n3. 修复图片模式帖子无限长\n4. 添加网络权限修复无法联网\n5. 过滤帖子摘要中的编辑器标签',
        '',
        0,
        1,
        date('Y-m-d H:i:s'),
    ]);

    echo "[OK] 已添加版本 {$version} (build {$buildNumber})\n";
} catch (Throwable $e) {
    echo "[失败] " . $e->getMessage() . "\n";
}

echo "\n更新完成。建议删除此文件。";
echo '</pre>';
