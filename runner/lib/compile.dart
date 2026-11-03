/// Compiling an action's Dart into EVC bytecode. Only the server does this:
/// the compiler brings the Dart analyzer with it.
library;

import 'dart:typed_data';

import 'package:action_runner/src/source.dart';
import 'package:dart_eval/dart_eval.dart';
// Its message is what the model needs; the class is not exported.
// ignore: implementation_imports
import 'package:dart_eval/src/eval/compiler/errors.dart' show CompileError;

/// {@template action_compile_error}
/// An action that is not Dart dart_eval can compile, with the compiler's
/// words, to hand back to the model.
/// {@endtemplate}
class ActionCompileError implements Exception {
  /// {@macro action_compile_error}
  const ActionCompileError(this.message);

  /// What the compiler said.
  final String message;

  @override
  String toString() => 'ActionCompileError: $message';
}

/// Compiles one action's [code] into bytecode `runAction` runs.
///
/// Throws [ActionCompileError] when it does not compile.
Uint8List compileAction(String code) {
  _warm();
  final compiler = Compiler();
  try {
    final program = compiler.compile({
      'app': {'main.dart': wrapAction(code)},
    });
    return program.write();
  } catch (error) {
    // The compiler throws errors as well as exceptions for bad source.
    throw ActionCompileError(_message(error));
  }
}

String _message(Object error) {
  if (error is CompileError) return error.message;
  final text = '$error';
  return text.length > 500 ? '${text.substring(0, 500)}…' : text;
}

var _warmed = false;

/// dart_eval 0.8.5 fails the first program of a process that reads some
/// core members on a typed value (`List x; x.length`), with a RangeError
/// from its own state; every program after compiles. So the first compile
/// of a process is one of ours, made to be thrown away.
void _warm() {
  if (_warmed) return;
  _warmed = true;
  try {
    Compiler().compile({
      'app': {
        'main.dart': wrapAction('''
int f(List x, Map m, String s) { return x.length + m.length + s.length; }
Future<List> run(Map input, Map event, Function call) async { return []; }
'''),
      },
    });
    // Whatever it throws is the point of it.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {}
}
