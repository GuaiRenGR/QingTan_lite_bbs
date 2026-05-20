<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

function h($str)
{
    return htmlspecialchars((string)$str, ENT_QUOTES, 'UTF-8');
}

function column_exists(PDO $pdo, $tableName, $column)
{
    $stmt = $pdo->prepare("SHOW COLUMNS FROM {$tableName} LIKE ?");
    $stmt->execute([$column]);
    return $stmt->fetch() ? true : false;
}

try {
    $pdo = Database::pdo();

    $prefix = defined('DB_PREFIX') ? DB_PREFIX : '';

    $users = Database::table('users');
    $threads = Database::table('threads');
    $posts = Database::table('posts');

    $appVersions = Database::table('app_versions');
    $checkins = Database::table('checkins');
    $contentStatsDaily = Database::table('content_stats_daily');
    $histories = Database::table('histories');
    $searchLogs = Database::table('search_logs');

    if (!column_exists($pdo, $users, 'points')) {
        $pdo->exec("ALTER TABLE {$users} ADD `points` INT NOT NULL DEFAULT 0");
    }

    if (!column_exists($pdo, $users, 'checkin_days')) {
        $pdo->exec("ALTER TABLE {$users} ADD `checkin_days` INT NOT NULL DEFAULT 0");
    }

    if (!column_exists($pdo, $users, 'last_checkin_date')) {
        $pdo->exec("ALTER TABLE {$users} ADD `last_checkin_date` DATE DEFAULT NULL");
    }

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$appVersions} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `platform` VARCHAR(30) NOT NULL DEFAULT 'all',
          `version` VARCHAR(50) NOT NULL,
          `build_number` INT NOT NULL DEFAULT 1,
          `force_update` TINYINT NOT NULL DEFAULT 0,
          `title` VARCHAR(255) DEFAULT NULL,
          `content` TEXT DEFAULT NULL,
          `download_url` VARCHAR(1000) DEFAULT NULL,
          `status` TINYINT NOT NULL DEFAULT 1,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          KEY `idx_platform_status` (`platform`, `status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$checkins} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `user_id` BIGINT UNSIGNED NOT NULL,
          `checkin_date` DATE NOT NULL,
          `points` INT NOT NULL DEFAULT 0,
          `continuous_days` INT NOT NULL DEFAULT 1,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_user_date` (`user_id`, `checkin_date`),
          KEY `idx_user` (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$contentStatsDaily} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `object_type` VARCHAR(30) NOT NULL,
          `object_id` BIGINT UNSIGNED NOT NULL,
          `user_id` BIGINT UNSIGNED NOT NULL,
          `stat_date` DATE NOT NULL,
          `view_count` INT NOT NULL DEFAULT 0,
          `like_count` INT NOT NULL DEFAULT 0,
          `favorite_count` INT NOT NULL DEFAULT 0,
          `share_count` INT NOT NULL DEFAULT 0,
          `reply_count` INT NOT NULL DEFAULT 0,
          `created_at` DATETIME NOT NULL,
          `updated_at` DATETIME DEFAULT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_object_date` (`object_type`, `object_id`, `stat_date`),
          KEY `idx_user_date` (`user_id`, `stat_date`),
          KEY `idx_object` (`object_type`, `object_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$histories} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `user_id` BIGINT UNSIGNED NOT NULL,
          `object_type` VARCHAR(30) NOT NULL,
          `object_id` BIGINT UNSIGNED NOT NULL,
          `last_viewed_at` DATETIME NOT NULL,
          `view_count` INT NOT NULL DEFAULT 1,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_user_object` (`user_id`, `object_type`, `object_id`),
          KEY `idx_user_time` (`user_id`, `last_viewed_at`),
          KEY `idx_object` (`object_type`, `object_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$searchLogs} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `user_id` BIGINT UNSIGNED DEFAULT NULL,
          `keyword` VARCHAR(255) NOT NULL,
          `ip` VARCHAR(64) DEFAULT NULL,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          KEY `idx_keyword` (`keyword`),
          KEY `idx_user` (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $exists = $pdo->query("SELECT COUNT(*) AS c FROM {$appVersions}")->fetch(PDO::FETCH_ASSOC);
    if ((int)$exists['c'] === 0) {
        $stmt = $pdo->prepare("
            INSERT INTO {$appVersions}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES
            ('all', '0.0.1', 1, 0, '发现新版本', '当前已是初始版本。', '', 1, ?)
        ");
        $stmt->execute([date('Y-m-d H:i:s')]);
    }

    echo '<h2>升级成功</h2>';
    echo '<p>已新增：更新检查、签到、创作中心统计、推荐算法、历史记录、搜索、回复可见所需表。</p>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_big_features.php。</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . h($e->getMessage()) . '</pre>';
}
