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
