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

    public static function listPlaylists()
    {
        $user = \Auth::requireLogin();
        self::ensureDefaultPlaylist((int)$user['id']);
        $table = \Database::table('music_playlists');
        $rows = \Database::fetchAll("SELECT id, public_id, name, description, cover_url, is_default, created_at FROM {$table} WHERE user_id = ? AND status = 1 ORDER BY is_default DESC, id ASC", [$user['id']]);
        \Response::success(['playlists' => array_map(function ($row) {
            return ['id' => (int)$row['id'], 'playlist_id' => (int)$row['public_id'], 'name' => $row['name'], 'description' => $row['description'], 'cover_url' => $row['cover_url'], 'is_default' => (int)$row['is_default'], 'created_at' => $row['created_at']];
        }, $rows)]);
    }

    public static function createPlaylist()
    {
        $user = \Auth::requireLogin();
        $name = trim(\Request::str('name'));
        if ($name === '') \Response::json(422, '歌单名称不能为空');
        if (mb_strlen($name) > 100) \Response::json(422, '歌单名称不能超过100字');
        $table = \Database::table('music_playlists');
        for ($attempt = 0; $attempt < 8; $attempt++) {
            $publicId = random_int(100000000, 999999999);
            try {
                \Database::execute("INSERT INTO {$table} (`user_id`,`name`,`description`,`public_id`,`is_default`,`status`,`created_at`,`updated_at`) VALUES (?,?,?,?,0,1,?,?)", [$user['id'], $name, trim(\Request::str('description')) ?: null, $publicId, now(), now()]);
                $id = (int)\Database::lastInsertId();
                $playlist = \Database::fetch("SELECT id, public_id, name, description, is_default FROM {$table} WHERE id = ?", [$id]);
                record_sync_operation('music_playlists', $id, 'insert', $playlist);
                \Response::success(['playlist' => ['id' => $id, 'playlist_id' => (int)$playlist['public_id'], 'name' => $playlist['name'], 'description' => $playlist['description'], 'is_default' => 0]], '歌单已创建');
            } catch (\Throwable $e) {
                if ($attempt === 7) throw $e;
            }
        }
    }

    public static function playlist()
    {
        $user = \Auth::requireLogin();
        $publicId = \Request::int('id');
        $table = \Database::table('music_playlists');
        $playlist = \Database::fetch("SELECT * FROM {$table} WHERE user_id = ? AND public_id = ? AND status = 1 LIMIT 1", [$user['id'], $publicId]);
        if (!$playlist) \Response::json(404, '歌单不存在');
        \Response::success(['playlist' => ['id' => (int)$playlist['id'], 'playlist_id' => (int)$playlist['public_id'], 'name' => $playlist['name'], 'is_default' => (int)$playlist['is_default']], 'tracks' => self::tracks((int)$playlist['id'])]);
    }

    public static function addTrack()
    {
        $user = \Auth::requireLogin();
        $playlist = self::ownedPlaylist((int)$user['id'], \Request::int('playlist_id'));
        $url = trim(\Request::str('url'));
        $uuid = strtolower(trim(\Request::str('music_uuid')));
        if ($uuid !== '') {
            $music = MusicLibraryController::find($uuid);
            if (!$music) \Response::json(404, '歌曲不存在');
            $url = $music['audio_url'];
            $lyricsUrl = $music['lyrics_url'];
            $coverUrl = $music['cover_url'];
            $title = $music['title'];
            $artist = $music['artist'];
        } else {
            if (!filter_var($url, FILTER_VALIDATE_URL) || !in_array(parse_url($url, PHP_URL_SCHEME), ['http', 'https'], true)) \Response::json(422, '歌曲地址无效');
            $lyricsUrl = trim(\Request::str('lyrics_url')) ?: null;
            $coverUrl = trim(\Request::str('cover_url')) ?: null;
            $title = trim(\Request::str('title')) ?: '音乐';
            $artist = trim(\Request::str('artist'));
        }
        $tracks = \Database::table('music_playlist_tracks');
        $key = hash('sha256', $url);
        $existing = \Database::fetch("SELECT id FROM {$tracks} WHERE playlist_id = ? AND music_key = ? LIMIT 1", [$playlist['id'], $key]);
        if ($existing) \Response::success(['added' => false], '歌曲已在歌单中');
        try {
            \Database::execute("INSERT INTO {$tracks} (`playlist_id`,`user_id`,`music_uuid`,`music_key`,`music_url`,`lyrics_url`,`cover_url`,`title`,`artist`,`sort_order`,`created_at`,`updated_at`) VALUES (?,?,?,?,?,?,?,?,?,0,?,?)", [$playlist['id'], $user['id'], $uuid ?: null, $key, $url, $lyricsUrl, $coverUrl, $title, $artist, now(), now()]);
        } catch (\Throwable $e) {
            if (\Database::fetch("SELECT id FROM {$tracks} WHERE playlist_id = ? AND music_key = ? LIMIT 1", [$playlist['id'], $key])) \Response::success(['added' => false], '歌曲已在歌单中');
            throw $e;
        }
        $id = (int)\Database::lastInsertId();
        record_sync_operation('music_playlist_tracks', $id, 'insert', \Database::fetch("SELECT * FROM {$tracks} WHERE id = ?", [$id]));
        \Response::success(['added' => true], '已加入歌单');
    }

    public static function removeTrack()
    {
        $user = \Auth::requireLogin();
        $playlist = self::ownedPlaylist((int)$user['id'], \Request::int('playlist_id'));
        $tracks = \Database::table('music_playlist_tracks');
        $row = \Database::fetch("SELECT * FROM {$tracks} WHERE id = ? AND playlist_id = ? LIMIT 1", [\Request::int('track_id'), $playlist['id']]);
        if (!$row) \Response::json(404, '歌曲不在歌单中');
        \Database::execute("DELETE FROM {$tracks} WHERE id = ?", [$row['id']]);
        record_sync_operation('music_playlist_tracks', (int)$row['id'], 'delete', $row);
        \Response::success([], '已移出歌单');
    }

    private static function ownedPlaylist($userId, $publicId)
    {
        $table = \Database::table('music_playlists');
        $playlist = \Database::fetch("SELECT * FROM {$table} WHERE user_id = ? AND public_id = ? AND status = 1 LIMIT 1", [$userId, $publicId]);
        if (!$playlist) \Response::json(404, '歌单不存在');
        return $playlist;
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
            self::ensurePublicId($playlist);
            return $playlist;
        }

        try {
            \Database::execute(
                "INSERT INTO {$playlists}
                 (`user_id`,`name`,`description`,`default_key`,`public_id`,`is_default`,`status`,`created_at`,`updated_at`)
                 VALUES (?,?,?,?,?,?,1,?,?)",
                [$userId, '我喜欢', '系统默认收藏歌单', $userId, self::newPublicId(), 1, now(), now()]
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

    private static function ensurePublicId($playlist)
    {
        if (!empty($playlist['public_id'])) return;
        $table = \Database::table('music_playlists');
        for ($attempt = 0; $attempt < 8; $attempt++) {
            try {
                $id = self::newPublicId();
                \Database::execute("UPDATE {$table} SET public_id = ?, updated_at = ? WHERE id = ? AND (public_id IS NULL OR public_id = 0)", [$id, now(), $playlist['id']]);
                $saved = \Database::fetch("SELECT public_id FROM {$table} WHERE id = ? LIMIT 1", [$playlist['id']]);
                if (!empty($saved['public_id'])) {
                    $playlist['public_id'] = $saved['public_id'];
                    return;
                }
            } catch (\Throwable $e) { if ($attempt === 7) throw $e; }
        }
    }

    private static function newPublicId()
    {
        return random_int(100000000, 999999999);
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
