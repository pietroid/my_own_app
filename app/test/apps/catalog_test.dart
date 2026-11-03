import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_app/apps/app_renderer.dart';

/// Draws a screen over its data and records what it fires and edits.
class _Harness {
  final fired = <(String, Map<String, Object?>)>[];
  final edits = <(String, Object?)>[];

  Future<void> pump(
    WidgetTester tester,
    List<Map<String, dynamic>> ui,
    Map<String, dynamic> data,
  ) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.current,
      home: Scaffold(
        body: SingleChildScrollView(
          child: AppRenderer(
            ui: ui,
            data: data,
            onAction: (name, event) => fired.add((name, event)),
            onEdit: (path, value) => edits.add((path, value)),
          ),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _act(String name) => {
  'event': {'name': name},
};

void main() {
  test('knows every icon the server lets an app name', () {
    final source = File('../server/src/apps/catalog.ts').readAsStringSync();
    final list = source.substring(
      source.indexOf('export const ICONS'),
      source.indexOf('] as const', source.indexOf('export const ICONS')),
    );
    final names = RegExp("'([A-Za-z]+)'").allMatches(list).map((m) => m[1]);
    expect(names, isNotEmpty);
    expect(AppIcons.named.keys.toSet(), names.toSet());
  });

  test('has an icon for every component the server knows', () {
    final source = File('../server/src/apps/catalog.ts').readAsStringSync();
    final list = source.substring(
      source.indexOf('export const COMPONENTS'),
      source.indexOf('] as const', source.indexOf('export const COMPONENTS')),
    );
    final names = RegExp("'([A-Za-z]+)'").allMatches(list).map((m) => m[1]);
    expect(names, hasLength(35));
    for (final name in names) {
      expect(AppIcons.components, contains(name));
    }
  });

  testWidgets('draws every component without an error', (tester) async {
    final h = _Harness();
    await h.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['card', 'divider', 'tabs', 'strip', 'inputs'],
        },
        {'id': 'card', 'component': 'Card', 'child': 'row'},
        {
          'id': 'row',
          'component': 'Row',
          'children': ['icon', 'pic', 'title', 'badge'],
        },
        {'id': 'icon', 'component': 'Icon', 'name': 'star', 'tone': 'accent'},
        {
          'id': 'pic',
          'component': 'Image',
          'url': 'https://example.com/a.png',
          'variant': 'avatar',
        },
        {'id': 'title', 'component': 'Text', 'text': 'Título', 'variant': 'h2'},
        {'id': 'badge', 'component': 'Badge', 'text': 'novo'},
        {'id': 'divider', 'component': 'Divider'},
        {
          'id': 'tabs',
          'component': 'Tabs',
          'tabs': [
            {'title': 'Conversa', 'child': 'msg'},
            {'title': 'Versões', 'child': 'title'},
          ],
        },
        {'id': 'msg', 'component': 'Message', 'text': 'Oi', 'role': 'me'},
        {
          'id': 'strip',
          'component': 'List',
          'direction': 'horizontal',
          'children': {'componentId': 'chip', 'path': '/tags'},
        },
        {
          'id': 'chip',
          'component': 'Badge',
          'text': {'path': ''},
        },
        {
          'id': 'inputs',
          'component': 'Column',
          'children': ['field', 'switch', 'pick', 'slider', 'date', 'go'],
        },
        {
          'id': 'field',
          'component': 'TextField',
          'label': 'Nota',
          'value': {'path': '/note'},
          'variant': 'longText',
        },
        {
          'id': 'switch',
          'component': 'Switch',
          'label': 'Ligado',
          'value': {'path': '/on'},
        },
        {
          'id': 'pick',
          'component': 'ChoicePicker',
          'options': [
            {'label': 'A', 'value': 'a'},
          ],
          'value': {'path': '/chosen'},
        },
        {
          'id': 'slider',
          'component': 'Slider',
          'max': 10,
          'value': {'path': '/level'},
        },
        {
          'id': 'date',
          'component': 'DateTimeInput',
          'label': 'Quando',
          'value': {'path': '/when'},
        },
        {
          'id': 'go',
          'component': 'Button',
          'label': 'Ir',
          'icon': 'forward',
          'variant': 'primary',
          'action': _act('go'),
        },
      ],
      {
        'note': '',
        'on': true,
        'chosen': <String>[],
        'level': 3,
        'when': '',
        'tags': ['a', 'b'],
      },
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    for (final text in ['Título', 'novo', 'Conversa', 'Oi', 'a', 'Ligado']) {
      expect(find.text(text), findsWidgets);
    }
  });

  testWidgets('hides what is not visible, and indents by inset', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['shown', 'hidden', 'wide'],
        },
        {
          'id': 'shown',
          'component': 'Text',
          'text': 'sim',
          'visible': {'path': '/on'},
          'inset': 2,
        },
        {
          'id': 'hidden',
          'component': 'Text',
          'text': 'não',
          'visible': {'path': '/off'},
        },
        {
          'id': 'wide',
          'component': 'Text',
          'text': 'largo',
          'visible': {'path': r'/$viewport/width'},
        },
      ],
      {'on': true, 'off': false},
    );

    expect(find.text('sim'), findsOneWidget);
    expect(find.text('não'), findsNothing);
    // Something is visible: a width is something.
    expect(find.text('largo'), findsOneWidget);
    final padding = tester.widget<Padding>(
      find.ancestor(of: find.text('sim'), matching: find.byType(Padding)).first,
    );
    expect(
      (padding.padding as EdgeInsets).left,
      2 * AppSpacing.treeIndent,
    );
  });

  testWidgets('draws the current page, the first when none is', (
    tester,
  ) async {
    final h = _Harness();
    final ui = [
      {
        'id': 'root',
        'component': 'Pages',
        'current': {'path': '/page'},
        'pages': {'home': 'home', 'about': 'about'},
      },
      {'id': 'home', 'component': 'Text', 'text': 'Início'},
      {'id': 'about', 'component': 'Text', 'text': 'Sobre'},
    ];
    await h.pump(tester, ui, {'page': ''});
    expect(find.text('Início'), findsOneWidget);
    await h.pump(tester, ui, {'page': 'about'});
    expect(find.text('Sobre'), findsOneWidget);
    expect(find.text('Início'), findsNothing);
  });

  testWidgets('a bound tab writes its title; an unbound one keeps its own', (
    tester,
  ) async {
    final h = _Harness();
    Map<String, dynamic> tabs({required bool bound}) => {
      'id': 'root',
      'component': 'Tabs',
      if (bound) 'value': {'path': '/tab'},
      'tabs': [
        {'title': 'Um', 'child': 'one'},
        {'title': 'Dois', 'child': 'two'},
      ],
    };
    final children = [
      {'id': 'one', 'component': 'Text', 'text': 'primeiro'},
      {'id': 'two', 'component': 'Text', 'text': 'segundo'},
    ];

    await h.pump(tester, [tabs(bound: true), ...children], {'tab': 'Dois'});
    expect(find.text('segundo'), findsOneWidget);
    await tester.tap(find.text('Um'));
    expect(h.edits.last, ('/tab', 'Um'));

    await h.pump(tester, [tabs(bound: false), ...children], {});
    await tester.tap(find.text('Dois'));
    await tester.pump();
    expect(find.text('segundo'), findsOneWidget);
  });

  testWidgets('an input keeps its value on the device, or hands it to its '
      'action', (tester) async {
    final h = _Harness();
    await h.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['local', 'saved', 'many'],
        },
        {
          'id': 'local',
          'component': 'Switch',
          'label': 'Local',
          'value': {'path': '/a'},
        },
        {
          'id': 'saved',
          'component': 'CheckBox',
          'label': 'Salvo',
          'value': {'path': '/b'},
          'action': _act('save'),
        },
        {
          'id': 'many',
          'component': 'ChoicePicker',
          'variant': 'multipleSelection',
          'options': {'path': '/options'},
          'value': {'path': '/chosen'},
        },
      ],
      {
        'a': false,
        'b': true,
        'options': ['x', 'y'],
        'chosen': ['x'],
      },
    );

    await tester.tap(find.text('Local'));
    expect(h.edits.last, ('/a', true));

    await tester.tap(find.text('Salvo'));
    expect(h.fired.last.$1, 'save');
    expect(h.fired.last.$2, {'value': false});
    expect(h.edits, hasLength(1));

    await tester.tap(find.text('y'));
    expect(h.edits.last.$1, '/chosen');
    expect(h.edits.last.$2, ['x', 'y']);
  });

  testWidgets('a field with an action runs it on enter', (tester) async {
    final h = _Harness();
    await h.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'TextField',
          'label': 'Mensagem',
          'value': {'path': '/draft'},
          'action': {
            'event': {
              'name': 'send',
              'context': {
                'text': {'path': '/draft'},
              },
            },
          },
        },
      ],
      {'draft': 'Olá'},
    );

    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    expect(h.fired.last.$1, 'send');
    expect(h.fired.last.$2, {'text': 'Olá'});
  });

  testWidgets('a card with an action is tapped whole; a weighted row child '
      'takes its share', (tester) async {
    final h = _Harness();
    await h.pump(tester, [
      {
        'id': 'root',
        'component': 'Card',
        'child': 'row',
        'action': _act('open'),
      },
      {
        'id': 'row',
        'component': 'Row',
        'children': ['a', 'b'],
      },
      {'id': 'a', 'component': 'Text', 'text': 'a', 'weight': 3},
      {'id': 'b', 'component': 'Text', 'text': 'b'},
    ], {});

    final flexes = tester
        .widgetList<Expanded>(find.byType(Expanded))
        .map((e) => e.flex);
    expect(flexes, [3, 1]);
    await tester.tap(find.text('b'));
    expect(h.fired.last.$1, 'open');
  });

  testWidgets('a modal shows its content while open, and a tap outside '
      'closes it', (tester) async {
    final h = _Harness();
    final ui = [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['label', 'sheet'],
      },
      {'id': 'label', 'component': 'Text', 'text': 'Tela'},
      {
        'id': 'sheet',
        'component': 'Modal',
        'open': {'path': '/open'},
        'content': 'inside',
      },
      {'id': 'inside', 'component': 'Text', 'text': 'Na folha'},
    ];
    await h.pump(tester, ui, {'open': false});
    expect(find.text('Na folha'), findsNothing);

    await h.pump(tester, ui, {'open': true});
    await tester.pump();
    expect(find.text('Na folha'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    expect(h.edits.last, ('/open', false));
  });

  test('lists every reference a component holds', () {
    expect(
      references({
        'child': 'a',
        'content': 'b',
        'tabs': [
          {'title': 'T', 'child': 'c'},
        ],
        'pages': {'p': 'd'},
      }),
      ['a', 'b', 'c', 'd'],
    );
  });
}
