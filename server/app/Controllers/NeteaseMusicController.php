<?php

namespace App\Controllers;

class NeteaseMusicController
{
    private const OFFICIAL_API_BASE = 'https://music.163.com';
    private const MUSIC_API_BASE = 'https://music-api.gdstudio.xyz/api.php';
    private const OFFICIAL_SOURCE = 'netease_official';
    private const MUSIC_SOURCES = [
        'netease',
        'tencent',
        'kuwo',
        'tidal',
        'qobuz',
        'joox',
        'bilibili',
        'apple',
        'ytmusic',
        'spotify',
    ];

    public static function search()
    {
        $keyword = trim(\Request::str('keyword'));
        $page = max(1, \Request::int('page', 1));
        $limit = min(50, max(1, \Request::int('limit', 30)));
        $source = self::searchSource();

        if ($keyword === '') {
            \Response::json(422, '请输入歌曲名或歌手');
        }

        if ($source === self::OFFICIAL_SOURCE) {
            return self::searchOfficial($keyword, $page, $limit);
        }

        $payload = self::requestMusicApi([
            'types' => 'search',
            'source' => $source,
            'name' => $keyword,
            'count' => $limit,
            'pages' => $page,
        ]);
        $songs = self::extractList($payload);
        $items = [];

        foreach ($songs as $song) {
            if (!is_array($song)) {
                continue;
            }
            $id = trim((string)($song['id'] ?? ''));
            if ($id === '') {
                continue;
            }
            $artists = $song['artist'] ?? [];
            if (is_array($artists)) {
                $artists = implode(' / ', array_values(array_filter(array_map('strval', $artists))));
            }
            $picId = trim((string)($song['pic_id'] ?? ''));
            $lyricId = trim((string)($song['lyric_id'] ?? $id));
            $query = '&source=' . rawurlencode($source);
            $coverUrl = self::directMediaUrl($picId);
            if ($coverUrl === '' && $picId !== '') {
                $coverUrl = request_origin() . '/index.php?route=netease/cover&id='
                    . rawurlencode($picId) . $query;
            }
            $items[] = [
                'id' => $id,
                'title' => (string)($song['name'] ?? '未知歌曲'),
                'artist' => trim((string)$artists),
                'album' => (string)($song['album'] ?? ''),
                'cover_url' => $coverUrl,
                'duration_ms' => 0,
                'playable' => true,
                'url' => request_origin() . '/index.php?route=netease/play&id='
                    . rawurlencode($id) . $query,
                'lyrics_url' => request_origin() . '/index.php?route=netease/lyrics&id='
                    . rawurlencode($lyricId) . $query,
            ];
        }

        \Response::success([
            'list' => $items,
            'page' => $page,
            'has_more' => count($items) >= $limit,
        ]);
    }

    public static function play()
    {
        // Media players may probe the URL with HEAD before issuing GET.
        $id = trim((string)($_GET['id'] ?? ''));
        $source = self::mediaSource();
        if ($id === '') {
            http_response_code(422);
            exit;
        }

        try {
            if ($source === self::OFFICIAL_SOURCE) {
                if (!preg_match('/^\d+$/D', $id) || (int)$id <= 0) {
                    http_response_code(422);
                    exit;
                }
                $payload = self::requestOfficialJson('/api/song/enhance/player/url', [
                    'ids' => '[' . (int)$id . ']',
                    'br' => 320000,
                ]);
                $url = trim((string)($payload['data'][0]['url'] ?? ''));
            } else {
                $payload = self::requestMusicApi([
                    'types' => 'url',
                    'source' => $source,
                    'id' => $id,
                    'br' => 999,
                ]);
                $url = trim((string)($payload['url'] ?? ''));
            }
            self::redirectToMedia($url);
        } catch (\Throwable $e) {
            log_error('[MusicPlay] ' . $e->getMessage());
            http_response_code(502);
        }
        exit;
    }

