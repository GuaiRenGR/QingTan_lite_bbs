<?php

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Response.php';
require_once FX_ROOT . '/core/Request.php';
require_once FX_ROOT . '/core/Database.php';
require_once FX_ROOT . '/core/Auth.php';
require_once FX_ROOT . '/core/SiteSetting.php';
require_once FX_ROOT . '/core/OneDriveService.php';
require_once FX_ROOT . '/core/DvCode.php';

spl_autoload_register(function ($class) {
    $prefix = 'App\\Controllers\\';
    if (strpos($class, $prefix) === 0) {
        $name = substr($class, strlen($prefix));
        $file = FX_ROOT . '/app/Controllers/' . $name . '.php';
        if (file_exists($file)) {
            require_once $file;
        }
    }
});

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type, X-Client, X-Device-ID');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

if (!file_exists(FX_ROOT . '/config/database.php')) {
    Response::json(500, '系统未安装，请先访问 install.php');
}

$route = $_GET['route'] ?? '';

// 请求采样触发同步
$serverConfig = [];
if (file_exists(FX_ROOT . '/config/servers.php')) {
    $serverConfig = require FX_ROOT . '/config/servers.php';
    if (
        !empty($serverConfig['sync']['sample_rate']) &&
        mt_rand(1, 100) <= (int)$serverConfig['sync']['sample_rate'] &&
        !in_array($route, ['sync/trigger', 'sync/push', 'sync/pull', 'sync/receive'], true)
    ) {
        try {
            sync_run_all();
        } catch (\Throwable $e) {
            log_error('[SyncSample] ' . $e->getMessage());
        }
    }
}

