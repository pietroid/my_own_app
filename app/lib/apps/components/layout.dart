part of '../app_renderer.dart';

/// Column, Row, List, Card, Tabs, Pages and Modal: what holds the rest.
extension on _Render {
  Widget column(Map<String, dynamic> c, _Scope scope, int depth) =>
      _tappable(c, scope, flow(c, scope, depth, horizontal: false));

  Widget row(Map<String, dynamic> c, _Scope scope, int depth) =>
      _tappable(c, scope, flow(c, scope, depth, horizontal: true));

  /// [c]'s children one after another, `gap` apart (default `md`): side by
  /// side when [horizontal] (sharing the width, unless `wrap` lets them
  /// run onto more lines), or one under the other.
  Widget flow(
    Map<String, dynamic> c,
    _Scope scope,
    int depth, {
    required bool horizontal,
  }) {
    final gap = step(c['gap'], scope) ?? AppSpacing.s3;
    final items = children(c, scope, depth);
    if (!horizontal) {
      return Column(
        mainAxisAlignment: _justify(c['justify']),
        crossAxisAlignment: _align(c['align'], CrossAxisAlignment.stretch),
        spacing: gap,
        children: items,
      );
    }
    if (value(c['wrap'], scope) == true) {
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      );
    }
    return Row(
      mainAxisAlignment: _justify(c['justify']),
      crossAxisAlignment: _align(c['align'], CrossAxisAlignment.center),
      spacing: gap,
      children: [
        for (final child in items)
          switch (child) {
            _Fixed() => child,
            _Grow() => Expanded(child: child),
            _Weighted(:final flex) => Expanded(flex: flex, child: child),
            _ => Expanded(child: child),
          },
      ],
    );
  }

  /// A Row or Column with an action is tapped whole (a row of a list).
  Widget _tappable(Map<String, dynamic> c, _Scope scope, Widget child) {
    if (!hasAction(c)) return child;
    return InkWell(
      borderRadius: const BorderRadius.all(
        Radius.circular(AppSpacing.chipRadius),
      ),
      onTap: () => fire(c, scope),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
        child: child,
      ),
    );
  }

  Widget list(Map<String, dynamic> c, _Scope scope, int depth) {
    final items = children(c, scope, depth);
    final gap = step(c['gap'], scope) ?? AppSpacing.s3;
    if (c['direction'] != 'horizontal') {
      // `divided`: a hairline between rows, as in a settings list.
      final divided = value(c['divided'], scope) == true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: divided ? 0 : gap,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (divided && i > 0) const Divider(height: AppSpacing.hairline),
            items[i],
          ],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: gap,
        children: [
          for (final item in items)
            SizedBox(width: AppSpacing.stripItemWidth, child: item),
        ],
      ),
    );
  }

  /// A raised surface around one `child`. `variant`: `outlined` (the
  /// default: a hairline), `filled` (a fill, no edge) or `accent` (the
  /// accent's soft colour, for the one thing that matters). `padding`
  /// (default `lg`), `background` and `radius` as any box.
  Widget card(Map<String, dynamic> c, _Scope scope, int depth) {
    final child = c['child'];
    final variant = value(c['variant'], scope);
    final background =
        paint(c['background'], scope) ??
        switch (variant) {
          'filled' => AppColors.fill,
          'accent' => AppColors.accentSoft,
          _ => AppColors.surface,
        };
    final border =
        edge(c['border'], scope) ??
        switch (variant) {
          'filled' => null,
          'accent' => AppColors.accent,
          _ => AppColors.line,
        };
    final shape = RoundedRectangleBorder(
      side: border == null ? BorderSide.none : BorderSide(color: border),
      borderRadius: BorderRadius.all(
        Radius.circular(corner(c['radius'], scope) ?? AppSpacing.cardRadius),
      ),
    );
    return Material(
      color: background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasAction(c) ? () => fire(c, scope) : null,
        child: Padding(
          padding: EdgeInsets.all(step(c['padding'], scope) ?? AppSpacing.s4),
          child: child is String
              ? build(child, scope, depth + 1)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget tabs(Map<String, dynamic> c, _Scope scope, int depth) {
    final tabs = [
      for (final tab in (c['tabs'] as List?) ?? const [])
        if (tab is Map && tab['child'] is String) tab,
    ];
    if (tabs.isEmpty) return const SizedBox.shrink();
    return _Tabs(
      titles: [for (final tab in tabs) string(tab['title'], scope)],
      icons: [
        for (final tab in tabs) AppIcons.named[string(tab['icon'], scope)],
      ],
      pills: value(c['variant'], scope) == 'pills',
      bound: c.containsKey('value') ? string(c['value'], scope) : null,
      onPick: (title) => edit(c['value'], scope, title),
      builder: (i) => build(tabs[i]['child'] as String, scope, depth + 1),
    );
  }

  Widget pages(Map<String, dynamic> c, _Scope scope, int depth) {
    final pages = c['pages'];
    if (pages is! Map || pages.isEmpty) return const SizedBox.shrink();
    final current = pages[string(c['current'], scope)] ?? pages.values.first;
    return build('$current', scope, depth + 1);
  }

  Widget modal(Map<String, dynamic> c, _Scope scope, int depth) {
    final content = c['content'];
    return _Modal(
      open: value(c['open'], scope) == true,
      onDismiss: () => edit(c['open'], scope, false),
      builder: (_) => content is String
          ? build(content, scope, depth + 1)
          : const SizedBox.shrink(),
    );
  }

  static MainAxisAlignment _justify(Object? value) => switch (value) {
    'center' => MainAxisAlignment.center,
    'end' => MainAxisAlignment.end,
    'spaceBetween' => MainAxisAlignment.spaceBetween,
    'spaceAround' => MainAxisAlignment.spaceAround,
    'spaceEvenly' => MainAxisAlignment.spaceEvenly,
    _ => MainAxisAlignment.start,
  };

  static CrossAxisAlignment _align(Object? value, CrossAxisAlignment or) =>
      switch (value) {
        'start' => CrossAxisAlignment.start,
        'center' => CrossAxisAlignment.center,
        'end' => CrossAxisAlignment.end,
        'stretch' => CrossAxisAlignment.stretch,
        _ => or,
      };
}

/// The tab strip and the open tab. The open one is [bound] when the app
/// keeps it in its data, or this widget's own otherwise.
class _Tabs extends StatefulWidget {
  const _Tabs({
    required this.titles,
    required this.icons,
    required this.pills,
    required this.bound,
    required this.onPick,
    required this.builder,
  });

  final List<String> titles;
  final List<AppIconData?> icons;

  /// Pills instead of the usual underlined strip.
  final bool pills;
  final String? bound;
  final ValueChanged<String> onPick;
  final Widget Function(int index) builder;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  var _own = 0;

  int get _open {
    final bound = widget.bound;
    final at = bound == null ? -1 : widget.titles.indexOf(bound);
    if (bound != null) return at == -1 ? 0 : at;
    return _own.clamp(0, widget.titles.length - 1);
  }

  void _pick(int i) {
    setState(() => _own = i);
    widget.onPick(widget.titles[i]);
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s3,
      children: [
        if (widget.pills)
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              for (var i = 0; i < widget.titles.length; i++)
                _Chip(
                  label: widget.titles[i],
                  chosen: i == open,
                  onTap: () => _pick(i),
                ),
            ],
          )
        else
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < widget.titles.length; i++)
                    _Tab(
                      label: widget.titles[i],
                      icon: widget.icons[i],
                      chosen: i == open,
                      onTap: () => _pick(i),
                    ),
                ],
              ),
            ),
          ),
        widget.builder(open),
      ],
    );
  }
}

