import 'package:analytics/analytics.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/app/app.dart';
import 'package:my_own_app/apps/app_run_page.dart';
import 'package:my_own_app/assistant/assistant.dart';
import 'package:my_own_app/home/home_page.dart';

/// {@template app}
/// The root widget: the router, the theme and the strings.
/// {@endtemplate}
class App extends StatelessWidget {
  /// {@macro app}
  ///
  /// Each route has a `name`, which is the screen PostHog reports.
  App({
    required String initialLocation,
    this.analytics = const NoAnalytics(),
    super.key,
  }) : _router = GoRouter(
         initialLocation: initialLocation,
         observers: analytics.navigatorObservers,
         routes: [
           GoRoute(
             path: '/',
             name: 'Home',
             builder: (context, state) => const HomePage(),
           ),
           GoRoute(
             path: '/assistente',
             name: 'Assistente',
             builder: (context, state) => const AssistantPage(),
           ),
           GoRoute(
             path: '/apps/:id',
             name: 'App',
             builder: (context, state) =>
                 AppRunPage(id: state.pathParameters['id']!),
           ),
           GoRoute(
             path: '/auth',
             name: 'Entrada',
             builder: (context, state) => AuthScreen(
               authRepository: context.read<AuthRepository>(),
               onAuthenticated: () => context.go('/'),
             ),
           ),
         ],
       );

  /// Where screens are reported, and what wraps the app for replays.
  final Analytics analytics;

  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) => _router.go(
        state.status == AppStatus.authenticated ? '/' : '/auth',
      ),
      child: analytics.wrap(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => context.l10n.appName,
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
        ),
      ),
    );
  }
}
