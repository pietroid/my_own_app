part of '../app_renderer.dart';

/// What is under the pointer while a screen is picked from: of every
/// component the pointer is over, the innermost one, so only it is
/// outlined (the way a design tool shows what a click would pick).
class _Hover extends ValueNotifier<_SelectableState?> {
  _Hover() : super(null);

  final _over = <_SelectableState>{};

  void enter(_SelectableState state) {
    _over.add(state);
    _settle();
  }

  void exit(_SelectableState state) {
    _over.remove(state);
    _settle();
  }

  void _settle() {
    _SelectableState? top;
    for (final state in _over) {
      if (top == null || state.widget.depth > top.widget.depth) top = state;
    }
    value = top;
  }
}

/// Keeps one [_Hover] for as long as a screen is picked from, across the
/// rebuilds of its renderer.
class _HoverScope extends StatefulWidget {
  const _HoverScope({required this.builder});

  final Widget Function(_Hover hover) builder;

  @override
  State<_HoverScope> createState() => _HoverScopeState();
}

class _HoverScopeState extends State<_HoverScope> {
  final _hover = _Hover();

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_hover);
}

/// A component on a screen being inspected: outlined and named when it is
/// the picked one, or (while picking) the one under the pointer.
class _Selectable extends StatefulWidget {
  const _Selectable({
    required this.id,
    required this.type,
    required this.depth,
    required this.selected,
    required this.hover,
    required this.absorb,
    required this.onTap,
    required this.child,
  });

  final String id;
  final String type;
  final int depth;
  final bool selected;

  /// Null when the screen is only shown with its selection, not picked from.
  final _Hover? hover;
  final bool absorb;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_Selectable> createState() => _SelectableState();
}

class _SelectableState extends State<_Selectable> {
  @override
  void initState() {
    super.initState();
    widget.hover?.addListener(_changed);
  }

  @override
  void didUpdateWidget(_Selectable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hover != widget.hover) {
      oldWidget.hover?.removeListener(_changed);
      widget.hover?.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.hover?.removeListener(_changed);
    widget.hover?.exit(this);
    super.dispose();
  }

  var _hovered = false;

  void _changed() {
    final now = widget.hover?.value == this;
    if (now != _hovered && mounted) setState(() => _hovered = now);
  }

  @override
  Widget build(BuildContext context) {
    final hover = widget.hover;
    final marked = widget.selected || _hovered;
    final drawn = Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        if (hover != null && widget.absorb)
          AbsorbPointer(child: widget.child)
        else
          widget.child,
        if (marked)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.selected ? null : AppColors.accentHalo,
                  border: Border.all(
                    color: AppColors.accent,
                    width: widget.selected
                        ? AppSpacing.selectionOutline
                        : AppSpacing.hairline,
                  ),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppSpacing.buttonRadius),
                  ),
                ),
              ),
            ),
          ),
        if (marked)
          Positioned(
            left: 0,
            top: -AppSpacing.selectionTag,
            child: IgnorePointer(
              child: _SelectionTag(
                id: widget.id,
                type: widget.type,
                solid: widget.selected,
              ),
            ),
          ),
      ],
    );
    if (hover == null) return drawn;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => hover.enter(this),
      onExit: (_) => hover.exit(this),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: drawn,
      ),
    );
  }
}

/// The name over an outlined component: its type's icon and its id.
class _SelectionTag extends StatelessWidget {
  const _SelectionTag({
    required this.id,
    required this.type,
    required this.solid,
  });

  final String id;
  final String type;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final ink = solid ? AppColors.onAccent : AppColors.accent;
    final icon = AppIcons.components[type];
    return Container(
      height: AppSpacing.selectionTag,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s1),
      decoration: BoxDecoration(
        color: solid ? AppColors.accent : AppColors.surface,
        border: solid ? null : Border.all(color: AppColors.accent),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.buttonRadius),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.s1,
        children: [
          if (icon != null)
            AppIcon(
              iconData: icon,
              size: AppSpacing.selectionTagIcon,
              color: ink,
            ),
          Text(id, style: AppTypography.caption.copyWith(color: ink)),
        ],
      ),
    );
  }
}
