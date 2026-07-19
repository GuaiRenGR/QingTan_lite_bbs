<?php

class OneDriveService
{
    private $config;

    public function __construct()
    {
        $file = FX_ROOT . '/config/onedrive.php';

        if (!file_exists($file)) {
            throw new Exception('OneDrive 配置文件不存在');
        }

        $this->config = require $file;
    }

    public function upload($localFile, $originalName, $type, $mime)
    {
        if (!file_exists($localFile)) {
            throw new Exception('上传临时文件不存在');
        }

        $type = in_array($type, ['music', 'video', 'attachments'], true) ? $type : 'images';

        $ext = $this->guessExt($originalName, $mime, $type);

        $folder = trim($this->config['base_path'], '/')
            . '/'
            . $type
            . '/'
            . date('Y')
            . '/'
            . date('m');

        $this->ensureFolder($folder);

        $fileName = date('YmdHis') . '_' . bin2hex(random_bytes(8)) . '.' . $ext;
        $remotePath = $folder . '/' . $fileName;

        $accessToken = $this->accessToken();

        $endpoint = 'https://graph.microsoft.com/v1.0/me/drive/root:/'
            . $this->encodePath($remotePath)
            . ':/content';

        $binary = file_get_contents($localFile);

        $response = $this->curl(
            $endpoint,
            'PUT',
            [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: ' . $mime,
            ],
            $binary
        );

        if ($response['code'] < 200 || $response['code'] >= 300) {
            throw new Exception('OneDrive 上传失败：' . $response['body']);
        }

        $item = json_decode($response['body'], true);

        if (!is_array($item) || empty($item['id'])) {
            throw new Exception('OneDrive 上传返回异常');
        }

        $share = $this->createShareLink($item['id']);

        return [
            'item_id' => $item['id'],
            'drive_id' => $item['parentReference']['driveId'] ?? '',
            'name' => $item['name'] ?? $fileName,
            'size' => $item['size'] ?? filesize($localFile),
            'mime' => $mime,
            'path' => '/' . $remotePath,
            'share_url' => $share['share_url'],
            'file_url' => '',
        ];
    }

    private function accessToken()
    {
        $cacheFile = FX_ROOT . '/cache/onedrive_token.json';

        if (file_exists($cacheFile)) {
            $data = json_decode(file_get_contents($cacheFile), true);

            if (
                is_array($data)
                && !empty($data['access_token'])
                && !empty($data['expired_at'])
                && $data['expired_at'] > time() + 120
            ) {
                return $data['access_token'];
            }
        }

        $refreshToken = $this->config['refresh_token'];

        if (file_exists($cacheFile)) {
            $old = json_decode(file_get_contents($cacheFile), true);
            if (!empty($old['refresh_token'])) {
                $refreshToken = $old['refresh_token'];
            }
        }

        $tenant = $this->config['tenant'] ?: 'common';

        $url = "https://login.microsoftonline.com/{$tenant}/oauth2/v2.0/token";

        $post = [
            'client_id' => $this->config['client_id'],
            'grant_type' => 'refresh_token',
            'refresh_token' => $refreshToken,
            'scope' => $this->config['scope'] ?: 'offline_access Files.ReadWrite.All',
        ];

        if (!empty($this->config['client_secret'])) {
            $post['client_secret'] = $this->config['client_secret'];
        }

        $response = $this->curl(
            $url,
            'POST',
            [
                'Content-Type: application/x-www-form-urlencoded',
            ],
            http_build_query($post)
        );

        if ($response['code'] < 200 || $response['code'] >= 300) {
            throw new Exception('OneDrive access_token 刷新失败：' . $response['body']);
        }

        $data = json_decode($response['body'], true);

        if (empty($data['access_token'])) {
            throw new Exception('OneDrive access_token 返回为空');
        }

        $save = [
            'access_token' => $data['access_token'],
            'refresh_token' => $data['refresh_token'] ?? $refreshToken,
            'expired_at' => time() + intval($data['expires_in'] ?? 3600),
            'created_at' => time(),
        ];

        if (!is_dir(dirname($cacheFile))) {
            mkdir(dirname($cacheFile), 0755, true);
        }

        file_put_contents($cacheFile, json_encode($save));

        return $data['access_token'];
    }

    private function createShareLink($itemId)
    {
        $accessToken = $this->accessToken();

        $endpoint = 'https://graph.microsoft.com/v1.0/me/drive/items/'
            . rawurlencode($itemId)
            . '/createLink';

        $payload = json_encode([
            'type' => 'view',
            'scope' => 'anonymous',
        ]);

        $response = $this->curl(
            $endpoint,
            'POST',
            [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json',
            ],
            $payload
        );

        if ($response['code'] < 200 || $response['code'] >= 300) {
            throw new Exception('OneDrive 创建分享链接失败：' . $response['body']);
        }

        $data = json_decode($response['body'], true);

        $webUrl = $data['link']['webUrl'] ?? '';

        if (!$webUrl) {
            throw new Exception('OneDrive 分享链接为空');
        }

        return [
            'share_url' => $webUrl,
        ];
    }

