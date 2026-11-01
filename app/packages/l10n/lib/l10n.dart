/// The app's strings.
///
/// Every user-facing sentence in the app lives in `lib/arb/app_pt.arb`, in
/// Brazilian Portuguese, and is read through `context.l10n`. Code, comments
/// and logs stay in English.
library;

import 'package:flutter/widgets.dart';
import 'package:l10n/src/gen/app_localizations.dart';

export 'package:l10n/src/gen/app_localizations.dart';

/// Reads the strings off a [BuildContext].
extension AppLocalizationsX on BuildContext {
  /// The strings for the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
