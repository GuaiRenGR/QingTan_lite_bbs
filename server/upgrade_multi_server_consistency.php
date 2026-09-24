<?php
// CLI-only migration for reliable per-peer sync delivery.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';
try {
    $config = require FX_ROOT . '/config/database.php';
    $prefix = $config['prefix'] ?? '';
    Database::pdo()->exec("CREATE TABLE IF NOT EXISTS `{$prefix}sync_operation_delivery` (`operation_id` BIGINT UNSIGNED NOT NULL, `peer_server_id` INT UNSIGNED NOT NULL, `delivered_at` DATETIME NOT NULL, PRIMARY KEY (`operation_id`, `peer_server_id`), KEY `idx_peer_time` (`peer_server_id`, `delivered_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    echo "Multi-server consistency migration completed.\n";
} catch (Throwable $e) {
    fwrite(STDERR, "Migration failed. Check server logs.\n");
    exit(1);
}
