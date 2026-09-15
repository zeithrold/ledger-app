import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/features/settings/settings_page.dart';

import '../test/support/select_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'deployment endpoint is read-only and supports localized navigation',
    (
      tester,
    ) async {
      Widget application() => ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig.fromEnvironment(
              apiBaseUrl: 'https://deployment.example.com',
            ),
          ),
        ],
        child: const LedgerApp(),
      );
      await tester.pumpWidget(application());
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Client configuration is missing or invalid. '
          'Check the deployment configuration.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('settings-tab')));
      await tester.pumpAndSettle();
      await chooseSettingsTheme(tester, 'dark');
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.dark,
      );
      await chooseSettingsTheme(tester, 'light');
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.light,
      );
      await openSettingsLanguage(tester);
      final chinese = find.byKey(const ValueKey('locale-zh'));
      await tester.scrollUntilVisible(
        chinese,
        150,
        scrollable: find.descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(chinese);
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(
          tester.element(find.byType(SettingsPage)),
        ).languageCode,
        'zh',
      );
      await tester.tap(find.byKey(const ValueKey('home-tab')));
      await tester.pumpAndSettle();
      expect(find.text('客户端配置缺失或无效，请检查部署配置。'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-tab')));
      await tester.pumpAndSettle();
      await openSettingsLanguage(tester);
      final english = find.byKey(const ValueKey('locale-en'));
      await tester.scrollUntilVisible(
        english,
        150,
        scrollable: find.descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(english);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-tab')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Client configuration is missing or invalid. '
          'Check the deployment configuration.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('settings-tab')));
      await tester.pumpAndSettle();
      expect(find.text('https://deployment.example.com/'), findsOneWidget);
      expect(find.byKey(const ValueKey('change-endpoint')), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(application());
      await tester.pumpAndSettle();
      expect(find.text('Choose your server'), findsNothing);
      expect(
        find.text(
          'Client configuration is missing or invalid. '
          'Check the deployment configuration.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('settings-tab')));
      await tester.pumpAndSettle();
      expect(find.text('https://deployment.example.com/'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
