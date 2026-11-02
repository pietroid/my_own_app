import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_own_app/app/app.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/assistant/assistant.dart';
import 'package:my_own_app/auth_token_provider.dart';
import 'package:my_own_app/bootstrap.dart';
import 'package:my_own_app/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Off without a key: dev builds, CI and tests send nothing.
  final analytics = kPostHogKey.isEmpty
      ? const NoAnalytics()
      : await PostHogAnalytics.start(key: kPostHogKey, host: kPostHogHost);

  final authRepository = BetterAuthRepository(
    apiBaseUrl: kApiBaseUrl,
    // The web build signs in through the redirect and needs no client id.
    // iOS reads its own from the reversed URL scheme in Info.plist when this
    // is null, but naming it here is what lets one build serve both flavors.
    googleClientId: kIsWeb ? null : nullIfEmpty(kGoogleIosClientId),
    // The ID token is minted for the web client, which is the one the
    // server always accepts.
    googleServerClientId: kIsWeb ? null : nullIfEmpty(kGoogleWebClientId),
  );
  final apiClient = ApiClient(
    baseUrl: kApiBaseUrl,
    tokenProvider: AuthTokenProvider(authRepository),
    // A 5xx is the server's failure, which the person saw; a dropped
    // network is not.
    onServerError: (error) => unawaited(
      analytics.captureException(
        error,
        stackTrace: error.stackTrace,
        properties: {
          'method': error.requestOptions.method,
          'path': error.requestOptions.path,
          'status': error.response?.statusCode ?? 0,
        },
      ),
    ),
  );

  final initialUser = await authRepository.restore();
  final initialLocation = initialUser == null ? '/auth' : '/';

  await bootstrap(
    () => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => authRepository),
        RepositoryProvider<AssistantRepository>(
          create: (_) => AssistantRepository(apiClient: apiClient),
        ),
        RepositoryProvider<AppsRepository>(
          create: (_) => AppsRepository(apiClient: apiClient),
        ),
      ],
      child: BlocProvider<AppBloc>(
        create: (_) => AppBloc(
          authRepository: authRepository,
          initialUser: initialUser,
          analytics: analytics,
        ),
        child: AnalyticsScope(
          analytics: analytics,
          child: App(initialLocation: initialLocation, analytics: analytics),
        ),
      ),
    ),
    analytics: analytics,
  );
}
