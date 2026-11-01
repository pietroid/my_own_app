import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The type tokens.
///
/// One face, Space Grotesk, across the whole app: a grotesque with
/// mono-derived quirks, technical with a wink. Weight and size carry the
/// hierarchy instead of a second family, and tracking tightens as the size
/// grows so a 36pt headline and a 12pt caption sit on the same optical rhythm.
abstract final class AppTypography {
  /// The only face. Every style in the app resolves through here.
  static TextStyle face({
    required double size,
    required FontWeight weight,
    double height = 1.3,
    double tracking = -0.01,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: size * tracking,
      color: color,
    );
  }

  /// 36/600. Billboard headings.
  static TextStyle get display =>
      face(size: 36, weight: FontWeight.w600, height: 1.05, tracking: -0.02);

  /// 24/600. Screen headings.
  static TextStyle get headline =>
      face(size: 24, weight: FontWeight.w600, height: 1.15, tracking: -0.02);

  /// 18/600. Section headers and the app bar.
  static TextStyle get title => face(size: 18, weight: FontWeight.w600);

  /// 16/400. The default: running text and input values.
  static TextStyle get body =>
      face(size: 16, weight: FontWeight.w400, height: 1.45);

  /// 16/600. Button labels, and a title with something written under it.
  ///
  /// The tighter line height comes with the weight: this sets one line that
  /// leads something else, not a paragraph.
  static TextStyle get bodyStrong =>
      face(size: 16, weight: FontWeight.w600, height: 1.25);

  /// 14/400. Labels, subtitles, and the prompt caption.
  static TextStyle get label =>
      face(size: 14, weight: FontWeight.w400, color: AppColors.ink2);

  /// 14/500. Chip and control labels.
  static TextStyle get labelStrong => face(size: 14, weight: FontWeight.w500);

  /// 12/500, tracked open (+4%). Captions and tab labels.
  static TextStyle get caption => face(
    size: 12,
    weight: FontWeight.w500,
    tracking: 0.04,
    color: AppColors.ink2,
  );

  /// The Material text theme, built from the scale above.
  static TextTheme get textTheme => TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: display,
    headlineLarge: headline,
    headlineMedium: headline,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: bodyStrong,
    titleSmall: labelStrong,
    bodyLarge: body,
    bodyMedium: label,
    bodySmall: caption,
    labelLarge: bodyStrong,
    labelMedium: labelStrong,
    labelSmall: caption,
  );
}
