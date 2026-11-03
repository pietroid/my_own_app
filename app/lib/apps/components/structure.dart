part of '../app_renderer.dart';

/// Screen, TopBar, NavBar, Split and Panel: what frames a real app's
/// screen. In a bounded box (a window, a drawn phone, a pane) they fill it
/// and only their bodies scroll; in a scroll view they lay out at their
/// own height.
extension on _Render {
  /// A whole screen: `header` (a TopBar), `body` (scrolls, `padding`
  /// default `lg`, unless it fills: a Split, a Panel), `footer` (pinned
  /// under the body: a composer, a total) and `nav` (a NavBar: at the
  /// bottom, or at the start when it is `side`). `background` defaults
  /// to the page's.
  Widget screen(Map<String, dynamic> c, _Scope scope, int depth) {
    final header = slot(c, 'header', scope, depth);
    final footer = slot(c, 'footer', scope, depth);
    final nav = slot(c, 'nav', scope, depth);
    final navId = c['nav'];
    final side =
        navId is String &&
        value(components[navId]?['variant'], scope) == 'side';
    final bodyId = c['body'];
    final pad = step(c['padding'], scope) ?? AppSpacing.s4;
    final background = paint(c['background'], scope) ?? AppColors.bg;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        final insets = MediaQuery.paddingOf(context);
        var body = bodyId is String
            ? build(bodyId, scope, depth + 1)
            : const SizedBox.shrink();
        if (bodyId is! String || !fills(bodyId, scope)) {
          body = bounded
              ? SingleChildScrollView(
                  padding: EdgeInsets.all(pad),
                  child: body,
                )
              : Padding(padding: EdgeInsets.all(pad), child: body);
        }
        if (side && nav != null) {
          body = Row(
            crossAxisAlignment: bounded
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              nav,
              Expanded(child: body),
            ],
          );
        }
        return ColoredBox(
          color: background,
          child: Padding(
            // Below a status bar, above a home indicator.
            padding: EdgeInsets.only(top: insets.top, bottom: insets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?header,
                if (bounded) Expanded(child: body) else body,
                if (footer != null)
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s3),
                      child: footer,
                    ),
                  ),
                if (!side) ?nav,
              ],
            ),
          ),
        );
      },
    );
  }

  /// The bar over a screen: `title`, `subtitle`, `leading` (one id, before
  /// the title), `trailing` (ids at the end: buttons, a picker). A back
  /// arrow comes first when there is a page to go back to.
  Widget topBar(Map<String, dynamic> c, _Scope scope, int depth) {
    final title = string(c['title'], scope);
    final subtitle = string(c['subtitle'], scope);
    final leading = slot(c, 'leading', scope, depth);
    final background = paint(c['background'], scope) ?? AppColors.bg;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.topBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: background,
        border: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        spacing: AppSpacing.s3,
        children: [
          const _Back(),
          ?leading,
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
              ],
            ),
          ),
          ...trailing(c, scope, depth),
        ],
      ),
    );
  }

  /// The way between an app's screens: `items` [{label, icon, value}],
  /// `value` {path} (the open item's value, written on a tap; with
  /// `action`, the action gets it as event.value instead). At the bottom
  /// of a phone; `variant` `side` for a web app's side navigation.
  Widget navBar(Map<String, dynamic> c, _Scope scope) {
    final items = [
      for (final item in (value(c['items'], scope) as List?) ?? const [])
        if (item is Map)
          (
            label: string(item['label'], scope),
            icon: AppIcons.named[string(item['icon'], scope)],
            value: '${item['value']}',
          ),
    ];
    final open = string(c['value'], scope);
    final side = value(c['variant'], scope) == 'side';
    if (side) {
      return Container(
        width: AppSpacing.sideNavWidth,
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(right: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s1,
          children: [
            for (final item in items)
              _SideNavItem(
                label: item.label,
                icon: item.icon,
                chosen: item.value == open,
                onTap: () => change(c, scope, item.value),
              ),
          ],
        ),
      );
    }
    return Container(
      height: AppSpacing.navBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _BottomNavItem(
                label: item.label,
                icon: item.icon,
                chosen: item.value == open,
                onTap: () => change(c, scope, item.value),
              ),
            ),
        ],
      ),
    );
  }

  /// Panes side by side, the whole height, a hairline between them: a
  /// studio, a mail client. `children` are the panes; one with `width`
  /// (`sm`, `md`, `lg` or a number) keeps it, the rest share what is left
  /// by `weight`. A pane that does not fill (a Panel does) scrolls; a
  /// Surface is centred.
  Widget split(Map<String, dynamic> c, _Scope scope, int depth) {
    final ids = [
      for (final id in (c['children'] as List?) ?? const [])
        if (components['$id'] case final pane? when isShown(pane, scope)) '$id',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        final panes = <Widget>[];
        for (final id in ids) {
          final pane = components[id]!;
          var drawn = build(id, scope, depth + 1);
          if (!fills(id, scope)) {
            drawn = pane['component'] == 'Surface'
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.s6),
                    child: Center(child: drawn),
                  )
                : bounded
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: drawn,
                  )
                : Padding(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: drawn,
                  );
          }
          final width = breadth(pane['width'], scope);
          final weight = pane['weight'];
          if (panes.isNotEmpty) {
            panes.add(
              const VerticalDivider(
                width: AppSpacing.hairline,
                thickness: AppSpacing.hairline,
              ),
            );
          }
          panes.add(
            width != null && width.isFinite
                ? SizedBox(width: width, child: drawn)
                : Expanded(
                    flex: weight is num && weight > 0 ? weight.round() : 1,
                    child: drawn,
                  ),
          );
        }
        return Row(
          crossAxisAlignment: bounded
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: panes,
        );
      },
    );
  }

  /// A titled section that fills its pane: a header (`title`, `icon`,
  /// `trailing` ids), a body (`child`, or `children` as a Column with
  /// `gap`; it scrolls, unless `scroll` is false: then it is centred, for
  /// a Surface), and a pinned `footer` (a composer). `padding` (default
  /// `lg`) and `background` (default none).
  Widget panel(Map<String, dynamic> c, _Scope scope, int depth) {
    final title = string(c['title'], scope);
    final icon = AppIcons.named[string(c['icon'], scope)];
    final tools = trailing(c, scope, depth);
    final footer = slot(c, 'footer', scope, depth);
    final scrolls = value(c['scroll'], scope) != false;
    final pad = step(c['padding'], scope) ?? AppSpacing.s4;
    final child = c['child'];
    final content = c['children'] != null
        ? flow(c, scope, depth, horizontal: false)
        : child is String
        ? build(child, scope, depth + 1)
        : const SizedBox.shrink();

    final header = title.isEmpty && tools.isEmpty
        ? null
        : Container(
            height: AppSpacing.panelHeaderHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              spacing: AppSpacing.s2,
              children: [
                if (icon != null)
                  AppIcon(
                    iconData: icon,
                    size: AppSpacing.iconSmall,
                    color: AppColors.ink2,
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelStrong,
                  ),
                ),
                ...tools,
              ],
            ),
          );
    final pinned = footer == null
        ? null
        : Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: footer,
          );

    return ColoredBox(
      color: paint(c['background'], scope) ?? Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight;
          final Widget body;
          if (!bounded) {
            body = Padding(padding: EdgeInsets.all(pad), child: content);
          } else if (scrolls) {
            body = Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: content,
              ),
            );
          } else {
            body = Expanded(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Center(child: content),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [?header, body, ?pinned],
          );
        },
      ),
    );
  }
}

