import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/accounting/entry_editor.dart';
import 'package:ledger_app/features/accounting/forms.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

import 'support/accounting_fixture.dart';
import 'support/design_harness.dart';
import 'support/fakes.dart';

Future<void> tapReadOnlyValue(WidgetTester tester, String key) async {
  await reveal(tester, key);
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(LedgerReadOnlyField),
  );
  expect(field, findsOneWidget);
  final value = find.descendant(
    of: field,
    matching: find.text(tester.widget<LedgerReadOnlyField>(field).value),
  );
  expect(value.hitTestable(), findsOneWidget);
  await tester.tap(value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('entry query changes replace the current source and draft', (
    tester,
  ) async {
    final container = await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: accountingFixture,
    );
    await reveal(tester, 'entry-amount');
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '999');
    final router = container.read(routerProvider)..go('/entry?original=fee');
    await tester.pumpAndSettle();
    var editor = tester.widget<EntryEditor>(find.byType(EntryEditor));
    expect(editor.originalId, 'fee');
    expect(editor.editId, isNull);
    await reveal(tester, 'entry-amount');
    String amount() => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey('entry-amount')),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;
    expect(amount(), isNot('999'));
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '0.25');
    router.go('/entry?edit=transfer');
    await tester.pumpAndSettle();
    editor = tester.widget<EntryEditor>(find.byType(EntryEditor));
    expect(editor.editId, 'transfer');
    expect(editor.originalId, isNull);
    await reveal(tester, 'entry-amount');
    expect(amount(), '100.00');
    expect(tester.takeException(), isNull);
  });

  for (final categories in [true, false]) {
    testWidgets(
      'catalog $categories separates book context from the add action',
      (tester) async {
        await pumpDesignApp(
          tester,
          initialLocation: categories ? '/categories' : '/counterparties',
          handler: accountingFixture,
        );
        final l10n = tester.element(find.byType(ReferencesPage)).l10n;
        final selector = tester.getRect(find.byType(AccountingBookSelector));
        final action = find.byWidgetPredicate(
          (widget) =>
              widget is LedgerAction &&
              widget.label ==
                  (categories ? l10n.addCategory : l10n.addCounterparty),
        );
        expect(
          tester.getRect(action).top - selector.bottom,
          greaterThanOrEqualTo(16),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '$language $mode invalid amount is visible and focused at 200%',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpDesignApp(
            tester,
            initialLocation: '/entry',
            language: language,
            mode: mode,
            handler: (request) {
              expect(request.method, 'GET');
              return accountingFixture(request);
            },
          );
          await reveal(tester, 'entry-amount');
          await tester.enterText(
            find.byKey(const ValueKey('entry-amount')),
            '1.001',
          );
          await press(tester, 'save-entry');
          final l10n = tester.element(find.byType(EntryEditor)).l10n;
          expect(find.text(l10n.invalidAmount).hitTestable(), findsOneWidget);
          final amount = tester.widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('entry-amount')),
              matching: find.byType(EditableText),
            ),
          );
          expect(amount.focusNode.hasFocus, isTrue);
          expect(find.byKey(const ValueKey('save-entry')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('account opening balance is optional and currency is explicit', (
    tester,
  ) async {
    http.Request? saved;
    await pumpDesignApp(
      tester,
      initialLocation: '/accounts/new',
      handler: (request) async {
        if (request.method == 'POST') {
          saved = request;
          return jsonResponse(accountFixture('new-account', 'CNY'), 201);
        }
        return accountingFixture(request);
      },
    );
    final l10n = tester.element(find.byType(ReferenceEditor)).l10n;
    expect(find.text(l10n.formAccountCurrency), findsOneWidget);
    expect(find.text(l10n.formAccountCurrencyHint), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reference-name')),
      'Travel wallet',
    );
    await reveal(tester, 'opening-amount');
    await tester.enterText(find.byKey(const ValueKey('opening-amount')), '');
    await press(tester, 'save-reference');
    expect(requestJson(saved!)['opening_amount'], '0.00');
    expect(find.byType(ReferenceEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refund keeps original amount visible and its category is read only',
    (tester) async {
      await pumpDesignApp(
        tester,
        initialLocation: '/entry?original=fee',
        handler: accountingFixture,
      );
      final l10n = tester.element(find.byType(EntryEditor)).l10n;
      expect(find.text(l10n.formOriginalExpense), findsOneWidget);
      expect(find.text(l10n.refundRemaining), findsOneWidget);
      await reveal(tester, 'entry-amount');
      await tester.enterText(find.byKey(const ValueKey('entry-amount')), '2');
      await press(tester, 'save-entry');
      expect(
        find.text(l10n.formRefundLimitError).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('1.00 USD'), findsWidgets);
      await tapReadOnlyValue(tester, 'entry-category');
      expect(find.byKey(const ValueKey('choice-search')), findsNothing);
      expect(find.text(l10n.formRefundCategoryFixed), findsOneWidget);
    },
  );

  testWidgets(
    'selected fee correction has padded fields and complete review',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDesignApp(
        tester,
        initialLocation: '/entry?edit=transfer',
        handler: accountingFixture,
      );
      await press(tester, 'include-fee-fee');
      await reveal(tester, 'fee-amount-fee');
      final amount = find.byKey(const ValueKey('fee-amount-fee'));
      final surface = find
          .ancestor(of: amount, matching: find.byType(LedgerSurface))
          .first;
      expect(
        tester.getRect(amount).left - tester.getRect(surface).left,
        greaterThanOrEqualTo(16),
      );
      expect(
        tester.getRect(surface).right - tester.getRect(amount).right,
        greaterThanOrEqualTo(16),
      );
      await tester.enterText(amount, '2');
      await press(tester, 'save-entry');
      final l10n = tester.element(find.byType(EntryEditor)).l10n;
      expect(find.text(l10n.formPreviousFee), findsOneWidget);
      expect(find.text(l10n.formUpdatedFee), findsOneWidget);
      expect(find.text('1.00 USD'), findsWidgets);
      expect(find.text('2.00 USD'), findsWidgets);
      expect(find.text('-1.00 USD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quick category creation keeps transaction type and returns to its draft',
    (tester) async {
      var created = false;
      http.Request? create;
      await pumpDesignApp(
        tester,
        initialLocation: '/entry',
        handler: (request) async {
          if (request.method == 'POST') {
            create = request;
            created = true;
            return jsonResponse({'id': 'new-category'}, 201);
          }
          if (request.url.path.endsWith('/categories') && created) {
            return jsonResponse({
              'categories': [
                {
                  'id': 'new-category',
                  'name': 'Travel meals',
                  'kind': 'expense',
                  'revision': 1,
                  'archived': false,
                },
              ],
            });
          }
          return accountingFixture(request);
        },
      );
      await reveal(tester, 'entry-amount');
      await tester.enterText(
        find.byKey(const ValueKey('entry-amount')),
        '12.34',
      );
      await press(tester, 'entry-add-category');
      await tapReadOnlyValue(tester, 'category-kind');
      expect(find.byKey(const ValueKey('option-income')), findsNothing);
      await reveal(tester, 'reference-name');
      await tester.enterText(
        find.byKey(const ValueKey('reference-name')),
        'Travel meals',
      );
      await press(tester, 'save-reference');
      expect(requestJson(create!)['kind'], 'expense');
      expect(find.byType(EntryEditor), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('entry-amount')))
            .controller!
            .text,
        '12.34',
      );
      expect(find.text('Travel meals'), findsOneWidget);
      expect(find.text('new-category'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'correction conflict compares latest data without overwriting its draft',
    (tester) async {
      final writes = <http.Request>[];
      var newer = false;
      await pumpDesignApp(
        tester,
        initialLocation: '/entry?edit=fee',
        handler: (request) async {
          if (request.method == 'POST') {
            writes.add(request);
            if (writes.length == 1) {
              newer = true;
              return problem('accounting-conflict', 409);
            }
            return jsonResponse({
              'transactions': <Object>[],
              'links': <Object>[],
            });
          }
          if (newer && request.url.path.endsWith('/transactions/fee')) {
            final latest = transactionFixture(
              id: 'fee',
              kind: 'expense',
              amount: '1.50',
            )..['revision'] = 2;
            return jsonResponse({
              'transaction': latest,
              'links': <Object>[],
              'history': <Object>[],
            });
          }
          return accountingFixture(request);
        },
      );
      await reveal(tester, 'entry-amount');
      await tester.enterText(find.byKey(const ValueKey('entry-amount')), '2');
      await reveal(tester, 'entry-note');
      await tester.enterText(
        find.byKey(const ValueKey('entry-note')),
        'Keep this draft',
      );
      await press(tester, 'save-entry');
      await press(tester, 'confirm-entry');
      await press(tester, 'entry-review-conflict');
      expect(find.text('1.50 USD'), findsOneWidget);
      expect(writes, hasLength(1));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('entry-amount')))
            .controller!
            .text,
        '2',
      );
      await press(tester, 'conflict-keep-draft');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('entry-note')))
            .controller!
            .text,
        'Keep this draft',
      );
      await press(tester, 'save-entry');
      await press(tester, 'confirm-entry');
      expect(writes, hasLength(2));
      expect(requestJson(writes.last)['expected_revision'], 2);
      expect((requestJson(writes.last)['entry'] as Map)['amount'], '2.00');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reference conflict explicitly keeps local input with latest revision',
    (tester) async {
      var newer = false;
      final writes = <http.Request>[];
      await pumpDesignApp(
        tester,
        initialLocation: '/accounts/usd/edit',
        handler: (request) async {
          if (request.method == 'PATCH') {
            writes.add(request);
            if (writes.length == 1) {
              newer = true;
              return problem('accounting-conflict', 409);
            }
            return jsonResponse(accountFixture('usd', 'USD'));
          }
          if (newer && request.url.path.endsWith('/accounts')) {
            final latest = accountFixture('usd', 'USD')
              ..['revision'] = 2
              ..['name'] = 'Remote name';
            return jsonResponse({
              'accounts': [latest, accountFixture('cny', 'CNY')],
            });
          }
          return accountingFixture(request);
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('reference-name')),
        'My name',
      );
      await press(tester, 'save-reference');
      await press(tester, 'reference-review-conflict');
      expect(find.text('Remote name'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('reference-name')))
            .controller!
            .text,
        'My name',
      );
      await press(tester, 'conflict-keep-draft');
      await press(tester, 'save-reference');
      expect(requestJson(writes.last)['expected_revision'], 2);
      expect(requestJson(writes.last)['name'], 'My name');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saving and uncertain retry preserve action state and original request',
    (tester) async {
      final delayed = Completer<http.Response>();
      final writes = <http.Request>[];
      await pumpDesignApp(
        tester,
        initialLocation: '/entry',
        handler: (request) async {
          if (request.method == 'POST') {
            writes.add(request);
            if (writes.length == 1) return delayed.future;
            return jsonResponse({
              'transactions': <Object>[],
              'links': <Object>[],
            });
          }
          return accountingFixture(request);
        },
      );
      await reveal(tester, 'entry-amount');
      await tester.enterText(find.byKey(const ValueKey('entry-amount')), '1');
      await press(tester, 'save-entry');
      await tester.tap(find.byKey(const ValueKey('confirm-entry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final l10n = tester.element(find.byType(EntryEditor)).l10n;
      final action = tester.widget<LedgerAction>(
        find.byKey(const ValueKey('save-entry')),
      );
      expect(action.busy, isTrue);
      expect(action.label, l10n.formSaving);
      delayed.completeError(http.ClientException('lost response'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.formPendingBody), findsOneWidget);
      expect(
        tester
            .widget<LedgerAction>(find.byKey(const ValueKey('save-entry')))
            .label,
        l10n.formResolveSave,
      );
      await press(tester, 'save-entry');
      expect(writes, hasLength(2));
      expect(writes.first.body, writes.last.body);
      expect(
        writes.first.headers['Idempotency-Key'],
        writes.last.headers['Idempotency-Key'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('date picker cancellation leaves the typed date intact', (
    tester,
  ) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: accountingFixture,
    );
    await reveal(tester, 'entry-date');
    await tester.enterText(
      find.byKey(const ValueKey('entry-date')),
      '2026-09-14',
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await tester.tap(find.byTooltip(l10n.formChooseDate));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('entry-date')))
          .controller!
          .text,
      '2026-09-14',
    );
    expect(tester.takeException(), isNull);
  });

  for (final unavailable in [false, true]) {
    testWidgets(
      'correction keeps its draft locked after '
      '${unavailable ? 'deletion' : 'failed latest read'}',
      (tester) async {
        var conflicted = false;
        var writes = 0;
        await pumpDesignApp(
          tester,
          initialLocation: '/entry?edit=fee',
          handler: (request) async {
            if (request.method == 'POST') {
              writes++;
              conflicted = true;
              return problem('accounting-conflict', 409);
            }
            if (conflicted && request.url.path.endsWith('/transactions/fee')) {
              if (!unavailable) return problem('service-unavailable', 503);
              final deleted =
                  transactionFixture(id: 'fee', kind: 'expense', amount: '1.50')
                    ..['revision'] = 2
                    ..['status'] = 'void';
              return jsonResponse({
                'transaction': deleted,
                'links': <Object>[],
                'history': <Object>[],
              });
            }
            return accountingFixture(request);
          },
        );
        await reveal(tester, 'entry-amount');
        await tester.enterText(find.byKey(const ValueKey('entry-amount')), '2');
        await press(tester, 'save-entry');
        await press(tester, 'confirm-entry');
        await press(tester, 'entry-review-conflict');
        final l10n = tester.element(find.byType(EntryEditor)).l10n;
        if (unavailable) {
          expect(
            find.text(l10n.formRecordUnavailable).hitTestable(),
            findsOneWidget,
          );
        }
        expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('entry-amount')))
              .controller!
              .text,
          '2',
        );
        await press(tester, 'save-entry');
        expect(writes, 1);
        expect(find.byKey(const ValueKey('confirm-entry')), findsNothing);
        if (unavailable) {
          expect(find.text(l10n.formRecordUnavailable), findsOneWidget);
          expect(
            find.byKey(const ValueKey('entry-review-conflict')),
            findsNothing,
          );
        } else {
          expect(find.text(l10n.serviceUnavailable), findsOneWidget);
          expect(
            find.byKey(const ValueKey('entry-review-conflict')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reference latest-read failure does not unlock the old revision',
    (tester) async {
      var conflicted = false;
      var writes = 0;
      await pumpDesignApp(
        tester,
        initialLocation: '/accounts/usd/edit',
        handler: (request) async {
          if (request.method == 'PATCH') {
            writes++;
            conflicted = true;
            return problem('accounting-conflict', 409);
          }
          if (conflicted && request.url.path.endsWith('/accounts')) {
            return problem('service-unavailable', 503);
          }
          return accountingFixture(request);
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('reference-name')),
        'My draft',
      );
      await press(tester, 'save-reference');
      await press(tester, 'reference-review-conflict');
      await press(tester, 'save-reference');
      expect(writes, 1);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('reference-name')))
            .controller!
            .text,
        'My draft',
      );
      expect(
        find.byKey(const ValueKey('reference-review-conflict')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
