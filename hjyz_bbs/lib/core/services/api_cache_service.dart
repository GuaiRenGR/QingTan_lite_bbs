import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ApiCacheService {
  ApiCacheService._();

  static final ApiCacheService instance = ApiCacheService._();

  static const _prefix = 'offline_api_cache_v1_';
  static const _indexKey = 'offline_api_cache_index_v1';
  static const _maxEntries = 60;
  static const _maxAge = Duration(days: 30);

  String _key(String route, Map<String, dynamic>? query) {
    final sorted = <String, dynamic>{};
    final keys = (query?.keys.toList() ?? <String>[])..sort();
    for (final key in keys) {
      sorted[key] = query![key];
    }
    final source = jsonEncode({'route': route, 'query': sorted});
    return '$_prefix${base64Url.encode(utf8.encode(source))}';
  }

  Future<void> write(
    String route,
    Map<String, dynamic>? query,
    dynamic data,
  ) async {
    try {
      final encoded = jsonEncode({
        'saved_at': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      });
      final preferences = await SharedPreferences.getInstance();
      final key = _key(route, query);
      await preferences.setString(key, encoded);

      final index = preferences.getStringList(_indexKey) ?? <String>[];
      index
        ..remove(key)
        ..insert(0, key);
      while (index.length > _maxEntries) {
        final removed = index.removeLast();
        await preferences.remove(removed);
      }
      await preferences.setStringList(_indexKey, index);
    } catch (_) {}
  }

  Future<dynamic> read(
    String route,
    Map<String, dynamic>? query,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key(route, query));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = int.tryParse(decoded['saved_at']?.toString() ?? '') ?? 0;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(savedAt),
      );
      if (savedAt <= 0 || age > _maxAge) return null;
      return decoded['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final index = preferences.getStringList(_indexKey) ?? <String>[];
      for (final key in index) {
        await preferences.remove(key);
      }
      await preferences.remove(_indexKey);
    } catch (_) {}
  }
}
