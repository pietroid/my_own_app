import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );

  testWidgets('calls back when tapped', (tester) async {
    var taps = 0;
    await pump(tester, AppButton(onPressed: () => taps++, text: 'Entrar'));

    await tester.tap(find.text('Entrar'));

    expect(taps, 1);
  });

  testWidgets('does nothing when disabled', (tester) async {
    await pump(tester, const AppButton(onPressed: null, text: 'Entrar'));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('draws an empty state with its action', (tester) async {
    await pump(
      tester,
      AppEmptyState(
        title: 'Nada aqui',
        body: 'Ainda.',
        action: AppButton(onPressed: () {}, text: 'Criar'),
      ),
    );

    expect(find.text('Nada aqui'), findsOneWidget);
    expect(find.text('Ainda.'), findsOneWidget);
    expect(find.text('Criar'), findsOneWidget);
  });
}
