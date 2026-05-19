<?php

class Request
{
    public static function input($key = null, $default = null)
    {
        $data = self::all();

        if ($key === null) {
            return $data;
        }

        return $data[$key] ?? $default;
    }

    public static function all()
    {
        $data = [];

        if ($_SERVER['REQUEST_METHOD'] === 'GET') {
            $data = $_GET;
        } else {
            $contentType = $_SERVER['CONTENT_TYPE'] ?? '';

            if (stripos($contentType, 'application/json') !== false) {
                $raw = file_get_contents('php://input');
                $json = json_decode($raw, true);
                $data = is_array($json) ? $json : [];
            } else {
                $data = $_POST;
            }
        }

        unset($data['route']);

        return $data;
    }

    public static function int($key, $default = 0)
    {
        return intval(self::input($key, $default));
    }

    public static function str($key, $default = '')
    {
        return trim((string)self::input($key, $default));
    }

    public static function bearerToken()
    {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';

        if (!$header && function_exists('apache_request_headers')) {
            $headers = apache_request_headers();
            $header = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        }

        if (stripos($header, 'Bearer ') === 0) {
            return trim(substr($header, 7));
        }

        return null;
    }
}
