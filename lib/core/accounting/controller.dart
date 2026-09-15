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
  bool _disposed = false;
  bool loading = false;
  bool loadingMore = false;
  ApiFailure? failure;
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
    loading = false;
    loadingMore = false;
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
    final currentBook = bookId!;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        identity.api!.books(),
        api.currencies(),
        api.accounts(currentBook),
        api.categories(currentBook),
        api.counterparties(),
        api.transactions(currentBook, filters),
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
      page = values[5] as LedgerTransactionPage;
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

  Future<void> filter(Map<String, String> value) async {
    filters = Map.of(value);
    page = null;
    await refresh();
  }

  Future<void> more() async {
    final cursor = page?.nextCursor;
    if (cursor == null || loading || loadingMore || !ready) return;
    final generation = _generation;
    final sequence = _loadSequence;
    loadingMore = true;
    notifyListeners();
    try {
      final next = await api.transactions(bookId!, {
        ...filters,
        'cursor': cursor,
      });
      if (_disposed || generation != _generation || sequence != _loadSequence) {
        return;
      }
      final old = page!;
      final seen = old.transactions.map((t) => t.id).toSet();
      old.transactions.addAll(next.transactions.where((t) => seen.add(t.id)));
      final linkIds = old.links.map((l) => l.id).toSet();
      old.links.addAll(next.links.where((l) => linkIds.add(l.id)));
      page = LedgerTransactionPage.fromJson({
        'transactions': [
          for (final t in old.transactions)
            {
              'id': t.id,
              'revision': t.revision,
              'status': t.status,
              'data': t.data,
            },
        ],
        'links': [
          for (final l in old.links)
            {
              'id': l.id,
              'source_id': l.sourceId,
              'target_id': l.targetId,
              'kind': l.kind,
            },
        ],
        'next_cursor': next.nextCursor,
      });
    } on ApiFailure catch (error) {
      if (!_disposed && generation == _generation) {
        failure = error;
        identity.handleFailure(error);
      }
    } finally {
      if (!_disposed && generation == _generation) {
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
