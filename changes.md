## 🤖 Assistant

下面重新生成一套**优先客户端 Flutter 核心代码**，适配你新的「原生 PHP 虚拟主机版」API 方案。

重点满足：

- 不登录也能浏览首页、发现、帖子列表；
- 网络失败、接口异常、JSON 异常时**不崩溃**；
- 首页风格类似 B 站：
  - 顶栏左侧头像；
  - 中间搜索栏；
  - 右侧私信按钮；
  - 频道 Tab；
  - 双列瀑布流，类似小红书；
- 底部导航栏 5 个按钮：
  - 首页
  - 动态
  - 加号
  - 发现
  - 我的
- API 兼容虚拟主机：

```text
https://your-domain.com/index.php?route=home/feed
https://your-domain.com/index.php?route=auth/login
```

---

# 一、Flutter 项目依赖

## pubspec.yaml

```yaml
name: forumx_lite_app
description: ForumX Lite Flutter Client

publish_to: "none"

version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

  dio: ^5.7.0
  flutter_riverpod: ^2.6.1
  go_router: ^14.6.0
  flutter_secure_storage: ^9.2.2
  cached_network_image: ^3.4.1
  flutter_staggered_grid_view: ^0.7.0
  shared_preferences: ^2.3.3

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
```

---

# 二、推荐目录结构

```text
lib
├── main.dart
├── app.dart
├── router.dart
├── core
│   ├── api
│   │   ├── api_client.dart
│   │   ├── api_exception.dart
│   │   └── api_result.dart
│   ├── config
│   │   └── app_config.dart
│   ├── storage
│   │   └── token_storage.dart
│   └── widgets
│       ├── error_view.dart
│       ├── loading_view.dart
│       └── safe_network_image.dart
├── features
│   ├── auth
│   │   ├── auth_controller.dart
│   │   └── login_page.dart
│   ├── main
│   │   └── main_shell_page.dart
│   ├── home
│   │   ├── home_page.dart
│   │   ├── home_feed_controller.dart
│   │   ├── home_repository.dart
│   │   └── widgets
│   │       ├── home_top_bar.dart
│   │       ├── home_channel_tabs.dart
│   │       └── thread_waterfall_card.dart
│   ├── thread
│   │   ├── thread_model.dart
│   │   └── thread_detail_page.dart
│   ├── discover
│   │   └── discover_page.dart
│   ├── dynamic
│   │   └── dynamic_page.dart
│   ├── post
│   │   └── create_post_page.dart
│   └── me
│       └── me_page.dart
```

---

# 三、核心配置

## lib/core/config/app_config.dart

```dart
class AppConfig {
  AppConfig._();

  /// 虚拟主机原生 PHP API 地址
  ///
  /// 例如：
  /// https://example.com/index.php
  ///
  /// 请求时会拼接：
  /// ?route=home/feed
  static const String apiEntry = 'https://your-domain.com/index.php';

  static const String defaultAvatar =
      'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';

  static const int pageSize = 20;
}
```

---

# 四、Token 本地存储

## lib/core/storage/token_storage.dart

```dart
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
```

---

# 五、接口错误与安全响应封装

## lib/core/api/api_exception.dart

```dart
class ApiException implements Exception {
  final String message;
  final int? code;
  final int? statusCode;

  ApiException({
    required this.message,
    this.code,
    this.statusCode,
  });

  @override
  String toString() {
    return 'ApiException(code: $code, statusCode: $statusCode, message: $message)';
  }
}
```

---

## lib/core/api/api_result.dart

```dart
class ApiResult<T> {
  final bool success;
  final T? data;
  final String message;
  final int? code;

  const ApiResult._({
    required this.success,
    this.data,
    required this.message,
    this.code,
  });

  factory ApiResult.ok(T data, {String message = 'success'}) {
    return ApiResult._(
      success: true,
      data: data,
      message: message,
      code: 0,
    );
  }

  factory ApiResult.fail(String message, {int? code}) {
    return ApiResult._(
      success: false,
      data: null,
      message: message,
      code: code,
    );
  }
}
```

---

# 六、安全 API Client

重点：

