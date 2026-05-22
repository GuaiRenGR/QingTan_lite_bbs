<?php

define('FX_ROOT', __DIR__);
$config = require FX_ROOT . '/config/database.php';

$dsn = sprintf(
    'mysql:host=%s;port=%s;dbname=%s;charset=%s',
    $config['host'],
    $config['port'],
    $config['database'],
    $config['charset'] ?? 'utf8mb4'
);

$pdo = new PDO($dsn, $config['username'], $config['password'], [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

$prefix = $config['prefix'];

echo '<pre>';
echo "=== 轻坛 版本更新 ===\n\n";

$updates = [
    [
        'version' => '1.1.0',
        'build_number' => 2005,
        'title' => '发现新版本 v1.1.0',
        'content' => implode("\n", [
            '【消息系统】',
            '1. 新增消息通知中心（回复我的、@我、收到的赞、系统通知）',
            '2. 新增用户私信功能，支持会话列表和实时聊天',
            '3. 通知免打扰设置，可按类型独立开关',
            '',
            '【评论互动】',
            '4. 新增评论点赞功能，每个评论下方有点赞按钮',
            '5. 新增回复评论功能，点击回复自动填充"回复@XXX："',
            '6. 回复评论时被回复者和帖子作者均收到通知',
            '',
            '【系统通知】',
            '7. 支持 Android 原生系统通知，应用外也能收到提醒',
            '8. 60秒轮询检测新通知，前后台自动管理',
            '9. 设置页可开关原生系统通知',
            '',
            '【管理功能】',
            '10. 管理员可编辑/删除任意帖子（不改变原作者）',
            '11. 管理员可设置/取消精华帖',
            '',
            '【图片体验】',
            '12. 图片模式改为小红书样式，图片紧挨顶栏，文字在下方',
            '13. 新增图片查看大图功能，支持双指缩放和左右滑动切换',
            '14. 推荐页图片恢复原始裁剪逻辑，极高图显示上半部分',
            '',
            '【其他优化】',
            '15. 个人主页添加私信按钮',
            '16. 我的页面添加消息入口',
            '17. 帖子详情页评论区 UI 优化',
        ]),
        'force_update' => 0,
    ],
];

foreach ($updates as $item) {
    try {
        $stmt = $pdo->prepare(
            "SELECT id FROM `{$prefix}app_versions`
             WHERE platform = 'all' AND version = ? AND build_number = ?
             LIMIT 1"
        );
        $stmt->execute([$item['version'], $item['build_number']]);
        $exists = $stmt->fetch();

        if ($exists) {
            $stmt = $pdo->prepare(
                "UPDATE `{$prefix}app_versions`
                 SET title = ?, content = ?, force_update = ?, status = 1, created_at = ?
                 WHERE id = ?"
            );
            $stmt->execute([
                $item['title'],
                $item['content'],
                $item['force_update'],
                date('Y-m-d H:i:s'),
                $exists['id'],
            ]);
            echo "[更新] 版本 {$item['version']} (build {$item['build_number']}) 已更新\n";
        } else {
            $stmt = $pdo->prepare(
                "INSERT INTO `{$prefix}app_versions`
                 (`platform`, `version`, `build_number`, `title`, `content`, `download_url`, `force_update`, `status`, `created_at`)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            );
            $stmt->execute([
                'all',
                $item['version'],
                $item['build_number'],
                $item['title'],
                $item['content'],
                '',
                $item['force_update'],
                1,
                date('Y-m-d H:i:s'),
            ]);
            echo "[新增] 版本 {$item['version']} (build {$item['build_number']})\n";
        }
    } catch (Throwable $e) {
        echo "[失败] {$item['version']}: " . $e->getMessage() . "\n";
    }
}

echo "\n更新完成。建议删除此文件。";
echo '</pre>';
