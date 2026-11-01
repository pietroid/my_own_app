/// HTTP client with authentication and token refresh middleware.
library;

// The transport's own failure type, so a caller can read why a request was
// refused without taking a direct dependency on dio.
export 'package:dio/dio.dart' show DioException, RequestOptions, Response;
export 'src/api_client.dart';
export 'src/interceptors/auth_interceptor.dart';
export 'src/token_provider.dart';