- 所有请求捕获异常；
- 网络失败不抛到 UI 导致崩溃；
- 兼容 `index.php?route=xxx`；
- 自动携带 Token；
- API 返回格式异常时也安全处理。

## lib/core/api/api_client.dart

```dart
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_result.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiEntry,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      headers: {
        'Accept': 'application/json',
        'X-Client': 'flutter',
      },
      validateStatus: (status) {
        return status != null && status < 600;
      },
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.instance.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );

  Future<ApiResult<dynamic>> get(
    String route, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          'route': route,
          ...?query,
        },
      );

      return _handleResponse(response);
    } on DioException catch (e) {
      return ApiResult.fail(_dioErrorMessage(e));
    } catch (_) {
      return ApiResult.fail('请求失败，请稍后重试');
    }
  }

  Future<ApiResult<dynamic>> post(
    String route, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    FormData? formData,
  }) async {
    try {
      final response = await _dio.post(
        '',
        queryParameters: {
          'route': route,
          ...?query,
        },
        data: formData ?? data,
      );

      return _handleResponse(response);
    } on DioException catch (e) {
      return ApiResult.fail(_dioErrorMessage(e));
    } catch (_) {
      return ApiResult.fail('请求失败，请稍后重试');
    }
  }

  ApiResult<dynamic> _handleResponse(Response response) {
    try {
      final statusCode = response.statusCode ?? 0;

      if (statusCode >= 500) {
        return ApiResult.fail('服务器开小差了，请稍后再试', code: statusCode);
      }

      if (statusCode == 404) {
        return ApiResult.fail('接口不存在', code: 404);
      }

      dynamic body = response.data;

      if (body is String) {
        try {
          body = jsonDecode(body);
        } catch (_) {
          return ApiResult.fail('服务器返回格式异常');
        }
      }

      if (body is! Map<String, dynamic>) {
        return ApiResult.fail('服务器返回数据异常');
      }

      final int code = _safeInt(body['code'], defaultValue: -1);
      final String message = body['message']?.toString() ?? '';

      if (code != 0) {
        return ApiResult.fail(
          message.isNotEmpty ? message : '请求失败',
          code: code,
        );
      }

      return ApiResult.ok(
        body['data'],
        message: message.isNotEmpty ? message : 'success',
      );
    } catch (_) {
      return ApiResult.fail('数据解析失败');
    }
  }

  int _safeInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  String _dioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时，请稍后重试';
      case DioExceptionType.receiveTimeout:
        return '服务器响应超时';
      case DioExceptionType.badCertificate:
        return '证书异常，无法安全连接';
      case DioExceptionType.connectionError:
        return '网络连接失败';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badResponse:
        return '服务器响应异常';
      case DioExceptionType.unknown:
        return '网络异常，请稍后重试';
    }
  }
}
```

---

# 七、通用安全图片组件

防止图片链接失效导致页面报错。

## lib/core/widgets/safe_network_image.dart

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = url ?? '';

    final child = imageUrl.isEmpty
        ? _buildError()
        : CachedNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, __) =>
                placeholder ??
                Container(
                  width: width,
                  height: height,
                  color: Colors.grey.shade200,
                ),
            errorWidget: (_, __, ___) => _buildError(),
          );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }

    return child;
  }

  Widget _buildError() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade500,
          ),
        );
  }
}
```

---

# 八、通用错误组件

## lib/core/widgets/error_view.dart

```dart
import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## lib/core/widgets/loading_view.dart

```dart
import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  final String text;

  const LoadingView({
    super.key,
    this.text = '加载中...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

# 九、帖子模型

兼容后端字段缺失、类型错误，不让 UI 崩溃。

## lib/features/thread/thread_model.dart

```dart
class ThreadModel {
  final int id;
  final int forumId;
  final int userId;
  final String title;
  final String summary;
  final String content;
  final String cover;
  final int viewCount;
  final int replyCount;
  final int likeCount;
  final int favoriteCount;
  final bool isTop;
  final bool isDigest;
  final String createdAt;

  final String authorName;
  final String authorAvatar;
  final String forumName;

