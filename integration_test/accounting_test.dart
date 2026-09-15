import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/accounting/models.dart';
import 'package:ledger_app/features/accounting/detail.dart';
import 'package:ledger_app/features/accounting/entry_editor.dart';
import 'package:ledger_app/features/accounting/forms.dart';

import '../test/accounting_widget_test.dart' show selectAccounting;
import '../test/support/design_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const endpoint = String.fromEnvironment('ACCOUNTING_TEST_URL');
  testWidgets('native manual accounting against isolated Go and PostgreSQL', (
    tester,
  ) async {
    expect(
      endpoint,
      isNotEmpty,
      reason: 'Start TestAccountingDeviceServer and pass its temporary URL.',
    );
    Future<void> until(bool Function() condition) async {
      for (var i = 0; i < 200 && !condition(); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(condition(), isTrue);
      await tester.pumpAndSettle();
    }

    final client = http.Client();
    addTearDown(client.close);
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/',
      apiBaseUrl: endpoint,
      client: client,
    );
    final c = container.read(accountingProvider);
    final router = container.read(routerProvider);
    await until(() => c.page != null);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    Future<void> capture(String name) async {
      if (!const bool.fromEnvironment('CAPTURE_VISUALS')) return;
      await tester.pumpAndSettle();
      await binding.takeScreenshot('accounting-$name');
    }

    Future<void> route(String path) async {
      unawaited(router.push<void>(path));
      await tester.pumpAndSettle();
    }

    Future<void> amount(String key, String value) async {
      await reveal(tester, key);
      await tester.enterText(find.byKey(ValueKey(key)), value);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    Future<void> save() async {
      await press(tester, 'save-entry');
      await press(tester, 'confirm-entry');
      await until(() => find.byType(EntryEditor).evaluate().isEmpty);
      expect(c.failure, isNull);
    }

    Future<AssetAccount> createAccount(String currency, String opening) async {
      await route('/accounts/new');
      await amount('reference-name', '$currency native');
      await selectAccounting(tester, 'account-currency', currency);
      await amount('opening-amount', opening);
      await capture('create-$currency');
      await press(tester, 'save-reference');
      await until(() => find.byType(ReferenceEditor).evaluate().isEmpty);
      return c.accounts.singleWhere((a) => a.name == '$currency native');
    }

    final usd = await createAccount('USD', '1000');
    final cny = await createAccount('CNY', '0');
    await route('/entry');
    await selectAccounting(tester, 'entry-kind', 'transfer');
    await selectAccounting(tester, 'entry-account', usd.id);
    await amount('entry-amount', '100');
    await selectAccounting(tester, 'entry-destination', cny.id);
    await amount('entry-to-amount', '720');
    await press(tester, 'add-fee-toggle');
    await amount('fee-amount', '1');
    await press(tester, 'save-entry');
    expect(find.text('-101.00 USD'), findsOneWidget);
    await capture('transfer-confirmation');
    await press(tester, 'confirm-entry');
    await until(() => find.byType(EntryEditor).evaluate().isEmpty);
    expect(c.account(usd.id)!.balance, '899.00');
    expect(c.account(cny.id)!.balance, '720.00');
    final transfer = c.page!.transactions.singleWhere(
      (t) => t.kind == 'transfer',
    );
    final feeId = c.page!.links.singleWhere((l) => l.kind == 'fee').targetId;
    await capture('home-balanced');

    await route('/entry');
    await selectAccounting(tester, 'entry-account', cny.id);
    final meals = c.categories.singleWhere((v) => v.systemCode == 'meals');
    await selectAccounting(tester, 'entry-category', meals.id);
    await amount('entry-amount', '100');
    await amount('entry-note', 'Native meal');
    await save();
    final expense = c.page!.transactions.singleWhere(
      (t) => t.note == 'Native meal',
    );
    await route('/entry?original=${expense.id}');
    await until(
      () => find.byKey(const ValueKey('entry-amount')).evaluate().isNotEmpty,
    );
    await amount('entry-amount', '30');
    await save();
    expect(c.account(cny.id)!.balance, '650.00');
    expect(
      c.summary!.totals.singleWhere((r) => r['currency'] == 'CNY')['amount'],
      '70.00',
    );

    await route('/entry?edit=$feeId');
    await until(
      () => find.byKey(const ValueKey('entry-amount')).evaluate().isNotEmpty,
    );
    await amount('entry-amount', '2');
    await save();
    expect(c.account(usd.id)!.balance, '898.00');
    final fee = await c.api.detail(c.bookId!, feeId);
    expect(fee.history, hasLength(2));
    expect(fee.journals, hasLength(3));
    expect(fee.journals.where((j) => j['reversal_of'] != null), hasLength(1));

    for (final language in ['en', 'zh']) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        container
            .read(localeControllerProvider.notifier)
            .setLocale(Locale(language));
        container.read(themeModeControllerProvider.notifier).setMode(mode);
        router.go('/transactions');
        await tester.pumpAndSettle();
        await capture('$language-${mode.name}-transactions');
        await route('/transactions/${transfer.id}');
        await until(
          () =>
              find.byType(TransactionDetailPage).evaluate().isNotEmpty &&
              find
                  .byKey(ValueKey('transaction-${transfer.id}'))
                  .evaluate()
                  .isNotEmpty,
        );
        await capture('$language-${mode.name}-detail');
        router.pop();
        await tester.pumpAndSettle();
        router.go('/accounts');
        await tester.pumpAndSettle();
        await capture('$language-${mode.name}-accounts');
      }
    }
    expect(tester.takeException(), isNull);
  });
}
