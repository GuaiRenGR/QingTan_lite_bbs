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

    $users = Database::table('users');
    $follows = Database::table('user_follows');

    if (!column_exists($pdo, $users, 'space_cover')) {
        $pdo->exec("ALTER TABLE {$users} ADD `space_cover` VARCHAR(255) DEFAULT NULL AFTER `avatar`");
    }

    if (!column_exists($pdo, $users, 'followers_count')) {
        $pdo->exec("ALTER TABLE {$users} ADD `followers_count` INT NOT NULL DEFAULT 0 AFTER `score`");
    }

    if (!column_exists($pdo, $users, 'following_count')) {
        $pdo->exec("ALTER TABLE {$users} ADD `following_count` INT NOT NULL DEFAULT 0 AFTER `followers_count`");
    }

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$follows} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `follower_id` BIGINT UNSIGNED NOT NULL,
          `following_id` BIGINT UNSIGNED NOT NULL,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_follow` (`follower_id`, `following_id`),
          KEY `idx_follower` (`follower_id`),
          KEY `idx_following` (`following_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    echo '<h2>升级成功</h2>';
    echo '<p>已新增用户主页、关注、空间背景图相关字段和表。</p>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_user_features.php。</p>';

} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . h($e->getMessage()) . '</pre>';
}
