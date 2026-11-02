// The server's action runner: one long-lived process beside Nest, spoken
// to in JSON lines on stdin and stdout, matched by `id`. Requests are
// handled side by side: a run waiting on a call does not hold up the rest.
//
//   {"id": 0, "type": "version"}
//     -> {"id": 0, "version": "..."}
//   {"id": 1, "type": "compile", "code": "<Dart>"}
//     -> {"id": 1, "evc": "<base64>", "version": "..."}
//     or {"id": 1, "error": "..."}
//   {"id": 2, "type": "run", "evc": "<base64>",
//    "input": "<JSON>", "event": "<JSON>", "calls": true}
//     -> {"id": 2, "patch": "<JSON>"}
//     or {"id": 2, "error": "...", "tooLong": true}
//
// A run with "calls" (a platform action) may ask Nest for something on the
// way, as many times as it awaits `call`:
//
//     <- {"id": 2, "call": {"seq": 0, "name": "apps.list", "event": "<JSON>"}}
//   {"id": 2, "type": "answer", "seq": 0, "result": "<JSON>"}
//     or {"id": 2, "type": "answer", "seq": 0, "error": "..."}
//
// Any other run has no `call`: a server action is the one being called.
// The heap is capped from outside (DART_VM_OPTIONS=--old_gen_heap_size=<MB>);
// past it the process dies, and Nest starts another.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:action_runner/compile.dart';
import 'package:action_runner/run.dart';

/// Calls waiting on Nest's answer, by run id and seq.
final _calls = <(Object?, int), Completer<String>>{};

Future<void> main() async {
  await stdin.transform(utf8.decoder).transform(const LineSplitter()).forEach((
    line,
  ) {
    // Not awaited: the next line may be the answer this one waits on.
    unawaited(_handle(line).then(_write));
  });
}

void _write(Map<String, Object?>? message) {
  if (message != null) stdout.writeln(jsonEncode(message));
}

Future<Map<String, Object?>?> _handle(String line) async {
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
        final runId = id;
        var seq = 0;
        final patch = await runAction(
          base64Decode(request['evc'] as String),
          input: request['input'] as String,
          event: request['event'] as String,
          call: request['calls'] == true
              ? (name, event) {
                  final key = (runId, seq++);
                  final answer = Completer<String>();
                  _calls[key] = answer;
                  _write({
                    'id': runId,
                    'call': {'seq': key.$2, 'name': name, 'event': event},
                  });
                  return answer.future;
                }
              : (_, _) async => throw StateError('a server action calls none'),
        );
        return {'id': id, 'patch': patch};
      case 'answer':
        final answer = _calls.remove((id, request['seq']));
        if (answer == null) return null;
        final error = request['error'];
        if (error is String) {
          answer.completeError(StateError(error));
        } else {
          answer.complete(request['result'] as String);
        }
        return null;
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
    return {'id': id, 'error': error is StateError ? error.message : '$error'};
  }
}