  ThreadModel({
    required this.id,
    required this.forumId,
    required this.userId,
    required this.title,
    required this.summary,
    required this.content,
    required this.cover,
    required this.viewCount,
    required this.replyCount,
    required this.likeCount,
    required this.favoriteCount,
    required this.isTop,
    required this.isDigest,
    required this.createdAt,
    required this.authorName,
    required this.authorAvatar,
    required this.forumName,
  });

  factory ThreadModel.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return ThreadModel.empty();
    }

    final user = json['user'];
    final forum = json['forum'];

    return ThreadModel(
      id: _toInt(json['id']),
      forumId: _toInt(json['forum_id']),
      userId: _toInt(json['user_id']),
      title: _toString(json['title'], fallback: '无标题'),
      summary: _toString(json['summary']),
      content: _toString(json['content']),
      cover: _toString(json['cover']),
      viewCount: _toInt(json['view_count']),
      replyCount: _toInt(json['reply_count']),
      likeCount: _toInt(json['like_count']),
      favoriteCount: _toInt(json['favorite_count']),
      isTop: _toBool(json['is_top']),
      isDigest: _toBool(json['is_digest']),
      createdAt: _toString(json['created_at']),
      authorName: user is Map
          ? _toString(user['nickname'], fallback: '匿名用户')
          : _toString(json['nickname'], fallback: '匿名用户'),
      authorAvatar: user is Map
          ? _toString(user['avatar'])
          : _toString(json['avatar']),
      forumName: forum is Map
          ? _toString(forum['name'], fallback: '社区')
          : _toString(json['forum_name'], fallback: '社区'),
    );
  }

  factory ThreadModel.empty() {
    return ThreadModel(
      id: 0,
      forumId: 0,
      userId: 0,
      title: '无标题',
      summary: '',
      content: '',
      cover: '',
      viewCount: 0,
      replyCount: 0,
      likeCount: 0,
      favoriteCount: 0,
      isTop: false,
      isDigest: false,
      createdAt: '',
      authorName: '匿名用户',
      authorAvatar: '',
      forumName: '社区',
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static String _toString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final str = value.toString();
    return str.isEmpty ? fallback : str;
  }
}
```

---

# 十、认证状态：允许游客模式

不登录也能使用，所以 AuthState 有 guest 状态。

## lib/features/auth/auth_controller.dart

```dart
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
```

---

# 十一、首页 Repository

兼容分页数据格式：

支持后端返回：

```json
{
  "data": {
    "list": []
  }
}
```

或：

```json
{
  "data": {
    "data": []
  }
}
```

或：

```json
{
  "data": []
}
```

## lib/features/home/home_repository.dart

```dart
import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../core/config/app_config.dart';
import '../thread/thread_model.dart';

