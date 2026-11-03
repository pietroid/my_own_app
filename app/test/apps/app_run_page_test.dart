import 'package:api_client/api_client.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_own_app/apps/app_run_page.dart';
import 'package:my_own_app/apps/apps_repository.dart';

class _MockRepository extends Mock implements AppsRepository {}

const _todo = AppSnapshot(
  id: 'a',
  name: 'Tarefas',
  ui: [
    {'id': 'root', 'component': 'Text', 'text': 'Minhas tarefas'},
  ],
  data: {},
);

const _editor = AppSnapshot(
  id: 'e',
  name: 'My Own App Editor',
  ui: [
    {'id': 'root', 'component': 'Text', 'text': 'O editor'},
  ],
  data: {},
);

void main() {
  late _MockRepository repository;

  setUp(() {
    repository = _MockRepository();
    when(() => repository.get('a')).thenAnswer((_) async => _todo);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider<AppsRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.current,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppRunPage(id: 'a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens the app in the editor', (tester) async {
    when(repository.editor).thenAnswer((_) async => _editor);
    await open(tester);
    expect(find.text('O editor'), findsOneWidget);
    expect(find.text('Minhas tarefas'), findsNothing);
  });

  testWidgets('runs the app on its own when the editor does not open, and '
      'brings the editor back', (tester) async {
    var broken = true;
    when(repository.editor).thenAnswer((_) async {
      if (broken) throw DioException(requestOptions: RequestOptions());
      return _editor;
    });
    when(repository.resetEditor).thenAnswer((_) async {
      broken = false;
      return const AppEdit(
        version: AppVersion(n: 2, prompt: '', reply: ''),
        app: _editor,
      );
    });
    await open(tester);
    expect(find.text('Minhas tarefas'), findsOneWidget);

    await tester.tap(find.text('Restaurar editor'));
    await tester.pumpAndSettle();
    expect(find.text('O editor'), findsOneWidget);
  });
}
