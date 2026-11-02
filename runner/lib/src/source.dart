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
/// host's string answers back into data: a patch from a saved action, or
/// whatever a platform call answers (`apps.list`: a list of apps).
String wrapAction(String code) =>
    '''
import 'dart:convert';

$code

Future<String> $entryFunction(String input, String event, Function host) async {
  // Untyped on purpose: dart_eval checks a closure's argument types against
  // the declared ones at the call, and a map built from data (`{'id':
  // event['id']}`) is not seen as a `Map`.
  Future call(dynamic name, dynamic event) async {
    final String answer = await host(name as String, jsonEncode(event));
    return jsonDecode(answer);
  }

  final out = await run(jsonDecode(input) as Map, jsonDecode(event) as Map, call);
  return jsonEncode(out ?? []);
}
''';
