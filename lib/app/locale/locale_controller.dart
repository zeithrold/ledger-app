import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/core/reference/display_locale.dart';

/// Display language, initially resolved from device language preferences.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => _deviceLocale();

  /// The device's preferred language, resolved to a supported one.
  ///
  /// Read directly instead of from a provider so a later device-locale refresh
  /// cannot discard the language the user chose in the application.
  Locale _deviceLocale() =>
      resolveDeviceLocale(WidgetsBinding.instance.platformDispatcher.locales);

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

/// One retained display language for the whole application shell.
final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
