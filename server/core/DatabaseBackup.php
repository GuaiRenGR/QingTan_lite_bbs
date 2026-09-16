<?php

class DatabaseBackup
{
    public static function createTemporaryFile()
    {
        $path = tempnam(sys_get_temp_dir(), 'qingtan_backup_');
        if ($path === false) {
            throw new RuntimeException('无法创建备份临时文件');
        }

        @chmod($path, 0600);
        register_shutdown_function(function () use ($path) {
            if (is_file($path)) {
                @unlink($path);
            }
        });

        try {
            self::writeToFile($path);
            return $path;
        } catch (Throwable $e) {
            @unlink($path);
            throw $e;
        }
    }

    public static function writeToFile($path)
    {
        $handle = fopen($path, 'wb');
        if ($handle === false) {
            throw new RuntimeException('无法写入备份文件');
        }

        $pdo = Database::pdo();
        $config = require FX_ROOT . '/config/database.php';
        $charset = preg_match('/^[A-Za-z0-9_]+$/', $config['charset'] ?? '')
            ? $config['charset']
            : 'utf8mb4';
        $database = self::commentValue($config['database'] ?? '');
        $prefix = self::commentValue($config['prefix'] ?? '');
        $inTransaction = false;
        $bufferAttribute = defined('PDO::MYSQL_ATTR_USE_BUFFERED_QUERY')
            ? constant('PDO::MYSQL_ATTR_USE_BUFFERED_QUERY')
            : null;

        try {
            self::write($handle, "-- 轻坛数据库备份\n");
            self::write($handle, '-- 导出时间：' . date('Y-m-d H:i:s') . "\n");
            self::write($handle, "-- 数据库：{$database}\n");
            self::write($handle, "-- 表前缀：{$prefix}\n\n");
            self::write($handle, "SET NAMES {$charset};\n");
            self::write($handle, "SET FOREIGN_KEY_CHECKS = 0;\n\n");

            $tableRows = $pdo->query('SHOW FULL TABLES')->fetchAll(PDO::FETCH_NUM);
            usort($tableRows, function ($left, $right) {
                $leftIsView = strtoupper((string)($left[1] ?? 'BASE TABLE')) === 'VIEW';
                $rightIsView = strtoupper((string)($right[1] ?? 'BASE TABLE')) === 'VIEW';
                return (int)$leftIsView <=> (int)$rightIsView;
            });

            $pdo->exec('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
            $pdo->beginTransaction();
            $inTransaction = true;

            if ($bufferAttribute !== null) {
                $pdo->setAttribute($bufferAttribute, false);
            }

            foreach ($tableRows as $tableRow) {
                $table = (string)($tableRow[0] ?? '');
                $type = strtoupper((string)($tableRow[1] ?? 'BASE TABLE'));
                if ($table === '') {
                    continue;
                }

                $identifier = self::quoteIdentifier($table);
                $createRow = $pdo->query("SHOW CREATE TABLE {$identifier}")->fetch(PDO::FETCH_NUM);
                if (!$createRow || !isset($createRow[1])) {
                    throw new RuntimeException("无法读取 {$table} 的建表语句");
                }

                if ($type === 'VIEW') {
                    self::write($handle, "DROP VIEW IF EXISTS {$identifier};\n");
                    self::write($handle, $createRow[1] . ";\n\n");
                    continue;
                }

                self::write($handle, "DROP TABLE IF EXISTS {$identifier};\n");
                self::write($handle, $createRow[1] . ";\n\n");

                $statement = $pdo->query("SELECT * FROM {$identifier}");
                while ($row = $statement->fetch(PDO::FETCH_NUM)) {
                    $values = [];
                    foreach ($row as $value) {
                        if ($value === null) {
                            $values[] = 'NULL';
                            continue;
                        }

                        $quoted = $pdo->quote((string)$value);
                        if ($quoted === false) {
                            throw new RuntimeException("无法转义 {$table} 的数据");
                        }
                        $values[] = $quoted;
                    }

                    self::write(
                        $handle,
                        "INSERT INTO {$identifier} VALUES (" . implode(', ', $values) . ");\n"
                    );
                }
                $statement->closeCursor();
                self::write($handle, "\n");
            }

            $pdo->commit();
            $inTransaction = false;

            self::write($handle, "SET FOREIGN_KEY_CHECKS = 1;\n");
            self::write($handle, "-- 备份完成\n");
        } catch (Throwable $e) {
            if ($inTransaction && $pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $e;
        } finally {
            if ($bufferAttribute !== null) {
                try {
                    $pdo->setAttribute($bufferAttribute, true);
                } catch (Throwable $e) {
                    // The connection is discarded at the end of this request.
                }
            }
            fclose($handle);
        }
    }

    private static function quoteIdentifier($value)
    {
        return '`' . str_replace('`', '``', $value) . '`';
    }

    private static function commentValue($value)
    {
        return str_replace(["\r", "\n"], ' ', (string)$value);
    }

    private static function write($handle, $content)
    {
        $length = strlen($content);
        $offset = 0;

        while ($offset < $length) {
            $written = fwrite($handle, substr($content, $offset));
            if ($written === false || $written === 0) {
                throw new RuntimeException('写入备份文件失败');
            }
            $offset += $written;
        }
    }
}