class HomeRepository {
  Future<ApiResult<List<ThreadModel>>> fetchFeed({
    required int page,
    required String channel,
  }) async {
    final result = await ApiClient.instance.get(
      'home/feed',
      query: {
        'page': page,
        'page_size': AppConfig.pageSize,
        'channel': channel,
      },
    );

    if (!result.success) {
      return ApiResult.fail(result.message, code: result.code);
    }

    try {
      final dynamic data = result.data;

      List list = [];

      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        if (data['list'] is List) {
          list = data['list'];
        } else if (data['data'] is List) {
          list = data['data'];
        } else if (data['items'] is List) {
          list = data['items'];
        }
      }

      final threads = list
          .map((item) => ThreadModel.fromJson(item))
          .where((item) => item.id > 0)
          .toList();

      return ApiResult.ok(threads);
    } catch (_) {
      return ApiResult.fail('列表数据解析失败');
    }
  }
}
```

---

# 十二、首页 Feed 状态管理

## lib/features/home/home_feed_controller.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../thread/thread_model.dart';
import 'home_repository.dart';

final homeFeedControllerProvider =
    StateNotifierProvider<HomeFeedController, HomeFeedState>((ref) {
  return HomeFeedController(HomeRepository())..refresh();
});

class HomeFeedState {
  final bool loading;
  final bool refreshing;
  final bool loadingMore;
  final bool noMore;
  final int page;
  final String channel;
  final List<ThreadModel> items;
  final String? error;

  const HomeFeedState({
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.noMore = false,
    this.page = 1,
    this.channel = 'recommend',
    this.items = const [],
    this.error,
  });

  HomeFeedState copyWith({
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    bool? noMore,
    int? page,
    String? channel,
    List<ThreadModel>? items,
    String? error,
  }) {
    return HomeFeedState(
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      noMore: noMore ?? this.noMore,
      page: page ?? this.page,
      channel: channel ?? this.channel,
      items: items ?? this.items,
      error: error,
    );
  }
}

class HomeFeedController extends StateNotifier<HomeFeedState> {
  final HomeRepository repository;

  HomeFeedController(this.repository) : super(const HomeFeedState());

  Future<void> refresh() async {
    if (state.refreshing) return;

    state = state.copyWith(
      loading: state.items.isEmpty,
      refreshing: true,
      page: 1,
      noMore: false,
      error: null,
    );

    final result = await repository.fetchFeed(
      page: 1,
      channel: state.channel,
    );

    if (result.success) {
      final list = result.data ?? [];

      state = state.copyWith(
        loading: false,
        refreshing: false,
        items: list,
        page: 1,
        noMore: list.isEmpty,
        error: null,
      );
    } else {
      state = state.copyWith(
        loading: false,
        refreshing: false,
        error: result.message,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loading ||
        state.refreshing ||
        state.loadingMore ||
        state.noMore) {
      return;
    }

    state = state.copyWith(
      loadingMore: true,
      error: null,
    );

    final nextPage = state.page + 1;

    final result = await repository.fetchFeed(
      page: nextPage,
      channel: state.channel,
    );

    if (result.success) {
      final list = result.data ?? [];

      state = state.copyWith(
        loadingMore: false,
        page: nextPage,
        items: [...state.items, ...list],
        noMore: list.isEmpty,
        error: null,
      );
    } else {
      state = state.copyWith(
        loadingMore: false,
        error: result.message,
      );
    }
  }

  Future<void> switchChannel(String channel) async {
    if (state.channel == channel) return;

    state = HomeFeedState(
      channel: channel,
      loading: true,
    );

    await refresh();
  }
}
```

---

# 十三、主入口 App

## lib/main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(
    const ProviderScope(
      child: ForumXApp(),
    ),
  );
}
```

---

## lib/app.dart

```dart
import 'package:flutter/material.dart';

import 'router.dart';

class ForumXApp extends StatelessWidget {
  const ForumXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ForumX Lite',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFB7299),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
    );
  }
}
```

---

# 十四、路由

## lib/router.dart

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_page.dart';
import 'features/main/main_shell_page.dart';
import 'features/thread/thread_detail_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const MainShellPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginPage(),
    ),
    GoRoute(
      path: '/thread/:id',
      builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

        return ThreadDetailPage(threadId: id);
      },
    ),
  ],
  errorBuilder: (_, __) {
    return const Scaffold(
      body: Center(
        child: Text('页面不存在'),
      ),
    );
  },
);
```

---

# 十五、底部导航主框架

5 个按钮：首页、动态、加号、发现、我的。

中间加号特殊样式。

## lib/features/main/main_shell_page.dart

