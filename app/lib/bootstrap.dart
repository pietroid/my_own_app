import 'dart:async';
import 'dart:developer';

import 'package:analytics/analytics.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver({this.analytics = const NoAnalytics()});

  /// Where an error a bloc threw is reported.
  final Analytics analytics;

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    log('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    unawaited(
      analytics.captureException(
        error,
        stackTrace: stackTrace,
        properties: {'bloc': '${bloc.runtimeType}'},
      ),
    );
    super.onError(bloc, error, stackTrace);
  }
}

Future<void> bootstrap(
  FutureOr<Widget> Function() builder, {
  Analytics analytics = const NoAnalytics(),
}) async {
  // PostHog, when it is on, has put its own handler here already; the log
  // goes in front of it rather than in its place.
  final reported = FlutterError.onError;
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
    if (reported != FlutterError.presentError) reported?.call(details);
  };

  Bloc.observer = AppBlocObserver(analytics: analytics);

  // Add cross-flavor configuration here

  runApp(await builder());
}
