@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_app/apps/client_runner.dart';

void main() {
  final runner = ClientRunner();

  Future<List<dynamic>> noCall(String _, Map<String, Object?> _) async =>
      throw StateError('no call');

  test('runs the code and answers with its patch', () async {
    final calls = <String>[];
    final patch = await runner.run(
      code:
          'async function run(input, event, call) {'
          ' const d = await call("add_todo", {title: input["/draft"]});'
          ' return [{op: "replace", path: "/n", value: d.length + event.k}]; }',
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

  test('each run gets a Worker of its own, even back to back', () async {
    runner.warm();
    const code =
        'function run() { const seen = self.seen === 1; self.seen = 1;'
        ' return [seen]; }';
    final patches = await Future.wait([
      for (var i = 0; i < 3; i++)
        runner.run(
          code: code,
          input: const {},
          event: const {},
          call: noCall,
        ),
    ]);
    final next = await runner.run(
      code: code,
      input: const {},
      event: const {},
      call: noCall,
    );
    expect([...patches, next], List.filled(4, [false]));
  });

  test('a closed runner runs nothing', () async {
    final closed = ClientRunner()
      ..warm()
      ..close();
    await expectLater(
      closed.run(
        code: 'function run() { return []; }',
        input: const {},
        event: const {},
        call: noCall,
      ),
      throwsA(isA<ClientActionFailed>()),
    );
  });

  test('has no network', () async {
    final patch = await runner.run(
      code:
          'function run() { return [typeof fetch, typeof XMLHttpRequest,'
          ' typeof WebSocket, typeof importScripts]; }',
      input: const {},
      event: const {},
      call: noCall,
    );
    expect(patch, ['undefined', 'undefined', 'undefined', 'undefined']);
  });

  test('runs with an opaque origin, so no cookie can go with it', () async {
    final patch = await runner.run(
      code: 'function run() { return [self.origin]; }',
      input: const {},
      event: const {},
      call: noCall,
    );
    expect(patch, ['null']);
  });

  test('a throw fails the action', () async {
    await expectLater(
      runner.run(
        code: 'function run() { throw new Error("no"); }',
        input: const {},
        event: const {},
        call: noCall,
      ),
      throwsA(isA<ClientActionFailed>()),
    );
  });

  test("a failed server call fails it with the server's error", () async {
    final error = StateError('409');
    await expectLater(
      runner.run(
        code: 'async function run(i, e, call) { await call("x", {}); }',
        input: const {},
        event: const {},
        call: (_, _) async => throw error,
      ),
      throwsA(same(error)),
    );
  });
}
