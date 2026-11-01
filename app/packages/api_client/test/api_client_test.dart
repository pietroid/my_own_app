import 'dart:convert';
import 'dart:typed_data';

import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tokens extends TokenProvider {
  const _Tokens();

  @override
  Future<String?> getToken() async => 'token';

  @override
  Future<String?> refreshToken() async => null;
}

/// Answers every request with [status], or fails to connect when null.
class _Server implements HttpClientAdapter {
  _Server(this.status);

  final int? status;

  /// The headers of every request it was sent.
  final List<Map<String, dynamic>> headers = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headers.add(options.headers);
    final status = this.status;
    if (status == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'message': 'x'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiClient onServerError', () {
    Future<List<DioException>> failuresFor(int? status) async {
      final failures = <DioException>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://app.test/api'))
        ..httpClientAdapter = _Server(status);
      final client = ApiClient(
        baseUrl: 'https://app.test/api',
        tokenProvider: const _Tokens(),
        dio: dio,
        onServerError: failures.add,
      );
      await expectLater(
        client.post<Object?>('/items/i-1'),
        throwsA(isA<DioException>()),
      );
      return failures;
    }

    test('hears of a 5xx', () async {
      final failures = await failuresFor(500);

      expect(failures, hasLength(1));
      expect(failures.single.response?.statusCode, 500);
      expect(failures.single.requestOptions.path, '/items/i-1');
    });

    test('does not hear of a refusal', () async {
      expect(await failuresFor(400), isEmpty);
    });

    test('does not hear of a dropped network', () async {
      expect(await failuresFor(null), isEmpty);
    });
  });
}
