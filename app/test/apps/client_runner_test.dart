import 'dart:convert';

import 'package:action_runner/compile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_app/apps/client_runner.dart';

// The device never compiles; the tests do, as the server would.
String _evc(String code) => base64Encode(compileAction(code));

void main() {
  final runner = ClientRunner();

  Future<List<dynamic>> noCall(String _, Map<String, Object?> _) async =>
      throw StateError('no call');

  test('runs the code and answers with its patch', () async {
    final calls = <String>[];
    final patch = await runner.run(
      evc: _evc('''
Future<List> run(Map input, Map event, Function call) async {
  final List kept = await call('add_todo', {'title': input['/draft']});
  return [{'op': 'replace', 'path': '/n', 'value': kept.length + (event['k'] as int)}];
}
'''),
      input: {'/draft': 'Pão'},
      event: {'k': 1},
      call: (action, event) async {
        calls.add('$action ${event['title']}');
        return [
          {'op': 'add', 'path': '/todos/-', 'value': 1},
        ];
      },
    );
    expect(calls, ['add_todo Pão']);
    expect(patch, [
      {'op': 'replace', 'path': '/n', 'value': 2},
    ]);
  });

  test('a throw fails the action', () async {
    await expectLater(
      runner.run(
        evc: _evc(
          'Future<List> run(Map i, Map e, Function c) async {'
          " throw Exception('no'); }",
        ),
        input: const {},
        event: const {},
        call: noCall,
      ),
      throwsA(isA<ClientActionFailed>()),
    );
  });

  test('a loop that never ends stops instead of freezing', () async {
    await expectLater(
      runner.run(
        evc: _evc(
          'Future<List> run(Map i, Map e, Function c) async {'
          ' while (true) {} }',
        ),
        input: const {},
        event: const {},
        call: noCall,
      ),
      throwsA(isA<ClientActionFailed>()),
    );
  });

  test('bytecode it cannot read fails the action', () async {
    for (final evc in ['AAAA', 'not base64!']) {
      await expectLater(
        runner.run(evc: evc, input: const {}, event: const {}, call: noCall),
        throwsA(isA<ClientActionFailed>()),
      );
    }
  });

  test("a failed server call fails it with the server's error", () async {
    final error = StateError('409');
    await expectLater(
      runner.run(
        evc: _evc('''
Future<List> run(Map i, Map e, Function call) async {
  await call('x', {});
  return [];
}
'''),
        input: const {},
        event: const {},
        call: (_, _) async => throw error,
      ),
      throwsA(same(error)),
    );
  });
}