try {
    switch ($route) {
        case 'system/ping':
            App\Controllers\SystemController::ping();
            break;

        case 'system/servers':
            App\Controllers\SystemController::servers();
            break;

        case 'system/public-config':
            App\Controllers\SystemController::publicConfig();
            break;

        case 'sponsors/list':
            App\Controllers\SponsorController::index();
            break;

        case 'system/health':
            App\Controllers\SystemController::health();
            break;

        case 'sync/trigger':
            App\Controllers\SystemController::syncTrigger();
            break;

        case 'sync/push':
            App\Controllers\SystemController::syncPush();
            break;

        case 'sync/pull':
            App\Controllers\SystemController::syncPull();
            break;

        case 'sync/receive':
            App\Controllers\SystemController::syncReceive();
            break;

        case 'sync/status':
            App\Controllers\SystemController::syncStatus();
            break;

        case 'auth/register':
            App\Controllers\AuthController::register();
            break;

        case 'auth/login':
            App\Controllers\AuthController::login();
            break;

        case 'auth/logout':
            App\Controllers\AuthController::logout();
            break;

        case 'auth/change-password':
            App\Controllers\AuthController::changePassword();
            break;

        case 'auth/sessions':
            App\Controllers\AuthController::sessions();
            break;

        case 'auth/revoke-session':
            App\Controllers\AuthController::revokeSession();
            break;

        case 'user/me':
            App\Controllers\AuthController::me();
            break;

        case 'captcha/image':
            App\Controllers\CaptchaController::image();
            break;

        case 'user/profile':
            App\Controllers\UserController::profile();
            break;

        case 'user/follow':
            App\Controllers\UserController::follow();
            break;

        case 'user/unfollow':
            App\Controllers\UserController::unfollow();
            break;

        case 'user/threads':
            App\Controllers\UserController::threads();
            break;

        case 'user/posts':
            App\Controllers\UserController::posts();
            break;

        case 'user/favorites':
            App\Controllers\UserController::favorites();
            break;

        case 'home/feed':
            App\Controllers\HomeController::feed();
            break;

        case 'forums/list':
            App\Controllers\ForumController::list();
            break;

        case 'forums/detail':
            App\Controllers\ForumController::detail();
            break;

        case 'forums/threads':
            App\Controllers\ForumController::threads();
            break;

        case 'upload/media':
            App\Controllers\UploadController::media();
            break;

        case 'upload/delete':
            App\Controllers\AttachmentController::delete();
            break;

        case 'upload/info':
            App\Controllers\AttachmentController::info();
            break;

        case 'music/playlists/default':
            App\Controllers\MusicPlaylistController::defaultPlaylist();
            break;

        case 'music/favorites/toggle':
            App\Controllers\MusicPlaylistController::toggleFavorite();
            break;

        case 'music/detail':
            App\Controllers\MusicLibraryController::detail();
            break;

        case 'music/search':
            App\Controllers\MusicLibraryController::search();
            break;

        case 'netease/search':
            App\Controllers\NeteaseMusicController::search();
            break;

        case 'netease/play':
            App\Controllers\NeteaseMusicController::play();
            break;

        case 'netease/cover':
            App\Controllers\NeteaseMusicController::cover();
            break;

        case 'netease/lyrics':
            App\Controllers\NeteaseMusicController::lyrics();
            break;

        case 'threads/detail':
            App\Controllers\ThreadReadController::detail();
            break;

        case 'threads/detail-by-dv':
            App\Controllers\ThreadReadController::detailByDv();
            break;

        case 'threads/embed':
            App\Controllers\ThreadReadController::embed();
            break;

        case 'threads/create':
            App\Controllers\ThreadCreateController::create();
            break;

        case 'threads/like':
            App\Controllers\ThreadActionController::like();
            break;

        case 'threads/unlike':
            App\Controllers\ThreadActionController::unlike();
            break;

        case 'threads/favorite':
            App\Controllers\ThreadActionController::favorite();
            break;

        case 'threads/unfavorite':
            App\Controllers\ThreadActionController::unfavorite();
            break;

        case 'threads/share':
            App\Controllers\ThreadActionController::share();
            break;

        case 'threads/following':
            App\Controllers\ThreadReadController::following();
            break;

        case 'posts/list':
            App\Controllers\PostController::list();
            break;

        case 'posts/create':
            App\Controllers\PostController::create();
            break;

        case 'posts/delete':
            App\Controllers\PostController::delete();
            break;

        case 'posts/like':
            App\Controllers\PostController::like();
            break;

        case 'posts/unlike':
            App\Controllers\PostController::unlike();
            break;

        case 'app/version/check':
            App\Controllers\AppVersionController::check();
            break;

        case 'checkin/status':
            App\Controllers\CheckinController::status();
            break;

        case 'checkin/do':
            App\Controllers\CheckinController::doCheckin();
            break;

        case 'creator/summary':
            App\Controllers\CreatorController::summary();
            break;

        case 'creator/threads':
            App\Controllers\CreatorController::threads();
            break;

        case 'threads/recommend':
            App\Controllers\RecommendController::threads();
            break;

        case 'history/list':
            App\Controllers\HistoryController::list();
            break;

        case 'history/delete':
            App\Controllers\HistoryController::delete();
            break;

        case 'history/clear':
            App\Controllers\HistoryController::clear();
            break;

        case 'search/threads':
            App\Controllers\SearchController::threads();
            break;

        case 'search/hot':
            App\Controllers\SearchController::hot();
            break;

        case 'threads/selection':
            App\Controllers\SearchController::threadPicker();
            break;

        case 'tags/hot':
            App\Controllers\TagController::hot();
            break;

        case 'threads/update':
            App\Controllers\ThreadManageController::update();
            break;

        case 'threads/delete':
            App\Controllers\ThreadManageController::delete();
            break;

        case 'threads/report':
            App\Controllers\ThreadManageController::report();
            break;

        case 'threads/toggle-digest':
            App\Controllers\ThreadManageController::toggleDigest();
            break;

        case 'profile/get':
            App\Controllers\ProfileController::get();
            break;

        case 'profile/update':
            App\Controllers\ProfileController::update();
            break;

        case 'file/resolve':
            App\Controllers\FileController::resolve();
            break;

        case 'notifications/list':
            App\Controllers\NotificationController::list();
            break;

        case 'notifications/unread':
            App\Controllers\NotificationController::unreadCount();
            break;

        case 'notifications/read':
            App\Controllers\NotificationController::markRead();
            break;

        case 'notifications/dnd/get':
            App\Controllers\NotificationController::getDnd();
            break;

        case 'notifications/dnd/set':
            App\Controllers\NotificationController::setDnd();
            break;

        case 'messages/conversations':
            App\Controllers\MessageController::conversations();
            break;

        case 'messages/list':
            App\Controllers\MessageController::messages();
            break;

        case 'messages/send':
            App\Controllers\MessageController::send();
            break;

        case 'messages/unread':
            App\Controllers\MessageController::unreadCount();
            break;

        case 'messages/read':
            App\Controllers\MessageController::markRead();
            break;

        case 'admin/stats':
            App\Controllers\AdminController::stats();
            break;

        case 'admin/users':
            App\Controllers\AdminController::users();
            break;

        case 'admin/user/ban':
            App\Controllers\AdminController::ban();
            break;

        case 'admin/user/unban':
            App\Controllers\AdminController::unban();
            break;

        case 'admin/user/delete':
            App\Controllers\AdminController::delete();
            break;

        case 'admin/user/create':
            App\Controllers\AdminController::create();
            break;

        case 'admin/review/list':
            App\Controllers\AdminController::reviewList();
            break;

        case 'admin/review/approve':
            App\Controllers\AdminController::reviewApprove();
            break;

        case 'admin/review/reject':
            App\Controllers\AdminController::reviewReject();
            break;

        case 'admin/settings/get':
            App\Controllers\AdminController::settingsGet();
            break;

        case 'admin/settings/update':
            App\Controllers\AdminController::settingsUpdate();
            break;

        case 'admin/sponsors/create':
            App\Controllers\SponsorController::create();
            break;

        case 'admin/sponsors/update':
            App\Controllers\SponsorController::update();
            break;

        case 'admin/sponsors/delete':
            App\Controllers\SponsorController::delete();
            break;

        case 'admin/user/update':
            App\Controllers\AdminController::updateUser();
            break;

        case 'admin/groups':
            App\Controllers\AdminController::groupList();
            break;

        case 'admin/threads':
            App\Controllers\AdminController::threads();
            break;

        case 'admin/thread/delete':
            App\Controllers\AdminController::threadDelete();
            break;

        case 'admin/thread/sticky':
            App\Controllers\AdminController::threadToggleSticky();
            break;

        case 'admin/thread/lock':
            App\Controllers\AdminController::threadToggleLock();
            break;

        case 'admin/files':
            App\Controllers\AdminFileController::index();
            break;

        case 'admin/files/folder/create':
            App\Controllers\AdminFileController::createFolder();
            break;

        case 'admin/files/move':
            App\Controllers\AdminFileController::move();
            break;

        case 'admin/files/delete':
            App\Controllers\AdminFileController::delete();
            break;

        default:
            Response::json(404, '接口不存在');
    }
} catch (Throwable $e) {
    log_error($e->getMessage() . "\n" . $e->getTraceAsString());

    Response::json(500, '服务器异常');
}
