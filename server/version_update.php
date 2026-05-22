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
echo "=== 轻坛 版本更新 ===\n\n";

$version = '1.1.0';
$buildNumber = 2005;

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
        "1. 新增消息通知系统（回复、@我、点赞、系统通知）\n2. 新增用户私信功能\n3. 新增评论点赞和回复评论\n4. 支持 Android/Windows 原生系统通知\n5. 通知免打扰设置\n6. 个人主页添加私信按钮",
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
