import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/core/accounting/accounting_api.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/features/accounting/entry_editor.dart';

import 'support/accounting_fixture.dart';
import 'support/design_harness.dart';
import 'support/fakes.dart';

Future<void> selectAccounting(
  WidgetTester tester,
  String key,
  String value,
) async {
  await press(tester, key);
  final search = find.byKey(const ValueKey('choice-search'));
  if (search.evaluate().isNotEmpty) {
    await tester.enterText(search, value);
    await tester.pumpAndSettle();
  }
  final option = find.byKey(ValueKey('option-$value'));
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('transfer confirmation and timeout retry preserve exact input', (
    tester,
  ) async {
    final writes = <http.Request>[];
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/',
      handler: (r) async {
        if (r.method == 'POST') {
          writes.add(r);
          if (writes.length == 1) throw http.ClientException('lost response');
          return jsonResponse({
            'transactions': <Object>[],
            'links': <Object>[],
          }, 201);
        }
        return accountingFixture(r);
      },
    );
    await press(tester, 'home-add-transaction');
    await selectAccounting(tester, 'entry-kind', 'transfer');
    await selectAccounting(tester, 'entry-account', 'usd');
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '100');
    await selectAccounting(tester, 'entry-destination', 'cny');
    await tester.enterText(
      find.byKey(const ValueKey('entry-to-amount')),
      '720',
    );
    await press(tester, 'add-fee-toggle');
    await reveal(tester, 'fee-amount');
    await tester.enterText(find.byKey(const ValueKey('fee-amount')), '1');
    await press(tester, 'save-entry');
    expect(find.text('-101.00 USD'), findsOneWidget);
    expect(find.text('720.00 CNY'), findsWidgets);
    await press(tester, 'confirm-entry');
    expect(writes, hasLength(1));
    final body = requestJson(writes.first);
    expect((body['entry'] as Map)['amount'], '100.00');
    expect((body['entry'] as Map)['to_amount'], '720.00');
    expect((body['fee'] as Map)['amount'], '1.00');
    expect(find.byType(EntryEditor), findsOneWidget);
    expect(container.read(accountingProvider).pendingWrite, isNotNull);
    await press(tester, 'save-entry');
    expect(writes, hasLength(2));
    expect(writes[0].body, writes[1].body);
    expect(
      writes[0].headers['Idempotency-Key'],
      writes[1].headers['Idempotency-Key'],
    );
    expect(find.byType(EntryEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session switch discards drafts and ignores delayed old reads', (
    tester,
  ) async {
    final auth = FakeAuth();
    final delayed = Completer<http.Response>();
    var hold = false;
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/',
      auth: auth,
      handler: (r) {
        if (hold && r.url.path.endsWith('/accounts')) return delayed.future;
        return accountingFixture(r);
      },
    );
    final c = container.read(accountingProvider);
    hold = true;
    final refresh = c.refresh();
    await tester.pump();
    auth.change(null);
    await tester.pumpAndSettle();
    delayed.complete(
      await accountingFixture(
        http.Request('GET', Uri.parse('https://example.com/accounts')),
      ),
    );
    await refresh;
    expect(c.accounts, isEmpty);
    expect(c.bookId, isNull);
    expect(c.pendingWrite, isNull);
  });

  testWidgets('ambiguous request survives navigation and blocks new writes', (
    tester,
  ) async {
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/',
      handler: (r) async => r.method == 'POST'
          ? throw http.ClientException('timeout')
          : accountingFixture(r),
    );
    final c = container.read(accountingProvider);
    final original = PendingLedgerWrite('POST', 'counterparties', {
      'name': 'Cafe',
    });
    final exposed = original.body!;
    exposed['name'] = 'Mutated';
    expect(original.body!['name'], 'Cafe');
    await expectLater(c.write(original), throwsA(isA<ApiFailure>()));
    container.read(routerProvider).go('/accounts');
    await tester.pumpAndSettle();
    expect(c.pendingWrite, same(original));
    await expectLater(
      c.write(PendingLedgerWrite('POST', 'counterparties', {'name': 'Other'})),
      throwsA(isA<ApiFailure>()),
    );
  });

  testWidgets(
    'editing selected fees carries independent revisions atomically',
    (
      tester,
    ) async {
      http.Request? submitted;
      final container = await pumpDesignApp(
        tester,
        initialLocation: '/',
        handler: (r) async {
          if (r.method == 'POST') {
            submitted = r;
            return jsonResponse({
              'transactions': <Object>[],
              'links': <Object>[],
            });
          }
          return accountingFixture(r);
        },
      );
      container.read(routerProvider).go('/entry?edit=transfer');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('entry-amount')), '120');
      final checkbox = find.byType(CheckboxListTile);
      await tester.scrollUntilVisible(
        checkbox,
        120,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
      await tester.ensureVisible(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: checkbox, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
      await reveal(tester, 'fee-amount-fee');
      await tester.enterText(find.byKey(const ValueKey('fee-amount-fee')), '2');
      await press(tester, 'save-entry');
      await press(tester, 'confirm-entry');
      final body = requestJson(submitted!);
      expect(
        submitted!.url.path,
        endsWith('/transactions/transfer/corrections'),
      );
      expect(body['expected_revision'], 1);
      expect((body['entry'] as Map)['amount'], '120.00');
      final fee = (body['fees'] as List).single as Map;
      expect(fee['id'], 'fee');
      expect(fee['expected_revision'], 1);
      expect((fee['entry'] as Map)['amount'], '2.00');
    },
  );

  testWidgets('stale correction retains entered amount for review', (
    tester,
  ) async {
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/',
      handler: (r) async => r.method == 'POST'
          ? problem('accounting-conflict', 409)
          : accountingFixture(r),
    );
    container.read(routerProvider).go('/entry?edit=fee');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '2');
    await press(tester, 'save-entry');
    await press(tester, 'confirm-entry');
    await reveal(tester, 'entry-amount');
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('entry-amount')),
    );
    expect(field.controller!.text, '2');
    expect(field.enabled, isTrue);
    expect(container.read(accountingProvider).pendingWrite, isNull);
    expect(find.byType(EntryEditor), findsOneWidget);
  });

  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$language $mode accounting supports 320px and 200% text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = await pumpDesignApp(
          tester,
          initialLocation: '/',
          language: language,
          mode: mode,
          handler: accountingFixture,
        );
        for (final path in [
          '/',
          '/transactions',
          '/accounts',
          '/settings',
          '/entry',
          '/accounts/new',
          '/categories',
          '/counterparties',
          '/transactions/transfer',
          '/entry?edit=transfer',
          '/entry?original=fee',
          '/transaction-filters',
        ]) {
          container.read(routerProvider).go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: path);
        }
        container.read(routerProvider).go('/entry');
        await tester.pumpAndSettle();
        await reveal(tester, 'entry-amount');
        await tester.enterText(
          find.byKey(const ValueKey('entry-amount')),
          '1.001',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await press(tester, 'save-entry');
        expect(tester.takeException(), isNull);
        expect(find.byType(EntryEditor), findsOneWidget);
        tester.view.resetViewInsets();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
