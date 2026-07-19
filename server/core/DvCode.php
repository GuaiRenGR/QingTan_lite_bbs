<?php

/**
 * DV 码工具类
 *
 * 将帖子数字 ID 编码为 DV + 8位混合字符的唯一标识
 * 字符集：大小写字母+数字，去除易混淆字符 0/O/o/I/l/1
 * 保留：23456789ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz（55字符）
 */
class DvCode
{
    // 字符集（大小写敏感）
    private const CHARSET = '23456789ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz';
    private const BASE = 55;
    private const CODE_LEN = 8;
    private const SPACE = 83733937890625;
    private const MULTIPLIER = 32020345226239;
    private const OFFSET = 17320508075688;
    private const MULTIPLIER_INVERSE = 49350892233409;

    private static $reverseMap = null;

    /**
     * 构建反向查找表（字符 → 索引）
     */
    private static function getReverseMap(): array
    {
        if (self::$reverseMap === null) {
            self::$reverseMap = [];
            for ($i = 0; $i < self::BASE; $i++) {
                self::$reverseMap[self::CHARSET[$i]] = $i;
            }
        }
        return self::$reverseMap;
    }

    /**
     * 数字 ID → DV 码
     */
    public static function encode(int $id): string
    {
        if ($id <= 0) {
            return '';
        }

        $value = self::mix($id);
        return 'DV' . self::encodeValue($value);
    }

    public static function encodeVariant(int $id, int $attempt): string
    {
        if ($id <= 0) {
            return '';
        }

        $value = (self::mix($id) + ($attempt * 7919)) % self::SPACE;
        return 'DV' . self::encodeValue($value);
    }

    /**
     * DV 码 → 数字 ID（解码失败返回 0）
     * 大小写敏感，必须与编码时完全一致
     */
    public static function decode(string $code): int
    {
        $code = trim($code);

        if (!self::isValid($code)) {
            return 0;
        }

        $value = self::decodeValue(substr($code, 2));
        $normalized = $value - self::OFFSET;
        if ($normalized < 0) {
            $normalized += self::SPACE;
        }

        return self::multiplyMod(
            $normalized,
            self::MULTIPLIER_INVERSE,
            self::SPACE
        );
    }

    /**
     * 验证新 DV 码格式是否合法（大小写敏感）
     */
    public static function isValid(string $code): bool
    {
        $code = trim($code);
        return (bool)preg_match(
            '/^DV[' . preg_quote(self::CHARSET, '/') . ']{8}$/D',
            $code
        );
    }

    public static function isLookupSafe(string $code): bool
    {
        return (bool)preg_match('/^DV[0-9A-Za-z]{6,32}$/D', trim($code));
    }

    private static function mix(int $id): int
    {
        return (self::multiplyMod($id, self::MULTIPLIER, self::SPACE)
            + self::OFFSET) % self::SPACE;
    }

    private static function encodeValue(int $value): string
    {
        $chars = '';
        for ($i = 0; $i < self::CODE_LEN; $i++) {
            $chars = self::CHARSET[$value % self::BASE] . $chars;
            $value = intdiv($value, self::BASE);
        }
        return $chars;
    }

    private static function decodeValue(string $chars): int
    {
        $map = self::getReverseMap();
        $result = 0;

        for ($i = 0; $i < self::CODE_LEN; $i++) {
            if (!isset($map[$chars[$i]])) {
                return 0;
            }
            $result = $result * self::BASE + $map[$chars[$i]];
        }

        return $result;
    }

    private static function multiplyMod(int $left, int $right, int $mod): int
    {
        $result = 0;
        $left %= $mod;

        while ($right > 0) {
            if (($right % 2) === 1) {
                $result = ($result + $left) % $mod;
            }
            $left = ($left * 2) % $mod;
            $right = intdiv($right, 2);
        }

        return $result;
    }
}
