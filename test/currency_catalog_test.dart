import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/preferences.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/core/reference/currency_catalog.dart';
import 'package:ledger_app/core/reference/display_locale.dart';

import 'support/design_harness.dart';
import 'support/reference_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = referenceFixture().currencies;
  test('full locale lookup preserves script, region and parent exceptions', () {
    for (final entry in {
      'en': 'en',
      'EN_ca': 'en-CA',
      'en-CA-u-nu-latn': 'en-CA',
      'en-AU': 'en',
      'zh': 'zh-Hans',
      'zh-CN': 'zh-Hans',
      'zh-SG': 'zh-Hans',
      'zh-TW': 'zh-Hant',
      'zh-HK': 'zh-Hant',
      'zh-Hant-TW': 'zh-Hant',
      'zh-Hans-TW': 'zh-Hans',
      'fr': 'en',
      'zh-min-nan': 'en',
      'zz-ZZ': 'en',
      '../../en': 'en',
    }.entries) {
      expect(catalog.resolve(entry.key), entry.value, reason: entry.key);
    }
    expect(catalog.label('USD', 'en').symbol, r'$');
    expect(catalog.label('USD', 'en-CA').symbol, r'US$');
    expect(catalog.label('CNY', 'zh-TW').name, '人民幣');
    expect(catalog.label('CNY', 'zh-CN').name, '人民币');
    // A future locale is registered as data, without adding a model field.
    final future = CurrencyCatalog(
      {
        ...catalog.manifest,
        'locales': {
          ...catalog.manifest['locales'] as Map,
          'es-419': {'path': 'locales/es-419.json'},
        },
      },
      catalog.metadata,
      catalog.rules,
      {
        ...catalog.bundles,
        'es-419': {
          'USD': {'display_name': 'dólar estadounidense', 'symbol': r'US$'},
        },
      },
    );
    expect(future.resolve('es-AR'), 'es-419');
    expect(future.label('USD', 'es-AR').name, 'dólar estadounidense');
    final noTraditional = CurrencyCatalog(
      {
        ...catalog.manifest,
        'locales': {
          'en': {'path': 'locales/en.json'},
          'zh-Hans': {'path': 'locales/zh-Hans.json'},
        },
      },
      catalog.metadata,
      catalog.rules,
      catalog.bundles,
    );
    expect(noTraditional.resolve('zh-TW'), 'en');
    expect(noTraditional.resolve('zh-Hant'), 'en');
  });

  test('missing names fall back to English and then the currency code', () {
    final incomplete = CurrencyCatalog(
      catalog.manifest,
      catalog.metadata,
      catalog.rules,
      {
        'en': catalog.bundles['en']!,
        'zh-Hant': {},
      },
    );
    expect(incomplete.label('USD', 'zh-Hant').name, 'US Dollar');
    expect(incomplete.label('ZZZ', 'zh-Hant').name, 'ZZZ');
    final choice = referenceFixture().currencyChoice('CNY', 'zh-TW');
    expect(choice.search, contains('人民幣'));
    expect(choice.search, contains('Chinese Yuan'));
    expect(choice.search, contains('CNY'));
  });

  test(
    'asset loading selects one locale plus fallback without backend access',
    () async {
      final loaded = await CurrencyCatalog.load(rootBundle, 'zh-TW');
      expect(loaded.bundles.keys.toSet(), {'en', 'zh-Hant'});
      expect(loaded.codes.length, 148);
      expect(loaded.label('CNY', 'zh-TW').name, '人民幣');
    },
  );

  test(
    'saved preferences retain full script and region with a shared UI fallback',
    () {
      final container = ProviderContainer(
        overrides: [shellPreferenceOverride, shellCurrencyLocaleOverride],
      );
      addTearDown(container.dispose);
      final controller = container.read(localeControllerProvider.notifier)
        ..setLanguageTag('zh-Hant-TW');
      expect(
        container.read(localeControllerProvider).toLanguageTag(),
        'zh-Hant-TW',
      );
      expect(container.read(currencyLocaleProvider), 'zh-Hant-TW');
      controller.setLanguageTag('en-CA');
      expect(container.read(currencyLocaleProvider), 'en-CA');
      controller.setLanguageTag('fr-CA');
      expect(container.read(localeControllerProvider).toLanguageTag(), 'fr-CA');
      expect(container.read(currencyLocaleProvider), 'en');
    },
  );

  test(
    'language changes invalidate loaded labels without stale bundle reuse',
    () async {
      final container = ProviderContainer(
        overrides: [shellPreferenceOverride, shellCurrencyLocaleOverride],
      );
      addTearDown(container.dispose);
      final controller = container.read(localeControllerProvider.notifier)
        ..setLanguageTag('zh-CN');
      final simplified = await container.read(referenceChoicesProvider.future);
      expect(simplified.currencyChoice('CNY', 'zh-CN').label, contains('人民币'));
      controller.setLanguageTag('zh-Hant-TW');
      final traditional = await container.read(referenceChoicesProvider.future);
      expect(
        traditional.currencyChoice('CNY', 'zh-Hant-TW').label,
        contains('人民幣'),
      );
      controller.setLanguageTag('fr-CA');
      final fallback = await container.read(referenceChoicesProvider.future);
      expect(
        fallback
            .currencyChoice('CNY', container.read(currencyLocaleProvider))
            .label,
        contains('Chinese Yuan'),
      );
    },
  );

  for (final language in ['en', 'zh']) {
    testWidgets('account currency labels use local resources in $language', (
      tester,
    ) async {
      final container = await pumpDesignApp(tester, language: language);
      container.read(routerProvider).go('/accounts/new');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-currency')), findsOneWidget);
      expect(
        find.textContaining(language == 'zh' ? '人民币' : 'Chinese Yuan'),
        findsWidgets,
      );
      container
          .read(localeControllerProvider.notifier)
          .setLocale(Locale(language == 'zh' ? 'en' : 'zh'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(language == 'zh' ? 'Chinese Yuan' : '人民币'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
