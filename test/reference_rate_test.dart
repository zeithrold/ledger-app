import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ledger_app/features/accounting/entry_editor.dart';
import 'package:ledger_app/l10n/l10n.dart';

import 'support/accounting_fixture.dart';
import 'support/design_harness.dart';
import 'support/fakes.dart';
import 'support/select_helpers.dart';

const ValueKey<String> _rateKey = ValueKey('reference-rate');
const ValueKey<String> _useKey = ValueKey('reference-rate-use');
const ValueKey<String> _retryKey = ValueKey('reference-rate-retry');

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

/// Opens the entry form and selects a distinct cross-currency transfer pair.
Future<void> _selectTransfer(
  WidgetTester tester, {
  String account = 'usd',
  String destination = 'cny',
}) async {
  await selectAccounting(tester, 'entry-kind', 'transfer');
  await selectAccounting(tester, 'entry-account', account);
  await selectAccounting(tester, 'entry-destination', destination);
}

/// Serves the accounting fixture and records every exchange-rate pair.
Future<http.Response> Function(http.Request) _rates({
  Map<String, dynamic> Function(String base, String quote)? rate,
  List<Map<String, dynamic>>? accounts,
  List<String>? pairs,
}) => (request) async {
  if (request.url.path.endsWith('exchange-rates')) {
    pairs?.add(
      '${request.url.queryParameters['base']}'
      '/${request.url.queryParameters['quote']}',
    );
  }
  return accountingFixture(request, accounts: accounts, rate: rate);
};

