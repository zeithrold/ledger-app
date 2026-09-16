import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/theme/ledger_theme.dart';
import 'package:ledger_app/l10n/generated/app_localizations.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

Future<void> pumpGroup(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: dark ? LedgerTheme.dark : LedgerTheme.light,
    home: Scaffold(
      body: Directionality(
        textDirection: direction,
        child: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    for (final language in ['en', 'zh']) {
      for (final (width, scale) in [
        (320.0, 1.0),
        (360.0, 1.3),
        (390.0, 2.0),
        (844.0, 1.0),
      ]) {
        testWidgets('$language dark=$dark group fits $width at $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final labels = language == 'en'
              ? ['Edit', 'Add refund', 'Add separate fee']
              : ['编辑', '添加退款', '添加费用'];
          final presses = <int>[];
          await pumpGroup(
            tester,
            LedgerButtonGroup(
              actions: [
                for (var i = 0; i < labels.length; i++)
                  LedgerButtonGroupAction(
                    key: ValueKey(i),
                    label: labels[i],
                    onPressed: () => presses.add(i),
                  ),
              ],
            ),
            dark: dark,
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < labels.length; i++) {
            final button = find.byKey(ValueKey(i));
            expect(
              tester.getSize(button).shortestSide,
              greaterThanOrEqualTo(48),
            );
            expect(find.text(labels[i]).hitTestable(), findsOneWidget);
            await tester.tap(button);
          }
          expect(presses, [0, 1, 2]);
          final first = tester.getRect(find.byKey(const ValueKey(0)));
          final last = tester.getRect(find.byKey(const ValueKey(2)));
          if (scale == 2 && language == 'en') {
            expect(last.top, greaterThan(first.bottom));
            expect(first.width, width - 32);
            expect(last.width, first.width);
          }
          if (width == 844) {
            expect(first.top, last.top);
            expect(first.height, last.height);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'busy and disabled actions retain geometry and independent state',
    (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        var busy = false;
        var firstWrites = 0;
        var secondWrites = 0;
        await pumpGroup(
          tester,
          StatefulBuilder(
            builder: (context, update) => LedgerButtonGroup(
              key: const ValueKey('group'),
              actions: [
                LedgerButtonGroupAction(
                  key: const ValueKey('first'),
                  label: 'Link transaction',
                  busy: busy,
                  onPressed: () {
                    firstWrites++;
                    update(() => busy = true);
                  },
                ),
                LedgerButtonGroupAction(
                  key: const ValueKey('second'),
                  label: 'Add fee',
                  onPressed: () => secondWrites++,
                ),
                const LedgerButtonGroupAction(
                  key: ValueKey('disabled'),
                  label: 'Unavailable',
                  onPressed: null,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = tester.getRect(find.byKey(const ValueKey('group')));
        final first = tester.getRect(find.byKey(const ValueKey('first')));
        await tester.tap(find.byKey(const ValueKey('first')));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.getRect(find.byKey(const ValueKey('group'))), before);
        expect(tester.getRect(find.byKey(const ValueKey('first'))), first);
        expect(
          tester.getSemantics(find.byKey(const ValueKey('first'))),
          isSemantics(
            label: 'Link transaction',
            value: 'Loading…',
            isEnabled: false,
            hasSelectedState: false,
            isSelected: false,
            hasTapAction: false,
            isButton: true,
            hasEnabledState: true,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('first')));
        await tester.tap(find.byKey(const ValueKey('second')));
        await tester.tap(find.byKey(const ValueKey('disabled')));
        expect(firstWrites, 1);
        expect(secondWrites, 1);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('RTL order and keyboard actions retain normal button behavior', (
    tester,
  ) async {
    var calls = 0;
    await pumpGroup(
      tester,
      LedgerButtonGroup(
        actions: [
          LedgerButtonGroupAction(
            key: const ValueKey('first'),
            label: 'First',
            onPressed: () => calls++,
          ),
          const LedgerButtonGroupAction(label: 'Disabled', onPressed: null),
        ],
      ),
      direction: TextDirection.rtl,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('First')).dx,
      greaterThan(tester.getCenter(find.text('Disabled')).dx),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
