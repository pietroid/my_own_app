part of '../app_renderer.dart';

/// Text, Icon, Image, Badge, Message, ListItem, Avatar, Progress, Stat,
/// Callout and EmptyState: what mostly shows.
extension on _Render {
  /// `text`; `variant` `h1`, `h2`, `h3`, `body`, `strong`, `label` or
  /// `caption`; `tone`; `textAlign` (`start`, `center`, `end`); `maxLines`.
  Widget text(Map<String, dynamic> c, _Scope scope) {
    final style = switch (value(c['variant'], scope)) {
      'h1' => AppTypography.display,
      'h2' || 'title' => AppTypography.headline,
      'h3' => AppTypography.title,
      'strong' => AppTypography.bodyStrong,
      'label' => AppTypography.label,
      'caption' => AppTypography.caption,
      _ => AppTypography.body,
    };
    final lines = value(c['maxLines'], scope);
    return Text(
      string(c['text'], scope),
      maxLines: lines is num && lines > 0 ? lines.toInt() : null,
      overflow: lines is num && lines > 0 ? TextOverflow.ellipsis : null,
      textAlign: switch (value(c['textAlign'], scope)) {
        'center' => TextAlign.center,
        'end' => TextAlign.end,
        _ => TextAlign.start,
      },
      style: style.copyWith(color: tone(c['tone'], scope, style.color!)),
    );
  }

  /// The size a `size` names: `sm`, `md` (the default) or `lg`.
  double iconSize(Object? bound, _Scope scope) => switch (value(bound, scope)) {
    'sm' => AppSpacing.iconSmall,
    'lg' => AppSpacing.iconLarge,
    _ => AppSpacing.iconSize,
  };

  Widget icon(Map<String, dynamic> c, _Scope scope) {
    final name = string(c['name'], scope);
    // `component:Text`: a component type's own icon, for an editor's tree.
    final data = name.startsWith('component:')
        ? AppIcons.components[name.substring('component:'.length)]
        : AppIcons.named[name];
    if (data == null) return const SizedBox.shrink();
    return AppIcon(
      iconData: data,
      size: iconSize(c['size'], scope),
      color: tone(c['tone'], scope, AppColors.ink2),
    );
  }

