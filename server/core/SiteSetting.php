<?php

class SiteSetting
{
    private static $cache = [];

    public static function get($key, $default = null)
    {
        if (isset(self::$cache[$key])) {
            return self::$cache[$key];
        }

        $table = \Database::table('site_settings');
        $row = \Database::fetch(
            "SELECT `value` FROM {$table} WHERE `key` = ? LIMIT 1",
            [$key]
        );

        $value = $row ? $row['value'] : $default;
        self::$cache[$key] = $value;

        return $value;
    }

    public static function set($key, $value)
    {
        $table = \Database::table('site_settings');
        \Database::execute(
            "INSERT INTO {$table} (`key`, `value`, `updated_at`) VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE `value` = VALUES(`value`), `updated_at` = VALUES(`updated_at`)",
            [$key, $value, now()]
        );
        self::$cache[$key] = $value;
    }

    public static function isReviewRequired()
    {
        return self::get('require_review', '0') === '1';
    }

    public static function isReviewer($user)
    {
        return (int)($user['group_id'] ?? 0) >= 50;
    }

    public static function isAdmin($user)
    {
        return (int)($user['group_id'] ?? 0) === 99;
    }
}
