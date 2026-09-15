import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/theme/ledger_theme.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

import 'support/design_harness.dart';

void main() {
  testWidgets('incoming route paints over previous page during push and pop', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    const boundaryKey = ValueKey('route-pixels');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: LedgerTheme.light.copyWith(platform: TargetPlatform.iOS),
          home: const ColoredBox(color: Color(0xFFFF0000)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const LedgerPage(title: 'Detail', children: []),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    Future<void> expectOpaqueCanvas() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = await boundary.toImage();
      final bytes = (await image.toByteData())!;
      final index = ((image.height ~/ 2) * image.width + image.width - 20) * 4;
      final expected = LedgerTheme.light.scaffoldBackgroundColor.toARGB32();
      expect(bytes.getUint8(index), (expected >> 16) & 255);
      expect(bytes.getUint8(index + 1), (expected >> 8) & 255);
      expect(bytes.getUint8(index + 2), expected & 255);
      image.dispose();
    }

    await tester.runAsync(expectOpaqueCanvas);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(expectOpaqueCanvas);
    await tester.pumpAndSettle();
  });
  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$language $mode title and controls share a center', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final title = language == 'zh' ? '账本' : 'Books';
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: mode == ThemeMode.dark
                  ? LedgerTheme.dark
                  : LedgerTheme.light,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: LedgerPage(
                  title: title,
                  leading: IconButton(
                    key: const ValueKey('back'),
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_back),
                  ),
                  actions: [
                    IconButton(
                      key: const ValueKey('refresh'),
                      onPressed: () {},
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                  children: const [],
                ),
              ),
            ),
          );
          final center = tester.getCenter(find.text(title)).dy;
          expect(
            tester.getCenter(find.byKey(const ValueKey('back'))).dy,
            closeTo(center, .01),
          );
          expect(
            tester.getCenter(find.byKey(const ValueKey('refresh'))).dy,
            closeTo(center, .01),
          );
          expect(tester.takeException(), isNull);
        }
      });
      testWidgets('$language $mode timezone hierarchy and pinned search', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpDesignApp(tester, language: language, mode: mode);
        await press(tester, 'settings-tab');
        await press(tester, 'edit-timezone');
        final selected = tester.widget<RadioListTile<String>>(
          find.byKey(const ValueKey('option-Asia/Shanghai')),
        );
        expect(
          (selected.title! as Text).data,
          language == 'zh' ? '上海' : 'Shanghai',
        );
        expect(
          (selected.subtitle! as Text).data,
          contains('UTC+08:00 · Asia/Shanghai'),
        );
        final scroll = find.byKey(const ValueKey('choice-results-scroll'));
        final search = find.byKey(const ValueKey('choice-search'));
        await tester.drag(scroll, const Offset(0, -350));
        await tester.pumpAndSettle();
        final pinnedTop = tester.getTopLeft(search).dy;
        expect(
          pinnedTop - tester.getTopLeft(scroll).dy,
          greaterThanOrEqualTo(16),
        );
        await tester.drag(scroll, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(search).dy, closeTo(pinnedTop, .01));
        expect(search.hitTestable(), findsOneWidget);
        await tester.enterText(search, 'Europe/London');
        await tester.pumpAndSettle();
        await reveal(tester, 'option-Europe/London');
        expect(
          find.byKey(const ValueKey('option-Europe/London')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