  Widget image(Map<String, dynamic> c, _Scope scope) {
    final url = string(c['url'], scope);
    final variant = c['variant'];
    final size = switch (variant) {
      'avatar' => AppSpacing.imageAvatar,
      'icon' => AppSpacing.iconSize,
      'smallFeature' => AppSpacing.imageSmall,
      'mediumFeature' => AppSpacing.imageMedium,
      'largeFeature' => AppSpacing.imageLarge,
      _ => null,
    };
    final fit = switch (c['fit']) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'none' => BoxFit.none,
      'scaleDown' => BoxFit.scaleDown,
      _ => BoxFit.cover,
    };
    const blank = ColoredBox(color: AppColors.fill);
    final picture = url.startsWith('https://')
        ? Image.network(
            url,
            fit: fit,
            semanticLabel: string(c['description'], scope),
            errorBuilder: (_, _, _) => blank,
          )
        : blank;
    final sized = SizedBox(
      width: size,
      height: size ?? AppSpacing.imageHeader,
      child: picture,
    );
    return variant == 'avatar'
        ? ClipOval(child: sized)
        : ClipRRect(
            borderRadius: BorderRadius.all(
              Radius.circular(
                corner(c['radius'], scope) ?? AppSpacing.cardRadius,
              ),
            ),
            child: sized,
          );
  }

  /// A small pill: `text`, `tone`, optional `icon`. `variant` `soft` (the
  /// default: the tone's soft colour), `solid` or `outline`.
  Widget badge(Map<String, dynamic> c, _Scope scope) {
    final variant = value(c['variant'], scope);
    final color = tone(c['tone'], scope, AppColors.ink2);
    final solid = variant == 'solid';
    final ink = solid ? AppColors.onAccent : color;
    final icon = AppIcons.named[string(c['icon'], scope)];
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1 / 2,
      ),
      decoration: ShapeDecoration(
        color: solid
            ? color
            : variant == 'outline'
            ? Colors.transparent
            : soft(c['tone'], scope),
        shape: StadiumBorder(
          side: variant == 'outline'
              ? BorderSide(color: color)
              : BorderSide.none,
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
          Text(
            string(c['text'], scope),
            style: AppTypography.caption.copyWith(color: ink),
          ),
        ],
      ),
    );
  }

  /// A chat bubble: `text`, `role` (`me` on the end, `other` on the start,
  /// `system` a line in the middle), optional `name` over it and `caption`
  /// under it.
  Widget message(Map<String, dynamic> c, _Scope scope) {
    final role = value(c['role'], scope);
    final caption = string(c['caption'], scope);
    if (role == 'system') {
      return Center(
        child: Text(
          string(c['text'], scope),
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
      );
    }
    final mine = role == 'me';
    final name = string(c['name'], scope);
    const round = Radius.circular(AppSpacing.bubbleRadius);
    const tail = Radius.circular(AppSpacing.bubbleTail);
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * AppSpacing.messageWidthFactor,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            spacing: AppSpacing.s1,
            children: [
              if (name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                  ),
                  child: Text(name, style: AppTypography.caption),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                decoration: BoxDecoration(
                  color: mine ? AppColors.accentSoft : AppColors.fill,
                  borderRadius: BorderRadius.only(
                    topLeft: round,
                    topRight: round,
                    bottomLeft: mine ? round : tail,
                    bottomRight: mine ? tail : round,
                  ),
                ),
                child: Text(
                  string(c['text'], scope),
                  style: AppTypography.body,
                ),
              ),
              if (caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                  ),
                  child: Text(caption, style: AppTypography.caption),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// One row of a list, as a real app draws it: `icon` (on a tile) or
  /// `avatar` (a name or an https url) at the start, `title`, `subtitle`,
  /// `meta` (a short text at the end: a time, a price), `trailing` (ids:
  /// a Switch, a Badge, a Button), `chevron` (an arrow: it opens
  /// something), `selected` (drawn picked), `dense` (a tighter row, the
  /// icon without its tile). With `action`, the whole row is tapped.
  Widget listItem(Map<String, dynamic> c, _Scope scope, int depth) {
    final selected = value(c['selected'], scope) == true;
    final dense = value(c['dense'], scope) == true;
    final icon =
        AppIcons.named[string(c['icon'], scope)] ??
        (string(c['icon'], scope).startsWith('component:')
            ? AppIcons.components[string(
                c['icon'],
                scope,
              ).substring('component:'.length)]
            : null);
    final avatarOf = string(c['avatar'], scope);
    final subtitle = string(c['subtitle'], scope);
    final meta = string(c['meta'], scope);
    final ink = selected ? AppColors.accent : AppColors.ink2;
    final iconColor = tone(c['tone'], scope, ink);

    final Widget? lead = avatarOf.isNotEmpty
        ? _Avatar(
            text: avatarOf,
            size: dense ? AppSpacing.avatarSmall : AppSpacing.imageAvatar,
            color: AppColors.accent,
            background: AppColors.accentSoft,
          )
        : icon == null
        ? null
        : dense
        ? AppIcon(iconData: icon, size: AppSpacing.iconSmall, color: iconColor)
        : Container(
            width: AppSpacing.iconTile,
            height: AppSpacing.iconTile,
            decoration: BoxDecoration(
              color: selected ? AppColors.bg : AppColors.fill,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppSpacing.chipRadius),
              ),
            ),
            child: Center(
              child: AppIcon(
                iconData: icon,
                size: AppSpacing.navIcon,
                color: iconColor,
              ),
            ),
          );

    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppSpacing.chipRadius)),
    );
    return Material(
      color: selected ? AppColors.accentSoft : Colors.transparent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: hasAction(c) ? () => fire(c, scope) : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? AppSpacing.s2 : AppSpacing.s3,
            vertical: dense ? AppSpacing.s2 : AppSpacing.s3,
          ),
          child: Row(
            spacing: dense ? AppSpacing.s2 : AppSpacing.s3,
            children: [
              ?lead,
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      string(c['title'], scope),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (dense ? AppTypography.label : AppTypography.body)
                          .copyWith(
                            color: selected ? AppColors.accent : AppColors.ink,
                          ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                  ],
                ),
              ),
              if (meta.isNotEmpty) Text(meta, style: AppTypography.caption),
              ...trailing(c, scope, depth),
              if (value(c['chevron'], scope) == true)
                const AppIcon(
                  iconData: AppIcons.open,
                  size: AppSpacing.iconSmall,
                  color: AppColors.ink3,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A person or a thing as a circle: `name` (its initials) or `url` (an
  /// https picture), `size` (`sm`, `md`, `lg`), `tone`.
  Widget avatar(Map<String, dynamic> c, _Scope scope) {
    final size = switch (value(c['size'], scope)) {
      'sm' => AppSpacing.avatarSmall,
      'lg' => AppSpacing.avatarLarge,
      _ => AppSpacing.imageAvatar,
    };
    final url = string(c['url'], scope);
    if (url.startsWith('https://')) {
      return ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.fill),
          ),
        ),
      );
    }
    return _Avatar(
      text: string(c['name'], scope),
      size: size,
      color: tone(c['tone'], scope, AppColors.accent),
      background: soft(c['tone'] ?? 'accent', scope),
    );
  }

  /// How far along: `value` (0 to 1, or to `max`), `label`, `tone`, and
  /// `showValue` (the percentage at the end of the label).
  Widget progress(Map<String, dynamic> c, _Scope scope) {
    final raw = (value(c['value'], scope) as num?)?.toDouble() ?? 0;
    final max = (value(c['max'], scope) as num?)?.toDouble() ?? 1;
    final share = max <= 0 ? 0.0 : (raw / max).clamp(0.0, 1.0);
    final label = string(c['label'], scope);
    final percent = value(c['showValue'], scope) == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s1,
      children: [
        if (label.isNotEmpty || percent)
          Row(
            children: [
              Expanded(child: Text(label, style: AppTypography.label)),
              if (percent)
                Text(
                  '${(share * 100).round()}%',
                  style: AppTypography.caption,
                ),
            ],
          ),
        ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppSpacing.pillRadius),
          ),
          child: LinearProgressIndicator(
            value: share,
            minHeight: AppSpacing.progressHeight,
            color: tone(c['tone'], scope, AppColors.accent),
            backgroundColor: AppColors.fillStrong,
          ),
        ),
      ],
    );
  }

  /// A number that matters: `label`, `value`, `caption` (under it, in
  /// `tone`), `icon`, `trend` (`up` or `down`: an arrow by the caption).
  Widget stat(Map<String, dynamic> c, _Scope scope) {
    final icon = AppIcons.named[string(c['icon'], scope)];
    final caption = string(c['caption'], scope);
    final trend = switch (value(c['trend'], scope)) {
      'up' => AppIcons.named['trendUp'],
      'down' => AppIcons.named['trendDown'],
      _ => null,
    };
    final color = tone(c['tone'], scope, AppColors.ink2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.s1,
      children: [
        Row(
          spacing: AppSpacing.s1,
          children: [
            if (icon != null)
              AppIcon(
                iconData: icon,
                size: AppSpacing.iconSmall,
                color: AppColors.ink2,
              ),
            Flexible(
              child: Text(
                string(c['label'], scope),
                style: AppTypography.label,
              ),
            ),
          ],
        ),
        Text(string(c['value'], scope), style: AppTypography.headline),
        if (caption.isNotEmpty || trend != null)
          Row(
            spacing: AppSpacing.s1,
            children: [
              if (trend != null)
                AppIcon(
                  iconData: trend,
                  size: AppSpacing.iconSmall,
                  color: color,
                ),
              Flexible(
                child: Text(
                  caption,
                  style: AppTypography.caption.copyWith(color: color),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// A note that stands out: `tone` (`accent`, the default, `positive`,
  /// `negative`, `warning`, `muted`), `icon` (one by tone otherwise),
  /// `title`, `text`, `trailing` (ids: a button).
  Widget callout(Map<String, dynamic> c, _Scope scope, int depth) {
    final kind = value(c['tone'], scope) ?? 'accent';
    final color = tone(kind, scope, AppColors.accent);
    final icon =
        AppIcons.named[string(c['icon'], scope)] ??
        AppIcons.named[switch (kind) {
          'positive' => 'checkCircle',
          'negative' || 'warning' => 'warning',
          _ => 'info',
        }]!;
    final title = string(c['title'], scope);
    final body = string(c['text'], scope);
    return Container(
      padding: EdgeInsets.all(step(c['padding'], scope) ?? AppSpacing.s3),
      decoration: BoxDecoration(
        color: paint(c['background'], scope) ?? soft(kind, scope),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppSpacing.cardRadius),
        ),
      ),
      child: Row(
        spacing: AppSpacing.s3,
        children: [
          AppIcon(iconData: icon, color: color),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(title, style: AppTypography.bodyStrong),
                if (body.isNotEmpty)
                  Text(
                    body,
                    style: AppTypography.label.copyWith(color: AppColors.ink),
                  ),
              ],
            ),
          ),
          ...trailing(c, scope, depth),
        ],
      ),
    );
  }

  /// What a list shows when it has nothing: `icon`, `title`, `text`, and
  /// `trailing` (ids: the button that fills it).
  Widget emptyState(Map<String, dynamic> c, _Scope scope, int depth) {
    final icon = AppIcons.named[string(c['icon'], scope)];
    final text = string(c['text'], scope);
    final tools = trailing(c, scope, depth);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.s3,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s4),
              decoration: const BoxDecoration(
                color: AppColors.fill,
                shape: BoxShape.circle,
              ),
              child: AppIcon(
                iconData: icon,
                size: AppSpacing.iconLarge,
                color: AppColors.ink2,
              ),
            ),
          Text(
            string(c['title'], scope),
            textAlign: TextAlign.center,
            style: AppTypography.title,
          ),
          if (text.isNotEmpty)
            Text(text, textAlign: TextAlign.center, style: AppTypography.label),
          if (tools.isNotEmpty) Wrap(spacing: AppSpacing.s2, children: tools),
        ],
      ),
    );
  }
}

/// A circle with a name's initials in it.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.text,
    required this.size,
    required this.color,
    required this.background,
  });

  final String text;
  final double size;
  final Color color;
  final Color background;

  String get _initials {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        _initials,
        style:
            (size >= AppSpacing.imageAvatar
                    ? AppTypography.labelStrong
                    : AppTypography.caption)
                .copyWith(color: color),
      ),
    );
  }
}
