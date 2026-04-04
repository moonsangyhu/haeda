import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_exception.dart';

// TODO: auth 슬라이스 완성 후 실제 토큰 관리로 교체
const _testAccessToken = '11111111-1111-1111-1111-111111111111';
const _baseUrl = 'http://localhost:8000/api/v1';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'Bearer $_testAccessToken';
    handler.next(options);
  }
}

class ResponseInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      response.data = data['data'];
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null && response.data is Map<String, dynamic>) {
      final apiException = ApiException.fromMap(
        response.data as Map<String, dynamic>,
        statusCode: response.statusCode,
      );
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: apiException,
          response: response,
          type: err.type,
        ),
      );
      return;
    }
    handler.next(err);
  }
}

Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(AuthInterceptor());
  dio.interceptors.add(ResponseInterceptor());
  return dio;
}

final dioProvider = Provider<Dio>((ref) => createDioClient());
