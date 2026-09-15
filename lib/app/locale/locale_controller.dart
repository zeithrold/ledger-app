import 'package:flutter/widgets.dart';
import 'package:ledger_app/l10n/generated/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_controller.g.dart';

/// Display language, initially resolved from device language preferences.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Locale build() => _deviceLocale();

  Locale _deviceLocale() {
    final preferred = WidgetsBinding.instance.platformDispatcher.locales;
    final resolved = basicLocaleListResolution(
      preferred,
      AppLocalizations.supportedLocales,
    );
    return preferred.firstWhere(
      (locale) => locale.languageCode == resolved.languageCode,
      orElse: () => resolved,
    );
  }

  /// Restores device language after clearing account preferences.
  void resetToDevice() => state = _deviceLocale();

  /// Selects a language; Flutter resolves unsupported locales to English.
  // Riverpod exposes explicit notifier methods for state changes.
  // ignore: use_setters_to_change_properties
  void setLocale(Locale locale) => state = locale;

  /// Restores language, script and region without collapsing to a UI language.
  void setLanguageTag(String tag) {
    final parts = tag.replaceAll('_', '-').split('-');
    String? script;
    String? country;
    for (final part in parts.skip(1)) {
      if (part.length == 1) break;
      if (RegExp(r'^[a-zA-Z]{4}$').hasMatch(part)) {
        script = '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      } else if (RegExp(r'^([a-zA-Z]{2}|[0-9]{3})$').hasMatch(part)) {
        country = part.toUpperCase();
      }
    }
    state = Locale.fromSubtags(
      languageCode: parts.first.toLowerCase(),
      scriptCode: script,
      countryCode: country,
    );
  }
}
