<?php

namespace App\Controllers;

class ProfileController
{
    public static function get()
    {
        $user = \Auth::requireLogin();

        $users = \Database::table('users');

        $row = \Database::fetch(
            "SELECT id, nickname, avatar, bio, gender, birthday, school, grade, location, profile_visibility_json
             FROM {$users}
             WHERE id = ?
             LIMIT 1",
            [$user['id']]
        );

        if (!$row) {
            \Response::json(404, '用户不存在');
        }

        $visibility = [];

        if (!empty($row['profile_visibility_json'])) {
            $decoded = json_decode($row['profile_visibility_json'], true);
            if (is_array($decoded)) {
                $visibility = $decoded;
            }
        }

        \Response::success([
            'id' => (int)$row['id'],
            'nickname' => $row['nickname'],
            'avatar' => $row['avatar'] ?? '',
            'bio' => $row['bio'] ?? '',
            'gender' => $row['gender'] ?? '',
            'birthday' => $row['birthday'] ?? '',
            'school' => $row['school'] ?? '',
            'grade' => $row['grade'] ?? '',
            'location' => $row['location'] ?? '',
            'visibility' => array_merge([
                'gender' => true,
                'birthday' => false,
                'school' => true,
                'grade' => true,
                'location' => true,
            ], $visibility),
        ]);
    }

    public static function update()
    {
        $user = \Auth::requireLogin();

        $avatar = trim(\Request::input('avatar', ''));
        $nickname = trim(\Request::input('nickname', ''));
        $bio = trim(\Request::input('bio', ''));
        $gender = trim(\Request::input('gender', ''));
        $birthday = trim(\Request::input('birthday', ''));
        $school = trim(\Request::input('school', ''));
        $grade = trim(\Request::input('grade', ''));
        $location = trim(\Request::input('location', ''));
        $visibility = \Request::input('visibility', []);

        if ($nickname === '') {
            \Response::json(422, '昵称不能为空');
        }

        if (mb_strlen($nickname) > 20) {
            \Response::json(422, '昵称最多 20 个字');
        }

        if (mb_strlen($bio) > 200) {
            \Response::json(422, '简介最多 200 个字');
        }

        if (!is_array($visibility)) {
            $visibility = [];
        }

        $visibility = [
            'gender' => !empty($visibility['gender']),
            'birthday' => !empty($visibility['birthday']),
            'school' => !empty($visibility['school']),
            'grade' => !empty($visibility['grade']),
            'location' => !empty($visibility['location']),
        ];

        $users = \Database::table('users');

        \Database::execute(
            "UPDATE {$users}
             SET avatar = ?,
                  nickname = ?,
                  bio = ?,
                  gender = ?,
                  birthday = ?,
                  school = ?,
                  grade = ?,
                  location = ?,
                  profile_visibility_json = ?
             WHERE id = ?",
            [
                $avatar,
                $nickname,
                $bio,
                $gender,
                $birthday !== '' ? $birthday : null,
                $school,
                $grade,
                $location,
                json_encode($visibility, JSON_UNESCAPED_UNICODE),
                $user['id'],
            ]
        );
        $updatedUser = \Database::fetch("SELECT * FROM {$users} WHERE id = ?", [$user['id']]);
        record_sync_operation('users', $user['id'], 'update', $updatedUser);

        \Response::success(null, '资料已保存');
    }
}
