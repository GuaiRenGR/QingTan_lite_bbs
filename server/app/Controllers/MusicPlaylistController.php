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
        $musicUrl = normalize_forum_media_url(\Request::str('music_url'));
        $lyricsUrl = \Request::str('lyrics_url');
        $title = \Request::str('title', '音乐');

        if ($musicUrl === '') {
            \Response::json(422, '音乐链接无效');
        }
        if (strlen($musicUrl) > 1000) {
            \Response::json(422, '音乐链接过长');
        }
        if ($lyricsUrl !== '' && !validate_remote_url($lyricsUrl)) {
            \Response::json(422, '歌词链接无效');
        }
        if (strlen($lyricsUrl) > 1000) {
            \Response::json(422, '歌词链接过长');
        }
        $title = function_exists('mb_substr')
            ? mb_substr($title, 0, 255, 'UTF-8')
            : substr($title, 0, 255);

        $playlist = self::ensureDefaultPlaylist((int)$user['id']);
        $tracks = \Database::table('music_playlist_tracks');
        $urlHash = hash('sha256', $musicUrl);
        $existing = \Database::fetch(
            "SELECT * FROM {$tracks}
             WHERE playlist_id = ? AND music_key = ?
             LIMIT 1",
            [$playlist['id'], $urlHash]
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
        \Database::execute(
            "INSERT INTO {$tracks}
             (`playlist_id`,`user_id`,`music_key`,`music_url`,`lyrics_url`,`title`,`sort_order`,`created_at`,`updated_at`)
             VALUES (?,?,?,?,?,?,?,?,?)",
            [
                $playlist['id'],
                $user['id'],
                $urlHash,
                $musicUrl,
                $lyricsUrl,
                $title === '' ? '音乐' : $title,
                (int)($nextSort['next_sort'] ?? 1),
                now(),
                now(),
            ]
        );
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
            "SELECT id, music_url AS url, lyrics_url, title, sort_order, created_at
             FROM {$tracks}
             WHERE playlist_id = ? AND status = 1
             ORDER BY sort_order ASC, id DESC",
            [$playlistId]
        );

        return array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'url' => $row['url'],
                'title' => $row['title'] ?: '音乐',
                'lyrics_url' => $row['lyrics_url'] ?: null,
                'sort_order' => (int)$row['sort_order'],
                'created_at' => $row['created_at'],
            ];
        }, $rows);
    }
}
