<?php

class Response
{
    public static function success($data = null, $message = 'success')
    {
        self::output([
            'code' => 0,
            'message' => $message,
            'data' => $data,
            'request_id' => uniqid('req_', true),
        ]);
    }

    public static function json($code = 400, $message = 'error', $data = null, $httpCode = 200)
    {
        http_response_code($httpCode);

        self::output([
            'code' => $code,
            'message' => $message,
            'data' => $data,
            'request_id' => uniqid('req_', true),
        ]);
    }

    private static function output($payload)
    {
        header('Content-Type: application/json; charset=utf-8');

        echo json_encode($payload, JSON_UNESCAPED_UNICODE);

        exit;
    }
}
