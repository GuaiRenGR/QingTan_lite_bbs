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
    } else {
        echo "<p>· threads.dv_code 列已存在</p>";
    }

    // 为未生成 DV 码的历史帖子补生成（幂等，可重复运行）
    require_once FX_ROOT . '/core/DvCode.php';
    $rows = $pdo->query("SELECT id FROM `{$prefix}threads` WHERE dv_code IS NULL OR dv_code = ''")->fetchAll(PDO::FETCH_COLUMN);
    if (!empty($rows)) {
        $checkStmt = $pdo->prepare("SELECT id FROM `{$prefix}threads` WHERE dv_code = ? LIMIT 1");
        $updateStmt = $pdo->prepare("UPDATE `{$prefix}threads` SET dv_code = ? WHERE id = ?");
        $generated = 0;
        foreach ($rows as $id) {
            $code = \DvCode::encode((int)$id);
            // 检查是否已存在该 DV 码（防冲突）
            $checkStmt->execute([$code]);
            $existing = $checkStmt->fetch(PDO::FETCH_COLUMN);
            if ($existing && (int)$existing !== (int)$id) {
                // 冲突：用后缀区分
                $suffix = 'a';
                do {
                    $tryCode = substr($code, 0, 7) . $suffix;
                    $checkStmt->execute([$tryCode]);
                    $existing = $checkStmt->fetch(PDO::FETCH_COLUMN);
                    $suffix++;
                } while ($existing && (int)$existing !== (int)$id);
                $code = $tryCode;
            }
            $updateStmt->execute([$code, $id]);
            $generated++;
        }
        echo "<p>✓ 已为 {$generated} 个历史帖子生成 DV 码</p>";
    } else {
        echo "<p>· 所有帖子已有 DV 码</p>";
    }

    // 2. users.badge_name 列
    $col = $pdo->query("SHOW COLUMNS FROM `{$prefix}users` LIKE 'badge_name'")->fetch();
    if (!$col) {
        $pdo->exec("ALTER TABLE `{$prefix}users` ADD COLUMN `badge_name` VARCHAR(10) DEFAULT NULL AFTER `bio`");
        echo "<p>✓ users.badge_name 列已添加</p>";
    } else {
        echo "<p>· users.badage_name 列已存在</p>";
    }

    // 3. users.badge_color 列
    $col = $pdo->query("SHOW COLUMNS FROM `{$prefix}users` LIKE 'badge_color'")->fetch();
    if (!$col) {
        $pdo->exec("ALTER TABLE `{$prefix}users` ADD COLUMN `badge_color` VARCHAR(20) DEFAULT NULL AFTER `badge_name`");
        echo "<p>✓ users.badge_color 列已添加</p>";
    } else {
        echo "<p>· users.badge_color 列已存在</p>";
    }

    // 4. users.verify_level 列
    $col = $pdo->query("SHOW COLUMNS FROM `{$prefix}users` LIKE 'verify_level'")->fetch();
    if (!$col) {
        $pdo->exec("ALTER TABLE `{$prefix}users` ADD COLUMN `verify_level` TINYINT NOT NULL DEFAULT 0 AFTER `badge_color`");
        echo "<p>✓ users.verify_level 列已添加</p>";
    } else {
        echo "<p>· users.verify_level 列已存在</p>";
    }

    // 5. 版本记录
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
                    '4. 新增永久下载页',
                    '5. 新增铭牌系统（管理员可设置）',
                    '6. 新增认证标志（官方/知名人物/已认证）',
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
