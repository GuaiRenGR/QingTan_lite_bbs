<?php
/**
 * 帖子分享页
 *
 * 用法：
 *   share.php?id=123 — 显示帖子内容
 */

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Database.php';
require_once FX_ROOT . '/core/SiteSetting.php';
require_once FX_ROOT . '/core/DvCode.php';

$configFile = FX_ROOT . '/config/database.php';

if (!file_exists($configFile)) {
    http_response_code(500);
    echo '系统未安装';
    exit;
}

$config = require $configFile;
$prefix = $config['prefix'] ?? '';

$threadId = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if ($threadId <= 0) {
    http_response_code(400);
    echo '<h1>参数错误</h1>';
    exit;
}

$threads = $prefix . 'threads';
$users = $prefix . 'users';
$forums = $prefix . 'forums';

try {
    $pdo = Database::pdo();

    $pdo->prepare(
        "UPDATE {$threads} SET view_count = view_count + 1 WHERE id = ?"
    )->execute([$threadId]);

    $stmt = $pdo->prepare(
        "SELECT
            t.id, t.forum_id, t.title, t.content, t.summary, t.cover,
            t.type, t.view_count, t.reply_count, t.like_count,
            t.share_count, t.created_at, t.dv_code,
            u.id AS author_id, u.nickname AS author_name,
            u.avatar AS author_avatar,
            f.name AS forum_name
         FROM {$threads} t
         LEFT JOIN {$users} u ON u.id = t.user_id
         LEFT JOIN {$forums} f ON f.id = t.forum_id
         WHERE t.id = ? AND t.status = 1
         LIMIT 1"
    );
    $stmt->execute([$threadId]);
    $thread = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$thread) {
        http_response_code(404);
        echo '<h1>帖子不存在</h1>';
        exit;
    }

} catch (\Throwable $e) {
    http_response_code(500);
    echo '<h1>服务器异常</h1>';
    exit;
}

function bbcode_to_html($text) {
    $text = htmlspecialchars((string)$text, ENT_QUOTES, 'UTF-8');
    $text = preg_replace('/\[img=(https?:\/\/[^\]]+)\]/i', '<img src="$1" alt="图片" loading="lazy">', $text);
    $text = preg_replace('/\[video=(https?:\/\/[^\]]+)\]/i', '<a href="$1" target="_blank" rel="noopener" class="video-link">查看视频</a>', $text);
    $text = preg_replace('/\[music=(https?:\/\/[^\]]+)\]/i', '<a href="$1" target="_blank" rel="noopener" class="music-link">查看音频</a>', $text);
    $text = preg_replace('/\[url=(https?:\/\/[^\]]+)\]([\s\S]*?)\[\/url\]/i', '<a href="$1" target="_blank" rel="noopener">$2</a>', $text);
    $text = preg_replace('/\[hide\][\s\S]*?\[\/hide\]/i', '<span class="hidden-text">隐藏内容，请在App中查看</span>', $text);
    $text = preg_replace('/\[thread=([^\]]+)\]/i', '<span class="thread-link">帖子链接: $1</span>', $text);
    $text = preg_replace('/\[[a-zA-Z]+[^\]]*\]/', '', $text);
    $text = preg_replace('/\[\/[a-zA-Z]+\]/', '', $text);
    $text = nl2br($text);
    return $text;
}

$title = htmlspecialchars($thread['title'], ENT_QUOTES, 'UTF-8');
$authorName = htmlspecialchars($thread['author_name'] ?? '匿名', ENT_QUOTES, 'UTF-8');
$forumName = htmlspecialchars($thread['forum_name'] ?? '未分类', ENT_QUOTES, 'UTF-8');
$contentHtml = bbcode_to_html($thread['content']);
$coverUrl = htmlspecialchars($thread['cover'] ?? '', ENT_QUOTES, 'UTF-8');
$dvCode = htmlspecialchars($thread['dv_code'] ?? '', ENT_QUOTES, 'UTF-8');
$createdAt = date('Y-m-d H:i', strtotime($thread['created_at']));
$viewCount = (int)$thread['view_count'];
$replyCount = (int)$thread['reply_count'];
$likeCount = (int)$thread['like_count'];

$appLink = 'hyjzbbs://thread/' . $threadId;
$downloadUrl = request_origin() . '/download.php';
$summary = htmlspecialchars(make_summary($thread['content'], 120), ENT_QUOTES, 'UTF-8');

$pageTitle = $title . ' - 轻坛分享';
?><!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
    <title><?= $pageTitle ?></title>
    <meta property="og:title" content="<?= $title ?>">
    <meta property="og:description" content="<?= $summary ?>">
<?php if ($coverUrl): ?>
    <meta property="og:image" content="<?= $coverUrl ?>">
