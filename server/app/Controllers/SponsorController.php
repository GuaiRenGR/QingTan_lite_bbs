<?php

namespace App\Controllers;

class SponsorController
{
    public static function index()
    {
        $table = \Database::table('sponsors');
        $rows = \Database::fetchAll(
            "SELECT id, name, amount, message, created_at
             FROM {$table}
             ORDER BY created_at DESC, id DESC"
        );

        foreach ($rows as &$row) {
            $row['id'] = (int)$row['id'];
            $row['amount'] = number_format((float)$row['amount'], 2, '.', '');
        }
        unset($row);

        \Response::success(['list' => $rows]);
    }

    public static function create()
    {
        self::requireAdmin();
        [$name, $amount, $message] = self::validatedInput();
        $table = \Database::table('sponsors');
        $now = now();

        \Database::execute(
            "INSERT INTO {$table} (`name`, `amount`, `message`, `created_at`, `updated_at`)
             VALUES (?, ?, ?, ?, ?)",
            [$name, $amount, $message, $now, $now]
        );
        $id = (int)\Database::lastInsertId();
        $row = \Database::fetch("SELECT * FROM {$table} WHERE id = ?", [$id]);
        record_sync_operation('sponsors', $id, 'insert', $row);

        \Response::success($row, '赞助记录已添加');
    }

    public static function update()
    {
        self::requireAdmin();
        $id = \Request::int('id');
        [$name, $amount, $message] = self::validatedInput();
        $table = \Database::table('sponsors');
        $old = \Database::fetch("SELECT * FROM {$table} WHERE id = ?", [$id]);
        if (!$old) {
            \Response::json(404, '赞助记录不存在');
        }

        \Database::execute(
            "UPDATE {$table} SET `name` = ?, `amount` = ?, `message` = ?, `updated_at` = ? WHERE id = ?",
            [$name, $amount, $message, now(), $id]
        );
        $row = \Database::fetch("SELECT * FROM {$table} WHERE id = ?", [$id]);
        record_sync_operation('sponsors', $id, 'update', $row, $old);

        \Response::success($row, '赞助记录已更新');
    }

    public static function delete()
    {
        self::requireAdmin();
        $id = \Request::int('id');
        $table = \Database::table('sponsors');
        $old = \Database::fetch("SELECT * FROM {$table} WHERE id = ?", [$id]);
        if (!$old) {
            \Response::json(404, '赞助记录不存在');
        }

        \Database::execute("DELETE FROM {$table} WHERE id = ?", [$id]);
        record_sync_operation('sponsors', $id, 'delete', null, $old);
        \Response::success(null, '赞助记录已删除');
    }

    private static function requireAdmin()
    {
        $user = \Auth::requireLogin();
        if (!\SiteSetting::isAdmin($user)) {
            \Response::json(403, '无管理员权限');
        }
    }

    private static function validatedInput()
    {
        $name = \Request::str('name');
        $message = \Request::str('message');
        $amount = round((float)\Request::input('amount', 0), 2);

        if ($name === '' || mb_strlen($name) > 100) {
            \Response::json(422, '留名不能为空且不能超过 100 个字符');
        }
        if ($amount <= 0 || $amount > 99999999.99) {
            \Response::json(422, '请输入有效的赞助金额');
        }
        if (mb_strlen($message) > 500) {
            \Response::json(422, '留言不能超过 500 个字符');
        }

        return [$name, number_format($amount, 2, '.', ''), $message];
    }
}
