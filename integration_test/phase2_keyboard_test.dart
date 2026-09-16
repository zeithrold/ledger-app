import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/core/accounting/controller.dart';

import '../test/support/accounting_fixture.dart';
import '../test/support/design_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native accounting keyboard and back at 200% text', (
    tester,
  ) async {
    final requests = <String>[];
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/',
      handler: (request) {
        requests.add(request.method);
        return accountingFixture(request);
      },
    );
    expect(container.read(accountingProvider).page, isNotNull);
    final captureClient = http.Client();
    addTearDown(captureClient.close);
    if (Platform.isAndroid && const bool.fromEnvironment('CAPTURE_VISUALS')) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = container.read(routerProvider);

    Future<void> captureKeyboard(String name) async {
      if (!const bool.fromEnvironment('CAPTURE_VISUALS')) return;
      await binding.takeScreenshot(name);
      const url = String.fromEnvironment('NATIVE_CAPTURE_URL');
      if (url.isEmpty) return;
      final response = await captureClient
          .get(Uri.parse(url).replace(queryParameters: {'name': name}))
          .timeout(const Duration(seconds: 15));
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
        expect(tester.view.viewInsets.bottom, 0);
        await press(tester, 'home-add-transaction');
        await reveal(tester, 'entry-amount');
        final amount = find.byKey(const ValueKey('entry-amount'));
        expect(amount.hitTestable(), findsOneWidget);
        // Keep the native text-input connection throughout this fresh process.
        // Synthetic editing values can desynchronize the real IME state.
        await tester.tap(amount);
        await tester.pump();
        final editable = find.descendant(
          of: amount,
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(editable).focusNode.hasFocus,
          isTrue,
          reason: '$language ${mode.name} amount tap must receive focus.',
        );
        for (var i = 0; i < 100 && tester.view.viewInsets.bottom == 0; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (tester.view.viewInsets.bottom == 0 &&
            const bool.fromEnvironment('CAPTURE_VISUALS')) {
          await captureKeyboard(
            'accounting-$language-${mode.name}-200-keyboard-missing',
          );
        }
        expect(
          tester.view.viewInsets.bottom,
          greaterThan(0),
          reason: '$language ${mode.name} must open the actual OS keyboard.',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        await tester.ensureVisible(amount);
        await tester.pumpAndSettle();
        expect(amount.hitTestable(), findsOneWidget);
        final keyboardTop =
            (tester.view.physicalSize.height - tester.view.viewInsets.bottom) /
            tester.view.devicePixelRatio;
        expect(tester.getRect(amount).bottom, lessThanOrEqualTo(keyboardTop));
        await captureKeyboard('accounting-$language-${mode.name}-200-keyboard');
        FocusManager.instance.primaryFocus?.unfocus();
        for (var i = 0; i < 100 && tester.view.viewInsets.bottom > 0; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(tester.view.viewInsets.bottom, 0);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(
          find.byKey(const ValueKey('home-add-transaction')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    }
    expect(requests, everyElement('GET'));
  });
}
