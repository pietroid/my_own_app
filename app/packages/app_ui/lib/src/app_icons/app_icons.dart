import 'package:app_ui/src/app_icons/app_icon_data.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// {@template app_icons}
/// A collection of app icons used throughout the application.
///
/// Icons default to Phosphor; SVG assets are kept only for brand logos
/// that are not available in the Phosphor set.
/// {@endtemplate}
class AppIcons {
  /// Google Icon (SVG asset).
  static const google = AppIconData.asset('google');

  /// The assistant. A placeholder until the app has a mark of its own for
  /// it (`/design-system`): never a sparkle, a wand or a robot.
  static const assistant = AppIconData.phosphor(
    PhosphorIconsRegular.chatCircleDots,
  );

  /// Sends a message.
  static const send = AppIconData.phosphor(PhosphorIconsRegular.paperPlaneTilt);

  /// Leaves the account.
  static const signOut = AppIconData.phosphor(PhosphorIconsRegular.signOut);

  /// Closes a page or a sheet.
  static const close = AppIconData.phosphor(PhosphorIconsRegular.x);
}
