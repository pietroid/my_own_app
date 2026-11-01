import 'package:app_ui/app_ui.dart';

/// Extension on [BuildContext] for easy access to theme tokens.
extension AppThemeBuildContext on BuildContext {
  /// The current [ThemeData].
  ThemeData get theme => Theme.of(this);

  /// The app's text styles.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// The app's color scheme.
  ColorScheme get colors => Theme.of(this).colorScheme;
}
