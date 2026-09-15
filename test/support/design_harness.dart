import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/core/auth/clerk_gateway.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/identity/device_defaults.dart';
import 'package:ledger_app/core/network/http_client.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/core/reference/currency_catalog.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'fakes.dart';

Future<ProviderContainer> pumpDesignApp(
  WidgetTester tester, {
  String language = 'en',
  String initialLocation = '/books',
  ThemeMode mode = ThemeMode.light,
  FakeAuth? auth,
  http.Client? client,
  String apiBaseUrl = 'https://example.com/',
  Future<http.Response> Function(http.Request)? handler,
  bool liveReferences = false,
}) async {
  final catalog = await tester.runAsync(() async {
    tzdata.initializeTimeZones();
    return decodeReferenceChoices(
      await CurrencyCatalog.load(rootBundle, 'zh-Hans'),
      await rootBundle.loadString('assets/reference/timezone_cities_zh.json'),
    );
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('visual-root'),
      child: ProviderScope(
        key: UniqueKey(),
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(apiBaseUrl: apiBaseUrl),
          ),
          authGatewayProvider.overrideWithValue(auth ?? FakeAuth()),
          if (!liveReferences)
            referenceChoicesProvider.overrideWith((ref) async => catalog!),
          deviceDefaultsProvider.overrideWith(
            (ref) async => const DeviceDefaults(
              'CNY',
              'Asia/Shanghai',
              usedFallback: false,
            ),
          ),
          httpClientProvider.overrideWithValue(
            client ?? MockClient(handler ?? normalApi),
          ),
        ],
        child: const LedgerApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LedgerApp)),
  );
  container.read(routerProvider).go(initialLocation);
  await tester.pumpAndSettle();
  container.read(localeControllerProvider.notifier).setLocale(Locale(language));
  container.read(themeModeControllerProvider.notifier).setMode(mode);
  await tester.pumpAndSettle();
  return container;
}

Future<void> reveal(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String key) async {
  await reveal(tester, key);
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}
