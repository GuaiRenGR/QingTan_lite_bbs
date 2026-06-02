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
            "SELECT id, username, nickname, email, avatar, group_id, level, score, points, status, permissions, created_at, last_login_at
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
                    t.visibility, t.is_sticky, t.is_locked, t.view_count,
                    t.like_count, t.post_count, t.created_at, t.updated_at,
                    u.id AS author_id, u.nickname AS author_name, u.avatar AS author_avatar
             FROM {$threads} t
             LEFT JOIN {$users} u ON u.id = t.user_id
             WHERE {$whereClause}
             ORDER BY t.is_sticky DESC, t.created_at DESC
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
            "SELECT id, is_sticky FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        $newVal = (int)$thread['is_sticky'] === 1 ? 0 : 1;

        \Database::execute(
            "UPDATE {$threads} SET is_sticky = ?, updated_at = ? WHERE id = ?",
            [$newVal, now(), $threadId]
        );

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
            "SELECT id, is_locked FROM {$threads} WHERE id = ? AND status = 1 LIMIT 1",
            [$threadId]
        );

        if (!$thread) {
            \Response::json(404, '帖子不存在');
        }

        $newVal = (int)$thread['is_locked'] === 1 ? 0 : 1;

        \Database::execute(
            "UPDATE {$threads} SET is_locked = ?, updated_at = ? WHERE id = ?",
            [$newVal, now(), $threadId]
        );

        \Response::success(['is_locked' => $newVal], $newVal ? '已锁定' : '已取消锁定');
    }
}
