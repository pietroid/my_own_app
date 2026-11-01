import 'package:analytics/analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recording extends NoAnalytics {
  const _Recording();
}

void main() {
  group('NoAnalytics', () {
    test('wraps nothing and observes nothing', () {
      const child = SizedBox();
      const analytics = NoAnalytics();

      expect(analytics.wrap(child), same(child));
      expect(analytics.navigatorObservers, isEmpty);
    });

    test('sends nothing, and never fails', () async {
      const analytics = NoAnalytics();

      await analytics.identify('user-1', properties: {'app': 'test'});
      await analytics.screen('Home');
      await analytics.captureException(StateError('x'));
      await analytics.reset();
    });
  });

  group('AnalyticsScope', () {
    testWidgets('answers NoAnalytics without a scope', (tester) async {
      late Analytics found;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            found = AnalyticsScope.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(found, isA<NoAnalytics>());
    });

    testWidgets('answers the scope’s analytics', (tester) async {
      const analytics = _Recording();
      late Analytics found;
      await tester.pumpWidget(
        AnalyticsScope(
          analytics: analytics,
          child: Builder(
            builder: (context) {
              found = AnalyticsScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(found, same(analytics));
    });
  });
}
