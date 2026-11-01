import 'package:app_ui/src/app_icons/app_icon_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// {@template app_icon}
/// Widget for displaying app icons.
///
/// Defaults to Phosphor icons; SVG assets are still supported for
/// brand/logos that are not available in Phosphor.
/// {@endtemplate}
class AppIcon extends StatelessWidget {
  /// {@macro app_icon}
  const AppIcon({
    required this.iconData,
    this.size = 24.0,
    this.color,
    super.key,
  });

  /// The data for the app icon to display.
  final AppIconData iconData;

  /// The size of the icon.
  final double size;

  /// Optional color to apply to the icon.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final phosphorIcon = iconData.iconData;
    if (phosphorIcon != null) {
      return Icon(phosphorIcon, size: size, color: color);
    }

    final assetPath = iconData.path;
    if (assetPath == null) return const SizedBox.shrink();

    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/icons/$assetPath.svg',
        package: 'app_ui',
        width: size,
        height: size,
        colorFilter: color != null
            ? ColorFilter.mode(color!, BlendMode.srcIn)
            : null,
      ),
    );
  }
}
