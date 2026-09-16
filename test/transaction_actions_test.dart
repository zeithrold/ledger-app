import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/features/accounting/detail.dart';
import 'package:ledger_app/features/accounting/entry_editor.dart';

import 'support/accounting_fixture.dart';
import 'support/design_harness.dart';
import 'support/fakes.dart';

const ValueKey<String> menuKey = ValueKey('transaction-action-sheet');

Future<void> top(WidgetTester tester) async {
  final scrollable = find
      .descendant(
        of: find.byType(CustomScrollView).last,
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('$language actions navigate once and refresh on return', (
      tester,
    ) async {
      var detailReads = 0;
      var writes = 0;
      final container = await pumpDesignApp(
        tester,
        language: language,
        initialLocation: '/transactions/fee',
        handler: (r) async {
          if (r.url.path.endsWith('/transactions/fee')) detailReads++;
          if (r.method != 'GET') writes++;
          return accountingFixture(r);
        },
      );
      for (final (key, path) in [
        ('transaction-edit', '/entry?edit=fee'),
        ('transaction-refund', '/entry?original=fee'),
        ('transaction-add-fee', '/entry?fee_for=fee'),
        ('transaction-link', '/link-transaction?source=fee&kind=related'),
        ('transaction-link-fee', '/link-transaction?source=fee&kind=fee'),
      ]) {
        await top(tester);
        await reveal(tester, 'transaction-more');
        expect(find.byKey(const ValueKey('transaction-refund')), findsNothing);
        if (key != 'transaction-edit') {
          final activate = tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey('transaction-more')),
              )
              .onPressed!;
          activate();
          activate();
          await tester.pumpAndSettle();
          expect(find.byKey(menuKey), findsOneWidget);
        }
        await reveal(tester, key);
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)), warnIfMissed: false);
        await tester.pumpAndSettle();
        final target = find.byType(
          path.startsWith('/entry') ? EntryEditor : LinkTransactionPage,
        );
        expect(target, findsOneWidget);
        expect(GoRouterState.of(tester.element(target)).uri.toString(), path);
        expect(find.byKey(menuKey), findsNothing);
        final before = detailReads;
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TransactionDetailPage), findsOneWidget);
        expect(detailReads, greaterThan(before));
        expect(
          container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/transactions/fee',
        );
      }
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (kind, status, refundable, expected) in [
    ('expense', 'posted', true, 4),
    ('expense', 'posted', false, 3),
    ('income', 'posted', false, 3),
    ('transfer', 'posted', false, 3),
    ('expense', 'void', true, 1),
  ]) {
    testWidgets('$kind $status refundable=$refundable keeps action rules', (
      tester,
    ) async {
      await pumpDesignApp(
        tester,
        initialLocation: '/transactions/fee',
        handler: (r) async {
          final response = await accountingFixture(r);
          if (!r.url.path.endsWith('/transactions/fee')) return response;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          data['transaction'] = transactionFixture(id: 'fee', kind: kind)
            ..['status'] = status;
          if (!refundable) data.remove('refundable_amount');
          return jsonResponse(data);
        },
      );
      await reveal(tester, 'transaction-more');
      expect(
        find.byKey(const ValueKey('transaction-edit')),
        status == 'posted' ? findsOneWidget : findsNothing,
      );
      await press(tester, 'transaction-more');
      final keys = [
        'transaction-refund',
        'transaction-add-fee',
        'transaction-link',
        'transaction-link-fee',
      ];
      expect(
        keys.where((k) => find.byKey(ValueKey(k)).evaluate().isNotEmpty).length,
        expected,
      );
      expect(
        find.text('New records'),
        status == 'posted' ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(const ValueKey('transaction-link')), findsOneWidget);
      await press(tester, 'close-transaction-actions');
    });
  }

  testWidgets('close, back, barrier and drag dismiss without writes', (
    tester,
  ) async {
    var writes = 0;
    await pumpDesignApp(
      tester,
      initialLocation: '/transactions/fee',
      handler: (r) async {
        if (r.method != 'GET') writes++;
        return accountingFixture(r);
      },
    );
    for (final method in ['close', 'back', 'barrier', 'drag']) {
      await press(tester, 'transaction-more');
      switch (method) {
        case 'close':
          await press(tester, 'close-transaction-actions');
        case 'back':
          await tester.binding.handlePopRoute();
        case 'barrier':
          await tester.tapAt(const Offset(10, 10));
        case 'drag':
          await tester.fling(find.byKey(menuKey), const Offset(0, 700), 1500);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(menuKey), findsNothing);
      expect(find.byType(TransactionDetailPage), findsOneWidget);
    }
    expect(writes, 0);
  });

  testWidgets('menu result is ignored after accounting scope changes', (
    tester,
  ) async {
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/transactions/fee',
      handler: accountingFixture,
    );
    await press(tester, 'transaction-more');
    container.read(accountingProvider).bookId = 'another-book';
    await press(tester, 'transaction-add-fee');
    expect(find.byType(EntryEditor), findsNothing);
    expect(find.byKey(menuKey), findsNothing);
  });

  testWidgets('refresh disables actions until detail has loaded', (
    tester,
  ) async {
    Completer<http.Response>? pending;
    await pumpDesignApp(
      tester,
      initialLocation: '/transactions/fee',
      handler: (r) async {
        if (pending != null && r.url.path.endsWith('/transactions/fee')) {
          return pending.future;
        }
        return accountingFixture(r);
      },
    );
    pending = Completer<http.Response>();
    await tester.tap(find.byKey(const ValueKey('refresh-transaction')));
    await tester.pump();
    final target = find.byKey(const ValueKey('transaction-more'));
    await tester.ensureVisible(target);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(target).onPressed, isNull);
    pending.complete(
      await accountingFixture(
        http.Request('GET', Uri.parse('https://example.com/transactions/fee')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(target).onPressed, isNotNull);
  });

  for (final (failureType, status) in [
    ('accounting-conflict', 409),
    ('service-unavailable', 503),
  ]) {
    testWidgets('saving and $failureType block actions until recovery', (
      tester,
    ) async {
      final pending = Completer<http.Response>();
      var posts = 0;
      await pumpDesignApp(
        tester,
        initialLocation: '/transactions/fee',
        handler: (r) async {
          if (r.method == 'POST') {
            posts++;
            return posts == 1
                ? pending.future
                : jsonResponse(<String, dynamic>{});
          }
          return accountingFixture(r);
        },
      );
      await press(tester, 'void-transaction');
      await reveal(tester, 'confirm-delete');
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pump();
      final target = find.byKey(const ValueKey('transaction-more'));
      await tester.scrollUntilVisible(
        target,
        -200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      expect(tester.widget<OutlinedButton>(target).onPressed, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const ValueKey('transaction-edit')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      pending.complete(problem(failureType, status));
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(target).onPressed, isNull);
      await press(tester, 'retry-detail-write');
      await top(tester);
      await reveal(tester, 'transaction-more');
      expect(tester.widget<OutlinedButton>(target).onPressed, isNotNull);
      expect(posts, status == 409 ? 1 : 2);
    });
  }

  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.system]) {
      for (final (size, scale) in [
        (const Size(390, 844), 1.0),
        (const Size(320, 568), 1.0),
        (const Size(320, 568), 2.0),
        (const Size(360, 800), 1.3),
        (const Size(844, 390), 1.0),
        (const Size(768, 1024), 1.0),
        (const Size(1280, 800), 1.0),
      ]) {
        testWidgets('$language ${mode.name} $size text $scale menu is usable', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpDesignApp(
            tester,
            language: language,
            mode: mode,
            initialLocation: '/transactions/fee',
            handler: accountingFixture,
          );
          await reveal(tester, 'transaction-more');
          final edit = tester.getRect(
            find.byKey(const ValueKey('transaction-edit')),
          );
          final more = tester.getRect(
            find.byKey(const ValueKey('transaction-more')),
          );
          if (size.width == 320 && scale == 2 && language == 'en') {
            expect(more.top, greaterThan(edit.bottom));
          }
          if (size.width == 390 && scale == 1) expect(more.top, edit.top);
          await press(tester, 'transaction-more');
          for (final key in [
            'transaction-refund',
            'transaction-add-fee',
            'transaction-link',
            'transaction-link-fee',
          ]) {
            await reveal(tester, key);
            final target = find.byKey(ValueKey(key));
            expect(target.hitTestable(), findsOneWidget);
            expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          }
          expect(
            find.text(
              language == 'zh'
                  ? '新记一笔手续费并关联当前账单'
                  : 'Record a new fee linked to this transaction',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              language == 'zh'
                  ? '从已有账单中选择手续费'
                  : 'Select a fee from existing transactions',
            ),
            findsOneWidget,
          );
          await press(tester, 'close-transaction-actions');
          expect(find.byKey(menuKey), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
