import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _accessTokenKey);
    } catch (_) {}
  }
}
