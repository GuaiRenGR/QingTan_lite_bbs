<?php

class Database
{
    private static $pdo = null;
    private static $config = null;

    public static function pdo()
    {
        if (self::$pdo) {
            return self::$pdo;
        }

        self::$config = require FX_ROOT . '/config/database.php';

        $dsn = sprintf(
            'mysql:host=%s;port=%s;dbname=%s;charset=%s',
            self::$config['host'],
            self::$config['port'],
            self::$config['database'],
            self::$config['charset'] ?? 'utf8mb4'
        );

        self::$pdo = new PDO($dsn, self::$config['username'], self::$config['password'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);

        self::applyServerId();

        return self::$pdo;
    }

    private static function applyServerId()
    {
        try {
            $configFile = FX_ROOT . '/config/servers.php';
            if (!file_exists($configFile)) {
                return;
            }
            $serverConfig = require $configFile;
            $serverId = (int)$serverConfig['server_id'];
            $maxServers = count($serverConfig['servers']) + 5;
            if ($maxServers < 2) {
                return;
            }
            self::$pdo->exec("SET @@session.auto_increment_increment = {$maxServers}");
            self::$pdo->exec("SET @@session.auto_increment_offset = {$serverId}");
        } catch (\Throwable $e) {
            log_error('[AutoIncrement] ' . $e->getMessage());
        }
    }

    public static function table($name)
    {
        if (!self::$config) {
            self::$config = require FX_ROOT . '/config/database.php';
        }

        return '`' . self::$config['prefix'] . $name . '`';
    }

    public static function fetch($sql, $params = [])
    {
        $stmt = self::pdo()->prepare($sql);
        $stmt->execute($params);

        return $stmt->fetch();
    }

    public static function fetchAll($sql, $params = [])
    {
        $stmt = self::pdo()->prepare($sql);
        $stmt->execute($params);

        return $stmt->fetchAll();
    }

    public static function execute($sql, $params = [])
    {
        $stmt = self::pdo()->prepare($sql);

        return $stmt->execute($params);
    }

    public static function lastInsertId()
    {
        return self::pdo()->lastInsertId();
    }

    public static function begin()
    {
        self::pdo()->beginTransaction();
    }

    public static function commit()
    {
        self::pdo()->commit();
    }

    public static function rollback()
    {
        if (self::pdo()->inTransaction()) {
            self::pdo()->rollBack();
        }
    }
}