void main() {
  testWidgets('the block appears only for a distinct cross-currency transfer', (
    tester,
  ) async {
    final pairs = <String>[];
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        pairs: pairs,
        accounts: [
          accountFixture('usd', 'USD'),
          accountFixture('cny', 'CNY'),
          accountFixture('usd2', 'USD', name: 'Second dollar'),
        ],
        rate: (base, quote) => marketRateFixture(base: base, quote: quote),
      ),
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    expect(find.byKey(_rateKey), findsNothing);
    await selectAccounting(tester, 'entry-kind', 'transfer');
    await selectAccounting(tester, 'entry-account', 'usd');
    expect(find.byKey(_rateKey), findsNothing);
    await selectAccounting(tester, 'entry-destination', 'cny');
    expect(find.byKey(_rateKey), findsOneWidget);
    expect(
      find.text(
        l10n.referenceRateAvailable('USD', '6.7082', 'CNY', '2026-09-15'),
      ),
      findsOneWidget,
    );
    // A same-currency pair never fetches or shows the block.
    await selectAccounting(tester, 'entry-destination', 'usd2');
    expect(find.byKey(_rateKey), findsNothing);
    expect(pairs, ['USD/CNY']);
    // Returning to the cross pair fetches again.
    await selectAccounting(tester, 'entry-destination', 'cny');
    expect(pairs, ['USD/CNY', 'USD/CNY']);
    // Leaving the transfer type removes the block.
    await selectAccounting(tester, 'entry-kind', 'expense');
    expect(find.byKey(_rateKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('available rate renders the value and effective date', (
    tester,
  ) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        rate: (base, quote) => marketRateFixture(base: base, quote: quote),
      ),
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    expect(
      find.text(
        l10n.referenceRateAvailable('USD', '6.7082', 'CNY', '2026-09-15'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(_useKey), findsOneWidget);
    expect(find.byKey(_retryKey), findsNothing);
    // The rate is never applied without the explicit action.
    expect(_fieldText(tester, 'entry-to-amount'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cross-derived rate names its pivot currency', (tester) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        rate: (base, quote) => marketRateFixture(
          base: base,
          quote: quote,
          derived: 'cross',
          pivot: 'EUR',
        ),
      ),
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    expect(
      find.text(
        l10n.referenceRateAvailableVia(
          'USD',
          '6.7082',
          'CNY',
          '2026-09-15',
          'EUR',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stale snapshot warns but still offers the action', (
    tester,
  ) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        rate: (base, quote) => marketRateFixture(
          base: base,
          quote: quote,
          status: 'stale',
          stale: true,
        ),
      ),
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    expect(
      find.text(l10n.referenceRateStale('USD', '6.7082', 'CNY', '2026-09-15')),
      findsOneWidget,
    );
    expect(find.byKey(_useKey), findsOneWidget);
    expect(find.byKey(_retryKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable shows the notice and a retry instead of a rate', (
    tester,
  ) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        rate: (base, quote) => marketRateFixture(
          base: base,
          quote: quote,
          status: 'unavailable',
          rate: null,
          numerator: null,
          denominator: null,
          derived: null,
          rateDate: null,
          reason: 'pair_unavailable',
        ),
      ),
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    expect(find.text(l10n.referenceRateUnavailable), findsOneWidget);
    expect(find.byKey(_retryKey), findsOneWidget);
    expect(find.byKey(_useKey), findsNothing);
    expect(_fieldText(tester, 'entry-to-amount'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the action fills the exact converted destination amount', (
    tester,
  ) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        rate: (base, quote) => marketRateFixture(base: base, quote: quote),
      ),
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    await reveal(tester, 'entry-amount');
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '100');
    await tester.enterText(
      find.byKey(const ValueKey('entry-to-amount')),
      '1.00',
    );
    await press(tester, 'reference-rate-use');
    expect(_fieldText(tester, 'entry-to-amount'), '670.82');
    expect(find.text(l10n.referenceRateApplied), findsOneWidget);
    expect(_fieldText(tester, 'entry-amount'), '100');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unparsable source amount leaves the destination untouched', (
    tester,
  ) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        rate: (base, quote) => marketRateFixture(base: base, quote: quote),
      ),
    );
    await _selectTransfer(tester);
    await reveal(tester, 'entry-amount');
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), 'abc');
    await tester.enterText(
      find.byKey(const ValueKey('entry-to-amount')),
      '9.99',
    );
    await press(tester, 'reference-rate-use');
    expect(_fieldText(tester, 'entry-to-amount'), '9.99');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed request keeps the draft and offers recovery', (
    tester,
  ) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: (request) async => request.url.path.endsWith('exchange-rates')
          ? problem('service-unavailable', 500)
          : accountingFixture(request),
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    await reveal(tester, 'entry-amount');
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '100');
    await tester.enterText(
      find.byKey(const ValueKey('entry-to-amount')),
      '55.5',
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.referenceRateUnavailable), findsOneWidget);
    expect(find.byKey(_retryKey), findsOneWidget);
    expect(find.byKey(_useKey), findsNothing);
    expect(_fieldText(tester, 'entry-amount'), '100');
    expect(_fieldText(tester, 'entry-to-amount'), '55.5');
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry refetches the pair after a failure', (tester) async {
    final pairs = <String>[];
    var attempts = 0;
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: (request) async {
        if (request.url.path.endsWith('exchange-rates')) {
          attempts++;
          pairs.add(
            '${request.url.queryParameters['base']}'
            '/${request.url.queryParameters['quote']}',
          );
          if (attempts == 1) return problem('service-unavailable', 500);
          return jsonResponse(marketRateFixture());
        }
        return accountingFixture(request);
      },
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    expect(find.text(l10n.referenceRateUnavailable), findsOneWidget);
    await press(tester, 'reference-rate-retry');
    expect(attempts, 2);
    expect(pairs, ['USD/CNY', 'USD/CNY']);
    expect(
      find.text(
        l10n.referenceRateAvailable('USD', '6.7082', 'CNY', '2026-09-15'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(_useKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source, destination and kind changes refetch the pair', (
    tester,
  ) async {
    final pairs = <String>[];
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        pairs: pairs,
        accounts: [
          accountFixture('usd', 'USD'),
          accountFixture('cny', 'CNY'),
          accountFixture('eur', 'EUR'),
        ],
        rate: (base, quote) => marketRateFixture(base: base, quote: quote),
      ),
    );
    await _selectTransfer(tester);
    expect(pairs, ['USD/CNY']);
    await selectAccounting(tester, 'entry-destination', 'eur');
    expect(pairs, ['USD/CNY', 'USD/EUR']);
    await selectAccounting(tester, 'entry-account', 'cny');
    expect(pairs, ['USD/CNY', 'USD/EUR', 'CNY/EUR']);
    await selectAccounting(tester, 'entry-kind', 'expense');
    expect(pairs, hasLength(3));
    await selectAccounting(tester, 'entry-kind', 'transfer');
    expect(pairs, ['USD/CNY', 'USD/EUR', 'CNY/EUR', 'CNY/EUR']);
    expect(find.byKey(_rateKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading state is replaced by the fetched rate', (tester) async {
    final delayed = Completer<http.Response>();
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: (request) async {
        if (request.url.path.endsWith('exchange-rates')) return delayed.future;
        return accountingFixture(request);
      },
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    expect(find.text(l10n.referenceRateLoading), findsOneWidget);
    delayed.complete(jsonResponse(marketRateFixture()));
    await tester.pumpAndSettle();
    expect(
      find.text(
        l10n.referenceRateAvailable('USD', '6.7082', 'CNY', '2026-09-15'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'zh']) {
    testWidgets('$language renders the reference rate copy', (tester) async {
      await pumpDesignApp(
        tester,
        initialLocation: '/entry',
        language: language,
        handler: _rates(
          rate: (base, quote) => marketRateFixture(base: base, quote: quote),
        ),
      );
      final l10n = tester.element(find.byType(EntryEditor)).l10n;
      await _selectTransfer(tester);
      expect(find.text(l10n.referenceRateTitle), findsOneWidget);
      expect(
        find.text(
          l10n.referenceRateAvailable('USD', '6.7082', 'CNY', '2026-09-15'),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.referenceRateUse), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unavailable rate fits 320px at 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        rate: (base, quote) => marketRateFixture(
          base: base,
          quote: quote,
          status: 'unavailable',
          rate: null,
          numerator: null,
          denominator: null,
          derived: null,
          rateDate: null,
          reason: 'no_snapshot',
        ),
      ),
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    await reveal(tester, 'reference-rate');
    expect(find.byKey(_retryKey), findsOneWidget);
    expect(find.text(l10n.referenceRateUnavailable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late response cannot overwrite a newer pair', (tester) async {
    final held = Completer<http.Response>();
    Future<http.Response> handler(http.Request request) {
      if (request.url.path.endsWith('exchange-rates') &&
          request.url.queryParameters['base'] == 'USD') {
        return held.future;
      }
      return accountingFixture(
        request,
        accounts: [
          accountFixture('usd', 'USD'),
          accountFixture('eur', 'EUR'),
          accountFixture('cny', 'CNY'),
        ],
        rate: (base, quote) => marketRateFixture(
          base: base,
          quote: quote,
          rate: base == 'EUR' ? '7.9' : '6.7082',
        ),
      );
    }

    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: handler,
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester); // USD/CNY stays in flight
    expect(find.text(l10n.referenceRateLoading), findsOneWidget);
    await selectAccounting(tester, 'entry-account', 'eur');
    await tester.pumpAndSettle();
    expect(
      find.text(
        l10n.referenceRateAvailable('EUR', '7.9', 'CNY', '2026-09-15'),
      ),
      findsOneWidget,
    );
    // The superseded USD/CNY response (the fixture defaults) completes late
    // and must be ignored.
    held.complete(jsonResponse(marketRateFixture()));
    await tester.pumpAndSettle();
    expect(
      find.text(
        l10n.referenceRateAvailable('EUR', '7.9', 'CNY', '2026-09-15'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        l10n.referenceRateAvailable('USD', '6.7082', 'CNY', '2026-09-15'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stale cross-derived rate warns and still offers the action', (
    tester,
  ) async {
    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: _rates(
        rate: (base, quote) => marketRateFixture(
          base: base,
          quote: quote,
          status: 'stale',
          stale: true,
          derived: 'cross',
          pivot: 'EUR',
        ),
      ),
    );
    final l10n = tester.element(find.byType(EntryEditor)).l10n;
    await _selectTransfer(tester);
    expect(
      find.text(
        l10n.referenceRateStaleVia('USD', '6.7082', 'CNY', '2026-09-15', 'EUR'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(_useKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the use action is disabled while the form is frozen', (
    tester,
  ) async {
    final held = Completer<http.Response>();
    Future<http.Response> handler(http.Request request) {
      if (request.method == 'POST' &&
          request.url.path.endsWith('transactions')) {
        return held.future;
      }
      return accountingFixture(
        request,
        rate: (base, quote) => marketRateFixture(base: base, quote: quote),
      );
    }

    await pumpDesignApp(
      tester,
      initialLocation: '/entry',
      handler: handler,
    );
    await _selectTransfer(tester);
    await tester.enterText(
      find.byKey(const ValueKey('entry-amount')),
      '100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-to-amount')),
      '720',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextButton>(find.byKey(_useKey)).onPressed,
      isNotNull,
    );
    await press(tester, 'save-entry');
    await tester.pump();
    // Saving freezes the form, so the rate can no longer rewrite the draft.
    expect(tester.widget<TextButton>(find.byKey(_useKey)).onPressed, isNull);
    held.complete(problem('service-unavailable', 503));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
