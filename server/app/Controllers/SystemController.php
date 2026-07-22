<?php

namespace App\Controllers;

class SystemController
{
    public static function ping()
    {
        $config = \load_server_config();

        \Response::success([
            'server_id'   => $config ? $config['server_id'] : 0,
            'server_name' => $config ? $config['server_name'] : 'unknown',
            'timestamp'   => now(),
        ], 'pong');
    }

    public static function servers()
    {
        $config = \load_server_config();
        $configured = $config['servers'] ?? [];
        $servers = [];

        foreach (is_array($configured) ? $configured : [] as $server) {
            $url = self::normalizeApiEntry($server['url'] ?? '');
            $id = (int)($server['id'] ?? 0);
            if ($id <= 0 || $url === '') {
                continue;
            }
            $servers[] = [
                'id' => $id,
                'name' => trim((string)($server['name'] ?? '服务器 ' . $id)),
                'url' => $url,
                'weight' => max(1, (int)($server['weight'] ?? 5)),
            ];
        }

        if (empty($servers) && $config) {
            $url = self::normalizeApiEntry($config['server_url'] ?? '');
            if ($url !== '') {
                $servers[] = [
                    'id' => max(1, (int)($config['server_id'] ?? 1)),
                    'name' => trim((string)($config['server_name'] ?? '默认服务器')),
                    'url' => $url,
                    'weight' => 5,
                ];
            }
        }

        \Response::success([
            'servers' => $servers,
            'updated_at' => now(),
        ]);
    }

    public static function health()
    {
        $config = \load_server_config();

        $dbStatus = 'ok';
        try {
            \Database::pdo()->query('SELECT 1');
        } catch (\Throwable $e) {
            $dbStatus = 'error: ' . $e->getMessage();
        }

        $pendingOps = 0;
        if ($config) {
            $logTable = \Database::table('sync_operation_log');
            $row = \Database::fetch(
                "SELECT COUNT(*) AS cnt FROM {$logTable} WHERE synced_at IS NULL"
            );
            $pendingOps = $row ? (int)$row['cnt'] : 0;
        }

        $serverStatus = [];
        if ($config) {
            $statusTable = \Database::table('sync_server_status');
            $serverStatus = \Database::fetchAll("SELECT * FROM {$statusTable}");
        }

        \Response::success([
            'server_id'      => $config ? $config['server_id'] : 0,
            'server_name'    => $config ? $config['server_name'] : 'unknown',
            'timestamp'      => now(),
            'db_status'      => $dbStatus,
            'pending_ops'    => $pendingOps,
            'server_status'  => $serverStatus,
        ]);
    }

    public static function syncTrigger()
    {
        $secret = \Request::str('secret');
        $config = \load_server_config();

        if ($config && !empty($config['sync']['sync_token'])) {
            if ($secret !== $config['sync']['sync_token']) {
                \Response::json(403, '同步密钥错误');
            }
        }

        $results = \sync_run_all();

        // 触发请求采样同步
        \Response::success($results, '同步完成');
    }

    public static function syncPush()
    {
        $config = \load_server_config();
        if (!$config) {
            \Response::json(500, 'servers.php not found');
        }

        self::requireSyncAuth();

        $peerServerId = \Request::int('server_id', 0);
        if ($peerServerId <= 0) {
            $peerServerId = null;
        }

        $operations = \sync_get_unsynced_ops($config['sync']['batch_size']);

        \Response::success([
            'server_id'  => $config['server_id'],
            'operations' => $operations,
        ]);
    }

    public static function syncPull()
    {
        self::requireSyncAuth();

        $requesterServerId = \Request::int('server_id');
        $afterId = \Request::int('after_id', 0);

        if ($requesterServerId <= 0) {
            \Response::json(422, '参数错误：server_id');
        }

        $config = \load_server_config();

        $logTable = \Database::table('sync_operation_log');

        $batchSize = (int)($config ? $config['sync']['batch_size'] : 100);
        $operations = \Database::fetchAll(
            "SELECT id, server_id, src_op_id, op_type, table_name, row_id, row_data, created_at
             FROM {$logTable}
             WHERE server_id != ? AND id > ?
             ORDER BY id ASC
             LIMIT {$batchSize}",
            [$requesterServerId, $afterId]
        );

        $maxId = 0;
        if (!empty($operations)) {
            $ids = array_column($operations, 'id');
            $maxId = (int)max($ids);
        }

        \Response::success([
            'operations' => $operations,
            'max_id'     => $maxId,
        ]);
    }

    public static function syncReceive()
    {
        self::requireSyncAuth();

        $input = \Request::input();
        $sourceServerId = (int)($input['source_server_id'] ?? 0);
        $operations = $input['operations'] ?? [];

        if ($sourceServerId <= 0 || empty($operations)) {
            \Response::json(422, '参数错误');
        }

        $result = \sync_receive_ops($sourceServerId, $operations);

        \Response::success($result, '接收完成');
    }

    public static function syncStatus()
    {
        \Auth::requireLogin();

        $statusTable = \Database::table('sync_server_status');
        $logTable = \Database::table('sync_operation_log');

        $servers = \Database::fetchAll("SELECT * FROM {$statusTable} ORDER BY server_id ASC");

        $pending = \Database::fetch(
            "SELECT COUNT(*) AS cnt FROM {$logTable} WHERE synced_at IS NULL"
        );

        \Response::success([
            'servers'          => $servers,
            'pending_count'    => $pending ? (int)$pending['cnt'] : 0,
        ]);
    }

    private static function requireSyncAuth()
    {
        $config = \load_server_config();
        if (!$config) {
            \Response::json(500, 'servers.php not found');
        }

        $token = $config['sync']['sync_token'] ?? '';
        if ($token === '') {
            return;
        }

        $headerToken = '';
        if (isset($_SERVER['HTTP_SYNC_TOKEN'])) {
            $headerToken = $_SERVER['HTTP_SYNC_TOKEN'];
        }

        if ($headerToken !== $token) {
            \Response::json(401, '同步认证失败');
        }
    }

    private static function normalizeApiEntry($url)
    {
        $url = rtrim(trim((string)$url), '/');
        if (!filter_var($url, FILTER_VALIDATE_URL)) {
            return '';
        }
        $path = (string)(parse_url($url, PHP_URL_PATH) ?? '');
        if (substr($path, -4) !== '.php') {
            $url .= '/index.php';
        }
        return $url;
    }
}
