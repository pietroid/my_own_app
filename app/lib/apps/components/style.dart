part of '../app_renderer.dart';

/// The box properties any component takes, and the components that are
/// only a box: Box, Grid, Spacer and Divider.
///
/// Every value names a token, never a number of pixels, so whatever an app
/// asks for stays on the design system's scale:
///
/// - `padding`, `gap`, `size`: `none`, `xs`, `sm`, `md`, `lg`, `xl`, `xxl`;
/// - `background`, `border`: `bg`, `surface`, `fill`, `fillStrong`, `line`,
///   `accent`, `accentSoft`, `positive(Soft)`, `negative(Soft)`,
///   `warning(Soft)`, `ink`, `muted` (`border: true` is a hairline);
/// - `radius`: `none`, `sm`, `md`, `lg`, `xl`, `pill`;
/// - `width`: `sm`, `md`, `lg` (a side pane's), `fill`, or a number;
///   `height`: a number.
extension on _Render {
  /// Draw their own padding and background from these properties.
  static const _ownBox = {'Box', 'Card', 'Panel', 'Screen', 'Callout'};

  /// A step of the spacing scale, or null when [bound] names none.
  double? step(Object? bound, _Scope scope) => switch (value(bound, scope)) {
    'none' => 0,
    'xs' => AppSpacing.s1,
    'sm' => AppSpacing.s2,
    'md' => AppSpacing.s3,
    'lg' => AppSpacing.s4,
    'xl' => AppSpacing.s6,
    'xxl' => AppSpacing.s8,
    _ => null,
  };

  /// A colour token by name, or null when [bound] names none.
  Color? paint(Object? bound, _Scope scope) => switch (value(bound, scope)) {
    'none' || 'transparent' => Colors.transparent,
    'bg' => AppColors.bg,
    'surface' => AppColors.surface,
    'fill' => AppColors.fill,
    'fillStrong' => AppColors.fillStrong,
    'line' => AppColors.line,
    'accent' => AppColors.accent,
    'accentSoft' => AppColors.accentSoft,
    'positive' => AppColors.positive,
    'positiveSoft' => AppColors.positiveSoft,
    'negative' => AppColors.negative,
    'negativeSoft' => AppColors.negativeSoft,
    'warning' => AppColors.warning,
    'warningSoft' => AppColors.warningSoft,
    'ink' => AppColors.ink,
    'muted' => AppColors.ink2,
    _ => null,
  };

  /// A corner radius by name, or null when [bound] names none.
  double? corner(Object? bound, _Scope scope) => switch (value(bound, scope)) {
    'none' => 0,
    'sm' => AppSpacing.buttonRadius,
    'md' => AppSpacing.chipRadius,
    'lg' => AppSpacing.cardRadius,
    'xl' => AppSpacing.bubbleRadius,
    'pill' || 'circle' => AppSpacing.pillRadius,
    _ => null,
  };

  /// The hairline [bound] asks for: `true` for the usual one, or a colour.
  Color? edge(Object? bound, _Scope scope) {
    final v = value(bound, scope);
    if (v == true) return AppColors.line;
    return paint(v, scope);
  }

  /// A width by name or number, or null.
  double? breadth(Object? bound, _Scope scope) => switch (value(bound, scope)) {
    'sm' => AppSpacing.paneSmall,
    'md' => AppSpacing.paneMedium,
    'lg' => AppSpacing.paneLarge,
    'fill' => double.infinity,
    final num n when n > 0 => n.toDouble(),
    _ => null,
  };

