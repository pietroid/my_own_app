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

  /// The icons a built app may name (`Icon.name`, `Button.icon`), by
  /// name: the same list as `ICONS` in `server/src/apps/catalog.ts`.
  static const named = <String, AppIconData>{
    'add': AppIconData.phosphor(PhosphorIconsRegular.plus),
    'remove': AppIconData.phosphor(PhosphorIconsRegular.minus),
    'edit': AppIconData.phosphor(PhosphorIconsRegular.pencilSimple),
    'delete': AppIconData.phosphor(PhosphorIconsRegular.trash),
    'check': AppIconData.phosphor(PhosphorIconsRegular.check),
    'checkCircle': AppIconData.phosphor(PhosphorIconsRegular.checkCircle),
    'close': AppIconData.phosphor(PhosphorIconsRegular.x),
    'search': AppIconData.phosphor(PhosphorIconsRegular.magnifyingGlass),
    'settings': AppIconData.phosphor(PhosphorIconsRegular.gear),
    'home': AppIconData.phosphor(PhosphorIconsRegular.house),
    'person': AppIconData.phosphor(PhosphorIconsRegular.user),
    'people': AppIconData.phosphor(PhosphorIconsRegular.users),
    'favorite': AppIconData.phosphor(PhosphorIconsRegular.heart),
    'star': AppIconData.phosphor(PhosphorIconsRegular.star),
    'calendar': AppIconData.phosphor(PhosphorIconsRegular.calendar),
    'clock': AppIconData.phosphor(PhosphorIconsRegular.clock),
    'notifications': AppIconData.phosphor(PhosphorIconsRegular.bell),
    'mail': AppIconData.phosphor(PhosphorIconsRegular.envelope),
    'chat': AppIconData.phosphor(PhosphorIconsRegular.chatCircle),
    'send': AppIconData.phosphor(PhosphorIconsRegular.paperPlaneTilt),
    'phone': AppIconData.phosphor(PhosphorIconsRegular.phone),
    'camera': AppIconData.phosphor(PhosphorIconsRegular.camera),
    'image': AppIconData.phosphor(PhosphorIconsRegular.image),
    'location': AppIconData.phosphor(PhosphorIconsRegular.mapPin),
    'cart': AppIconData.phosphor(PhosphorIconsRegular.shoppingCart),
    'bag': AppIconData.phosphor(PhosphorIconsRegular.shoppingBag),
    'money': AppIconData.phosphor(PhosphorIconsRegular.money),
    'card': AppIconData.phosphor(PhosphorIconsRegular.creditCard),
    'chart': AppIconData.phosphor(PhosphorIconsRegular.chartBar),
    'list': AppIconData.phosphor(PhosphorIconsRegular.listBullets),
    'grid': AppIconData.phosphor(PhosphorIconsRegular.squaresFour),
    'folder': AppIconData.phosphor(PhosphorIconsRegular.folder),
    'file': AppIconData.phosphor(PhosphorIconsRegular.file),
    'book': AppIconData.phosphor(PhosphorIconsRegular.book),
    'bookmark': AppIconData.phosphor(PhosphorIconsRegular.bookmarkSimple),
    'tag': AppIconData.phosphor(PhosphorIconsRegular.tag),
    'filter': AppIconData.phosphor(PhosphorIconsRegular.funnel),
    'sort': AppIconData.phosphor(PhosphorIconsRegular.sortAscending),
    'menu': AppIconData.phosphor(PhosphorIconsRegular.list),
    'more': AppIconData.phosphor(PhosphorIconsRegular.dotsThree),
    'back': AppIconData.phosphor(PhosphorIconsRegular.arrowLeft),
    'forward': AppIconData.phosphor(PhosphorIconsRegular.arrowRight),
    'up': AppIconData.phosphor(PhosphorIconsRegular.caretUp),
    'down': AppIconData.phosphor(PhosphorIconsRegular.caretDown),
    'open': AppIconData.phosphor(PhosphorIconsRegular.caretRight),
    'play': AppIconData.phosphor(PhosphorIconsRegular.play),
    'pause': AppIconData.phosphor(PhosphorIconsRegular.pause),
    'lock': AppIconData.phosphor(PhosphorIconsRegular.lock),
    'share': AppIconData.phosphor(PhosphorIconsRegular.shareNetwork),
    'link': AppIconData.phosphor(PhosphorIconsRegular.link),
    'info': AppIconData.phosphor(PhosphorIconsRegular.info),
    'warning': AppIconData.phosphor(PhosphorIconsRegular.warning),
    'sun': AppIconData.phosphor(PhosphorIconsRegular.sun),
    'moon': AppIconData.phosphor(PhosphorIconsRegular.moon),
    'music': AppIconData.phosphor(PhosphorIconsRegular.musicNote),
    'gift': AppIconData.phosphor(PhosphorIconsRegular.gift),
    'globe': AppIconData.phosphor(PhosphorIconsRegular.globe),
    'desktop': AppIconData.phosphor(PhosphorIconsRegular.desktop),
    'mobile': AppIconData.phosphor(PhosphorIconsRegular.deviceMobile),
    'browser': AppIconData.phosphor(PhosphorIconsRegular.browser),
    'code': AppIconData.phosphor(PhosphorIconsRegular.code),
    'visible': AppIconData.phosphor(PhosphorIconsRegular.eye),
    'download': AppIconData.phosphor(PhosphorIconsRegular.download),
    'flag': AppIconData.phosphor(PhosphorIconsRegular.flag),
    'food': AppIconData.phosphor(PhosphorIconsRegular.forkKnife),
    'travel': AppIconData.phosphor(PhosphorIconsRegular.airplane),
    'car': AppIconData.phosphor(PhosphorIconsRegular.car),
    'fitness': AppIconData.phosphor(PhosphorIconsRegular.barbell),
    'assistant': AppIconData.phosphor(PhosphorIconsRegular.chatCircleDots),
    'cursor': AppIconData.phosphor(PhosphorIconsRegular.cursor),
    'tree': AppIconData.phosphor(PhosphorIconsRegular.treeStructure),
    'version': AppIconData.phosphor(PhosphorIconsRegular.clockCounterClockwise),
    'restore': AppIconData.phosphor(PhosphorIconsRegular.arrowCounterClockwise),
    'action': AppIconData.phosphor(PhosphorIconsRegular.lightning),
    'component': AppIconData.phosphor(PhosphorIconsRegular.squaresFour),
  };

  /// Each catalog component's icon, by its type, for the studio's tree.
  static const components = <String, AppIconData>{
    'Column': AppIconData.phosphor(PhosphorIconsRegular.rows),
    'Row': AppIconData.phosphor(PhosphorIconsRegular.columns),
    'List': AppIconData.phosphor(PhosphorIconsRegular.listBullets),
    'Card': AppIconData.phosphor(PhosphorIconsRegular.square),
    'Divider': AppIconData.phosphor(PhosphorIconsRegular.minus),
    'Tabs': AppIconData.phosphor(PhosphorIconsRegular.tabs),
    'Pages': AppIconData.phosphor(PhosphorIconsRegular.stack),
    'Modal': AppIconData.phosphor(PhosphorIconsRegular.appWindow),
    'Text': AppIconData.phosphor(PhosphorIconsRegular.textT),
    'Icon': AppIconData.phosphor(PhosphorIconsRegular.smiley),
    'Image': AppIconData.phosphor(PhosphorIconsRegular.image),
    'Badge': AppIconData.phosphor(PhosphorIconsRegular.tag),
    'Message': AppIconData.phosphor(PhosphorIconsRegular.chatCircle),
    'TextField': AppIconData.phosphor(PhosphorIconsRegular.textbox),
    'CheckBox': AppIconData.phosphor(PhosphorIconsRegular.checkSquare),
    'Switch': AppIconData.phosphor(PhosphorIconsRegular.toggleLeft),
    'ChoicePicker': AppIconData.phosphor(PhosphorIconsRegular.listChecks),
    'Slider': AppIconData.phosphor(PhosphorIconsRegular.slidersHorizontal),
    'DateTimeInput': AppIconData.phosphor(PhosphorIconsRegular.calendar),
    'Button': AppIconData.phosphor(PhosphorIconsRegular.cursorClick),
    'Surface': AppIconData.phosphor(PhosphorIconsRegular.appWindow),
  };
}
