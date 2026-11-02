import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/app/app.dart';
import 'package:my_own_app/apps/app_run_page.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/assistant/assistant.dart';
import 'package:my_own_app/home/home_page.dart';

/// A standalone entry point that draws the app's screens against fixed data,
/// with no backend and no login. Nothing ships from here.
///
/// `?s=<n>` picks the scene, as `.tool/preview` shoots them:
///
/// 1. the home, signed in;
/// 2. the assistant, mid-conversation;
/// 3. the sign-in;
/// 4. a built app running: a to-do list.
///
/// A feature's mockup (`/create`) copies this shape into
/// `lib/<slug>_preview.dart`: each scene seeds its state directly rather
/// than replaying taps.
void main() {
  final scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;
  runApp(_PreviewApp(scene: scene));
}

const _ana = AppUser(
  id: 'preview',
  name: 'Ana Souza',
  email: 'ana@exemplo.com',
);

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({required this.scene});

  final int scene;

  @override
  Widget build(BuildContext context) {
    final auth = _FakeAuthRepository();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: auth),
        RepositoryProvider<AssistantRepository>.value(
          value: _FakeAssistantRepository(),
        ),
        RepositoryProvider<AppsRepository>.value(value: _FakeAppsRepository()),
      ],
      child: BlocProvider(
        create: (_) => AppBloc(authRepository: auth, initialUser: _ana),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: switch (scene) {
            2 => BlocProvider(
              create: (context) {
                final cubit = AssistantCubit(
                  repository: context.read<AssistantRepository>(),
                );
                unawaited(cubit.send('O que você consegue fazer?'));
                return cubit;
              },
              child: const AssistantView(),
            ),
            3 => AuthScreen(authRepository: auth),
            4 => const AppRunPage(id: 'tarefas'),
            _ => const HomePage(),
          },
        ),
      ),
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AppUser?> get user => const Stream.empty();

  @override
  AppUser? get currentUser => _ana;

  @override
  Future<String?> token() async => null;

  @override
  Future<AppUser?> restore() async => _ana;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeAssistantRepository implements AssistantRepository {
  @override
  Future<String> reply(List<AssistantMessage> messages) async =>
      'Por enquanto, converso. Quando o app crescer, '
      'vou poder fazer mais por você.';
}

class _FakeAppsRepository implements AppsRepository {
  static const _todo = AppSnapshot(
    id: 'tarefas',
    name: 'Tarefas',
    ui: [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['form', 'list'],
      },
      {
        'id': 'form',
        'component': 'Row',
        'children': ['field', 'add'],
      },
      {
        'id': 'field',
        'component': 'TextField',
        'label': 'Nova tarefa',
        'value': {'path': '/draft'},
      },
      {
        'id': 'add',
        'component': 'Button',
        'label': 'Adicionar',
        'action': {
          'event': {'name': 'add_todo'},
        },
      },
      {
        'id': 'list',
        'component': 'List',
        'children': {'componentId': 'item', 'path': '/todos'},
      },
      {
        'id': 'item',
        'component': 'CheckBox',
        'label': {'path': 'title'},
        'value': {'path': 'done'},
        'action': {
          'event': {'name': 'toggle_todo'},
        },
      },
    ],
    data: {
      'draft': '',
      'todos': [
        {'title': 'Comprar pão', 'done': true},
        {'title': 'Pagar a conta de luz', 'done': false},
        {'title': 'Ligar para a Bia', 'done': false},
      ],
    },
  );

  @override
  Future<List<AppSummary>> list() async => [
    const AppSummary(id: 'tarefas', name: 'Tarefas'),
  ];

  @override
  Future<AppSnapshot> get(String id) async => _todo;

  @override
  Future<AppSnapshot> create(String prompt) async => _todo;

  @override
  Future<AppHistory> history(String id) async => const AppHistory(
    current: 2,
    versions: [
      AppVersion(n: 1, prompt: 'Uma lista de tarefas', reply: ''),
      AppVersion(
        n: 2,
        prompt: 'Coloque um título no topo',
        reply: 'Pronto: o título "Minhas tarefas" está no topo.',
        changes: AppChanges(components: ['root', 'title']),
      ),
    ],
  );

  @override
  Future<AppSnapshot> version(String id, int n) async => _todo;

  @override
  Future<AppEdit> send(String id, String prompt, {String? focus}) async =>
      AppEdit(
        version: AppVersion(n: 3, prompt: prompt, reply: 'Feito.'),
        app: _todo,
      );

  @override
  Future<AppEdit> restore(String id, int n) async => AppEdit(
    version: AppVersion(
      n: 3,
      prompt: '',
      reply: '',
      changes: AppChanges(restoredFrom: n),
    ),
    app: _todo,
  );

  @override
  Future<List<dynamic>> act(
    String id,
    String action,
    Map<String, Object?> event,
  ) async => const [];
}
