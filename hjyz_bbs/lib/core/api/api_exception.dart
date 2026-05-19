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
