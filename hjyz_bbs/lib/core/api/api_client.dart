import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../services/api_cache_service.dart';
import '../services/connectivity_service.dart';
import '../storage/token_storage.dart';
import '../utils/app_logger.dart';
import '../utils/device_helper.dart';
import '../utils/url_helper.dart';
import 'api_result.dart';
import 'server_manager.dart';
import 'write_queue.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final Map<int, Dio> _dioInstances = {};
  Dio? _fallbackDio;

  Dio _getDio() {
    final server = ServerManager.instance.currentServer;
    if (server == null) {
      return _getFallbackDio();
    }
    return _getDioForServer(server.id, server.url);
  }

  Dio _getDioForServer(int serverId, String baseUrl) {
    if (!_dioInstances.containsKey(serverId)) {
      _dioInstances[serverId] = _createDio(baseUrl);
    }
    return _dioInstances[serverId]!;
  }

  Dio _getFallbackDio() {
    _fallbackDio ??= _createDio(AppConfig.apiEntry);
    return _fallbackDio!;
  }

  Dio _createDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          'X-Client': 'flutter',
        },
        validateStatus: (status) {
          return status != null && status < 600;
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = UrlHelper.fix(options.baseUrl);
          final token = await TokenStorage.instance.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          try {
            final deviceName = await DeviceHelper.getDeviceName();
            options.headers['X-Device-Name'] = deviceName;
          } catch (_) {}
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );

    return dio;
  }

  Dio get dio => _getDio();

  String resolveUrl(String url) {
    final value = UrlHelper.fix(url.trim());
    if (value.isEmpty) return value;

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;

    final base = Uri.tryParse(UrlHelper.fix(_getDio().options.baseUrl));
    return base?.resolve(value).toString() ?? value;
  }

  Future<Response<List<int>>> rawGet(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _getDio().get<List<int>>(
      resolveUrl(url),
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  Future<ApiResult<dynamic>> get(
    String route, {
    Map<String, dynamic>? query,
  }) async {
    final servers = ServerManager.instance.activeServers;
    await AppLogger.log('ApiClient', 'get start: route=$route servers=${servers.length}');
    DioException? lastError;
    ApiResult<dynamic>? lastResponse;

    for (final server in servers) {
      try {
        final dio = _getDioForServer(server.id, server.url);
        final response = await dio.get(
          '',
          queryParameters: {
            'route': route,
            ...?query,
          },
        );
        ConnectivityService.instance.markOnline();
        ServerManager.instance.reportSuccess(server.id);
        final result = _handleResponse(response);
        await AppLogger.log('ApiClient', 'get OK: route=$route serverId=${server.id} code=${response.statusCode}');
        if (result.success) {
          await ApiCacheService.instance.write(route, query, result.data);
          return result;
        }
        if (result.code == 401 || result.code == 403) return result;
        lastResponse = result;
      } on DioException catch (e) {
        lastError = e;
        ServerManager.instance.reportFailure(server.id);
        await AppLogger.log('ApiClient', 'get FAIL: route=$route serverId=${server.id} error=${e.type} ${e.message}');
        continue;
      } catch (e) {
        await AppLogger.log('ApiClient', 'get ERROR: route=$route error=$e');
        continue;
      }
    }

    await AppLogger.log('ApiClient', 'get ALL_FAILED: route=$route');
    if (lastError != null || lastResponse == null) {
      ConnectivityService.instance.markOffline();
    }
    final cached = await ApiCacheService.instance.read(route, query);
    if (cached != null) {
      return ApiResult.ok(cached, message: '当前为离线模式，已加载本地缓存');
    }
    if (lastResponse != null) return lastResponse;
    return ApiResult.fail(
      lastError == null ? '当前无可用网络' : _dioErrorMessage(lastError),
      code: -1,
    );
  }

  Future<ApiResult<dynamic>> post(
    String route, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    FormData? formData,
  }) async {
    final servers = ServerManager.instance.activeServers;
    await AppLogger.log('ApiClient', 'post start: route=$route servers=${servers.length}');

    for (final server in servers) {
      try {
        final dio = _getDioForServer(server.id, server.url);
        final response = await dio.post(
          '',
          queryParameters: {
            'route': route,
            ...?query,
          },
          data: formData ?? data,
        );
        ConnectivityService.instance.markOnline();
        ServerManager.instance.reportSuccess(server.id);
        final result = _handleResponse(response);
        await AppLogger.log('ApiClient', 'post OK: route=$route serverId=${server.id} code=${response.statusCode}');
        return result;
      } on DioException catch (e) {
        ServerManager.instance.reportFailure(server.id);
        await AppLogger.log('ApiClient', 'post FAIL: route=$route serverId=${server.id} error=${e.type} ${e.message}');
        continue;
      } catch (e) {
        await AppLogger.log('ApiClient', 'post ERROR: route=$route error=$e');
        continue;
      }
    }

    await AppLogger.log('ApiClient', 'post ALL_FAILED, enqueue: route=$route');
    ConnectivityService.instance.markOffline();
    final canQueue = !route.startsWith('auth/');
    if (canQueue) {
      await WriteQueue.instance.enqueue(route, data: data);
    }

    return ApiResult.fail(
      canQueue ? '所有服务器均不可用，请求已加入重试队列' : '当前网络不可用',
      code: -1,
    );
  }

  ApiResult<dynamic> _handleResponse(Response response) {
    try {
      final statusCode = response.statusCode ?? 0;

      if (statusCode >= 500) {
        AppLogger.log('ApiClient', 'handleResponse: 500 status=$statusCode');
        return ApiResult.fail('服务器开小差了，请稍后再试', code: statusCode);
      }

      if (statusCode == 404) {
        AppLogger.log('ApiClient', 'handleResponse: 404');
        return ApiResult.fail('接口不存在', code: 404);
      }

      dynamic body = response.data;

      if (body is String) {
        try {
          body = jsonDecode(body);
        } catch (_) {
          AppLogger.log('ApiClient', 'handleResponse: jsonDecode failed, body=$body');
          return ApiResult.fail('服务器返回格式异常');
        }
      }

      if (body is! Map<String, dynamic>) {
        AppLogger.log('ApiClient', 'handleResponse: not Map, type=${body.runtimeType}');
        return ApiResult.fail('服务器返回数据异常');
      }

      final int code = _safeInt(body['code'], defaultValue: -1);
      final String message = body['message']?.toString() ?? '';

      AppLogger.log('ApiClient', 'handleResponse: code=$code dataType=${body['data']?.runtimeType}');

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
    } catch (e) {
      AppLogger.log('ApiClient', 'handleResponse: exception=$e');
      return ApiResult.fail('数据解析失败');
    }
  }

  int _safeInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Future<ApiResult<dynamic>> uploadFile(
    String route, {
    required File file,
    Map<String, String>? fields,
  }) async {
    final servers = ServerManager.instance.activeServers;
    DioException? lastError;

    for (final server in servers) {
      try {
        final formData = FormData.fromMap({
          ...?fields,
          'file': await MultipartFile.fromFile(file.path),
        });

        final dio = _getDioForServer(server.id, server.url);
        final response = await dio.post(
          '',
          queryParameters: {
            'route': route,
          },
          data: formData,
          options: Options(
            sendTimeout: const Duration(seconds: 300),
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        ConnectivityService.instance.markOnline();
        ServerManager.instance.reportSuccess(server.id);
        return _handleResponse(response);
      } on DioException catch (e) {
        lastError = e;
        ServerManager.instance.reportFailure(server.id);
        continue;
      } catch (_) {
        continue;
      }
    }

    ConnectivityService.instance.markOffline();
    return ApiResult.fail(lastError != null
        ? _dioErrorMessage(lastError)
        : '上传失败，请稍后重试');
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
