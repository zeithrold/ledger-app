import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/l10n/generated/app_localizations.dart';

/// Matches a requested locale to a supported one and keeps the requested
/// script/region variant, so `en-CA` stays `en-CA` rather than collapsing to
/// the translated UI language.
Locale resolveDisplayLocale(Locale requested) {
  final resolved = basicLocaleListResolution([
    requested,
  ], AppLocalizations.supportedLocales);
  return requested.languageCode == resolved.languageCode ? requested : resolved;
}

/// The device's preferred languages, resolved to a supported one.
///
/// Resolution may reorder the list, so the first entry matching the resolved
/// language is returned to preserve its script and region.
Locale resolveDeviceLocale(List<Locale> preferred) {
  if (preferred.isEmpty) return const Locale('en');
  final resolved = basicLocaleListResolution(
    preferred,
    AppLocalizations.supportedLocales,
  );
  return preferred.firstWhere(
    (locale) => locale.languageCode == resolved.languageCode,
    orElse: () => resolved,
  );
}

/// The language tag used to resolve translated reference data such as currency
/// and timezone labels. Unsupported UI languages fall back to English here and
/// in every page, so both stay consistent.
///
/// Core owns the default, derived from the device language, so it stays usable
/// stand-alone. The application overrides this with the chosen display language
/// so reference data follows the interface.
final currencyLocaleProvider = Provider<String>((ref) {
  final preferred = WidgetsBinding.instance.platformDispatcher.locales;
  return resolveDeviceLocale(preferred).toLanguageTag();
});
