<?php

class Auth
{
    public static function user()
    {
        $token = Request::bearerToken();

        if (!$token) {
            return null;
        }

        $hash = hash('sha256', $token);

        $tokens = Database::table('user_tokens');
        $users = Database::table('users');

        $sql = "
            SELECT u.*
            FROM {$tokens} t
            INNER JOIN {$users} u ON u.id = t.user_id
            WHERE t.token_hash = ?
              AND t.expired_at > ?
              AND u.status = 1
            LIMIT 1
        ";

        return Database::fetch($sql, [$hash, now()]);
    }

    public static function requireLogin()
    {
        $user = self::user();

        if (!$user) {
            Response::json(401, '请先登录');
        }

        return $user;
    }

    public static function createToken($userId)
    {
        $token = random_token(32);
        $hash = hash('sha256', $token);

        $table = Database::table('user_tokens');

        Database::execute(
            "INSERT INTO {$table}
            (`user_id`,`token_hash`,`device_id`,`ip`,`user_agent`,`expired_at`,`created_at`)
            VALUES (?,?,?,?,?,?,?)",
            [
                $userId,
                $hash,
                $_SERVER['HTTP_X_DEVICE_ID'] ?? '',
                client_ip(),
                substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255),
                date('Y-m-d H:i:s', time() + 86400 * 30),
                now(),
            ]
        );

        return $token;
    }

    public static function logout()
    {
        $token = Request::bearerToken();

        if (!$token) {
            return;
        }

        $hash = hash('sha256', $token);
        $table = Database::table('user_tokens');

        Database::execute("DELETE FROM {$table} WHERE token_hash = ?", [$hash]);
    }
}
