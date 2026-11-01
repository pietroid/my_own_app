import 'package:flutter/material.dart';

/// What makes this app this app, beyond its tokens.
///
/// The name is in the strings (`context.l10n.appName`); the colours are in
/// `AppColors`. What is left is here: whether it is drawn light or dark, and
/// its mark.
abstract final class AppBrand {
  /// Whether the app is drawn light or dark.
  static const Brightness brightness = Brightness.light;

  /// The square app mark, bundled in `app_ui` (pass `package: 'app_ui'`).
  static const String markAsset = 'assets/brand/mark.png';
}
