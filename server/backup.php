<?php
/**
 * 数据库备份脚本
 * 仅供服务器管理员通过命令行执行：php /path/to/backup.php
 * 客户端备份请使用管理中心内受鉴权保护的下载功能。
 *
 * 为避免绕过管理员鉴权，本脚本拒绝所有 Web 请求。
 */

// Web backups must go through the authenticated admin API. Keep this legacy
// script available only to administrators with command-line server access.
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    header('Cache-Control: no-store');
    exit('Not Found');
}

error_reporting(E_ALL);
ini_set('display_errors', '1');

// 限制脚本执行时间，大数据库可能需要更长时间
set_time_limit(300);

define('FX_ROOT', __DIR__);

try {
    $dbConfig = require FX_ROOT . '/config/database.php';
} catch (Throwable $e) {
    die("无法加载 config/database.php：数据库配置文件不存在或格式错误。");
}

$host     = $dbConfig['host'] ?? '127.0.0.1';
$port     = $dbConfig['port'] ?? '3306';
$dbname   = $dbConfig['database'] ?? $dbConfig['dbname'] ?? '';
$username = $dbConfig['username'] ?? 'root';
$password = $dbConfig['password'] ?? '';
$charset  = $dbConfig['charset'] ?? 'utf8mb4';
$prefix   = $dbConfig['prefix'] ?? '';

if (empty($dbname)) {
    die("config/database.php 中 dbname 为空，请检查配置。");
}

try {
    $dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset={$charset}";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ]);
} catch (PDOException $e) {
    die("数据库连接失败：" . $e->getMessage());
}

$output = "-- 轻坛数据库备份\n";
$output .= "-- 导出时间：" . date('Y-m-d H:i:s') . "\n";
$output .= "-- 数据库：{$dbname}\n";
$output .= "-- 表前缀：{$prefix}\n\n";
$output .= "SET NAMES {$charset};\n";
$output .= "SET FOREIGN_KEY_CHECKS = 0;\n\n";

// 获取所有表
$tables = $pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
if (empty($tables)) {
    $output .= "-- 数据库中没有任何表\n";
} else {
    foreach ($tables as $table) {
        echo "正在导出表：{$table} ...<br>\n";
        ob_flush();
        flush();

        // 1. DROP TABLE IF EXISTS
        $output .= "DROP TABLE IF EXISTS `{$table}`;\n";

        // 2. CREATE TABLE
        $createStmt = $pdo->query("SHOW CREATE TABLE `{$table}`")->fetch();
        if ($createStmt && isset($createStmt['Create Table'])) {
            $output .= $createStmt['Create Table'] . ";\n\n";
        }

        // 3. INSERT INTO
        $rowCount = $pdo->query("SELECT COUNT(*) FROM `{$table}`")->fetchColumn();
        if ($rowCount > 0) {
            $output .= "INSERT INTO `{$table}` VALUES\n";

            $stmt = $pdo->query("SELECT * FROM `{$table}`");
            $rowIndex = 0;
            while ($row = $stmt->fetch(PDO::FETCH_NUM)) {
                $rowIndex++;
                $escaped = [];
                foreach ($row as $value) {
                    if ($value === null) {
                        $escaped[] = 'NULL';
                    } else {
                        $escaped[] = $pdo->quote((string)$value);
                    }
                }
                $comma = ($rowIndex < $rowCount) ? ',' : ';';
                $output .= "(" . implode(', ', $escaped) . "){$comma}\n";
            }
            $output .= "\n";
        }

        // 每导完一个表就写入一次，避免内存溢出
        file_put_contents(FX_ROOT . '/backup_' . date('Ymd_His') . '_partial.sql', $output, FILE_APPEND);
    }
}

$output .= "SET FOREIGN_KEY_CHECKS = 1;\n";
$output .= "-- 备份完成\n";

// 写入最终文件
$filename = 'backup_' . date('Ymd_His') . '.sql';
file_put_contents(FX_ROOT . '/' . $filename, $output);

// 清理临时文件
$partialFile = FX_ROOT . '/backup_' . date('Ymd_His') . '_partial.sql';
if (file_exists($partialFile)) {
    unlink($partialFile);
}

// 如果通过浏览器访问，显示下载链接
if (php_sapi_name() !== 'cli') {
    echo "<h2>备份完成！</h2>\n";
    echo "<p>文件：<a href='{$filename}'>{$filename}</a></p>\n";
    echo "<p>大小：" . number_format(filesize(FX_ROOT . '/' . $filename) / 1024, 2) . " KB</p>\n";
    echo "<p style='color:red;'>安全提醒：请立即下载并删除 backup.php 和 {$filename}！</p>\n";
} else {
    echo "备份完成：{$filename}\n";
    echo "大小：" . number_format(filesize(FX_ROOT . '/' . $filename) / 1024, 2) . " KB\n";
}
