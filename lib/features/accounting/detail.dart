// Transaction details expose accounting history and typed,
// independent relations.
// ignore_for_file: public_member_api_docs
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/accounting/models.dart';
import 'package:ledger_app/core/accounting/money.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/accounting/forms.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timezone/timezone.dart' as tz;

part 'detail_actions.dart';

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
  final Map<String, ApiFailure> relatedErrors = {};
  final Set<String> relatedLoading = {};
  ApiFailure? loadError;
  bool loading = false;
  bool staleAfterConflict = false;
  int generation = 0;
  String? activeAction;
  bool openingAction = false;

  bool get actionsDisabled =>
      frozen ||
      loading ||
      staleAfterConflict ||
      error?.isType('accounting-conflict') == true;

  List<_DetailAction> get availableActions {
    final t = detail?.transaction;
    if (t == null) return const [];
    return [
      if (t.status == 'posted') ...[
        if (t.kind == 'expense' && detail!.refundableAmount != null)
          _DetailAction.refund,
        _DetailAction.addFee,
      ],
      _DetailAction.link,
      if (t.status == 'posted') _DetailAction.linkFee,
    ];
  }

  Future<void> openDetailAction({bool edit = false}) async {
    if (actionsDisabled || openingAction || detail == null) return;
    final scope = ledger.scope;
    setState(() => openingAction = true);
    try {
      if (edit) {
        if (detail!.transaction.status == 'posted') {
          await open('/entry?edit=${widget.id}');
        }
        return;
      }
      final action = await showModalBottomSheet<_DetailAction>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: LedgerTokens.contentWidth),
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        builder: (_) => _DetailActionSheet(actions: availableActions),
      );
      if (!mounted ||
          scope != ledger.scope ||
          actionsDisabled ||
          action == null ||
          !availableActions.contains(action)) {
        return;
      }
      final path = switch (action) {
        _DetailAction.refund => '/entry?original=${widget.id}',
        _DetailAction.addFee => '/entry?fee_for=${widget.id}',
        _DetailAction.link =>
          '/link-transaction?source=${widget.id}&kind=related',
        _DetailAction.linkFee =>
          '/link-transaction?source=${widget.id}&kind=fee',
      };
      await open(path);
    } finally {
      if (mounted) setState(() => openingAction = false);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(load));
  }

  Future<void> load() async {
    if (loading) return;
    final scope = ledger.scope;
    final sequence = ++generation;
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final next = await ledger.api.detail(ledger.bookId!, widget.id);
      if (!mounted || scope != ledger.scope || sequence != generation) return;
      final ids = next.links.map((link) => link.other(widget.id)).toSet();
      setState(() {
        detail = next;
        staleAfterConflict = false;
        if (request == null && error?.isType('accounting-conflict') == true) {
          error = null;
        }
        related.removeWhere((id, _) => !ids.contains(id));
        relatedErrors.clear();
        relatedLoading
          ..clear()
          ..addAll(ids);
      });
      await Future.wait([
        for (final id in ids) loadRelated(id, sequence: sequence),
      ]);
    } on ApiFailure catch (failure) {
      if (mounted && scope == ledger.scope && sequence == generation) {
        setState(() => loadError = failure);
        ledger.identity.handleFailure(failure);
      }
    } finally {
      if (mounted && scope == ledger.scope && sequence == generation) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> loadRelated(String id, {int? sequence}) async {
    final expected = sequence ?? generation;
    final scope = ledger.scope;
    setState(() {
      relatedLoading.add(id);
      relatedErrors.remove(id);
    });
    try {
      final next = await ledger.api.detail(ledger.bookId!, id);
      if (mounted && scope == ledger.scope && expected == generation) {
        setState(() => related[id] = next.transaction);
      }
    } on ApiFailure catch (failure) {
      if (mounted && scope == ledger.scope && expected == generation) {
        setState(() => relatedErrors[id] = failure);
        ledger.identity.handleFailure(failure);
      }
    } finally {
      if (mounted && scope == ledger.scope && expected == generation) {
        setState(() => relatedLoading.remove(id));
      }
    }
  }

  Future<void> open(String path) async {
    final scope = ledger.scope;
    await context.push(path);
    if (mounted && scope == ledger.scope) await load();
  }

  bool get feesReady => detail!.links
      .where((link) => link.kind == 'fee' && link.sourceId == widget.id)
      .every(
        (link) =>
            related.containsKey(link.targetId) &&
            !relatedLoading.contains(link.targetId) &&
            !relatedErrors.containsKey(link.targetId),
      );

  Future<void> retryMutation() async {
    if (request case final pending?) {
      await perform(pending.method, pending.path, pending.body, close: false);
      if (mounted && request == null && error == null) await load();
    } else {
      setState(() {
        staleAfterConflict = error?.isType('accounting-conflict') == true;
        error = null;
      });
      await load();
    }
  }

  Future<void> removeLink(TransactionLink link) async {
    setState(() => activeAction = link.id);
    await perform(
      'DELETE',
      ledger.api.bookPath(ledger.bookId!, 'transaction-links/${link.id}'),
      null,
      close: false,
    );
    if (mounted && request == null && error == null) await load();
  }

  Future<void> deleteTransaction() async {
    if (frozen || loading || !feesReady) return;
    final d = detail!;
    final fees = d.links
        .where((link) => link.kind == 'fee' && link.sourceId == widget.id)
        .map((link) => related[link.targetId])
        .nonNulls
        .where((transaction) => transaction.status == 'posted')
        .toList();
    final selected = <String>{};
    final scope = ledger.scope;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final changes = reversalChanges(
            ledger,
            [d.transaction, ...fees.where((fee) => selected.contains(fee.id))],
          );
          return AlertDialog(
            scrollable: true,
            title: Text(context.l10n.deleteTransaction),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.deleteHint),
                accountingGap,
                _PrincipalReview(
                  controller: ledger,
                  transaction: d.transaction,
                ),
                if (fees.isNotEmpty) ...[
                  accountingGap,
                  Text(
                    context.l10n.includeFeesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: LedgerTokens.sm),
                  Text(context.l10n.includeFeesHint),
                  for (final fee in fees)
                    CheckboxListTile(
                      key: ValueKey('void-fee-${fee.id}'),
                      value: selected.contains(fee.id),
                      contentPadding: EdgeInsets.zero,
                      title: Text(transactionAmount(ledger, fee)),
                      subtitle: Text(
                        [
                          ledger.account(fee.accountId)?.name ??
                              context.l10n.accountLabel,
                          fee.date,
                          if (fee.note.isNotEmpty) fee.note,
                        ].join(' · '),
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
                accountingGap,
                Text(
                  context.l10n.detailReversalChanges,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final entry in changes.entries)
                  AccountingReviewLine(
                    key: ValueKey('void-net-${entry.key}'),
                    title: ledger.account(entry.key)!.name,
                    value: entry.value.format(
                      ledger.account(entry.key)!.currency,
                    ),
                  ),
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
          );
        },
      ),
    );
    if (confirmed != true || !mounted || scope != ledger.scope) return;
    setState(() => activeAction = 'void');
    await perform(
      'POST',
      ledger.api.bookPath(
        ledger.bookId!,
        'transactions/${widget.id}/corrections',
      ),
      {
        'expected_revision': d.transaction.revision,
        'fees': [
          for (final fee in fees.where((fee) => selected.contains(fee.id)))
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
        final disabled = actionsDisabled || openingAction;
        return LedgerPage(
          title: context.l10n.transactionDetail,
          leading: accountingBack(context),
          actions: [
            IconButton(
              key: const ValueKey('refresh-transaction'),
              tooltip: loading
                  ? context.l10n.refreshingLabel
                  : context.l10n.refreshAction,
              onPressed: frozen || loading ? null : load,
              icon: loading
                  ? const SizedBox.square(
                      dimension: LedgerTokens.icon,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.refreshCw),
            ),
          ],
          children: [
            if (d == null && loading) const LedgerLoading(),
            if (loadError case final failure?) ...[
              FailureView(
                failure,
                action: LedgerAction(
                  key: const ValueKey('retry-detail-load'),
                  label: context.l10n.reloadDetail,
                  secondary: true,
                  onPressed: frozen || loading ? null : load,
                ),
              ),
              accountingGap,
            ],
            if (d != null && t != null) ...[
              TransactionSummary(
                key: ValueKey('transaction-${t.id}'),
                controller: c,
                transaction: t,
              ),
              accountingGap,
              LedgerGroup(
                children: [
                  LedgerRow(title: context.l10n.dateLabel, value: t.date),
                  if (c.categoryName(
                        t.data['category_id'] as String?,
                        Localizations.localeOf(context).languageCode,
                      )
                      case final String category when category.isNotEmpty)
                    LedgerRow(
                      title: context.l10n.categoryLabel,
                      value: category,
                    ),
                  if (t.data['counterparty_id'] case final String id)
                    LedgerRow(
                      title: context.l10n.counterpartyLabel,
                      value:
                          c.counterparties
                              .where((value) => value.id == id)
                              .firstOrNull
                              ?.name ??
                          context.l10n.noneOption,
                    ),
                  if (t.note.isNotEmpty)
                    LedgerRow(title: context.l10n.noteLabel, value: t.note),
                  if (d.refundableAmount != null &&
                      c.account(t.accountId) != null)
                    LedgerFinancialRow(
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
                          '1 ${rate['from_currency']} = '
                          '${rate['display']} ${rate['to_currency']}',
                      subtitle: rate['date'] as String,
                    ),
                ],
              ),
              accountingGap,
              _DetailActionButtons(
                key: const ValueKey('transaction-actions'),
                onEdit: disabled ? null : () => openDetailAction(edit: true),
                showEdit: t.status == 'posted',
                onMore: disabled ? null : openDetailAction,
              ),
              accountingGap,
              ...feedback(showSaving: false),
              if (error != null || request != null && !saving) ...[
                LedgerAction(
                  key: const ValueKey('retry-detail-write'),
                  label: request == null
                      ? context.l10n.reloadDetail
                      : context.l10n.retryAction,
                  secondary: true,
                  busy: saving,
                  onPressed: loading ? null : retryMutation,
                ),
                accountingGap,
              ],
              LedgerSection(
                title: context.l10n.relatedTransactions,
                children: [
                  if (d.links.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(LedgerTokens.lg),
                      child: Text(context.l10n.detailNoRelations),
                    ),
                  for (final link in d.links)
                    _RelationItem(
                      key: ValueKey('relation-${link.id}'),
                      targetId: link.other(widget.id),
                      controller: c,
                      kind: link.kind,
                      transaction: related[link.other(widget.id)],
                      failure: relatedErrors[link.other(widget.id)],
                      loading: relatedLoading.contains(link.other(widget.id)),
                      busy: saving && activeAction == link.id,
                      enabled: !disabled,
                      onOpen: () => open(
                        '/transactions/'
                        '${Uri.encodeComponent(link.other(widget.id))}',
                      ),
                      onRetry: () => loadRelated(link.other(widget.id)),
                      onRemove: link.kind == 'related'
                          ? () => removeLink(link)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: LedgerTokens.xl),
              _HistoryPanel(controller: c, detail: d),
              if (t.status == 'posted') ...[
                const SizedBox(height: LedgerTokens.xl),
                if (!feesReady) ...[
                  LedgerNotice(
                    title: context.l10n.includeFeesTitle,
                    body: context.l10n.detailFeesIncomplete,
                  ),
                  const SizedBox(height: LedgerTokens.md),
                ],
                TextButton(
                  key: const ValueKey('void-transaction'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: disabled || !feesReady ? null : deleteTransaction,
                  child: Text(
                    saving && activeAction == 'void'
                        ? context.l10n.detailSaving
                        : context.l10n.deleteTransaction,
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

String transactionAmount(AccountingController controller, LedgerTransaction t) {
  final account = controller.account(t.accountId);
  return account == null
      ? t.amount
      : amountText(controller, t.amount, account.currency);
}

Map<String, LedgerMoney> reversalChanges(
  AccountingController controller,
  List<LedgerTransaction> transactions,
) {
  final changes = <String, LedgerMoney>{};
  void add(String accountId, String amount, {required bool negative}) {
    final account = controller.account(accountId);
    if (account == null) return;
    final value = LedgerMoney.parse(
      amount,
      controller.scale(account.currency),
      constrain: false,
    );
    final signed = negative ? value.negative : value;
    changes.update(
      accountId,
      (previous) => previous + signed,
      ifAbsent: () => signed,
    );
  }

  for (final t in transactions) {
    add(
      t.accountId,
      t.amount,
      negative: !['expense', 'transfer'].contains(t.kind),
    );
    if (t.kind == 'transfer') {
      add(
        t.data['to_account_id'] as String,
        t.data['to_amount'] as String,
        negative: true,
      );
    }
  }
  return changes;
}

class TransactionSummary extends StatelessWidget {
  const TransactionSummary({
    required this.controller,
    required this.transaction,
    super.key,
  });
  final AccountingController controller;
  final LedgerTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final source = controller.account(t.accountId);
    final destination = controller.account(
      t.data['to_account_id'] as String? ?? '',
    );
    return LedgerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: LedgerTokens.md,
            runSpacing: LedgerTokens.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                transactionKind(context, t.kind),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              LedgerBadge(
                t.status == 'void'
                    ? context.l10n.voidedLabel
                    : context.l10n.detailStatusPosted,
              ),
            ],
          ),
          accountingGap,
          Text(
            destination != null
                ? context.l10n.sourcePrincipal
                : source?.name ?? context.l10n.accountLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (destination != null)
            Text(source?.name ?? context.l10n.accountLabel),
          const SizedBox(height: LedgerTokens.sm),
          LedgerMoneyText(transactionAmount(controller, t), prominent: true),
          if (destination != null) ...[
            accountingGap,
            Text(
              context.l10n.destinationPrincipal,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(destination.name),
            const SizedBox(height: LedgerTokens.sm),
            LedgerMoneyText(
              amountText(
                controller,
                t.data['to_amount'] as String,
                destination.currency,
              ),
              prominent: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _PrincipalReview extends StatelessWidget {
  const _PrincipalReview({required this.controller, required this.transaction});
  final AccountingController controller;
  final LedgerTransaction transaction;
  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final sourceName =
        controller.account(t.accountId)?.name ?? context.l10n.accountLabel;
    final destination = controller.account(
      t.data['to_account_id'] as String? ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AccountingReviewLine(
          title: destination == null
              ? transactionKind(context, t.kind)
              : context.l10n.sourcePrincipal,
          subtitle: '$sourceName · ${t.date}',
          value: transactionAmount(controller, t),
        ),
        if (destination != null)
          AccountingReviewLine(
            title: context.l10n.destinationPrincipal,
            subtitle: destination.name,
            value: amountText(
              controller,
              t.data['to_amount'] as String,
              destination.currency,
            ),
          ),
        if (t.note.isNotEmpty) Text(t.note),
      ],
    );
  }
}

class _RelationItem extends StatelessWidget {
  const _RelationItem({
    required this.targetId,
    required this.controller,
    required this.kind,
    required this.transaction,
    required this.failure,
    required this.loading,
    required this.busy,
    required this.enabled,
    required this.onOpen,
    required this.onRetry,
    required this.onRemove,
    super.key,
  });
  final AccountingController controller;
  final String targetId;
  final String kind;
  final LedgerTransaction? transaction;
  final ApiFailure? failure;
  final bool loading;
  final bool busy;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onRetry;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final t = transaction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LedgerTokens.lg,
            LedgerTokens.lg,
            LedgerTokens.lg,
            0,
          ),
          child: Text(
            relationKind(context, kind),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        if (t != null)
          TransactionRow(
            controller: controller,
            transaction: t,
            onTap: onOpen,
            enabled: enabled,
            links: const [],
          ),
        if (t == null && loading)
          Padding(
            padding: const EdgeInsets.all(LedgerTokens.lg),
            child: Semantics(
              liveRegion: true,
              child: Text(context.l10n.loadingLabel),
            ),
          ),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.all(LedgerTokens.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: LedgerTokens.sm),
                Text(
                  context.l10n.detailRelatedUnavailable,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(context.l10n.detailRelatedRetryBody),
                const SizedBox(height: LedgerTokens.sm),
                LedgerAction(
                  key: ValueKey('retry-related-$targetId'),
                  label: context.l10n.retryAction,
                  secondary: true,
                  onPressed: loading ? null : onRetry,
                ),
              ],
            ),
          ),
        if (onRemove != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LedgerTokens.lg,
              0,
              LedgerTokens.lg,
              LedgerTokens.lg,
            ),
            child: LedgerAction(
              label: context.l10n.removeLink,
              secondary: true,
              busy: busy,
              onPressed: enabled ? onRemove : null,
            ),
          ),
      ],
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.controller, required this.detail});
  final AccountingController controller;
  final LedgerTransactionDetail detail;
  @override
  Widget build(BuildContext context) => _DetailExpansion(
    key: const ValueKey('transaction-history'),
    title: context.l10n.historyTitle,
    children: [
      for (final revision in detail.history)
        _RevisionSummary(
          controller: controller,
          detail: detail,
          revision: revision,
        ),
    ],
  );
}

class _RevisionSummary extends StatelessWidget {
  const _RevisionSummary({
    required this.controller,
    required this.detail,
    required this.revision,
  });
  final AccountingController controller;
  final LedgerTransactionDetail detail;
  final Json revision;
  @override
  Widget build(BuildContext context) {
    final data = revision['data'] as Json;
    final t = LedgerTransaction.fromJson({
      'id': detail.transaction.id,
      'revision': revision['revision'],
      'status': revision['voided'] == true ? 'void' : 'posted',
      'data': data,
    });
    final created = DateTime.tryParse(revision['created_at'] as String? ?? '');
    final localTime = created == null
        ? null
        : tz.TZDateTime.from(
            created,
            tz.getLocation(
              controller.identity.context?.preferences.timezone ?? 'UTC',
            ),
          );
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsets.only(bottom: LedgerTokens.lg),
      child: LedgerSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${context.l10n.revisionLabel} ${revision['revision']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: LedgerTokens.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: LedgerBadge(
                t.status == 'void'
                    ? context.l10n.voidedLabel
                    : context.l10n.detailStatusPosted,
              ),
            ),
            if (localTime != null) ...[
              const SizedBox(height: LedgerTokens.sm),
              Text(
                '${context.l10n.detailRecordedAt}: '
                '${DateFormat.yMMMd(locale).add_Hm().format(localTime)}',
              ),
            ],
            _PrincipalReview(controller: controller, transaction: t),
            if (controller.categoryName(
                  t.data['category_id'] as String?,
                  Localizations.localeOf(context).languageCode,
                )
                case final String category when category.isNotEmpty)
              Text('${context.l10n.categoryLabel}: $category'),
            for (final journal in detail.journals.where(
              (journal) => journal['revision'] == revision['revision'],
            ))
              _DetailExpansion(
                title: journal['reversal_of'] == null
                    ? context.l10n.postingLabel
                    : context.l10n.reversalLabel,
                children: [
                  for (final posting
                      in (journal['postings'] as List).cast<Json>())
                    AccountingReviewLine(
                      title:
                          controller
                              .account(posting['account_id'] as String? ?? '')
                              ?.name ??
                          context.l10n.categoryLabel,
                      value: amountText(
                        controller,
                        posting['amount'] as String,
                        posting['currency'] as String,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailExpansion extends StatefulWidget {
  const _DetailExpansion({
    required this.title,
    required this.children,
    super.key,
  });
  final String title;
  final List<Widget> children;
  @override
  State<_DetailExpansion> createState() => _DetailExpansionState();
}

class _DetailExpansionState extends State<_DetailExpansion> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(widget.title),
    trailing: Icon(expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown),
    onExpansionChanged: (value) => setState(() => expanded = value),
    tilePadding: const EdgeInsets.symmetric(horizontal: LedgerTokens.lg),
    childrenPadding: const EdgeInsets.only(top: LedgerTokens.md),
    children: widget.children,
  );
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
  LedgerTransaction? source;
  Set<String> existingTargets = {};
  ApiFailure? loadError;
  ApiFailure? sourceError;
  bool loading = false;
  String? selectedId;
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(() async {
        await Future.wait([load(), loadSource()]);
      }),
    );
  }

  Future<void> loadSource() async {
    final scope = ledger.scope;
    setState(() => sourceError = null);
    try {
      final detail = await ledger.api.detail(ledger.bookId!, widget.sourceId);
      if (mounted && scope == ledger.scope) {
        setState(() {
          source = detail.transaction;
          existingTargets = detail.links
              .where((link) => link.kind == widget.kind)
              .map((link) => link.other(widget.sourceId))
              .toSet();
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted && scope == ledger.scope) {
        setState(() => sourceError = failure);
        ledger.identity.handleFailure(failure);
      }
    }
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    final scope = ledger.scope;
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final next = await ledger.api.transactions(ledger.bookId!, {
        if (widget.kind == 'fee') 'kind': 'expense',
        if (widget.kind == 'related') 'include_voided': 'true',
        if (more && page?.nextCursor != null) 'cursor': page!.nextCursor!,
      });
      if (mounted && scope == ledger.scope) {
        setState(() {
          page = more && page != null
              ? mergeTransactionPages(page!, next)
              : next;
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted && scope == ledger.scope) {
        setState(() => loadError = failure);
        ledger.identity.handleFailure(failure);
      }
    } finally {
      if (mounted && scope == ledger.scope) setState(() => loading = false);
    }
  }

  Future<void> link(LedgerTransaction transaction) async {
    setState(() => selectedId = transaction.id);
    await perform(
      'POST',
      ledger.api.bookPath(ledger.bookId!, 'transaction-links'),
      {
        'source_id': widget.sourceId,
        'target_id': transaction.id,
        'kind': widget.kind,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        page?.transactions
            .where(
              (transaction) =>
                  transaction.id != widget.sourceId &&
                  !existingTargets.contains(transaction.id) &&
                  (widget.kind != 'fee' || transaction.status == 'posted'),
            )
            .toList() ??
        <LedgerTransaction>[];
    return LedgerPage(
      title: widget.kind == 'fee'
          ? context.l10n.feeSelectExisting
          : context.l10n.linkTransaction,
      leading: accountingBack(context),
      itemCount: rows.length + (page?.nextCursor != null ? 1 : 0),
      itemBuilder: (context, index) => index == rows.length
          ? LedgerAction(
              label: context.l10n.loadMore,
              secondary: true,
              busy: loading,
              onPressed: frozen ? null : () => load(more: true),
            )
          : Padding(
              padding: const EdgeInsets.only(bottom: LedgerTokens.md),
              child: LedgerGroup(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TransactionRow(
                        controller: ledger,
                        transaction: rows[index],
                        readOnly: true,
                        links: page?.links,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          LedgerTokens.lg,
                          0,
                          LedgerTokens.lg,
                          LedgerTokens.lg,
                        ),
                        child: LedgerAction(
                          key: ValueKey('link-${rows[index].id}'),
                          label: context.l10n.detailLinkAction,
                          secondary: true,
                          busy: saving && selectedId == rows[index].id,
                          onPressed:
                              frozen || source == null || sourceError != null
                              ? null
                              : () => link(rows[index]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      children: [
        LedgerNotice(
          title: widget.kind == 'fee'
              ? context.l10n.feeRelation
              : context.l10n.relatedType,
          body: widget.kind == 'fee'
              ? context.l10n.detailLinkFeeHint
              : context.l10n.detailLinkHint,
        ),
        accountingGap,
        if (source case final transaction?) ...[
          Text(
            context.l10n.detailLinkSource,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TransactionRow(
            controller: ledger,
            transaction: transaction,
            readOnly: true,
          ),
          accountingGap,
        ],
        if (source == null && sourceError == null) ...[
          const LedgerLoading(),
          accountingGap,
        ],
        if (sourceError != null) ...[
          FailureView(
            sourceError!,
            action: LedgerAction(
              label: context.l10n.retryAction,
              secondary: true,
              onPressed: loadSource,
            ),
          ),
          accountingGap,
        ],
        ...feedback(showSaving: false),
        if (error != null || request != null && !saving) ...[
          LedgerAction(
            key: const ValueKey('retry-link-write'),
            label: request == null
                ? context.l10n.reloadDetail
                : context.l10n.retryAction,
            secondary: true,
            busy: saving,
            onPressed: loading
                ? null
                : () async {
                    if (request case final pending?) {
                      await perform(pending.method, pending.path, pending.body);
                    } else {
                      setState(() => error = null);
                      await Future.wait([load(), loadSource()]);
                    }
                  },
          ),
          accountingGap,
        ],
        if (loading && page == null) const LedgerLoading(),
        if (page != null && rows.isEmpty)
          LedgerNotice(
            title: context.l10n.noMatches,
            body: context.l10n.detailLinkEmpty,
          ),
        if (loadError != null) ...[
          FailureView(
            loadError!,
            action: LedgerAction(
              label: context.l10n.retryAction,
              secondary: true,
              onPressed: loading
                  ? null
                  : () => load(more: page?.nextCursor != null),
            ),
          ),
          accountingGap,
        ],
      ],
    );
  }
}
