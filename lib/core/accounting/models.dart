// Wire fields are documented by the canonical Ledger OpenAPI contract.
// ignore_for_file: public_member_api_docs
typedef Json = Map<String, dynamic>;

class CurrencyInfo {
  CurrencyInfo.fromJson(Json json)
    : code = json['code'] as String,
      minorUnits = json['minor_units'] as int;
  final String code;
  final int minorUnits;
}

class AssetAccount {
  AssetAccount.fromJson(Json json)
    : id = json['id'] as String,
      name = json['name'] as String,
      kind = json['kind'] as String,
      currency = json['currency'] as String,
      balance = json['balance'] as String,
      archived = json['archived'] as bool,
      revision = json['revision'] as int;
  final String id;
  final String name;
  final String kind;
  final String currency;
  final String balance;
  final bool archived;
  final int revision;
}

class LedgerCategory {
  LedgerCategory.fromJson(Json json)
    : id = json['id'] as String,
      name = json['name'] as String,
      nameZH = json['name_zh'] as String? ?? '',
      kind = json['kind'] as String,
      parentId = json['parent_id'] as String?,
      systemCode = json['system_code'] as String?,
      archived = json['archived'] as bool,
      revision = json['revision'] as int;
  final String id;
  final String name;
  final String nameZH;
  final String kind;
  final String? parentId;
  final String? systemCode;
  final bool archived;
  final int revision;
  String label(String language) =>
      language == 'zh' && nameZH.isNotEmpty ? nameZH : name;
}

class LedgerCounterparty {
  LedgerCounterparty.fromJson(Json json)
    : id = json['id'] as String,
      name = json['name'] as String,
      archived = json['archived'] as bool,
      revision = json['revision'] as int;
  final String id;
  final String name;
  final bool archived;
  final int revision;
}

class LedgerTransaction {
  LedgerTransaction.fromJson(Json json)
    : id = json['id'] as String,
      revision = json['revision'] as int,
      status = json['status'] as String,
      data = Map<String, dynamic>.from(json['data'] as Map);
  final String id;
  final int revision;
  final String status;
  final Json data;
  String get kind => data['kind'] as String;
  String get date => data['occurred_on'] as String;
  String get amount => data['amount'] as String;
  String get accountId => data['account_id'] as String;
  String get note => data['note'] as String? ?? '';
}

class TransactionLink {
  TransactionLink.fromJson(Json json)
    : id = json['id'] as String,
      sourceId = json['source_id'] as String,
      targetId = json['target_id'] as String,
      kind = json['kind'] as String;
  final String id;
  final String sourceId;
  final String targetId;
  final String kind;
  String other(String id) => id == sourceId ? targetId : sourceId;
}

class LedgerTransactionPage {
  LedgerTransactionPage.fromJson(Json json)
    : transactions = (json['transactions'] as List)
          .map((v) => LedgerTransaction.fromJson(v as Json))
          .toList(),
      links = (json['links'] as List)
          .map((v) => TransactionLink.fromJson(v as Json))
          .toList(),
      nextCursor = json['next_cursor'] as String?;
  final List<LedgerTransaction> transactions;
  final List<TransactionLink> links;
  final String? nextCursor;
}

class LedgerTransactionDetail {
  LedgerTransactionDetail.fromJson(Json json)
    : transaction = LedgerTransaction.fromJson(json['transaction'] as Json),
      links = (json['links'] as List)
          .map((v) => TransactionLink.fromJson(v as Json))
          .toList(),
      history = (json['history'] as List).cast<Json>(),
      journals = (json['journals'] as List? ?? []).cast<Json>(),
      refundableAmount = json['refundable_amount'] as String?,
      exchangeRate = json['exchange_rate'] as Json?;
  final LedgerTransaction transaction;
  final List<TransactionLink> links;
  final List<Json> history;
  final List<Json> journals;
  final String? refundableAmount;
  final Json? exchangeRate;
}

class LedgerSummary {
  LedgerSummary.fromJson(Json json)
    : totals = (json['totals'] as List).cast<Json>(),
      categories = (json['categories'] as List).cast<Json>();
  final List<Json> totals;
  final List<Json> categories;
}
