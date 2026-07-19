<?php

if (!defined('FX_ROOT')) {
    http_response_code(403);
    exit('403 Forbidden');
}

$localConfig = [];
$localFile = __DIR__ . '/onedrive.local.php';

if (is_file($localFile)) {
    $loadedConfig = require $localFile;
    if (is_array($loadedConfig)) {
        $localConfig = $loadedConfig;
    }
}

$readConfig = static function ($key, $environmentKey, $default = '') use ($localConfig) {
    if (array_key_exists($key, $localConfig) && $localConfig[$key] !== '') {
        return $localConfig[$key];
    }

    $environmentValue = getenv($environmentKey);
    if ($environmentValue !== false && $environmentValue !== '') {
        return $environmentValue;
    }

    return $default;
};

return [
    'client_id' => (string)$readConfig('client_id', 'ONEDRIVE_CLIENT_ID'),
    'client_secret' => (string)$readConfig('client_secret', 'ONEDRIVE_CLIENT_SECRET'),
    'refresh_token' => (string)$readConfig('refresh_token', 'ONEDRIVE_REFRESH_TOKEN'),
    'tenant' => (string)$readConfig('tenant', 'ONEDRIVE_TENANT', 'common'),
    'base_path' => (string)$readConfig('base_path', 'ONEDRIVE_BASE_PATH', 'QingTan'),
    'scope' => (string)$readConfig(
        'scope',
        'ONEDRIVE_SCOPE',
        'offline_access Files.ReadWrite.All'
    ),
    'max_image_size' => (int)$readConfig(
        'max_image_size',
        'ONEDRIVE_MAX_IMAGE_SIZE',
        10 * 1024 * 1024
    ),
    'max_music_size' => (int)$readConfig(
        'max_music_size',
        'ONEDRIVE_MAX_MUSIC_SIZE',
        30 * 1024 * 1024
    ),
    'max_video_size' => (int)$readConfig(
        'max_video_size',
        'ONEDRIVE_MAX_VIDEO_SIZE',
        200 * 1024 * 1024
    ),
];
