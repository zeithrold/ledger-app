import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/identity/providers.dart';
import 'package:ledger_app/features/accounting/entry_editor.dart';
import 'package:ledger_app/l10n/l10n.dart';

import '../test/support/accounting_fixture.dart';
import '../test/support/design_harness.dart';
import '../test/support/fakes.dart';
import 'phase2_ui_mutation_test.dart' as accounting_mutations;
import 'ui_refresh_test.dart' as identity_visuals;

/// Native rendering acceptance uses isolated HTTP boundaries.
void main() {
  if (!const bool.fromEnvironment('ACCOUNTING_VISUALS_ONLY')) {
    identity_visuals.main();
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$language ${mode.name} accounting page refinement', (
        tester,
      ) async {
        var empty = true;
        var failRelated = false;
        final requests = <String>[];
        final container = await pumpDesignApp(
          tester,
          initialLocation: '/',
          language: language,
          mode: mode,
          handler: (request) async {
            requests.add(request.method);
            if (empty && request.url.path.endsWith('/summary')) {
              return normalApi(request);
            }
            if (failRelated && request.url.path.endsWith('/transactions/fee')) {
              return problem('service-unavailable', 503);
            }
            if (request.url.path.endsWith('/counterparties')) {
              return jsonResponse({
                'counterparties': [
                  {
                    'id': 'shop',
                    'name': 'Corner market',
                    'revision': 1,
                    'archived': false,
                  },
                ],
              });
            }
            return accountingFixture(request);
          },
        );
        final identity = container.read(identityProvider);
        expect(identity.context, isNotNull, reason: '${identity.error?.type}');
        if (Platform.isAndroid &&
            const bool.fromEnvironment('CAPTURE_VISUALS')) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
        }
        final router = container.read(routerProvider);
        final prefix = 'accounting-$language-${mode.name}';
        Future<void> capture(String name) async {
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_VISUALS')) {
            await binding.takeScreenshot('$prefix-$name');
          }
        }

        Future<void> page(String route, String name) async {
          router.go(route);
          await tester.pumpAndSettle();
          await capture(name);
        }

        await capture('home-empty');
        final emptyCard = find.byKey(const ValueKey('empty-month-summary'));
        expect(tester.getSize(emptyCard).height, greaterThanOrEqualTo(56));
        empty = false;
        await container.read(accountingProvider).refresh();
        await capture('home');
        for (final (route, name) in [
          ('/transactions', 'transactions'),
          ('/transaction-filters', 'filters'),
          ('/accounts', 'accounts'),
          ('/accounts/usd', 'account-detail'),
          ('/accounts/new', 'account-create'),
          ('/accounts/usd/edit', 'account-edit'),
          ('/categories', 'categories'),
          ('/categories/new', 'category-create'),
          ('/categories/meals/edit', 'category-edit'),
          ('/counterparties', 'counterparties'),
          ('/counterparties/new', 'counterparty-create'),
          ('/counterparties/shop/edit', 'counterparty-edit'),
          ('/entry', 'expense-create'),
          ('/entry?original=fee', 'refund-create'),
          ('/entry?fee_for=transfer', 'fee-create'),
          ('/entry?edit=transfer', 'transfer-correct'),
        ]) {
          await page(route, name);
        }
        await press(tester, 'include-fee-fee');
        await reveal(tester, 'fee-amount-fee');
        await capture('fee-fields');
        await tester.enterText(
          find.byKey(const ValueKey('fee-amount-fee')),
          '2',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await press(tester, 'save-entry');
        expect(find.byType(AlertDialog), findsOneWidget);
        await capture('correction-review');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await page('/transactions/transfer', 'detail');
        await press(tester, 'transaction-history');
        await capture('history');
        final historyDestination = find.descendant(
          of: find.byKey(const ValueKey('transaction-history')),
          matching: find.text('720.00 CNY'),
        );
        await tester.ensureVisible(historyDestination);
        await tester.pumpAndSettle();
        expect(historyDestination.hitTestable(), findsOneWidget);
        await capture('history-values');
        await press(tester, 'void-transaction');
        await capture('reversal-review');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await page('/link-transaction?source=transfer&kind=related', 'link');
        failRelated = true;
        await page('/transactions/transfer', 'partial-detail');
        await reveal(tester, 'retry-related-fee');
        await capture('relation-error');
        failRelated = false;
        await press(tester, 'retry-related-fee');
        await capture('relation-recovered');

        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await page('/', 'large-home');
        await page('/transactions/transfer', 'large-detail');
        await page('/entry', 'large-form');
        await reveal(tester, 'entry-amount');
        await tester.enterText(
          find.byKey(const ValueKey('entry-amount')),
          '1.001',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await press(tester, 'save-entry');
        final l10n = tester.element(find.byType(EntryEditor)).l10n;
        expect(find.text(l10n.invalidAmount).hitTestable(), findsOneWidget);
        await capture('large-field-error');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await page('/entry', 'entry-date');
        await reveal(tester, 'entry-date');
        await tester.tap(find.byTooltip(l10n.formChooseDate));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await capture('calendar');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await page('/', 'final-home');
        expect(requests, everyElement('GET'));
      });
    }
  }
  accounting_mutations.main();
}
