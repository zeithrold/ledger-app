import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/features/accounting/filters.dart';
import 'package:ledger_app/features/accounting/pages.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

import 'support/accounting_fixture.dart';
import 'support/design_harness.dart';
import 'support/fakes.dart';

void viewport(WidgetTester tester, {double scale = 1, double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Map<String, dynamic> listTransaction(String id, {String? note}) => {
  ...transactionFixture(id: id, kind: 'expense', amount: '12.50'),
  'data': {
    ...transactionFixture(id: id, kind: 'expense')['data'] as Map,
    'amount': '12.50',
    'note': ?note,
  },
};

http.Response transactionPage(
  List<Map<String, dynamic>> transactions, {
  String? cursor,
  List<Map<String, dynamic>> links = const [],
}) => jsonResponse({
  'transactions': transactions,
  'links': links,
  'next_cursor': ?cursor,
});

void main() {
  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('empty home keeps insets $language $mode at 200%', (
        tester,
      ) async {
        viewport(tester, scale: 2, width: 320);
        await pumpDesignApp(
          tester,
          initialLocation: '/',
          language: language,
          mode: mode,
          handler: (request) async {
            switch (request.url.path.split('/').last) {
              case 'accounts':
                return jsonResponse({'accounts': <Object>[]});
              case 'transactions':
                return transactionPage([]);
              case 'summary':
                return jsonResponse({
                  'totals': <Object>[],
                  'categories': <Object>[],
                });
            }
            return accountingFixture(request);
          },
        );
        await reveal(tester, 'empty-month-summary');
        final empty = find.byKey(const ValueKey('empty-month-summary'));
        final l10n = tester.element(empty).l10n;
        final group = find.ancestor(
          of: empty,
          matching: find.byType(LedgerGroup),
        );
        final text = find.text(l10n.emptySummary);
        expect(tester.getSize(group).height, greaterThanOrEqualTo(56));
        expect(
          tester.getTopLeft(text).dx - tester.getTopLeft(group).dx,
          16,
        );
        expect(
          tester.getTopLeft(text).dy - tester.getTopLeft(group).dy,
          16,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('empty home separates the account notice and monthly section', (
    tester,
  ) async {
    viewport(tester);
    await pumpDesignApp(
      tester,
      initialLocation: '/',
      handler: (request) async {
        if (request.url.path.endsWith('/accounts')) {
          return jsonResponse({'accounts': <Object>[]});
        }
        if (request.url.path.endsWith('/transactions')) {
          return transactionPage([]);
        }
        if (request.url.path.endsWith('/summary')) {
          return jsonResponse({'totals': <Object>[], 'categories': <Object>[]});
        }
        return accountingFixture(request);
      },
    );
    final notice = find.byType(LedgerNotice);
    final title = find.text('This month');
    expect(
      tester.getTopLeft(title).dy - tester.getBottomLeft(notice).dy,
      24,
    );
  });

  testWidgets(
    'refresh keeps visible content still and preserves failed reads',
    (
      tester,
    ) async {
      viewport(tester);
      final delayed = Completer<http.Response>();
      var hold = false;
      final container = await pumpDesignApp(
        tester,
        initialLocation: '/',
        handler: (request) {
          if (hold && request.url.path.endsWith('/accounts')) {
            return delayed.future;
          }
          return accountingFixture(request);
        },
      );
      final c = container.read(accountingProvider);
      final oldPage = c.page;
      final action = find.byKey(const ValueKey('home-add-transaction'));
      final before = tester.getTopLeft(action);
      hold = true;
      final refresh = c.refresh();
      await tester.pump();
      expect(tester.getTopLeft(action), before);
      expect(find.byType(LedgerLoading), findsNothing);
      expect(c.page, same(oldPage));
      delayed.completeError(http.ClientException('offline'));
      await refresh;
      await tester.pumpAndSettle();
      expect(c.page, same(oldPage));
      expect(c.failure, isNotNull);
      expect(c.loading, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'zh']) {
    testWidgets(
      'date range errors remain registered below the fold $language',
      (
        tester,
      ) async {
        viewport(tester, width: 320, scale: 2);
        var filteredRequests = 0;
        await pumpDesignApp(
          tester,
          initialLocation: '/transaction-filters',
          language: language,
          handler: (request) {
            if (request.url.path.endsWith('/transactions') &&
                request.url.queryParameters.containsKey('from')) {
              filteredRequests++;
            }
            return accountingFixture(request);
          },
        );
        await reveal(tester, 'filter-from');
        await tester.enterText(
          find.byKey(const ValueKey('filter-from')),
          '2026-09-20',
        );
        await reveal(tester, 'filter-to');
        await tester.enterText(
          find.byKey(const ValueKey('filter-to')),
          '2026-09-01',
        );
        await press(tester, 'apply-transaction-filters');
        final field = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey('filter-to')),
            matching: find.byType(EditableText),
          ),
        );
        final l10n = tester.element(find.byType(TransactionFiltersPage)).l10n;
        expect(find.text(l10n.invalidDateRange), findsOneWidget);
        expect(field.focusNode.hasFocus, isTrue);
        expect(filteredRequests, 0);
        await reveal(tester, 'filter-from');
        await tester.enterText(
          find.byKey(const ValueKey('filter-from')),
          '2026-02-30',
        );
        await press(tester, 'apply-transaction-filters');
        expect(find.text(l10n.invalidDate), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byKey(const ValueKey('filter-from')),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        expect(filteredRequests, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'filter apply freezes drafts and failure preserves applied results',
    (
      tester,
    ) async {
      viewport(tester);
      final delayed = Completer<http.Response>();
      var matchingRequests = 0;
      var succeed = false;
      final container = await pumpDesignApp(
        tester,
        initialLocation: '/transactions',
        handler: (request) {
          if (request.url.path.endsWith('/transactions') &&
              request.url.queryParameters['kind'] == 'income') {
            matchingRequests++;
            return succeed
                ? Future.value(transactionPage([listTransaction('filtered')]))
                : delayed.future;
          }
          return accountingFixture(request);
        },
      );
      final c = container.read(accountingProvider);
      final oldPage = c.page;
      await press(tester, 'transaction-filters');
      await press(tester, 'filter-kind');
      await press(tester, 'option-income');
      await reveal(tester, 'apply-transaction-filters');
      await tester.tap(find.byKey(const ValueKey('apply-transaction-filters')));
      await tester.pump();
      final button = tester.widget<LedgerAction>(
        find.byKey(const ValueKey('apply-transaction-filters')),
      );
      expect(button.busy, isTrue);
      expect(button.label, 'Apply filters');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('filter-from')))
            .enabled,
        isFalse,
      );
      expect(c.page, same(oldPage));
      expect(c.filters, isEmpty);
      await tester.tap(find.byKey(const ValueKey('apply-transaction-filters')));
      await tester.pump();
      expect(matchingRequests, 1);
      delayed.completeError(http.ClientException('offline'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionFiltersPage), findsOneWidget);
      expect(c.page, same(oldPage));
      expect(c.filters, isEmpty);
      expect(c.filterFailure, isNotNull);
      expect(c.failure, isNull);
      succeed = true;
      await press(tester, 'apply-transaction-filters');
      expect(find.byType(TransactionFiltersPage), findsNothing);
      expect(c.filters, {'kind': 'income'});
      expect(c.page!.transactions.single.id, 'filtered');
      expect(find.byKey(const ValueKey('applied-filters')), findsOneWidget);
      expect(find.textContaining('Income'), findsOneWidget);
      expect(matchingRequests, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a stale refresh cannot replace a newly applied filter', (
    tester,
  ) async {
    final delayed = Completer<http.Response>();
    var holdRefresh = false;
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/transactions',
      handler: (request) {
        if (request.url.path.endsWith('/transactions')) {
          if (request.url.queryParameters['kind'] == 'income') {
            return Future.value(transactionPage([listTransaction('filtered')]));
          }
          if (holdRefresh && request.url.queryParameters.isEmpty) {
            return delayed.future;
          }
        }
        return accountingFixture(request);
      },
    );
    final c = container.read(accountingProvider);
    holdRefresh = true;
    final refresh = c.refresh();
    expect(await c.filter({'kind': 'income'}), isTrue);
    delayed.complete(transactionPage([listTransaction('stale')]));
    await refresh;
    await tester.pumpAndSettle();
    expect(c.filters, {'kind': 'income'});
    expect(c.page!.transactions.single.id, 'filtered');
    expect(c.loading, isFalse);
    expect(c.filtering, isFalse);
  });

  testWidgets('pagination fails locally and retries the original cursor', (
    tester,
  ) async {
    viewport(tester);
    var attempts = 0;
    final cursors = <String>[];
    final delayed = Completer<http.Response>();
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/transactions',
      handler: (request) {
        if (request.url.path.endsWith('/transactions') &&
            request.url.queryParameters['limit'] != '5') {
          final cursor = request.url.queryParameters['cursor'];
          if (cursor != null) {
            attempts++;
            cursors.add(cursor);
            if (attempts == 1) throw http.ClientException('offline');
            return delayed.future;
          }
          return Future.value(
            transactionPage(
              [listTransaction('first')],
              cursor: 'next-1',
              links: [accountingLinkFixture],
            ),
          );
        }
        return accountingFixture(request);
      },
    );
    final c = container.read(accountingProvider);
    final firstPage = c.page;
    await press(tester, 'pagination-action');
    expect(c.failure, isNull);
    expect(c.moreFailure, isNotNull);
    expect(c.page, same(firstPage));
    expect(c.page!.nextCursor, 'next-1');
    final footer = find.byKey(const ValueKey('transactions-pagination'));
    expect(
      find.descendant(
        of: footer,
        matching: find.text('More transactions could not be loaded'),
      ),
      findsOneWidget,
    );
    await reveal(tester, 'pagination-action');
    await tester.tap(find.byKey(const ValueKey('pagination-action')));
    await tester.pump();
    final retry = tester.widget<LedgerAction>(
      find.byKey(const ValueKey('pagination-action')),
    );
    expect(retry.label, 'Retry loading');
    expect(retry.busy, isTrue);
    delayed.complete(
      transactionPage(
        [listTransaction('first'), listTransaction('second')],
        links: [accountingLinkFixture],
      ),
    );
    await tester.pumpAndSettle();
    expect(c.page!.transactions.map((row) => row.id), ['first', 'second']);
    expect(c.page!.links, hasLength(1));
    expect(c.moreFailure, isNull);
    expect(cursors, ['next-1', 'next-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh preserves the previously loaded page range', (
    tester,
  ) async {
    final queries = <Map<String, String>>[];
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/transactions',
      handler: (request) {
        if (request.url.path.endsWith('/transactions') &&
            request.url.queryParameters['limit'] != '5') {
          queries.add(request.url.queryParameters);
          if (request.url.queryParameters['cursor'] == 'next-1') {
            return Future.value(transactionPage([listTransaction('second')]));
          }
          return Future.value(
            transactionPage(
              [listTransaction('first')],
              cursor: 'next-1',
            ),
          );
        }
        return accountingFixture(request);
      },
    );
    final c = container.read(accountingProvider);
    await c.more();
    expect(c.page!.transactions, hasLength(2));
    queries.clear();
    await c.refresh();
    await tester.pumpAndSettle();
    expect(queries, [
      <String, String>{},
      {'cursor': 'next-1'},
    ]);
    expect(c.page!.transactions.map((row) => row.id), ['first', 'second']);
  });

  testWidgets('a list refresh retains its scroll position and visible row', (
    tester,
  ) async {
    viewport(tester);
    final delayed = Completer<http.Response>();
    var hold = false;
    final data = [for (var i = 0; i < 25; i++) listTransaction('row-$i')];
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/transactions',
      handler: (request) {
        if (request.url.path.endsWith('/transactions') &&
            request.url.queryParameters['limit'] != '5') {
          return hold ? delayed.future : Future.value(transactionPage(data));
        }
        return accountingFixture(request);
      },
    );
    await reveal(tester, 'transaction-row-18');
    final target = find.byKey(const ValueKey('transaction-row-18'));
    final before = tester.getTopLeft(target);
    hold = true;
    final refresh = container.read(accountingProvider).refresh();
    await tester.pump();
    expect(tester.getTopLeft(target), before);
    delayed.complete(transactionPage(data));
    await refresh;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(target), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account detail rereads its transactions after child returns', (
    tester,
  ) async {
    viewport(tester);
    var updated = false;
    var accountReads = 0;
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/accounts/usd',
      handler: (request) {
        if (request.url.path.endsWith('/accounts') && updated) {
          return Future.value(
            jsonResponse({
              'accounts': [
                {...accountFixture('usd', 'USD'), 'balance': '887.50'},
                accountFixture('cny', 'CNY'),
              ],
            }),
          );
        }
        if (request.url.path.endsWith('/transactions') &&
            request.url.queryParameters['account_id'] == 'usd') {
          accountReads++;
          return Future.value(
            transactionPage(
              [
                listTransaction(
                  'fee',
                  note: updated ? 'Updated entry' : 'Old entry',
                ),
              ],
              links: [accountingLinkFixture],
            ),
          );
        }
        return accountingFixture(request);
      },
    );
    expect(accountReads, 1);
    await press(tester, 'transaction-fee');
    updated = true;
    await container.read(accountingProvider).refresh();
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    await reveal(tester, 'transaction-fee');
    expect(accountReads, 2);
    expect(find.text('Updated entry'), findsOneWidget);
    expect(find.text('Old entry'), findsNothing);
    expect(
      container.read(accountingProvider).account('usd')!.balance,
      '887.50',
    );
    expect(find.textContaining('Fee link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('book changes discard a delayed filter result', (tester) async {
    final delayed = Completer<http.Response>();
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/',
      handler: (request) {
        if (request.url.path.endsWith('/books')) {
          return Future.value(
            jsonResponse({
              'books': [bookJson(), bookJson(id: 'book-b')],
            }),
          );
        }
        if (request.url.path.endsWith('/transactions')) {
          if (request.url.queryParameters['kind'] == 'income') {
            return delayed.future;
          }
          if (request.url.path.contains('book-b')) {
            return Future.value(transactionPage([listTransaction('new-book')]));
          }
        }
        return accountingFixture(request);
      },
    );
    final c = container.read(accountingProvider);
    final filtering = c.filter({'kind': 'income'});
    await c.selectBook('book-b');
    delayed.complete(transactionPage([listTransaction('old-book')]));
    expect(await filtering, isFalse);
    await tester.pumpAndSettle();
    expect(c.bookId, 'book-b');
    expect(c.filters, isEmpty);
    expect(c.page!.transactions.single.id, 'new-book');
    expect(c.filtering, isFalse);
    expect(c.filterFailure, isNull);
  });

  for (final archived in [false, true]) {
    testWidgets(
      'transactions explain account availability archived=$archived',
      (
        tester,
      ) async {
        viewport(tester);
        await pumpDesignApp(
          tester,
          initialLocation: '/transactions',
          handler: (request) {
            if (request.url.path.endsWith('/accounts')) {
              return Future.value(
                jsonResponse({
                  'accounts': [
                    if (archived)
                      {...accountFixture('usd', 'USD'), 'archived': true},
                  ],
                }),
              );
            }
            if (request.url.path.endsWith('/transactions')) {
              return Future.value(transactionPage([]));
            }
            return accountingFixture(request);
          },
        );
        expect(
          find.text(archived ? 'No active accounts' : 'Add your first account'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Add account'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Add transaction'),
          findsNothing,
        );
        if (archived) expect(find.text('Add your first account'), findsNothing);
      },
    );
  }

  testWidgets('a filter with no matches offers filter recovery', (
    tester,
  ) async {
    viewport(tester);
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/transactions',
      handler: (request) {
        if (request.url.queryParameters['kind'] == 'income') {
          return Future.value(transactionPage([]));
        }
        return accountingFixture(request);
      },
    );
    await container.read(accountingProvider).filter({'kind': 'income'});
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(TransactionsPage)).l10n;
    expect(find.text(l10n.noMatches), findsOneWidget);
    expect(find.text(l10n.noMatchingTransactionsBody), findsOneWidget);
    expect(find.text(l10n.emptyTransactionsBody), findsNothing);
    await press(tester, 'clear-transaction-filters');
    expect(container.read(accountingProvider).filters, isEmpty);
    expect(container.read(accountingProvider).page!.transactions, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
