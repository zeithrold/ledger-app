// Accounting pages preserve content during refresh and derive values
// from the API.
// ignore_for_file: public_member_api_docs
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/accounting/models.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _sectionGap = SizedBox(height: LedgerTokens.xl);

abstract class _AccountingListState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}

class AccountingHomePage extends ConsumerStatefulWidget {
  const AccountingHomePage({super.key});
  @override
  ConsumerState<AccountingHomePage> createState() => _AccountingHomePageState();
}

class _AccountingHomePageState
    extends _AccountingListState<AccountingHomePage> {
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final page = c.recent;
        final summary = c.summary;
        final recent =
            page?.transactions.take(5).toList() ?? <LedgerTransaction>[];
        final activeAccounts = c.accounts.any((account) => !account.archived);
        return LedgerPage(
          title: context.l10n.homeTab,
          controller: scrollController,
          actions: [
            _RefreshAction(busy: c.loading, onPressed: c.refresh),
          ],
          children: [
            AccountingBookSelector(c),
            accountingGap,
            AccountingFeedback(c),
            if (page != null) ...[
              if (!activeAccounts)
                _AccountAvailability(controller: c)
              else
                LedgerAction(
                  key: const ValueKey('home-add-transaction'),
                  label: context.l10n.addTransaction,
                  onPressed: () => context.push('/entry'),
                ),
              _sectionGap,
            ],
            if (summary != null)
              _MonthlySummary(controller: c, summary: summary),
            if (page != null && activeAccounts && recent.isEmpty) ...[
              LedgerNotice(
                title: context.l10n.emptyTransactionsTitle,
                body: context.l10n.emptyTransactionsBody,
              ),
              _sectionGap,
            ],
            if (recent.isNotEmpty)
              LedgerSection(
                title: context.l10n.recentTransactions,
                children: [
                  for (final t in recent)
                    TransactionRow(controller: c, transaction: t),
                  TextButton(
                    onPressed: () => context.go('/transactions'),
                    child: Text(context.l10n.viewAllTransactions),
                  ),
                ],
              ),
            if (summary != null && summary.categories.isNotEmpty)
              LedgerGroup(
                children: [
                  ExpansionTile(
                    title: Text(context.l10n.byCategoryTitle),
                    children: [
                      for (final row in summary.categories)
                        LedgerFinancialRow(
                          title: c.categoryName(
                            row['category_id'] as String?,
                            Localizations.localeOf(context).languageCode,
                          ),
                          value: amountText(
                            c,
                            row['amount'] as String,
                            row['currency'] as String,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.controller, required this.summary});
  final AccountingController controller;
  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final currencies =
        summary.totals.map((row) => row['currency'] as String).toSet().toList()
          ..sort();
    return LedgerSection(
      title: context.l10n.monthlySummary,
      children: [
        if (summary.totals.isEmpty)
          ConstrainedBox(
            key: const ValueKey('empty-month-summary'),
            constraints: const BoxConstraints(
              minHeight: LedgerTokens.rowHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(LedgerTokens.lg),
              child: Text(context.l10n.emptySummary),
            ),
          ),
        for (final currency in currencies)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LedgerTokens.lg,
                  LedgerTokens.lg,
                  LedgerTokens.lg,
                  0,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    currency,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              for (final row in summary.totals.where(
                (row) => row['currency'] == currency,
              ))
                LedgerFinancialRow(
                  title: transactionKind(context, row['kind'] as String),
                  value: amountText(
                    controller,
                    row['amount'] as String,
                    currency,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});
  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends _AccountingListState<AccountsPage> {
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => LedgerPage(
        title: context.l10n.accountsTab,
        controller: scrollController,
        actions: [_RefreshAction(busy: c.loading, onPressed: c.refresh)],
        itemCount: c.accounts.length,
        itemBuilder: (context, index) {
          final account = c.accounts[index];
          return _SeparatedRow(
            first: index == 0,
            child: LedgerFinancialRow(
              key: ValueKey('account-${account.id}'),
              title: account.name,
              subtitle: accountKind(context, account.kind),
              value: amountText(c, account.balance, account.currency),
              trailing: account.archived
                  ? LedgerBadge(context.l10n.archivedLabel)
                  : null,
              onTap: () => context.push(
                '/accounts/${Uri.encodeComponent(account.id)}',
              ),
            ),
          );
        },
        children: [
          AccountingBookSelector(c),
          accountingGap,
          AccountingFeedback(c),
          if (c.page != null)
            if (c.accounts.isEmpty)
              _AccountAvailability(controller: c)
            else ...[
              if (c.accounts.every((account) => account.archived)) ...[
                LedgerNotice(
                  title: context.l10n.noActiveAccountsTitle,
                  body: context.l10n.noActiveAccountsBody,
                ),
                accountingGap,
              ],
              LedgerAction(
                label: context.l10n.addAccount,
                onPressed: () => context.push('/accounts/new'),
              ),
            ],
        ],
      ),
    );
  }
}

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});
  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends _AccountingListState<TransactionsPage> {
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final rows = c.page?.transactions ?? [];
        final activeAccounts = c.accounts.any((account) => !account.archived);
        return LedgerPage(
          title: context.l10n.transactionsTab,
          controller: scrollController,
          actions: [
            IconButton(
              key: const ValueKey('transaction-filters'),
              tooltip: c.filters.isEmpty
                  ? context.l10n.filtersTitle
                  : '${context.l10n.filtersTitle} (${c.filters.length})',
              onPressed: c.page == null || c.filtering
                  ? null
                  : () => context.push('/transaction-filters'),
              icon: Badge(
                isLabelVisible: c.filters.isNotEmpty,
                label: Text('${c.filters.length}'),
                child: const Icon(LucideIcons.slidersHorizontal),
              ),
            ),
            _RefreshAction(busy: c.loading, onPressed: c.refresh),
          ],
          itemCount: rows.length + (c.page?.nextCursor != null ? 1 : 0),
          itemBuilder: (context, index) => index == rows.length
              ? _PaginationFooter(
                  key: const ValueKey('transactions-pagination'),
                  busy: c.loadingMore,
                  failure: c.moreFailure,
                  onPressed: c.loading || c.filtering ? null : c.more,
                )
              : _SeparatedRow(
                  first: index == 0,
                  child: TransactionRow(
                    controller: c,
                    transaction: rows[index],
                  ),
                ),
          children: [
            AccountingBookSelector(c),
            accountingGap,
            AccountingFeedback(c),
            if (c.page != null) ...[
              if (!activeAccounts) ...[
                _AccountAvailability(controller: c),
                if (rows.isNotEmpty || c.filters.isNotEmpty) accountingGap,
              ],
              if (activeAccounts && rows.isNotEmpty) ...[
                LedgerAction(
                  label: context.l10n.addTransaction,
                  onPressed: () => context.push('/entry'),
                ),
                if (c.filters.isNotEmpty) accountingGap,
              ],
              if (c.filters.isNotEmpty) ...[
                _AppliedFilters(controller: c),
                if (rows.isEmpty) accountingGap,
              ],
              if (c.filterFailure != null) ...[
                LedgerNotice(
                  title: context.l10n.filterApplyErrorTitle,
                  body: context.l10n.filterApplyErrorBody,
                  icon: LucideIcons.circleAlert,
                  isError: true,
                  action: LedgerAction(
                    label: context.l10n.filtersTitle,
                    secondary: true,
                    onPressed: () => context.push('/transaction-filters'),
                  ),
                ),
                accountingGap,
              ],
              if (rows.isEmpty && (activeAccounts || c.filters.isNotEmpty))
                LedgerNotice(
                  title: c.filters.isEmpty
                      ? context.l10n.emptyTransactionsTitle
                      : context.l10n.noMatches,
                  body: c.filters.isEmpty
                      ? context.l10n.emptyTransactionsBody
                      : context.l10n.noMatchingTransactionsBody,
                  action: c.filters.isEmpty
                      ? LedgerAction(
                          label: context.l10n.addTransaction,
                          onPressed: () => context.push('/entry'),
                        )
                      : LedgerAction(
                          label: context.l10n.filtersTitle,
                          secondary: true,
                          onPressed: () => context.push('/transaction-filters'),
                        ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _AppliedFilters extends StatelessWidget {
  const _AppliedFilters({required this.controller});
  final AccountingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final l10n = context.l10n;
    final labels = <String, String>{
      l10n.fromDate: ?c.filters['from'],
      l10n.toDate: ?c.filters['to'],
      if (c.filters['account_id'] case final id?)
        l10n.accountLabel: c.account(id)?.name ?? l10n.selectionUnavailable,
      if (c.filters['kind'] case final kind?)
        l10n.transactionType: transactionKind(context, kind),
      l10n.currencyLabel: ?c.filters['currency'],
      if (c.filters['category_id'] case final id?)
        l10n.categoryLabel: c.categoryName(
          id,
          Localizations.localeOf(context).languageCode,
        ),
      if (c.filters['counterparty_id'] case final id?)
        l10n.counterpartyLabel:
            c.counterparties.where((row) => row.id == id).firstOrNull?.name ??
            l10n.selectionUnavailable,
    };
    final descriptions = labels.entries.map((entry) {
      final value = entry.value.isEmpty
          ? l10n.selectionUnavailable
          : entry.value;
      return '${entry.key}: $value';
    }).toList();
    if (c.filters['include_voided'] == 'true') {
      descriptions.add(l10n.includeDeleted);
    }
    return LedgerNotice(
      key: const ValueKey('applied-filters'),
      title: l10n.appliedFiltersTitle,
      body: descriptions.join('\n'),
      action: LedgerAction(
        key: const ValueKey('clear-transaction-filters'),
        label: l10n.clearFilters,
        secondary: true,
        busy: c.filtering,
        onPressed: () => c.filter({}),
      ),
    );
  }
}

class _AccountAvailability extends StatelessWidget {
  const _AccountAvailability({required this.controller});
  final AccountingController controller;

  @override
  Widget build(BuildContext context) {
    final firstUse = controller.accounts.isEmpty;
    return LedgerNotice(
      title: firstUse
          ? context.l10n.emptyAccountsTitle
          : context.l10n.noActiveAccountsTitle,
      body: firstUse
          ? context.l10n.emptyAccountsBody
          : context.l10n.noActiveAccountsBody,
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LedgerAction(
            label: context.l10n.addAccount,
            onPressed: () => context.push('/accounts/new'),
          ),
          if (!firstUse) ...[
            accountingGap,
            LedgerAction(
              label: context.l10n.viewAccountsAction,
              secondary: true,
              onPressed: () => context.go('/accounts'),
            ),
          ],
        ],
      ),
    );
  }
}

class AccountDetailPage extends ConsumerStatefulWidget {
  const AccountDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends _AccountingListState<AccountDetailPage> {
  LedgerTransactionPage? page;
  ApiFailure? failure;
  ApiFailure? moreFailure;
  bool loading = false;
  bool loadingMore = false;
  int loadedPageCount = 1;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(load));
  }

  Future<void> load({bool more = false}) async {
    if (loading || loadingMore || !mounted) return;
    final c = ref.read(accountingProvider);
    if (!c.ready || c.account(widget.id) == null) return;
    final scope = c.scope;
    setState(() {
      if (more) {
        loadingMore = true;
      } else {
        loading = true;
        failure = null;
      }
    });
    try {
      final next = more
          ? await c.api.transactions(c.bookId!, {
              'account_id': widget.id,
              'cursor': page!.nextCursor!,
            })
          : await c.transactionRange(
              {'account_id': widget.id},
              pageCount: loadedPageCount,
            );
      if (mounted && scope == c.scope) {
        setState(() {
          page = more ? mergeTransactionPages(page!, next) : next;
          moreFailure = null;
          if (more) loadedPageCount++;
        });
      }
    } on ApiFailure catch (error) {
      if (mounted && scope == c.scope) {
        c.identity.handleFailure(error);
        if (mounted) {
          setState(() {
            if (more) {
              moreFailure = error;
            } else {
              failure = error;
            }
          });
        }
      }
    } finally {
      if (mounted && scope == c.scope) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> open(String location) async {
    final scope = ref.read(accountingProvider).scope;
    await context.push(location);
    if (mounted && scope == ref.read(accountingProvider).scope) await load();
  }

  Future<void> refresh() async {
    final c = ref.read(accountingProvider);
    final scope = c.scope;
    await c.refresh();
    if (mounted && scope == c.scope) await load();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final account = c.account(widget.id);
        final rows = page?.transactions ?? [];
        return LedgerPage(
          title: account?.name ?? context.l10n.accountLabel,
          contentBottomSpacing: 0,
          controller: scrollController,
          leading: accountingBack(context),
          actions: [
            _RefreshAction(
              busy: loading || c.loading,
              onPressed: loadingMore ? null : refresh,
            ),
          ],
          itemCount: account == null
              ? 0
              : rows.length + (page?.nextCursor != null ? 1 : 0),
          itemBuilder: (context, index) => index == rows.length
              ? _PaginationFooter(
                  key: const ValueKey('account-pagination'),
                  busy: loadingMore,
                  failure: moreFailure,
                  onPressed: loading ? null : () => load(more: true),
                )
              : _SeparatedRow(
                  first: index == 0,
                  child: TransactionRow(
                    controller: c,
                    transaction: rows[index],
                    links: page!.links,
                    onTap: () => open(
                      '/transactions/${Uri.encodeComponent(rows[index].id)}',
                    ),
                  ),
                ),
          children: [
            AccountingFeedback(c),
            if (account == null && !c.loading && c.failure == null)
              LedgerNotice(
                title: context.l10n.accountUnavailableTitle,
                body: context.l10n.accountUnavailableBody,
                action: LedgerAction(
                  label: context.l10n.viewAccountsAction,
                  secondary: true,
                  onPressed: () => context.go('/accounts'),
                ),
              ),
            if (account != null) ...[
              LedgerSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.balanceLabel,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: LedgerTokens.sm),
                    LedgerMoneyText(
                      amountText(c, account.balance, account.currency),
                      prominent: true,
                    ),
                    accountingGap,
                    Text(
                      '${accountKind(context, account.kind)} · '
                      '${account.currency}',
                    ),
                    if (account.archived) ...[
                      accountingGap,
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: LedgerBadge(context.l10n.archivedLabel),
                      ),
                    ],
                  ],
                ),
              ),
              accountingGap,
              if (account.archived) ...[
                LedgerNotice(
                  title: context.l10n.archivedLabel,
                  body: context.l10n.archivedAccountBody,
                  action: LedgerAction(
                    label: context.l10n.editAccount,
                    secondary: true,
                    onPressed: () => open(
                      '/accounts/${Uri.encodeComponent(account.id)}/edit',
                    ),
                  ),
                ),
              ] else
                LedgerAction(
                  label: context.l10n.editAccount,
                  secondary: true,
                  onPressed: () => open(
                    '/accounts/${Uri.encodeComponent(account.id)}/edit',
                  ),
                ),
              _sectionGap,
              Semantics(
                header: true,
                child: Text(
                  context.l10n.transactionsTab,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              accountingGap,
              if (loading && page == null) const LedgerLoading(),
              if (failure != null) ...[
                FailureView(
                  failure!,
                  action: LedgerAction(
                    label: context.l10n.retryAction,
                    secondary: true,
                    busy: loading,
                    onPressed: load,
                  ),
                ),
              ],
              if (page != null && rows.isEmpty)
                LedgerNotice(
                  title: context.l10n.emptyTransactionsTitle,
                  body: context.l10n.accountTransactionsEmptyBody,
                  action: account.archived
                      ? null
                      : LedgerAction(
                          label: context.l10n.addTransaction,
                          onPressed: () => open('/entry'),
                        ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _SeparatedRow extends StatelessWidget {
  const _SeparatedRow({required this.first, required this.child});
  final bool first;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [if (!first) const Divider(), child],
  );
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.busy,
    required this.failure,
    required this.onPressed,
    super.key,
  });
  final bool busy;
  final ApiFailure? failure;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final action = LedgerAction(
      key: const ValueKey('pagination-action'),
      label: failure == null
          ? context.l10n.loadMore
          : context.l10n.retryLoadMoreAction,
      secondary: true,
      busy: busy,
      onPressed: onPressed,
    );
    return Padding(
      padding: const EdgeInsets.only(top: LedgerTokens.lg),
      child: failure == null
          ? action
          : LedgerNotice(
              title: context.l10n.loadMoreErrorTitle,
              body: context.l10n.loadMoreErrorBody,
              icon: LucideIcons.circleAlert,
              isError: true,
              action: action,
            ),
    );
  }
}

class _RefreshAction extends StatelessWidget {
  const _RefreshAction({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: busy ? context.l10n.refreshingLabel : context.l10n.refreshAction,
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox.square(
            dimension: LedgerTokens.icon,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(LucideIcons.refreshCw),
  );
}
