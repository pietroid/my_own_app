import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:auth/auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_own_app/app/app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _RecordingAnalytics extends Analytics {
  final calls = <String>[];

  @override
  Future<void> identify(
    String userId, {
    Map<String, Object>? properties,
  }) async => calls.add('identify $userId $properties');

  @override
  Future<void> reset() async => calls.add('reset');

  @override
  Future<void> screen(String name) async {}

  @override
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) async {}

  @override
  List<NavigatorObserver> get navigatorObservers => const [];

  @override
  Widget wrap(Widget child) => child;
}

void main() {
  group('AppBloc analytics', () {
    late StreamController<AppUser?> users;
    late _MockAuthRepository auth;
    late _RecordingAnalytics analytics;

    const ana = AppUser(id: 'user-1', name: 'Ana', email: 'ana@exemplo.com');

    setUp(() {
      users = StreamController<AppUser?>();
      auth = _MockAuthRepository();
      when(() => auth.user).thenAnswer((_) => users.stream);
      analytics = _RecordingAnalytics();
    });

    tearDown(() => users.close());

    test('identifies the restored account by its id', () async {
      final bloc = AppBloc(
        authRepository: auth,
        initialUser: ana,
        analytics: analytics,
      );
      await pumpEventQueue();

      expect(analytics.calls, ['identify user-1 null']);
      await bloc.close();
    });

    test('identifies on sign-in, once, and resets on sign-out', () async {
      final bloc = AppBloc(authRepository: auth, analytics: analytics);

      users
        ..add(ana)
        ..add(ana)
        ..add(null);
      await pumpEventQueue();

      expect(analytics.calls, [
        'identify user-1 null',
        'reset',
      ]);
      await bloc.close();
    });

    test('never sends the name or the email', () async {
      final bloc = AppBloc(authRepository: auth, analytics: analytics);

      users.add(ana);
      await pumpEventQueue();

      expect(analytics.calls.join(), isNot(contains('Ana')));
      expect(analytics.calls.join(), isNot(contains('@')));
      await bloc.close();
    });
  });
}
