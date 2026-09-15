// Feature composition uses the maintained Material tokens and semantic
// controls.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/accounting/models.dart';
import 'package:ledger_app/core/accounting/money.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/features/auth/session_gate.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/choice_select.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const accountingGap = SizedBox(height: LedgerTokens.lg);

/// Recreates protected page state on either a session or book change.
class AccountingGate extends ConsumerWidget {
  const AccountingGate({
    required this.child,
    this.fullscreen = false,
    super.key,
  });
  final Widget child;
  final bool fullscreen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(accountingProvider);
    final content = ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SessionGate(
        child: controller.currencies.isEmpty
            ? LedgerPage(
                title: context.l10n.appTitle,
                children: [AccountingFeedback(controller)],
              )
            : KeyedSubtree(key: ValueKey(controller.scope), child: child),
      ),
    );
    return fullscreen ? Scaffold(body: SafeArea(child: content)) : content;
  }
}

String transactionKind(BuildContext context, String kind) => switch (kind) {
  'income' => context.l10n.incomeType,
  'expense' => context.l10n.expenseType,
  'transfer' => context.l10n.transferType,
  'refund' => context.l10n.refundType,
  'opening' => context.l10n.openingType,
  _ => context.l10n.transactionDetail,
};
String accountKind(BuildContext context, String kind) => switch (kind) {
  'cash' => context.l10n.accountCash,
  'bank' => context.l10n.accountBank,
  'wallet' => context.l10n.accountWallet,
  _ => context.l10n.accountOther,
};
String relationKind(BuildContext context, String kind) => switch (kind) {
  'fee' => context.l10n.feeRelation,
  'refund' => context.l10n.refundRelation,
  _ => context.l10n.relatedType,
};
String amountText(
  AccountingController controller,
  String amount,
  String currency,
) => LedgerMoney.parse(
  amount,
  controller.scale(currency),
  constrain: false,
).format(currency);

class AccountingBookSelector extends StatelessWidget {
  const AccountingBookSelector(this.controller, {super.key});
  final AccountingController controller;
  @override
  Widget build(BuildContext context) => controller.books.isEmpty
      ? const SizedBox.shrink()
      : ChoiceSelect(
          key: const ValueKey('selected-book'),
          label: context.l10n.selectBook,
          value: controller.bookId!,
          choices: [for (final b in controller.books) Choice(b.id, b.name)],
          searchable: controller.books.length > 5,
          onChanged: controller.loading ? null : controller.selectBook,
        );
}

class AccountingFeedback extends StatefulWidget {
  const AccountingFeedback(this.controller, {super.key});
  final AccountingController controller;
  @override
  State<AccountingFeedback> createState() => _AccountingFeedbackState();
}

class _AccountingFeedbackState extends State<AccountingFeedback> {
  bool resolving = false;
  ApiFailure? failure;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.pendingWrite != null) ...[
          LedgerStateView(
            title: context.l10n.pendingWriteTitle,
            body: context.l10n.pendingWriteBody,
          ),
          LedgerAction(
            label: context.l10n.resolveWrite,
            secondary: true,
            onPressed: resolving
                ? null
                : () async {
                    final pending = c.pendingWrite;
                    if (pending == null) return;
                    setState(() {
                      resolving = true;
                      failure = null;
                    });
                    try {
                      await c.write(pending);
                    } on ApiFailure catch (e) {
                      if (mounted) setState(() => failure = e);
                    } finally {
                      if (mounted) setState(() => resolving = false);
                    }
                  },
          ),
          accountingGap,
        ],
        if (failure ?? c.failure case final error?) ...[
          FailureView(error),
          LedgerAction(
            label: context.l10n.retryAction,
            secondary: true,
            onPressed: c.loading ? null : c.refresh,
          ),
          accountingGap,
        ],
        if (c.loading) ...[const LedgerLoading(), accountingGap],
      ],
    );
  }
}

Widget accountingBack(BuildContext context) => IconButton(
  tooltip: context.l10n.backToHome,
  onPressed: () {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  },
  icon: const Icon(LucideIcons.arrowLeft),
);

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    required this.controller,
    required this.transaction,
    this.onTap,
    this.readOnly = false,
    super.key,
  });
  final AccountingController controller;
  final LedgerTransaction transaction;
  final VoidCallback? onTap;
  final bool readOnly;
  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final account = controller.account(t.accountId);
    final category = controller.categoryName(
      t.data['category_id'] as String?,
      Localizations.localeOf(context).languageCode,
    );
    final kind = transactionKind(context, t.kind);
    final amount = account == null
        ? t.amount
        : amountText(controller, t.amount, account.currency);
    final destination = controller.account(
      t.data['to_account_id'] as String? ?? '',
    );
    final received = destination == null
        ? ''
        : amountText(
            controller,
            t.data['to_amount'] as String,
            destination.currency,
          );
    final relations =
        [...controller.page?.links ?? [], ...controller.recent?.links ?? []]
            .where((l) => l.sourceId == t.id || l.targetId == t.id)
            .map((l) => relationKind(context, l.kind))
            .toSet()
            .join(' · ');
    final value = destination == null ? amount : '$amount → $received';
    return LedgerRow(
      key: ValueKey('transaction-${t.id}'),
      title: t.note.isNotEmpty
          ? t.note
          : category.isNotEmpty
          ? category
          : kind,
      subtitle:
          '${t.date} · $kind · ${account?.name ?? ''}'
          '${relations.isEmpty ? '' : ' · $relations'}'
          '${t.status == 'void' ? ' · ${context.l10n.voidedLabel}' : ''}',
      value: value,
      onTap: readOnly
          ? null
          : onTap ??
                () =>
                    context.push('/transactions/${Uri.encodeComponent(t.id)}'),
    );
  }
}

/// Intrinsic-size-safe text for scrollable Material confirmation dialogs.
class AccountingReviewLine extends StatelessWidget {
  const AccountingReviewLine({
    required this.title,
    required this.value,
    this.subtitle,
    super.key,
  });
  final String title;
  final String value;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: LedgerTokens.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        if (subtitle != null) Text(subtitle!),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
