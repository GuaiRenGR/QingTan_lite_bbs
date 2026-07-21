<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';

function version_1_1_10_column_exists(PDO $pdo, $table, $column)
{
    $stmt = $pdo->prepare("SHOW COLUMNS FROM {$table} LIKE ?");
    $stmt->execute([$column]);
    return (bool)$stmt->fetch();
}

function version_1_1_10_index_exists(PDO $pdo, $table, $index)
{
    $stmt = $pdo->prepare("SHOW INDEX FROM {$table} WHERE Key_name = ?");
    $stmt->execute([$index]);
    return (bool)$stmt->fetch();
}

function version_1_1_10_uuid()
{
    $bytes = random_bytes(16);
    $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
    $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
    $hex = bin2hex($bytes);
    return substr($hex, 0, 8) . '-' . substr($hex, 8, 4) . '-' . substr($hex, 12, 4) . '-' . substr($hex, 16, 4) . '-' . substr($hex, 20);
}

try {
    $pdo = Database::pdo();
    $library = Database::table('music_library');
    $tracks = Database::table('music_playlist_tracks');
    $versions = Database::table('app_versions');

    $pdo->exec("CREATE TABLE IF NOT EXISTS {$library} (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `uuid` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
        `uploader_id` BIGINT UNSIGNED NOT NULL,
        `attachment_id` BIGINT UNSIGNED DEFAULT NULL,
        `audio_url` VARCHAR(1000) NOT NULL,
        `lyrics_url` VARCHAR(1000) DEFAULT NULL,
        `cover_url` VARCHAR(1000) DEFAULT NULL,
        `title` VARCHAR(255) NOT NULL,
        `artist` VARCHAR(255) DEFAULT NULL,
        `original_name` VARCHAR(255) DEFAULT NULL,
        `status` TINYINT NOT NULL DEFAULT 1,
        `created_at` DATETIME NOT NULL,
        `updated_at` DATETIME NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uk_music_uuid` (`uuid`),
        KEY `idx_music_search` (`status`, `title`, `artist`),
        KEY `idx_uploader_time` (`uploader_id`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

    foreach (['music_uuid' => "CHAR(36) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL AFTER `user_id`", 'cover_url' => "VARCHAR(1000) DEFAULT NULL AFTER `lyrics_url`", 'artist' => "VARCHAR(255) DEFAULT NULL AFTER `title`"] as $column => $definition) {
        if (!version_1_1_10_column_exists($pdo, $tracks, $column)) {
            $pdo->exec("ALTER TABLE {$tracks} ADD `{$column}` {$definition}");
        }
    }

    $legacy = $pdo->query("SELECT * FROM {$tracks} WHERE music_uuid IS NULL OR music_uuid = ''")->fetchAll(PDO::FETCH_ASSOC);
    $insertMusic = $pdo->prepare("INSERT INTO {$library}
        (`uuid`,`uploader_id`,`audio_url`,`lyrics_url`,`cover_url`,`title`,`artist`,`original_name`,`status`,`created_at`,`updated_at`)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)");
    $updateTrack = $pdo->prepare("UPDATE {$tracks} SET music_uuid = ? WHERE id = ?");
    foreach ($legacy as $track) {
        $url = trim($track['music_url'] ?? '');
        if ($url === '') continue;
        $existing = $pdo->prepare("SELECT uuid FROM {$library} WHERE audio_url = ? LIMIT 1");
        $existing->execute([$url]);
        $row = $existing->fetch(PDO::FETCH_ASSOC);
        $uuid = $row['uuid'] ?? version_1_1_10_uuid();
        if (!$row) {
            $insertMusic->execute([$uuid, (int)$track['user_id'], $url, $track['lyrics_url'] ?: null,
                $track['cover_url'] ?: null, $track['title'] ?: '未知歌曲', $track['artist'] ?: null,
                $track['title'] ?: null, 1, $track['created_at'] ?: now(), now()]);
        }
        $updateTrack->execute([$uuid, $track['id']]);
    }

    $threads = Database::table('threads');
    $threadRows = $pdo->query("SELECT id, user_id, content FROM {$threads} WHERE content LIKE '%[music=%'")->fetchAll(PDO::FETCH_ASSOC);
    $findMusic = $pdo->prepare("SELECT uuid FROM {$library} WHERE audio_url = ? LIMIT 1");
    $insertThreadMusic = $pdo->prepare("INSERT INTO {$library}
        (`uuid`,`uploader_id`,`audio_url`,`lyrics_url`,`title`,`original_name`,`status`,`created_at`,`updated_at`)
        VALUES (?,?,?,?,?,?,?,?,?)");
    $updateContent = $pdo->prepare("UPDATE {$threads} SET content = ?, updated_at = ? WHERE id = ?");
    $migratedReferences = 0;
    foreach ($threadRows as $thread) {
        $changed = false;
        $content = preg_replace_callback('/\[music=([^\]]+)\]/i', function ($match) use (&$changed, &$migratedReferences, $findMusic, $insertThreadMusic, $thread) {
            $parts = preg_split('/[,|]/', $match[1], 2);
            $source = trim($parts[0] ?? '');
            if (preg_match('/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i', $source)) {
                return '[music=' . strtolower($source) . ']';
            }
            if (!validate_remote_url($source)) return $match[0];
            $findMusic->execute([$source]);
            $existing = $findMusic->fetch(PDO::FETCH_ASSOC);
            $uuid = $existing['uuid'] ?? version_1_1_10_uuid();
            if (!$existing) {
                $lyrics = trim($parts[1] ?? '');
                $lyrics = validate_remote_url($lyrics) ? $lyrics : null;
                $name = pathinfo(parse_url($source, PHP_URL_PATH) ?: '', PATHINFO_FILENAME) ?: '未知歌曲';
                $insertThreadMusic->execute([$uuid, (int)$thread['user_id'], $source, $lyrics, $name, $name, 1, now(), now()]);
            }
            $changed = true;
            $migratedReferences++;
            return '[music=' . $uuid . ']';
        }, $thread['content']);
        if ($changed && $content !== null) {
            $updateContent->execute([$content, now(), $thread['id']]);
        }
    }

    if (!version_1_1_10_index_exists($pdo, $tracks, 'uk_playlist_music_uuid')) {
        $pdo->exec("ALTER TABLE {$tracks} ADD UNIQUE KEY `uk_playlist_music_uuid` (`playlist_id`, `music_uuid`)");
    }
    echo '<p>✓ 音乐库、UUID 引用和歌单去重已升级，已迁移 ' . $migratedReferences . ' 个帖子音乐引用</p>';

    $notes = implode("\n", [
        '1. 音乐上传后生成独立 UUID，多个帖子可引用同一首音乐',
        '2. 新增音乐搜索与插入，歌曲可按歌名、歌手搜索',
        '3. 默认歌单按音乐 UUID 去重，修复重复收藏',
        '4. 播放器和音乐卡片显示歌名、歌手及上传封面',
        '5. 修复歌词当前句居中位置偏下',
    ]);
    $existing = Database::fetch("SELECT id FROM {$versions} WHERE version = ? AND build_number = ? LIMIT 1", ['1.1.10', 25]);
    if ($existing) {
        Database::execute("UPDATE {$versions} SET title = ?, content = ?, status = 1 WHERE id = ?", ['版本 1.1.10', $notes, $existing['id']]);
    } else {
        Database::execute("INSERT INTO {$versions} (`platform`,`version`,`build_number`,`force_update`,`title`,`content`,`download_url`,`status`,`created_at`) VALUES (?,?,?,?,?,?,?,?,?)", ['all', '1.1.10', 25, 0, '版本 1.1.10', $notes, '', 1, now()]);
    }
    echo '<p>✓ 版本 1.1.10+25 已记录</p><h2 style="color:green">升级完成</h2>';
} catch (Throwable $e) {
    echo '<h2>升级失败</h2><pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
}
