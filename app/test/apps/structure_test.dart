import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_app/apps/app_renderer.dart';

Map<String, dynamic> _act(String name) => {
  'event': {'name': name},
};

/// A real app's screen: a bar, a side navigation, two panes, and every
/// component that is mostly a box.
final _ui = <Map<String, dynamic>>[
  {
    'id': 'root',
    'component': 'Screen',
    'header': 'bar',
    'body': 'split',
    'footer': 'total',
    'nav': 'nav',
  },
  {
    'id': 'bar',
    'component': 'TopBar',
    'title': 'Finanças',
    'subtitle': 'Novembro',
    'leading': 'me',
    'trailing': ['more'],
  },
  {'id': 'me', 'component': 'Avatar', 'name': 'Ana Souza', 'size': 'sm'},
  {
    'id': 'more',
    'component': 'Button',
    'icon': 'more',
    'label': '',
    'action': _act('go'),
  },
  {
    'id': 'nav',
    'component': 'NavBar',
    'variant': 'side',
    'value': {'path': '/page'},
    'items': [
      {'label': 'Resumo', 'icon': 'chart', 'value': 'resumo'},
      {'label': 'Contas', 'icon': 'card', 'value': 'contas'},
    ],
  },
  {
    'id': 'split',
    'component': 'Split',
    'children': ['list', 'detail'],
  },
  {
    'id': 'list',
    'component': 'Panel',
    'title': 'Contas',
    'icon': 'card',
    'width': 'md',
    'children': ['search', 'rows', 'empty'],
  },
  {
    'id': 'search',
    'component': 'TextField',
    'label': 'Buscar',
    'variant': 'search',
    'value': {'path': '/q'},
  },
  {
    'id': 'rows',
    'component': 'List',
    'divided': true,
    'children': {'componentId': 'row', 'path': '/bills'},
  },
  {
    'id': 'row',
    'component': 'ListItem',
    'icon': 'money',
    'title': {'path': 'name'},
    'subtitle': 'Vence dia 10',
    'meta': {'path': 'value'},
    'chevron': true,
    'selected': {'path': 'open'},
    'trailing': ['paid'],
    'action': _act('open'),
  },
  {'id': 'paid', 'component': 'Badge', 'text': 'paga', 'tone': 'positive'},
  {
    'id': 'empty',
    'component': 'EmptyState',
    'icon': 'checkCircle',
    'title': 'Nenhuma conta',
    'visible': {'path': '/bills', 'is': <Object>[]},
  },
  {
    'id': 'detail',
    'component': 'Panel',
    'title': 'Resumo',
    'children': ['grid', 'note', 'goal', 'bubble', 'tabs'],
  },
  {
    'id': 'grid',
    'component': 'Grid',
    'columns': 2,
    'children': ['spent', 'left'],
  },
  {
    'id': 'spent',
    'component': 'Stat',
    'label': 'Gasto',
    'value': r'R$ 1.200',
    'caption': '+8%',
    'trend': 'up',
    'tone': 'negative',
  },
  {
    'id': 'left',
    'component': 'Stat',
    'label': 'Sobra',
    'value': r'R$ 300',
  },
  {
    'id': 'note',
    'component': 'Callout',
    'tone': 'warning',
    'title': 'Atenção',
    'text': 'Duas contas vencem amanhã.',
  },
  {
    'id': 'goal',
    'component': 'Progress',
    'label': 'Meta',
    'value': 0.4,
    'showValue': true,
  },
  {
    'id': 'bubble',
    'component': 'Box',
    'shape': 'bubbleStart',
    'direction': 'row',
    'children': ['bubbleText', 'push', 'tag'],
  },
  {'id': 'bubbleText', 'component': 'Text', 'text': 'Oi', 'variant': 'strong'},
  {'id': 'push', 'component': 'Spacer'},
  {'id': 'tag', 'component': 'Text', 'text': 'agora', 'variant': 'caption'},
  {
    'id': 'tabs',
    'component': 'Tabs',
    'tabs': [
      {'title': 'Mês', 'icon': 'calendar', 'child': 'left'},
      {'title': 'Ano', 'child': 'spent'},
    ],
  },
  {
    'id': 'total',
    'component': 'Text',
    'text': 'Total: 3 contas',
    'padding': 'sm',
    'background': 'fill',
    'radius': 'pill',
  },
];

final _data = <String, dynamic>{
  'page': 'resumo',
  'q': '',
  'bills': [
    {'name': 'Luz', 'value': r'R$ 120', 'open': true},
    {'name': 'Água', 'value': r'R$ 80', 'open': false},
  ],
};

Future<void> _pump(
  WidgetTester tester, {
  bool scroll = false,
  String? selectedId,
  ValueChanged<String>? onSelect,
  void Function(String, Map<String, Object?>)? onAction,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final renderer = AppRenderer(
    ui: _ui,
    data: _data,
    onAction: onAction ?? (_, _) {},
    onEdit: (_, _) {},
    selectedId: selectedId,
    onSelect: onSelect,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.current,
      home: Scaffold(
        body: scroll ? SingleChildScrollView(child: renderer) : renderer,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('a Screen, a Split or a Panel at the root fills the screen', () {
    expect(AppRenderer.fillsScreen(_ui), isTrue);
    expect(
      AppRenderer.fillsScreen([
        {'id': 'root', 'component': 'Column'},
      ]),
      isFalse,
    );
  });

  testWidgets('draws a whole real-app screen, filling the window', (
    tester,
  ) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    for (final text in [
      'Finanças',
      'Novembro',
      'AS',
      'Resumo',
      'Luz',
      r'R$ 120',
      'paga',
      'Gasto',
      '+8%',
      'Atenção',
      '40%',
      'Oi',
      'Mês',
      'Total: 3 contas',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    // The list is not empty: its empty state is hidden.
    expect(find.text('Nenhuma conta'), findsNothing);
    // The Screen took the window: its footer sits at the bottom.
    expect(
      tester.getBottomLeft(find.text('Total: 3 contas')).dy,
      greaterThan(700),
    );
  });

  testWidgets('lays the same screen out at its own height in a scroll view', (
    tester,
  ) async {
    await _pump(tester, scroll: true);
    expect(tester.takeException(), isNull);
    expect(find.text('Finanças'), findsOneWidget);
  });

  testWidgets('a tap on a list item runs its action', (tester) async {
    final fired = <String>[];
    await _pump(tester, onAction: (name, _) => fired.add(name));
    await tester.tap(find.text('Água'));
    expect(fired, ['open']);
  });

  testWidgets('the selected component is named and outlined, picking or not', (
    tester,
  ) async {
    await _pump(tester, selectedId: 'note');
    expect(tester.takeException(), isNull);
    // Its tag: the id over the outline.
    expect(find.text('note'), findsOneWidget);

    final picked = <String>[];
    await _pump(tester, selectedId: 'note', onSelect: picked.add);
    // While picking, a tap picks the innermost component, and runs nothing.
    await tester.tap(find.text('Água'));
    expect(picked, ['row']);
  });
}
