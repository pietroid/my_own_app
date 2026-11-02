import 'dart:convert';

import 'package:action_runner/run.dart';

/// Runs a server action from inside a client one: answers with the JSON
/// Patch the server kept, already applied to the app's data.
typedef ServerCall =
    Future<List<dynamic>> Function(String action, Map<String, Object?> event);

/// {@template client_action_failed}
/// A client action that threw, ran too long, or whose bytecode this app
/// cannot read (an app older than the server).
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
/// Runs a client action on the device, and answers with the JSON Patch it
/// returned.
///
/// The action is Dart the server compiled into dart_eval bytecode, run by
/// the same interpreter on the web, iOS and Android (`runner/`, the one the
/// server runs too). It gets no files, network or processes; `call` is its
/// one way out, and it reaches only the app's server actions. It runs on
/// this isolate within a step budget, so a loop that never ends stops
/// instead of freezing the screen.
/// {@endtemplate}
// One seam, and a fake in tests.
// ignore: one_member_abstracts
abstract interface class ClientRunner {
  /// {@macro client_runner}
  factory ClientRunner() => const _EvalRunner();

  /// Runs [evc] (base64) with [input] (keyed by pointer) and [event];
  /// [call] runs a server action on its behalf.
  Future<List<dynamic>> run({
    required String evc,
    required Map<String, Object?> input,
    required Map<String, Object?> event,
    required ServerCall call,
  });
}

class _EvalRunner implements ClientRunner {
  const _EvalRunner();

  @override
  Future<List<dynamic>> run({
    required String evc,
    required Map<String, Object?> input,
    required Map<String, Object?> event,
    required ServerCall call,
  }) async {
    try {
      final patch = await runAction(
        base64Decode(evc),
        input: jsonEncode(input),
        event: jsonEncode(event),
        call: (action, event) async => jsonEncode(
          await call(action, jsonDecode(event) as Map<String, Object?>),
        ),
      );
      return jsonDecode(patch) as List<dynamic>;
    } on ActionRunError catch (error) {
      throw ClientActionFailed(error.message);
    } on FormatException catch (error) {
      throw ClientActionFailed('bad bytecode: ${error.message}');
    }
  }
}
