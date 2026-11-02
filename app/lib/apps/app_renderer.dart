import 'package:app_ui/app_ui.dart';
import 'package:my_own_app/apps/json_patch.dart';

/// Called when a component fires its action.
typedef AppActionCallback =
    void Function(String action, Map<String, Object?> event);

/// {@template app_renderer}
/// Draws a built app's screen: our own subset of A2UI v0.9 over `app_ui`.
///
/// Components bind to [data] by JSON Pointer. Inside a list template, a
/// path without a leading `/` is relative to the item, and every event fired
/// there carries `itemPath` and `index`. A component the renderer does not
/// know draws nothing.
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
    super.key,
  }) : _components = {
         for (final component in ui) component['id'] as String: component,
       };

  /// The app's whole state.
  final Map<String, dynamic> data;

  /// A tap on something with an action.
  final AppActionCallback onAction;

  /// Typing into a field: the absolute path, and the text.
  final void Function(String path, String value) onEdit;

  /// Picks a component by id; when set, taps select instead of acting.
  final ValueChanged<String>? onSelect;

  /// The component picked, outlined wherever it is drawn.
  final String? selectedId;

  final Map<String, Map<String, dynamic>> _components;

  @override
  Widget build(BuildContext context) {
    return _build('root', const _Scope(), 0);
  }

  Widget _build(String id, _Scope scope, int depth) {
    final c = _components[id];
    // A cycle or a missing id draws nothing rather than overflowing.
    if (c == null || depth > 32) return const SizedBox.shrink();

    final drawn = _draw(c, scope, depth);
    final select = onSelect;
    if (select == null) return drawn;
    // A container takes the taps between its children; a leaf takes all
    // of its own, so a button is picked, not pressed.
    final leaf = !_containers.contains(c['component']);
    Widget wrap(Widget child) => _Selectable(
      selected: id == selectedId,
      absorb: leaf,
      onTap: () => select(id),
      child: child,
    );
    return drawn is _Fixed ? _Fixed(wrap(drawn.child)) : wrap(drawn);
  }

  static const _containers = {'Column', 'Row', 'List'};

  Widget _draw(Map<String, dynamic> c, _Scope scope, int depth) {
    return switch (c['component']) {
      'Column' || 'List' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s3,
        children: _children(c, scope, depth),
      ),
      'Row' => Row(
        spacing: AppSpacing.s3,
        children: [
          for (final child in _children(c, scope, depth))
            child is _Fixed ? child : Expanded(child: child),
        ],
      ),
      'Text' => Text(
        _string(c['text'], scope),
        style: switch (c['variant']) {
          'title' => AppTypography.headline,
          'caption' => AppTypography.caption,
          _ => AppTypography.body,
        },
      ),
      'TextField' => _Field(
        key: ValueKey('field:${scope.resolve(_path(c['value']))}'),
        label: _string(c['label'], scope),
        value: _string(c['value'], scope),
        onChanged: (text) => onEdit(scope.resolve(_path(c['value'])), text),
      ),
      'CheckBox' => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(_string(c['label'], scope), style: AppTypography.body),
        value: _value(c['value'], scope) == true,
        onChanged: c['action'] == null ? null : (_) => _fire(c, scope),
      ),
      'Button' => _Fixed(
        AppButton(
          variant: AppButtonVariant.secondary,
          text: _string(c['label'], scope),
          onPressed: c['action'] == null ? null : () => _fire(c, scope),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  List<Widget> _children(Map<String, dynamic> c, _Scope scope, int depth) {
    final children = c['children'];
    if (children is List) {
      return [for (final id in children) _build('$id', scope, depth + 1)];
    }
    if (children is Map) {
      final path = scope.resolve('${children['path']}');
      final items = valueAt(data, path);
      if (items is! List) return const [];
      return [
        for (var i = 0; i < items.length; i++)
          _build(
            '${children['componentId']}',
            _Scope(itemPath: '$path/$i', index: i),
            depth + 1,
          ),
      ];
    }
    return const [];
  }

  void _fire(Map<String, dynamic> c, _Scope scope) {
    final event = (c['action'] as Map?)?['event'] as Map?;
    final name = event?['name'];
    if (name is! String) return;
    final context = event?['context'];
    onAction(name, {
      if (context is Map)
        for (final entry in context.entries)
          '${entry.key}': _value(entry.value, scope),
      if (scope.itemPath != null) 'itemPath': scope.itemPath,
      if (scope.index != null) 'index': scope.index,
    });
  }

  /// A literal, or the value at `{"path"}`.
  Object? _value(Object? bound, _Scope scope) {
    if (bound is Map && bound['path'] is String) {
      return valueAt(data, scope.resolve(bound['path'] as String));
    }
    return bound;
  }

  String _string(Object? bound, _Scope scope) {
    final value = _value(bound, scope);
    return value == null ? '' : '$value';
  }

  static String _path(Object? bound) =>
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

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_Field oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An action may change the field's value (clearing it after "add").
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: AppTypography.body,
      decoration: InputDecoration(hintText: widget.label),
    );
  }
}
