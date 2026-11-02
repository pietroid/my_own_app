/// Running an action's bytecode. The app and the server both do this, on
/// every platform, the web included.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:action_runner/src/source.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
// The step budget is ours, in the vendored copy: see third_party/README.md.
// ignore: implementation_imports
import 'package:dart_eval/src/eval/runtime/runtime.dart'
    show RuntimeException, StepLimitExceeded;
import 'package:dart_eval/stdlib/core.dart';

/// Which runner writes and reads bytecode: dart_eval's version and our
/// changes to it. Bytecode runs only on the runner that wrote it; bump the
/// last number when a change to `third_party/` changes what runs.
const runnerVersion = 'dart_eval-0.8.5+steps.1+nullable-as.1+call.2';

/// How many interpreter steps one run may take, its continuations after
/// each `await` included. About 50 ms of work on a phone; the time spent
/// waiting on `call` does not count.
const defaultStepLimit = 2000000;

/// What an action's `call` reaches: takes a name and an event (JSON) and
/// answers JSON. On the device, a saved action, answering the patch the
/// server kept; on the server, inside a platform action, a platform call
/// (`apps.list`, ...), answering its result.
typedef HostCall = Future<String> Function(String action, String event);

/// {@template action_run_error}
/// An action that threw, returned something that is not a patch, or ran
/// past its step budget ([tooLong]).
/// {@endtemplate}
class ActionRunError implements Exception {
  /// {@macro action_run_error}
  const ActionRunError(this.message, {this.tooLong = false});

  /// Why, for logs.
  final String message;

  /// Whether it ran past its step budget.
  final bool tooLong;

  @override
  String toString() => 'ActionRunError: $message';
}

/// Runs the action in [evc] with [input] and [event] (both JSON) and
/// answers with its JSON Patch, as JSON.
///
/// [call] is the action's one way out. A [call] that throws fails the
/// action with that same error, so the person reads the server's words.
/// Nothing else is granted: no files, no network, no processes.
Future<String> runAction(
  Uint8List evc, {
  required String input,
  required String event,
  required HostCall call,
  int stepLimit = defaultStepLimit,
}) async {
  Object? callError;
  final host = $Closure((runtime, target, args) {
    final name = args[0]!.$value as String;
    final payload = args[1]!.$value as String;
    return $Future.wrap(
      call(name, payload).then<$Value>(
        $String.new,
        onError: (Object error) {
          callError = error;
          // The host's own error, kept so it is rethrown as the host threw it.
          // ignore: only_throw_errors
          throw error;
        },
      ),
    );
  });
  final Runtime runtime;
  try {
    runtime = Runtime(ByteData.sublistView(evc))..stepLimit = stepLimit;
  } catch (error) {
    // A bad or foreign blob fails as the action failing, whatever it threw.
    throw ActionRunError('bad bytecode: $error');
  }
  try {
    final out =
        await (runtime.executeLib(actionLibrary, entryFunction, [
              $String(input),
              $String(event),
              host,
            ])
            as Future);
    final text = out is $Value ? out.$value : out;
    if (text is! String) throw const ActionRunError('no patch');
    if (jsonDecode(text) is! List) throw const ActionRunError('no patch');
    return text;
  } on ActionRunError {
    rethrow;
  } catch (error) {
    // Whatever the program threw, it fails the action.
    final failed = callError;
    // The server's error, as the server threw it.
    // ignore: only_throw_errors
    if (failed != null) throw failed;
    if (_tooLong(error)) {
      throw ActionRunError('more than $stepLimit steps', tooLong: true);
    }
    throw ActionRunError('$error');
  }
}

bool _tooLong(Object error) =>
    error is StepLimitExceeded ||
    (error is RuntimeException && error.caughtException is StepLimitExceeded);
