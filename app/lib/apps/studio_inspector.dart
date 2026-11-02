import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/apps/app_renderer.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/apps/studio_cubit.dart';

/// What a component type is called, in the person's words.
String componentName(AppLocalizations l10n, String? type) => switch (type) {
  'Column' => l10n.componentColumn,
  'Row' => l10n.componentRow,
  'List' => l10n.componentList,
  'Text' => l10n.componentText,
  'TextField' => l10n.componentTextField,
  'CheckBox' => l10n.componentCheckBox,
  'Button' => l10n.componentButton,
  'Card' => l10n.componentCard,
  'Divider' => l10n.componentDivider,
  'Tabs' => l10n.componentTabs,
  'Pages' => l10n.componentPages,
  'Modal' => l10n.componentModal,
  'Icon' => l10n.componentIcon,
  'Image' => l10n.componentImage,
  'Badge' => l10n.componentBadge,
  'Message' => l10n.componentMessage,
  'Switch' => l10n.componentSwitch,
  'ChoicePicker' => l10n.componentChoicePicker,
  'Slider' => l10n.componentSlider,
  'DateTimeInput' => l10n.componentDateTimeInput,
  _ => l10n.componentUnknown,
};

/// The icon of a component type.
AppIconData componentIcon(String? type) =>
    AppIcons.components[type] ?? AppIcons.componentButton;

/// {@template studio_inspector}
/// The app's components as a tree, the picked one highlighted; under it,
/// the picked component's menu: what it is, what it shows, the action it
/// runs, and a way to ask for a change to it.
/// {@endtemplate}
class StudioInspector extends StatelessWidget {
  /// {@macro studio_inspector}
  const StudioInspector({required this.app, super.key});

  /// The app on the phone: as it is, or the version being looked at.
  final AppSnapshot? app;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<StudioCubit>().state;
    final components = {
      for (final c in app?.ui ?? const <Map<String, dynamic>>[])
        c['id'] as String: c,
    };
    final selected = components[state.selectedId];

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s2,
            ),
            child: Row(
              spacing: AppSpacing.s2,
              children: [
                const AppIcon(
                  iconData: AppIcons.tree,
                  size: AppSpacing.iconSmall,
                ),
                Text(l10n.studioTreeTitle, style: AppTypography.title),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              children: [
                for (final row in _rows(components))
                  _TreeRow(
                    row: row,
                    selected: row.component['id'] == state.selectedId,
                    // Picking is for changing the app as it is.
                    onTap: state.viewing != null
                        ? null
                        : () => context.read<StudioCubit>().select(
                            row.component['id'] as String,
                          ),
                  ),
              ],
            ),
          ),
          const Divider(height: AppSpacing.hairline),
          SizedBox(
            height: AppSpacing.studioMenuHeight,
            child: selected == null
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: Text(
                      l10n.studioNothingSelected,
                      style: AppTypography.label,
                    ),
                  )
                : _Menu(component: selected, actions: app?.actions ?? {}),
          ),
        ],
      ),
    );
  }

  /// The tree in drawing order, from root: each component with its depth,
  /// and whether it is drawn once per item of a list.
  static List<_Row> _rows(Map<String, Map<String, dynamic>> components) {
    final rows = <_Row>[];
    final seen = <String>{};
    void walk(String id, int depth, {bool perItem = false}) {
      final c = components[id];
      if (c == null || !seen.add(id)) return;
      rows.add(_Row(component: c, depth: depth, perItem: perItem));
      final children = c['children'];
      if (children is List) {
        for (final child in children) {
          walk('$child', depth + 1);
        }
      } else if (children is Map) {
        walk('${children['componentId']}', depth + 1, perItem: true);
      }
      for (final ref in references(c)) {
        walk(ref, depth + 1);
      }
    }

    walk('root', 0);
    return rows;
  }
}

class _Row {
  const _Row({
    required this.component,
    required this.depth,
    required this.perItem,
  });

  final Map<String, dynamic> component;
  final int depth;
  final bool perItem;
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final _Row row;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = row.component['component'] as String?;

    return Material(
      color: selected ? AppColors.accentSoft : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4 + row.depth * AppSpacing.treeIndent,
            AppSpacing.s1,
            AppSpacing.s4,
            AppSpacing.s1,
          ),
          child: Row(
            spacing: AppSpacing.s2,
            children: [
              AppIcon(
                iconData: componentIcon(type),
                size: AppSpacing.iconSmall,
                color: selected ? AppColors.accent : AppColors.ink2,
              ),
              Text(componentName(l10n, type), style: AppTypography.label),
              Expanded(
                child: Text(
                  '${row.component['id']}',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ),
              if (row.perItem)
                Text(l10n.studioPerItem, style: AppTypography.caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// The picked component's menu.
class _Menu extends StatelessWidget {
  const _Menu({required this.component, required this.actions});

  final Map<String, dynamic> component;
  final Map<String, AppAction> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = component['component'] as String?;
    final id = component['id'] as String;
    final children = component['children'];
    final actionName =
        ((component['action'] as Map?)?['event'] as Map?)?['name'] as String?;
    final action = actions[actionName];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      children: [
        Row(
          spacing: AppSpacing.s2,
          children: [
            AppIcon(
              iconData: componentIcon(type),
              size: AppSpacing.iconSmall,
              color: AppColors.accent,
            ),
            Text(componentName(l10n, type), style: AppTypography.bodyStrong),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        _Property(l10n.studioId, id),
        if (component['text'] != null)
          _Property(l10n.studioText, _shown(component['text'])),
        if (component['label'] != null)
          _Property(l10n.studioLabel, _shown(component['label'])),
        if (component['value'] != null)
          _Property(l10n.studioValue, _shown(component['value'])),
        if (children is List)
          _Property(l10n.studioChildren, children.join(', ')),
        if (children is Map) _Property(l10n.studioItems, '${children['path']}'),
        if (actionName != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Row(
            spacing: AppSpacing.s2,
            children: [
              const AppIcon(
                iconData: AppIcons.action,
                size: AppSpacing.iconSmall,
              ),
              Expanded(
                child: Text(actionName, style: AppTypography.labelStrong),
              ),
              if (action != null)
                Text(
                  action.saved ? l10n.studioSaved : l10n.studioScreenOnly,
                  style: AppTypography.caption,
                ),
            ],
          ),
          if (action != null && action.input.isNotEmpty)
            _Property(l10n.studioReads, action.input.join(', ')),
        ],
        const SizedBox(height: AppSpacing.s4),
        AppButton(
          expand: true,
          onPressed: () => context.read<StudioCubit>().focus(id),
          text: l10n.studioAskChange,
        ),
      ],
    );
  }

  /// A literal as it is; a binding as the path it reads.
  static String _shown(Object? bound) =>
      bound is Map && bound['path'] is String ? '→ ${bound['path']}' : '$bound';
}

class _Property extends StatelessWidget {
  const _Property(this.name, this.value);

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSpacing.propertyNameWidth,
            child: Text(name, style: AppTypography.caption),
          ),
          Expanded(child: Text(value, style: AppTypography.label)),
        ],
      ),
    );
  }
}
