import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/services/api_cache_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/app_logger.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController()..init();
});

class AuthState {
  final bool loading;
  final bool loggedIn;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({
    this.loading = false,
    this.loggedIn = false,
    this.user,
    this.error,
  });

  bool get isGuest => !loggedIn;

  AuthState copyWith({
    bool? loading,
    bool? loggedIn,
    Map<String, dynamic>? user,
    String? error,
  }) {
    return AuthState(
      loading: loading ?? this.loading,
      loggedIn: loggedIn ?? this.loggedIn,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState());

  static const _cachedUserKey = 'auth_cached_user_v1';

  Future<Map<String, dynamic>?> _readCachedUser() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cachedUserKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheUser(Map<String, dynamic>? user) async {
    if (user == null || user.isEmpty) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_cachedUserKey, jsonEncode(user));
    } catch (_) {}
  }

  Future<void> _clearCachedUser() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_cachedUserKey);
    } catch (_) {}
  }

  Future<void> init() async {
    state = state.copyWith(loading: true);

    final token = await TokenStorage.instance.getToken();
    await AppLogger.log('Auth', 'init: token=${token != null && token.isNotEmpty ? 'exists' : 'empty'}');

    if (token == null || token.isEmpty) {
      state = const AuthState(
        loading: false,
        loggedIn: false,
        user: null,
      );
      return;
    }

    final cachedUser = await _readCachedUser();
    state = AuthState(
      loading: true,
      loggedIn: true,
      user: cachedUser,
    );

    final result = await ApiClient.instance.get('user/me');
    await AppLogger.log('Auth', 'init: user/me success=${result.success} dataType=${result.data?.runtimeType} message=${result.message}');

    if (result.success && result.data is Map<String, dynamic>) {
      final userMap = result.data as Map<String, dynamic>;
      await AppLogger.log('Auth', 'init: loggedIn=true userId=${userMap['id']} nickname=${userMap['nickname']}');
      await _cacheUser(userMap);
      state = AuthState(
        loading: false,
        loggedIn: true,
        user: userMap,
      );
    } else if (result.code == 401 || result.code == 403) {
      await AppLogger.log('Auth', 'init: token rejected, clearing local session');
      await TokenStorage.instance.clearToken();
      await ApiCacheService.instance.clear();
      await _clearCachedUser();
      state = AuthState(
        loading: false,
        loggedIn: false,
        user: null,
        error: result.message,
      );
    } else {
      await AppLogger.log('Auth', 'init: offline, keeping token and cached user');
      state = AuthState(
        loading: false,
        loggedIn: true,
        user: cachedUser,
        error: result.message,
      );
    }
  }

  Future<bool> login({
    required String account,
    required String password,
  }) async {
    state = state.copyWith(loading: true, error: null);
    await AppLogger.log('Auth', 'login start: account=$account');

    final result = await ApiClient.instance.post(
      'auth/login',
      data: {
        'account': account,
        'password': password,
      },
    );

    await AppLogger.log('Auth', 'login result: success=${result.success} dataType=${result.data?.runtimeType} message=${result.message}');

    if (!result.success || result.data is! Map<String, dynamic>) {
      state = state.copyWith(
        loading: false,
        loggedIn: false,
        error: result.message,
      );
      return false;
    }

    final data = result.data as Map<String, dynamic>;
    final token = data['access_token']?.toString();
    final userData = data['user'];

    await AppLogger.log('Auth', 'login: token=${token != null ? 'exists' : 'null'} userType=${userData?.runtimeType}');

    if (token == null || token.isEmpty) {
      state = state.copyWith(
        loading: false,
        loggedIn: false,
        error: '登录返回数据异常',
      );
      return false;
    }

    await ApiCacheService.instance.clear();
    await TokenStorage.instance.saveToken(token);

    final normalizedUser = userData is Map
        ? Map<String, dynamic>.from(userData)
        : null;
    await _cacheUser(normalizedUser);

    state = AuthState(
      loading: false,
      loggedIn: true,
      user: normalizedUser,
    );

    await AppLogger.log('Auth', 'login success: userId=${normalizedUser?['id']}');
    return true;
  }

  Future<bool> register({
    required String username,
    required String password,
    required String passwordConfirm,
    required String captchaId,
    required String captcha,
    String? nickname,
  }) async {
    state = state.copyWith(loading: true, error: null);

    final result = await ApiClient.instance.post(
      'auth/register',
      data: {
        'username': username,
        'nickname': (nickname != null && nickname.isNotEmpty) ? nickname : username,
        'password': password,
        'password_confirm': passwordConfirm,
        'captcha_id': captchaId,
        'captcha': captcha,
      },
    );

    if (!result.success || result.data is! Map<String, dynamic>) {
      state = state.copyWith(
        loading: false,
        loggedIn: false,
        error: result.message,
      );
      return false;
    }

    final data = result.data as Map<String, dynamic>;
    final token = data['access_token']?.toString();

    if (token == null || token.isEmpty) {
      state = state.copyWith(
        loading: false,
        loggedIn: false,
        error: '注册返回数据异常',
      );
      return false;
    }

    await ApiCacheService.instance.clear();
    await TokenStorage.instance.saveToken(token);

    final normalizedUser = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : null;
    await _cacheUser(normalizedUser);

    state = AuthState(
      loading: false,
      loggedIn: true,
      user: normalizedUser,
    );

    return true;
  }

  Future<void> logout() async {
    await ApiClient.instance.post('auth/logout');
    await TokenStorage.instance.clearToken();
    await ApiCacheService.instance.clear();
    await _clearCachedUser();

    state = const AuthState(
      loading: false,
      loggedIn: false,
      user: null,
    );
  }
}
