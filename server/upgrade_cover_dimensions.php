<?php

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

header('Content-Type: text/html; charset=utf-8');
@set_time_limit(0);

try {
    $pdo = Database::pdo();
    $threads = Database::table('threads');
    $databaseName = $pdo->query('SELECT DATABASE()')->fetchColumn();
    $tableName = trim($threads, '`');

    $columnExists = function ($column) use ($pdo, $databaseName, $tableName) {
        $stmt = $pdo->prepare(
            'SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?'
        );
        $stmt->execute([$databaseName, $tableName, $column]);
        return (int)$stmt->fetchColumn() > 0;
    };

    if (!$columnExists('cover_width')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `cover_width` INT UNSIGNED DEFAULT NULL AFTER `cover`");
    }
    if (!$columnExists('cover_height')) {
        $pdo->exec("ALTER TABLE {$threads} ADD `cover_height` INT UNSIGNED DEFAULT NULL AFTER `cover_width`");
    }

    $rows = Database::fetchAll(
        "SELECT id, cover FROM {$threads}
         WHERE status = 1
           AND cover IS NOT NULL
           AND cover <> ''
           AND (cover_width IS NULL OR cover_width = 0 OR cover_height IS NULL OR cover_height = 0)
         ORDER BY id ASC"
    );

    $updated = 0;
    $failed = 0;
    foreach ($rows as $row) {
        $dimensions = get_image_dimensions($row['cover']);
        if (!$dimensions) {
            $failed++;
            continue;
        }

        Database::execute(
            "UPDATE {$threads} SET cover_width = ?, cover_height = ? WHERE id = ?",
            [$dimensions['width'], $dimensions['height'], $row['id']]
        );
        $updated++;
    }

    echo '<h2>封面分辨率补充完成</h2>';
    echo '<p>已更新 ' . $updated . ' 篇帖子，无法读取 ' . $failed . ' 篇。</p>';
    echo '<p>请立即删除此脚本。</p>';
} catch (Throwable $e) {
    http_response_code(500);
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
