import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/identity/providers.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/accounting/detail.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/features/books/books_page.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

import 'support/accounting_fixture.dart';
import 'support/design_harness.dart';
import 'support/fakes.dart';

void main() {
  testWidgets('book detail retry stays inside its failure region', (
    tester,
  ) async {
    var fail = true;
    await pumpDesignApp(
      tester,
      initialLocation: '/books/book-a',
      handler: (request) async =>
          fail && request.url.path.endsWith('/books/book-a')
          ? problem('service-unavailable', 503)
          : normalApi(request),
    );
    expect(find.byType(BookDetailPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FailureView),
        matching: find.byKey(const ValueKey('retry-book')),
      ),
      findsOneWidget,
    );
    fail = false;
    await press(tester, 'retry-book');
    expect(find.text('CNY'), findsOneWidget);
    expect(find.byType(FailureView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail keeps both principals and accounts at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpDesignApp(
      tester,
      initialLocation: '/transactions/transfer',
      handler: accountingFixture,
    );
    final summary = find.byType(TransactionSummary);
    expect(
      find.descendant(of: summary, matching: find.text('100.00 USD')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('720.00 CNY')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('USD account')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('CNY account')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'related failure leaves principal available and blocks '
    'incomplete fee reversal',
    (tester) async {
      var fail = true;
      await pumpDesignApp(
        tester,
        initialLocation: '/transactions/transfer',
        handler: (request) async =>
            fail && request.url.path.endsWith('/transactions/fee')
            ? problem('service-unavailable', 503)
            : accountingFixture(request),
      );
      expect(find.byType(TransactionSummary), findsOneWidget);
      await reveal(tester, 'void-transaction');
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('void-transaction')))
            .onPressed,
        isNull,
      );
      fail = false;
      await press(tester, 'retry-related-fee');
      await reveal(tester, 'void-transaction');
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('void-transaction')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'conflict recovery keeps retry available after a failed refresh',
    (tester) async {
      var conflict = false;
      var refreshFails = true;
      await pumpDesignApp(
        tester,
        initialLocation: '/transactions/transfer',
        handler: (request) async {
          if (request.method == 'POST') {
            conflict = true;
            return problem('accounting-conflict', 409);
          }
          if (conflict &&
              refreshFails &&
              request.url.path.endsWith('/transactions/transfer')) {
            return problem('service-unavailable', 503);
          }
          return accountingFixture(request);
        },
      );
      await press(tester, 'void-transaction');
      await press(tester, 'confirm-delete');
      await press(tester, 'retry-detail-write');
      await reveal(tester, 'void-transaction');
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('void-transaction')))
            .onPressed,
        isNull,
      );
      refreshFails = false;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('retry-detail-load')),
        -200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await press(tester, 'retry-detail-load');
      await reveal(tester, 'void-transaction');
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('void-transaction')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'void review shows separate currencies and recomputes '
    'exact selected fee changes',
    (tester) async {
      var writes = 0;
      await pumpDesignApp(
        tester,
        initialLocation: '/transactions/transfer',
        handler: (request) async {
          if (request.method != 'GET') writes++;
          final response = await accountingFixture(request);
          if (request.url.path.endsWith('/transactions/fee')) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            (data['transaction'] as Map<String, dynamic>)['data'] = {
              ...(data['transaction'] as Map<String, dynamic>)['data']
                  as Map<String, dynamic>,
              'account_id': 'cny',
              'amount': '2.00',
            };
            return jsonResponse(data);
          }
          return response;
        },
      );
      await press(tester, 'void-transaction');
      final dialog = find.byType(AlertDialog);
      final fee = find.byKey(const ValueKey('void-fee-fee'));
      expect(tester.widget<CheckboxListTile>(fee).value, isFalse);
      expect(
        find.descendant(of: dialog, matching: find.text('2.00 CNY')),
        findsOneWidget,
      );
      final net = find.byKey(const ValueKey('void-net-cny'));
      expect(
        find.descendant(of: net, matching: find.text('-720.00 CNY')),
        findsOneWidget,
      );
      await tester.ensureVisible(fee);
      await tester.tap(fee);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: net, matching: find.text('-718.00 CNY')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Cancel')),
      );
      await tester.pumpAndSettle();
      expect(writes, 0);
    },
  );

  testWidgets(
    'void review remains operable at 320px and 200 percent in both locales',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final language in ['en', 'zh']) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          await pumpDesignApp(
            tester,
            language: language,
            mode: mode,
            initialLocation: '/transactions/transfer',
            handler: accountingFixture,
          );
          await press(tester, 'void-transaction');
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
          final fee = find.byKey(const ValueKey('void-fee-fee'));
          await tester.ensureVisible(fee);
          await tester.pumpAndSettle();
          await tester.tap(fee);
          await tester.pumpAndSettle();
          expect(tester.widget<CheckboxListTile>(fee).value, isTrue);
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        }
      }
    },
  );

  testWidgets(
    'returning from voided related transaction refreshes parent relation',
    (tester) async {
      var voided = false;
      final container = await pumpDesignApp(
        tester,
        initialLocation: '/transactions/transfer',
        handler: (request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/fee/corrections')) {
            voided = true;
            return jsonResponse(<String, dynamic>{});
          }
          final response = await accountingFixture(request);
          if (voided && request.url.path.endsWith('/transactions/fee')) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            (data['transaction'] as Map<String, dynamic>)['status'] = 'void';
            return jsonResponse(data);
          }
          return response;
        },
      );
      await press(tester, 'transaction-fee');
      await press(tester, 'void-transaction');
      await press(tester, 'confirm-delete');
      expect(voided, isTrue);
      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      await reveal(tester, 'transaction-fee');
      final relation = find.byKey(const ValueKey('transaction-fee'));
      expect(
        find.descendant(of: relation, matching: find.byType(LedgerBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: relation, matching: find.text('Deleted')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'link selection is read-only until explicit Link and submits once',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      await pumpDesignApp(
        tester,
        initialLocation: '/link-transaction?source=transfer&kind=related',
        handler: (request) async {
          if (request.method == 'POST') {
            writes.add(requestJson(request));
            return jsonResponse(<String, dynamic>{});
          }
          return accountingFixture(request);
        },
      );
      await reveal(tester, 'transaction-fee');
      await tester.tap(find.byKey(const ValueKey('transaction-fee')));
      await tester.pumpAndSettle();
      expect(find.byType(LinkTransactionPage), findsOneWidget);
      expect(find.byType(TransactionDetailPage), findsNothing);
      expect(writes, isEmpty);
      await press(tester, 'link-fee');
      expect(writes, [
        {'source_id': 'transfer', 'target_id': 'fee', 'kind': 'related'},
      ]);
    },
  );

  testWidgets(
    'failed preference retries selected patch and clears on session change',
    (tester) async {
      var attempts = 0;
      final patches = <Map<String, dynamic>>[];
      final auth = FakeAuth();
      final container = await pumpDesignApp(
        tester,
        initialLocation: '/settings',
        auth: auth,
        handler: (request) async {
          if (request.method == 'PATCH') {
            attempts++;
            patches.add(requestJson(request));
            if (attempts != 2) return problem('service-unavailable', 503);
          }
          return normalApi(request);
        },
      );
      final identity = container.read(identityProvider);
      await identity.savePreferences({'theme': 'dark'});
      await tester.pumpAndSettle();
      expect(identity.context!.preferences.theme, 'system');
      await press(tester, 'retry-preferences');
      expect(patches, [
        {'theme': 'dark'},
        {'theme': 'dark'},
      ]);
      expect(identity.context!.preferences.theme, 'dark');
      expect(identity.pendingPreferences, isNull);
      await identity.savePreferences({'locale': 'zh'});
      await tester.pumpAndSettle();
      expect(identity.pendingPreferences, {'locale': 'zh'});
      auth.change('session-b');
      await tester.pumpAndSettle();
      expect(identity.pendingPreferences, isNull);
      expect(find.byKey(const ValueKey('retry-preferences')), findsNothing);
    },
  );

  testWidgets('history retains transfer principals in each revision', (
    tester,
  ) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/transactions/transfer',
      handler: accountingFixture,
    );
    await press(tester, 'transaction-history');
    final review = find.byType(AccountingReviewLine);
    expect(review, findsNWidgets(2));
    expect(
      find.descendant(of: review, matching: find.text('100.00 USD')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: review, matching: find.text('720.00 CNY')),
      findsOneWidget,
    );
    expect(find.byType(LedgerMoneyText), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reversal exact arithmetic keeps source and destination separate',
    (tester) async {
      final container = await pumpDesignApp(
        tester,
        initialLocation: '/',
        handler: accountingFixture,
      );
      final controller = container.read(accountingProvider);
      final changes = reversalChanges(
        controller,
        controller.page!.transactions,
      );
      expect(changes['usd']!.decimal, '101.00');
      expect(changes['cny']!.decimal, '-720.00');
    },
  );
}
