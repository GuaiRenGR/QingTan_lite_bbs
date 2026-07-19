<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

function version_1_1_8_column_exists(PDO $pdo, $tableName, $column)
{
    $stmt = $pdo->prepare("SHOW COLUMNS FROM {$tableName} LIKE ?");
    $stmt->execute([$column]);
    return $stmt->fetch() ? true : false;
}

function version_1_1_8_index_exists(PDO $pdo, $tableName, $indexName)
{
    $stmt = $pdo->prepare("SHOW INDEX FROM {$tableName} WHERE Key_name = ?");
    $stmt->execute([$indexName]);
    return $stmt->fetch() ? true : false;
}

try {
    $pdo = Database::pdo();
    $attachments = Database::table('attachments');
    $folders = Database::table('attachment_folders');

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$folders} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `name` VARCHAR(50) NOT NULL,
          `created_by` BIGINT UNSIGNED NOT NULL,
          `status` TINYINT NOT NULL DEFAULT 1,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_name_status` (`name`, `status`),
          KEY `idx_status_name` (`status`, `name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    if (!version_1_1_8_column_exists($pdo, $attachments, 'folder_id')) {
        $pdo->exec(
            "ALTER TABLE {$attachments}
             ADD `folder_id` BIGINT UNSIGNED DEFAULT NULL AFTER `object_id`"
        );
        echo '<p>✓ attachments.folder_id 字段已添加</p>';
    } else {
        echo '<p>· attachments.folder_id 字段已存在</p>';
    }

    if (!version_1_1_8_index_exists($pdo, $attachments, 'idx_folder')) {
        $pdo->exec("ALTER TABLE {$attachments} ADD KEY `idx_folder` (`folder_id`, `status`)");
        echo '<p>✓ 附件文件夹索引已添加</p>';
    } else {
        echo '<p>· 附件文件夹索引已存在</p>';
    }

    $versions = Database::table('app_versions');
    $existing = Database::fetch(
        "SELECT id FROM {$versions} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.1.8', 23]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$versions}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all',
                '1.1.8',
                23,
                0,
                '版本 1.1.8',
                implode("\n", [
                    '1. 优化图片磁盘缓存与内存解码，减少重复加载流量',
                    '2. 优化瀑布流和图集预加载，并按需创建主导航页面',
                    '3. 修复 hyjzbbs 帖子深度链接跳转到不存在页面',
                    '4. 我的页面改为无边框设计，发帖输入框改为白色无边框',
                    '5. 首页头像改为进入我的页面',
                    '6. 管理员新增附件文件管理、文件夹、移动和删除功能',
                    '7. 修复用户空间帖子预览泄露隐藏内容',
                    '8. 完成插入帖子卡片渲染和帖子选择器',
                ]),
                '',
                1,
                now(),
            ]
        );
        echo '<p>✓ 版本 1.1.8+23 已记录</p>';
    } else {
        echo '<p>· 版本 1.1.8+23 已存在</p>';
    }

    echo '<h2 style="color:green;">升级完成！</h2>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_version_1_1_8.php。</p>';
} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
