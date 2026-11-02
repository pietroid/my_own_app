// The server's action runner: one long-lived process beside Nest, spoken
// to in JSON lines on stdin and stdout, one request and one answer per line,
// matched by `id`.
//
//   {"id": 0, "type": "version"}
//     -> {"id": 0, "version": "..."}
//   {"id": 1, "type": "compile", "code": "<Dart>"}
//     -> {"id": 1, "evc": "<base64>", "version": "..."}
//     or {"id": 1, "error": "..."}
//   {"id": 2, "type": "run", "evc": "<base64>",
//    "input": "<JSON>", "event": "<JSON>"}
//     -> {"id": 2, "patch": "<JSON>"}
//     or {"id": 2, "error": "...", "tooLong": true}
//
// A server action has no `call`: it is the one being called. Its heap is
// capped from outside (DART_VM_OPTIONS=--old_gen_heap_size=<MB>); past it the
// process dies, and Nest starts another.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:action_runner/compile.dart';
import 'package:action_runner/run.dart';

Future<void> main() async {
  await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .asyncMap(_handle)
      .forEach((answer) => stdout.writeln(jsonEncode(answer)));
}

Future<Map<String, Object?>> _handle(String line) async {
  Object? id;
  try {
    final request = jsonDecode(line) as Map<String, dynamic>;
    id = request['id'];
    switch (request['type']) {
      case 'version':
        return {'id': id, 'version': runnerVersion};
      case 'compile':
        final evc = compileAction(request['code'] as String);
        return {'id': id, 'evc': base64Encode(evc), 'version': runnerVersion};
      case 'run':
        final patch = await runAction(
          base64Decode(request['evc'] as String),
          input: request['input'] as String,
          event: request['event'] as String,
          call: (_, _) async => throw StateError('a server action calls none'),
        );
        return {'id': id, 'patch': patch};
      default:
        return {'id': id, 'error': 'unknown request'};
    }
  } on ActionCompileError catch (error) {
    return {'id': id, 'error': error.message};
  } on ActionRunError catch (error) {
    return {'id': id, 'error': error.message, 'tooLong': error.tooLong};
    // Anything else is this request failing, never the process.
    // ignore: avoid_catches_without_on_clauses
  } catch (error) {
    return {'id': id, 'error': '$error'};
  }
}
