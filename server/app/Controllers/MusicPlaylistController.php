<?php

namespace App\Controllers;

class MusicPlaylistController
{
    public static function defaultPlaylist()
    {
        $user = \Auth::requireLogin();
        $playlist = self::ensureDefaultPlaylist((int)$user['id']);
        $tracks = self::tracks((int)$playlist['id']);

        \Response::success([
            'playlist' => [
                'id' => (int)$playlist['id'],
                'name' => $playlist['name'],
                'is_default' => (int)$playlist['is_default'],
                'track_count' => count($tracks),
            ],
            'tracks' => $tracks,
        ]);
    }

    public static function toggleFavorite()
    {
        $user = \Auth::requireLogin();
        $uuid = strtolower(trim(\Request::str('music_uuid')));
        if (!preg_match('/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/', $uuid)) {
            \Response::json(422, '请选择音乐库中的歌曲');
        }
        $music = MusicLibraryController::find($uuid);
        if (!$music) {
            \Response::json(404, '音乐不存在或已下架');
        }

        $playlist = self::ensureDefaultPlaylist((int)$user['id']);
        $tracks = \Database::table('music_playlist_tracks');
        $existing = \Database::fetch(
            "SELECT * FROM {$tracks}
             WHERE playlist_id = ? AND music_uuid = ?
             LIMIT 1",
            [$playlist['id'], $uuid]
        );

        if ($existing) {
            \Database::execute(
                "DELETE FROM {$tracks} WHERE id = ?",
                [$existing['id']]
            );
            record_sync_operation(
                'music_playlist_tracks',
                (int)$existing['id'],
                'delete',
                $existing
            );
            \Response::success([
                'is_favorited' => false,
                'playlist_id' => (int)$playlist['id'],
            ], '已取消收藏');
        }

        $nextSort = \Database::fetch(
            "SELECT COALESCE(MAX(sort_order), 0) + 1 AS next_sort
             FROM {$tracks} WHERE playlist_id = ?",
            [$playlist['id']]
        );
        try {
            \Database::execute(
                "INSERT INTO {$tracks}
                 (`playlist_id`,`user_id`,`music_uuid`,`music_key`,`music_url`,`lyrics_url`,`cover_url`,`title`,`artist`,`sort_order`,`created_at`,`updated_at`)
                 VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                [
                    $playlist['id'], $user['id'], $uuid, hash('sha256', $music['audio_url']),
                    $music['audio_url'], $music['lyrics_url'], $music['cover_url'], $music['title'],
                    $music['artist'], (int)($nextSort['next_sort'] ?? 1), now(), now(),
                ]
            );
        } catch (\Throwable $e) {
            // 唯一索引处理并发收藏，避免产生重复歌曲记录。
            $alreadyAdded = \Database::fetch(
                "SELECT id FROM {$tracks} WHERE playlist_id = ? AND music_uuid = ? LIMIT 1",
                [$playlist['id'], $uuid]
            );
            if ($alreadyAdded) {
                \Response::success([
                    'is_favorited' => true,
                    'playlist_id' => (int)$playlist['id'],
                ], '歌曲已在默认歌单中');
            }
            throw $e;
        }
        $trackId = (int)\Database::lastInsertId();
        $track = \Database::fetch("SELECT * FROM {$tracks} WHERE id = ?", [$trackId]);
        record_sync_operation('music_playlist_tracks', $trackId, 'insert', $track);

        \Response::success([
            'is_favorited' => true,
            'playlist_id' => (int)$playlist['id'],
        ], '已加入默认歌单');
    }

    private static function ensureDefaultPlaylist($userId)
    {
        $playlists = \Database::table('music_playlists');
        $playlist = \Database::fetch(
            "SELECT * FROM {$playlists}
             WHERE user_id = ? AND is_default = 1 AND status = 1
             LIMIT 1",
            [$userId]
        );
        if ($playlist) {
            return $playlist;
        }

        try {
            \Database::execute(
                "INSERT INTO {$playlists}
                 (`user_id`,`name`,`description`,`default_key`,`is_default`,`status`,`created_at`,`updated_at`)
                 VALUES (?,?,?,?,?,?,?,?)",
                [$userId, '默认歌单', '系统默认收藏歌单', $userId, 1, 1, now(), now()]
            );
        } catch (\Throwable $e) {
            $playlist = \Database::fetch(
                "SELECT * FROM {$playlists}
                 WHERE user_id = ? AND is_default = 1 AND status = 1
                 LIMIT 1",
                [$userId]
            );
            if ($playlist) return $playlist;
            throw $e;
        }
        $playlistId = (int)\Database::lastInsertId();
        $playlist = \Database::fetch(
            "SELECT * FROM {$playlists} WHERE id = ? LIMIT 1",
            [$playlistId]
        );
        record_sync_operation('music_playlists', $playlistId, 'insert', $playlist);
        return $playlist;
    }

    private static function tracks($playlistId)
    {
        $tracks = \Database::table('music_playlist_tracks');
        $rows = \Database::fetchAll(
            "SELECT id, music_uuid, music_url AS url, lyrics_url, cover_url, title, artist, sort_order, created_at
             FROM {$tracks}
             WHERE playlist_id = ? AND status = 1
             ORDER BY sort_order ASC, id DESC",
            [$playlistId]
        );

        return array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'uuid' => $row['music_uuid'] ?: null,
                'url' => $row['url'],
                'title' => $row['title'] ?: '音乐',
                'artist' => $row['artist'] ?: '',
                'cover_url' => $row['cover_url'] ?: null,
                'lyrics_url' => $row['lyrics_url'] ?: null,
                'sort_order' => (int)$row['sort_order'],
                'created_at' => $row['created_at'],
            ];
        }, $rows);
    }
}
