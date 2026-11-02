import 'dart:async';
import 'dart:convert';

import 'package:action_runner/compile.dart';
import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_own_app/apps/apps_cubit.dart';
import 'package:my_own_app/apps/apps_repository.dart';

class _MockRepository extends Mock implements AppsRepository {}

// The device never compiles; the tests do, as the server would.
String _evc(String code) => base64Encode(compileAction(code));

final String _addTodo = _evc('''
Future<List> run(Map input, Map event, Function call) async {
  final title = (event['title'] as String? ?? '').trim();
  if (title.isEmpty) return [];
  return [
    {'op': 'add', 'path': '/todos/-', 'value': {'title': title, 'done': false}},
    {'op': 'replace', 'path': '/draft', 'value': ''},
  ];
}
''');

final String _filter = _evc('''
Future<List> run(Map input, Map event, Function call) async {
  final List kept = await call('add_todo', {'title': 'Leite'});
  return [{'op': 'replace', 'path': '/filter', 'value': kept.length}];
}
''');

final _app = AppSnapshot(
  id: 'a',
  name: 'Tarefas',
  ui: const [],
  data: const {'draft': '', 'filter': 0, 'todos': <Object?>[]},
  actions: {
    'add_todo': AppAction(input: const [], evc: _addTodo),
    'show': AppAction(input: const [], evc: _filter, saved: false),
    'old': const AppAction(input: [], evc: 'AAAA'),
    // Its bytecode would fail here: a platform action must never run here.
    'make': const AppAction(input: [], evc: 'AAAA', platform: true),
  },
);

List<Map<String, Object?>> _added(String title) => [
  {
    'op': 'add',
    'path': '/todos/-',
    'value': {'title': title, 'done': false},
  },
  {'op': 'replace', 'path': '/draft', 'value': ''},
];

List<Object?> _todos(AppRunCubit cubit) =>
    cubit.state.app!.data['todos'] as List<Object?>;

void main() {
  late _MockRepository repository;

  setUp(() {
    repository = _MockRepository();
    when(() => repository.get('a')).thenAnswer((_) async => _app);
  });

  Future<AppRunCubit> open() async {
    final cubit = AppRunCubit(repository: repository, id: 'a');
    await cubit.load();
    return cubit;
  }

  test('a saved action shows its patch before the server answers', () async {
    final answer = Completer<List<dynamic>>();
    when(
      () => repository.act('a', 'add_todo', {'title': 'Pão'}),
    ).thenAnswer((_) => answer.future);
    final cubit = await open();
    cubit.edit('/draft', 'Pão');

    await cubit.act('add_todo', {'title': 'Pão'});

    expect(_todos(cubit), [
      {'title': 'Pão', 'done': false},
    ]);
    expect(cubit.state.app!.data['draft'], '');

    // The server agrees: nothing is applied twice, nothing reloads.
    answer.complete(_added('Pão'));
    await pumpEventQueue();
    expect(_todos(cubit), hasLength(1));
    verify(() => repository.get('a')).called(1);
  });

  test('saved actions reach the server one at a time, in order', () async {
    final first = Completer<List<dynamic>>();
    final sent = <String>[];
    when(() => repository.act('a', 'add_todo', any())).thenAnswer((call) {
      final title = (call.positionalArguments[2] as Map)['title'] as String;
      sent.add(title);
      return title == 'Pão' ? first.future : Future.value(_added(title));
    });
    final cubit = await open();

    await cubit.act('add_todo', {'title': 'Pão'});
    await cubit.act('add_todo', {'title': 'Leite'});
    await pumpEventQueue();

    expect(_todos(cubit), hasLength(2));
    expect(sent, ['Pão']);
    first.complete(_added('Pão'));
    await pumpEventQueue();
    expect(sent, ['Pão', 'Leite']);
  });

  test("when the server's patch differs, its copy is loaded", () async {
    when(
      () => repository.act('a', 'add_todo', any()),
    ).thenAnswer((_) async => _added('Outro'));
    final cubit = await open();

    await cubit.act('add_todo', {'title': 'Pão'});
    await pumpEventQueue();

    verify(() => repository.get('a')).called(2);
    expect(_todos(cubit), isEmpty);
  });

  test('a refusal brings back the server copy and says why', () async {
    when(() => repository.act('a', 'add_todo', any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 409,
          data: {'message': 'O app mudou enquanto isso. Tente de novo.'},
        ),
      ),
    );
    final cubit = await open();

    await cubit.act('add_todo', {'title': 'Pão'});
    expect(_todos(cubit), hasLength(1));
    await pumpEventQueue();

    expect(_todos(cubit), isEmpty);
    expect(cubit.state.error, 'O app mudou enquanto isso. Tente de novo.');
  });

  test('a client action is not sent; the saved one it calls is', () async {
    when(
      () => repository.act('a', 'add_todo', {'title': 'Leite'}),
    ).thenAnswer((_) async => _added('Leite'));
    final cubit = await open();

    await cubit.act('show', const {});
    await pumpEventQueue();

    expect(cubit.state.app!.data['filter'], 2);
    expect(_todos(cubit), hasLength(1));
    verifyNever(() => repository.act('a', 'show', any()));
    verify(() => repository.act('a', 'add_todo', {'title': 'Leite'})).called(1);
  });

  test('an action this app cannot run waits for the server', () async {
    when(() => repository.act('a', 'old', const {})).thenAnswer(
      (_) async => [
        {'op': 'replace', 'path': '/draft', 'value': 'x'},
      ],
    );
    final cubit = await open();

    await cubit.act('old', const {});

    expect(cubit.state.app!.data['draft'], 'x');
    expect(cubit.state.error, isNull);
  });

  test('a platform action runs on the server only, and is pending until '
      'it answers', () async {
    final answer = Completer<List<dynamic>>();
    final idle = Completer<List<dynamic>>();
    when(
      () => repository.act('a', 'make', {'prompt': 'Loja'}),
    ).thenAnswer((_) => answer.future);
    when(
      () => repository.act('a', 'add_todo', {'title': 'Pão'}),
    ).thenAnswer((_) => idle.future);
    final cubit = await open();

    final making = cubit.act('make', {'prompt': 'Loja'});
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.pending, {
      'make': {'prompt': 'Loja'},
    });

    // Not queued behind it: another tap goes to the server meanwhile.
    await cubit.act('add_todo', {'title': 'Pão'});
    await Future<void>.delayed(Duration.zero);
    verify(() => repository.act('a', 'add_todo', {'title': 'Pão'})).called(1);
    expect(_todos(cubit), hasLength(1));

    answer.complete([
      {'op': 'replace', 'path': '/filter', 'value': 7},
    ]);
    await making;
    expect(cubit.state.pending, isEmpty);
    expect(cubit.state.app!.data['filter'], 7);
    expect(_todos(cubit), hasLength(1));
    await cubit.close();
  });

  test(
    'a refused platform action is no longer pending, and says why',
    () async {
      when(() => repository.act('a', 'make', any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(
            requestOptions: RequestOptions(),
            statusCode: 422,
            data: {'message': 'Descreva o app em poucas palavras.'},
          ),
        ),
      );
      final cubit = await open();
      await cubit.act('make', {'prompt': ''});
      expect(cubit.state.pending, isEmpty);
      expect(cubit.state.error, 'Descreva o app em poucas palavras.');
      await cubit.close();
    },
  );
}
