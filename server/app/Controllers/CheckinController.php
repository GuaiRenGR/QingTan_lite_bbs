<?php

namespace App\Controllers;

class CheckinController
{
    public static function status()
    {
        $user = \Auth::requireLogin();

        $checkins = \Database::table('checkins');
        $users = \Database::table('users');

        $today = today();

        $todayRecord = \Database::fetch(
            "SELECT * FROM {$checkins} WHERE user_id = ? AND checkin_date = ? LIMIT 1",
            [$user['id'], $today]
        );

        $latest = \Database::fetch(
            "SELECT * FROM {$checkins} WHERE user_id = ? ORDER BY checkin_date DESC LIMIT 1",
            [$user['id']]
        );

        $userRow = \Database::fetch(
            "SELECT score FROM {$users} WHERE id = ? LIMIT 1",
            [$user['id']]
        );

        \Response::success([
            'checked_today' => $todayRecord ? true : false,
            'continuous_days' => $latest ? (int)$latest['continuous_days'] : 0,
            'points' => $userRow ? (int)$userRow['score'] : 0,
            'today_reward' => self::reward(($latest ? (int)$latest['continuous_days'] : 0) + 1),
        ]);
    }

    public static function doCheckin()
    {
        $user = \Auth::requireLogin();

        $checkins = \Database::table('checkins');
        $users = \Database::table('users');
        $scoreLogs = \Database::table('score_logs');

        $today = today();
        $yesterday = date('Y-m-d', time() - 86400);

        \Database::begin();

        try {
            $exists = \Database::fetch(
                "SELECT id FROM {$checkins} WHERE user_id = ? AND checkin_date = ? LIMIT 1",
                [$user['id'], $today]
            );

            if ($exists) {
                \Database::rollback();
                \Response::json(409, '今日已签到');
            }

            $yesterdayRecord = \Database::fetch(
                "SELECT * FROM {$checkins} WHERE user_id = ? AND checkin_date = ? LIMIT 1",
                [$user['id'], $yesterday]
            );

            $continuousDays = $yesterdayRecord ? ((int)$yesterdayRecord['continuous_days'] + 1) : 1;
            $reward = self::reward($continuousDays);
            $now = now();

            \Database::execute(
                "INSERT INTO {$checkins}
                (`user_id`,`checkin_date`,`reward_score`,`continuous_days`,`created_at`)
                VALUES (?,?,?,?,?)",
                [$user['id'], $today, $reward, $continuousDays, $now]
            );

            \Database::execute(
                "UPDATE {$users} SET score = score + ? WHERE id = ?",
                [$reward, $user['id']]
            );

            $newUser = \Database::fetch(
                "SELECT score FROM {$users} WHERE id = ?",
                [$user['id']]
            );

            \Database::execute(
                "INSERT INTO {$scoreLogs}
                (`user_id`,`action`,`amount`,`balance`,`remark`,`created_at`)
                VALUES (?,?,?,?,?,?)",
                [
                    $user['id'],
                    'checkin',
                    $reward,
                    $newUser['score'],
                    '连续签到 ' . $continuousDays . ' 天',
                    $now
                ]
            );

            \Database::commit();

            $checkinRow = \Database::fetch("SELECT * FROM {$checkins} WHERE user_id = ? AND checkin_date = ?", [$user['id'], $today]);
            record_sync_operation('checkins', $checkinRow ? (int)$checkinRow['id'] : 0, 'insert', $checkinRow);
            $updatedUser = \Database::fetch("SELECT * FROM {$users} WHERE id = ?", [$user['id']]);
            record_sync_operation('users', $user['id'], 'update', $updatedUser);

            \Response::success([
                'reward_score' => $reward,
                'continuous_days' => $continuousDays,
                'score' => (int)$newUser['score'],
            ], '签到成功');

        } catch (\Throwable $e) {
            \Database::rollback();
            log_error($e->getMessage());

            \Response::json(500, '签到失败');
        }
    }

    private static function reward($days)
    {
        if ($days >= 30) {
            return 100;
        }

        if ($days >= 7) {
            return 20;
        }

        return 5 + min($days - 1, 5);
    }
}