/// A back arrow, when the page this screen is on can go back, and the
/// screen is not drawn inside another app.
class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) {
    if (_SurfaceDepth.inside(context)) return const SizedBox.shrink();
    final navigator = Navigator.maybeOf(context);
    if (navigator == null || !navigator.canPop()) {
      return const SizedBox.shrink();
    }
    return IconButton(
      onPressed: () => unawaited(navigator.maybePop()),
      icon: AppIcon(iconData: AppIcons.named['back']!, color: AppColors.ink),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final AppIconData? icon;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = chosen ? AppColors.accent : AppColors.ink2;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.s1,
        children: [
          if (icon case final icon?)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s1 / 2,
              ),
              decoration: BoxDecoration(
                color: chosen ? AppColors.accentSoft : Colors.transparent,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppSpacing.pillRadius),
                ),
              ),
              child: AppIcon(
                iconData: icon,
                size: AppSpacing.navIcon,
                color: ink,
              ),
            ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.label,
    required this.icon,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final AppIconData? icon;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = chosen ? AppColors.accent : AppColors.ink2;
    return Material(
      color: chosen ? AppColors.accentSoft : Colors.transparent,
      borderRadius: const BorderRadius.all(
        Radius.circular(AppSpacing.chipRadius),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(
          Radius.circular(AppSpacing.chipRadius),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s2,
          ),
          child: Row(
            spacing: AppSpacing.s3,
            children: [
              if (icon case final icon?)
                AppIcon(iconData: icon, size: AppSpacing.iconSmall, color: ink),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelStrong.copyWith(
                    color: chosen ? AppColors.ink : AppColors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
