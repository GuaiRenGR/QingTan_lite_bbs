<?php

namespace App\Controllers;

class CaptchaController
{
    public static function image()
    {
        $captchaId = \Request::str('captcha_id');

        if (!$captchaId || !preg_match('/^[A-Za-z0-9_\-]{6,80}$/', $captchaId)) {
            self::outputPlainImage('ERR');
        }

        if (!extension_loaded('gd')) {
            self::outputPlainImage('GD');
        }

        $code = self::makeCode(4);
        self::saveCode($captchaId, $code);

        $width = 120;
        $height = 54;

        $image = imagecreatetruecolor($width, $height);

        $bg = imagecolorallocate($image, 245, 246, 248);
        $textColor = imagecolorallocate($image, 35, 35, 35);
        $noiseColor = imagecolorallocate($image, 180, 180, 180);
        $lineColor = imagecolorallocate($image, 251, 114, 153);

        imagefilledrectangle($image, 0, 0, $width, $height, $bg);

        for ($i = 0; $i < 8; $i++) {
            imageline(
                $image,
                mt_rand(0, $width),
                mt_rand(0, $height),
                mt_rand(0, $width),
                mt_rand(0, $height),
                $noiseColor
            );
        }

        for ($i = 0; $i < 120; $i++) {
            imagesetpixel(
                $image,
                mt_rand(0, $width - 1),
                mt_rand(0, $height - 1),
                $noiseColor
            );
        }

        $fontSize = 5;
        $x = 18;

        for ($i = 0; $i < strlen($code); $i++) {
            $y = mt_rand(14, 24);
            imagestring(
                $image,
                $fontSize,
                $x + $i * 22,
                $y,
                $code[$i],
                $textColor
            );
        }

        imageline($image, 10, mt_rand(20, 40), $width - 10, mt_rand(16, 38), $lineColor);

        header('Content-Type: image/png');
        header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
        imagepng($image);
        imagedestroy($image);
        exit;
    }

    public static function verifyCaptcha($captchaId, $captcha)
    {
        $captchaId = trim((string)$captchaId);
        $captcha = strtolower(trim((string)$captcha));

        if (!$captchaId || !$captcha) {
            return false;
        }

        $file = self::filePath($captchaId);

        if (!file_exists($file)) {
            return false;
        }

        $raw = file_get_contents($file);
        $data = json_decode($raw, true);

        @unlink($file);

        if (!is_array($data)) {
            return false;
        }

        if (($data['expired_at'] ?? 0) < time()) {
            return false;
        }

        $hash = $data['hash'] ?? '';

        return hash_equals($hash, hash('sha256', strtolower($captcha)));
    }

    private static function makeCode($length = 4)
    {
        $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $code = '';

        for ($i = 0; $i < $length; $i++) {
            $code .= $chars[mt_rand(0, strlen($chars) - 1)];
        }

        return $code;
    }

    private static function saveCode($captchaId, $code)
    {
        $dir = FX_ROOT . '/cache/captcha';

        if (!is_dir($dir)) {
            @mkdir($dir, 0755, true);
        }

        $data = [
            'hash' => hash('sha256', strtolower($code)),
            'expired_at' => time() + 300,
            'created_at' => time(),
        ];

        file_put_contents(self::filePath($captchaId), json_encode($data));
    }

    private static function filePath($captchaId)
    {
        $safeId = preg_replace('/[^A-Za-z0-9_\-]/', '', $captchaId);

        return FX_ROOT . '/cache/captcha/' . $safeId . '.json';
    }

    private static function outputPlainImage($text)
    {
        if (!extension_loaded('gd')) {
            header('Content-Type: text/plain; charset=utf-8');
            echo 'captcha error';
            exit;
        }

        $image = imagecreatetruecolor(120, 54);
        $bg = imagecolorallocate($image, 245, 245, 245);
        $color = imagecolorallocate($image, 120, 120, 120);

        imagefilledrectangle($image, 0, 0, 120, 54, $bg);
        imagestring($image, 5, 35, 18, $text, $color);

        header('Content-Type: image/png');
        imagepng($image);
        imagedestroy($image);
        exit;
    }
}
