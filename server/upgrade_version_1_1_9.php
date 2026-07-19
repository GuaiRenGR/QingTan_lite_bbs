<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';
require_once FX_ROOT . '/core/DvCode.php';

function version_1_1_9_column_exists(PDO $pdo, $tableName, $column)
{
    $stmt = $pdo->prepare("SHOW COLUMNS FROM {$tableName} LIKE ?");
    $stmt->execute([$column]);
    return $stmt->fetch() ? true : false;
}

function version_1_1_9_index_exists(PDO $pdo, $tableName, $indexName)
{
    $stmt = $pdo->prepare("SHOW INDEX FROM {$tableName} WHERE Key_name = ?");
    $stmt->execute([$indexName]);
    return $stmt->fetch() ? true : false;
}

try {
    $pdo = Database::pdo();
    $threads = Database::table('threads');
    $aliases = Database::table('thread_dv_aliases');

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$aliases} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `thread_id` BIGINT UNSIGNED NOT NULL,
          `dv_code` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
          `created_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_dv_code` (`dv_code`),
          KEY `idx_thread_id` (`thread_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    if (!version_1_1_9_column_exists($pdo, $threads, 'dv_code')) {
        $pdo->exec(
            "ALTER TABLE {$threads}
             ADD `dv_code` VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL AFTER `id`"
        );
    } else {
        $column = $pdo->query("SHOW FULL COLUMNS FROM {$threads} LIKE 'dv_code'")->fetch();
        if (($column['Collation'] ?? '') !== 'ascii_bin') {
            $pdo->exec(
                "ALTER TABLE {$threads}
                 MODIFY `dv_code` VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL"
            );
        }
    }

    if (!version_1_1_9_index_exists($pdo, $threads, 'idx_dv_code')) {
        $pdo->exec("ALTER TABLE {$threads} ADD UNIQUE KEY `idx_dv_code` (`dv_code`)");
    }

    $threadIds = $pdo->query(
        "SELECT id FROM {$threads} ORDER BY id ASC"
    )->fetchAll(PDO::FETCH_COLUMN);

    if (!empty($threadIds)) {
        $pdo->beginTransaction();
        try {
            $pdo->exec(
                "INSERT IGNORE INTO {$aliases} (`thread_id`, `dv_code`, `created_at`)
                 SELECT id, dv_code, NOW()
                 FROM {$threads}
                 WHERE dv_code IS NOT NULL AND dv_code != ''"
            );

            $pdo->exec("UPDATE {$threads} SET dv_code = NULL");
            $updateCode = $pdo->prepare(
                "UPDATE {$threads} SET dv_code = ? WHERE id = ?"
            );
            foreach ($threadIds as $threadId) {
                $updateCode->execute([
                    \DvCode::encode((int)$threadId),
                    (int)$threadId,
                ]);
            }
            $pdo->commit();
            echo '<p>✓ 已保存旧 DV 别名并重新生成 ' . count($threadIds) . ' 个帖子 DV 码</p>';
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $e;
        }
    } else {
        echo '<p>· 当前没有需要生成 DV 的帖子</p>';
    }

    $playlists = Database::table('music_playlists');
    $playlistTracks = Database::table('music_playlist_tracks');
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$playlists} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `user_id` BIGINT UNSIGNED NOT NULL,
          `name` VARCHAR(100) NOT NULL,
          `description` VARCHAR(500) DEFAULT NULL,
          `cover_url` VARCHAR(1000) DEFAULT NULL,
          `default_key` BIGINT UNSIGNED DEFAULT NULL,
          `is_default` TINYINT NOT NULL DEFAULT 0,
          `status` TINYINT NOT NULL DEFAULT 1,
          `created_at` DATETIME NOT NULL,
          `updated_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_default_key` (`default_key`),
          KEY `idx_user_status` (`user_id`, `status`, `is_default`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS {$playlistTracks} (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `playlist_id` BIGINT UNSIGNED NOT NULL,
          `user_id` BIGINT UNSIGNED NOT NULL,
          `music_key` CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
          `music_url` VARCHAR(1000) NOT NULL,
          `lyrics_url` VARCHAR(1000) DEFAULT NULL,
          `title` VARCHAR(255) NOT NULL,
          `sort_order` INT NOT NULL DEFAULT 0,
          `status` TINYINT NOT NULL DEFAULT 1,
          `created_at` DATETIME NOT NULL,
          `updated_at` DATETIME NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uk_playlist_music` (`playlist_id`, `music_key`),
          KEY `idx_user_time` (`user_id`, `created_at`),
          KEY `idx_playlist_sort` (`playlist_id`, `status`, `sort_order`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");
    echo '<p>✓ 音乐默认歌单与歌曲收藏表已创建</p>';

    $versions = Database::table('app_versions');
    $releaseNotes = implode("\n", [
        '1. 修复部分帖子短 DV 码导致插入卡片显示不可用',
        '2. DV 码改为完整 8 位空间置换，前缀分布更加随机',
        '3. 重新生成全部帖子 DV，并通过别名兼容历史链接',
        '4. 帖子卡片加载失败时自动重试并支持点击重载',
        '5. 优化音乐元数据缓存与下一曲预下载，减少重复流量',
        '6. 音乐播放器支持 LRC 歌词、封面歌词左右滑动与收藏歌单',
        '7. 音乐上传支持分别选择音乐和可选歌词文件',
    ]);
    $existing = Database::fetch(
        "SELECT id FROM {$versions} WHERE version = ? AND build_number = ? LIMIT 1",
        ['1.1.9', 24]
    );

    if (!$existing) {
        Database::execute(
            "INSERT INTO {$versions}
            (`platform`, `version`, `build_number`, `force_update`, `title`, `content`, `download_url`, `status`, `created_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                'all',
                '1.1.9',
                24,
                0,
                '版本 1.1.9',
                $releaseNotes,
                '',
                1,
                now(),
            ]
        );
        echo '<p>✓ 版本 1.1.9+24 已记录</p>';
    } else {
        Database::execute(
            "UPDATE {$versions}
             SET title = ?, content = ?, status = 1
             WHERE id = ?",
            ['版本 1.1.9', $releaseNotes, (int)$existing['id']]
        );
        echo '<p>✓ 版本 1.1.9+24 更新说明已刷新</p>';
    }

    echo '<h2 style="color:green;">升级完成！</h2>';
    echo '<p style="color:red;">安全建议：请删除 upgrade_version_1_1_9.php。</p>';
} catch (Throwable $e) {
    echo '<h2>升级失败</h2>';
    echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
