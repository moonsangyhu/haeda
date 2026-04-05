import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_exception.dart';

const _baseUrl = 'http://localhost:8000/api/v1';

class AuthInterceptor extends QueuedInterceptorsWrapper {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
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
