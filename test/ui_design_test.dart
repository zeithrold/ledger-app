import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/app/theme/ledger_theme.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/features/books/books_page.dart';
import 'package:ledger_app/features/settings/settings_page.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_navigation.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

import 'support/design_harness.dart';
import 'support/fakes.dart';

void viewport(WidgetTester tester, Size size, double scale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (size, scale) in [
        (const Size(390, 844), 1.0),
        (const Size(320, 568), 1.0),
        (const Size(320, 568), 2.0),
        (const Size(360, 800), 1.3),
        (const Size(844, 390), 1.0),
        (const Size(768, 1024), 1.0),
        (const Size(1280, 800), 1.0),
      ]) {
        testWidgets('$language ${mode.name} $size text $scale pages', (
          tester,
        ) async {
          viewport(tester, size, scale);
          await pumpDesignApp(tester, language: language, mode: mode);
          expect(find.byKey(const ValueKey('book-book-a')), findsOneWidget);
          expect(
            find.byType(NavigationRail),
            size.width >= 600 ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
          await press(tester, 'book-book-a');
          expect(find.byType(BookDetailPage), findsOneWidget);
          expect(tester.takeException(), isNull);
          await press(tester, 'settings-tab');
          await press(tester, 'settings-appearance');
          await reveal(tester, 'theme-dark');
          expect(
            tester.getSize(find.byKey(const ValueKey('theme-dark'))).height,
            greaterThanOrEqualTo(48),
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            Theme.of(tester.element(find.byType(SettingsPage))).brightness,
            mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );
          await press(tester, 'settings-language');
          await reveal(tester, 'locale-$language');
          expect(
            find.byKey(ValueKey('locale-$language')).hitTestable(),
            findsOneWidget,
          );
          await press(tester, 'locale-$language');
          expect(find.byType(BottomSheet), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
      testWidgets('$language ${mode.name} keyboard leaves results operable', (
        tester,
      ) async {
        viewport(tester, const Size(320, 568), 2);
        final patches = <Map<String, dynamic>>[];
        await pumpDesignApp(
          tester,
          language: language,
          mode: mode,
          handler: (request) async {
            if (request.method == 'PATCH') {
              patches.add(jsonDecode(request.body) as Map<String, dynamic>);
            }
            return normalApi(request);
          },
        );
        await press(tester, 'settings-tab');
        await press(tester, 'edit-timezone');
        await tester.enterText(
          find.byKey(const ValueKey('choice-search')),
          'Europe/London',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final scroll = find.byKey(const ValueKey('choice-results-scroll'));
        expect(tester.getSize(scroll).height, greaterThan(48));
        await reveal(tester, 'option-Europe/London');
        final result = find.byKey(const ValueKey('option-Europe/London'));
        expect(result.hitTestable(), findsOneWidget);
        expect(tester.getRect(result).top, lessThan(268));
        expect(patches, isEmpty);
        await press(tester, 'option-Europe/London');
        expect(patches.single, {'timezone': 'Europe/London'});
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('selected radio labels retain readable accent color', (
    tester,
  ) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await pumpDesignApp(tester, mode: mode);
      await press(tester, 'settings-tab');
      await press(tester, 'settings-appearance');
      final label = find
          .descendant(
            of: find.byKey(ValueKey('theme-${mode.name}')),
            matching: find.byType(RichText),
          )
          .first;
      final text = tester.widget<RichText>(label).text;
      final theme = mode == ThemeMode.light
          ? LedgerTheme.light
          : LedgerTheme.dark;
      expect(text.style?.color, theme.colorScheme.primary);
    }
  });

  testWidgets('long book titles remain readable at large text sizes', (
    tester,
  ) async {
    viewport(tester, const Size(320, 568), 2);
    const name = 'A shared household ledger with a deliberately long name';
    await pumpDesignApp(
      tester,
      handler: (request) async {
        if (request.url.path.contains('/books/')) {
          return jsonResponse({...bookJson(), 'name': name});
        }
        return normalApi(request);
      },
    );
    await press(tester, 'book-book-a');
    expect(find.text(name), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('CNY'), 160);
    await tester.pumpAndSettle();
    expect(find.text('CNY').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('open selector follows system theme and cancel writes nothing', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844), 1);
    var patches = 0;
    final container = await pumpDesignApp(
      tester,
      mode: ThemeMode.system,
      handler: (request) async {
        if (request.method == 'PATCH') patches++;
        return normalApi(request);
      },
    );
    await press(tester, 'settings-tab');
    await press(tester, 'edit-timezone');
    final semantics = tester.ensureSemantics();
    final selected = find.byKey(const ValueKey('option-Asia/Shanghai'));
    final data = tester.getSemantics(selected).getSemanticsData();
    expect(data.flagsCollection.isChecked, ui.CheckedState.isTrue);
    expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    for (final brightness in [Brightness.dark, Brightness.light]) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpAndSettle();
      final context = tester.element(selected);
      expect(Theme.of(context).brightness, brightness);
    }
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    container
        .read(themeModeControllerProvider.notifier)
        .setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(selected)).brightness, Brightness.dark);
    await tester.enterText(
      find.byKey(const ValueKey('choice-search')),
      'ZZZNONE',
    );
    await tester.pumpAndSettle();
    expect(find.byType(RadioListTile<String>), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(patches, 0);
    semantics.dispose();
  });

  testWidgets('tab stacks and list scroll survive settings and system back', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844), 1);
    final container = await pumpDesignApp(
      tester,
      handler: (request) async {
        if (request.url.path.endsWith('/books')) {
          return jsonResponse({
            'books': [
              for (var i = 0; i < 20; i++)
                {...bookJson(id: 'book-$i'), 'name': 'Book $i'},
            ],
          });
        }
        return normalApi(request);
      },
    );
    await reveal(tester, 'book-book-12');
    final before = tester.getTopLeft(
      find.byKey(const ValueKey('book-book-12')),
    );
    await press(tester, 'book-book-12');
    await press(tester, 'settings-tab');
    await press(tester, 'home-tab');
    expect(find.byType(BookDetailPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BooksPage), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('book-book-12'))),
      before,
    );
    container.read(routerProvider).go('/books/book-direct');
    await tester.pumpAndSettle();
    await press(tester, 'book-back');
    expect(find.byType(BooksPage), findsOneWidget);
  });

  testWidgets('refresh keeps rows through pending request and failure', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var loads = 0;
    await pumpDesignApp(
      tester,
      handler: (request) async {
        if (request.url.path.endsWith('/books') && ++loads > 2) {
          return pending.future;
        }
        return normalApi(request);
      },
    );
    final book = find.byKey(const ValueKey('book-book-a'));
    final position = tester.getTopLeft(book);
    final refresh = find.byKey(const ValueKey('refresh-books'));
    await tester.tap(refresh);
    await tester.pump();
    expect(book, findsOneWidget);
    expect(tester.getTopLeft(book), position);
    final l10n = tester.element(find.byType(BooksPage)).l10n;
    final busyAction = tester.widget<IconButton>(refresh);
    expect(busyAction.tooltip, l10n.refreshingLabel);
    expect(busyAction.onPressed, isNull);
    expect(
      find.descendant(
        of: refresh,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(refresh);
    expect(loads, 3);
    pending.complete(problem('service-unavailable', 503));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('book-book-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('failure-message')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LedgerGroup),
        matching: find.byKey(const ValueKey('retry-books')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('primary action has a labeled 48 pixel touch target', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844), 1);
    await pumpDesignApp(tester, auth: FakeAuth(sessionKey: null));
    final semantics = tester.ensureSemantics();
    final action = find.descendant(
      of: find.byKey(const ValueKey('browser-sign-in')),
      matching: find.byType(FilledButton),
    );
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(find.byType(LedgerAction), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'navigation labels honor 200 percent text and retain selection semantics',
    (tester) async {
      viewport(tester, const Size(320, 568), 1);
      await pumpDesignApp(tester);
      final before = tester.getSize(find.byType(LedgerNavigation)).height;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('expanded-navigation')))
            .height,
        greaterThan(before),
      );
      final label = find.descendant(
        of: find.byKey(const ValueKey('home-tab')),
        matching: find.text('Home'),
      );
      final textContext = tester.element(label);
      final richText = tester.widget<RichText>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      expect(
        MediaQuery.textScalerOf(
          textContext,
        ).scale(richText.text.style!.fontSize!),
        24,
      );
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('home-tab')))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      await press(tester, 'settings-tab');
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('settings-tab')))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'appearance dismisses without writes and selection commits exactly once',
    (tester) async {
      viewport(tester, const Size(390, 844), 1);
      final patches = <Map<String, dynamic>>[];
      await pumpDesignApp(
        tester,
        handler: (request) async {
          if (request.method == 'PATCH') {
            final patch = jsonDecode(request.body) as Map<String, dynamic>;
            patches.add(patch);
            return jsonResponse({
              ...contextJson()['preferences'] as Map<String, dynamic>,
              ...patch,
            });
          }
          return normalApi(request);
        },
      );
      await press(tester, 'settings-tab');
      expect(find.byType(RadioListTile<String>), findsNothing);
      await press(tester, 'settings-appearance');
      expect(find.byType(RadioListTile<String>), findsNWidgets(3));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(patches, isEmpty);
      await press(tester, 'settings-appearance');
      await press(tester, 'theme-dark');
      expect(patches, [
        {'theme': 'dark'},
      ]);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.dark,
      );
      await press(tester, 'settings-appearance');
      await press(tester, 'theme-dark');
      expect(patches.length, 2);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets('keyboard focus reaches and activates Material preference rows', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844), 1);
    await pumpDesignApp(tester);
    await press(tester, 'settings-tab');
    // Pointer navigation leaves focus on the selected destination; restart
    // traversal at the page header and reach appearance through standard Tab.
    FocusManager.instance.primaryFocus?.unfocus();
    for (
      var i = 0;
      i < 12 && find.byType(BottomSheet).evaluate().isEmpty;
      i++
    ) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (focusContext != null &&
          focusContext.findAncestorWidgetOfExactType<LedgerRow>()?.title ==
              'Appearance') {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }
    }
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(RadioListTile<String>), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion removes theme and navigation animation', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844), 1);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = await pumpDesignApp(tester);
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .themeAnimationDuration,
      Duration.zero,
    );
    if (find.byType(NavigationBar).evaluate().isNotEmpty) {
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .animationDuration,
        Duration.zero,
      );
    } else {
      expect(find.byKey(const ValueKey('expanded-navigation')), findsOneWidget);
    }
    container
        .read(themeModeControllerProvider.notifier)
        .setMode(ThemeMode.dark);
    await tester.pump();
    expect(
      Theme.of(tester.element(find.byType(BooksPage))).brightness,
      Brightness.dark,
    );
    await press(tester, 'settings-tab');
    await tester.tap(find.byKey(const ValueKey('settings-appearance')));
    await tester.pump();
    final sheetContext = tester.element(
      find.byType(RadioListTile<String>).first,
    );
    expect(ModalRoute.of(sheetContext)!.animation!.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preference accessories align and timezone summary '
    'avoids duplicate identifiers',
    (tester) async {
      viewport(tester, const Size(390, 844), 1);
      await pumpDesignApp(tester);
      await press(tester, 'settings-tab');
      final rightEdges = <double>[];
      for (final key in [
        'settings-appearance',
        'settings-language',
        'edit-timezone',
      ]) {
        final entry = find.byKey(ValueKey(key));
        final accessory = find
            .descendant(of: entry, matching: find.byType(Icon))
            .last;
        rightEdges.add(tester.getBottomRight(accessory).dx);
      }
      expect(rightEdges[0], rightEdges[1]);
      expect(rightEdges[1], rightEdges[2]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('edit-timezone')),
          matching: find.text('Shanghai · UTC+08:00'),
        ),
        findsOneWidget,
      );
      await press(tester, 'edit-timezone');
      expect(find.text('Shanghai'), findsOneWidget);
      expect(find.textContaining('UTC+08:00 · Asia/Shanghai'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('semantic palette meets text and control contrast requirements', () {
    double ratio(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()];
      return (math.max(values[0], values[1]) + .05) /
          (math.min(values[0], values[1]) + .05);
    }

    for (final theme in [LedgerTheme.light, LedgerTheme.dark]) {
      final c = theme.colorScheme;
      for (final surface in [theme.scaffoldBackgroundColor, c.surface]) {
        expect(ratio(c.onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(ratio(c.onSurfaceVariant, surface), greaterThanOrEqualTo(4.5));
        expect(ratio(c.primary, surface), greaterThanOrEqualTo(4.5));
        expect(ratio(c.error, surface), greaterThanOrEqualTo(4.5));
        expect(
          ratio(c.outline, surface),
          greaterThanOrEqualTo(3),
        );
      }
      expect(ratio(c.primary, c.onPrimary), greaterThanOrEqualTo(4.5));
    }
  });
}
