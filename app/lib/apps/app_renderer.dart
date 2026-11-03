import 'dart:async';
import 'dart:convert';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/apps/apps_cubit.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/apps/json_patch.dart';

part 'components/display.dart';
part 'components/input.dart';
part 'components/layout.dart';
part 'components/surface.dart';

/// Called when a component fires its action.
typedef AppActionCallback =
    void Function(String action, Map<String, Object?> event);

/// Called when a component changes a value on the device: the absolute
/// path, and the value (text, a boolean, a number, a list).
typedef AppEditCallback = void Function(String path, Object? value);

/// The read-only paths the renderer adds to the data, for components only
/// (an action never sees them): `/$viewport/width`, `/$viewport/height`,
/// and `/$viewport/size`, the window's class: `compact` (a phone),
/// `medium` or `expanded` (from `AppSpacing.studioBreakpoint`).
const viewportKey = r'$viewport';

/// See [viewportKey]: `/$pending/<action>` is the event of a platform
/// action on its way, missing when none is.
const pendingKey = r'$pending';

/// The ids [component] draws other than through `children`: a Card's
/// child, each tab, each page, a Modal's content (as `references` in
/// `server/src/apps/catalog.ts`).
List<String> references(Map<String, dynamic> component) => [
  if (component['child'] case final String id) id,
  if (component['content'] case final String id) id,
  if (component['tabs'] case final List<dynamic> tabs)
    for (final tab in tabs)
      if (tab case {'child': final String id}) id,
  if (component['pages'] case final Map<dynamic, dynamic> pages)
    for (final id in pages.values)
      if (id is String) id,
];

/// {@template app_renderer}
/// Draws a built app's screen: our own subset of A2UI v0.9 over `app_ui`
/// (the catalog is `server/src/apps/catalog.ts`).
///
/// Components bind to [data] by JSON Pointer. Inside a list template, a
/// path without a leading `/` is relative to the item, and every event fired
/// there carries `itemPath` and `index`. A component the renderer does not
/// know draws nothing. Any component may carry `visible`, `weight` (its
/// share of a Row) and `inset` (steps of indentation).
///
/// With [onSelect], the screen is being inspected rather than used: a tap
/// picks the component under it (the innermost one) instead of running
/// anything, and every copy of [selectedId] is outlined.
/// {@endtemplate}
class AppRenderer extends StatelessWidget {
  /// {@macro app_renderer}
  AppRenderer({
    required List<Map<String, dynamic>> ui,
    required this.data,
    required this.onAction,
    required this.onEdit,
    this.onSelect,
    this.selectedId,
    this.pending = const {},
    super.key,
  }) : _components = {
         for (final component in ui) component['id'] as String: component,
       };

  /// The app's whole state.
  final Map<String, dynamic> data;

  /// A tap on something with an action.
  final AppActionCallback onAction;

  /// A value changed on the device: typing, a switch, a slider.
  final AppEditCallback onEdit;

  /// Picks a component by id; when set, taps select instead of acting.
  final ValueChanged<String>? onSelect;

  /// The component picked, outlined wherever it is drawn.
  final String? selectedId;

  /// The platform actions on their way, by name, with their events.
  final Map<String, Map<String, Object?>> pending;

  final Map<String, Map<String, dynamic>> _components;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final render = _Render(
      this,
      {
        ...data,
        viewportKey: {
          'width': size.width,
          'height': size.height,
          'size': size.width >= AppSpacing.studioBreakpoint
              ? 'expanded'
              : size.width >= AppSpacing.phoneFrameBreakpoint
              ? 'medium'
              : 'compact',
        },
        pendingKey: pending,
      },
    );
    return render.build('root', const _Scope(), 0);
  }
}

/// One drawing of the screen: the data it reads (with the viewport) and the
/// components, drawn from `root` down. The components themselves are in
/// `components/`, one file per group.
class _Render {
  _Render(this.renderer, this.data);

  final AppRenderer renderer;
  final Map<String, dynamic> data;

  Map<String, Map<String, dynamic>> get components => renderer._components;

  static const _containers = {
    'Column',
    'Row',
    'List',
    'Card',
    'Tabs',
    'Pages',
    'Modal',
  };

  /// Kept at their own width inside a Row unless given a weight.
  static const _fixed = {'Button', 'Icon', 'Image', 'Badge', 'Divider'};

  Widget build(String id, _Scope scope, int depth) {
    final c = components[id];
    // A cycle or a missing id draws nothing rather than overflowing.
    if (c == null || depth > 32) return const _Fixed(SizedBox.shrink());
    if (c.containsKey('visible') && !shown(c['visible'], scope)) {
      return const _Fixed(SizedBox.shrink());
    }

    var drawn = _draw(c, scope, depth);
    final inset = value(c['inset'], scope);
    if (inset is num && inset > 0) {
      drawn = Padding(
        padding: EdgeInsets.only(left: inset * AppSpacing.treeIndent),
        child: drawn,
      );
    }

    final select = renderer.onSelect;
    if (select != null) {
      // A container takes the taps between its children; a leaf takes all
      // of its own, so a button is picked, not pressed.
      drawn = _Selectable(
        selected: id == renderer.selectedId,
        absorb: !_containers.contains(c['component']),
        onTap: () => select(id),
        child: drawn,
      );
    }

    final weight = c['weight'];
    if (weight is num && weight > 0) return _Weighted(weight.round(), drawn);
    if (_fixed.contains(c['component'])) return _Fixed(drawn);
    return drawn;
  }

