import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/core/auth/clerk_gateway.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/identity/device_defaults.dart';
import 'package:ledger_app/core/network/http_client.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/core/reference/currency_catalog.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fakes.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_VISUALS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('visual-root')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('${Directory.systemTemp.path}/ledger-visuals');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$language $mode welcome and wizard visual layout', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = FakeAuth(sessionKey: null);
        final catalog = await tester.runAsync(() async {
          tzdata.initializeTimeZones();
          return decodeReferenceChoices(
            await CurrencyCatalog.load(rootBundle, 'zh-Hans'),
            await rootBundle.loadString(
              'assets/reference/timezone_cities_zh.json',
            ),
          );
        });
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('visual-root'),
            child: ProviderScope(
              overrides: [
                appConfigProvider.overrideWithValue(
                  const AppConfig.fromEnvironment(
                    apiBaseUrl: 'https://example.com/',
                  ),
                ),
                authGatewayProvider.overrideWithValue(auth),
                referenceChoicesProvider.overrideWith((ref) async => catalog!),
                deviceDefaultsProvider.overrideWith(
                  (ref) async => const DeviceDefaults(
                    'CNY',
                    'Asia/Shanghai',
                    usedFallback: false,
                  ),
                ),
                httpClientProvider.overrideWithValue(
                  MockClient((_) async => problem('bootstrap-required', 409)),
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
        container
            .read(localeControllerProvider.notifier)
            .setLocale(Locale(language));
        container.read(themeModeControllerProvider.notifier).setMode(mode);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('browser-sign-in')), findsOneWidget);
        await capture(tester, '$language-${mode.name}-welcome');
        await tester.tap(find.byKey(const ValueKey('browser-sign-in')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('setup-next')), findsOneWidget);
        await capture(tester, '$language-${mode.name}-currency');
        await tester.tap(find.byKey(const ValueKey('setup-next')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('setup-language')), findsOneWidget);
        await capture(tester, '$language-${mode.name}-preferences');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
