<?php

namespace App\Controllers;

class NeteaseMusicController
{
    private const API_BASE = 'https://music.163.com';

    public static function search()
    {
        $keyword = trim(\Request::str('keyword'));
        $page = max(1, \Request::int('page', 1));
        $limit = min(50, max(1, \Request::int('limit', 30)));

        if ($keyword === '') {
            \Response::json(422, '请输入歌曲名或歌手');
        }

        $payload = self::requestJson('/api/cloudsearch/pc', [
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
                $playback = self::requestJson('/api/song/enhance/player/url', [
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
                'url' => request_origin() . '/index.php?route=netease/play&id=' . $id,
                'lyrics_url' => request_origin() . '/index.php?route=netease/lyrics&id=' . $id,
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
        $id = (int)($_GET['id'] ?? \Request::int('id'));
        if ($id <= 0) {
            http_response_code(422);
            exit;
        }

        try {
            $payload = self::requestJson('/api/song/enhance/player/url', [
                'ids' => '[' . $id . ']',
                'br' => 320000,
            ]);
            $url = trim((string)($payload['data'][0]['url'] ?? ''));
            if ($url === '') {
                http_response_code(404);
                exit;
            }
            $url = preg_replace('#^http://#i', 'https://', $url);
            if (!filter_var($url, FILTER_VALIDATE_URL)) {
                http_response_code(502);
                exit;
            }
            header('Cache-Control: no-store');
            header('Location: ' . $url, true, 302);
        } catch (\Throwable $e) {
            log_error('[NeteasePlay] ' . $e->getMessage());
            http_response_code(502);
        }
        exit;
    }

    public static function lyrics()
    {
        $id = \Request::int('id');
        if ($id <= 0) {
            http_response_code(422);
            exit;
        }

        try {
            $payload = self::requestJson('/api/song/lyric', [
                'id' => $id,
                'lv' => -1,
                'tv' => -1,
            ]);
            $lyrics = trim((string)($payload['lrc']['lyric'] ?? ''));
            header('Content-Type: text/plain; charset=utf-8');
            header('Cache-Control: public, max-age=86400');
            echo $lyrics;
        } catch (\Throwable $e) {
            log_error('[NeteaseLyrics] ' . $e->getMessage());
            http_response_code(502);
        }
        exit;
    }

    private static function requestJson($path, array $query)
    {
        $url = self::API_BASE . $path . '?' . http_build_query($query);
        $headers = [
            'Accept: application/json',
            'Referer: https://music.163.com/',
            'User-Agent: Mozilla/5.0 (Linux; Android 10; Qingtan) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36',
        ];

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
                throw new \RuntimeException('网易云音乐接口不可用');
            }
        }

        $decoded = json_decode($body, true);
        if (!is_array($decoded)) {
            throw new \RuntimeException('网易云音乐返回格式异常');
        }
        return $decoded;
    }
}
