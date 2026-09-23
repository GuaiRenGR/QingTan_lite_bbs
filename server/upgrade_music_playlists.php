<?php

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

header('Content-Type: text/html; charset=utf-8');
try {
    $pdo = Database::pdo();
    $table = Database::table('music_playlists');
    $columns = [];
    foreach ($pdo->query("SHOW COLUMNS FROM {$table}")->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $columns[strtolower((string)$row['Field'])] = true;
    }
    if (!isset($columns['public_id'])) {
        $pdo->exec("ALTER TABLE {$table} ADD COLUMN `public_id` INT UNSIGNED DEFAULT NULL AFTER `default_key`");
    }
    $indexes = $pdo->query("SHOW INDEX FROM {$table}")->fetchAll(PDO::FETCH_ASSOC);
    $hasIndex = false;
    foreach ($indexes as $index) if (strtolower((string)$index['Key_name']) === 'uk_public_id') $hasIndex = true;
    if (!$hasIndex) $pdo->exec("ALTER TABLE {$table} ADD UNIQUE KEY `uk_public_id` (`public_id`)");

    $rows = $pdo->query("SELECT id FROM {$table} WHERE public_id IS NULL OR public_id = 0")->fetchAll(PDO::FETCH_ASSOC);
    foreach ($rows as $row) {
        do {
            $publicId = random_int(100000000, 999999999);
            $check = $pdo->prepare("SELECT id FROM {$table} WHERE public_id = ? LIMIT 1");
            $check->execute([$publicId]);
        } while ($check->fetch());
        $update = $pdo->prepare("UPDATE {$table} SET public_id = ? WHERE id = ?");
        $update->execute([$publicId, $row['id']]);
    }
    echo '<h2>升级成功</h2><p>歌单公开 ID 已准备完成，请立即删除此脚本。</p>';
} catch (Throwable $e) {
    http_response_code(500);
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
