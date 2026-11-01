import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/app/app.dart';
import 'package:my_own_app/assistant/assistant.dart';
import 'package:my_own_app/home/home_page.dart';

/// A standalone entry point that draws the app's screens against fixed data,
/// with no backend and no login. Nothing ships from here.
///
/// `?s=<n>` picks the scene, as `.tool/preview` shoots them:
///
/// 1. the home, signed in;
/// 2. the assistant, mid-conversation;
/// 3. the sign-in.
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