    public static function cover()
    {
        $id = trim((string)($_GET['id'] ?? ''));
        $source = self::musicApiSource();
        if ($id === '') {
            http_response_code(422);
            exit;
        }

        try {
            $payload = self::requestMusicApi([
                'types' => 'pic',
                'source' => $source,
                'id' => $id,
                'size' => 500,
            ]);
            self::redirectToMedia(trim((string)($payload['url'] ?? '')), 86400);
        } catch (\Throwable $e) {
            log_error('[MusicCover] ' . $e->getMessage());
            http_response_code(502);
        }
        exit;
    }

    public static function lyrics()
    {
        $id = trim((string)($_GET['id'] ?? ''));
        $source = self::mediaSource();
        if ($id === '') {
            http_response_code(422);
            exit;
        }

        try {
            if ($source === self::OFFICIAL_SOURCE) {
                if (!preg_match('/^\d+$/D', $id) || (int)$id <= 0) {
                    http_response_code(422);
                    exit;
                }
                $payload = self::requestOfficialJson('/api/song/lyric', [
                    'id' => (int)$id,
                    'lv' => -1,
                    'tv' => -1,
                ]);
                $lyrics = trim((string)($payload['lrc']['lyric'] ?? ''));
            } else {
                $payload = self::requestMusicApi([
                    'types' => 'lyric',
                    'source' => $source,
                    'id' => $id,
                ]);
                $lyrics = trim((string)($payload['lyric'] ?? ''));
            }
            header('Content-Type: text/plain; charset=utf-8');
            header('Cache-Control: public, max-age=86400');
            echo $lyrics;
        } catch (\Throwable $e) {
            log_error('[MusicLyrics] ' . $e->getMessage());
            http_response_code(502);
        }
        exit;
    }

    private static function searchOfficial($keyword, $page, $limit)
    {
        $payload = self::requestOfficialJson('/api/cloudsearch/pc', [
            's' => $keyword,
            'type' => 1,
            'limit' => $limit,
            'offset' => ($page - 1) * $limit,
        ]);
        $songs = $payload['result']['songs'] ?? [];
        $playableIds = [];
        $availabilityLoaded = false;
        $songIds = array_values(array_filter(array_map(function ($song) {
            return (int)($song['id'] ?? 0);
        }, is_array($songs) ? $songs : [])));
        if (!empty($songIds)) {
            try {
                $playback = self::requestOfficialJson('/api/song/enhance/player/url', [
                    'ids' => '[' . implode(',', $songIds) . ']',
                    'br' => 320000,
                ]);
                foreach (($playback['data'] ?? []) as $item) {
                    if (!empty($item['url'])) {
                        $playableIds[(int)($item['id'] ?? 0)] = true;
                    }
                }
                $availabilityLoaded = true;
            } catch (\Throwable $e) {
                log_error('[NeteaseAvailability] ' . $e->getMessage());
            }
        }
        $items = [];

        foreach (is_array($songs) ? $songs : [] as $song) {
            $id = (int)($song['id'] ?? 0);
            if ($id <= 0) {
                continue;
            }
            $artists = $song['artists'] ?? $song['ar'] ?? [];
            $artistNames = [];
            foreach (is_array($artists) ? $artists : [] as $artist) {
                $name = trim((string)($artist['name'] ?? ''));
                if ($name !== '') {
                    $artistNames[] = $name;
                }
            }
            $album = $song['album'] ?? $song['al'] ?? [];
            $playable = !$availabilityLoaded || isset($playableIds[$id]);
            $sourceQuery = '&source=' . self::OFFICIAL_SOURCE;
            $items[] = [
                'id' => $id,
                'title' => (string)($song['name'] ?? '未知歌曲'),
                'artist' => implode(' / ', $artistNames),
                'album' => (string)($album['name'] ?? ''),
                'cover_url' => preg_replace(
                    '#^http://#i',
                    'https://',
                    (string)($album['picUrl'] ?? '')
                ),
                'duration_ms' => (int)($song['duration'] ?? $song['dt'] ?? 0),
                'playable' => $playable,
                'url' => request_origin() . '/index.php?route=netease/play&id=' . $id . $sourceQuery,
                'lyrics_url' => request_origin() . '/index.php?route=netease/lyrics&id=' . $id . $sourceQuery,
            ];
        }

        \Response::success([
            'list' => $items,
            'page' => $page,
            'has_more' => count($items) >= $limit,
        ]);
    }

