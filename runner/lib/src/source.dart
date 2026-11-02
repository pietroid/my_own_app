/// The library an action is compiled into (dart_eval keeps the functions
/// of files named `main.dart` as entry points), and the function the runner
/// calls in it.
const actionLibrary = 'package:app/main.dart';

/// See [actionLibrary].
const entryFunction = 'entry__';

/// One action's source, as the model wrote it, with the entry point the
/// runner calls around it.
///
/// The action is `Future<List> run(Map input, Map event, Function call)`
/// (always `async`), answering a JSON Patch; dart_eval will not `await` a value
/// that is not a `Future`. Values cross into and out
/// of the interpreter as JSON strings, so nothing but plain data does: the
/// entry point decodes them, and `call` is a closure here that turns the
/// host's string answers back into data.
String wrapAction(String code) =>
    '''
import 'dart:convert';

$code

Future<String> $entryFunction(String input, String event, Function host) async {
  Future<List> call(String name, Map event) async {
    final String answer = await host(name, jsonEncode(event));
    return jsonDecode(answer) as List;
  }

  final out = await run(jsonDecode(input) as Map, jsonDecode(event) as Map, call);
  return jsonEncode(out ?? []);
}
''';
