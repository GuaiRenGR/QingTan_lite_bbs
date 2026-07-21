<?php
/**
 * ForumX Lite 安装向导
 * 原生 PHP 虚拟主机版
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

define('FX_ROOT', __DIR__);
define('FX_CONFIG_DIR', FX_ROOT . '/config');
define('FX_DB_CONFIG_FILE', FX_CONFIG_DIR . '/database.php');
define('FX_INSTALL_LOCK', FX_ROOT . '/runtime/install.lock');

if (file_exists(FX_INSTALL_LOCK)) {
    exit('系统已安装。如需重新安装，请删除 runtime/install.lock。');
}

function h($str)
{
    return htmlspecialchars((string)$str, ENT_QUOTES, 'UTF-8');
}

function checkWritable($path)
{
    if (!is_dir($path)) {
        @mkdir($path, 0755, true);
    }
    return is_writable($path);
}

function renderHeader()
{
    echo '<!doctype html><html><head><meta charset="utf-8">';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
    echo '<title>ForumX Lite 安装向导</title>';
    echo '<style>
        body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Arial;background:#f6f7f9;margin:0;padding:30px;}
        .box{max-width:820px;margin:0 auto;background:#fff;border-radius:12px;padding:24px;box-shadow:0 4px 20px rgba(0,0,0,.06);}
        h1{margin-top:0;}
        table{width:100%;border-collapse:collapse;margin:15px 0;}
        td,th{border-bottom:1px solid #eee;padding:10px;text-align:left;}
        .ok{color:#16a34a;font-weight:bold;}
        .fail{color:#dc2626;font-weight:bold;}
        input{width:100%;box-sizing:border-box;padding:10px;border:1px solid #ddd;border-radius:6px;}
        .form-row{margin-bottom:14px;}
        button{background:#fb7299;color:#fff;border:none;padding:12px 22px;border-radius:8px;cursor:pointer;font-size:15px;}
        .tip{color:#666;font-size:13px;}
        .error{background:#fee2e2;color:#991b1b;padding:12px;border-radius:8px;margin:12px 0;}
        .success{background:#dcfce7;color:#166534;padding:12px;border-radius:8px;margin:12px 0;}
    </style>';
    echo '</head><body><div class="box">';
}

function renderFooter()
{
    echo '</div></body></html>';
}

function createTables(PDO $pdo, string $prefix)
{
    $sqls = [];

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}users` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `username` VARCHAR(50) NOT NULL,
      `nickname` VARCHAR(50) NOT NULL,
      `email` VARCHAR(100) DEFAULT NULL,
      `password_hash` VARCHAR(255) NOT NULL,
      `avatar` VARCHAR(255) DEFAULT NULL,
      `space_cover` VARCHAR(255) DEFAULT NULL,
      `bio` VARCHAR(255) DEFAULT NULL,
      `group_id` INT NOT NULL DEFAULT 1,
      `level` INT NOT NULL DEFAULT 1,
      `score` INT NOT NULL DEFAULT 0,
      `points` INT NOT NULL DEFAULT 0,
      `checkin_days` INT NOT NULL DEFAULT 0,
      `last_checkin_date` DATE DEFAULT NULL,
      `followers_count` INT NOT NULL DEFAULT 0,
      `following_count` INT NOT NULL DEFAULT 0,
      `status` TINYINT NOT NULL DEFAULT 1,
      `last_login_at` DATETIME DEFAULT NULL,
      `last_login_ip` VARCHAR(45) DEFAULT NULL,
      `created_at` DATETIME NOT NULL,
      `updated_at` DATETIME DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_username` (`username`),
      UNIQUE KEY `uk_email` (`email`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}user_tokens` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `token_hash` CHAR(64) NOT NULL,
      `device_id` VARCHAR(100) DEFAULT NULL,
      `ip` VARCHAR(45) DEFAULT NULL,
      `user_agent` VARCHAR(255) DEFAULT NULL,
      `expired_at` DATETIME NOT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_user_id` (`user_id`),
      UNIQUE KEY `uk_token_hash` (`token_hash`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}user_groups` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `name` VARCHAR(50) NOT NULL,
      `type` VARCHAR(20) NOT NULL DEFAULT 'member',
      `permissions` TEXT DEFAULT NULL,
      `min_score` INT NOT NULL DEFAULT 0,
      `max_score` INT NOT NULL DEFAULT 999999999,
      `status` TINYINT NOT NULL DEFAULT 1,
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}forums` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `parent_id` INT DEFAULT 0,
      `name` VARCHAR(100) NOT NULL,
      `icon` VARCHAR(255) DEFAULT NULL,
      `cover` VARCHAR(255) DEFAULT NULL,
      `description` TEXT DEFAULT NULL,
      `rules` TEXT DEFAULT NULL,
      `sort_order` INT NOT NULL DEFAULT 0,
      `thread_count` INT NOT NULL DEFAULT 0,
      `post_count` INT NOT NULL DEFAULT 0,
      `today_count` INT NOT NULL DEFAULT 0,
      `need_audit` TINYINT NOT NULL DEFAULT 0,
      `status` TINYINT NOT NULL DEFAULT 1,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_status_sort` (`status`, `sort_order`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}threads` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `forum_id` INT NOT NULL,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `dv_code` VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
      `type` VARCHAR(20) NOT NULL DEFAULT 'normal',
      `title` VARCHAR(120) NOT NULL,
      `summary` VARCHAR(255) DEFAULT NULL,
      `content` MEDIUMTEXT NOT NULL,
      `cover` VARCHAR(1000) DEFAULT NULL,
      `mode` VARCHAR(20) NOT NULL DEFAULT 'article',
      `images_json` MEDIUMTEXT NULL,
      `music_url` VARCHAR(1000) DEFAULT NULL,
      `music_name` VARCHAR(255) DEFAULT NULL,
      `view_count` INT NOT NULL DEFAULT 0,
      `reply_count` INT NOT NULL DEFAULT 0,
      `like_count` INT NOT NULL DEFAULT 0,
      `favorite_count` INT NOT NULL DEFAULT 0,
      `share_count` INT NOT NULL DEFAULT 0,
      `is_top` TINYINT NOT NULL DEFAULT 0,
      `is_digest` TINYINT NOT NULL DEFAULT 0,
      `is_closed` TINYINT NOT NULL DEFAULT 0,
      `status` TINYINT NOT NULL DEFAULT 1,
      `last_reply_at` DATETIME DEFAULT NULL,
      `created_at` DATETIME NOT NULL,
      `updated_at` DATETIME DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `idx_dv_code` (`dv_code`),
      KEY `idx_forum_status_time` (`forum_id`, `status`, `created_at`),
      KEY `idx_user_status_time` (`user_id`, `status`, `created_at`),
      KEY `idx_feed` (`status`, `is_top`, `is_digest`, `last_reply_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}thread_dv_aliases` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `thread_id` BIGINT UNSIGNED NOT NULL,
      `dv_code` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_dv_code` (`dv_code`),
      KEY `idx_thread_id` (`thread_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}posts` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `thread_id` BIGINT UNSIGNED NOT NULL,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `parent_id` BIGINT UNSIGNED DEFAULT NULL,
      `quote_post_id` BIGINT UNSIGNED DEFAULT NULL,
      `content` MEDIUMTEXT NOT NULL,
      `floor` INT NOT NULL DEFAULT 1,
      `like_count` INT NOT NULL DEFAULT 0,
      `status` TINYINT NOT NULL DEFAULT 1,
      `created_at` DATETIME NOT NULL,
      `updated_at` DATETIME DEFAULT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_thread_floor` (`thread_id`, `status`, `floor`),
      KEY `idx_user_time` (`user_id`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}likes` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `object_type` VARCHAR(20) NOT NULL,
      `object_id` BIGINT UNSIGNED NOT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_like` (`user_id`, `object_type`, `object_id`),
      KEY `idx_object` (`object_type`, `object_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}favorites` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `object_type` VARCHAR(20) NOT NULL,
      `object_id` BIGINT UNSIGNED NOT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_fav` (`user_id`, `object_type`, `object_id`),
      KEY `idx_object` (`object_type`, `object_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}checkins` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `checkin_date` DATE NOT NULL,
      `reward_score` INT NOT NULL DEFAULT 0,
      `continuous_days` INT NOT NULL DEFAULT 1,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_user_date` (`user_id`, `checkin_date`),
      KEY `idx_date` (`checkin_date`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}music_playlists` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `name` VARCHAR(100) NOT NULL,
      `description` VARCHAR(500) DEFAULT NULL,
      `cover_url` VARCHAR(1000) DEFAULT NULL,
      `default_key` BIGINT UNSIGNED DEFAULT NULL,
      `is_default` TINYINT NOT NULL DEFAULT 0,
      `status` TINYINT NOT NULL DEFAULT 1,
      `created_at` DATETIME NOT NULL,
      `updated_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_default_key` (`default_key`),
      KEY `idx_user_status` (`user_id`, `status`, `is_default`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}music_playlist_tracks` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `playlist_id` BIGINT UNSIGNED NOT NULL,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `music_uuid` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
      `music_key` CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `music_url` VARCHAR(1000) NOT NULL,
      `lyrics_url` VARCHAR(1000) DEFAULT NULL,
      `cover_url` VARCHAR(1000) DEFAULT NULL,
      `title` VARCHAR(255) NOT NULL,
      `artist` VARCHAR(255) DEFAULT NULL,
      `sort_order` INT NOT NULL DEFAULT 0,
      `status` TINYINT NOT NULL DEFAULT 1,
      `created_at` DATETIME NOT NULL,
      `updated_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_playlist_music` (`playlist_id`, `music_key`),
      UNIQUE KEY `uk_playlist_music_uuid` (`playlist_id`, `music_uuid`),
      KEY `idx_user_time` (`user_id`, `created_at`),
      KEY `idx_playlist_sort` (`playlist_id`, `status`, `sort_order`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}score_logs` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `action` VARCHAR(50) NOT NULL,
      `amount` INT NOT NULL,
      `balance` INT NOT NULL,
      `remark` VARCHAR(255) DEFAULT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_user_time` (`user_id`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}attachment_folders` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `name` VARCHAR(50) NOT NULL,
      `created_by` BIGINT UNSIGNED NOT NULL,
      `status` TINYINT NOT NULL DEFAULT 1,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_name_status` (`name`, `status`),
      KEY `idx_status_name` (`status`, `name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}attachments` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `object_type` VARCHAR(20) DEFAULT NULL,
      `object_id` BIGINT UNSIGNED DEFAULT NULL,
      `folder_id` BIGINT UNSIGNED DEFAULT NULL,
      `file_name` VARCHAR(255) NOT NULL,
      `file_path` VARCHAR(1000) NOT NULL,
      `file_url` VARCHAR(1000) NOT NULL,
      `file_type` VARCHAR(80) DEFAULT NULL,
      `file_size` BIGINT UNSIGNED NOT NULL DEFAULT 0,
      `onedrive_item_id` VARCHAR(255) DEFAULT NULL,
      `status` TINYINT NOT NULL DEFAULT 1,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_object` (`object_type`, `object_id`),
      KEY `idx_folder` (`folder_id`, `status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}music_library` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `uuid` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `uploader_id` BIGINT UNSIGNED NOT NULL,
      `attachment_id` BIGINT UNSIGNED DEFAULT NULL,
      `audio_url` VARCHAR(1000) NOT NULL,
      `lyrics_url` VARCHAR(1000) DEFAULT NULL,
      `cover_url` VARCHAR(1000) DEFAULT NULL,
      `title` VARCHAR(255) NOT NULL,
      `artist` VARCHAR(255) DEFAULT NULL,
      `original_name` VARCHAR(255) DEFAULT NULL,
      `status` TINYINT NOT NULL DEFAULT 1,
      `created_at` DATETIME NOT NULL,
      `updated_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_music_uuid` (`uuid`),
      KEY `idx_music_search` (`status`, `title`, `artist`),
      KEY `idx_uploader_time` (`uploader_id`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}notifications` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `type` VARCHAR(50) NOT NULL,
      `title` VARCHAR(100) NOT NULL,
      `content` TEXT DEFAULT NULL,
      `data` TEXT DEFAULT NULL,
      `is_read` TINYINT NOT NULL DEFAULT 0,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_user_read_time` (`user_id`, `is_read`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}reports` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `reporter_id` BIGINT UNSIGNED NOT NULL,
      `target_type` VARCHAR(20) NOT NULL,
      `target_id` BIGINT UNSIGNED NOT NULL,
      `reason` VARCHAR(100) NOT NULL,
      `description` TEXT DEFAULT NULL,
      `status` TINYINT NOT NULL DEFAULT 1,
      `handler_id` BIGINT UNSIGNED DEFAULT NULL,
      `handled_at` DATETIME DEFAULT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_status_time` (`status`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}user_follows` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `follower_id` BIGINT UNSIGNED NOT NULL,
      `following_id` BIGINT UNSIGNED NOT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_follow` (`follower_id`, `following_id`),
      KEY `idx_follower` (`follower_id`),
      KEY `idx_following` (`following_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}shares` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED DEFAULT NULL,
      `thread_id` BIGINT UNSIGNED NOT NULL,
      `ip` VARCHAR(64) DEFAULT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_thread` (`thread_id`),
      KEY `idx_user` (`user_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}settings` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `setting_key` VARCHAR(100) NOT NULL,
      `setting_value` MEDIUMTEXT DEFAULT NULL,
      `type` VARCHAR(20) DEFAULT 'string',
      `updated_at` DATETIME DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_key` (`setting_key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}app_versions` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `platform` VARCHAR(30) NOT NULL DEFAULT 'all',
      `version` VARCHAR(50) NOT NULL,
      `build_number` INT NOT NULL DEFAULT 1,
      `force_update` TINYINT NOT NULL DEFAULT 0,
      `title` VARCHAR(255) DEFAULT NULL,
      `content` TEXT DEFAULT NULL,
      `download_url` VARCHAR(1000) DEFAULT NULL,
      `status` TINYINT NOT NULL DEFAULT 1,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_platform_status` (`platform`, `status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}content_stats_daily` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `object_type` VARCHAR(30) NOT NULL,
      `object_id` BIGINT UNSIGNED NOT NULL,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `stat_date` DATE NOT NULL,
      `view_count` INT NOT NULL DEFAULT 0,
      `like_count` INT NOT NULL DEFAULT 0,
      `favorite_count` INT NOT NULL DEFAULT 0,
      `share_count` INT NOT NULL DEFAULT 0,
      `reply_count` INT NOT NULL DEFAULT 0,
      `created_at` DATETIME NOT NULL,
      `updated_at` DATETIME DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_object_date` (`object_type`, `object_id`, `stat_date`),
      KEY `idx_user_date` (`user_id`, `stat_date`),
      KEY `idx_object` (`object_type`, `object_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}histories` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `object_type` VARCHAR(30) NOT NULL,
      `object_id` BIGINT UNSIGNED NOT NULL,
      `last_viewed_at` DATETIME NOT NULL,
      `view_count` INT NOT NULL DEFAULT 1,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_user_object` (`user_id`, `object_type`, `object_id`),
      KEY `idx_user_time` (`user_id`, `last_viewed_at`),
      KEY `idx_object` (`object_type`, `object_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}conversations` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_a_id` BIGINT UNSIGNED NOT NULL,
      `user_b_id` BIGINT UNSIGNED NOT NULL,
      `last_message_at` DATETIME DEFAULT NULL,
      `last_message_preview` VARCHAR(100) DEFAULT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_pair` (`user_a_id`, `user_b_id`),
      KEY `idx_user_a` (`user_a_id`, `last_message_at`),
      KEY `idx_user_b` (`user_b_id`, `last_message_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}messages` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `conversation_id` BIGINT UNSIGNED NOT NULL,
      `sender_id` BIGINT UNSIGNED NOT NULL,
      `content` TEXT NOT NULL,
      `is_read` TINYINT NOT NULL DEFAULT 0,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_conv_time` (`conversation_id`, `created_at`),
      KEY `idx_sender` (`sender_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}notification_settings` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED NOT NULL,
      `type` VARCHAR(50) NOT NULL,
      `dnd` TINYINT NOT NULL DEFAULT 0,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uk_user_type` (`user_id`, `type`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}search_logs` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `user_id` BIGINT UNSIGNED DEFAULT NULL,
      `keyword` VARCHAR(255) NOT NULL,
      `ip` VARCHAR(64) DEFAULT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_keyword` (`keyword`),
      KEY `idx_user` (`user_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}sync_operation_log` (
      `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      `server_id` INT UNSIGNED NOT NULL COMMENT '来源服务器ID',
      `src_op_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '来源服务器的日志ID',
      `op_type` VARCHAR(16) NOT NULL COMMENT 'insert | update | delete',
      `table_name` VARCHAR(64) NOT NULL COMMENT '表名',
      `row_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '受影响行的主键ID',
      `row_data` MEDIUMTEXT COMMENT '行数据的 JSON 快照',
      `old_data` MEDIUMTEXT COMMENT '更新前的旧数据',
      `created_at` DATETIME NOT NULL,
      `synced_at` DATETIME DEFAULT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_server_op` (`server_id`, `src_op_id`),
      KEY `idx_synced` (`synced_at`),
      KEY `idx_created` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}sync_server_status` (
      `server_id` INT UNSIGNED NOT NULL,
      `server_url` VARCHAR(255) NOT NULL,
      `server_name` VARCHAR(64) NOT NULL,
      `last_ping_at` DATETIME DEFAULT NULL,
      `last_sync_at` DATETIME DEFAULT NULL,
      `last_sync_op_id` BIGINT UNSIGNED DEFAULT 0,
      `status` VARCHAR(16) NOT NULL DEFAULT 'active',
      `version` VARCHAR(32) DEFAULT NULL,
      `created_at` DATETIME NOT NULL,
      `updated_at` DATETIME NOT NULL,
      PRIMARY KEY (`server_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    $sqls[] = "
    CREATE TABLE IF NOT EXISTS `{$prefix}id_sequences` (
      `table_name` VARCHAR(64) NOT NULL,
      `next_id` BIGINT UNSIGNED NOT NULL DEFAULT 1,
      PRIMARY KEY (`table_name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    foreach ($sqls as $sql) {
        $pdo->exec($sql);
    }
}

renderHeader();

$step = $_GET['step'] ?? 'check';

if ($step === 'check') {
    $checks = [
        'PHP 版本 >= 7.4' => version_compare(PHP_VERSION, '7.4.0', '>='),
        'PDO 扩展' => extension_loaded('pdo'),
        'PDO MySQL 扩展' => extension_loaded('pdo_mysql'),
        'JSON 支持' => function_exists('json_encode'),
        'GD 图片扩展，验证码需要' => extension_loaded('gd'),
        'file_uploads 开启' => (bool)ini_get('file_uploads'),
        'config 目录可写' => checkWritable(FX_CONFIG_DIR),
        'uploads 目录可写' => checkWritable(FX_ROOT . '/uploads'),
        'cache 目录可写' => checkWritable(FX_ROOT . '/cache'),
        'runtime 目录可写' => checkWritable(FX_ROOT . '/runtime'),
        'runtime/logs 目录可写' => checkWritable(FX_ROOT . '/runtime/logs'),
    ];

    echo '<h1>ForumX Lite 安装向导</h1>';
    echo '<h2>环境检测</h2>';
    echo '<table>';
    foreach ($checks as $name => $ok) {
        echo '<tr><td>' . h($name) . '</td><td>' . ($ok ? '<span class="ok">通过</span>' : '<span class="fail">失败</span>') . '</td></tr>';
    }
    echo '</table>';

    if (in_array(false, $checks, true)) {
        echo '<div class="error">环境检测未通过，请修复后刷新。</div>';
    } else {
        echo '<a href="?step=db"><button>下一步：数据库配置</button></a>';
    }

    renderFooter();
    exit;
}

if ($step === 'db' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    echo '<h1>数据库配置</h1>';
    echo '<form method="post" action="?step=install">';
    echo '<div class="form-row"><label>数据库主机</label><input name="db_host" value="localhost" required></div>';
    echo '<div class="form-row"><label>数据库端口</label><input name="db_port" value="3306" required></div>';
    echo '<div class="form-row"><label>数据库名</label><input name="db_name" required></div>';
    echo '<div class="form-row"><label>数据库用户名</label><input name="db_user" required></div>';
    echo '<div class="form-row"><label>数据库密码</label><input name="db_pass" type="password"></div>';
    echo '<div class="form-row"><label>表前缀</label><input name="db_prefix" value="fx_" required></div>';
    echo '<hr>';
    echo '<h2>管理员账号</h2>';
    echo '<div class="form-row"><label>管理员用户名</label><input name="admin_user" value="admin" required></div>';
    echo '<div class="form-row"><label>管理员密码</label><input name="admin_pass" type="password" required></div>';
    echo '<div class="form-row"><label>管理员邮箱</label><input name="admin_email" value="admin@example.com"></div>';
    echo '<button type="submit">开始安装</button>';
    echo '</form>';
    renderFooter();
    exit;
}

if ($step === 'install' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $dbHost = trim($_POST['db_host'] ?? '');
    $dbPort = trim($_POST['db_port'] ?? '3306');
    $dbName = trim($_POST['db_name'] ?? '');
    $dbUser = trim($_POST['db_user'] ?? '');
    $dbPass = (string)($_POST['db_pass'] ?? '');
    $prefix = trim($_POST['db_prefix'] ?? 'fx_');

    $adminUser = trim($_POST['admin_user'] ?? 'admin');
    $adminPass = (string)($_POST['admin_pass'] ?? '');
    $adminEmail = trim($_POST['admin_email'] ?? '');

    if (!$dbHost || !$dbName || !$dbUser || !$adminUser || strlen($adminPass) < 6) {
        echo '<div class="error">请填写完整信息，管理员密码至少 6 位。</div>';
        echo '<a href="?step=db">返回</a>';
        renderFooter();
        exit;
    }

    try {
        $dsn = "mysql:host={$dbHost};port={$dbPort};dbname={$dbName};charset=utf8mb4";
        $pdo = new PDO($dsn, $dbUser, $dbPass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);

        createTables($pdo, $prefix);

        $now = date('Y-m-d H:i:s');

        $pdo->prepare("INSERT IGNORE INTO `{$prefix}user_groups`
            (`id`,`name`,`type`,`permissions`,`min_score`,`max_score`,`status`)
            VALUES
            (1,'普通会员','member','{\"thread.create\":true,\"post.create\":true}',0,999999999,1),
            (99,'管理员','admin','{\"admin\":true}',0,999999999,1)")
            ->execute();

        $pdo->prepare("INSERT IGNORE INTO `{$prefix}forums`
            (`id`,`name`,`description`,`sort_order`,`status`,`created_at`)
            VALUES
            (1,'综合讨论','日常交流与综合话题',1,1,?),
            (2,'站务公告','官方公告与社区规则',2,1,?),
            (3,'技术交流','开发、运维、AI 等技术内容',3,1,?)")
            ->execute([$now, $now, $now]);

        $hash = password_hash($adminPass, PASSWORD_DEFAULT);

        $stmt = $pdo->prepare("SELECT id FROM `{$prefix}users` WHERE username = ?");
        $stmt->execute([$adminUser]);
        $exists = $stmt->fetch();

        if (!$exists) {
            $stmt = $pdo->prepare("INSERT INTO `{$prefix}users`
                (`username`,`nickname`,`email`,`password_hash`,`group_id`,`level`,`score`,`status`,`created_at`,`updated_at`)
                VALUES (?,?,?,?,99,1,0,1,?,?)");
            $stmt->execute([
                $adminUser,
                $adminUser,
                $adminEmail ?: null,
                $hash,
                $now,
                $now
            ]);
        }

        $configContent = "<?php\nreturn " . var_export([
            'host' => $dbHost,
            'port' => $dbPort,
            'database' => $dbName,
            'username' => $dbUser,
            'password' => $dbPass,
            'prefix' => $prefix,
            'charset' => 'utf8mb4',
        ], true) . ";\n";

        if (!is_dir(FX_CONFIG_DIR)) {
            mkdir(FX_CONFIG_DIR, 0755, true);
        }

        file_put_contents(FX_DB_CONFIG_FILE, $configContent);

        if (!is_dir(FX_ROOT . '/runtime')) {
            mkdir(FX_ROOT . '/runtime', 0755, true);
        }

        file_put_contents(FX_INSTALL_LOCK, 'installed at ' . $now);

        echo '<div class="success">安装成功！</div>';
        echo '<p>API 入口：<code>index.php?route=home/feed</code></p>';
        echo '<p>管理员账号：' . h($adminUser) . '</p>';
        echo '<p class="tip">安全建议：请删除或重命名 install.php。</p>';
        echo '<a href="index.php?route=home/feed"><button>访问 API 测试</button></a>';

    } catch (Throwable $e) {
        echo '<div class="error">安装失败：' . h($e->getMessage()) . '</div>';
        echo '<a href="?step=db">返回修改</a>';
    }

    renderFooter();
    exit;
}

echo 'Invalid step.';
renderFooter();
