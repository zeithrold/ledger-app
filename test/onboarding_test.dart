import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/shared/choice_select.dart';
import 'identity_widget_test.dart' show application;
import 'support/fakes.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '$language $mode wizard selects, searches and preserves draft',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.8;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final auth = FakeAuth();
          final posts = <Map<String, dynamic>>[];
          await tester.pumpWidget(
            application(auth, (request) async {
              if (request.method == 'POST') {
                posts.add(jsonDecode(request.body) as Map<String, dynamic>);
                return jsonResponse(contextJson(locale: 'zh-CN'), 201);
              }
              return problem('bootstrap-required', 409);
            }),
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
          expect(find.byKey(const ValueKey('home-tab')), findsNothing);
          await tapKey(tester, 'base-currency');
          await tester.enterText(
            find.byKey(const ValueKey('choice-search')),
            'not-a-currency',
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('option-GBP')), findsNothing);
          await tester.enterText(
            find.byKey(const ValueKey('choice-search')),
            'GBP',
          );
          await tester.pumpAndSettle();
          await tapKey(tester, 'option-GBP');
          await tapKey(tester, 'setup-next');
          await tapKey(tester, 'setup-language');
          await tapKey(tester, 'locale-zh');
          expect(
            Localizations.localeOf(
              tester.element(find.byType(ChoiceSelect).first),
            ).languageCode,
            'zh',
          );
          await tapKey(tester, 'setup-timezone');
          await tester.enterText(
            find.byKey(const ValueKey('choice-search')),
            'Europe/London',
          );
          await tester.pumpAndSettle();
          await tapKey(tester, 'option-Europe/London');
          await tapKey(tester, 'setup-back');
          expect(
            tester
                .widget<ChoiceSelect>(
                  find.byKey(const ValueKey('base-currency')),
                )
                .value,
            'GBP',
          );
          await tapKey(tester, 'setup-next');
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('setup-timezone')),
            150,
          );
          expect(
            tester
                .widget<ChoiceSelect>(
                  find.byKey(const ValueKey('setup-timezone')),
                )
                .value,
            'Europe/London',
          );
          expect(posts, isEmpty);
          await tapKey(tester, 'create-space');
          expect(posts.single, {
            'base_currency': 'GBP',
            'timezone': 'Europe/London',
            'locale': 'zh',
          });
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('changing accounts resets the wizard draft', (tester) async {
    final auth = FakeAuth();
    await tester.pumpWidget(
      application(auth, (_) async => problem('bootstrap-required', 409)),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'setup-next');
    auth.change('another-session');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup-next')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-timezone')), findsNothing);
  });
}
