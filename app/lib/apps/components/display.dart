part of '../app_renderer.dart';

/// Text, Icon, Image, Badge and Message: what only shows.
extension on _Render {
  Widget text(Map<String, dynamic> c, _Scope scope) {
    final style = switch (c['variant']) {
      'h1' => AppTypography.display,
      'h2' || 'title' => AppTypography.headline,
      'h3' => AppTypography.title,
      'caption' => AppTypography.caption,
      _ => AppTypography.body,
    };
    return Text(
      string(c['text'], scope),
      style: style.copyWith(color: tone(c['tone'], scope, style.color!)),
    );
  }

  Widget icon(Map<String, dynamic> c, _Scope scope) {
    final name = string(c['name'], scope);
    // `component:Text`: a component type's own icon, for an editor's tree.
    final data = name.startsWith('component:')
        ? AppIcons.components[name.substring('component:'.length)]
        : AppIcons.named[name];
    if (data == null) return const SizedBox.shrink();
    return AppIcon(
      iconData: data,
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
            borderRadius: const BorderRadius.all(
              Radius.circular(AppSpacing.cardRadius),
            ),
            child: sized,
          );
  }

  Widget badge(Map<String, dynamic> c, _Scope scope) {
    final color = tone(c['tone'], scope, AppColors.ink2);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1 / 2,
      ),
      decoration: ShapeDecoration(
        color: AppColors.fill,
        shape: StadiumBorder(side: BorderSide(color: color)),
      ),
      child: Text(
        string(c['text'], scope),
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }

  Widget message(Map<String, dynamic> c, _Scope scope) {
    final mine = value(c['role'], scope) == 'me';
    final caption = string(c['caption'], scope);
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * AppSpacing.messageWidthFactor,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              color: mine ? AppColors.accentSoft : AppColors.fill,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppSpacing.cardRadius),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.s1,
              children: [
                Text(string(c['text'], scope), style: AppTypography.body),
                if (caption.isNotEmpty)
                  Text(caption, style: AppTypography.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
