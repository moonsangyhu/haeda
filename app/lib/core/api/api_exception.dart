class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  factory ApiException.fromMap(Map<String, dynamic> map, {int? statusCode}) {
    final error = map['error'] as Map<String, dynamic>?;
    if (error != null) {
      return ApiException(
        code: error['code'] as String? ?? 'UNKNOWN_ERROR',
        message: error['message'] as String? ?? '알 수 없는 오류가 발생했습니다.',
        statusCode: statusCode,
      );
    }
    return ApiException(
      code: 'UNKNOWN_ERROR',
      message: '알 수 없는 오류가 발생했습니다.',
      statusCode: statusCode,
    );
  }

  @override
  String toString() => 'ApiException($code): $message';
}
