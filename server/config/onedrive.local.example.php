<?php

if (!defined('FX_ROOT')) {
    http_response_code(403);
    exit('403 Forbidden');
}

return [
    'client_id' => '',
    'client_secret' => '',
    'refresh_token' => '',
    'tenant' => 'common',
    'base_path' => 'QingTan',
    'scope' => 'offline_access Files.ReadWrite.All',
];
