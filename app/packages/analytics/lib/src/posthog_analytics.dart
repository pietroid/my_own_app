import 'package:analytics/src/analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// {@template posthog_analytics}
/// [Analytics] over PostHog: the only place the app calls the plugin.
///
/// Replays mask every text, every image and everything custom-painted, so a
/// title or a note never leaves the device; there are no heatmaps.
/// {@endtemplate}
class PostHogAnalytics extends Analytics {
  PostHogAnalytics._();

  /// {@macro posthog_analytics}
  ///
  /// Sets PostHog up with the project [key] on [host]. On the web the
  /// posthog-js snippet in `web/index.html` does the setup, and this only
  /// turns on the capture of Flutter's errors.
  static Future<PostHogAnalytics> start({
    required String key,
    required String host,
  }) async {
    final config = PostHogConfig(key)
      ..host = host
      ..debug = kDebugMode
      ..captureApplicationLifecycleEvents = true
      ..personProfiles = PostHogPersonProfiles.identifiedOnly
      ..surveys = false
      ..sessionReplay = true
      ..sessionReplayConfig.maskAllTexts = true
      ..sessionReplayConfig.maskAllImages = true
      ..sessionReplayConfig.maskCustomPaint = true
      ..errorTrackingConfig.captureFlutterErrors = true
      ..errorTrackingConfig.capturePlatformDispatcherErrors = true
      ..errorTrackingConfig.captureNativeExceptions = true;
    await Posthog().setup(config);
    return PostHogAnalytics._();
  }

  final _posthog = Posthog();

  @override
  Future<void> identify(String userId, {Map<String, Object>? properties}) =>
      _posthog.identify(userId: userId, userProperties: properties);

  @override
  Future<void> reset() => _posthog.reset();

  @override
  Future<void> screen(String name) => _posthog.screen(screenName: name);

  @override
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) => _posthog.captureException(
    error: error,
    stackTrace: stackTrace,
    properties: properties,
  );

  @override
  List<NavigatorObserver> get navigatorObservers => [PosthogObserver()];

  @override
  Widget wrap(Widget child) => PostHogWidget(child: child);
}
