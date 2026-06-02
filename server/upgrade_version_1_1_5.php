<?php
/**
 * 升级脚本 v1.1.5
 * - users 表添加 permissions 字段（单独权限覆盖）
 */

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/Database.php';

$configFile = FX_ROOT . '/config/database.php';
if (!file_exists($configFile)) {
    die('错误：数据库配置文件不存在，请先运行 install.php');
}

$config = require $configFile;
$prefix = $config['prefix'] ?? '';
$host = $config['host'] ?? '127.0.0.1';
$port = $config['port'] ?? 3306;
$dbname = $config['database'] ?? '';
$user = $config['username'] ?? '';
$pass = $config['password'] ?? '';

try {
    $dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset=utf8mb4";
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]);

    // 检查 permissions 列是否已存在
    $stmt = $pdo->prepare("SHOW COLUMNS FROM `{$prefix}users` LIKE 'permissions'");
    $stmt->execute();
    $exists = $stmt->fetch();

    if (!$exists) {
        $pdo->exec("ALTER TABLE `{$prefix}users` ADD COLUMN `permissions` TEXT DEFAULT NULL AFTER `verify_level`");
        echo "✓ users 表已添加 permissions 字段\n";
    } else {
        echo "⊘ users 表 permissions 字段已存在，跳过\n";
    }

    echo "升级完成！\n";
} catch (Throwable $e) {
    die("升级失败：" . $e->getMessage() . "\n");
}
