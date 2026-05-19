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

function index_exists(PDO $pdo, $tableName, $indexName)
{
    $stmt = $pdo->prepare("SHOW INDEX FROM {$tableName} WHERE Key_name = ?");
    $stmt->execute([$indexName]);
    return $stmt->fetch() ? true : false;
}

try {
    $pdo = Database::pdo();

    $threads = Database::table('threads');
    $posts = Database::table('posts');
    $likes = Database::table('likes');
    $favorites = Database::table('favorites');
    $attachments = Database::table('attachments');
    $shares = Database::table('shares');

    if (!column_exists($pdo, $threads, 'mode')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `mode` VARCHAR(20) NOT NULL DEFAULT 'article' AFTER `cover`");
    }

    if (!column_exists($pdo, $threads, 'images_json')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `images_json` MEDIUMTEXT NULL AFTER `mode`");
    }

    if (!column_exists($pdo, $threads, 'music_url')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `music_url` VARCHAR(1000) DEFAULT NULL AFTER `images_json`");
    }

    if (!column_exists($pdo, $threads, 'music_name')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `music_name` VARCHAR(255) DEFAULT NULL AFTER `music_url`");
    }

    if (!column_exists($pdo, $threads, 'share_count')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `share_count` INT NOT NULL DEFAULT 0 AFTER `favorite_count`");
    }

    if (!column_exists($pdo, $posts, 'like_count')) {
        $pdo->exec("ALTER TABLE {$posts} ADD `like_count` INT NOT NULL DEFAULT 0 AFTER `floor`");
    }

    if (!column_exists($pdo, $posts, 'updated_at')) {
        $pdo->exec("ALTER TABLE {$posts} ADD `updated_at` DATETIME DEFAULT NULL AFTER `created_at`");
    }

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$likes} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `user_id` BIGINT UNSIGNED NOT NULL,
          `object_type` VARCHAR(30) NOT NULL,
          `object_id` BIGINT UNSIGNED NOT NULL,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_like_object` (`user_id`, `object_type`, `object_id`),
          KEY `idx_object` (`object_type`, `object_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$favorites} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `user_id` BIGINT UNSIGNED NOT NULL,
          `object_type` VARCHAR(30) NOT NULL,
          `object_id` BIGINT UNSIGNED NOT NULL,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_favorite_object` (`user_id`, `object_type`, `object_id`),
          KEY `idx_object` (`object_type`, `object_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$attachments} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `user_id` BIGINT UNSIGNED NOT NULL,
          `object_type` VARCHAR(30) DEFAULT NULL,
          `object_id` BIGINT UNSIGNED DEFAULT NULL,
          `file_name` VARCHAR(255) NOT NULL,
          `file_path` VARCHAR(1000) DEFAULT NULL,
          `file_url` VARCHAR(1000) NOT NULL,
          `file_type` VARCHAR(100) DEFAULT NULL,
          `file_size` BIGINT UNSIGNED NOT NULL DEFAULT 0,
          `status` TINYINT NOT NULL DEFAULT 1,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          KEY `idx_user` (`user_id`),
          KEY `idx_object` (`object_type`, `object_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$shares} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `user_id` BIGINT UNSIGNED DEFAULT NULL,
          `thread_id` BIGINT UNSIGNED NOT NULL,
          `ip` VARCHAR(64) DEFAULT NULL,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          KEY `idx_thread` (`thread_id`),
          KEY `idx_user` (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    echo '<h2>升级成功</h2>';
    echo '<p>已新增发帖模式、图片列表、音乐、点赞、收藏、评论、转发、附件表。</p>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_post_features.php。</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . h($e->getMessage()) . '</pre>';
}
