import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_own_app/app/app.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/home/home_page.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAppsRepository extends Mock implements AppsRepository {}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('greets the person by first name and signs them out', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final users = StreamController<AppUser?>();
    addTearDown(users.close);
    when(() => auth.user).thenAnswer((_) => users.stream);
    when(auth.signOut).thenAnswer((_) async {});
    final apps = _MockAppsRepository();
    when(apps.list).thenAnswer(
      (_) async => [const AppSummary(id: 'a', name: 'Tarefas')],
    );

    await tester.pumpWidget(
      RepositoryProvider<AppsRepository>.value(
        value: apps,
        child: BlocProvider(
          create: (_) => AppBloc(
            authRepository: auth,
            initialUser: const AppUser(id: 'user-1', name: 'Ana Souza'),
          ),
          child: const MaterialApp(
            locale: Locale('pt', 'BR'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomePage(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Olá, Ana'), findsOneWidget);
    expect(find.text('Tarefas'), findsOneWidget);
    expect(find.text('Criar app'), findsOneWidget);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pump();

    verify(auth.signOut).called(1);
  });
}
