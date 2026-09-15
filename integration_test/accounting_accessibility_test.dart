import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/core/accounting/controller.dart';

import '../test/support/design_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native accounting large text keyboard and back navigation', (
    tester,
  ) async {
    final client = http.Client();
    addTearDown(client.close);
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/',
      apiBaseUrl: const String.fromEnvironment('ACCOUNTING_TEST_URL'),
      client: client,
    );
    final c = container.read(accountingProvider);
    for (var i = 0; i < 200 && c.page == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.page, isNotNull);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = container.read(routerProvider);
    Future<void> nativeCapture(String name) async {
      const url = String.fromEnvironment('NATIVE_CAPTURE_URL');
      if (url.isEmpty) return;
      final response = await client.get(
        Uri.parse(url).replace(queryParameters: {'name': name}),
      );
      expect(response.statusCode, 200, reason: response.body);
    }

    for (final language in ['en', 'zh']) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        container
            .read(localeControllerProvider.notifier)
            .setLocale(Locale(language));
        container.read(themeModeControllerProvider.notifier).setMode(mode);
        router.go('/');
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('CAPTURE_VISUALS')) {
          await binding.takeScreenshot(
            'accounting-$language-${mode.name}-200-home',
          );
          await nativeCapture('accounting-$language-${mode.name}-200-home');
        }
        await press(tester, 'home-add-transaction');
        await reveal(tester, 'entry-amount');
        await tester.tap(find.byKey(const ValueKey('entry-amount')));
        for (var i = 0; i < 100 && tester.view.viewInsets.bottom == 0; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.view.viewInsets.bottom, greaterThan(0));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('CAPTURE_VISUALS')) {
          await binding.takeScreenshot(
            'accounting-$language-${mode.name}-200-keyboard',
          );
          await nativeCapture('accounting-$language-${mode.name}-200-keyboard');
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('home-add-transaction')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
