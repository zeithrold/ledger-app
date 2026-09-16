import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fakes.dart';

Map<String, dynamic> accountFixture(
  String id,
  String currency, {
  String? name,
}) => {
  'id': id,
  'name': name ?? '$currency account',
  'kind': 'bank',
  'currency': currency,
  'balance': currency == 'USD' ? '899.00' : '720.00',
  'revision': 1,
  'archived': false,
};

/// A market reference-rate payload matching the read-only endpoint.
///
/// Fields the endpoint nulls for an unavailable pair stay null so callers get
/// the same shape the transport decodes.
Map<String, dynamic> marketRateFixture({
  String base = 'USD',
  String quote = 'CNY',
  String status = 'available',
  bool stale = false,
  String? rate = '6.7082',
  String? numerator = '67082',
  String? denominator = '10000',
  String? derived = 'direct',
  String? pivot,
  String? rateDate = '2026-09-15',
  String? reason,
}) => {
  'base': base,
  'quote': quote,
  'status': status,
  'stale': stale,
  'source': 'frankfurter',
  'provider_filter': 'blended',
  'pivot': pivot,
  'rate': rate,
  'numerator': numerator,
  'denominator': denominator,
  'derived': derived,
  'rate_date': rateDate,
  'snapshot_date': '2026-09-16',
  'fetched_at': '2026-09-16T17:10:03Z',
  'latest_snapshot_date': '2026-09-16',
  'reason': reason,
};

Map<String, dynamic> transactionFixture({
  String id = 'transfer',
  String kind = 'transfer',
  String amount = '100.00',
}) => {
  'id': id,
  'revision': 1,
  'status': 'posted',
  'created_at': '2026-09-15T00:00:00Z',
  'data': {
    'kind': kind,
    'occurred_on': '2026-09-15',
    'account_id': 'usd',
    'amount': amount,
    if (kind == 'transfer') ...{'to_account_id': 'cny', 'to_amount': '720.00'},
    if (kind == 'expense') 'category_id': 'fees',
  },
};

final accountingLinkFixture = {
  'id': 'fee-link',
  'source_id': 'transfer',
  'target_id': 'fee',
  'kind': 'fee',
};

Future<http.Response> accountingFixture(
  http.Request request, {
  List<Map<String, dynamic>>? accounts,
  Map<String, dynamic> Function(String base, String quote)? rate,
}) async {
  if (rate != null && request.url.path.endsWith('exchange-rates')) {
    return jsonResponse(
      rate(
        request.url.queryParameters['base'] ?? '',
        request.url.queryParameters['quote'] ?? '',
      ),
    );
  }
  final resource = request.url.path.split('/').last;
  if (resource == 'accounts') {
    return jsonResponse({
      'accounts':
          accounts ??
          [accountFixture('usd', 'USD'), accountFixture('cny', 'CNY')],
    });
  }
  if (resource == 'categories') {
    return jsonResponse({
      'categories': [
        for (final (code, en, zh, kind, parent) in [
          ('food', 'Food', '餐饮', 'expense', null),
          ('meals', 'Meals', '餐食', 'expense', 'food'),
          ('fees', 'Fees', '手续费', 'expense', null),
          ('salary', 'Salary', '工资', 'income', null),
        ])
          {
            'id': code,
            'name': en,
            'name_zh': zh,
            'kind': kind,
            'parent_id': parent,
            'system_code': code,
            'revision': 1,
            'archived': false,
          },
      ],
    });
  }
  if (resource == 'transactions') {
    return jsonResponse({
      'transactions': [
        transactionFixture(),
        transactionFixture(id: 'fee', kind: 'expense', amount: '1.00'),
      ],
      'links': [accountingLinkFixture],
    });
  }
  if (['transfer', 'fee'].contains(resource)) {
    final t = resource == 'transfer'
        ? transactionFixture()
        : transactionFixture(id: 'fee', kind: 'expense', amount: '1.00');
    return jsonResponse({
      'transaction': t,
      'links': [accountingLinkFixture],
      'history': [
        {
          'revision': 1,
          'voided': false,
          'data': t['data'],
          'actor_id': 'user-a',
          'created_at': '2026-09-15T00:00:00Z',
        },
      ],
      'journals': <Object>[],
      if (resource == 'fee') 'refundable_amount': '1.00',
    });
  }
  if (resource == 'summary') {
    return jsonResponse({
      'totals': [
        {'currency': 'USD', 'kind': 'expense', 'amount': '1.00'},
      ],
      'categories': <Object>[],
    });
  }
  return normalApi(request);
}

Map<String, dynamic> requestJson(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;
