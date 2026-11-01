/// The spacing, radius, and sizing tokens.
///
/// One 4pt grid, so every gap, pad, and corner in the app comes from the same
/// scale. Nothing hard-codes a number that could have come from here. The
/// shape is sharp and dense: small corners, hairlines instead of shadows.
abstract final class AppSpacing {
  /// 4pt. Hairline gaps, icon-to-label inside a dense control.
  static const s1 = 4.0;

  /// 8pt. The gap between tightly related elements.
  static const s2 = 8.0;

  /// 12pt. Control padding and list row gaps.
  static const s3 = 12.0;

  /// 16pt. The default gutter.
  static const s4 = 16.0;

  /// 20pt. The field and card pad.
  static const s5 = 20.0;

  /// 24pt. The screen gutter.
  static const s6 = 24.0;

  /// 32pt. The gap between sections.
  static const s8 = 32.0;

  /// 48pt. The gap between a heading and the block it introduces.
  static const s12 = 48.0;

  /// 64pt. Hero breathing room.
  static const s16 = 64.0;

  /// The corner radius of a card or a sheet.
  static const cardRadius = 8.0;

  /// The corner radius of a chip, a menu, or an inline surface.
  static const chipRadius = 6.0;

  /// The corner radius of a button and a small control.
  static const buttonRadius = 4.0;

  /// A fully rounded corner, for pills and tap targets.
  static const pillRadius = 999.0;

  /// The minimum tap target, per Fitts's law.
  static const tapTarget = 44.0;

  /// The height of the app's single-line prompt field.
  static const fieldHeight = 44.0;

  /// The width of a hairline: the edge of a panel, a field, or the app bar
  /// (Flutter's default `BorderSide` width), and the lines of the build grid.
  static const hairline = 1.0;

  /// The cell of the faint build grid behind the sign-in (`AppBuildGrid`).
  static const gridCell = 24.0;

  /// The side of one block in the assistant's typing indicator.
  static const typingBlock = 6.0;

  /// The default icon size.
  static const iconSize = 24.0;

  /// The widest a content column ever gets, so text stays readable on web.
  static const maxContentWidth = 560.0;
}
