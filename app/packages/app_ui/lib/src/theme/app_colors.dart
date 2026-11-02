import 'package:flutter/material.dart';

/// The color tokens.
///
/// A dark graphite workbench and one signal orange. The neutrals carry
/// almost no hue, so the apps built inside My Own App can bring their own
/// colour; orange only ever means "this can be acted on" or a state. Screens
/// only ever read these names, so changing a value restyles every screen at
/// once; a value a screen needs that is not here becomes a new token, never a
/// literal.
abstract final class AppColors {
  /// The page background behind every screen.
  static const bg = Color(0xFF121214);

  /// The surface a sheet, a menu, a dialog or a panel sits on: one step up
  /// from [bg], usually edged with a [line].
  static const surface = Color(0xFF19191C);

  /// The fill that gives a field or a card its shape.
  static const fill = Color(0xFF202024);

  /// A heavier [fill], for pressed states, tracks, and inactive bars.
  static const fillStrong = Color(0xFF2B2B30);

  /// Hairline separators and the edges of panels and fields.
  static const line = Color(0xFF2A2A2F);

  /// Text primary. 16:1 on [bg].
  static const ink = Color(0xFFEDEDF0);

  /// Text secondary: labels, captions, and subtitles. 7.3:1 on [bg].
  static const ink2 = Color(0xFFA1A1AA);

  /// Text tertiary: placeholders and disabled labels only (3.6:1 on [bg]).
  static const ink3 = Color(0xFF6B6B74);

  /// The one colour for what can be acted on: signal orange.
  static const accent = Color(0xFFFF7438);

  /// What is drawn on [accent]: near-black, 7.3:1 (white would be 2.7:1).
  static const onAccent = Color(0xFF140A05);

  /// A dark [accent], behind something selected or the person's own words.
  static const accentSoft = Color(0xFF3A2219);

  /// Something went well.
  static const positive = Color(0xFF4ADE80);

  /// Something went wrong.
  static const negative = Color(0xFFF87171);

  /// The glass of a drawn phone where nothing lights it: the island.
  static const device = Color(0xFF000000);

  /// What dims the screen behind a sheet.
  static const scrim = Color(0x99000000);
}