    public function deleteFile($itemId)
    {
        $accessToken = $this->accessToken();

        $endpoint = 'https://graph.microsoft.com/v1.0/me/drive/items/'
            . rawurlencode($itemId);

        $this->curl($endpoint, 'DELETE', [
            'Authorization: Bearer ' . $accessToken,
        ]);
    }

    public function getFileUrl($itemId)
    {
        $accessToken = $this->accessToken();

        $endpoint = 'https://graph.microsoft.com/v1.0/me/drive/items/'
            . rawurlencode($itemId)
            . '/content';

        $ch = curl_init($endpoint);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $accessToken,
        ]);
        curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $redirectUrl = curl_getinfo($ch, CURLINFO_REDIRECT_URL);
        curl_close($ch);

        if ($code === 302 && $redirectUrl) {
            return $redirectUrl;
        }

        throw new Exception('OneDrive 获取文件直链失败');
    }

    private function ensureFolder($folder)
    {
        $accessToken = $this->accessToken();

        $parts = array_values(array_filter(explode('/', trim($folder, '/'))));
        $current = '';

        foreach ($parts as $part) {
            $parent = $current;
            $current = $current ? $current . '/' . $part : $part;

            $checkUrl = 'https://graph.microsoft.com/v1.0/me/drive/root:/'
                . $this->encodePath($current);

            $check = $this->curl(
                $checkUrl,
                'GET',
                [
                    'Authorization: Bearer ' . $accessToken,
                ]
            );

            if ($check['code'] >= 200 && $check['code'] < 300) {
                continue;
            }

            if ($parent) {
                $createUrl = 'https://graph.microsoft.com/v1.0/me/drive/root:/'
                    . $this->encodePath($parent)
                    . ':/children';
            } else {
                $createUrl = 'https://graph.microsoft.com/v1.0/me/drive/root/children';
            }

            $payload = json_encode([
                'name' => $part,
                'folder' => new stdClass(),
                '@microsoft.graph.conflictBehavior' => 'fail',
            ]);

            $create = $this->curl(
                $createUrl,
                'POST',
                [
                    'Authorization: Bearer ' . $accessToken,
                    'Content-Type: application/json',
                ],
                $payload
            );

            if (
                !($create['code'] >= 200 && $create['code'] < 300)
                && strpos($create['body'], 'nameAlreadyExists') === false
            ) {
                throw new Exception('OneDrive 创建目录失败：' . $create['body']);
            }
        }
    }

    private function guessExt($originalName, $mime, $type)
    {
        $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));

        $allowImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        $allowMusic = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac', 'lrc'];

        if ($type === 'images') {
            if (in_array($ext, $allowImage, true)) {
                return $ext;
            }

            if ($mime === 'image/jpeg') return 'jpg';
            if ($mime === 'image/png') return 'png';
            if ($mime === 'image/gif') return 'gif';
            if ($mime === 'image/webp') return 'webp';

            throw new Exception('不支持的图片格式');
        }

        if ($type === 'music') {
            if (in_array($ext, $allowMusic, true)) {
                return $ext;
            }

            if ($mime === 'audio/mpeg') return 'mp3';
            if ($mime === 'audio/mp4') return 'm4a';
            if ($mime === 'audio/aac') return 'aac';
            if ($mime === 'audio/wav') return 'wav';
            if ($mime === 'audio/ogg') return 'ogg';
            if ($mime === 'audio/flac') return 'flac';
            if ($mime === 'text/plain') return 'lrc';

            throw new Exception('不支持的音乐格式');
        }

        if ($type === 'video') {
            $allowVideo = ['mp4', 'webm', 'mov', 'avi', 'mkv'];

            if (in_array($ext, $allowVideo, true)) {
                return $ext;
            }

            if ($mime === 'video/mp4') return 'mp4';
            if ($mime === 'video/webm') return 'webm';
            if ($mime === 'video/quicktime') return 'mov';
            if ($mime === 'video/x-msvideo') return 'avi';
            if ($mime === 'video/x-matroska') return 'mkv';

            throw new Exception('不支持的视频格式');
        }

        // attachments: 允许任意扩展名
        if ($ext !== '') {
            return $ext;
        }

        throw new Exception('未知文件类型');
    }

    private function encodePath($path)
    {
        $parts = explode('/', trim($path, '/'));
        $parts = array_map('rawurlencode', $parts);

        return implode('/', $parts);
    }

    private function curl($url, $method = 'GET', $headers = [], $body = null)
    {
        $ch = curl_init($url);

        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_TIMEOUT, 60);

        if ($body !== null) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
        }

        $bodyText = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);

        curl_close($ch);

        if ($bodyText === false) {
            throw new Exception('Curl 请求失败：' . $error);
        }

        return [
            'code' => $code,
            'body' => $bodyText,
        ];
    }
}
