import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/features/accounting/detail.dart';
import 'package:ledger_app/features/accounting/entry_editor.dart';
import 'package:ledger_app/features/accounting/forms.dart';

import '../test/support/accounting_fixture.dart';
import '../test/support/design_harness.dart';
import '../test/support/fakes.dart';

/// Native UI writes use a deterministic HTTP boundary, never real finances.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native account, transfer, retry, refund, correction and reversal',
    (
      tester,
    ) async {
      final writes = <http.Request>[];
      var loseTransferResponse = true;
      var voided = false;
      final container = await pumpDesignApp(
        tester,
        initialLocation: '/',
        handler: (request) async {
          if (request.method == 'POST') {
            writes.add(request);
            final body = requestJson(request);
            if (request.url.path.endsWith('/accounts')) {
              return jsonResponse(accountFixture('native', 'CNY'), 201);
            }
            if (request.url.path.endsWith('/transactions') &&
                (body['entry'] as Map)['kind'] == 'transfer' &&
                loseTransferResponse) {
              loseTransferResponse = false;
              throw http.ClientException('Fixture lost the first response');
            }
            if (request.url.path.endsWith('/transfer/corrections')) {
              voided = true;
            }
            return jsonResponse(<String, dynamic>{}, 201);
          }
          final response = await accountingFixture(request);
          if (voided && request.url.path.endsWith('/transactions/transfer')) {
            final value = jsonDecode(response.body) as Map<String, dynamic>;
            (value['transaction'] as Map<String, dynamic>)['status'] = 'void';
            return jsonResponse(value);
          }
          return response;
        },
      );
      if (Platform.isAndroid && const bool.fromEnvironment('CAPTURE_VISUALS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      final router = container.read(routerProvider);
      Future<void> route(String path) async {
        router.go(path);
        await tester.pumpAndSettle();
      }

      Future<void> input(String key, String value) async {
        await reveal(tester, key);
        await tester.enterText(find.byKey(ValueKey(key)), value);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }

      Future<void> select(String key, String option) async {
        await press(tester, key);
        await press(tester, 'option-$option');
      }

      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_VISUALS')) {
          await binding.takeScreenshot('accounting-native-write-$name');
        }
      }

      Future<void> saveEntry() async {
        await press(tester, 'save-entry');
        await press(tester, 'confirm-entry');
        expect(find.byType(EntryEditor), findsNothing);
      }

      await route('/accounts/new');
      await input('reference-name', 'Native wallet');
      await input('opening-amount', '10');
      await press(tester, 'save-reference');
      expect(find.byType(ReferenceEditor), findsNothing);
      expect(requestJson(writes.last)['opening_amount'], '10.00');
      expect(requestJson(writes.last)['currency'], 'CNY');

      await route('/entry');
      await select('entry-kind', 'transfer');
      await input('entry-amount', '100');
      await select('entry-destination', 'cny');
      await input('entry-to-amount', '720');
      await press(tester, 'add-fee-toggle');
      await input('fee-amount', '1');
      await press(tester, 'save-entry');
      await capture('transfer-review');
      await press(tester, 'confirm-entry');
      expect(find.byType(EntryEditor), findsOneWidget);
      await capture('unknown-outcome');
      final original = writes.last;
      await press(tester, 'save-entry');
      expect(find.byType(EntryEditor), findsNothing);
      expect(writes.last.body, original.body);
      expect(
        writes.last.headers['Idempotency-Key'],
        original.headers['Idempotency-Key'],
      );
      final transfer = requestJson(original);
      expect((transfer['entry'] as Map)['amount'], '100.00');
      expect((transfer['entry'] as Map)['to_amount'], '720.00');
      expect((transfer['fee'] as Map)['amount'], '1.00');

      await route('/entry?original=fee');
      await input('entry-amount', '0.5');
      await saveEntry();
      final refund = requestJson(writes.last)['entry'] as Map;
      expect(refund['kind'], 'refund');
      expect(refund['original_id'], 'fee');
      expect(refund['amount'], '0.50');

      await route('/entry?edit=fee');
      await input('entry-amount', '2');
      await saveEntry();
      final correction = requestJson(writes.last);
      expect(correction['expected_revision'], 1);
      expect((correction['entry'] as Map)['amount'], '2.00');

      await route('/transactions/transfer');
      await press(tester, 'void-transaction');
      await capture('reversal-review');
      await press(tester, 'confirm-delete');
      expect(find.byType(TransactionSummary), findsOneWidget);
      expect(find.byKey(const ValueKey('void-transaction')), findsNothing);
      expect(requestJson(writes.last)['fees'], isEmpty);
      expect(requestJson(writes.last)['expected_revision'], 1);
      await capture('reversal-complete');
      expect(writes, hasLength(6));
    },
  );
}
