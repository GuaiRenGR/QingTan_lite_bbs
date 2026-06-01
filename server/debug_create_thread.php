<?php
/**
 * 调试脚本：测试帖子创建流程的每个环节
 *
 * 用法：POST /debug_create_thread.php
 * Body (JSON): { "username": "你的用户名", "password": "密码", "title": "测试标题", "content": "测试内容" }
 *
 * 也可以用 Token：
 * Header: Authorization: Bearer <token>
 * Body (JSON): { "title": "测试标题", "content": "测试内容" }
 */

header('Content-Type: application/json; charset=utf-8');

define('FX_ROOT', __DIR__);

require_once FX_ROOT . '/core/Database.php';
require_once FX_ROOT . '/core/Response.php';
require_once FX_ROOT . '/core/Request.php';
require_once FX_ROOT . '/core/Auth.php';
require_once FX_ROOT . '/core/helpers.php';
require_once FX_ROOT . '/core/DvCode.php';
require_once FX_ROOT . '/core/SiteSetting.php';
require_once FX_ROOT . '/config/database.php';

$steps = [];

function step($name, $ok, $detail = '') {
    global $steps;
    $steps[] = ['step' => $name, 'ok' => $ok, 'detail' => $detail];
}

try {
    // Step 1: 数据库连接
    try {
        \Database::fetch("SELECT 1");
        step('数据库连接', true);
    } catch (\Throwable $e) {
        step('数据库连接', false, $e->getMessage());
        throw $e;
    }

    // Step 2: 读取输入
    $rawInput = file_get_contents('php://input');
    $json = json_decode($rawInput, true);

    step('原始输入', is_string($rawInput), '长度: ' . strlen($rawInput) . ', 内容: ' . substr($rawInput, 0, 200));
    step('JSON解析', is_array($json), $json ? '字段: ' . implode(', ', array_keys($json)) : 'json_decode失败: ' . json_last_error_msg());

    if (!is_array($json)) $json = [];

    $username = trim($json['username'] ?? '');
    $password = $json['password'] ?? '';

    // Step 3: 认证 — 支持 Token 或 用户名密码
    $user = null;

    // 方式一：Token
    $token = \Request::bearerToken();
    if ($token) {
        $user = \Auth::user();
        step('Token认证', $user !== null, $user ? '用户ID: ' . $user['id'] . ', 用户名: ' . $user['username'] : 'Token无效或已过期');
    }

    // 方式二：用户名密码
    if (!$user && $username !== '' && $password !== '') {
        $users = \Database::table('users');
        $row = \Database::fetch(
            "SELECT * FROM {$users} WHERE username = ? AND status = 1 LIMIT 1",
            [$username]
        );

        if (!$row) {
            step('密码认证', false, '用户不存在或已禁用');
        } else {
            step('用户查询', true, '字段: ' . implode(', ', array_keys($row)));

            $hash = $row['password'] ?? $row['passwd'] ?? $row['pass_hash'] ?? $row['password_hash'] ?? '';
            if ($hash === '') {
                step('密码认证', false, '找不到密码字段，可用字段: ' . implode(', ', array_keys($row)));
            } elseif (password_verify($password, $hash)) {
                $user = $row;
                step('密码认证', true, '用户ID: ' . $user['id'] . ', 用户名: ' . $user['username']);
            } else {
                step('密码认证', false, '密码不匹配');
            }
        }
    }

    if (!$user) {
        step('认证失败', false, '请提供 Token 或 username+password');
        echo json_encode(['steps' => $steps], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    // Step 4: 读取帖子字段
    $title = trim($json['title'] ?? '测试标题');
    $content = trim($json['content'] ?? '测试内容');
    $forumId = intval($json['forum_id'] ?? 0);
    $mode = trim($json['mode'] ?? 'article');

    step('读取字段', true, "title=\"{$title}\", content长度=" . strlen($content) . ", forum_id={$forumId}, mode={$mode}");

    // Step 5: 验证
    if (mb_strlen($title) < 2 || mb_strlen($title) > 80) {
        step('标题验证', false, "标题长度: " . mb_strlen($title) . " (需要2-80)");
    } else {
        step('标题验证', true);
    }

    // Step 6: 内容清理
    $sanitized = '';
    try {
        $sanitized = sanitize_forum_content($content);
        step('内容清理', true, "清理后长度: " . strlen($sanitized));
    } catch (\Throwable $e) {
        step('内容清理', false, $e->getMessage());
    }

    // Step 7: 板块检查
    if ($forumId <= 0) {
        try {
            $forumId = \ForumController::defaultId();
            step('默认板块', true, "forum_id={$forumId}");
        } catch (\Throwable $e) {
            step('默认板块', false, $e->getMessage());
        }
    } else {
        $exists = \Database::fetch("SELECT id FROM " . \Database::table('forums') . " WHERE id = ?", [$forumId]);
        step('板块存在', $exists !== false, $exists ? "板块ID: {$exists['id']}" : "板块 {$forumId} 不存在");
    }

    // Step 8: 审核状态
    $visibility = 'public';
    try {
        $needsReview = \SiteSetting::isReviewRequired();
        $isReviewer = \SiteSetting::isReviewer($user);
        step('审核检查', true, "需要审核: " . ($needsReview ? '是' : '否') . ", 审核员: " . ($isReviewer ? '是' : '否'));

        if ($needsReview && !$isReviewer) {
            $visibility = 'pending';
        }
    } catch (\Throwable $e) {
        step('审核检查', false, $e->getMessage());
    }

    // Step 9: DV码测试
    try {
        $testDv = \DvCode::encode(99999);
        step('DV码生成', true, "测试编码: {$testDv}");
    } catch (\Throwable $e) {
        step('DV码生成', false, $e->getMessage());
    }

    // Step 10: 实际插入测试（回滚）
    $threadId = 0;
    try {
        $threads = \Database::table('threads');
        $now = date('Y-m-d H:i:s');

        \Database::begin();

        \Database::execute(
            "INSERT INTO {$threads}
            (`forum_id`, `user_id`, `title`, `content`, `summary`, `cover`,
             `mode`, `images_json`, `music_url`, `music_name`,
             `view_count`, `reply_count`, `like_count`, `favorite_count`, `share_count`,
             `is_top`, `is_digest`, `status`, `visibility`, `created_at`, `updated_at`)
            VALUES
            (?, ?, ?, ?, '', '', ?, '[]', '', '', 0, 0, 0, 0, 0, 0, 0, 1, ?, ?, ?)",
            [
                $forumId,
                $user['id'],
                $title,
                $sanitized,
                $mode,
                $visibility,
                $now,
                $now,
            ]
        );

        $threadId = (int)\Database::lastInsertId();
        step('插入帖子', true, "thread_id={$threadId}");

        // DV码
        $dvCode = \DvCode::encode($threadId);
        \Database::execute(
            "UPDATE {$threads} SET dv_code = ? WHERE id = ?",
            [$dvCode, $threadId]
        );
        step('设置DV码', true, "dv_code={$dvCode}");

        \Database::rollback();
        step('回滚', true, '已回滚，帖子未真正创建');

    } catch (\Throwable $e) {
        \Database::rollback();
        step('插入帖子', false, $e->getMessage());
    }

    echo json_encode([
        'steps' => $steps,
        'result' => '调试完成',
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

} catch (\Throwable $e) {
    echo json_encode([
        'steps' => $steps,
        'error' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}
