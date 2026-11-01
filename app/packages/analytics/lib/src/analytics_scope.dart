import 'package:analytics/src/analytics.dart';
import 'package:flutter/widgets.dart';

/// {@template analytics_scope}
/// Hands [analytics] to the widgets below.
///
/// Read through [AnalyticsScope.of], which answers [NoAnalytics] where there
/// is no scope, so a page built in a test needs none.
/// {@endtemplate}
class AnalyticsScope extends InheritedWidget {
  /// {@macro analytics_scope}
  const AnalyticsScope({
    required this.analytics,
    required super.child,
    super.key,
  });

  /// What the widgets below report through.
  final Analytics analytics;

  /// The nearest scope's [Analytics], or [NoAnalytics].
  static Analytics of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AnalyticsScope>()?.analytics ??
      const NoAnalytics();

  @override
  bool updateShouldNotify(AnalyticsScope oldWidget) =>
      analytics != oldWidget.analytics;
}
