import 'package:my_own_app/apps/client_runner_stub.dart'
    if (dart.library.js_interop) 'package:my_own_app/apps/client_runner_web.dart'
    as platform;

/// Runs a server action from inside a client one: answers with the JSON
/// Patch the server kept, already applied to the app's data.
typedef ServerCall =
    Future<List<dynamic>> Function(String action, Map<String, Object?> event);

/// {@template client_action_failed}
/// A client action that did not compile, threw, ran too long, or cannot run
/// on this device.
/// {@endtemplate}
class ClientActionFailed implements Exception {
  /// {@macro client_action_failed}
  const ClientActionFailed(this.reason);

  /// Why, for logs; the person is shown the app's own words.
  final String reason;

  @override
  String toString() => 'ClientActionFailed: $reason';
}

/// {@template client_runner}
/// Runs a client action, `async function run(input, event, call)`, on the
/// device, and answers with the JSON Patch it returned.
///
/// On the web it runs in a Worker of its own with no network; `call` is the
/// one way out, and it reaches only the app's server actions. On iOS and
/// Android client actions do not run yet: they fail.
/// {@endtemplate}
// One seam with two platforms behind it, and a fake in tests.
abstract interface class ClientRunner {
  /// {@macro client_runner}
  factory ClientRunner() => platform.createClientRunner();

  /// Runs [code] with [input] (keyed by pointer) and [event]; [call] runs a
  /// server action on its behalf.
  Future<List<dynamic>> run({
    required String code,
    required Map<String, Object?> input,
    required Map<String, Object?> event,
    required ServerCall call,
  });

  /// Gets the next run ready ahead of time, so a tap does not wait for it.
  void warm();

  /// Lets go of what [warm] got ready; nothing runs after.
  void close();
}