  /// [child] inside the box [c]'s properties describe.
  Widget styled(Map<String, dynamic> c, _Scope scope, Widget child) {
    final own = _ownBox.contains(c['component']);
    final pad = own ? null : step(c['padding'], scope);
    final background = own ? null : paint(c['background'], scope);
    final border = own ? null : edge(c['border'], scope);
    final width = breadth(c['width'], scope);
    final height = value(c['height'], scope);

    var drawn = child;
    if (pad != null && pad > 0) {
      drawn = Padding(padding: EdgeInsets.all(pad), child: drawn);
    }
    if (background != null || border != null) {
      final radius = corner(c['radius'], scope) ?? AppSpacing.chipRadius;
      drawn = Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: background,
          border: border == null ? null : Border.all(color: border),
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
        child: drawn,
      );
    }
    if (width != null || (height is num && height > 0)) {
      drawn = SizedBox(
        width: width,
        height: height is num && height > 0 ? height.toDouble() : null,
        child: drawn,
      );
    }
    return drawn;
  }

  /// A shape with something in it: a panel's section, a chip, a bubble, a
  /// circle. `child`, or `children` laid out as a Column (`direction`:
  /// `row` for a Row) with `gap`, `justify` and `align`. `shape`:
  /// `rounded` (the default, `radius` to change it), `pill`, `circle`,
  /// `square`, `bubbleStart` or `bubbleEnd` (a chat bubble, its tight
  /// corner on that side). `background` (default `fill`), `border`,
  /// `padding` (default `md`), `center` (the content in the middle). With
  /// `action`, the whole box is tapped.
  Widget box(Map<String, dynamic> c, _Scope scope, int depth) {
    final background = paint(c['background'], scope) ?? AppColors.fill;
    final border = edge(c['border'], scope);
    final side = border == null ? BorderSide.none : BorderSide(color: border);
    final radius = corner(c['radius'], scope) ?? AppSpacing.cardRadius;
    const round = Radius.circular(AppSpacing.bubbleRadius);
    const tail = Radius.circular(AppSpacing.bubbleTail);
    final shape = switch (value(c['shape'], scope)) {
      'circle' => CircleBorder(side: side),
      'pill' => StadiumBorder(side: side),
      'square' => Border.fromBorderSide(side),
      'bubbleStart' => RoundedRectangleBorder(
        side: side,
        borderRadius: const BorderRadius.only(
          topLeft: round,
          topRight: round,
          bottomRight: round,
          bottomLeft: tail,
        ),
      ),
      'bubbleEnd' => RoundedRectangleBorder(
        side: side,
        borderRadius: const BorderRadius.only(
          topLeft: round,
          topRight: round,
          bottomLeft: round,
          bottomRight: tail,
        ),
      ),
      _ => RoundedRectangleBorder(
        side: side,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      ),
    };

    final child = c['child'];
    var content = c['children'] != null
        ? flow(c, scope, depth, horizontal: c['direction'] == 'row')
        : child is String
        ? build(child, scope, depth + 1)
        : const SizedBox.shrink();
    if (value(c['center'], scope) == true) content = Center(child: content);

    return Material(
      color: background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: shape,
        onTap: hasAction(c) ? () => fire(c, scope) : null,
        child: Padding(
          padding: EdgeInsets.all(step(c['padding'], scope) ?? AppSpacing.s3),
          child: content,
        ),
      ),
    );
  }

  /// Tiles in rows of `columns` (a number; by default as many as fit at
  /// `AppSpacing.paneSmall` each), `gap` apart: a gallery, a dashboard.
  Widget grid(Map<String, dynamic> c, _Scope scope, int depth) {
    final items = children(c, scope, depth);
    final gap = step(c['gap'], scope) ?? AppSpacing.s3;
    final asked = value(c['columns'], scope);
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        final count = asked is num && asked >= 1
            ? asked.toInt()
            : room.isFinite
            ? ((room + gap) / (AppSpacing.paneSmall + gap)).floor().clamp(1, 6)
            : 2;
        final tile = room.isFinite
            ? (room - gap * (count - 1)) / count
            : AppSpacing.paneSmall;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items) SizedBox(width: tile, child: item),
          ],
        );
      },
    );
  }

  /// Room: `size` (a step) of it; with none, inside a Row, all that is left.
  Widget spacer(Map<String, dynamic> c, _Scope scope) {
    final size = step(c['size'], scope) ?? AppSpacing.s4;
    return SizedBox(width: size, height: size);
  }

  /// A hairline: `vertical` inside a Row, `label` for one in the middle.
  Widget divider(Map<String, dynamic> c, _Scope scope) {
    if (value(c['vertical'], scope) == true) {
      return const SizedBox(
        height: AppSpacing.s6,
        child: VerticalDivider(width: AppSpacing.s3),
      );
    }
    final label = string(c['label'], scope);
    if (label.isEmpty) return const Divider(height: AppSpacing.s3);
    return Row(
      spacing: AppSpacing.s3,
      children: [
        const Expanded(child: Divider()),
        Text(label, style: AppTypography.caption),
        const Expanded(child: Divider()),
      ],
    );
  }
}
