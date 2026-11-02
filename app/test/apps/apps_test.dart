import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_own_app/apps/app_renderer.dart';
import 'package:my_own_app/apps/json_patch.dart';

const _ui = <Map<String, dynamic>>[
  {
    'id': 'root',
    'component': 'Column',
    'children': ['field', 'add', 'list'],
  },
  {
    'id': 'field',
    'component': 'TextField',
    'label': 'Nova tarefa',
    'value': {'path': '/draft'},
  },
  {
    'id': 'add',
    'component': 'Button',
    'label': 'Adicionar',
    'action': {
      'event': {
        'name': 'add_todo',
        'context': {
          'title': {'path': '/draft'},
        },
      },
    },
  },
  {
    'id': 'list',
    'component': 'List',
    'children': {'componentId': 'item', 'path': '/todos'},
  },
  {
    'id': 'item',
    'component': 'CheckBox',
    'label': {'path': 'title'},
    'value': {'path': 'done'},
    'action': {
      'event': {
        'name': 'toggle_todo',
        'context': {
          'done': {'path': 'done'},
        },
      },
    },
  },
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('applyPatch', () {
    test('adds, replaces and removes', () {
      final data = <String, dynamic>{
        'draft': 'x',
        'todos': [
          {'title': 'a', 'done': false},
        ],
      };
      final next = applyPatch(data, [
        {
          'op': 'add',
          'path': '/todos/-',
          'value': {'title': 'b', 'done': false},
        },
        {'op': 'replace', 'path': '/todos/0/done', 'value': true},
        {'op': 'replace', 'path': '/draft', 'value': ''},
        {'op': 'remove', 'path': '/todos/1'},
      ]);
      expect(next, {
        'draft': '',
        'todos': [
          {'title': 'a', 'done': true},
        ],
      });
      expect(data['draft'], 'x');
    });
  });

  testWidgets('draws the app and fires its actions with their context', (
    tester,
  ) async {
    final fired = <(String, Map<String, Object?>)>[];
    final edits = <(String, String)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRenderer(
            ui: _ui,
            data: const {
              'draft': 'Pão',
              'todos': [
                {'title': 'Leite', 'done': true},
              ],
            },
            onAction: (name, event) => fired.add((name, event)),
            onEdit: (path, text) => edits.add((path, text)),
          ),
        ),
      ),
    );

    expect(find.text('Leite'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Café');
    expect(edits.last, ('/draft', 'Café'));

    await tester.tap(find.text('Adicionar'));
    expect(fired.last.$1, 'add_todo');
    expect(fired.last.$2, {'title': 'Pão'});

    await tester.tap(find.text('Leite'));
    expect(fired.last.$1, 'toggle_todo');
    expect(fired.last.$2, {'done': true, 'itemPath': '/todos/0', 'index': 0});
  });

  testWidgets('picks a component instead of running it, while inspecting', (
    tester,
  ) async {
    final fired = <String>[];
    final picked = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRenderer(
            ui: _ui,
            data: const {
              'draft': '',
              'todos': [
                {'title': 'Leite', 'done': false},
              ],
            },
            onAction: (name, _) => fired.add(name),
            onEdit: (_, _) {},
            onSelect: picked.add,
            selectedId: 'add',
          ),
        ),
      ),
    );

    // The leaf absorbs the tap itself, so the text is not hit: expected.
    await tester.tap(find.text('Adicionar'), warnIfMissed: false);
    await tester.tap(find.text('Leite'), warnIfMissed: false);
    expect(picked, ['add', 'item']);
    expect(fired, isEmpty);
  });
}
