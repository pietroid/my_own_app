import 'package:api_client/src/token_provider.dart';
import 'package:dio/dio.dart';

/// {@template auth_interceptor}
/// [Interceptor] that attaches a bearer token to every request and refreshes
/// it once when a `401 Unauthorized` response is received.
/// {@endtemplate}
class AuthInterceptor extends Interceptor {
  /// {@macro auth_interceptor}
  const AuthInterceptor({
    required this.tokenProvider,
    required this.dio,
  });

  /// Provider used to retrieve and refresh the access token.
  final TokenProvider tokenProvider;

  /// The Dio instance used to retry failed requests so that base URL,
  /// content type and CORS credentials settings are preserved.
  final Dio dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenProvider.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    try {
      final newToken = await tokenProvider.refreshToken();
      if (newToken == null || newToken.isEmpty) {
        handler.next(err);
        return;
      }

      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newToken';

      final response = await dio.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on Exception catch (_) {
      handler.next(err);
    }
  }
}
