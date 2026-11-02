import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_own_app/apps/apps_cubit.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/apps/client_runner.dart';

class _MockRepository extends Mock implements AppsRepository {}

/// Stands in for the Worker: does what the to-do's client `add` does.
class _FakeRunner implements ClientRunner {
  Map<String, Object?>? input;

  @override
  Future<List<dynamic>> run({
    required String code,
    required Map<String, Object?> input,
    required Map<String, Object?> event,
    required ServerCall call,
  }) async {
    this.input = input;
    await call('add_todo', {'title': input['/draft']});
    return [
      {'op': 'replace', 'path': '/draft', 'value': ''},
    ];
  }

  @override
  void warm() {}

  @override
  void close() {}
}

const _app = AppSnapshot(
  id: 'a',
  name: 'Tarefas',
  ui: [],
  data: {'draft': '', 'todos': <Object?>[]},
  clientActions: {
    'add': ClientAction(input: ['/draft'], code: 'async function run() {}'),
  },
);

void main() {
  late _MockRepository repository;
  late _FakeRunner runner;

  setUp(() {
    repository = _MockRepository();
    runner = _FakeRunner();
    when(() => repository.get('a')).thenAnswer((_) async => _app);
  });

  test('a client action calls a server one, then patches the screen', () async {
    when(() => repository.act('a', 'add_todo', {'title': 'Pão'})).thenAnswer(
      (_) async => [
        {
          'op': 'add',
          'path': '/todos/-',
          'value': {'title': 'Pão', 'done': false},
        },
      ],
    );
    final cubit = AppRunCubit(repository: repository, id: 'a', runner: runner);
    await cubit.load();
    cubit.edit('/draft', 'Pão');

    await cubit.act('add', const {});

    expect(runner.input, {'/draft': 'Pão'});
    expect(cubit.state.app!.data, {
      'draft': '',
      'todos': [
        {'title': 'Pão', 'done': false},
      ],
    });
    expect(cubit.state.error, isNull);
  });

  test('a server action goes straight to the server', () async {
    when(() => repository.act('a', 'clear', const {})).thenAnswer(
      (_) async => [
        {'op': 'replace', 'path': '/draft', 'value': 'x'},
      ],
    );
    final cubit = AppRunCubit(repository: repository, id: 'a', runner: runner);
    await cubit.load();

    await cubit.act('clear', const {});

    expect(cubit.state.app!.data['draft'], 'x');
    expect(runner.input, isNull);
  });

  test('a client action that cannot run says so', () async {
    final cubit = AppRunCubit(
      repository: repository,
      id: 'a',
      runner: ClientRunner(),
    );
    await cubit.load();

    await cubit.act('add', const {});

    expect(cubit.state.error, '');
  });
}
