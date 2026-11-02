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

  /// Opens something, at the end of a row.
  static const open = AppIconData.phosphor(PhosphorIconsRegular.caretRight);

  /// Closes a page or a sheet.
  static const close = AppIconData.phosphor(PhosphorIconsRegular.x);

  /// Picks a component on a built app's screen, instead of tapping it.
  static const select = AppIconData.phosphor(PhosphorIconsRegular.cursor);

  /// The tree of a built app's components.
  static const tree = AppIconData.phosphor(PhosphorIconsRegular.treeStructure);

  /// A version of a built app, in its history.
  static const version = AppIconData.phosphor(
    PhosphorIconsRegular.clockCounterClockwise,
  );

  /// Brings an earlier version back.
  static const restore = AppIconData.phosphor(
    PhosphorIconsRegular.arrowCounterClockwise,
  );

  /// An app's action: the code a tap runs.
  static const action = AppIconData.phosphor(PhosphorIconsRegular.lightning);

  /// A Column component.
  static const componentColumn = AppIconData.phosphor(
    PhosphorIconsRegular.rows,
  );

  /// A Row component.
  static const componentRow = AppIconData.phosphor(
    PhosphorIconsRegular.columns,
  );

  /// A List component.
  static const componentList = AppIconData.phosphor(
    PhosphorIconsRegular.listBullets,
  );

  /// A Text component.
  static const componentText = AppIconData.phosphor(PhosphorIconsRegular.textT);

  /// A TextField component.
  static const componentField = AppIconData.phosphor(
    PhosphorIconsRegular.textbox,
  );

  /// A CheckBox component.
  static const componentCheck = AppIconData.phosphor(
    PhosphorIconsRegular.checkSquare,
  );

  /// A Button component.
  static const componentButton = AppIconData.phosphor(
    PhosphorIconsRegular.cursorClick,
  );
}
