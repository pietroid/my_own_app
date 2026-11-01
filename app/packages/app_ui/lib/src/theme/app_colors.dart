import 'package:flutter/material.dart';

/// The color tokens.
///
/// A neutral ramp and one accent: the template's placeholder look, meant to
/// be replaced by the app's own (`/design-system`). Screens only ever read
/// these names, so changing a value restyles every screen at once; a value a
/// screen needs that is not here becomes a new token, never a literal.
abstract final class AppColors {
  /// The page background behind every screen.
  static const bg = Color(0xFFFFFFFF);

  /// The surface a sheet, a menu, or a dialog sits on.
  static const surface = Color(0xFFFFFFFF);

  /// The borderless fill that gives a field or a card its shape.
  static const fill = Color(0xFFF4F4F5);

  /// A heavier [fill], for pressed states, tracks, and inactive bars.
  static const fillStrong = Color(0xFFE4E4E7);

  /// Hairline separators.
  static const line = Color(0xFFE4E4E7);

  /// Text primary.
  static const ink = Color(0xFF18181B);

  /// Text secondary: labels, captions, and subtitles.
  static const ink2 = Color(0xFF71717A);

  /// Text tertiary: placeholders and disabled labels.
  static const ink3 = Color(0xFFA1A1AA);

  /// The one colour for what can be acted on.
  static const accent = Color(0xFF4F46E5);

  /// What is drawn on [accent].
  static const onAccent = Color(0xFFFFFFFF);

  /// A pale [accent], behind something selected or the person's own words.
  static const accentSoft = Color(0xFFEEF2FF);

  /// Something went well.
  static const positive = Color(0xFF16A34A);

  /// Something went wrong.
  static const negative = Color(0xFFDC2626);
}
