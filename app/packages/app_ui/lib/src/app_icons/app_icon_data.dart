import 'package:flutter/widgets.dart';

/// {@template app_icon_data}
/// Data class for representing app icons.
///
/// Supports either a Phosphor [IconData] or an SVG asset path.
/// {@endtemplate}
class AppIconData {
  /// {@macro app_icon_data}
  const AppIconData.asset(this.path) : iconData = null;

  /// {@macro app_icon_data}
  const AppIconData.phosphor(this.iconData) : path = null;

  /// The path to the app icon asset, when using an SVG.
  final String? path;

  /// The Phosphor [IconData], when using a Phosphor icon.
  final IconData? iconData;
}
