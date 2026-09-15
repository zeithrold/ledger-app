import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/core/network/http_client.dart';
import 'package:ledger_app/features/home/home_page.dart';
import 'package:ledger_app/features/settings/settings_page.dart';

import 'support/select_helpers.dart';

void main() {
  testWidgets(
    'configuration opens the default entrypoint without service credentials',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('zh', 'CN')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(const ProviderScope(child: LedgerApp()));
      await tester.pumpAndSettle();
      expect(find.text('Ledger'), findsOneWidget);
      expect(
        find.text(
          '客户端配置缺失或无效，请检查部署配置。',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('navigation and themes work without creating a network client', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWith((ref) {
            throw StateError('The shell must not create a network client');
          }),
        ],
        child: const LedgerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    for (final mode in ['dark', 'light', 'system']) {
      await chooseSettingsTheme(tester, mode);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SettingsPage));
      final expected = mode == 'dark' ? Brightness.dark : Brightness.light;
      expect(Theme.of(context).brightness, expected);
    }

    await tester.tap(find.byKey(const ValueKey('home-tab')));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system theme responds to platform brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const ProviderScope(child: LedgerApp()));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(HomePage))).brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(HomePage))).brightness,
      Brightness.light,
    );
  });

  testWidgets('small mobile viewport has no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: LedgerApp()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
