// Accounting pages preserve content during refresh and derive values
// from the API.
// ignore_for_file: public_member_api_docs
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/accounting/models.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AccountingHomePage extends ConsumerWidget {
  const AccountingHomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final page = c.recent;
        final summary = c.summary;
        final recent =
            page?.transactions.take(5).toList() ?? <LedgerTransaction>[];
        return LedgerPage(
          title: context.l10n.homeTab,
          actions: [
            IconButton(
              tooltip: context.l10n.refreshAction,
              onPressed: c.loading ? null : c.refresh,
              icon: const Icon(LucideIcons.refreshCw),
            ),
          ],
          children: [
            AccountingBookSelector(c),
            AccountingFeedback(c),
            if (page != null &&
                c.accounts.where((a) => !a.archived).isEmpty) ...[
              LedgerStateView(
                title: context.l10n.emptyAccountsTitle,
                body: context.l10n.emptyAccountsBody,
              ),
              LedgerAction(
                label: context.l10n.addAccount,
                onPressed: () => context.push('/accounts/new'),
              ),
            ] else if (page != null) ...[
              LedgerAction(
                key: const ValueKey('home-add-transaction'),
                label: context.l10n.addTransaction,
                onPressed: () => context.push('/entry'),
              ),
              accountingGap,
            ],
            if (summary != null)
              LedgerSection(
                title: context.l10n.monthlySummary,
                children: [
                  if (summary.totals.isEmpty) Text(context.l10n.emptySummary),
                  for (final row in summary.totals)
                    LedgerRow(
                      title: transactionKind(context, row['kind'] as String),
                      value: amountText(
                        c,
                        row['amount'] as String,
                        row['currency'] as String,
                      ),
                    ),
                ],
              ),
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
              ExpansionTile(
                title: Text(context.l10n.byCategoryTitle),
                children: [
                  for (final row in summary.categories)
                    LedgerRow(
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
        );
      },
    );
  }
}

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => LedgerPage(
        title: context.l10n.accountsTab,
        itemCount: c.accounts.length,
        itemBuilder: (context, index) {
          final a = c.accounts[index];
          return LedgerRow(
            key: ValueKey('account-${a.id}'),
            title: a.name,
            subtitle:
                '${accountKind(context, a.kind)}'
                '${a.archived ? ' · ${context.l10n.archivedLabel}' : ''}',
            value: amountText(c, a.balance, a.currency),
            onTap: () => context.push('/accounts/${Uri.encodeComponent(a.id)}'),
          );
        },
        children: [
          AccountingBookSelector(c),
          AccountingFeedback(c),
          if (c.page != null) ...[
            if (c.accounts.isEmpty)
              LedgerStateView(
                title: context.l10n.emptyAccountsTitle,
                body: context.l10n.emptyAccountsBody,
              ),
            LedgerAction(
              label: context.l10n.addAccount,
              onPressed: () => context.push('/accounts/new'),
            ),
            accountingGap,
          ],
        ],
      ),
    );
  }
}

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final rows = c.page?.transactions ?? [];
        return LedgerPage(
          title: context.l10n.transactionsTab,
          actions: [
            IconButton(
              key: const ValueKey('transaction-filters'),
              tooltip: context.l10n.filtersTitle,
              onPressed: c.page == null
                  ? null
                  : () => context.push('/transaction-filters'),
              icon: const Icon(LucideIcons.slidersHorizontal),
            ),
          ],
          itemCount: rows.length + (c.page?.nextCursor != null ? 1 : 0),
          itemBuilder: (context, index) => index == rows.length
              ? LedgerAction(
                  label: context.l10n.loadMore,
                  secondary: true,
                  onPressed: c.loadingMore ? null : c.more,
                )
              : TransactionRow(controller: c, transaction: rows[index]),
          children: [
            AccountingBookSelector(c),
            AccountingFeedback(c),
            if (c.page != null) ...[
              if (c.accounts.any((a) => !a.archived))
                LedgerAction(
                  label: context.l10n.addTransaction,
                  onPressed: () => context.push('/entry'),
                ),
              if (c.filters.isNotEmpty)
                TextButton(
                  onPressed: () => c.filter({}),
                  child: Text(context.l10n.clearFilters),
                ),
              if (rows.isEmpty)
                LedgerStateView(
                  title: c.filters.isEmpty
                      ? context.l10n.emptyTransactionsTitle
                      : context.l10n.noMatches,
                  body: context.l10n.emptyTransactionsBody,
                ),
            ],
          ],
        );
      },
    );
  }
}

class AccountDetailPage extends ConsumerStatefulWidget {
  const AccountDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  LedgerTransactionPage? page;
  ApiFailure? failure;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(load));
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    final c = ref.read(accountingProvider);
    final scope = c.scope;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final next = await c.api.transactions(c.bookId!, {
        'account_id': widget.id,
        if (more && page?.nextCursor != null) 'cursor': page!.nextCursor!,
      });
      if (mounted && scope == c.scope) {
        setState(() {
          if (more) next.transactions.insertAll(0, page!.transactions);
          page = next;
        });
      }
    } on ApiFailure catch (e) {
      c.identity.handleFailure(e);
      if (mounted && scope == c.scope) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final a = c.account(widget.id);
        return LedgerPage(
          title: a?.name ?? context.l10n.accountLabel,
          leading: accountingBack(context),
          itemCount:
              (page?.transactions.length ?? 0) +
              (page?.nextCursor != null ? 1 : 0),
          itemBuilder: (context, i) => i == page!.transactions.length
              ? LedgerAction(
                  label: context.l10n.loadMore,
                  secondary: true,
                  onPressed: loading ? null : () => load(more: true),
                )
              : TransactionRow(
                  controller: c,
                  transaction: page!.transactions[i],
                ),
          children: [
            AccountingFeedback(c),
            if (a != null) ...[
              LedgerRow(
                title: context.l10n.balanceLabel,
                value: amountText(c, a.balance, a.currency),
              ),
              LedgerRow(
                title: context.l10n.accountKind,
                value: accountKind(context, a.kind),
              ),
              LedgerAction(
                label: context.l10n.editAccount,
                secondary: true,
                onPressed: () async {
                  await context.push(
                    '/accounts/${Uri.encodeComponent(a.id)}/edit',
                  );
                  if (mounted) await load();
                },
              ),
              accountingGap,
            ],
            if (loading) const LedgerLoading(),
            if (failure != null) FailureView(failure!),
            if (failure != null)
              LedgerAction(
                label: context.l10n.retryAction,
                onPressed: loading ? null : load,
              ),
            if (page != null && page!.transactions.isEmpty)
              Text(context.l10n.emptyTransactionsTitle),
          ],
        );
      },
    );
  }
}
