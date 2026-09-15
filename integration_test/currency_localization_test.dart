import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/l10n/l10n.dart';

import '../test/support/design_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native currency resources, search, locale refresh and back', (
    tester,
  ) async {
    final container = await pumpDesignApp(tester, liveReferences: true);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    final client = http.Client();
    addTearDown(client.close);
    for (final (tag, mode, name, search) in [
      ('en-CA', ThemeMode.light, 'Chinese Yuan', 'Chinese Yuan'),
      ('zh-Hans-CN', ThemeMode.dark, '人民币', 'CNY'),
      ('zh-Hant-TW', ThemeMode.light, '人民幣', 'Chinese Yuan'),
    ]) {
      container.read(localeControllerProvider.notifier).setLanguageTag(tag);
      container.read(themeModeControllerProvider.notifier).setMode(mode);
      container.read(routerProvider).go('/accounts/new');
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      final picker = find.byKey(const ValueKey('account-currency'));
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      expect(find.textContaining(name), findsWidgets);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('choice-search')),
        search,
      );
      await tester.pumpAndSettle();
      final choice = find.byKey(const ValueKey('option-CNY'));
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      expect(find.textContaining(name), findsWidgets);
      final capture = 'accounting-currency-${tag.toLowerCase()}';
      await binding.takeScreenshot(capture);
      const nativeURL = String.fromEnvironment('NATIVE_CAPTURE_URL');
      if (nativeURL.isNotEmpty) {
        final response = await client.get(
          Uri.parse(nativeURL).replace(queryParameters: {'name': capture}),
        );
        expect(response.statusCode, 200, reason: response.body);
      }
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('choice-search')), findsNothing);
      expect(find.textContaining(name), findsWidgets);
      final context = tester.element(picker);
      await tester.tap(find.byTooltip(context.l10n.backToHome));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
