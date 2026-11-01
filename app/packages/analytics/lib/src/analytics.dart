import 'package:flutter/widgets.dart';

/// {@template analytics}
/// Who is using the app, where they are in it, and what broke.
///
/// The person's actions are counted on the server, which sees every write;
/// the app tells only what the server cannot see: the person behind the
/// session, the screens, and the errors that never reached it.
/// {@endtemplate}
abstract class Analytics {
  /// {@macro analytics}
  const Analytics();

  /// Ties what follows to the account [userId], across devices.
  Future<void> identify(String userId, {Map<String, Object>? properties});

  /// Forgets the account: what follows is anonymous again.
  Future<void> reset();

  /// The person is looking at [name] (a tab, which is not a route).
  Future<void> screen(String name);

  /// Something failed that the person may have seen.
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  });

  /// What the router reports screens through.
  List<NavigatorObserver> get navigatorObservers;

  /// [child], wrapped so the session can be replayed.
  Widget wrap(Widget child);
}

/// {@template no_analytics}
/// Sends nothing: tests, previews, the demo, and any build without a key.
/// {@endtemplate}
class NoAnalytics extends Analytics {
  /// {@macro no_analytics}
  const NoAnalytics();

  @override
  Future<void> identify(
    String userId, {
    Map<String, Object>? properties,
  }) async {}

  @override
  Future<void> reset() async {}

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
