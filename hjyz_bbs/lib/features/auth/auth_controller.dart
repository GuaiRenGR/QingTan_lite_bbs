import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';

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

  Future<void> init() async {
    state = state.copyWith(loading: true);

    final token = await TokenStorage.instance.getToken();

    if (token == null || token.isEmpty) {
      state = const AuthState(
        loading: false,
        loggedIn: false,
        user: null,
      );
      return;
    }

    final result = await ApiClient.instance.get('user/me');

    if (result.success && result.data is Map<String, dynamic>) {
      state = AuthState(
        loading: false,
        loggedIn: true,
        user: result.data as Map<String, dynamic>,
      );
    } else {
      await TokenStorage.instance.clearToken();
      state = AuthState(
        loading: false,
        loggedIn: false,
        user: null,
        error: result.message,
      );
    }
  }

  Future<bool> login({
    required String account,
    required String password,
  }) async {
    state = state.copyWith(loading: true, error: null);

    final result = await ApiClient.instance.post(
      'auth/login',
      data: {
        'account': account,
        'password': password,
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
        error: '登录返回数据异常',
      );
      return false;
    }

    await TokenStorage.instance.saveToken(token);

    state = AuthState(
      loading: false,
      loggedIn: true,
      user: data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : null,
    );

    return true;
  }

  Future<bool> register({
    required String username,
    required String password,
    required String passwordConfirm,
    required String captchaId,
    required String captcha,
  }) async {
    state = state.copyWith(loading: true, error: null);

    final result = await ApiClient.instance.post(
      'auth/register',
      data: {
        'username': username,
        'nickname': username,
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

    await TokenStorage.instance.saveToken(token);

    state = AuthState(
      loading: false,
      loggedIn: true,
      user: data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : null,
    );

    return true;
  }

  Future<void> logout() async {
    await ApiClient.instance.post('auth/logout');
    await TokenStorage.instance.clearToken();

    state = const AuthState(
      loading: false,
      loggedIn: false,
      user: null,
    );
  }
}
