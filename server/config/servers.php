<?php
/**
 * 多服务器配置
 * 每台服务器部署时需根据自身身份修改此文件
 */

$serverId = 1;

return [
    'server_id'   => $serverId,
    'server_name' => '主服务器',

    'server_url' => 'http://newbbs.hj1bbs.top',

    'servers' => [
        ['id' => 1, 'name' => '主服务器',   'url' => 'http://newbbs.hj1bbs.top', 'weight' => 10],
        ['id' => 2, 'name' => '备用服务器', 'url' => 'http://s2.example.com',    'weight' => 5],
        ['id' => 3, 'name' => '备用服务器', 'url' => 'http://s3.example.com',    'weight' => 5],
    ],

    'sync' => [
        'sync_token'  => 'change-this-to-a-secure-random-token',
        'batch_size'  => 100,
        'retry_times' => 3,
        'timeout'     => 30,
        'sample_rate' => 10,
    ],
];
