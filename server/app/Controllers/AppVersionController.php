<?php

namespace App\Controllers;

class AppVersionController
{
    public static function check()
    {
        $platform = \Request::input('platform', 'all');
        $currentVersion = \Request::input('version', '0.0.0');
        $currentBuild = \Request::int('build_number', 1);

        $table = \Database::table('app_versions');

        $row = \Database::fetch(
            "SELECT *
             FROM {$table}
             WHERE status = 1
               AND (`platform` = ? OR `platform` = 'all')
             ORDER BY build_number DESC, id DESC
             LIMIT 1",
            [$platform]
        );

        if (!$row) {
            \Response::success([
                'has_update' => false,
            ]);
        }

        $latestBuild = (int)$row['build_number'];

        $hasUpdate = $latestBuild > $currentBuild;

        \Response::success([
            'has_update' => $hasUpdate,
            'force_update' => (int)$row['force_update'] === 1,
            'version' => $row['version'],
            'build_number' => $latestBuild,
            'title' => $row['title'] ?: '发现新版本',
            'content' => $row['content'] ?: '',
            'download_url' => $row['download_url'] ?: '',
        ]);
    }
}
