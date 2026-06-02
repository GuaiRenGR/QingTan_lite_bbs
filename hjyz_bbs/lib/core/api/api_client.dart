import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import '../utils/device_helper.dart';
import '../utils/url_helper.dart';
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
          options.baseUrl = UrlHelper.fix(options.baseUrl);
          final token = await TokenStorage.instance.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // 注入设备名称，用于服务端记录登录设备
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

  Future<ApiResult<dynamic>> uploadFile(
    String route, {
    required File file,
    Map<String, String>? fields,
  }) async {
    try {
      final formData = FormData.fromMap({
        ...?fields,
        'file': await MultipartFile.fromFile(file.path),
      });

      final response = await _dio.post(
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

      return _handleResponse(response);
    } on DioException catch (e) {
      return ApiResult.fail(_dioErrorMessage(e));
    } catch (e) {
      return ApiResult.fail('上传失败：$e');
    }
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
