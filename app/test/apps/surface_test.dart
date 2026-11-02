import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_own_app/apps/app_renderer.dart';
import 'package:my_own_app/apps/apps_repository.dart';

class _MockRepository extends Mock implements AppsRepository {}

/// An app with one line of text, [form] for its frame.
AppSnapshot _app(String id, String text, {AppForm form = AppForm.mobile}) =>
    AppSnapshot(
      id: id,
      name: 'App $id',
      form: form,
      ui: [
        const {
          'id': 'root',
          'component': 'Column',
          'children': ['line'],
        },
        {'id': 'line', 'component': 'Text', 'text': text},
      ],
      data: const {},
    );

/// The editor: a Surface of the app at /editing.
const List<Map<String, dynamic>> _host = [
  {
    'id': 'root',
    'component': 'Surface',
    'app': {'path': '/editing'},
    'version': {'path': '/viewing'},
    'picking': {'path': '/picking'},
    'selected': {'path': '/picked'},
    'action': {
      'event': {'name': 'pick'},
    },
  },
];

void main() {
  late _MockRepository repository;
  final fired = <(String, Map<String, Object?>)>[];

  setUp(() {
    fired.clear();
    repository = _MockRepository();
    when(() => repository.get('a')).thenAnswer((_) async => _app('a', 'Olá'));
    when(
      () => repository.get('w'),
    ).thenAnswer((_) async => _app('w', 'Loja', form: AppForm.web));
    when(
      () => repository.version('a', 1),
    ).thenAnswer((_) async => _app('a', 'Antes'));
  });

  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> data, {
    List<Map<String, dynamic>> ui = _host,
  }) async {
    await tester.pumpWidget(
      RepositoryProvider<AppsRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.current,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // As the run page does: the screen scrolls.
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppRenderer(
                ui: ui,
                data: data,
                onAction: (name, event) => fired.add((name, event)),
                onEdit: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('draws another app, live, in a phone', (tester) async {
    await pump(tester, {'editing': 'a', 'picking': false});
    expect(find.text('Olá'), findsOneWidget);
    expect(find.byType(AppPhoneFrame), findsOneWidget);
    verify(() => repository.get('a')).called(1);
  });

  testWidgets('a web app goes in a browser window', (tester) async {
    await pump(tester, {'editing': 'w'});
    expect(find.text('Loja'), findsOneWidget);
    expect(find.byType(AppBrowserFrame), findsOneWidget);
  });

  testWidgets('shows a version, read-only, when asked', (tester) async {
    await pump(tester, {'editing': 'a', 'viewing': 1});
    expect(find.text('Antes'), findsOneWidget);
    verifyNever(() => repository.get('a'));
  });

  testWidgets('picking: a tap fires the host action with the component', (
    tester,
  ) async {
    await pump(tester, {'editing': 'a', 'picking': true, 'picked': ''});
    await tester.tap(find.text('Olá'), warnIfMissed: false);
    expect(fired.single.$1, 'pick');
    expect(fired.single.$2, {'componentId': 'line'});
  });

  testWidgets('an app drawn in itself draws its own Surface as a placeholder', (
    tester,
  ) async {
    const self = [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['title', 'inner'],
      },
      {'id': 'title', 'component': 'Text', 'text': 'Editor'},
      {
        'id': 'inner',
        'component': 'Surface',
        'app': {'path': '/editing'},
      },
    ];
    when(() => repository.get('e')).thenAnswer(
      (_) async => const AppSnapshot(
        id: 'e',
        name: 'Editor',
        ui: self,
        data: {'editing': 'e'},
      ),
    );
    await pump(tester, {'editing': 'e'}, ui: self);
    // The host's title, and the one in the Surface; no third.
    expect(find.text('Editor'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
