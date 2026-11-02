import 'dart:convert';

import 'package:action_runner/compile.dart';
import 'package:action_runner/run.dart';
import 'package:test/test.dart';

Future<String> _noCall(String _, String _) async => throw StateError('no call');

Future<Object?> _run(
  String code, {
  Map<String, Object?> input = const {},
  Map<String, Object?> event = const {},
  HostCall call = _noCall,
  int stepLimit = defaultStepLimit,
}) async => jsonDecode(
  await runAction(
    compileAction(code),
    input: jsonEncode(input),
    event: jsonEncode(event),
    call: call,
    stepLimit: stepLimit,
  ),
);

void main() {
  test('runs the code and answers with its patch', () async {
    expect(
      await _run(
        '''
Future<List> run(Map input, Map event, Function call) async {
  final todos = input['/todos'] as List;
  return [
    {'op': 'add', 'path': '/todos/-', 'value': {'title': event['title'], 'done': false}},
    {'op': 'replace', 'path': '/count', 'value': todos.length + 1},
  ];
}
''',
        input: {
          '/todos': [1, 2],
        },
        event: {'title': 'Pão'},
      ),
      [
        {
          'op': 'add',
          'path': '/todos/-',
          'value': {'title': 'Pão', 'done': false},
        },
        {'op': 'replace', 'path': '/count', 'value': 3},
      ],
    );
  });

  test('awaits a server call', () async {
    final calls = <String>[];
    final patch = await _run(
      '''
Future<List> run(Map input, Map event, Function call) async {
  final kept = await call('add_todo', {'title': input['/draft']});
  return [{'op': 'replace', 'path': '/n', 'value': kept.length + (event['k'] as int)}];
}
''',
      input: {'/draft': 'Pão'},
      event: {'k': 1},
      call: (action, event) async {
        calls.add('$action ${(jsonDecode(event) as Map)['title']}');
        return jsonEncode([
          {'op': 'add', 'path': '/todos/-', 'value': 1},
        ]);
      },
    );
    expect(calls, ['add_todo Pão']);
    expect(patch, [
      {'op': 'replace', 'path': '/n', 'value': 2},
    ]);
  });

  test("a failed server call fails it with the server's error", () async {
    final error = StateError('409');
    await expectLater(
      _run(
        '''
Future<List> run(Map input, Map event, Function call) async {
  await call('x', {});
  return [];
}
''',
        call: (_, _) async => throw error,
      ),
      throwsA(same(error)),
    );
  });

  test('a throw fails the action', () async {
    await expectLater(
      _run(
        'Future<List> run(Map i, Map e, Function c) async {'
        " throw Exception('no'); }",
      ),
      throwsA(isA<ActionRunError>()),
    );
  });

  test('a loop that never ends is stopped, and cannot catch it', () async {
    await expectLater(
      _run('''
Future<List> run(Map i, Map e, Function c) async {
  var n = 0;
  while (true) {
    try { n++; } catch (_) {}
  }
}
''', stepLimit: 100000),
      throwsA(
        isA<ActionRunError>().having((e) => e.tooLong, 'tooLong', isTrue),
      ),
    );
  });

  test('has no files, network or processes', () async {
    await expectLater(
      _run('''
import 'dart:io';
Future<List> run(Map i, Map e, Function c) async {
  await File('/etc/hosts').readAsString();
  return [];
}
'''),
      throwsA(isA<ActionRunError>()),
    );
  });

  test('a compile error says why', () {
    expect(
      () => compileAction('List run(Map i, Map e, Function c) { return [; }'),
      throwsA(isA<ActionCompileError>()),
    );
  });
}
