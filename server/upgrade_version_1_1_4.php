<?php

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

    // 1. threads.dv_code 列
    $col = $pdo->query("SHOW COLUMNS FROM `{$prefix}threads` LIKE 'dv_code'")->fetch();
    if (!$col) {
        $pdo->exec("ALTER TABLE `{$prefix}threads` ADD COLUMN `dv_code` VARCHAR(12) DEFAULT NULL AFTER `id`");
        $pdo->exec("CREATE UNIQUE INDEX `idx_dv_code` ON `{$prefix}threads` (`dv_code`)");
        echo "<p>✓ threads.dv_code 列已添加（含唯一索引）</p>";

        // 为已有帖子生成 DV 码
        require_once FX_ROOT . '/core/DvCode.php';
        $rows = $pdo->query("SELECT id FROM `{$prefix}threads` WHERE dv_code IS NULL")->fetchAll(PDO::FETCH_COLUMN);
        $stmt = $pdo->prepare("UPDATE `{$prefix}threads` SET dv_code = ? WHERE id = ?");
        foreach ($rows as $id) {
            $stmt->execute([\DvCode::encode((int)$id), $id]);
        }
        echo "<p>✓ 已为 " . count($rows) . " 个历史帖子生成 DV 码</p>";
    } else {
        echo "<p>· threads.dv_code 列已存在</p>";
    }

    // 2. 版本记录
    $table = Database::table('app_versions');
    $existing = Database::fetch(
        "SELECT id FROM {$table} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.1.4', 9]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$table}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all', '1.1.4', 2009, 0, '版本 1.1.4',
                implode("\n", [
                    '1. 用户名不再允许中文，仅支持字母、数字、下划线',
                    '2. 注册页面新增昵称输入（可选）',
                    '3. 帖子新增 DV 号唯一标识',
                ]),
                '', 1, $now,
            ]
        );
        echo "<p>✓ 版本 1.1.4+9</p>";
    }

    echo '<h2 style="color:green;">升级完成！</h2>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_version_1_1_4.php。</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
