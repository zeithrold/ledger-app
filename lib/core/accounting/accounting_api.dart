// Typed accounting operations share the identity client's authenticated
// transport.
// ignore_for_file: public_member_api_docs
import 'dart:convert';
import 'dart:math';
import 'package:ledger_app/core/accounting/models.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/core/network/ledger_transport.dart';

class AccountingApi {
  AccountingApi(this.transport);
  final LedgerTransport transport;
  String bookPath(String book, String resource) =>
      'books/${Uri.encodeComponent(book)}/$resource';

  Future<T> _decode<T>(Future<Json> response, T Function(Json) decode) async {
    final json = await response;
    try {
      return decode(json);
    } on Object {
      throw const ApiFailure('invalid-response');
    }
  }

  Future<List<CurrencyInfo>> currencies() => _decode(
    transport.request('GET', 'currencies'),
    (j) => (j['currencies'] as List)
        .map((v) => CurrencyInfo.fromJson(v as Json))
        .toList(),
  );
  Future<List<AssetAccount>> accounts(String book) => _decode(
    transport.request('GET', bookPath(book, 'accounts')),
    (j) => (j['accounts'] as List)
        .map((v) => AssetAccount.fromJson(v as Json))
        .toList(),
  );
  Future<List<LedgerCategory>> categories(String book) => _decode(
    transport.request('GET', bookPath(book, 'categories')),
    (j) => (j['categories'] as List)
        .map((v) => LedgerCategory.fromJson(v as Json))
        .toList(),
  );
  Future<List<LedgerCounterparty>> counterparties() => _decode(
    transport.request('GET', 'counterparties'),
    (j) => (j['counterparties'] as List)
        .map((v) => LedgerCounterparty.fromJson(v as Json))
        .toList(),
  );
  Future<LedgerTransactionPage> transactions(
    String book, [
    Map<String, String>? filter,
  ]) => _decode(
    transport.request('GET', bookPath(book, 'transactions'), null, filter),
    LedgerTransactionPage.fromJson,
  );
  Future<LedgerTransactionDetail> detail(String book, String id) => _decode(
    transport.request(
      'GET',
      bookPath(book, 'transactions/${Uri.encodeComponent(id)}'),
    ),
    LedgerTransactionDetail.fromJson,
  );
  Future<LedgerSummary> summary(String book, [Map<String, String>? filter]) =>
      _decode(
        transport.request('GET', bookPath(book, 'summary'), null, filter),
        LedgerSummary.fromJson,
      );
  Future<MarketRate> exchangeRate({
    required String base,
    required String quote,
  }) => _decode(
    transport.request('GET', 'exchange-rates', null, {
      'base': base,
      'quote': quote,
    }),
    MarketRate.fromJson,
  );
  Future<Json> mutate(String method, String path, Json? body, String key) =>
      transport.request(method, path, body, null, key);
}

/// A frozen request survives ambiguous failures in memory until it is resolved.
class PendingLedgerWrite {
  PendingLedgerWrite(this.method, this.path, Json? body)
    : _encoded = body == null ? null : jsonEncode(body),
      key = _uuid();
  final String method;
  final String path;
  final String? _encoded;
  Json? get body => _encoded == null ? null : jsonDecode(_encoded) as Json;
  final String key;
  Future<Json> send(AccountingApi api) => api.mutate(method, path, body, key);
  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
