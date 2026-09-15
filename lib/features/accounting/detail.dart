// Transaction details expose accounting history and typed, independent
// relations.
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
import 'package:ledger_app/features/accounting/forms.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

class TransactionDetailPage extends ConsumerStatefulWidget {
  const TransactionDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<TransactionDetailPage> createState() =>
      _TransactionDetailPageState();
}

class _TransactionDetailPageState
    extends LedgerMutationState<TransactionDetailPage> {
  LedgerTransactionDetail? detail;
  final Map<String, LedgerTransaction> related = {};
  bool loading = false;
  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(load));
  }

  Future<void> load() async {
    if (loading) return;
    final scope = ledger.scope;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await ledger.api.detail(ledger.bookId!, widget.id);
      final transactions = await Future.wait([
        for (final link in next.links)
          ledger.api.detail(ledger.bookId!, link.other(widget.id)),
      ]);
      if (mounted && scope == ledger.scope) {
        setState(() {
          detail = next;
          related.clear();
          for (final t in transactions) {
            related[t.transaction.id] = t.transaction;
          }
        });
      }
    } on ApiFailure catch (e) {
      if (mounted && scope == ledger.scope) {
        setState(() => error = e);
        ledger.identity.handleFailure(e);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(String path) async {
    await context.push(path);
    if (mounted) await load();
  }

  Future<void> deleteTransaction() async {
    final d = detail!;
    final fees = d.links
        .where((l) => l.kind == 'fee' && l.sourceId == widget.id)
        .map((l) => related[l.targetId])
        .nonNulls
        .where((t) => t.status == 'posted')
        .toList();
    final selected = <String>{};
    final scope = ledger.scope;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.deleteTransaction),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.deleteHint),
              accountingGap,
              if (fees.isNotEmpty) ...[
                Text(context.l10n.includeFeesHint),
                for (final fee in fees)
                  CheckboxListTile(
                    value: selected.contains(fee.id),
                    title: Text(
                      '${context.l10n.feeLabel} · '
                      '${ledger.account(fee.accountId)?.name ?? ''} · '
                      '${fee.amount}',
                    ),
                    onChanged: (value) => update(() {
                      if (value ?? false) {
                        selected.add(fee.id);
                      } else {
                        selected.remove(fee.id);
                      }
                    }),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancelAction),
            ),
            TextButton(
              key: const ValueKey('confirm-delete'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.deleteTransaction),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted || scope != ledger.scope) return;
    await perform(
      'POST',
      ledger.api.bookPath(
        ledger.bookId!,
        'transactions/${widget.id}/corrections',
      ),
      {
        'expected_revision': d.transaction.revision,
        'fees': [
          for (final fee in fees.where((t) => selected.contains(t.id)))
            {'id': fee.id, 'expected_revision': fee.revision},
        ],
      },
      close: false,
    );
    if (mounted && request == null && error == null) await load();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final d = detail;
        final t = d?.transaction;
        return LedgerPage(
          title: context.l10n.transactionDetail,
          leading: accountingBack(context),
          children: [
            ...feedback(),
            if (loading) const LedgerLoading(),
            if (error != null)
              LedgerAction(
                label: request == null
                    ? context.l10n.reloadDetail
                    : context.l10n.retryAction,
                secondary: true,
                onPressed: saving || loading
                    ? null
                    : () async {
                        if (request != null) {
                          await perform(
                            request!.method,
                            request!.path,
                            request!.body,
                            close: false,
                          );
                        }
                        if (mounted && request == null) await load();
                      },
              ),
            if (d != null && t != null) ...[
              TransactionRow(controller: c, transaction: t, readOnly: true),
              if (t.data['counterparty_id'] case final String id)
                LedgerRow(
                  title: context.l10n.counterpartyLabel,
                  value:
                      c.counterparties
                          .where((v) => v.id == id)
                          .firstOrNull
                          ?.name ??
                      '',
                ),
              if (d.refundableAmount != null && c.account(t.accountId) != null)
                LedgerRow(
                  title: context.l10n.refundRemaining,
                  value: amountText(
                    c,
                    d.refundableAmount!,
                    c.account(t.accountId)!.currency,
                  ),
                ),
              if (d.exchangeRate case final rate?)
                LedgerRow(
                  title: context.l10n.exchangeRateLabel,
                  value:
                      '1 '
                      '${rate['from_currency']} = '
                      '${rate['display']} '
                      '${rate['to_currency']}',
                  subtitle: rate['date'] as String,
                ),
              accountingGap,
              if (t.status == 'posted')
                Wrap(
                  spacing: LedgerTokens.sm,
                  runSpacing: LedgerTokens.sm,
                  children: [
                    OutlinedButton(
                      onPressed: frozen
                          ? null
                          : () => open('/entry?edit=${widget.id}'),
                      child: Text(context.l10n.editAction),
                    ),
                    if (t.kind == 'expense' && d.refundableAmount != null)
                      OutlinedButton(
                        onPressed: frozen
                            ? null
                            : () => open('/entry?original=${widget.id}'),
                        child: Text(context.l10n.addRefund),
                      ),
                    OutlinedButton(
                      onPressed: frozen
                          ? null
                          : () => open('/entry?fee_for=${widget.id}'),
                      child: Text(context.l10n.addFee),
                    ),
                    TextButton(
                      onPressed: frozen ? null : deleteTransaction,
                      child: Text(context.l10n.deleteTransaction),
                    ),
                  ],
                ),
              accountingGap,
              LedgerSection(
                title: context.l10n.relatedTransactions,
                children: [
                  for (final link in d.links) ...[
                    Padding(
                      padding: const EdgeInsets.all(LedgerTokens.gutter),
                      child: Text(
                        relationKind(context, link.kind),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    if (related[link.other(widget.id)] case final target?)
                      TransactionRow(controller: c, transaction: target),
                    if (link.kind == 'related')
                      TextButton(
                        onPressed: frozen
                            ? null
                            : () async {
                                await perform(
                                  'DELETE',
                                  c.api.bookPath(
                                    c.bookId!,
                                    'transaction-links/${link.id}',
                                  ),
                                  null,
                                  close: false,
                                );
                                if (mounted &&
                                    request == null &&
                                    error == null) {
                                  await load();
                                }
                              },
                        child: Text(context.l10n.removeLink),
                      ),
                  ],
                  TextButton(
                    onPressed: frozen
                        ? null
                        : () => open(
                            '/link-transaction?source='
                            '${widget.id}&kind=related',
                          ),
                    child: Text(context.l10n.linkTransaction),
                  ),
                  if (t.status == 'posted') ...[
                    TextButton(
                      onPressed: frozen
                          ? null
                          : () => open(
                              '/link-transaction?source=${widget.id}&kind=fee',
                            ),
                      child: Text(context.l10n.feeSelectExisting),
                    ),
                  ],
                ],
              ),
              ExpansionTile(
                title: Text(context.l10n.historyTitle),
                children: [
                  for (final revision in d.history) ...[
                    LedgerRow(
                      title:
                          '${context.l10n.revisionLabel} '
                          '${revision['revision']}',
                      subtitle:
                          '${revision['created_at']}\n'
                          '${(revision['data'] as Json)['note'] ?? ''}',
                      value: revision['voided'] == true
                          ? context.l10n.voidedLabel
                          : '${(revision['data'] as Json)['amount']} · '
                                '${(revision['data'] as Json)['occurred_on']}',
                    ),
                    for (final journal in d.journals.where(
                      (j) => j['revision'] == revision['revision'],
                    ))
                      ExpansionTile(
                        title: Text(
                          journal['reversal_of'] == null
                              ? context.l10n.postingLabel
                              : context.l10n.reversalLabel,
                        ),
                        subtitle: Text(journal['occurred_on'] as String),
                        children: [
                          for (final p
                              in (journal['postings'] as List).cast<Json>())
                            LedgerRow(
                              title:
                                  c.account(p['account_id'] as String)?.name ??
                                  context.l10n.categoryLabel,
                              value: amountText(
                                c,
                                p['amount'] as String,
                                p['currency'] as String,
                              ),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class LinkTransactionPage extends ConsumerStatefulWidget {
  const LinkTransactionPage({
    required this.sourceId,
    required this.kind,
    super.key,
  });
  final String sourceId;
  final String kind;
  @override
  ConsumerState<LinkTransactionPage> createState() =>
      _LinkTransactionPageState();
}

class _LinkTransactionPageState
    extends LedgerMutationState<LinkTransactionPage> {
  LedgerTransactionPage? page;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(load));
  }

  Future<void> load() async {
    if (loading) return;
    final scope = ledger.scope;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await ledger.api.transactions(ledger.bookId!, {
        if (widget.kind == 'fee') 'kind': 'expense',
        if (widget.kind == 'related') 'include_voided': 'true',
        if (page?.nextCursor != null) 'cursor': page!.nextCursor!,
      });
      if (mounted && scope == ledger.scope) {
        setState(() {
          if (page != null) next.transactions.insertAll(0, page!.transactions);
          page = next;
        });
      }
    } on ApiFailure catch (e) {
      ledger.identity.handleFailure(e);
      if (mounted && scope == ledger.scope) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        page?.transactions.where((v) => v.id != widget.sourceId).toList() ??
        <LedgerTransaction>[];
    return LedgerPage(
      title: context.l10n.chooseTransaction,
      leading: accountingBack(context),
      itemCount: rows.length + (page?.nextCursor != null ? 1 : 0),
      itemBuilder: (context, i) => i == rows.length
          ? LedgerAction(
              label: context.l10n.loadMore,
              secondary: true,
              onPressed: loading ? null : load,
            )
          : TransactionRow(
              controller: ledger,
              transaction: rows[i],
              onTap: () {
                if (!frozen) {
                  unawaited(
                    perform(
                      'POST',
                      ledger.api.bookPath(ledger.bookId!, 'transaction-links'),
                      {
                        'source_id': widget.sourceId,
                        'target_id': rows[i].id,
                        'kind': widget.kind,
                      },
                    ),
                  );
                }
              },
            ),
      children: [
        ...feedback(),
        if (loading) const LedgerLoading(),
        if (page != null && rows.isEmpty) Text(context.l10n.noMatches),
        if (error != null && request == null)
          LedgerAction(
            label: context.l10n.retryAction,
            onPressed: loading ? null : load,
          ),
        if (request != null)
          LedgerAction(
            label: context.l10n.retryAction,
            onPressed: saving
                ? null
                : () => perform(request!.method, request!.path, request!.body),
          ),
      ],
    );
  }
}
