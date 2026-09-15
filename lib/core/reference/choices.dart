// Reference data uses Unicode CLDR and IANA identifiers.
// ignore_for_file: public_member_api_docs
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/core/reference/currency_catalog.dart';
import 'package:ledger_app/l10n/generated/app_localizations.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Choice {
  const Choice(
    this.value,
    this.label, {
    this.search = '',
    this.displayLabel,
    this.subtitle,
  });
  final String value;
  final String label;
  final String search;
  final String? displayLabel;
  final String? subtitle;
}

class ReferenceChoices {
  ReferenceChoices(this.currencies, this.chineseCities);
  final CurrencyCatalog currencies;
  final Map<String, String> chineseCities;

  Choice currencyChoice(String code, String locale) {
    final label = currencies.label(code, locale);
    final fallback = currencies.label(code, 'en');
    return Choice(
      code,
      '${label.name} · $code · ${label.symbol}',
      search: '$code ${label.name} ${fallback.name} ${label.symbol}',
    );
  }

  List<Choice> currencyChoices(String locale) => [
    for (final code in currencies.codes) currencyChoice(code, locale),
  ];

  List<Choice> timezoneChoices(String language, {DateTime? at}) {
    final now = at ?? DateTime.now();
    return [
      const Choice(
        'UTC',
        'UTC',
        subtitle: 'UTC+00:00',
        displayLabel: 'UTC · UTC+00:00',
      ),
      for (final location in tz.timeZoneDatabase.locations.values)
        if (location.name != 'UTC')
          Choice(
            location.name,
            cityLabel(location.name, language),
            subtitle: '${locationOffset(location, now)} · ${location.name}',
            displayLabel:
                '${cityLabel(location.name, language)}'
                ' · ${locationOffset(location, now)}',
            search:
                '${chineseCities[location.name] ?? ''} ${city(location.name)}',
          ),
    ];
  }

  String cityLabel(String name, String language) =>
      language == 'zh' ? chineseCities[name] ?? city(name) : city(name);

  static String locationOffset(tz.Location location, DateTime at) =>
      offsetLabel(tz.TZDateTime.from(at, location).timeZoneOffset);

  static String city(String name) => name.split('/').last.replaceAll('_', ' ');
  static String offsetLabel(Duration offset) {
    final minutes = offset.inMinutes;
    final sign = minutes < 0 ? '-' : '+';
    return 'UTC$sign${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes.abs() % 60).toString().padLeft(2, '0')}';
  }
}

// A region/script variant can refine labels within a translated UI language.
// Unsupported UI languages use the same English fallback across all pages.
final currencyLocaleProvider = Provider<String>((ref) {
  final requested = ref.watch(localeControllerProvider);
  final ui = basicLocaleListResolution([
    requested,
  ], AppLocalizations.supportedLocales);
  return (requested.languageCode == ui.languageCode ? requested : ui)
      .toLanguageTag();
});

final referenceChoicesProvider = FutureProvider<ReferenceChoices>((ref) async {
  final locale = ref.watch(currencyLocaleProvider);
  tzdata.initializeTimeZones();
  final catalog = await CurrencyCatalog.load(rootBundle, locale);
  final cities = await rootBundle.loadString(
    'assets/reference/timezone_cities_zh.json',
  );
  return decodeReferenceChoices(catalog, cities);
});

ReferenceChoices decodeReferenceChoices(
  CurrencyCatalog currencies,
  String cities,
) {
  return ReferenceChoices(
    currencies,
    Map<String, String>.from(jsonDecode(cities) as Map),
  );
}
