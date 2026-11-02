import 'package:my_own_app/apps/client_runner.dart';

/// iOS and Android: client actions are not run on the device yet.
ClientRunner createClientRunner() => const _Unsupported();

class _Unsupported implements ClientRunner {
  const _Unsupported();

  @override
  Future<List<dynamic>> run({
    required String code,
    required Map<String, Object?> input,
    required Map<String, Object?> event,
    required ServerCall call,
  }) => Future.error(const ClientActionFailed('not on this platform yet'));

  @override
  void warm() {}

  @override
  void close() {}
}
