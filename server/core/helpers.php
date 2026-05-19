<?php

function now()
{
    return date('Y-m-d H:i:s');
}

function today()
{
    return date('Y-m-d');
}

function client_ip()
{
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ip = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0];
        return trim($ip);
    }

    return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
}

function safe_text($str)
{
    return htmlspecialchars((string)$str, ENT_QUOTES, 'UTF-8');
}

function strip_dangerous_html($html)
{
    $html = (string)$html;

    $html = preg_replace('/<script\b[^>]*>(.*?)<\/script>/is', '', $html);
    $html = preg_replace('/<iframe\b[^>]*>(.*?)<\/iframe>/is', '', $html);
    $html = preg_replace('/on\w+="[^"]*"/i', '', $html);
    $html = preg_replace("/on\w+='[^']*'/i", '', $html);
    $html = preg_replace('/javascript:/i', '', $html);

    return $html;
}

function make_summary($content, $length = 120)
{
    $text = trim(strip_tags($content));
    if (function_exists('mb_substr')) {
        return mb_substr($text, 0, $length, 'UTF-8');
    }
    return substr($text, 0, $length);
}

function random_token($length = 32)
{
    if (function_exists('random_bytes')) {
        return bin2hex(random_bytes($length));
    }

    return bin2hex(openssl_random_pseudo_bytes($length));
}

function log_error($message)
{
    $dir = FX_ROOT . '/runtime/logs';

    if (!is_dir($dir)) {
        @mkdir($dir, 0755, true);
    }

    $file = $dir . '/error-' . date('Ymd') . '.log';

    @file_put_contents(
        $file,
        '[' . now() . '] ' . $message . "\n",
        FILE_APPEND
    );
}

function validate_remote_url($url)
{
    $url = trim((string)$url);

    if (!$url) {
        return false;
    }

    if (!filter_var($url, FILTER_VALIDATE_URL)) {
        return false;
    }

    $scheme = parse_url($url, PHP_URL_SCHEME);

    return in_array(strtolower($scheme), ['http', 'https'], true);
}

function extract_img_tags($content)
{
    $content = (string)$content;

    preg_match_all('/\[img=(https?:\/\/[^\]\s]+)\]/i', $content, $matches);

    return $matches[1] ?? [];
}

function sanitize_forum_content($content)
{
    $content = (string)$content;

    $content = strip_dangerous_html($content);

    $content = preg_replace_callback('/\[img=([^\]]+)\]/i', function ($m) {
        $url = trim($m[1]);

        if (!validate_remote_url($url)) {
            return '';
        }

        return '[img=' . $url . ']';
    }, $content);

    $content = preg_replace_callback('/\[url=([^\]]+)\]([\s\S]*?)\[\/url\]/i', function ($m) {
        $url = trim($m[1]);
        $text = trim($m[2]);

        if (!validate_remote_url($url)) {
            return $text;
        }

        if ($text === '') {
            $text = $url;
        }

        return '[url=' . $url . ']' . $text . '[/url]';
    }, $content);

    return trim($content);
}

function parse_json_array_input($value)
{
    if (is_array($value)) {
        return $value;
    }

    if (is_string($value) && $value !== '') {
        $json = json_decode($value, true);

        if (is_array($json)) {
            return $json;
        }
    }

    return [];
}
