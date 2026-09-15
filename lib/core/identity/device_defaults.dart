import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/number_symbols_data.dart';

/// Suggested initialization values; always reviewed before bootstrap.
class DeviceDefaults {
  /// Records whether either suggestion needed a fallback.
  const DeviceDefaults(
    this.currency,
    this.timezone, {
    required this.usedFallback,
  });

  /// Device-region currency, or USD.
  final String currency;

  /// IANA identifier, or UTC.
  final String timezone;

  /// Show an explicit review hint when inference was incomplete.
  final bool usedFallback;
}

/// Uses region-specific CLDR symbols only, never a language-only guess.
DeviceDefaults inferDefaults(Locale locale, String? timezone) {
  final country = locale.countryCode;
  String? currency;
  if (country != null && country.isNotEmpty) {
    final exact = numberFormatSymbols['${locale.languageCode}_$country'];
    currency = exact?.DEF_CURRENCY_CODE;
    if (currency == null) {
      final matching = numberFormatSymbols.entries.where(
        (entry) => entry.key.endsWith('_$country'),
      );
      if (matching.isNotEmpty) {
        currency = matching.first.value.DEF_CURRENCY_CODE;
      }
    }
  }
  final zone = timezone?.trim();
  final validZone =
      zone != null && (zone == 'UTC' || zone.contains('/')) && zone != 'Local';
  return DeviceDefaults(
    currency ?? 'USD',
    validZone ? zone : 'UTC',
    usedFallback: currency == null || !validZone,
  );
}

/// Platform access is isolated for deterministic tests.
final deviceDefaultsProvider = FutureProvider<DeviceDefaults>((ref) async {
  String? timezone;
  try {
    timezone = (await FlutterTimezone.getLocalTimezone().timeout(
      const Duration(seconds: 5),
    )).identifier;
  } on Object {
    /* Manual review is available. */
  }
  return inferDefaults(
    WidgetsBinding.instance.platformDispatcher.locale,
    timezone,
  );
});
