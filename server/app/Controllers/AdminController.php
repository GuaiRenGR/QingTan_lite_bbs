<?php

namespace App\Controllers;

class AdminController
{
    private static function requireAdmin()
    {
        $user = \Auth::requireLogin();

        if ((int)($user['group_id'] ?? 0) !== 99) {
            \Response::json(403, '无管理员权限');
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
            "SELECT id, username, nickname, email, avatar, group_id, level, score, points, status, created_at, last_login_at
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
        \Database::execute("DELETE FROM {$users} WHERE id = ?", [$userId]);

        \Response::success(null, '删除成功');
    }

    public static function create()
    {
        self::requireAdmin();

        $username = \Request::str('username');
        $password = (string)\Request::input('password');
        $nickname = \Request::str('nickname', $username);

        if (!preg_match('/^[\x{4e00}-\x{9fa5}A-Za-z0-9_]{3,20}$/u', $username)) {
            \Response::json(422, '用户名格式错误（3-20位，中文/字母/数字/下划线）');
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
            \SiteSetting::set($key, (string)$value);
        }

        \Response::success(null, '设置已更新');
    }
}
