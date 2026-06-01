<?php

/**
 * DV 码工具类
 *
 * 将帖子数字 ID 编码为 DV + 8位混合字符的唯一标识
 * 字符集：大小写字母+数字，去除易混淆字符 0/O/o/I/l/1
 * 保留：23456789ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz（54字符）
 */
class DvCode
{
    // 54 字符集（大小写敏感）
    private const CHARSET = '23456789ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz';
    private const BASE = 54;
    private const CODE_LEN = 8;
    // 混淆盐（XOR），不影响唯一性，仅防止连续 ID 可预测
    private const SALT = 0xA3B7C9D1;

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

        $obfuscated = $id ^ self::SALT;
        $chars = '';
        $charset = self::CHARSET;

        for ($i = 0; $i < self::CODE_LEN; $i++) {
            $chars = $charset[$obfuscated % self::BASE] . $chars;
            $obfuscated = intdiv($obfuscated, self::BASE);
        }

        return 'DV' . $chars;
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

        $chars = substr($code, 2);
        $map = self::getReverseMap();
        $result = 0;

        for ($i = 0; $i < self::CODE_LEN; $i++) {
            if (!isset($map[$chars[$i]])) {
                return 0;
            }
            $result = $result * self::BASE + $map[$chars[$i]];
        }

        return ($result ^ self::SALT);
    }

    /**
     * 验证格式是否合法（大小写敏感）
     * 必须是 DV + 8个合法字符
     */
    public static function isValid(string $code): bool
    {
        $code = trim($code);
        return (bool)preg_match('/^DV[2-9A-HJ-NP-Za-hj-np-z]{8}$/', $code);
    }
}
