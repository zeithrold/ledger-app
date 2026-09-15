import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/features/home/home_page.dart';
import 'package:ledger_app/features/settings/settings_page.dart';

import 'support/select_helpers.dart';

void main() {
  test('all locales translate every English resource', () {
    final template = _readArb('lib/l10n/app_en.arb');
    final keys = template.keys.where((key) => !key.startsWith('@')).toSet();
    final files = Directory('lib/l10n').listSync().whereType<File>().where(
      (file) => file.path.endsWith('.arb'),
    );
    for (final file in files) {
      final translation = _readArb(file.path);
      expect(
        translation.keys.where((key) => !key.startsWith('@')).toSet(),
        keys,
        reason: 'Missing or obsolete translations in ${file.path}',
      );
      for (final key in keys) {
        expect(translation[key], isA<String>());
        expect((translation[key]! as String).trim(), isNotEmpty);
      }
    }
  });

  testWidgets('language switching preserves the route and selected theme', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: LedgerApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    await chooseSettingsTheme(tester, 'dark');
    await tester.pumpAndSettle();

    for (final (code, emptyText) in [
      ('zh', '客户端配置缺失或无效，请检查部署配置。'),
      (
        'en',
        'Client configuration is missing or invalid. '
            'Check the deployment configuration.',
      ),
    ]) {
      await openSettingsLanguage(tester);
      final option = find.byKey(ValueKey('locale-$code'));
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      final context = tester.element(find.byType(SettingsPage));
      expect(Localizations.localeOf(context).languageCode, code);
      expect(
        MaterialLocalizations.of(context).cancelButtonLabel,
        code == 'zh' ? '取消' : 'Cancel',
      );
      expect(Theme.of(context).brightness, Brightness.dark);
      await tester.tap(find.byKey(const ValueKey('home-tab')));
      await tester.pumpAndSettle();
      expect(find.text(emptyText), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-tab')));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported locale falls back to English', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(localeControllerProvider.notifier)
        .setLocale(
          const Locale('fr'),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LedgerApp()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HomePage));
    expect(Localizations.localeOf(context), const Locale('en'));
    expect(
      find.text(
        'Client configuration is missing or invalid. '
        'Check the deployment configuration.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new application scope starts in English', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(localeControllerProvider.notifier)
        .setLocale(
          const Locale('zh'),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LedgerApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('客户端配置缺失或无效，请检查部署配置。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const ProviderScope(child: LedgerApp()));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Client configuration is missing or invalid. '
        'Check the deployment configuration.',
      ),
      findsOneWidget,
    );
  });

  for (final (code, errorTitle, backLabel) in [
    ('en', 'Page not found', 'Back to home'),
    ('zh', '页面不存在', '返回首页'),
  ]) {
    testWidgets('$code unknown route has a localized recovery action', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeControllerProvider.notifier).setLocale(Locale(code));
      container.read(routerProvider).go('/missing');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LedgerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(errorTitle), findsOneWidget);
      await tester.tap(find.text(backLabel));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$code supports a small viewport with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeControllerProvider.notifier).setLocale(Locale(code));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LedgerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('settings-tab')));
      await tester.pumpAndSettle();
      await openSettingsLanguage(tester);
      final option = find.byKey(ValueKey('locale-$code'));
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      expect(option.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Map<String, Object?> _readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