<?php endif; ?>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif;background:#f5f5f5;color:#333;line-height:1.6;-webkit-font-smoothing:antialiased}
        .container{max-width:680px;margin:0 auto;padding:0}
        .cover-wrapper{width:100%;overflow:hidden;background:#e0e0e0}
        .cover{display:block;width:100%;height:100%;object-fit:cover;object-position:top center}
        .content-wrap{padding:20px 16px}
        .forum-badge{display:inline-block;font-size:12px;color:#FB7299;background:rgba(251,114,153,0.1);padding:2px 10px;border-radius:10px;margin-bottom:10px}
        h1{font-size:22px;font-weight:700;line-height:1.4;margin-bottom:12px;color:#1a1a1a}
        .meta{display:flex;align-items:center;gap:10px;font-size:13px;color:#999;margin-bottom:20px;padding-bottom:16px;border-bottom:1px solid #eee;flex-wrap:wrap}
        .meta .author{color:#666;font-weight:500}
        .meta .dot{color:#ddd}
        .body-text{font-size:16px;color:#333;word-wrap:break-word;overflow-wrap:break-word}
        .body-text img{max-width:100%;height:auto;border-radius:8px;margin:12px 0;display:block}
        .body-text a{color:#FB7299;text-decoration:none}
        .body-text a:hover{text-decoration:underline}
        .body-text .video-link,.body-text .music-link{display:inline-block;padding:8px 16px;background:#f8f8f8;border-radius:8px;margin:4px 0;font-size:14px}
        .body-text .hidden-text{display:block;padding:12px 16px;background:#f0f0f0;border-radius:8px;color:#999;font-size:14px;text-align:center;margin:12px 0}
        .body-text .thread-link{color:#999;font-size:14px}
        .stats{display:flex;gap:20px;font-size:13px;color:#999;margin-top:20px;padding-top:16px;border-top:1px solid #eee}
        .stats span{display:flex;align-items:center;gap:4px}
        .app-banner{margin-top:24px;padding:20px 16px;background:linear-gradient(135deg,#FB7299,#FF9F6E);border-radius:12px;text-align:center;color:#fff}
        .app-banner h3{font-size:17px;font-weight:600;margin-bottom:6px}
        .app-banner p{font-size:13px;opacity:0.9;margin-bottom:14px}
        .app-banner .btn-group{display:flex;gap:10px;justify-content:center;flex-wrap:wrap}
        .app-banner .btn{display:inline-flex;align-items:center;gap:6px;padding:10px 20px;border-radius:24px;font-size:14px;font-weight:500;text-decoration:none;transition:transform 0.1s,opacity 0.15s}
        .app-banner .btn-primary{background:#fff;color:#FB7299}
        .app-banner .btn-secondary{background:rgba(255,255,255,0.2);color:#fff;border:1px solid rgba(255,255,255,0.3)}
        .app-banner .btn:active{transform:scale(0.96)}
        .dv-code{text-align:center;font-size:12px;color:#bbb;margin-top:16px;padding-bottom:32px}
        .footer{text-align:center;color:#bbb;font-size:12px;margin-top:8px;padding-bottom:32px}
    </style>
</head>
<body>
<div class="container">
<?php if ($coverUrl): ?>
    <div class="cover-wrapper">
        <img class="cover" src="<?= $coverUrl ?>" alt="封面" loading="lazy">
    </div>
<?php endif; ?>
    <div class="content-wrap">
        <div class="forum-badge"><?= $forumName ?></div>
        <h1><?= $title ?></h1>
        <div class="meta">
            <span class="author"><?= $authorName ?></span>
            <span class="dot">·</span>
            <span><?= $createdAt ?></span>
<?php if ($dvCode): ?>
            <span class="dot">·</span>
            <span>DV <?= $dvCode ?></span>
<?php endif; ?>
        </div>
        <div class="body-text"><?= $contentHtml ?></div>
        <div class="stats">
            <span><?= $viewCount ?> 阅读</span>
            <span><?= $replyCount ?> 回复</span>
            <span><?= $likeCount ?> 点赞</span>
        </div>
        <div class="app-banner">
            <h3>轻坛 · 轻量论坛</h3>
            <p>查看完整内容和回复，体验最佳阅读效果</p>
            <div class="btn-group">
                <a class="btn btn-primary" href="<?= $appLink ?>">打开App查看全文</a>
                <a class="btn btn-secondary" href="<?= $downloadUrl ?>">下载App</a>
            </div>
        </div>
<?php if ($dvCode): ?>
        <div class="dv-code">DV <?= $dvCode ?></div>
<?php endif; ?>
    </div>
    <div class="footer">轻坛 QingTan · 分享页</div>
</div>
<script>
document.addEventListener('DOMContentLoaded', function() {
    var img = document.querySelector('.cover-wrapper img');
    if (!img) return;
    function setCoverRatio() {
        if (img.naturalWidth > 0 && img.naturalHeight > 0) {
            var r = img.naturalWidth / img.naturalHeight;
            var MAX_RATIO = 21 / 9;   // 横版最宽
            var MIN_RATIO = 9 / 16;   // 竖版最高
            if (r > MAX_RATIO) r = MAX_RATIO;
            if (r < MIN_RATIO) r = MIN_RATIO;
            img.parentElement.style.aspectRatio = r;
        }
    }
    if (img.complete) {
        setCoverRatio();
    } else {
        img.onload = setCoverRatio;
        img.onerror = function() {
            // 加载失败时使用默认16:9
            img.parentElement.style.aspectRatio = '16/9';
        };
    }
});
</script>
</body>
</html>