```dart
import 'package:flutter/material.dart';

import '../discover/discover_page.dart';
import '../dynamic/dynamic_page.dart';
import '../home/home_page.dart';
import '../me/me_page.dart';
import '../post/create_post_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    HomePage(),
    DynamicPage(),
    CreatePostPage(),
    DiscoverPage(),
    MePage(),
  ];

  void onTap(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _ForumBottomNavBar(
        currentIndex: currentIndex,
        onTap: onTap,
      ),
    );
  }
}

class _ForumBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ForumBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _NavItem(
            index: 0,
            currentIndex: currentIndex,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: '首页',
            onTap: onTap,
          ),
          _NavItem(
            index: 1,
            currentIndex: currentIndex,
            icon: Icons.bubble_chart_outlined,
            activeIcon: Icons.bubble_chart,
            label: '动态',
            onTap: onTap,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Center(
                child: Container(
                  width: 48,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB7299),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFB7299).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          _NavItem(
            index: 3,
            currentIndex: currentIndex,
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore,
            label: '发现',
            onTap: onTap,
          ),
          _NavItem(
            index: 4,
            currentIndex: currentIndex,
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: '我的',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    final color = active ? const Color(0xFFFB7299) : Colors.grey.shade600;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

# 十六、首页顶栏：头像 + 搜索 + 私信

## lib/features/home/widgets/home_top_bar.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../auth/auth_controller.dart';

class HomeTopBar extends ConsumerWidget {
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onMessageTap;

  const HomeTopBar({
    super.key,
    this.onAvatarTap,
    this.onSearchTap,
    this.onMessageTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    final avatar = auth.user?['avatar']?.toString() ?? '';

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 12,
        right: 12,
        bottom: 8,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: SafeNetworkImage(
              url: avatar.isNotEmpty ? avatar : AppConfig.defaultAvatar,
              width: 36,
              height: 36,
              borderRadius: BorderRadius.circular(18),
              errorWidget: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                child: Icon(
                  auth.loggedIn ? Icons.person : Icons.person_outline,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onSearchTap,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '搜索帖子、版块、用户',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onMessageTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.mail_outline_rounded,
                    color: Colors.grey.shade800,
                    size: 25,
                  ),
                  if (auth.loggedIn)
                    Positioned(
                      right: 5,
                      top: 6,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFB7299),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

# 十七、首页频道 Tab

## lib/features/home/widgets/home_channel_tabs.dart

```dart
import 'package:flutter/material.dart';

class HomeChannel {
  final String label;
  final String value;

  const HomeChannel({
    required this.label,
    required this.value,
  });
}

class HomeChannelTabs extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const HomeChannelTabs({
    super.key,
    required this.current,
    required this.onChanged,
  });

  static const channels = [
    HomeChannel(label: '推荐', value: 'recommend'),
    HomeChannel(label: '热门', value: 'hot'),
    HomeChannel(label: '最新', value: 'latest'),
    HomeChannel(label: '精华', value: 'digest'),
    HomeChannel(label: '关注', value: 'follow'),
    HomeChannel(label: '图文', value: 'image'),
    HomeChannel(label: '问答', value: 'qa'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (_, index) {
          final item = channels[index];
          final selected = current == item.value;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(item.value),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: selected ? 16 : 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? const Color(0xFFFB7299)
                            : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selected ? 18 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB7299),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemCount: channels.length,
      ),
    );
  }
}
```

---

# 十八、瀑布流帖子卡片

## lib/features/home/widgets/thread_waterfall_card.dart

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/safe_network_image.dart';
import '../../thread/thread_model.dart';

class ThreadWaterfallCard extends StatelessWidget {
  final ThreadModel thread;

  const ThreadWaterfallCard({
    super.key,
    required this.thread,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: thread.id > 0 ? () => context.push('/thread/${thread.id}') : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade100,
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(thread: thread),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                thread.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  height: 1.25,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
            ),
            if (thread.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Text(
                  thread.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.25,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
              child: Row(
                children: [
                  SafeNetworkImage(
                    url: thread.authorAvatar,
                    width: 20,
                    height: 20,
                    borderRadius: BorderRadius.circular(10),
                    errorWidget: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(
                        Icons.person,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      thread.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 15,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(thread.likeCount),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }
}

class _Cover extends StatelessWidget {
  final ThreadModel thread;

  const _Cover({
    required this.thread,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = thread.cover.isNotEmpty;

    return Stack(
      children: [
        if (hasCover)
          SafeNetworkImage(
            url: thread.cover,
            width: double.infinity,
            height: _mockHeight(thread.id),
            fit: BoxFit.cover,
          )
        else
          Container(
            width: double.infinity,
            height: _mockHeight(thread.id),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.pink.shade50,
                  Colors.blue.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.article_outlined,
                size: 38,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        Positioned(
          left: 6,
          top: 6,
          child: Row(
            children: [
              if (thread.isTop) _badge('置顶', Colors.red),
              if (thread.isDigest) _badge('精华', Colors.orange),
            ],
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 11,
                ),
                const SizedBox(width: 2),
                Text(
                  '${thread.replyCount}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _mockHeight(int id) {
    final heights = [120.0, 145.0, 170.0, 135.0, 190.0];
    return heights[id.abs() % heights.length];
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```

---

# 十九、首页页面：B 站顶栏 + 小红书瀑布流

