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
