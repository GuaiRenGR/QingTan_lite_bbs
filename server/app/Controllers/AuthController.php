<?php

namespace App\Controllers;

class AuthController
{
    public static function register()
    {
        $username = \Request::str('username');
        $nickname = \Request::str('nickname', $username);
        $email = \Request::str('email');
        $password = (string)\Request::input('password');
        $passwordConfirm = (string)\Request::input('password_confirm', \Request::input('password_confirmation'));

        $captchaId = \Request::str('captcha_id');
        $captcha = \Request::str('captcha');

        if (!CaptchaController::verifyCaptcha($captchaId, $captcha)) {
            \Response::json(422, '图片验证码错误或已过期');
        }

        if (!preg_match('/^[A-Za-z0-9_]{3,20}$/', $username)) {
            \Response::json(422, '用户名格式错误（3-20位，仅允许字母、数字、下划线）');
        }

        if (strlen($password) < 8 || strlen($password) > 32) {
            \Response::json(422, '密码长度需为 8-32 位');
        }

        if ($password !== $passwordConfirm) {
            \Response::json(422, '两次密码不一致');
        }

        if ($email && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            \Response::json(422, '邮箱格式错误');
        }

        $users = \Database::table('users');

        $exists = \Database::fetch(
            "SELECT id FROM {$users} WHERE username = ? OR email = ? LIMIT 1",
            [$username, $email ?: '__empty__']
        );

        if ($exists) {
            \Response::json(409, '用户名或邮箱已存在');
        }

        $hash = password_hash($password, PASSWORD_DEFAULT);
        $now = now();

        \Database::begin();

        try {
            \Database::execute(
                "INSERT INTO {$users}
                (`username`,`nickname`,`email`,`password_hash`,`group_id`,`level`,`score`,`status`,`created_at`,`updated_at`)
                VALUES (?,?,?,?,1,1,10,1,?,?)",
                [
                    $username,
                    $nickname,
                    $email ?: null,
                    $hash,
                    $now,
                    $now
                ]
            );

            $userId = \Database::lastInsertId();

            $scoreLogs = \Database::table('score_logs');

            \Database::execute(
                "INSERT INTO {$scoreLogs}
                (`user_id`,`action`,`amount`,`balance`,`remark`,`created_at`)
                VALUES (?,?,?,?,?,?)",
                [$userId, 'register', 10, 10, '注册奖励', $now]
            );

            \Database::commit();

            $token = \Auth::createToken($userId);

            $user = \Database::fetch(
                "SELECT id,username,nickname,email,avatar,score,level,status,created_at FROM {$users} WHERE id = ?",
                [$userId]
            );

            \Response::success([
                'access_token' => $token,
                'token_type' => 'Bearer',
                'user' => $user,
            ], '注册成功');

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, '注册失败');
        }
    }

    public static function login()
    {
        $account = \Request::str('account');
        $password = (string)\Request::input('password');

        if (!$account || !$password) {
            \Response::json(422, '请输入账号和密码');
        }

        $users = \Database::table('users');

        $user = \Database::fetch(
            "SELECT * FROM {$users} WHERE username = ? OR email = ? LIMIT 1",
            [$account, $account]
        );

        if (!$user || !password_verify($password, $user['password_hash'])) {
            \Response::json(401, '账号或密码错误');
        }

        if ((int)$user['status'] !== 1) {
            \Response::json(403, '账号状态异常');
        }

        \Database::execute(
            "UPDATE {$users} SET last_login_at = ?, last_login_ip = ?, updated_at = ? WHERE id = ?",
            [now(), client_ip(), now(), $user['id']]
        );

        $token = \Auth::createToken($user['id']);

        unset($user['password_hash']);

        \Response::success([
            'access_token' => $token,
            'token_type' => 'Bearer',
            'token_expire_time' => date('Y-m-d H:i:s', time() + 86400 * 30),
            'user' => $user,
        ], '登录成功');
    }

    public static function me()
    {
        $user = \Auth::requireLogin();

        unset($user['password_hash']);

        \Response::success($user);
    }

    public static function logout()
    {
        \Auth::logout();

        \Response::success(null, '退出成功');
    }

    public static function changePassword()
    {
        $user = \Auth::requireLogin();

        $oldPassword = (string)\Request::input('old_password');
        $newPassword = (string)\Request::input('new_password');
        $confirmPassword = (string)\Request::input('confirm_password');

        if (!$oldPassword || !$newPassword) {
            \Response::json(422, '请输入旧密码和新密码');
        }

        if (strlen($newPassword) < 8 || strlen($newPassword) > 32) {
            \Response::json(422, '新密码长度需为 8-32 位');
        }

        if ($newPassword !== $confirmPassword) {
            \Response::json(422, '两次新密码不一致');
        }

        $users = \Database::table('users');
        $row = \Database::fetch(
            "SELECT password_hash FROM {$users} WHERE id = ? LIMIT 1",
            [$user['id']]
        );

        if (!$row || !password_verify($oldPassword, $row['password_hash'])) {
            \Response::json(422, '旧密码错误');
        }

        $hash = password_hash($newPassword, PASSWORD_DEFAULT);

        \Database::execute(
            "UPDATE {$users} SET password_hash = ?, updated_at = ? WHERE id = ?",
            [$hash, now(), $user['id']]
        );

        \Response::success(null, '密码已修改');
    }

    public static function sessions()
    {
        $user = \Auth::requireLogin();

        $tokens = \Database::table('user_tokens');

        $rows = \Database::fetchAll(
            "SELECT id, device_id, ip, user_agent, created_at, expired_at
             FROM {$tokens}
             WHERE user_id = ? AND expired_at > ?
             ORDER BY created_at DESC",
            [$user['id'], now()]
        );

        $currentHash = hash('sha256', \Request::bearerToken() ?? '');

        $sessions = [];
        foreach ($rows as $row) {
            $sessions[] = [
                'id' => (int)$row['id'],
                'device_id' => $row['device_id'] ?? '',
                'ip' => $row['ip'] ?? '',
                'user_agent' => $row['user_agent'] ?? '',
                'created_at' => $row['created_at'],
                'expired_at' => $row['expired_at'],
            ];
        }

        \Response::success([
            'sessions' => $sessions,
            'current_token_hash' => $currentHash,
        ]);
    }

    public static function revokeSession()
    {
        $user = \Auth::requireLogin();

        $sessionId = \Request::int('session_id');

        if ($sessionId <= 0) {
            \Response::json(422, '参数错误');
        }

        $tokens = \Database::table('user_tokens');

        $session = \Database::fetch(
            "SELECT id FROM {$tokens} WHERE id = ? AND user_id = ? LIMIT 1",
            [$sessionId, $user['id']]
        );

        if (!$session) {
            \Response::json(404, '会话不存在');
        }

        \Database::execute(
            "DELETE FROM {$tokens} WHERE id = ? AND user_id = ?",
            [$sessionId, $user['id']]
        );

        \Response::success(null, '已撤销该会话');
    }
}
