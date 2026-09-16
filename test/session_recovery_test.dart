import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/preferences.dart';
import 'package:ledger_app/l10n/generated/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'support/design_harness.dart';
import 'support/fakes.dart';

void main() => sessionRecoveryTests();

void sessionRecoveryTests({
  Future<void> Function(String name)? capture,
  bool nativeSurface = false,
}) {
  for (final languages in [
    [const Locale('zh', 'CN')],
    [const Locale('fr'), const Locale('zh', 'TW')],
    [const Locale('en', 'US'), const Locale('zh')],
    [const Locale('fr')],
  ]) {
    testWidgets('device language preference $languages', (tester) async {
      tester.platformDispatcher.localesTestValue = languages;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final container = ProviderContainer(
        overrides: [shellPreferenceOverride, shellCurrencyLocaleOverride],
      );
      addTearDown(container.dispose);
      final resolved = basicLocaleListResolution(
        languages,
        AppLocalizations.supportedLocales,
      );
      final expected = languages.firstWhere(
        (l) => l.languageCode == resolved.languageCode,
        orElse: () => resolved,
      );
      expect(container.read(localeControllerProvider), expected);
      container
          .read(localeControllerProvider.notifier)
          .setLocale(
            const Locale('en'),
          );
      expect(container.read(localeControllerProvider), const Locale('en'));
      container.read(localeControllerProvider.notifier).resetToDevice();
      expect(container.read(localeControllerProvider), expected);
    });
  }
  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$language ${mode.name} rejected login and recovery', (
        tester,
      ) async {
        if (!nativeSurface) {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
        }
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final auth = FakeAuth();
        var rejected = true;
        await pumpDesignApp(
          tester,
          auth: auth,
          language: language,
          mode: mode,
          handler: (request) async =>
              rejected ? problem('invalid-token', 401) : normalApi(request),
        );
        expect(auth.refreshes, [false, true]);
        final title = find.byKey(const ValueKey('failure-title'));
        final body = find.byKey(const ValueKey('failure-message'));
        final icon = find.byIcon(LucideIcons.circleAlert);
        final l10n = AppLocalizations.of(tester.element(title));
        expect(find.text(l10n.sessionErrorTitle), findsOneWidget);
        expect(tester.getTopLeft(body).dx, tester.getTopLeft(icon).dx);
        expect(tester.getCenter(title).dy, tester.getCenter(icon).dy);
        expect(
          tester.getTopLeft(body).dy,
          greaterThan(tester.getBottomLeft(title).dy),
        );
        expect(tester.takeException(), isNull);
        await capture?.call('session-$language-${mode.name}');
        rejected = false;
        await tester.scrollUntilVisible(
          find.text(l10n.retryAction),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.retryAction));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('failure-message')), findsNothing);
        expect(find.byKey(const ValueKey('book-book-a')), findsOneWidget);
      });
    }
  }
}
