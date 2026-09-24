import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalChatConversation {
  final String key;
  final String title;
  final int messageCount;

  const LocalChatConversation({
    required this.key,
    required this.title,
    required this.messageCount,
  });
}

/// Private on-device database for chat history. It is deliberately kept out
/// of cache/download directories and is not affected by cache cleanup.
class LocalChatDatabase {
  LocalChatDatabase._();

  static final instance = LocalChatDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final support = await getApplicationSupportDirectory();
    _database = await openDatabase(
      path.join(support.path, 'qingtan_private_messages.sqlite'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chat_messages (
            conversation_key TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            message_id INTEGER NOT NULL,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (conversation_key, message_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_chat_messages_time ON chat_messages(conversation_key, created_at)',
        );
      },
    );
    // Remove the old SharedPreferences-based group cache introduced by an
    // earlier build. Chat history now belongs exclusively in this database.
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((key) => key.startsWith('group_messages_'))) {
        await prefs.remove(key);
      }
    } catch (_) {}
    return _database!;
  }

  Future<List<Map<String, dynamic>>> loadMessages(String key) async {
    try {
      final db = await database;
      final rows = await db.query(
      'chat_messages',
      where: 'conversation_key = ?',
      whereArgs: [key],
      orderBy: 'created_at DESC',
      limit: 500,
    );
      return rows
        .map((row) {
          try {
            final value = jsonDecode(row['payload'] as String);
            return value is Map ? Map<String, dynamic>.from(value) : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveMessages(
    String key,
    String title,
    Iterable<Map<String, dynamic>> messages,
  ) async {
    try {
      final db = await database;
      final batch = db.batch();
    for (final message in messages.take(500)) {
      final id = int.tryParse(message['id']?.toString() ?? '') ?? 0;
      if (id <= 0) continue;
      final created = DateTime.tryParse(message['created_at']?.toString() ?? '')
              ?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;
      batch.insert(
        'chat_messages',
        {
          'conversation_key': key,
          'title': title,
          'message_id': id,
          'payload': jsonEncode(message),
          'created_at': created,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<List<LocalChatConversation>> conversations() async {
    try {
      final db = await database;
      final rows = await db.rawQuery('''
      SELECT conversation_key, MAX(title) AS title, COUNT(*) AS message_count
      FROM chat_messages
      GROUP BY conversation_key
      ORDER BY MAX(created_at) DESC
    ''');
      return rows
        .map(
          (row) => LocalChatConversation(
            key: row['conversation_key']?.toString() ?? '',
            title: row['title']?.toString() ?? '',
            messageCount: int.tryParse(row['message_count']?.toString() ?? '') ?? 0,
          ),
        )
        .where((item) => item.key.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> deleteConversation(String key) async {
    try {
      final db = await database;
      await db.delete('chat_messages', where: 'conversation_key = ?', whereArgs: [key]);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      final db = await database;
      await db.delete('chat_messages');
    } catch (_) {}
  }
}
