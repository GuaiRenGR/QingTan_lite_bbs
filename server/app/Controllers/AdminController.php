<?php

namespace App\Controllers;

class AdminController
{
    private static function requireAdmin()
    {
        $user = \Auth::requireLogin();

        if ((int)($user['group_id'] ?? 0) !== 99) {
            \Response::json(403, '无管理员权限', null, 403);
        }

        return $user;
    }

    public static function stats()
    {
        self::requireAdmin();

        $users = \Database::table('users');
        $threads = \Database::table('threads');
        $posts = \Database::table('posts');
        $today = date('Y-m-d');

        $userCount = \Database::fetch("SELECT COUNT(*) AS c FROM {$users}");
        $threadCount = \Database::fetch("SELECT COUNT(*) AS c FROM {$threads}");
        $postCount = \Database::fetch("SELECT COUNT(*) AS c FROM {$posts}");
        $bannedCount = \Database::fetch("SELECT COUNT(*) AS c FROM {$users} WHERE status = 0");
        $todayThreads = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$threads} WHERE DATE(created_at) = ?",
            [$today]
        );
        $todayUsers = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$users} WHERE DATE(created_at) = ?",
            [$today]
        );

        \Response::success([
            'user_count' => (int)($userCount['c'] ?? 0),
            'thread_count' => (int)($threadCount['c'] ?? 0),
            'post_count' => (int)($postCount['c'] ?? 0),
            'banned_count' => (int)($bannedCount['c'] ?? 0),
            'today_threads' => (int)($todayThreads['c'] ?? 0),
            'today_users' => (int)($todayUsers['c'] ?? 0),
        ]);
    }

    public static function users()
    {
        self::requireAdmin();

        $page = max(1, \Request::int('page', 1));
        $pageSize = min(100, max(1, \Request::int('page_size', 20)));
        $keyword = trim(\Request::str('keyword', ''));

        $users = \Database::table('users');
        $offset = ($page - 1) * $pageSize;

        $where = '';
        $params = [];

        if ($keyword !== '') {
            $where = "WHERE username LIKE ? OR nickname LIKE ?";
            $like = '%' . $keyword . '%';
            $params = [$like, $like];
        }

        $countRow = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$users} {$where}",
            $params
        );
        $total = (int)($countRow['c'] ?? 0);

        $list = \Database::fetchAll(
            "SELECT id, username, nickname, email, avatar, group_id, level, score, points,
                    status, permissions, badge_name, badge_color, verify_level,
                    created_at, last_login_at
             FROM {$users}
             {$where}
             ORDER BY id DESC
             LIMIT {$pageSize} OFFSET {$offset}",
            $params
        );

        \Response::success([
            'list' => $list,
            'total' => $total,
            'page' => $page,
            'page_size' => $pageSize,
        ]);
    }

    public static function ban()
    {
        self::requireAdmin();

        $userId = \Request::int('user_id');

        if ($userId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        $users = \Database::table('users');

        $target = \Database::fetch(
            "SELECT id, group_id FROM {$users} WHERE id = ? LIMIT 1",
            [$userId]
        );

        if (!$target) {
            \Response::json(404, '用户不存在');
        }

        if ((int)$target['group_id'] === 99) {
            \Response::json(422, '不能封禁管理员');
        }

        \Database::execute(
            "UPDATE {$users} SET status = 0, updated_at = ? WHERE id = ?",
            [now(), $userId]
        );
        $bannedUser = \Database::fetch("SELECT * FROM {$users} WHERE id = ?", [$userId]);
        record_sync_operation('users', $userId, 'update', $bannedUser);

        // 清除该用户所有 token，强制下线
        $tokens = \Database::table('user_tokens');
        \Database::execute("DELETE FROM {$tokens} WHERE user_id = ?", [$userId]);

        \Response::success(null, '封禁成功');
    }

    public static function unban()
    {
        self::requireAdmin();

        $userId = \Request::int('user_id');

        if ($userId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        $users = \Database::table('users');

        $target = \Database::fetch(
            "SELECT id FROM {$users} WHERE id = ? LIMIT 1",
            [$userId]
        );

        if (!$target) {
            \Response::json(404, '用户不存在');
        }

        \Database::execute(
            "UPDATE {$users} SET status = 1, updated_at = ? WHERE id = ?",
            [now(), $userId]
        );
        $unbannedUser = \Database::fetch("SELECT * FROM {$users} WHERE id = ?", [$userId]);
        record_sync_operation('users', $userId, 'update', $unbannedUser);

        \Response::success(null, '解封成功');
    }

    public static function delete()
    {
        self::requireAdmin();

        $userId = \Request::int('user_id');

        if ($userId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        $users = \Database::table('users');

        $target = \Database::fetch(
            "SELECT id, group_id FROM {$users} WHERE id = ? LIMIT 1",
            [$userId]
        );

        if (!$target) {
            \Response::json(404, '用户不存在');
        }

        if ((int)$target['group_id'] === 99) {
            \Response::json(422, '不能删除管理员');
        }

        // 清除 token
        $tokens = \Database::table('user_tokens');
        \Database::execute("DELETE FROM {$tokens} WHERE user_id = ?", [$userId]);

        // 删除用户
        $delUser = \Database::fetch("SELECT * FROM {$users} WHERE id = ?", [$userId]);
        \Database::execute("DELETE FROM {$users} WHERE id = ?", [$userId]);
        record_sync_operation('users', $userId, 'delete', null, $delUser);

        \Response::success(null, '删除成功');
    }

    public static function create()
    {
        self::requireAdmin();

        $username = \Request::str('username');
        $password = (string)\Request::input('password');
        $nickname = \Request::str('nickname', $username);

        if (!preg_match('/^[A-Za-z0-9_]{3,20}$/', $username)) {
            \Response::json(422, '用户名格式错误（3-20位，仅允许字母、数字、下划线）');
        }

        if (strlen($password) < 8 || strlen($password) > 32) {
            \Response::json(422, '密码长度需为 8-32 位');
        }

        $users = \Database::table('users');

        $exists = \Database::fetch(
            "SELECT id FROM {$users} WHERE username = ? LIMIT 1",
            [$username]
        );

        if ($exists) {
            \Response::json(409, '用户名已存在');
        }

        $hash = password_hash($password, PASSWORD_DEFAULT);
        $now = now();

        \Database::execute(
            "INSERT INTO {$users}
            (`username`,`nickname`,`password_hash`,`group_id`,`level`,`score`,`status`,`created_at`,`updated_at`)
            VALUES (?,?,?,1,1,10,1,?,?)",
            [$username, $nickname, $hash, $now, $now]
        );
        $newUserId = (int)\Database::lastInsertId();
        $newUser = \Database::fetch("SELECT * FROM {$users} WHERE id = ?", [$newUserId]);
        record_sync_operation('users', $newUserId, 'insert', $newUser);

        \Response::success(null, '用户创建成功');
    }

    // ========== 审核 ==========

    private static function requireReviewer()
    {
        $user = \Auth::requireLogin();

        if (!\SiteSetting::isReviewer($user)) {
            \Response::json(403, '无审核权限');
        }

        return $user;
    }

    public static function reviewList()
    {
        self::requireReviewer();

        $page = max(1, \Request::int('page', 1));
        $pageSize = min(50, max(1, \Request::int('page_size', 20)));
        $offset = ($page - 1) * $pageSize;

        $threads = \Database::table('threads');
        $users = \Database::table('users');

        $countRow = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$threads} WHERE status = 1 AND visibility = 'pending'"
        );
        $total = (int)($countRow['c'] ?? 0);

        $rows = \Database::fetchAll(
            "SELECT t.id, t.title, t.summary, t.cover, t.mode, t.visibility, t.created_at,
                    u.id AS author_id, u.nickname AS author_name, u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE t.status = 1 AND t.visibility = 'pending'
             ORDER BY t.created_at DESC
             LIMIT {$pageSize} OFFSET {$offset}"
        );

        $list = array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'title' => $row['title'],
                'summary' => $row['summary'] ?? '',
                'cover' => $row['cover'] ?? '',
                'mode' => $row['mode'] ?? 'article',
                'visibility' => $row['visibility'],
                'created_at' => $row['created_at'],
                'author' => [
                    'id' => (int)$row['author_id'],
                    'nickname' => $row['author_name'] ?: '用户',
                    'avatar' => $row['author_avatar'] ?: '',
                ],
            ];
        }, $rows);

        \Response::success([
            'list' => $list,
            'total' => $total,
            'page' => $page,
            'page_size' => $pageSize,
        ]);
    }

    public static function reviewApprove()
    {
        $user = self::requireReviewer();

        $threadId = \Request::int('thread_id');
        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $thread = \Database::fetch(
            "SELECT id, visibility FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        \Database::execute(
            "UPDATE {$threads} SET visibility = 'public', updated_at = ? WHERE id = ?",
            [now(), $threadId]
        );
        $approvedThread = \Database::fetch("SELECT * FROM {$threads} WHERE id = ?", [$threadId]);
        record_sync_operation('threads', $threadId, 'update', $approvedThread);

        // 记录审核日志
        $auditLog = \Database::table('audit_log');
        \Database::execute(
            "INSERT INTO {$audit_log} (`thread_id`, `action`, `reviewer_id`, `remark`, `created_at`) VALUES (?, 'approve', ?, ?, ?)",
            [$threadId, $user['id'], \Request::str('remark', ''), now()]
        );

        \Response::success(null, '已通过审核');
    }

    public static function reviewReject()
    {
        $user = self::requireReviewer();

        $threadId = \Request::int('thread_id');
        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $thread = \Database::fetch(
            "SELECT id, visibility FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        \Database::execute(
            "UPDATE {$threads} SET visibility = 'locked', updated_at = ? WHERE id = ?",
            [now(), $threadId]
        );
        $rejectedThread = \Database::fetch("SELECT * FROM {$threads} WHERE id = ?", [$threadId]);
        record_sync_operation('threads', $threadId, 'update', $rejectedThread);

        // 记录审核日志
        $auditLog = \Database::table('audit_log');
        \Database::execute(
            "INSERT INTO {$audit_log} (`thread_id`, `action`, `reviewer_id`, `remark`, `created_at`) VALUES (?, 'reject', ?, ?, ?)",
            [$threadId, $user['id'], \Request::str('remark', ''), now()]
        );

        \Response::success(null, '已拒绝');
    }

    // ========== 设置 ==========

    public static function settingsGet()
    {
        self::requireAdmin();

        $table = \Database::table('site_settings');
        $rows = \Database::fetchAll("SELECT `key`, `value` FROM {$table}");

        $settings = [];
        foreach ($rows as $row) {
            $settings[$row['key']] = $row['value'];
        }

        \Response::success($settings);
    }

    public static function settingsUpdate()
    {
        self::requireAdmin();

        $settings = \Request::input('settings', []);
        if (!is_array($settings)) {
            \Response::json(422, '参数错误');
        }

        foreach ($settings as $key => $value) {
            if ($key === 'contact_url') {
                $value = trim((string)$value);
                if ($value !== '' && (!filter_var($value, FILTER_VALIDATE_URL) || strlen($value) > 1000)) {
                    \Response::json(422, '联系我们链接格式不正确');
                }
            }
            if (in_array($key, ['ai_review_enabled', 'ai_review_base_url', 'ai_review_api_key', 'ai_review_model'], true)) {
                $value = trim((string)$value);
                if ($key === 'ai_review_base_url' && $value !== '' && !filter_var($value, FILTER_VALIDATE_URL)) {
                    \Response::json(422, 'AI接口地址格式错误');
                }
                if ($key === 'ai_review_enabled') {
                    $value = $value === '1' ? '1' : '0';
                }
            }
            \SiteSetting::set($key, (string)$value);
        }

        \Response::success(null, '设置已更新');
    }

    public static function publishSystemNotification()
    {
        self::requireAdmin();

        $title = trim(\Request::str('title', ''));
        $content = trim(\Request::str('content', ''));
        $audience = \Request::str('audience', 'registered');
        if ($title === '' || mb_strlen($title) > 100) {
            \Response::json(422, '通知标题不能为空且不超过100字');
        }
        if (mb_strlen($content) > 10000) {
            \Response::json(422, '通知内容不能超过10000字');
        }
        if (!in_array($audience, ['registered', 'all'], true)) {
            \Response::json(422, '无效的发布范围');
        }

        $notifications = \Database::table('notifications');
        $payload = json_encode([
            'broadcast' => $audience === 'all',
            'audience' => $audience,
        ], JSON_UNESCAPED_UNICODE);
        $createdAt = now();

        if ($audience === 'all') {
            \Database::execute(
                "INSERT INTO {$notifications} (`user_id`, `type`, `title`, `content`, `data`, `is_read`, `created_at`)
                 VALUES (0, 'system', ?, ?, ?, 0, ?)",
                [$title, $content, $payload, $createdAt]
            );
            record_sync_operation('notifications', (int)\Database::lastInsertId(), 'insert');
            $count = 0;
        } else {
            $users = \Database::table('users');
            \Database::execute(
                "INSERT INTO {$notifications} (`user_id`, `type`, `title`, `content`, `data`, `is_read`, `created_at`)
                 SELECT id, 'system', ?, ?, ?, 0, ? FROM {$users} WHERE status = 1",
                [$title, $content, $payload, $createdAt]
            );
            $countRow = \Database::fetch("SELECT ROW_COUNT() AS c");
            $count = (int)($countRow['c'] ?? 0);
        }

        \Response::success(['audience' => $audience, 'count' => $count], '系统通知已发布');
    }

    public static function backupDownload()
    {
        self::requireAdmin();

        if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
            \Response::json(405, '仅支持 POST 请求', null, 405);
        }

        @set_time_limit(600);
        $backupPath = \DatabaseBackup::createTemporaryFile();

        $filename = 'qingtan_backup_' . date('Ymd_His') . '.sql';
        $size = filesize($backupPath);
        if ($size === false) {
            @unlink($backupPath);
            throw new \RuntimeException('无法读取备份文件大小');
        }

        $stream = fopen($backupPath, 'rb');
        if ($stream === false) {
            @unlink($backupPath);
            throw new \RuntimeException('无法读取备份文件');
        }

        while (ob_get_level() > 0) {
            ob_end_clean();
        }
        @ini_set('zlib.output_compression', '0');

        header('Content-Type: application/sql; charset=utf-8');
        header('Content-Disposition: attachment; filename="' . $filename . '"');
        header('Content-Length: ' . $size);
        header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
        header('Pragma: no-cache');
        header('Expires: 0');
        header('X-Content-Type-Options: nosniff');

        fpassthru($stream);
        fclose($stream);
        @unlink($backupPath);
        exit;
    }

    /**
     * Generate a self-contained multi-server deployment archive.
     * Database passwords are only embedded when explicitly supplied by the
     * administrator; otherwise the generated installer asks for them.
     */
    public static function multiServerPackage()
    {
        self::requireAdmin();

        if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
            \Response::json(405, '仅支持 POST 请求', null, 405);
        }
        if (!class_exists('ZipArchive')) {
            \Response::json(500, '服务器未启用 Zip 扩展，无法生成部署包', null, 500);
        }

        $input = \Request::input();
        $rawServers = $input['servers'] ?? [];
        if (!is_array($rawServers) || count($rawServers) < 1 || count($rawServers) > 32) {
            \Response::json(422, '至少填写一台服务器，最多支持 32 台', null, 422);
        }

        $servers = [];
        $seen = [];
        foreach ($rawServers as $index => $item) {
            if (!is_array($item)) continue;
            $url = trim((string)($item['url'] ?? ''));
            $parts = parse_url($url);
            if (!$parts || empty($parts['scheme']) || !in_array(strtolower($parts['scheme']), ['http', 'https'], true) || empty($parts['host'])) {
                \Response::json(422, '第 ' . ((int)$index + 1) . ' 台服务器地址无效', null, 422);
            }
            $normalized = rtrim($url, '/');
            if (isset($seen[$normalized])) {
                \Response::json(422, '服务器地址不能重复', null, 422);
            }
            $seen[$normalized] = true;
            $weight = max(1, min(1000, (int)($item['weight'] ?? 1)));
            $name = trim((string)($item['name'] ?? ('服务器 ' . ((int)$index + 1))));
            $servers[] = [
                'id' => count($servers) + 1,
                'name' => $name !== '' ? mb_substr($name, 0, 64) : ('服务器 ' . (count($servers) + 1)),
                'url' => $normalized,
                'weight' => $weight,
            ];
        }

        $dbName = trim((string)($input['db_name'] ?? ''));
        $dbPassword = (string)($input['db_password'] ?? '');
        if ($dbName !== '' && !preg_match('/^[A-Za-z0-9_$-]{1,64}$/', $dbName)) {
            \Response::json(422, '数据库名格式无效', null, 422);
        }

        $backupPath = \DatabaseBackup::createTemporaryFile();
        $workDir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'qingtan_cluster_' . bin2hex(random_bytes(8));
        $zipPath = $workDir . '.zip';
        if (!mkdir($workDir, 0700, true) && !is_dir($workDir)) {
            \Response::json(500, '无法创建部署包临时目录', null, 500);
        }
        $cleanup = static function () use ($workDir, $zipPath, $backupPath) {
            if (is_file($zipPath)) @unlink($zipPath);
            if (is_file($backupPath)) @unlink($backupPath);
            if (is_dir($workDir)) {
                $iterator = new \RecursiveIteratorIterator(
                    new \RecursiveDirectoryIterator($workDir, \FilesystemIterator::SKIP_DOTS),
                    \RecursiveIteratorIterator::CHILD_FIRST
                );
                foreach ($iterator as $file) {
                    $file->isDir() ? @rmdir($file->getPathname()) : @unlink($file->getPathname());
                }
                @rmdir($workDir);
            }
        };
        register_shutdown_function($cleanup);

        $sourceDir = FX_ROOT;
        $copyDir = $workDir . DIRECTORY_SEPARATOR . 'server';
        $skip = ['config/database.php', 'config/onedrive.local.php', 'uploads'];
        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($sourceDir, \FilesystemIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::SELF_FIRST
        );
        foreach ($iterator as $file) {
            $relative = str_replace('\\', '/', substr($file->getPathname(), strlen($sourceDir) + 1));
            if (in_array($relative, $skip, true) || strpos($relative, 'storage/') === 0) continue;
            if (strpos($relative, 'server.zip') === 0) continue;
            $target = $copyDir . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relative);
            if ($file->isDir()) {
                @mkdir($target, 0700, true);
            } else {
                @mkdir(dirname($target), 0700, true);
                @copy($file->getPathname(), $target);
            }
        }
        @copy($backupPath, $workDir . DIRECTORY_SEPARATOR . 'database.sql');

        $token = bin2hex(random_bytes(32));
        $config = [
            'server_id' => 1,
            'server_name' => $servers[0]['name'],
            'server_url' => $servers[0]['url'],
            'servers' => $servers,
            'sync' => [
                'sync_token' => $token,
                'batch_size' => 100,
                'retry_times' => 3,
                'timeout' => 30,
                'sample_rate' => 10,
            ],
        ];
        $configExport = var_export($config, true);
        $dbNameJson = json_encode($dbName, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $dbPasswordJson = json_encode($dbPassword, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $installer = self::multiServerInstaller($configExport, $dbNameJson ?: "''", $dbPasswordJson ?: "''");
        file_put_contents($workDir . DIRECTORY_SEPARATOR . 'install-multi-server.php', $installer, LOCK_EX);
        file_put_contents($workDir . DIRECTORY_SEPARATOR . 'README.txt', "轻坛多服务器部署包\n\n1. 将本目录上传到目标服务器。\n2. 访问 install-multi-server.php，或使用 PHP CLI 执行。\n3. 未预填的数据库名/密码会在安装时询问。\n4. 安装完成后删除安装脚本和 database.sql。\n\n所有节点必须使用同一份 servers.php 和 sync_token。\n", LOCK_EX);

        $zip = new \ZipArchive();
        if ($zip->open($zipPath, \ZipArchive::CREATE | \ZipArchive::OVERWRITE) !== true) {
            \Response::json(500, '无法创建部署包', null, 500);
        }
        $files = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($workDir, \FilesystemIterator::SKIP_DOTS));
        foreach ($files as $file) {
            if (!$file->isFile()) continue;
            $relative = str_replace('\\', '/', substr($file->getPathname(), strlen($workDir) + 1));
            $zip->addFile($file->getPathname(), $relative);
        }
        $zip->close();

        $size = filesize($zipPath);
        $stream = fopen($zipPath, 'rb');
        if ($stream === false || $size === false) {
            \Response::json(500, '无法读取部署包', null, 500);
        }
        while (ob_get_level() > 0) ob_end_clean();
        header('Content-Type: application/zip');
        header('Content-Disposition: attachment; filename="qingtan_multi_server_' . date('Ymd_His') . '.zip"');
        header('Content-Length: ' . $size);
        header('Cache-Control: no-store');
        fpassthru($stream);
        fclose($stream);
        $cleanup();
        exit;
    }

    private static function multiServerInstaller($configExport, $dbName, $dbPassword)
    {
        return <<<PHP
<?php
// 轻坛多服务器一键安装器。安装完成后请立即删除本文件和 database.sql。
\$defaults = ['db_name' => {$dbName}, 'db_password' => {$dbPassword}];
\$isCli = PHP_SAPI === 'cli';
\$value = function (\$key, \$fallback = '') use (\$isCli) {
    if (\$isCli) { global \$argv; foreach (\$argv as \$arg) if (strpos(\$arg, \"--\$key=\") === 0) return substr(\$arg, strlen(\"--\$key=\")); }
    return \$_POST[\$key] ?? \$fallback;
};
\$dbHost = trim((string)\$value('db_host', '127.0.0.1'));
\$dbPort = (int)\$value('db_port', '3306');
\$dbUser = trim((string)\$value('db_user', 'root'));
\$dbName = trim((string)\$value('db_name', \$defaults['db_name']));
\$dbPass = (string)\$value('db_password', \$defaults['db_password']);
if (\$dbName === '') { if (\$isCli) { fwrite(STDERR, "--db_name is required\\n"); exit(1); } echo '<form method="post"><input name="db_host" value="127.0.0.1"><input name="db_port" value="3306"><input name="db_user" value="root"><input name="db_name" required placeholder="数据库名"><input name="db_password" type="password" placeholder="数据库密码"><button>开始安装</button></form>'; exit; }
if (!preg_match('/^[A-Za-z0-9_$-]{1,64}$/', \$dbName)) die('数据库名格式无效');
\$pdo = new PDO('mysql:host=' . \\$dbHost . ';port=' . \\$dbPort . ';dbname=' . \\$dbName . ';charset=utf8mb4', \\$dbUser, \\$dbPass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
\$sql = file_get_contents(__DIR__ . '/database.sql');
if (\$sql === false || \\$pdo->exec(\$sql) === false) die('数据库恢复失败');
\$serverDir = __DIR__ . '/server';
\$configDir = \\$serverDir . '/config';
if (!is_dir(\$configDir)) mkdir(\$configDir, 0750, true);
file_put_contents(\$configDir . '/database.php', "<?php\\nreturn " . var_export(['host' => \\$dbHost, 'port' => \\$dbPort, 'database' => \\$dbName, 'username' => \\$dbUser, 'password' => \\$dbPass, 'charset' => 'utf8mb4', 'prefix' => ''], true) . ";\\n", LOCK_EX);
file_put_contents(\$configDir . '/servers.php', "<?php\\nreturn " . var_export({$configExport}, true) . ";\\n", LOCK_EX);
echo \\$isCli ? "安装完成，请将 server 目录配置为网站根目录。\\n" : '<p>安装完成，请将 server 目录配置为网站根目录，并删除本安装脚本及 database.sql。</p>';
PHP;
    }

    // ========== 用户资料编辑 ==========

    public static function updateUser()
    {
        self::requireAdmin();

        $userId = \Request::int('user_id');
        if ($userId <= 0) {
            \Response::json(422, '用户 ID 错误');
        }

        $users = \Database::table('users');
        $target = \Database::fetch(
            "SELECT id, group_id FROM {$users} WHERE id = ? LIMIT 1",
            [$userId]
        );

        if (!$target) {
            \Response::json(404, '用户不存在');
        }

        // 不能修改管理员的用户组
        if ((int)$target['group_id'] === 99) {
            $newGroupId = \Request::input('group_id');
            if ($newGroupId !== null && (int)$newGroupId !== 99) {
                \Response::json(422, '不能修改管理员的用户组');
            }
        }

        $fields = [];
        $params = [];

        // 铭牌
        $badgeName = \Request::input('badge_name');
        if ($badgeName !== null) {
            $badgeName = trim((string)$badgeName);
            if ($badgeName === '') {
                $fields[] = '`badge_name` = NULL';
                $fields[] = '`badge_color` = NULL';
            } else {
                $len = mb_strlen($badgeName);
                if ($len < 2 || $len > 5) {
                    \Response::json(422, '铭牌需为 2-5 个字符');
                }
                $fields[] = '`badge_name` = ?';
                $params[] = $badgeName;

                $badgeColor = trim(\Request::str('badge_color', '#FB7299'));
                if (!preg_match('/^#[0-9A-Fa-f]{6}$/', $badgeColor)) {
                    $badgeColor = '#FB7299';
                }
                $fields[] = '`badge_color` = ?';
                $params[] = $badgeColor;
            }
        }

        // 认证等级
        $verifyLevel = \Request::input('verify_level');
        if ($verifyLevel !== null) {
            $level = (int)$verifyLevel;
            if ($level < 0 || $level > 3) {
                \Response::json(422, '认证等级需为 0-3');
            }
            $fields[] = '`verify_level` = ?';
            $params[] = $level;
        }

        // 用户组
        $groupId = \Request::input('group_id');
        if ($groupId !== null) {
            $gid = (int)$groupId;
            if ($gid <= 0) {
                \Response::json(422, '用户组 ID 错误');
            }
            // 检查用户组是否存在
            $groups = \Database::table('user_groups');
            $group = \Database::fetch(
                "SELECT id FROM {$groups} WHERE id = ? LIMIT 1",
                [$gid]
            );
            if (!$group) {
                \Response::json(422, '用户组不存在');
            }
            $fields[] = '`group_id` = ?';
            $params[] = $gid;
        }

        // 单独权限覆盖（JSON）
        $permissions = \Request::input('permissions');
        if ($permissions !== null) {
            if (is_array($permissions)) {
                $permJson = json_encode($permissions, JSON_UNESCAPED_UNICODE);
            } else {
                $permJson = (string)$permissions;
            }
            // 验证是否为合法 JSON
            if ($permJson !== 'null' && $permJson !== '{}') {
                json_decode($permJson);
                if (json_last_error() !== JSON_ERROR_NONE) {
                    \Response::json(422, '权限数据格式错误');
                }
            }
            $fields[] = '`permissions` = ?';
            $params[] = $permJson === 'null' || $permJson === '{}' ? null : $permJson;
        }

        if (empty($fields)) {
            \Response::json(422, '没有需要更新的字段');
        }

        $fields[] = '`updated_at` = ?';
        $params[] = now();
        $params[] = $userId;

        \Database::execute(
            "UPDATE {$users} SET " . implode(', ', $fields) . " WHERE id = ?",
            $params
        );
        $updatedAdminUser = \Database::fetch("SELECT * FROM {$users} WHERE id = ?", [$userId]);
        record_sync_operation('users', $userId, 'update', $updatedAdminUser);

        \Response::success(null, '用户资料已更新');
    }

    // ========== 用户组列表 ==========

    public static function groupList()
    {
        self::requireAdmin();

        $groups = \Database::table('user_groups');
        $rows = \Database::fetchAll(
            "SELECT id, name, type, permissions, min_score, max_score, status FROM {$groups} ORDER BY id ASC"
        );

        $list = array_map(function ($row) {
            $perms = json_decode($row['permissions'] ?? '{}', true) ?: [];
            return [
                'id' => (int)$row['id'],
                'name' => $row['name'],
                'type' => $row['type'],
                'permissions' => $perms,
                'min_score' => (int)$row['min_score'],
                'max_score' => (int)$row['max_score'],
                'status' => (int)$row['status'],
            ];
        }, $rows);

        \Response::success(['list' => $list]);
    }

    // ========== 帖子管理 ==========

    public static function threads()
    {
        self::requireAdmin();

        $page = max(1, \Request::int('page', 1));
        $pageSize = min(100, max(1, \Request::int('page_size', 20)));
        $keyword = trim(\Request::str('keyword', ''));
        $forumId = \Request::int('forum_id', 0);
        $visibility = \Request::str('visibility', '');

        $threads = \Database::table('threads');
        $users = \Database::table('users');
        $offset = ($page - 1) * $pageSize;

        $where = ['t.status = 1'];
        $params = [];

        if ($keyword !== '') {
            $where[] = '(t.title LIKE ? OR u.nickname LIKE ?)';
            $like = '%' . $keyword . '%';
            $params[] = $like;
            $params[] = $like;
        }

        if ($forumId > 0) {
            $where[] = 't.forum_id = ?';
            $params[] = $forumId;
        }

        if ($visibility !== '') {
            $where[] = 't.visibility = ?';
            $params[] = $visibility;
        }

        $whereClause = implode(' AND ', $where);

        $countRow = \Database::fetch(
            "SELECT COUNT(*) AS c FROM {$threads} t LEFT JOIN {$users} u ON u.id = t.user_id WHERE {$whereClause}",
            $params
        );
        $total = (int)($countRow['c'] ?? 0);

        $rows = \Database::fetchAll(
            "SELECT t.id, t.title, t.summary, t.cover, t.mode, t.forum_id,
                    t.visibility, t.is_top AS is_sticky, t.is_closed AS is_locked,
                    t.view_count, t.like_count, t.reply_count AS post_count,
                    t.created_at, t.updated_at,
                    u.id AS author_id, u.nickname AS author_name, u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE {$whereClause}
             ORDER BY t.is_top DESC, t.created_at DESC
             LIMIT {$pageSize} OFFSET {$offset}",
            $params
        );

        $list = array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'title' => $row['title'],
                'summary' => $row['summary'] ?? '',
                'cover' => $row['cover'] ?? '',
                'mode' => $row['mode'] ?? 'article',
                'forum_id' => (int)$row['forum_id'],
                'visibility' => $row['visibility'],
                'is_sticky' => (int)$row['is_sticky'],
                'is_locked' => (int)$row['is_locked'],
                'view_count' => (int)$row['view_count'],
                'like_count' => (int)$row['like_count'],
                'post_count' => (int)$row['post_count'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at'],
                'author' => [
                    'id' => (int)$row['author_id'],
                    'nickname' => $row['author_name'] ?: '用户',
                    'avatar' => $row['author_avatar'] ?: '',
                ],
            ];
        }, $rows);

        \Response::success([
            'list' => $list,
            'total' => $total,
            'page' => $page,
            'page_size' => $pageSize,
        ]);
    }

    public static function threadDelete()
    {
        self::requireAdmin();

        $threadId = \Request::int('thread_id');
        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $thread = \Database::fetch(
            "SELECT id FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        \Database::execute(
            "UPDATE {$threads} SET status = 0, updated_at = ? WHERE id = ?",
            [now(), $threadId]
        );
        record_sync_operation('threads', $threadId, 'delete');

        \Response::success(null, '帖子已删除');
    }

    public static function threadToggleSticky()
    {
        self::requireAdmin();

        $threadId = \Request::int('thread_id');
        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $thread = \Database::fetch(
            "SELECT id, is_top FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        $newVal = (int)$thread['is_top'] === 1 ? 0 : 1;

        \Database::execute(
            "UPDATE {$threads} SET is_top = ?, updated_at = ? WHERE id = ?",
            [$newVal, now(), $threadId]
        );
        $stickyThread = \Database::fetch("SELECT * FROM {$threads} WHERE id = ?", [$threadId]);
        record_sync_operation('threads', $threadId, 'update', $stickyThread);

        \Response::success(['is_sticky' => $newVal], $newVal ? '已置顶' : '已取消置顶');
    }

    public static function threadToggleLock()
    {
        self::requireAdmin();

        $threadId = \Request::int('thread_id');
        if ($threadId <= 0) {
            \Response::json(422, '帖子 ID 错误');
        }

        $threads = \Database::table('threads');
        $thread = \Database::fetch(
            "SELECT id, is_closed FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        $newVal = (int)$thread['is_closed'] === 1 ? 0 : 1;

        \Database::execute(
            "UPDATE {$threads} SET is_closed = ?, updated_at = ? WHERE id = ?",
            [$newVal, now(), $threadId]
        );
        $lockedThread = \Database::fetch("SELECT * FROM {$threads} WHERE id = ?", [$threadId]);
        record_sync_operation('threads', $threadId, 'update', $lockedThread);

        \Response::success(['is_locked' => $newVal], $newVal ? '已锁定' : '已取消锁定');
    }
}
