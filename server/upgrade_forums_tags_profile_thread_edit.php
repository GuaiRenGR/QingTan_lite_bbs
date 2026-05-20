<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

function column_exists(PDO $pdo, $tableName, $column)
{
    $stmt = $pdo->prepare("SHOW COLUMNS FROM {$tableName} LIKE ?");
    $stmt->execute([$column]);
    return $stmt->fetch() ? true : false;
}

try {
    $pdo = Database::pdo();

    $users = Database::table('users');
    $threads = Database::table('threads');
    $forums = Database::table('forums');
    $tags = Database::table('tags');
    $threadTags = Database::table('thread_tags');
    $reports = Database::table('reports');

    if (!column_exists($pdo, $users, 'bio')) {
        $pdo->exec("ALTER TABLE {$users} ADD `bio` VARCHAR(500) DEFAULT ''");
    }

    if (!column_exists($pdo, $users, 'gender')) {
        $pdo->exec("ALTER TABLE {$users} ADD `gender` VARCHAR(20) DEFAULT ''");
    }

    if (!column_exists($pdo, $users, 'birthday')) {
        $pdo->exec("ALTER TABLE {$users} ADD `birthday` DATE DEFAULT NULL");
    }

    if (!column_exists($pdo, $users, 'school')) {
        $pdo->exec("ALTER TABLE {$users} ADD `school` VARCHAR(100) DEFAULT ''");
    }

    if (!column_exists($pdo, $users, 'grade')) {
        $pdo->exec("ALTER TABLE {$users} ADD `grade` VARCHAR(100) DEFAULT ''");
    }

    if (!column_exists($pdo, $users, 'location')) {
        $pdo->exec("ALTER TABLE {$users} ADD `location` VARCHAR(100) DEFAULT ''");
    }

    if (!column_exists($pdo, $users, 'profile_visibility_json')) {
        $pdo->exec("ALTER TABLE {$users} ADD `profile_visibility_json` TEXT DEFAULT NULL");
    }

    if (!column_exists($pdo, $threads, 'updated_at')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `updated_at` DATETIME DEFAULT NULL");
    }

    if (!column_exists($pdo, $threads, 'deleted_at')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `deleted_at` DATETIME DEFAULT NULL");
    }

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$forums} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `name` VARCHAR(100) NOT NULL,
          `description` VARCHAR(255) DEFAULT '',
          `icon` VARCHAR(100) DEFAULT '',
          `sort_order` INT NOT NULL DEFAULT 0,
          `is_default` TINYINT NOT NULL DEFAULT 0,
          `status` TINYINT NOT NULL DEFAULT 1,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          KEY `idx_status_sort` (`status`, `sort_order`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$tags} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `name` VARCHAR(50) NOT NULL,
          `use_count` INT NOT NULL DEFAULT 0,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_name` (`name`),
          KEY `idx_use_count` (`use_count`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$threadTags} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `thread_id` BIGINT UNSIGNED NOT NULL,
          `tag_id` BIGINT UNSIGNED NOT NULL,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_thread_tag` (`thread_id`, `tag_id`),
          KEY `idx_thread` (`thread_id`),
          KEY `idx_tag` (`tag_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$reports} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `user_id` BIGINT UNSIGNED DEFAULT NULL,
          `object_type` VARCHAR(30) NOT NULL,
          `object_id` BIGINT UNSIGNED NOT NULL,
          `reason` VARCHAR(255) DEFAULT '',
          `status` TINYINT NOT NULL DEFAULT 0,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          KEY `idx_object` (`object_type`, `object_id`),
          KEY `idx_user` (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    $count = $pdo->query("SELECT COUNT(*) AS c FROM {$forums}")->fetch(PDO::FETCH_ASSOC);

    if ((int)$count['c'] === 0) {
        $now = date('Y-m-d H:i:s');

        $rows = [
            ['默认', '默认分区', 'apps', 0, 1],
            ['校园', '校园生活、通知、活动', 'school', 10, 0],
            ['学习', '学习资料、经验交流', 'menu_book', 20, 0],
            ['生活', '日常、吐槽、分享', 'local_cafe', 30, 0],
            ['社团', '社团、兴趣、活动', 'groups', 40, 0],
            ['二手', '二手交易、闲置交换', 'shopping_bag', 50, 0],
            ['问答', '提问与求助', 'help', 60, 0],
        ];

        $stmt = $pdo->prepare("
            INSERT INTO {$forums}
            (`name`, `description`, `icon`, `sort_order`, `is_default`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, 1, ?)
        ");

        foreach ($rows as $row) {
            $stmt->execute([$row[0], $row[1], $row[2], $row[3], $row[4], $now]);
        }
    }

    echo '<h2>升级成功</h2>';
    echo '<p>请删除 upgrade_forums_tags_profile_thread_edit.php</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