  Widget _draw(Map<String, dynamic> c, _Scope scope, int depth) {
    return switch (c['component']) {
      'Column' => column(c, scope, depth),
      'Row' => row(c, scope, depth),
      'List' => list(c, scope, depth),
      'Card' => card(c, scope, depth),
      'Divider' => const Divider(height: AppSpacing.s3),
      'Tabs' => tabs(c, scope, depth),
      'Pages' => pages(c, scope, depth),
      'Modal' => modal(c, scope, depth),
      'Text' => text(c, scope),
      'Icon' => icon(c, scope),
      'Image' => image(c, scope),
      'Badge' => badge(c, scope),
      'Message' => message(c, scope),
      'TextField' => field(c, scope),
      'CheckBox' => check(c, scope, switchStyle: false),
      'Switch' => check(c, scope, switchStyle: true),
      'ChoicePicker' => choice(c, scope),
      'Slider' => slider(c, scope),
      'DateTimeInput' => date(c, scope),
      'Button' => button(c, scope),
      'Surface' => surface(c, scope),
      _ => const SizedBox.shrink(),
    };
  }

  List<Widget> children(Map<String, dynamic> c, _Scope scope, int depth) {
    final children = c['children'];
    if (children is List) {
      return [for (final id in children) build('$id', scope, depth + 1)];
    }
    if (children is Map) {
      final path = scope.resolve('${children['path']}');
      final items = valueAt(data, path);
      if (items is! List) return const [];
      return [
        for (var i = 0; i < items.length; i++)
          build(
            '${children['componentId']}',
            _Scope(itemPath: '$path/$i', index: i),
            depth + 1,
          ),
      ];
    }
    return const [];
  }

  /// Fires [c]'s action, with its context, where it sits, and [extra]
  /// (an input's new `value`).
  void fire(
    Map<String, dynamic> c,
    _Scope scope, [
    Map<String, Object?> extra = const {},
  ]) {
    final event = (c['action'] as Map?)?['event'] as Map?;
    final name = event?['name'];
    if (name is! String) return;
    final context = event?['context'];
    renderer.onAction(name, {
      if (context is Map)
        for (final entry in context.entries)
          '${entry.key}': value(entry.value, scope),
      if (scope.itemPath != null) 'itemPath': scope.itemPath,
      if (scope.index != null) 'index': scope.index,
      ...extra,
    });
  }

  /// Whether `visible` lets a component draw: `{"path", "is": x}` when the
  /// value equals x (`"not": true`: when it does not); otherwise when it is
  /// something (not null, false, 0, or empty).
  bool shown(Object? visible, _Scope scope) {
    final v = value(visible, scope);
    if (visible is Map && visible.containsKey('is')) {
      final same = jsonEncode(v) == jsonEncode(visible['is']);
      return visible['not'] == true ? !same : same;
    }
    return switch (v) {
      null || false || 0 || '' => false,
      List() => v.isNotEmpty,
      Map() => v.isNotEmpty,
      _ => true,
    };
  }

  bool hasAction(Map<String, dynamic> c) =>
      ((c['action'] as Map?)?['event'] as Map?)?['name'] is String;

  /// An input's new [next] value: with an action, the action decides (it
  /// gets the value as `event.value`); without one, it is kept on the
  /// device at the bound path.
  void change(Map<String, dynamic> c, _Scope scope, Object? next) {
    if (hasAction(c)) {
      fire(c, scope, {'value': next});
    } else {
      edit(c['value'], scope, next);
    }
  }

  /// Writes [next] to the path [bound] names, if it names one.
  void edit(Object? bound, _Scope scope, Object? next) {
    final path = pathOf(bound);
    if (path.isEmpty) return;
    renderer.onEdit(scope.resolve(path), next);
  }

  /// A literal, or the value at `{"path"}`.
  Object? value(Object? bound, _Scope scope) {
    if (bound is Map && bound['path'] is String) {
      return valueAt(data, scope.resolve(bound['path'] as String));
    }
    return bound;
  }

  String string(Object? bound, _Scope scope) {
    final v = value(bound, scope);
    return v == null ? '' : '$v';
  }

  /// The colour a `tone` names, or [fallback].
  Color tone(Object? bound, _Scope scope, Color fallback) =>
      switch (value(bound, scope)) {
        'muted' => AppColors.ink2,
        'accent' => AppColors.accent,
        'positive' => AppColors.positive,
        'negative' => AppColors.negative,
        _ => fallback,
      };

  static String pathOf(Object? bound) =>
      bound is Map && bound['path'] is String ? bound['path'] as String : '';
}

/// Where a component sits: at the top, or inside a list template's item.
class _Scope {
  const _Scope({this.itemPath, this.index});

  final String? itemPath;
  final int? index;

  String resolve(String path) {
    if (path.startsWith('/') || itemPath == null) return path;
    return path.isEmpty ? itemPath! : '$itemPath/$path';
  }
}

/// A component that can be picked: outlined when it is.
class _Selectable extends StatelessWidget {
  const _Selectable({
    required this.selected,
    required this.absorb,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final bool absorb;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          foregroundDecoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected
                  ? AppSpacing.selectionOutline
                  : AppSpacing.hairline,
            ),
            borderRadius: const BorderRadius.all(
              Radius.circular(AppSpacing.chipRadius),
            ),
          ),
          child: absorb ? AbsorbPointer(child: child) : child,
        ),
      ),
    );
  }
}

/// A child of a row that keeps its own width instead of sharing the row.
class _Fixed extends StatelessWidget {
  const _Fixed(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// A child of a row that takes [flex] shares of the width.
class _Weighted extends StatelessWidget {
  const _Weighted(this.flex, this.child);

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
