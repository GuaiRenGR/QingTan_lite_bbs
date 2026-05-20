<?php

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/Response.php';
require_once FX_ROOT . '/core/Request.php';
require_once FX_ROOT . '/core/Database.php';
require_once FX_ROOT . '/core/Auth.php';
require_once FX_ROOT . '/core/OneDriveService.php';

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

try {
    switch ($route) {
        case 'auth/register':
            App\Controllers\AuthController::register();
            break;

        case 'auth/login':
            App\Controllers\AuthController::login();
            break;

        case 'auth/logout':
            App\Controllers\AuthController::logout();
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

        case 'threads/detail':
            App\Controllers\ThreadReadController::detail();
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

        case 'profile/get':
            App\Controllers\ProfileController::get();
            break;

        case 'profile/update':
            App\Controllers\ProfileController::update();
            break;

        default:
            Response::json(404, '接口不存在');
    }
} catch (Throwable $e) {
    log_error($e->getMessage() . "\n" . $e->getTraceAsString());

    Response::json(500, '服务器异常');
}
