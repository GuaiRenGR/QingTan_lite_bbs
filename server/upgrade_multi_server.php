<?php
/**
 * 升级脚本：多服务器支持
 * - 创建 sync_operation_log 表（操作日志）
 * - 创建 sync_server_status 表（服务器状态）
 * - 创建 id_sequences 表（ID 生成序列）
 * - 创建 servers.php 默认配置
 * - 记录版本号
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

try {
    $pdo = Database::pdo();
    $config = require FX_ROOT . '/config/database.php';
    $prefix = $config['prefix'] ?? '';

    $now = date('Y-m-d H:i:s');

    // 1. sync_operation_log 表
    $tableExists = $pdo->query("SHOW TABLES LIKE '{$prefix}sync_operation_log'")->fetch();
    if (!$tableExists) {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS `{$prefix}sync_operation_log` (
              `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
              `server_id` INT UNSIGNED NOT NULL COMMENT '来源服务器ID',
              `src_op_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '来源服务器的日志ID',
              `op_type` VARCHAR(16) NOT NULL COMMENT 'insert | update | delete',
              `table_name` VARCHAR(64) NOT NULL COMMENT '表名',
              `row_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '受影响行的主键ID',
              `row_data` MEDIUMTEXT COMMENT '行数据的 JSON 快照',
              `old_data` MEDIUMTEXT COMMENT '更新前的旧数据',
              `created_at` DATETIME NOT NULL,
              `synced_at` DATETIME DEFAULT NULL,
              PRIMARY KEY (`id`),
              KEY `idx_server_op` (`server_id`, `src_op_id`),
              KEY `idx_synced` (`synced_at`),
              KEY `idx_created` (`created_at`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        echo "<p>✓ sync_operation_log 表已创建</p>";
    } else {
        echo "<p>· sync_operation_log 表已存在</p>";
    }

    // 2. sync_server_status 表
    $tableExists = $pdo->query("SHOW TABLES LIKE '{$prefix}sync_server_status'")->fetch();
    if (!$tableExists) {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS `{$prefix}sync_server_status` (
              `server_id` INT UNSIGNED NOT NULL,
              `server_url` VARCHAR(255) NOT NULL,
              `server_name` VARCHAR(64) NOT NULL,
              `last_ping_at` DATETIME DEFAULT NULL,
              `last_sync_at` DATETIME DEFAULT NULL,
              `last_sync_op_id` BIGINT UNSIGNED DEFAULT 0,
              `status` VARCHAR(16) NOT NULL DEFAULT 'active',
              `version` VARCHAR(32) DEFAULT NULL,
              `created_at` DATETIME NOT NULL,
              `updated_at` DATETIME NOT NULL,
              PRIMARY KEY (`server_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        echo "<p>✓ sync_server_status 表已创建</p>";
    } else {
        echo "<p>· sync_server_status 表已存在</p>";
    }

    // 3. id_sequences 表
    $tableExists = $pdo->query("SHOW TABLES LIKE '{$prefix}id_sequences'")->fetch();
    if (!$tableExists) {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS `{$prefix}id_sequences` (
              `table_name` VARCHAR(64) NOT NULL,
              `next_id` BIGINT UNSIGNED NOT NULL DEFAULT 1,
              PRIMARY KEY (`table_name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        // 为主表预填初始 ID 序列
        $mainTables = ['threads', 'posts', 'users', 'forums', 'tags', 'messages'];
        $pdo->exec("BEGIN");
        $stmt = $pdo->prepare("INSERT IGNORE INTO `{$prefix}id_sequences` (`table_name`, `next_id`) VALUES (?, 1)");
        foreach ($mainTables as $t) {
            $maxId = $pdo->query("SELECT COALESCE(MAX(id), 0) + 1 FROM `{$prefix}{$t}`")->fetchColumn();
            $pdo->exec("INSERT INTO `{$prefix}id_sequences` (`table_name`, `next_id`) VALUES ('{$t}', {$maxId}) ON DUPLICATE KEY UPDATE `next_id` = GREATEST(`next_id`, {$maxId})");
        }
        $pdo->exec("COMMIT");
        echo "<p>✓ id_sequences 表已创建，主表 ID 序列已初始化</p>";
    } else {
        echo "<p>· id_sequences 表已存在</p>";
    }

    // 4. 生成 servers.php 配置（如果不存在）
    $serversConfigFile = FX_ROOT . '/config/servers.php';
    if (!file_exists($serversConfigFile)) {
        $phpSelf = $_SERVER['HTTP_HOST'] ?? 'localhost';
        $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        $defaultUrl = $protocol . '://' . $phpSelf;
        $configContent = "<?php\n/**\n * 多服务器配置\n * 每台服务器部署时需根据自身身份修改此文件\n */\n" .
            "\$serverId = 1;\n\n" .
            "return [\n" .
            "    'server_id'   => \$serverId,\n" .
            "    'server_name' => '主服务器',\n\n" .
            "    'server_url' => '{$defaultUrl}',\n\n" .
            "    'servers' => [\n" .
            "        ['id' => 1, 'name' => '主服务器',   'url' => '{$defaultUrl}', 'weight' => 10],\n" .
            "        ['id' => 2, 'name' => '备用服务器', 'url' => 'http://s2.example.com',    'weight' => 5],\n" .
            "        ['id' => 3, 'name' => '备用服务器', 'url' => 'http://s3.example.com',    'weight' => 5],\n" .
            "    ],\n\n" .
            "    'sync' => [\n" .
            "        'sync_token'  => '" . bin2hex(random_bytes(16)) . "',\n" .
            "        'batch_size'  => 100,\n" .
            "        'retry_times' => 3,\n" .
            "        'timeout'     => 30,\n" .
            "        'sample_rate' => 10,\n" .
            "    ],\n" .
            "];\n";
        file_put_contents($serversConfigFile, $configContent);
        echo "<p>✓ config/servers.php 已生成（server_id=1，请根据实际情况修改）</p>";
    } else {
        echo "<p>· config/servers.php 已存在，跳过</p>";
    }

    // 5. 版本记录
    $table = Database::table('app_versions');
    $existing = Database::fetch(
        "SELECT id FROM {$table} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.2.0', 20]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$table}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all', '1.2.0', 20, 0, '版本 1.2.0',
                implode("\n", [
                    '1. 多服务器部署支持（故障转移 / 负载分担）',
                    '2. 服务器健康检查与自动切换',
                    '3. 写操作队列，离线请求自动重试',
                    '4. 操作日志同步机制',
                ]),
                '', 1, $now,
            ]
        );
        echo "<p>✓ 版本 1.2.0+20 已记录</p>";
    } else {
        echo "<p>· 版本 1.2.0+20 已存在</p>";
    }

    echo '<h2 style="color:green;">多服务器升级完成！</h2>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_multi_server.php。</p>';
    echo '<p>下一步：修改 config/servers.php 中的服务器列表与 sync_token，然后在各服务器上部署。</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
