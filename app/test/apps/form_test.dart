import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_app/apps/apps_repository.dart';

void main() {
  test('reads the form, a phone when the server says none', () {
    final web = AppSnapshot.fromJson(const {
      'id': 'a',
      'name': 'Loja',
      'ui': <dynamic>[],
      'data': <String, dynamic>{},
      'form': 'web',
    });
    expect(web.form, AppForm.web);
    expect(web.withData(const {}).form, AppForm.web);
    expect(AppForm.of(null), AppForm.mobile);
    expect(AppChanges.fromJson(const {'form': 'web'}).form, AppForm.web);
    expect(AppChanges.fromJson(const {'form': 'web'}).any, isTrue);
  });

  testWidgets('a browser window lays its page out wide, scaled to fit', (
    tester,
  ) async {
    Size? laidOut;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 640,
          height: 420,
          child: AppBrowserFrame(
            address: 'Loja',
            child: Builder(
              builder: (context) {
                laidOut = MediaQuery.sizeOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    expect(laidOut, AppBrowserFrame.screen);
    expect(find.text('Loja'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
