import 'dart:developer';

import 'package:api_client/src/interceptors/auth_interceptor.dart';
import 'package:api_client/src/token_provider.dart';
import 'package:dio/dio.dart';

/// {@template api_client}
/// Dio-based HTTP client with automatic authentication headers and token
/// refresh on `401` responses.
///
/// `onServerError` hears of every answer the server failed (a 5xx): not a
/// refusal, which is a 4xx it wrote on purpose, and not a dropped network,
/// which is the device's.
/// {@endtemplate}
class ApiClient {
  /// {@macro api_client}
  ApiClient({
    required String baseUrl,
    required TokenProvider tokenProvider,
    Dio? dio,
    this._onServerError,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               contentType: Headers.jsonContentType,
               // Required for cross-origin requests when the backend sets
               // `Access-Control-Allow-Credentials: true`. The web adapter
               // reads this value from RequestOptions.extra; it is ignored
               // on mobile platforms.
               extra: const {'withCredentials': true},
             ),
           ) {
    _dio.interceptors.add(
      AuthInterceptor(
        tokenProvider: tokenProvider,
        dio: _dio,
      ),
    );
    _dio.interceptors.add(_loggingInterceptor());
  }

  final Dio _dio;
  final void Function(DioException error)? _onServerError;

  /// Performs a `GET` request to [path].
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  /// Performs a `POST` request to [path] with optional [data].
  Future<Response<T>> post<T>(String path, {Object? data}) {
    return _dio.post<T>(path, data: data);
  }

  /// Performs a `PUT` request to [path] with optional [data].
  Future<Response<T>> put<T>(String path, {Object? data}) {
    return _dio.put<T>(path, data: data);
  }

  /// Performs a `PATCH` request to [path] with optional [data].
  Future<Response<T>> patch<T>(String path, {Object? data}) {
    return _dio.patch<T>(path, data: data);
  }

  /// Performs a `DELETE` request to [path].
  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }

  Interceptor _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        log(
          '[ApiClient] >> ${options.method} ${options.uri}',
          name: 'api_client',
          error: {
            'headers': options.headers,
            'data': options.data,
          },
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        log(
          '[ApiClient] << ${response.statusCode} '
          '${response.requestOptions.uri}',
          name: 'api_client',
          error: {
            'data': response.data,
          },
        );
        handler.next(response);
      },
      onError: (error, handler) {
        log(
          '[ApiClient] !! ${error.response?.statusCode ?? 'network'} '
          '${error.requestOptions.uri}',
          name: 'api_client',
          error: {
            'message': error.message,
            'responseData': error.response?.data,
            'stackTrace': error.stackTrace.toString(),
          },
        );
        final status = error.response?.statusCode;
        if (status != null && status >= 500) _onServerError?.call(error);
        handler.next(error);
      },
    );
  }
}
