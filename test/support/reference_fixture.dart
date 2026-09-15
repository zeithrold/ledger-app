import 'dart:convert';
import 'dart:io';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/core/reference/currency_catalog.dart';
import 'package:timezone/data/latest.dart' as tzdata;

ReferenceChoices referenceFixture() {
  tzdata.initializeTimeZones();
  CurrencyJson read(String path) =>
      jsonDecode(File('assets/reference/currencies/$path').readAsStringSync())
          as CurrencyJson;
  final manifest = read('manifest.json');
  return decodeReferenceChoices(
    CurrencyCatalog(manifest, read('catalog.json'), read('locale_rules.json'), {
      for (final entry in (manifest['locales'] as Map).entries)
        entry.key as String:
            read((entry.value as Map)['path'] as String)['currencies']
                as CurrencyJson,
    }),
    File('assets/reference/timezone_cities_zh.json').readAsStringSync(),
  );
}