## lib/features/home/home_page.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import 'home_feed_controller.dart';
import 'widgets/home_channel_tabs.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/thread_waterfall_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    scrollController.addListener(() {
      if (!scrollController.hasClients) return;

      final position = scrollController.position;

      if (position.pixels >= position.maxScrollExtent - 500) {
        ref.read(homeFeedControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _showGuestMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(homeFeedControllerProvider);
    final controller = ref.read(homeFeedControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          HomeTopBar(
            onAvatarTap: () {
              _showGuestMessage('进入我的页面');
            },
            onSearchTap: () {
              _showGuestMessage('搜索功能开发中');
            },
            onMessageTap: () {
              _showGuestMessage('私信需要登录后使用');
              context.push('/login');
            },
          ),
          HomeChannelTabs(
            current: state.channel,
            onChanged: controller.switchChannel,
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (state.loading && state.items.isEmpty) {
                  return const LoadingView();
                }

                if (state.error != null && state.items.isEmpty) {
                  return ErrorView(
                    message: state.error!,
                    onRetry: controller.refresh,
                  );
                }

                if (state.items.isEmpty) {
                  return ErrorView(
                    message: '暂无内容',
                    onRetry: controller.refresh,
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFFFB7299),
                  onRefresh: controller.refresh,
                  child: CustomScrollView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        sliver: SliverMasonryGrid.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childCount: state.items.length,
                          itemBuilder: (context, index) {
                            return ThreadWaterfallCard(
                              thread: state.items[index],
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _BottomLoadState(
                          loadingMore: state.loadingMore,
                          noMore: state.noMore,
                          error: state.error,
                          onRetry: controller.loadMore,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomLoadState extends StatelessWidget {
  final bool loadingMore;
  final bool noMore;
  final String? error;
  final VoidCallback onRetry;

  const _BottomLoadState({
    required this.loadingMore,
    required this.noMore,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (error != null && error!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: TextButton(
            onPressed: onRetry,
            child: Text('加载失败，点击重试：$error'),
          ),
        ),
      );
    }

    if (noMore) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Text(
            '没有更多了',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: 20);
  }
}
```

---

# 二十、帖子详情页：安全加载

## lib/features/thread/thread_detail_page.dart

```dart
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/safe_network_image.dart';
import 'thread_model.dart';

class ThreadDetailPage extends StatefulWidget {
  final int threadId;

  const ThreadDetailPage({
    super.key,
    required this.threadId,
  });

  @override
  State<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<ThreadDetailPage> {
  bool loading = true;
  String? error;
  ThreadModel? thread;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (widget.threadId <= 0) {
      setState(() {
        loading = false;
        error = '帖子不存在';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    final result = await ApiClient.instance.get(
      'threads/detail',
      query: {
        'id': widget.threadId,
      },
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        thread = ThreadModel.fromJson(result.data);
        loading = false;
      });
    } else {
      setState(() {
        error = result.message;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = thread;

    return Scaffold(
      appBar: AppBar(
        title: const Text('帖子详情'),
      ),
      body: Builder(
        builder: (_) {
          if (loading) {
            return const LoadingView();
          }

          if (error != null) {
            return ErrorView(
              message: error!,
              onRetry: _loadDetail,
            );
          }

          if (item == null) {
            return ErrorView(
              message: '帖子不存在',
              onRetry: _loadDetail,
            );
          }

          return RefreshIndicator(
            onRefresh: _loadDetail,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SafeNetworkImage(
                      url: item.authorAvatar,
                      width: 36,
                      height: 36,
                      borderRadius: BorderRadius.circular(18),
                      errorWidget: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade200,
                        child: Icon(
                          Icons.person,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${item.viewCount} 浏览',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (item.cover.isNotEmpty)
                  SafeNetworkImage(
                    url: item.cover,
                    width: double.infinity,
                    height: 220,
                    borderRadius: BorderRadius.circular(12),
                  ),
                if (item.cover.isNotEmpty) const SizedBox(height: 16),
                Text(
                  item.content.isNotEmpty ? item.content : item.summary,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.favorite_border,
                      text: '${item.likeCount}',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('点赞需要登录')),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      icon: Icons.chat_bubble_outline,
                      text: '${item.replyCount}',
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      icon: Icons.star_border,
                      text: '${item.favoriteCount}',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('收藏需要登录')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
    );
  }
}
```

---

# 二十一、登录页：不强制登录

## lib/features/auth/login_page.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final accountController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscure = true;

  @override
  void dispose() {
    accountController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final account = accountController.text.trim();
    final password = passwordController.text;

    if (account.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账号和密码')),
      );
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).login(
          account: account,
          password: password,
        );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(authControllerProvider).error ?? '登录失败';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 40),
          const Text(
            '欢迎回来',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '不登录也可以浏览社区内容',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: accountController,
            decoration: const InputDecoration(
              labelText: '用户名 / 邮箱',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: '密码',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    obscure = !obscure;
                  });
                },
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.loading ? null : _login,
            child: auth.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登录'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('先不登录，继续浏览'),
          ),
        ],
      ),
    );
  }
}
```

---

# 二十二、其他底部页面占位

## lib/features/dynamic/dynamic_page.dart

```dart
import 'package:flutter/material.dart';

class DynamicPage extends StatelessWidget {
  const DynamicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('动态'),
      ),
      body: const Center(
        child: Text('动态页开发中，不登录也可浏览公开动态'),
      ),
    );
  }
}
```

---

## lib/features/post/create_post_page.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/login_page.dart';

class CreatePostPage extends ConsumerWidget {
  const CreatePostPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (!auth.loggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('发布'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 70,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  '登录后可以发布帖子',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '你仍然可以以游客身份浏览首页和发现内容',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                  child: const Text('去登录'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('发布帖子'),
      ),
      body: const Center(
        child: Text('发帖编辑器开发中'),
      ),
    );
  }
}
```

---

## lib/features/discover/discover_page.dart

```dart
import 'package:flutter/material.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      '热门话题',
      '热门版块',
      '热帖榜',
      '新帖榜',
      '签到榜',
      '推荐用户',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 92,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                items[index],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

---

## lib/features/me/me_page.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/login_page.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (!auth.loggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('我的'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(
                    Icons.person_outline,
                    size: 44,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '当前为游客模式',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '登录后可发帖、回复、收藏、签到',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                  child: const Text('登录 / 注册'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = auth.user ?? {};
    final nickname = user['nickname']?.toString() ?? '用户';
    final score = user['score']?.toString() ?? '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.pink.shade50,
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('积分：$score'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MenuItem(
            icon: Icons.article_outlined,
            text: '我的帖子',
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.star_border,
            text: '我的收藏',
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.calendar_month_outlined,
            text: '签到中心',
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.logout,
            text: '退出登录',
            onTap: () {
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
```

---

# 二十三、后端接口返回格式建议

你的原生 PHP 后端首页接口建议返回这种结构：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "list": [
      {
        "id": 1,
        "forum_id": 1,
        "user_id": 1,
        "title": "这是标题",
        "summary": "摘要内容",
        "content": "正文内容",
        "cover": "https://example.com/uploads/images/1.jpg",
        "view_count": 100,
        "reply_count": 20,
        "like_count": 12,
        "favorite_count": 3,
        "is_top": 0,
        "is_digest": 1,
        "created_at": "2025-01-01 12:00:00",
        "user": {
          "id": 1,
          "nickname": "测试用户",
          "avatar": "https://example.com/uploads/avatar/1.jpg"
        },
        "forum": {
          "id": 1,
          "name": "综合讨论"
        }
      }
    ],
    "page": 1,
    "page_size": 20,
    "has_more": true
  }
}
```

---

# 二十四、目前这套客户端已实现能力

已经具备：

- 原生 PHP 虚拟主机 API 请求封装；
- 不登录浏览；
- 登录状态初始化；
- 首页 B 站式顶栏；
- 首页频道 Tab；
- 双列瀑布流；
- 图片加载失败兜底；
- 接口失败兜底；
- JSON 格式异常兜底；
- 分页加载；
- 下拉刷新；
- 底部 5 按钮导航；
- 游客模式；
- 登录页；
- 我的页游客提示；
- 帖子详情安全加载。

你只需要先把：

```dart
AppConfig.apiEntry = 'https://your-domain.com/index.php';
```

改成你的接口地址即可。
