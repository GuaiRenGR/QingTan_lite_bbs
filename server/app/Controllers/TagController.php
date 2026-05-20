<?php

namespace App\Controllers;

class TagController
{
    public static function hot()
    {
        $tags = \Database::table('tags');

        $rows = \Database::fetchAll(
            "SELECT id, name, use_count
             FROM {$tags}
             ORDER BY use_count DESC, id DESC
             LIMIT 20"
        );

        $list = array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'name' => $row['name'],
                'use_count' => (int)$row['use_count'],
            ];
        }, $rows);

        \Response::success([
            'list' => $list,
        ]);
    }
}
