<?php

namespace App\Controllers;

class MusicLibraryController
{
    public static function detail()
    {
        $uuid = self::uuid(\Request::str('uuid'));
        if ($uuid === '') {
            \Response::json(422, '音乐标识无效');
        }

        $music = self::find($uuid);
        if (!$music) {
            \Response::json(404, '音乐不存在或已下架');
        }
        \Response::success(['music' => self::serialize($music)]);
    }

    public static function search()
    {
        $keyword = trim(\Request::str('keyword'));
        $pageSize = min(50, max(1, \Request::int('page_size', 20)));
        if ($keyword === '') {
            \Response::success(['list' => []]);
        }
        if (function_exists('mb_strlen') && mb_strlen($keyword, 'UTF-8') > 50) {
            \Response::json(422, '关键词过长');
        }

        $music = \Database::table('music_library');
        $users = \Database::table('users');
        $like = '%' . $keyword . '%';
        $rows = \Database::fetchAll(
            "SELECT m.*, COALESCE(u.nickname, u.username, '用户') AS uploader_name
             FROM {$music} m
             LEFT JOIN {$users} u ON u.id = m.uploader_id
             WHERE m.status = 1
               AND (m.title LIKE ? OR m.artist LIKE ? OR m.original_name LIKE ?)
             ORDER BY CASE WHEN m.title LIKE ? THEN 0 ELSE 1 END, m.created_at DESC, m.id DESC
             LIMIT {$pageSize}",
            [$like, $like, $like, $like]
        );

        \Response::success([
            'list' => array_map([self::class, 'serialize'], $rows),
        ]);
    }

    public static function find($uuid)
    {
        $music = \Database::table('music_library');
        return \Database::fetch(
            "SELECT * FROM {$music} WHERE uuid = ? AND status = 1 LIMIT 1",
            [$uuid]
        );
    }

    public static function createFromUpload($userId, $attachmentId, $audioUrl, $originalName, $metadata = [])
    {
        $music = \Database::table('music_library');
        $title = self::limit(trim((string)($metadata['title'] ?? '')), 255);
        $artist = self::limit(trim((string)($metadata['artist'] ?? '')), 255);
        $lyricsUrl = normalize_forum_media_url($metadata['lyrics_url'] ?? '');
        $coverUrl = normalize_forum_media_url($metadata['cover_url'] ?? '');
        $fallbackTitle = pathinfo((string)$originalName, PATHINFO_FILENAME);
        $title = $title === '' ? ($fallbackTitle === '' ? '未知歌曲' : $fallbackTitle) : $title;

        for ($attempt = 0; $attempt < 5; $attempt++) {
            $uuid = self::newUuid();
            try {
                \Database::execute(
                    "INSERT INTO {$music}
                     (`uuid`,`uploader_id`,`attachment_id`,`audio_url`,`lyrics_url`,`cover_url`,`title`,`artist`,`original_name`,`status`,`created_at`,`updated_at`)
                     VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                    [$uuid, $userId, $attachmentId, $audioUrl, $lyricsUrl ?: null, $coverUrl ?: null,
                        $title, $artist ?: null, self::limit($originalName, 255), 1, now(), now()]
                );
                $id = (int)\Database::lastInsertId();
                $row = \Database::fetch("SELECT * FROM {$music} WHERE id = ?", [$id]);
                record_sync_operation('music_library', $id, 'insert', $row);
                return $row;
            } catch (\Throwable $e) {
                if ($attempt === 4) throw $e;
            }
        }
        throw new \RuntimeException('无法创建音乐记录');
    }

    public static function serialize($row)
    {
        return [
            'id' => (int)$row['id'],
            'uuid' => $row['uuid'],
            'url' => $row['audio_url'],
            'lyrics_url' => $row['lyrics_url'] ?: null,
            'cover_url' => $row['cover_url'] ?: null,
            'title' => $row['title'] ?: '未知歌曲',
            'artist' => $row['artist'] ?: '',
            'original_name' => $row['original_name'] ?: '',
            'created_at' => $row['created_at'],
        ];
    }

    private static function uuid($value)
    {
        $uuid = strtolower(trim((string)$value));
        return preg_match('/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/', $uuid)
            ? $uuid
            : '';
    }

    private static function newUuid()
    {
        $bytes = random_bytes(16);
        $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
        $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
        $hex = bin2hex($bytes);
        return substr($hex, 0, 8) . '-' . substr($hex, 8, 4) . '-' . substr($hex, 12, 4) . '-' . substr($hex, 16, 4) . '-' . substr($hex, 20);
    }

    private static function limit($value, $length)
    {
        return function_exists('mb_substr') ? mb_substr($value, 0, $length, 'UTF-8') : substr($value, 0, $length);
    }
}
