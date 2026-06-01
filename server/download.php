<?php
/**
 * 永久下载页
 *
 * 用法：
 *   download.php              — 显示全部平台链接
 *   download.php?os=android   — 302 跳转到安卓下载
 *   download.php?os=ios       — 302 跳转到 iOS 下载
 *   download.php?os=windows   — 302 跳转到 Windows 下载
 *   download.php?os=macos     — 302 跳转到 macOS 下载
 *   download.php?os=linux     — 302 跳转到 Linux 下载
 */

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/Database.php';
require_once FX_ROOT . '/core/SiteSetting.php';

$configFile = FX_ROOT . '/config/database.php';

if (!file_exists($configFile)) {
    http_response_code(500);
    echo '系统未安装';
    exit;
}

$config = require $configFile;
$prefix = $config['prefix'] ?? '';

$platforms = [
    'android' => ['label' => 'Android', 'icon' => '🤖'],
    'ios'     => ['label' => 'iOS',     'icon' => '🍎'],
    'windows' => ['label' => 'Windows', 'icon' => '🪟'],
    'macos'   => ['label' => 'macOS',   'icon' => '🍎'],
    'linux'   => ['label' => 'Linux',   'icon' => '🐧'],
];

$os = strtolower(trim($_GET['os'] ?? ''));

// 读取配置
function getSetting($key) {
    $prefix = $GLOBALS['prefix'];
    $pdo = Database::pdo();
    $stmt = $pdo->prepare("SELECT `value` FROM `{$prefix}site_settings` WHERE `key` = ? LIMIT 1");
    $stmt->execute([$key]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return $row ? trim($row['value']) : '';
}

// 有 os 参数时尝试跳转
if ($os !== '' && isset($platforms[$os])) {
    $url = getSetting('dl_' . $os);

    if (!empty($url) && filter_var($url, FILTER_VALIDATE_URL)) {
        header('Location: ' . $url, true, 302);
        exit;
    }

    // 没有配置该平台链接，显示提示页
    $info = $platforms[$os];
}

// 无参数或链接未配置 — 显示全部平台列表
$pageTitle = '下载中心';
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($pageTitle) ?></title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #f5f5f5;
            color: #333;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            width: 100%;
            max-width: 420px;
            padding: 24px;
        }
        .card {
            background: #fff;
            border-radius: 16px;
            padding: 32px 24px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.08);
        }
        h1 {
            font-size: 24px;
            font-weight: 700;
            text-align: center;
            margin-bottom: 8px;
        }
        .subtitle {
            text-align: center;
            color: #999;
            font-size: 14px;
            margin-bottom: 24px;
        }
        .not-found {
            text-align: center;
            color: #999;
            font-size: 14px;
            padding: 20px 0;
        }
        .btn {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 14px 18px;
            margin-bottom: 10px;
            background: #f8f8f8;
            border-radius: 12px;
            text-decoration: none;
            color: #333;
            transition: background 0.15s, transform 0.1s;
        }
        .btn:hover {
            background: #eee;
            transform: translateY(-1px);
        }
        .btn:active {
            transform: translateY(0);
        }
        .btn-left {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .btn-icon {
            font-size: 20px;
        }
        .btn-label {
            font-size: 15px;
            font-weight: 500;
        }
        .btn-arrow {
            color: #ccc;
            font-size: 18px;
        }
        .btn-unavailable {
            opacity: 0.45;
            pointer-events: none;
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #bbb;
            font-size: 12px;
        }
    </style>
</head>
<body>
<div class="container">
    <div class="card">
        <h1>下载中心</h1>
        <p class="subtitle">选择你的平台</p>

        <?php if (isset($info)): ?>
            <div class="not-found">
                <p style="font-size:32px; margin-bottom:12px;"><?= $info['icon'] ?></p>
                <p><?= htmlspecialchars($info['label']) ?> 版本暂未开放下载</p>
                <p style="margin-top:6px;"><a href="download.php" style="color:#FB7299;">← 返回全部平台</a></p>
            </div>
        <?php else: ?>
            <?php foreach ($platforms as $key => $info): ?>
                <?php
                    $url = getSetting('dl_' . $key);
                    $available = !empty($url) && filter_var($url, FILTER_VALIDATE_URL);
                ?>
                <a class="btn <?= $available ? '' : 'btn-unavailable' ?>"
                   href="<?= $available ? htmlspecialchars($url) : '#' ?>">
                    <span class="btn-left">
                        <span class="btn-icon"><?= $info['icon'] ?></span>
                        <span class="btn-label"><?= htmlspecialchars($info['label']) ?></span>
                    </span>
                    <span class="btn-arrow">
                        <?= $available ? '→' : '暂未开放' ?>
                    </span>
                </a>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>
    <p class="footer">轻坛 QingTan · 永久下载页</p>
</div>
</body>
</html>