/// A sheet over the screen while [open]; a tap outside it dismisses it.
class _Modal extends StatefulWidget {
  const _Modal({
    required this.open,
    required this.onDismiss,
    required this.builder,
  });

  final bool open;
  final VoidCallback onDismiss;
  final WidgetBuilder builder;

  @override
  State<_Modal> createState() => _ModalState();
}

class _ModalState extends State<_Modal> {
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    if (widget.open) _portal.show();
  }

  @override
  void didUpdateWidget(_Modal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Showing changes the overlay, which must not happen mid-build.
    if (widget.open != _portal.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.open ? _portal.show() : _portal.hide();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: const ColoredBox(color: AppColors.scrim),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height *
                    AppSpacing.sheetHeightFactor,
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: Material(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.cardRadius),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.s6),
                  child: widget.builder(context),
                ),
              ),
            ),
          ),
        ],
      ),
      child: const SizedBox.shrink(),
    );
  }
}

/// A pill that is picked or not: a tab, a choice.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.chosen, required this.onTap});

  final String label;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: chosen ? AppColors.accentSoft : AppColors.fill,
      shape: StadiumBorder(
        side: BorderSide(color: chosen ? AppColors.accent : AppColors.line),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s1,
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: chosen ? AppColors.accent : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab of an underlined strip: the open one in the accent, underlined.
class _Tab extends StatelessWidget {
  const _Tab({
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
    final ink = chosen ? AppColors.ink : AppColors.ink2;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s3,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: chosen ? AppColors.accent : Colors.transparent,
              width: AppSpacing.selectionOutline,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s2,
          children: [
            if (icon case final icon?)
              AppIcon(iconData: icon, size: AppSpacing.iconSmall, color: ink),
            Text(label, style: AppTypography.labelStrong.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}
