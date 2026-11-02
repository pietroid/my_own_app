import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/apps/studio_cubit.dart';

class _MockRepository extends Mock implements AppsRepository {}

AppSnapshot _app(int version, String label) => AppSnapshot(
  id: 'a',
  name: 'Tarefas',
  ui: [
    const {
      'id': 'root',
      'component': 'Column',
      'children': ['add'],
    },
    {'id': 'add', 'component': 'Button', 'label': label},
  ],
  data: const {},
  version: version,
);

const _history = AppHistory(
  current: 1,
  versions: [AppVersion(n: 1, prompt: 'Uma lista de tarefas', reply: '')],
);

void main() {
  late _MockRepository repository;
  late List<AppSnapshot> shown;
  late StudioCubit cubit;

  setUp(() {
    repository = _MockRepository();
    shown = [];
    cubit = StudioCubit(repository: repository, id: 'a', onApp: shown.add);
    when(() => repository.history('a')).thenAnswer((_) async => _history);
  });

  tearDown(() => cubit.close());

  test('loads the conversation', () async {
    await cubit.load();
    expect(cubit.state.versions, _history.versions);
    expect(cubit.state.current, 1);
  });

  test('a request about the picked component makes a new version', () async {
    final edit = AppEdit(
      version: const AppVersion(
        n: 2,
        prompt: 'Mude o texto',
        reply: 'Mudei.',
        changes: AppChanges(components: ['add']),
      ),
      app: _app(2, 'Nova tarefa'),
    );
    when(
      () => repository.send('a', 'Mude o texto', focus: 'add'),
    ).thenAnswer((_) async => edit);
    await cubit.load();
    cubit
      ..select('add')
      ..focus('add');
    expect(cubit.state.selecting, isTrue);

    final sending = cubit.send('  Mude o texto ');
    expect(cubit.state.pending, 'Mude o texto');
    await sending;

    expect(shown, [edit.app]);
    expect(cubit.state.versions.last, edit.version);
    expect(cubit.state.current, 2);
    expect(cubit.state.sending, isFalse);
    expect(cubit.state.focusId, isNull);
    // Still there, so still picked.
    expect(cubit.state.selectedId, 'add');
  });

  test("says the server's words when a request fails", () async {
    when(() => repository.send('a', 'x')).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 422,
          data: {'message': 'Não consegui fazer isso.'},
        ),
      ),
    );
    await cubit.send('x');
    expect(cubit.state.sendFailed, isTrue);
    expect(cubit.state.error, 'Não consegui fazer isso.');
    expect(shown, isEmpty);
  });

  test('looks at an earlier version and brings it back', () async {
    final old = _app(1, 'Adicionar');
    when(() => repository.version('a', 1)).thenAnswer((_) async => old);
    final restored = AppEdit(
      version: const AppVersion(
        n: 3,
        prompt: '',
        reply: '',
        changes: AppChanges(restoredFrom: 1),
      ),
      app: _app(3, 'Adicionar'),
    );
    when(() => repository.restore('a', 1)).thenAnswer((_) async => restored);
    when(() => repository.history('a')).thenAnswer(
      (_) async => const AppHistory(
        current: 2,
        versions: [
          AppVersion(n: 1, prompt: 'Uma lista de tarefas', reply: ''),
          AppVersion(n: 2, prompt: 'Mude o texto', reply: 'Mudei.'),
        ],
      ),
    );
    await cubit.load();

    await cubit.view(1);
    expect(cubit.state.viewing, 1);
    expect(cubit.state.viewed, old);

    await cubit.restore();
    expect(cubit.state.viewing, isNull);
    expect(cubit.state.current, 3);
    expect(shown, [restored.app]);
  });

  test('the current version is the app itself', () async {
    await cubit.load();
    await cubit.view(1);
    expect(cubit.state.viewing, isNull);
    verifyNever(() => repository.version(any(), any()));
  });
}
