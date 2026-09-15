import 'package:flutter/widgets.dart';
import 'package:ledger_app/l10n/generated/app_localizations.dart';

/// Access to generated application messages in the current locale.
extension AppLocalizationsContext on BuildContext {
  /// The application messages for this context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
