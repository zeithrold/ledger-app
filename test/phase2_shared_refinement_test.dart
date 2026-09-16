import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/theme/ledger_theme.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/l10n/generated/app_localizations.dart';
import 'package:ledger_app/shared/choice_select.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

Future<void> pumpSurface(
  WidgetTester tester,
  Widget child, {
  String language = 'en',
  bool dark = false,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: dark ? LedgerTheme.dark : LedgerTheme.light,
      home: Scaffold(body: SafeArea(child: child)),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    for (final language in ['en', 'zh']) {
      for (final (width, scale) in [(320.0, 1.0), (390.0, 2.0)]) {
        testWidgets('$language dark=$dark $width/$scale retains every value', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final title = language == 'en' ? 'Account' : '账户';
          final subtitle = language == 'en' ? 'Bank account' : '银行账户';
          await pumpSurface(
            tester,
            SingleChildScrollView(
              child: Column(
                children: [
                  LedgerRow(title: title, subtitle: subtitle, value: '899 USD'),
                  LedgerFinancialRow(
                    title: title,
                    subtitle: subtitle,
                    value: '100 USD',
                    secondaryValue: '720 CNY',
                  ),
                ],
              ),
            ),
            language: language,
            dark: dark,
          );
          await tester.pumpAndSettle();
          expect(find.text(title), findsNWidgets(2));
          expect(find.text(subtitle), findsNWidgets(2));
          for (final value in ['899 USD', '100 USD', '720 CNY']) {
            expect(find.text(value), findsOneWidget);
            await tester.ensureVisible(find.text(value));
            await tester.pumpAndSettle();
            expect(find.text(value).hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('content surface and form section own padding without dividers', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      const LedgerFormSection(
        title: 'Fee',
        children: [Text('Explanation'), SizedBox(height: 16), Text('Amount')],
      ),
    );
    await tester.pumpAndSettle();
    final surface = tester.getRect(find.byType(LedgerSurface));
    final text = tester.getRect(find.text('Explanation'));
    expect(text.left - surface.left, 16);
    expect(text.top - surface.top, 16);
    expect(find.byType(Divider), findsNothing);
    expect(surface.height, greaterThanOrEqualTo(56));
  });

  testWidgets('selection fields validate, commit once and never show raw IDs', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    var value = '';
    var writes = 0;
    await pumpSurface(
      tester,
      StatefulBuilder(
        builder: (context, update) => Form(
          key: form,
          child: LedgerSelectField(
            label: 'Account',
            value: value,
            choices: const [Choice('a', 'Savings')],
            searchable: false,
            validator: (v) =>
                v == null || v.isEmpty ? 'Choose an account' : null,
            onChanged: (v) => update(() {
              value = v;
              writes++;
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Choose an account'), findsOneWidget);
    await tester.tap(find.text('Choose an option'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('option-a')));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(form.currentState!.validate(), isTrue);
    expect(find.text('Savings'), findsOneWidget);

    await pumpSurface(
      tester,
      const LedgerSelectField(
        label: 'Account',
        value: 'internal-missing-id',
        choices: [],
        onChanged: null,
        readOnly: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('internal-missing-id'), findsNothing);
    expect(find.text('Selection unavailable'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('eager form fields remain registered beyond the viewport', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    final controllers = List.generate(12, (_) => TextEditingController());
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
    await pumpSurface(
      tester,
      Form(
        key: form,
        child: LedgerPage(
          title: 'Entry',
          eagerChildren: true,
          children: [
            for (var i = 0; i < controllers.length; i++)
              LedgerTextField(
                label: 'Field $i',
                controller: controllers[i],
                validator: (value) => value!.isEmpty ? 'Required $i' : null,
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final invalid = form.currentState!.validateGranularly();
    expect(invalid, hasLength(12));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Required 11'));
    await tester.pumpAndSettle();
    expect(find.text('Required 11').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog close stays reachable after a long scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var writes = 0;
    await pumpSurface(
      tester,
      ChoiceSelect(
        label: 'Account',
        value: '0',
        choices: [for (var i = 0; i < 80; i++) Choice('$i', 'Account $i')],
        onChanged: (_) => writes++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('choice-results-scroll')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    final close = find.byKey(const ValueKey('choice-close'));
    expect(close.hitTestable(), findsOneWidget);
    expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large page titles use the full content width below controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpSurface(
      tester,
      LedgerPage(
        title: 'Transaction',
        leading: IconButton(
          onPressed: () {},
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
        ],
        children: const [Text('Transaction content')],
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('Transaction'));
    final back = tester.getRect(find.byTooltip('Back'));
    expect(title.left, 20);
    expect(title.right, 370);
    expect(title.top, greaterThanOrEqualTo(back.bottom + 8));
    expect(tester.takeException(), isNull);
  });
}
