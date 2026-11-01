import 'package:app_ui/app_ui.dart';

/// How much weight a button carries.
enum AppButtonVariant {
  /// A filled button in the action's colour. The one thing to tap.
  primary,

  /// An outlined button on the page background, for a real alternative.
  secondary,

  /// Text only, for the action someone takes when they want none of the above.
  tertiary,
}

/// {@template app_button}
/// The app's button.
///
/// Three tiers, and the difference between them is weight rather than hue: a
/// primary button fills with its colour, a secondary outlines in it, a
/// tertiary only tints its label. Put three of them side by side and the order
/// to read them in is obvious before a single word has been.
/// {@endtemplate}
class AppButton extends StatelessWidget {
  /// {@macro app_button}
  const AppButton({
    required this.onPressed,
    required this.text,
    this.variant = AppButtonVariant.primary,
    this.color = AppColors.accent,
    this.expand = false,
    this.icon,
    super.key,
  });

  /// {@template app_button_icon}
  /// Button variant that displays an icon before the label, for sign-in
  /// providers and other actions carrying a mark.
  /// {@endtemplate}
  const AppButton.icon({
    required this.onPressed,
    required this.icon,
    required this.text,
    this.variant = AppButtonVariant.primary,
    this.color = AppColors.accent,
    this.expand = false,
    super.key,
  });

  /// {@template app_button_text}
  /// Button variant with no fill, for low-emphasis actions.
  /// {@endtemplate}
  const AppButton.text({
    required this.onPressed,
    required this.text,
    this.color = AppColors.accent,
    this.expand = false,
    super.key,
  }) : icon = null,
       variant = AppButtonVariant.tertiary;

  /// Called when the button is tapped. A null value disables the button.
  final VoidCallback? onPressed;

  /// Optional icon displayed before the text.
  final Widget? icon;

  /// Text content displayed inside the button.
  final String text;

  /// How much weight the button carries.
  final AppButtonVariant variant;

  /// The action's colour. Defaults to the accent.
  final Color color;

  /// Whether the button stretches to the width of its parent.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    // Disabled states drop to the neutral ramp rather than to a faded colour,
    // so a greyed-out destructive button does not still read as red.
    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary =>
        enabled
            ? (color, _onColor(color), Colors.transparent)
            : (AppColors.fillStrong, AppColors.ink3, Colors.transparent),
      AppButtonVariant.secondary =>
        enabled
            ? (Colors.transparent, color, color.withValues(alpha: 0.45))
            : (Colors.transparent, AppColors.ink3, AppColors.line),
      AppButtonVariant.tertiary => (
        Colors.transparent,
        enabled ? AppColors.ink2 : AppColors.ink3,
        Colors.transparent,
      ),
    };

    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodyStrong.copyWith(color: foreground),
    );

    final child = icon == null
        ? label
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: foreground, size: AppSpacing.s5),
                child: icon!,
              ),
              const SizedBox(width: AppSpacing.s2),
              // A narrow button cuts its label rather than overflowing.
              Flexible(child: label),
            ],
          );

    final style = FilledButton.styleFrom(
      backgroundColor: background,
      disabledBackgroundColor: background,
      minimumSize: Size(expand ? double.infinity : 0, AppSpacing.tapTarget),
      padding: EdgeInsets.symmetric(
        horizontal: variant == AppButtonVariant.tertiary
            ? AppSpacing.s4
            : AppSpacing.s5,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(AppSpacing.buttonRadius),
        ),
        side: border == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: border),
      ),
    );

    return FilledButton(onPressed: onPressed, style: style, child: child);
  }

  /// Black or white, whichever stays readable on [background]: the
  /// accent's own [AppColors.onAccent], and by luminance for any other fill.
  static Color _onColor(Color background) {
    if (background == AppColors.accent) return AppColors.onAccent;
    return background.computeLuminance() > 0.5
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
  }
}
