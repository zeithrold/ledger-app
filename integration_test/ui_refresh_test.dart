import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/features/books/books_page.dart';

import '../test/support/design_harness.dart';
import '../test/support/fakes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_VISUALS')) return;
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  for (final language in ['zh', 'en']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$language ${mode.name} native redesign and recovery', (
        tester,
      ) async {
        var fail = false;
        var preferences = <String, dynamic>{
          'locale': language == 'zh' ? 'zh-CN' : 'en',
          'theme': mode.name,
          'timezone': 'Asia/Shanghai',
        };
        await pumpDesignApp(
          tester,
          language: language,
          mode: mode,
          handler: (request) async {
            if (request.method == 'PATCH') {
              preferences = {
                ...preferences,
                ...jsonDecode(request.body) as Map<String, dynamic>,
              };
              return jsonResponse(preferences);
            }
            if (request.url.path.endsWith('/me')) {
              return jsonResponse({
                ...contextJson(),
                'preferences': preferences,
              });
            }
            if (fail && request.url.path.endsWith('/books')) {
              return problem('service-unavailable', 503);
            }
            return normalApi(request);
          },
        );
        if (const bool.fromEnvironment('CAPTURE_VISUALS')) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
        }
        final prefix = 'native-$language-${mode.name}';
        await capture(tester, '$prefix-books');
        await tester.tap(find.byKey(const ValueKey('book-book-a')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        if (const bool.fromEnvironment('CAPTURE_VISUALS')) {
          await binding.takeScreenshot('$prefix-detail-transition');
        }
        await tester.pumpAndSettle();
        await capture(tester, '$prefix-detail');
        if (Theme.of(tester.element(find.byType(BookDetailPage))).platform ==
            TargetPlatform.iOS) {
          final size = tester.getSize(find.byType(Scaffold).first);
          await tester.timedDragFrom(
            Offset(1, size.height / 2),
            Offset(size.width * .8, 0),
            const Duration(milliseconds: 400),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BooksPage), findsOneWidget);
          await press(tester, 'book-book-a');
        }

        await press(tester, 'settings-tab');
        await capture(tester, '$prefix-settings');
        await press(tester, 'settings-appearance');
        await capture(tester, '$prefix-appearance');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await press(tester, 'edit-timezone');
        await capture(tester, '$prefix-timezones');
        final results = find.byKey(const ValueKey('choice-results-scroll'));
        final search = find.byKey(const ValueKey('choice-search'));
        await tester.drag(results, const Offset(0, -350));
        await tester.pumpAndSettle();
        final pinnedTop = tester.getTopLeft(search).dy;
        await tester.drag(results, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(search).dy, closeTo(pinnedTop, .01));
        expect(search.hitTestable(), findsOneWidget);
        await capture(tester, '$prefix-timezones-scrolled');
        await tester.enterText(
          find.byKey(const ValueKey('choice-search')),
          'London',
        );
        await tester.pumpAndSettle();
        await reveal(tester, 'option-Europe/London');
        expect(
          find.byKey(const ValueKey('option-Europe/London')).hitTestable(),
          findsOneWidget,
        );
        await capture(tester, '$prefix-keyboard');
        await press(tester, 'option-Europe/London');
        expect(find.byType(BottomSheet), findsNothing);
        final selectedContext = tester.element(
          find.byKey(const ValueKey('edit-timezone')),
        );
        expect(Localizations.localeOf(selectedContext).languageCode, language);
        expect(
          Theme.of(selectedContext).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        await press(tester, 'home-tab');
        expect(find.byType(BookDetailPage), findsOneWidget);
        await press(tester, 'book-back');
        fail = true;
        await press(tester, 'refresh-books');
        expect(find.byKey(const ValueKey('book-book-a')), findsOneWidget);
        await capture(tester, '$prefix-error');
        expect(tester.takeException(), isNull);

        final auth = FakeAuth(sessionKey: null);
        await pumpDesignApp(
          tester,
          language: language,
          mode: mode,
          auth: auth,
          handler: (_) async => problem('bootstrap-required', 409),
        );
        await capture(tester, '$prefix-welcome');
        await press(tester, 'browser-sign-in');
        await capture(tester, '$prefix-currency');
        await press(tester, 'setup-next');
        await capture(tester, '$prefix-setup');
        await press(tester, 'setup-back');
        expect(find.byKey(const ValueKey('base-currency')), findsOneWidget);
        await press(tester, 'setup-next');
        await press(tester, 'setup-language');
        await capture(tester, '$prefix-language');
        await press(tester, 'locale-$language');
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
