// Accounting state is scoped to the authenticated session and selected book.
// ignore_for_file: public_member_api_docs
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/core/accounting/accounting_api.dart';
import 'package:ledger_app/core/accounting/models.dart';
import 'package:ledger_app/core/identity/identity_controller.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/core/identity/providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final accountingProvider = Provider<AccountingController>((ref) {
  final controller = AccountingController(ref.watch(identityProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

class AccountingController extends ChangeNotifier {
  AccountingController(this.identity) {
    tzdata.initializeTimeZones();
    identity.addListener(_identityChanged);
    _identityChanged();
  }
  final IdentityController identity;
  String? _session;
  String? bookId;
  int _generation = 0;
  int _loadSequence = 0;
  int _querySequence = 0;
  int _moreSequence = 0;
  int _loadedPageCount = 1;
  bool _disposed = false;
  bool loading = false;
  bool loadingMore = false;
  bool filtering = false;
  ApiFailure? failure;
  ApiFailure? moreFailure;
  ApiFailure? filterFailure;
  List<Book> books = [];
  List<CurrencyInfo> currencies = [];
  List<AssetAccount> accounts = [];
  List<LedgerCategory> categories = [];
  List<LedgerCounterparty> counterparties = [];
  LedgerTransactionPage? page;
  LedgerTransactionPage? recent;
  LedgerSummary? summary;
  Map<String, String> filters = {};
  PendingLedgerWrite? pendingWrite;
  AccountingApi get api => AccountingApi(identity.api!);
  String get scope => '${identity.auth.sessionKey}/$bookId';
  bool get ready => identity.phase == IdentityPhase.ready && bookId != null;
  String get today {
    final zone = identity.context?.preferences.timezone ?? 'UTC';
    final date = tz.TZDateTime.now(tz.getLocation(zone));
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void _identityChanged() {
    if (_disposed) return;
    final next = identity.phase == IdentityPhase.ready
        ? identity.auth.sessionKey
        : null;
    if (_session == next) return;
    _session = next;
    pendingWrite = null;
    _generation++;
    _clear();
    bookId = next == null ? null : identity.context!.defaultBook.id;
    if (next != null) unawaited(refresh());
    notifyListeners();
  }

  void _clear() {
    accounts = [];
    categories = [];
    counterparties = [];
    currencies = [];
    page = null;
    recent = null;
    summary = null;
    books = [];
    filters = {};
    failure = null;
    moreFailure = null;
    filterFailure = null;
    loading = false;
    loadingMore = false;
    filtering = false;
    _querySequence++;
    _moreSequence++;
    _loadedPageCount = 1;
  }

  Future<void> selectBook(String id) async {
    if (id == bookId || !books.any((b) => b.id == id)) return;
    final knownBooks = books;
    _generation++;
    _clear();
    books = knownBooks;
    bookId = id;
    notifyListeners();
    await refresh();
  }

  Future<Json> write(PendingLedgerWrite request) async {
    if (!ready) throw const ApiFailure('session-changed');
    if (pendingWrite != null && !identical(pendingWrite, request)) {
      throw const ApiFailure('pending-write');
    }
    final session = _session;
    pendingWrite = request;
    notifyListeners();
    try {
      final result = await request.send(api);
      if (_disposed || session != _session) {
        throw const ApiFailure('session-changed');
      }
      pendingWrite = null;
      await refresh();
      return result;
    } on ApiFailure catch (error) {
      if (!_disposed && session == _session) {
        if (error.status != null && error.status! < 500) pendingWrite = null;
        identity.handleFailure(error);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (!ready || _disposed) return;
    final generation = _generation;
    final sequence = ++_loadSequence;
    final querySequence = _querySequence;
    final appliedFilters = Map<String, String>.of(filters);
    final currentBook = bookId!;
    loading = true;
    _moreSequence++;
    loadingMore = false;
    moreFailure = null;
    failure = null;
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        identity.api!.books(),
        api.currencies(),
        api.accounts(currentBook),
        api.categories(currentBook),
        api.counterparties(),
        transactionRange(appliedFilters, pageCount: _loadedPageCount),
        api.transactions(currentBook, {'limit': '5'}),
        api.summary(currentBook, {
          'from': '${today.substring(0, 7)}-01',
          'to': today,
        }),
      ]);
      if (_disposed || generation != _generation || sequence != _loadSequence) {
        return;
      }
      books = values[0] as List<Book>;
      currencies = values[1] as List<CurrencyInfo>;
      accounts = values[2] as List<AssetAccount>;
      categories = values[3] as List<LedgerCategory>;
      counterparties = values[4] as List<LedgerCounterparty>;
      if (querySequence == _querySequence &&
          !filtering &&
          mapEquals(filters, appliedFilters)) {
        page = values[5] as LedgerTransactionPage;
      }
      recent = values[6] as LedgerTransactionPage;
      summary = values[7] as LedgerSummary;
    } on ApiFailure catch (error) {
      if (!_disposed &&
          generation == _generation &&
          sequence == _loadSequence) {
        failure = error;
        identity.handleFailure(error);
      }
    } finally {
      if (!_disposed &&
          generation == _generation &&
          sequence == _loadSequence) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> filter(Map<String, String> value) async {
    if (!ready || _disposed || filtering || page == null) return false;
    final generation = _generation;
    final sequence = ++_querySequence;
    final candidate = Map<String, String>.of(value);
    _moreSequence++;
    loadingMore = false;
    moreFailure = null;
    filtering = true;
    filterFailure = null;
    notifyListeners();
    try {
      final next = await transactionRange(candidate);
      if (_disposed ||
          generation != _generation ||
          sequence != _querySequence) {
        return false;
      }
      filters = candidate;
      page = next;
      _loadedPageCount = 1;
      return true;
    } on ApiFailure catch (error) {
      if (!_disposed &&
          generation == _generation &&
          sequence == _querySequence) {
        filterFailure = error;
        identity.handleFailure(error);
      }
      return false;
    } finally {
      if (!_disposed &&
          generation == _generation &&
          sequence == _querySequence) {
        filtering = false;
        notifyListeners();
      }
    }
  }

  /// Re-reads the visible page range without dropping already loaded rows.
  Future<LedgerTransactionPage> transactionRange(
    Map<String, String> query, {
    int pageCount = 1,
  }) async {
    if (!ready || _disposed) throw const ApiFailure('session-changed');
    final generation = _generation;
    final currentBook = bookId!;
    final gateway = api;
    var result = await gateway.transactions(currentBook, query);
    final cursors = <String>{};
    for (var i = 1; i < pageCount && result.nextCursor != null; i++) {
      if (_disposed || generation != _generation) {
        throw const ApiFailure('session-changed');
      }
      final cursor = result.nextCursor!;
      if (!cursors.add(cursor)) break;
      final next = await gateway.transactions(currentBook, {
        ...query,
        'cursor': cursor,
      });
      result = mergeTransactionPages(result, next);
    }
    if (_disposed || generation != _generation) {
      throw const ApiFailure('session-changed');
    }
    return result;
  }

  Future<void> more() async {
    final cursor = page?.nextCursor;
    if (cursor == null || loading || loadingMore || filtering || !ready) return;
    final generation = _generation;
    final sequence = ++_moreSequence;
    final querySequence = _querySequence;
    loadingMore = true;
    notifyListeners();
    try {
      final next = await api.transactions(bookId!, {
        ...filters,
        'cursor': cursor,
      });
      if (_disposed ||
          generation != _generation ||
          sequence != _moreSequence ||
          querySequence != _querySequence) {
        return;
      }
      page = mergeTransactionPages(page!, next);
      moreFailure = null;
      _loadedPageCount++;
    } on ApiFailure catch (error) {
      if (!_disposed &&
          generation == _generation &&
          sequence == _moreSequence) {
        moreFailure = error;
        identity.handleFailure(error);
      }
    } finally {
      if (!_disposed &&
          generation == _generation &&
          sequence == _moreSequence) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  AssetAccount? account(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  int scale(String currency) =>
      currencies.firstWhere((c) => c.code == currency).minorUnits;
  String categoryName(String? id, String language) {
    for (final c in categories) {
      if (c.id == id) {
        final parent = categories.where((v) => v.id == c.parentId).firstOrNull;
        return parent == null
            ? c.label(language)
            : '${parent.label(language)} / ${c.label(language)}';
      }
    }
    return '';
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    identity.removeListener(_identityChanged);
    super.dispose();
  }
}

/// Keeps the union of records and typed relations when another page arrives.
LedgerTransactionPage mergeTransactionPages(
  LedgerTransactionPage current,
  LedgerTransactionPage next,
) {
  final transactions = {
    for (final row in current.transactions) row.id: row,
    for (final row in next.transactions) row.id: row,
  };
  final links = {
    for (final link in current.links) link.id: link,
    for (final link in next.links) link.id: link,
  };
  return LedgerTransactionPage.fromJson({
    'transactions': [
      for (final row in transactions.values)
        {
          'id': row.id,
          'revision': row.revision,
          'status': row.status,
          'data': row.data,
        },
    ],
    'links': [
      for (final link in links.values)
        {
          'id': link.id,
          'source_id': link.sourceId,
          'target_id': link.targetId,
          'kind': link.kind,
        },
    ],
    'next_cursor': next.nextCursor,
  });
}
