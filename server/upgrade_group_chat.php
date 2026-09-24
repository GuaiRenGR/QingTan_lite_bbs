<?php
// Run from the server CLI after uploading the new server files.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
error_reporting(E_ALL);
ini_set('display_errors', '0');
define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

try {
    $pdo = Database::pdo();
    $config = require FX_ROOT . '/config/database.php';
    $prefix = $config['prefix'] ?? '';
    try { $pdo->exec("ALTER TABLE `{$prefix}conversations` ADD COLUMN `group_id` BIGINT UNSIGNED DEFAULT NULL AFTER `user_b_id`"); } catch (Throwable $e) {}
    try { $pdo->exec("ALTER TABLE `{$prefix}conversations` DROP INDEX `uk_pair`"); } catch (Throwable $e) {}
    try { $pdo->exec("ALTER TABLE `{$prefix}conversations` ADD UNIQUE KEY `uk_pair_group` (`user_a_id`, `user_b_id`, `group_id`), ADD KEY `idx_group` (`group_id`)"); } catch (Throwable $e) {}
    $pdo->exec("CREATE TABLE IF NOT EXISTS `{$prefix}chat_groups` (`id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `group_no` CHAR(8) NOT NULL, `name` VARCHAR(80) NOT NULL, `owner_id` BIGINT UNSIGNED NOT NULL, `created_at` DATETIME NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `uk_group_no` (`group_no`), KEY `idx_owner` (`owner_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS `{$prefix}chat_group_members` (`id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `group_id` BIGINT UNSIGNED NOT NULL, `user_id` BIGINT UNSIGNED NOT NULL, `role` VARCHAR(16) NOT NULL DEFAULT 'member', `joined_at` DATETIME NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `uk_group_user` (`group_id`, `user_id`), KEY `idx_user` (`user_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    echo "Group chat database upgrade completed. Delete this script.\n";
} catch (Throwable $e) {
    fwrite(STDERR, "Group chat upgrade failed. Check server logs.\n");
    exit(1);
}