    private static function searchSource()
    {
        $source = trim((string)($_GET['source'] ?? 'netease'));
        if ($source === self::OFFICIAL_SOURCE || in_array($source, self::MUSIC_SOURCES, true)) {
            return $source;
        }
        \Response::json(422, '不支持的音乐源');
    }

    private static function mediaSource()
    {
        // Keep source-less legacy playback URLs on the original official API.
        $source = trim((string)($_GET['source'] ?? self::OFFICIAL_SOURCE));
        if ($source === self::OFFICIAL_SOURCE || in_array($source, self::MUSIC_SOURCES, true)) {
            return $source;
        }
        http_response_code(422);
        exit;
    }

    private static function musicApiSource()
    {
        $source = trim((string)($_GET['source'] ?? 'netease'));
        if (in_array($source, self::MUSIC_SOURCES, true)) {
            return $source;
        }
        http_response_code(422);
        exit;
    }

    private static function extractList($payload)
    {
        if (!is_array($payload)) {
            return [];
        }
        if (isset($payload['data']) && is_array($payload['data'])) {
            return $payload['data'];
        }
        if (isset($payload['list']) && is_array($payload['list'])) {
            return $payload['list'];
        }
        return array_values($payload) === $payload ? $payload : [];
    }

    private static function redirectToMedia($url, $maxAge = 0)
    {
        $url = self::directMediaUrl($url);
        if ($url === '') {
            http_response_code(404);
            exit;
        }
        header($maxAge > 0 ? 'Cache-Control: public, max-age=' . $maxAge : 'Cache-Control: no-store');
        header('Location: ' . $url, true, 302);
        exit;
    }

    private static function directMediaUrl($url)
    {
        $url = trim((string)$url);
        if (strpos($url, '//') === 0) {
            $url = 'https:' . $url;
        }
        $url = preg_replace('#^http://#i', 'https://', $url);
        return filter_var($url, FILTER_VALIDATE_URL) ? $url : '';
    }

    private static function requestMusicApi(array $query)
    {
        return self::requestJson(self::MUSIC_API_BASE . '?' . http_build_query($query), [
            'Accept: application/json',
            'Referer: https://music.gdstudio.xyz/',
            'User-Agent: Mozilla/5.0 (Linux; Android 10; Qingtan) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36',
        ]);
    }

    private static function requestOfficialJson($path, array $query)
    {
        return self::requestJson(self::OFFICIAL_API_BASE . $path . '?' . http_build_query($query), [
            'Accept: application/json',
            'Referer: https://music.163.com/',
            'User-Agent: Mozilla/5.0 (Linux; Android 10; Qingtan) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36',
        ]);
    }

    private static function requestJson($url, array $headers)
    {
        if (function_exists('curl_init')) {
            $curl = curl_init($url);
            curl_setopt_array($curl, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_CONNECTTIMEOUT => 5,
                CURLOPT_TIMEOUT => 12,
                CURLOPT_HTTPHEADER => $headers,
            ]);
            $body = curl_exec($curl);
            $status = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
            $error = curl_error($curl);
            if ($body === false || $status < 200 || $status >= 300) {
                throw new \RuntimeException($error !== '' ? $error : 'HTTP ' . $status);
            }
        } else {
            $context = stream_context_create([
                'http' => [
                    'method' => 'GET',
                    'timeout' => 12,
                    'ignore_errors' => true,
                    'header' => implode("\r\n", $headers),
                ],
            ]);
            $body = @file_get_contents($url, false, $context);
            if ($body === false) {
                throw new \RuntimeException('音乐接口不可用');
            }
        }

        $decoded = json_decode($body, true);
        if (!is_array($decoded)) {
            throw new \RuntimeException('音乐接口返回格式异常');
        }
        return $decoded;
    }
}
