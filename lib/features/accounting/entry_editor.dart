// Entry controls preserve exact amounts and explicit correction scope.
// ignore_for_file: public_member_api_docs
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/accounting/models.dart';
import 'package:ledger_app/core/accounting/money.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/accounting/forms.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

class EntryEditor extends ConsumerStatefulWidget {
  const EntryEditor({this.editId, this.originalId, this.feeForId, super.key});
  final String? editId;
  final String? originalId;
  final String? feeForId;
  @override
  ConsumerState<EntryEditor> createState() => _EntryEditorState();
}

class _FeeDraft {
  _FeeDraft({
    required this.account,
    required this.category,
    required String date,
    this.transaction,
    String amount = '',
  }) : amount = TextEditingController(text: amount),
       date = TextEditingController(text: date),
       note = TextEditingController(text: transaction?.note ?? '');
  LedgerTransaction? transaction;
  String account;
  String category;
  bool selected = false;
  bool available = true;
  final TextEditingController amount;
  final TextEditingController date;
  final TextEditingController note;
  void dispose() {
    amount.dispose();
    date.dispose();
    note.dispose();
  }
}

class _EntrySnapshot {
  const _EntrySnapshot(this.detail, this.fees, this.original);
  final LedgerTransactionDetail detail;
  final List<LedgerTransaction> fees;
  final LedgerTransactionDetail? original;
}

class _EntryEditorState extends LedgerMutationState<EntryEditor> {
  final GlobalKey _unavailableNoticeKey = GlobalKey();
  final amount = TextEditingController();
  final toAmount = TextEditingController();
  final date = TextEditingController();
  final note = TextEditingController();
  String kind = 'expense';
  String account = '';
  String destination = '';
  String category = '';
  String counterparty = '';
  String? originalId;
  String? refundCurrency;
  String? refundLimit;
  LedgerTransaction? existing;
  LedgerTransaction? sourceTransaction;
  bool initialized = false;
  bool loadingEntry = false;
  bool loadedExisting = false;
  bool reviewing = false;
  bool recovering = false;
  bool sourceUnavailable = false;
  _FeeDraft? newFee;
  final List<_FeeDraft> relatedFees = [];

  bool get needsSource =>
      widget.editId != null ||
      widget.originalId != null ||
      widget.feeForId != null;
  bool get correctionConflict =>
      revisionReviewRequired && widget.editId != null;
  @override
  bool get frozen =>
      super.frozen || reviewing || recovering || sourceUnavailable;

  @override
  void dispose() {
    amount.dispose();
    toAmount.dispose();
    date.dispose();
    note.dispose();
    newFee?.dispose();
    for (final f in relatedFees) {
      f.dispose();
    }
    super.dispose();
  }

  void initialize(AccountingController c) {
    if (initialized || c.page == null) return;
    initialized = true;
    date.text = c.today;
    account = c.accounts.where((a) => !a.archived).firstOrNull?.id ?? '';
    category =
        c.categories
            .where(
              (v) =>
                  !v.archived &&
                  v.kind == 'expense' &&
                  (widget.feeForId == null || v.systemCode == 'fees'),
            )
            .firstOrNull
            ?.id ??
        '';
    originalId = widget.originalId;
    if (originalId != null) kind = 'refund';
    if (needsSource) {
      loadingEntry = true;
      unawaited(Future<void>.microtask(loadExisting));
    }
  }

  Future<_EntrySnapshot> fetchSnapshot() async {
    final scope = ledger.scope;
    final api = ledger.api;
    final book = ledger.bookId!;
    void checkScope() {
      if (!mounted || ledger.scope != scope) {
        throw const ApiFailure('session-changed');
      }
    }

    final detail = await api.detail(
      book,
      widget.editId ?? widget.originalId ?? widget.feeForId!,
    );
    checkScope();
    final fees = <LedgerTransaction>[];
    if (widget.editId != null) {
      for (final link in detail.links.where(
        (v) => v.kind == 'fee' && v.sourceId == detail.transaction.id,
      )) {
        final fee = await api.detail(book, link.targetId);
        checkScope();
        if (fee.transaction.status == 'posted') fees.add(fee.transaction);
      }
    }
    final original =
        widget.editId != null && detail.transaction.kind == 'refund'
        ? await api.detail(
            book,
            detail.transaction.data['original_id'] as String,
          )
        : null;
    checkScope();
    return _EntrySnapshot(detail, fees, original);
  }

  _FeeDraft feeDraft(LedgerTransaction fee) => _FeeDraft(
    transaction: fee,
    account: fee.accountId,
    category: fee.data['category_id'] as String,
    date: fee.date,
    amount: fee.amount,
  );

  void applySnapshot(_EntrySnapshot snapshot, {bool keepDraft = false}) {
    final t = snapshot.detail.transaction;
    sourceUnavailable = t.status != 'posted';
    if (widget.editId != null) {
      existing = t;
      sourceTransaction = snapshot.original?.transaction ?? t;
      kind = t.kind;
      originalId = t.data['original_id'] as String?;
      if (!keepDraft) {
        account = t.accountId;
        amount.text = t.amount;
        destination = t.data['to_account_id'] as String? ?? '';
        toAmount.text = t.data['to_amount'] as String? ?? '';
        date.text = t.date;
        note.text = t.note;
        counterparty = t.data['counterparty_id'] as String? ?? '';
        category = t.data['category_id'] as String? ?? '';
        for (final f in relatedFees) {
          f.dispose();
        }
        relatedFees.clear();
      }
      if (kind == 'opening') account = t.accountId;
      if (kind == 'refund') {
        category = t.data['category_id'] as String? ?? '';
        refundCurrency = ledger.account(sourceTransaction!.accountId)?.currency;
        final remaining = snapshot.original?.refundableAmount;
        if (remaining != null && refundCurrency != null) {
          final scale = ledger.scale(refundCurrency!);
          refundLimit =
              (LedgerMoney.parse(remaining, scale) +
                      LedgerMoney.parse(t.amount, scale))
                  .decimal;
        }
      }
      for (final f in relatedFees) {
        final latest = snapshot.fees
            .where((v) => v.id == f.transaction?.id)
            .firstOrNull;
        f.available = latest != null;
        if (latest != null) {
          f.transaction = latest;
        } else {
          f.selected = false;
        }
      }
      for (final fee in snapshot.fees) {
        if (!relatedFees.any((v) => v.transaction?.id == fee.id)) {
          relatedFees.add(feeDraft(fee));
        }
      }
    } else {
      sourceTransaction = t;
      if (widget.originalId != null) {
        refundCurrency = ledger.account(t.accountId)?.currency;
        refundLimit = snapshot.detail.refundableAmount;
        account = t.accountId;
        amount.text = refundLimit ?? '';
        category = t.data['category_id'] as String? ?? '';
      } else if (widget.feeForId != null) {
        account = t.accountId;
      }
    }
    loadedExisting = true;
  }

  Future<void> loadExisting() async {
    final scope = ledger.scope;
    try {
      final snapshot = await fetchSnapshot();
      if (!mounted || scope != ledger.scope) return;
      setState(() {
        applySnapshot(snapshot);
        error = null;
      });
    } on ApiFailure catch (e) {
      if (mounted && scope == ledger.scope) {
        ledger.identity.handleFailure(e);
        setState(() => error = e);
      }
    } finally {
      if (mounted && scope == ledger.scope) {
        setState(() => loadingEntry = false);
      }
    }
  }

  String canonical(String value, String accountId, {bool signed = false}) {
    final a = ledger.account(accountId);
    if (a == null) throw const FormatException('Missing account');
    final m = LedgerMoney.parse(value, ledger.scale(a.currency));
    if (m.units == BigInt.zero || (!signed && m.units.isNegative)) {
      throw const FormatException('Positive amount required');
    }
    return m.decimal;
  }

  String accountName(String id) => ledger.account(id)?.name ?? '';

  List<Choice> accountChoices(String selected) => [
    for (final a in ledger.accounts.where(
      (v) => !v.archived || v.id == selected,
    ))
      Choice(
        a.id,
        '${a.name} · ${a.currency}'
        '${a.archived ? ' · ${context.l10n.archivedLabel}' : ''}',
      ),
  ];
  List<Choice> categoryChoices(String type, String selected) => [
    for (final c in ledger.categories.where(
      (v) => v.kind == type && (!v.archived || v.id == selected),
    ))
      Choice(
        c.id,
        ledger.categoryName(c.id, Localizations.localeOf(context).languageCode),
      ),
  ];
  String? requiredChoice(String? value, List<Choice> choices) =>
      requiredText(value) ??
      (choices.any((v) => v.value == value)
          ? null
          : context.l10n.formSelectionUnavailable);

  Json feeInput(_FeeDraft f) => {
    'kind': 'expense',
    'occurred_on': f.date.text,
    'account_id': f.account,
    'amount': canonical(f.amount.text, f.account),
    'category_id': f.category,
    if (f.note.text.trim().isNotEmpty) 'note': f.note.text.trim(),
    if (f.transaction?.data['counterparty_id'] case final String cp)
      'counterparty_id': cp,
  };

  String formattedEntryAmount(Json input) => amountText(
    ledger,
    input['amount'] as String,
    ledger.account(input['account_id'] as String)!.currency,
  );

  Widget reviewEntry(String title, Json input) => Padding(
    padding: const EdgeInsets.only(bottom: LedgerTokens.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: LedgerTokens.sm),
        Text(
          '${ledger.account(input['account_id'] as String)?.name ?? ''}'
          ' · ${input['occurred_on']}',
        ),
        if (input['category_id'] case final String id)
          Text(
            ledger.categoryName(
              id,
              Localizations.localeOf(context).languageCode,
            ),
          ),
        LedgerMoneyText(formattedEntryAmount(input)),
        if (input['to_account_id'] case final String target) ...[
          const SizedBox(height: LedgerTokens.sm),
          Text(ledger.account(target)?.name ?? ''),
          LedgerMoneyText(
            amountText(
              ledger,
              input['to_amount'] as String,
              ledger.account(target)!.currency,
            ),
          ),
        ],
        if (input['note'] case final String note)
          if (note.isNotEmpty) Text(note),
      ],
    ),
  );

  Future<void> resolveConflict() async {
    if (frozen) return;
    final scope = ledger.scope;
    setState(() => recovering = true);
    try {
      final latest = await fetchSnapshot();
      if (!mounted || ledger.scope != scope) return;
      if (latest.detail.transaction.status != 'posted') {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() {
          sourceUnavailable = true;
          sourceTransaction = latest.detail.transaction;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || ledger.scope != scope) return;
          final notice = _unavailableNoticeKey.currentContext;
          if (notice != null) {
            unawaited(Scrollable.ensureVisible(notice, alignment: .1));
          }
        });
        return;
      }
      final missingSelected = relatedFees
          .where(
            (f) =>
                f.selected &&
                !latest.fees.any((t) => t.id == f.transaction?.id),
          )
          .toList();
      setState(() => recovering = false);
      final keep = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.formConflictTitle),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.formConflictReview),
              accountingGap,
              reviewEntry(
                context.l10n.formLatestValues,
                latest.detail.transaction.data,
              ),
              AccountingReviewLine(
                title: context.l10n.formYourDraft,
                subtitle:
                    '${ledger.account(account)?.name ?? ''} · ${date.text}',
                value:
                    '${amount.text} ${ledger.account(account)?.currency ?? ''}',
              ),
              if (kind == 'transfer')
                AccountingReviewLine(
                  title: context.l10n.destinationPrincipal,
                  subtitle: ledger.account(destination)?.name,
                  value:
                      '${toAmount.text} '
                      '${ledger.account(destination)?.currency ?? ''}',
                ),
              if (note.text.isNotEmpty) Text(note.text),
              for (final f in relatedFees.where((v) => v.selected)) ...[
                if (latest.fees
                        .where((t) => t.id == f.transaction?.id)
                        .firstOrNull
                    case final LedgerTransaction current)
                  reviewEntry(context.l10n.formLatestFee, current.data),
                AccountingReviewLine(
                  title: context.l10n.formDraftFee,
                  subtitle:
                      '${ledger.account(f.account)?.name ?? ''}'
                      ' · ${f.date.text}',
                  value:
                      '${f.amount.text} '
                      '${ledger.account(f.account)?.currency ?? ''}',
                ),
                if (f.note.text.isNotEmpty) Text(f.note.text),
              ],
              if (missingSelected.isNotEmpty)
                Text(context.l10n.formUnavailableFees),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancelAction),
            ),
            TextButton(
              key: const ValueKey('conflict-use-latest'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.formUseLatest),
            ),
            FilledButton(
              key: const ValueKey('conflict-keep-draft'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.formKeepDraft),
            ),
          ],
        ),
      );
      if (!mounted || scope != ledger.scope || keep == null) return;
      setState(() {
        applySnapshot(latest, keepDraft: keep);
        revisionReviewRequired = false;
        error = null;
      });
    } on ApiFailure catch (e) {
      if (mounted && scope == ledger.scope) {
        ledger.identity.handleFailure(e);
        if (mounted && scope == ledger.scope) setState(() => error = e);
      }
    } finally {
      if (mounted) setState(() => recovering = false);
    }
  }

  Future<void> save() async {
    if (saving || reviewing || recovering || sourceUnavailable) return;
    if (request != null) {
      await perform(request!.method, request!.path, request!.body);
      return;
    }
    setState(() => validation = null);
    if (!validateForm() || correctionConflict) return;
    Json input;
    Json? fee;
    List<Json> fees;
    try {
      input = {
        'kind': kind,
        'occurred_on': date.text,
        'account_id': account,
        'amount': canonical(amount.text, account, signed: kind == 'opening'),
        if (kind == 'transfer') ...{
          'to_account_id': destination,
          'to_amount': canonical(toAmount.text, destination),
        },
        if (kind == 'income' || kind == 'expense' || kind == 'refund')
          'category_id': category,
        if (counterparty.isNotEmpty) 'counterparty_id': counterparty,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
        if (originalId != null) 'original_id': originalId,
      };
      fee = newFee?.selected == true ? feeInput(newFee!) : null;
      fees = [
        for (final f in relatedFees.where((v) => v.selected && v.available))
          {
            'id': f.transaction!.id,
            'expected_revision': f.transaction!.revision,
            'entry': feeInput(f),
          },
      ];
    } on FormatException {
      setState(() => validation = context.l10n.invalidAmount);
      return;
    }
    final scope = ledger.scope;
    setState(() => reviewing = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.reviewTransaction),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${transactionKind(context, kind)} · ${date.text}'),
            accountingGap,
            if (existing != null)
              reviewEntry(context.l10n.formPreviousEntry, existing!.data),
            reviewEntry(
              existing == null
                  ? context.l10n.formTransactionDetails
                  : context.l10n.formUpdatedEntry,
              input,
            ),
            if (kind == 'transfer') ...[
              AccountingReviewLine(
                title: context.l10n.sourcePrincipal,
                value: formattedEntryAmount(input),
              ),
              AccountingReviewLine(
                title: context.l10n.destinationPrincipal,
                value: amountText(
                  ledger,
                  input['to_amount'] as String,
                  ledger.account(destination)!.currency,
                ),
              ),
            ],
            if (fee != null) reviewEntry(context.l10n.feeAmount, fee),
            for (final f in fees) ...[
              const Divider(),
              reviewEntry(
                context.l10n.formPreviousFee,
                relatedFees
                    .firstWhere((v) => v.transaction!.id == f['id'])
                    .transaction!
                    .data,
              ),
              reviewEntry(context.l10n.formUpdatedFee, f['entry'] as Json),
            ],
            if (fee != null || fees.isNotEmpty)
              Text(context.l10n.feeSeparateHint),
            accountingGap,
            Text(
              context.l10n.netAccountChanges,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...previewChanges(input, fee, fees),
            for (final f in relatedFees.where(
              (v) => !v.selected && v.available,
            ))
              reviewEntry(
                context.l10n.unselectedFeesRemain,
                f.transaction!.data,
              ),
            if (relatedFees.any((v) => !v.available))
              Text(context.l10n.formUnavailableFees),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.returnToEntry),
          ),
          FilledButton(
            key: const ValueKey('confirm-entry'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirmAction),
          ),
        ],
      ),
    );
    if (!mounted || scope != ledger.scope) return;
    setState(() => reviewing = false);
    if (accepted != true) return;
    final path = ledger.api.bookPath(
      ledger.bookId!,
      existing == null
          ? 'transactions'
          : 'transactions/${existing!.id}/corrections',
    );
    final body = existing == null
        ? <String, dynamic>{
            'entry': input,
            'fee': ?fee,
            if (widget.feeForId != null) 'fee_for_id': widget.feeForId,
          }
        : <String, dynamic>{
            'expected_revision': existing!.revision,
            'entry': input,
            if (fees.isNotEmpty) 'fees': fees,
          };
    await perform('POST', path, body);
  }

  List<Widget> previewChanges(Json input, Json? fee, List<Json> fees) {
    final changes = <String, LedgerMoney>{};
    void apply(Json entry, {bool reverse = false}) {
      final aid = entry['account_id'] as String;
      final a = ledger.account(aid)!;
      var m = LedgerMoney.parse(
        entry['amount'] as String,
        ledger.scale(a.currency),
      );
      if (entry['kind'] == 'expense' || entry['kind'] == 'transfer') {
        m = m.negative;
      }
      if (reverse) m = m.negative;
      changes[aid] = (changes[aid] ?? LedgerMoney(BigInt.zero, m.scale)) + m;
      if (entry['kind'] == 'transfer') {
        final target = entry['to_account_id'] as String;
        var received = LedgerMoney.parse(
          entry['to_amount'] as String,
          ledger.scale(ledger.account(target)!.currency),
        );
        if (reverse) received = received.negative;
        changes[target] =
            (changes[target] ?? LedgerMoney(BigInt.zero, received.scale)) +
            received;
      }
    }

    if (existing != null) apply(existing!.data, reverse: true);
    apply(input);
    if (fee != null) apply(fee);
    for (final f in fees) {
      final old = relatedFees.firstWhere((v) => v.transaction!.id == f['id']);
      apply(old.transaction!.data, reverse: true);
      apply(f['entry'] as Json);
    }
    return [
      for (final entry in changes.entries)
        AccountingReviewLine(
          title: ledger.account(entry.key)!.name,
          value: entry.value.format(ledger.account(entry.key)!.currency),
        ),
    ];
  }

  List<Widget> feeFields(_FeeDraft f) {
    final suffix = f.transaction?.id ?? 'new';
    final feeIndex = relatedFees
        .where((v) => v.selected && v.available)
        .toList()
        .indexOf(f);
    final path = f.transaction == null ? 'fee' : 'fees[$feeIndex].entry';
    final currency = ledger.account(f.account)?.currency ?? '';
    return [
      selectField(
        id: 'fee-account-$suffix',
        label: context.l10n.feeAccount,
        value: f.account,
        choices: accountChoices(f.account),
        onChanged: (v) => setState(() => f.account = v),
        validator: (v) => requiredChoice(v, accountChoices(f.account)),
        aliases: ['account_id', '$path.account_id'],
      ),
      selectField(
        id: 'fee-category-$suffix',
        label: context.l10n.feeCategory,
        value: f.category,
        choices: categoryChoices('expense', f.category),
        onChanged: (v) => setState(() => f.category = v),
        validator: (v) =>
            requiredChoice(v, categoryChoices('expense', f.category)),
        aliases: ['category_id', '$path.category_id'],
      ),
      field(
        context.l10n.feeAmount,
        f.amount,
        money: true,
        currency: currency,
        validator: (v) => amountValidator(v, currency),
        keyName: f.transaction == null
            ? 'fee-amount'
            : 'fee-amount-${f.transaction!.id}',
        aliases: ['amount', '$path.amount'],
      ),
      field(
        context.l10n.dateLabel,
        f.date,
        date: true,
        validator: dateText,
        keyName: 'fee-date-$suffix',
        aliases: ['occurred_on', '$path.occurred_on'],
      ),
      field(
        context.l10n.noteLabel,
        f.note,
        multiline: true,
        keyName: 'fee-note-$suffix',
        helperText: context.l10n.formOptional,
        aliases: ['note', '$path.note'],
      ),
    ];
  }

  Future<void> createCategory() async {
    final type = kind;
    final scope = ledger.scope;
    final result = await context.push<Json>('/categories/new?kind=$type');
    if (!mounted || ledger.scope != scope || result == null) return;
    final id = result['id'] as String?;
    final item = ledger.categories
        .where((v) => v.id == id && v.kind == type && !v.archived)
        .firstOrNull;
    if (item == null || kind != type) {
      setState(() => validation = context.l10n.formCategoryMismatch);
      return;
    }
    setState(() {
      category = item.id;
      validation = null;
    });
    fieldChanged('entry-category');
  }

  Future<void> createCounterparty() async {
    final scope = ledger.scope;
    final result = await context.push<Json>('/counterparties/new');
    if (!mounted || ledger.scope != scope || result == null) return;
    final id = result['id'] as String?;
    final item = ledger.counterparties
        .where((v) => v.id == id && !v.archived)
        .firstOrNull;
    if (item == null) {
      setState(() => validation = context.l10n.formSelectionUnavailable);
      return;
    }
    setState(() => counterparty = item.id);
    fieldChanged('entry-counterparty');
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        initialize(c);
        final currency = c.account(account)?.currency ?? '';
        final destinationCurrency = c.account(destination)?.currency ?? '';
        final accountOptions = accountChoices(account)
            .where(
              (v) =>
                  kind != 'refund' ||
                  refundCurrency == null ||
                  c.account(v.value)?.currency == refundCurrency,
            )
            .toList();
        final categoryOptions = categoryChoices(
          kind == 'refund' ? 'expense' : kind,
          category,
        );
        return Form(
          key: formKey,
          child: LedgerPage(
            title: widget.editId != null
                ? context.l10n.formCorrectTransaction
                : kind == 'refund'
                ? context.l10n.addRefund
                : widget.feeForId != null
                ? context.l10n.addFee
                : context.l10n.addTransaction,
            leading: accountingBack(context),
            maxWidth: LedgerTokens.formWidth,
            eagerChildren: true,
            children: [
              if (!initialized) AccountingFeedback(c),
              if (loadingEntry) const LedgerLoading(),
              if (initialized &&
                  !loadingEntry &&
                  (!needsSource || loadedExisting)) ...[
                if (sourceUnavailable) ...[
                  LedgerNotice(
                    key: _unavailableNoticeKey,
                    title: context.l10n.voidedLabel,
                    body: context.l10n.formRecordUnavailable,
                  ),
                  accountingGap,
                ],
                if (sourceTransaction case final LedgerTransaction source)
                  LedgerFormSection(
                    title: kind == 'refund'
                        ? context.l10n.formOriginalExpense
                        : widget.feeForId != null
                        ? context.l10n.formLinkedTransaction
                        : context.l10n.formPreviousEntry,
                    children: [
                      reviewEntry(
                        transactionKind(context, source.kind),
                        source.data,
                      ),
                      if (kind == 'refund' &&
                          refundLimit != null &&
                          refundCurrency != null)
                        LedgerReadOnlyField(
                          label: context.l10n.refundRemaining,
                          value: amountText(c, refundLimit!, refundCurrency!),
                        ),
                      if (existing != null)
                        Text(context.l10n.formCorrectionHint),
                    ],
                  ),
                if (accountOptions.isEmpty) ...[
                  LedgerNotice(
                    title: context.l10n.formNoAccounts,
                    body: context.l10n.formCreateAccountHint,
                    action: TextButton(
                      onPressed: frozen
                          ? null
                          : () => context.push('/accounts/new'),
                      child: Text(context.l10n.addAccount),
                    ),
                  ),
                  accountingGap,
                ],
                LedgerFormSection(
                  title: context.l10n.formTransactionDetails,
                  children: [
                    if (widget.editId == null &&
                        originalId == null &&
                        widget.feeForId == null)
                      selectField(
                        id: 'entry-kind',
                        label: context.l10n.transactionType,
                        value: kind,
                        searchable: false,
                        choices: [
                          for (final k in ['expense', 'income', 'transfer'])
                            Choice(k, transactionKind(context, k)),
                        ],
                        onChanged: (v) => setState(() {
                          kind = v;
                          category = '';
                        }),
                        aliases: const ['kind', 'entry.kind'],
                      ),
                    selectField(
                      id: 'entry-account',
                      label: kind == 'transfer'
                          ? context.l10n.sourceAccount
                          : context.l10n.accountLabel,
                      value: account,
                      choices: accountOptions,
                      readOnly: kind == 'opening',
                      helperText: kind == 'opening'
                          ? context.l10n.formOpeningAccountFixed
                          : null,
                      onChanged: (v) => setState(() {
                        account = v;
                        if (destination == account) destination = '';
                      }),
                      validator: (v) => requiredChoice(v, accountOptions),
                      aliases: const ['account_id', 'entry.account_id'],
                    ),
                    field(
                      kind == 'transfer'
                          ? context.l10n.sourcePrincipal
                          : context.l10n.amountLabel,
                      amount,
                      money: true,
                      currency: currency,
                      signed: kind == 'opening',
                      validator: (v) => amountValidator(
                        v,
                        currency,
                        signed: kind == 'opening',
                        maximum: kind == 'refund' ? refundLimit : null,
                      ),
                      keyName: 'entry-amount',
                      aliases: const ['amount', 'entry.amount'],
                    ),
                    if (kind == 'transfer') ...[
                      selectField(
                        id: 'entry-destination',
                        label: context.l10n.destinationAccount,
                        value: destination,
                        choices: accountChoices(
                          destination,
                        ).where((v) => v.value != account).toList(),
                        onChanged: (v) => setState(() => destination = v),
                        validator: (v) => v == account
                            ? context.l10n.sameAccountError
                            : requiredChoice(v, accountChoices(destination)),
                        aliases: const ['to_account_id', 'entry.to_account_id'],
                      ),
                      field(
                        context.l10n.destinationPrincipal,
                        toAmount,
                        money: true,
                        currency: destinationCurrency,
                        validator: (v) {
                          final error = amountValidator(v, destinationCurrency);
                          if (error != null) return error;
                          if (currency == destinationCurrency &&
                              amountValidator(amount.text, currency) == null &&
                              LedgerMoney.parse(v!, c.scale(currency)).units !=
                                  LedgerMoney.parse(
                                    amount.text,
                                    c.scale(currency),
                                  ).units) {
                            return context.l10n.formSameCurrencyPrincipal;
                          }
                          return null;
                        },
                        keyName: 'entry-to-amount',
                        aliases: const ['to_amount', 'entry.to_amount'],
                      ),
                    ],
                    if (kind == 'expense' ||
                        kind == 'income' ||
                        kind == 'refund') ...[
                      selectField(
                        id: 'entry-category',
                        label: context.l10n.categoryLabel,
                        value: category,
                        choices: categoryOptions,
                        readOnly: kind == 'refund',
                        helperText: kind == 'refund'
                            ? context.l10n.formRefundCategoryFixed
                            : null,
                        onChanged: (v) => setState(() => category = v),
                        validator: (v) => requiredChoice(v, categoryOptions),
                        aliases: const ['category_id', 'entry.category_id'],
                      ),
                      if (kind != 'refund')
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            key: const ValueKey('entry-add-category'),
                            onPressed: frozen ? null : createCategory,
                            child: Text(context.l10n.addCategory),
                          ),
                        ),
                    ],
                    field(
                      context.l10n.dateLabel,
                      date,
                      date: true,
                      validator: dateText,
                      keyName: 'entry-date',
                      aliases: const ['occurred_on', 'entry.occurred_on'],
                    ),
                  ],
                ),
                LedgerFormSection(
                  title: context.l10n.formAdditionalDetails,
                  children: [
                    selectField(
                      id: 'entry-counterparty',
                      label: context.l10n.counterpartyLabel,
                      value: counterparty,
                      helperText: context.l10n.formOptional,
                      choices: [
                        Choice('', context.l10n.noneOption),
                        for (final v in c.counterparties.where(
                          (v) => !v.archived || v.id == counterparty,
                        ))
                          Choice(v.id, v.name),
                      ],
                      onChanged: (v) => setState(() => counterparty = v),
                      aliases: const [
                        'counterparty_id',
                        'entry.counterparty_id',
                      ],
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: const ValueKey('entry-add-counterparty'),
                        onPressed: frozen ? null : createCounterparty,
                        child: Text(context.l10n.addCounterparty),
                      ),
                    ),
                    field(
                      context.l10n.noteLabel,
                      note,
                      multiline: true,
                      keyName: 'entry-note',
                      helperText: context.l10n.formOptional,
                      aliases: const ['note', 'entry.note'],
                    ),
                  ],
                ),
                if (existing == null &&
                    widget.feeForId == null &&
                    kind != 'opening')
                  LedgerFormSection(
                    title: context.l10n.feeLabel,
                    children: [
                      SwitchListTile(
                        key: const ValueKey('add-fee-toggle'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.addFee),
                        subtitle: Text(context.l10n.feeSeparateHint),
                        value: newFee?.selected ?? false,
                        onChanged: frozen
                            ? null
                            : (v) => setState(() {
                                newFee ??= _FeeDraft(
                                  account: account,
                                  category:
                                      c.categories
                                          .where(
                                            (v) =>
                                                !v.archived &&
                                                v.kind == 'expense' &&
                                                v.systemCode == 'fees',
                                          )
                                          .firstOrNull
                                          ?.id ??
                                      '',
                                  date: date.text,
                                );
                                newFee!.selected = v;
                              }),
                      ),
                      if (newFee?.selected == true) ...[
                        accountingGap,
                        ...feeFields(newFee!),
                      ],
                    ],
                  ),
                if (relatedFees.isNotEmpty) ...[
                  LedgerNotice(
                    title: context.l10n.includeFeesTitle,
                    body: context.l10n.includeFeesHint,
                  ),
                  accountingGap,
                  for (final f in relatedFees)
                    LedgerFormSection(
                      children: [
                        CheckboxListTile(
                          key: ValueKey('include-fee-${f.transaction!.id}'),
                          contentPadding: EdgeInsets.zero,
                          value: f.selected,
                          title: Text(context.l10n.feeLabel),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${accountName(f.transaction!.accountId)}'
                                ' · ${f.transaction!.date}',
                              ),
                              LedgerMoneyText(
                                formattedEntryAmount(f.transaction!.data),
                              ),
                            ],
                          ),
                          onChanged: frozen || !f.available
                              ? null
                              : (v) => setState(() => f.selected = v ?? false),
                        ),
                        if (!f.available) ...[
                          Text(context.l10n.formUnavailableFees),
                          LedgerReadOnlyField(
                            label: context.l10n.formDraftFee,
                            value:
                                '${f.amount.text} '
                                '${c.account(f.account)?.currency ?? ''}'
                                ' · ${f.date.text}',
                          ),
                          if (f.note.text.isNotEmpty) Text(f.note.text),
                        ],
                        if (f.selected) ...[accountingGap, ...feeFields(f)],
                      ],
                    ),
                ],
                ...feedback(
                  showSaving: false,
                  showError: error?.status != 409 || !correctionConflict,
                ),
                if (correctionConflict && !sourceUnavailable) ...[
                  LedgerNotice(
                    title: context.l10n.formConflictTitle,
                    body: context.l10n.formConflictBody,
                    action: LedgerAction(
                      key: const ValueKey('entry-review-conflict'),
                      label: context.l10n.formReviewLatest,
                      secondary: true,
                      busy: recovering,
                      onPressed: resolveConflict,
                    ),
                  ),
                  accountingGap,
                ],
                LedgerAction(
                  key: const ValueKey('save-entry'),
                  label: actionLabel(
                    existing == null
                        ? context.l10n.saveEntry
                        : context.l10n.formSaveCorrection,
                  ),
                  busy: saving,
                  onPressed:
                      reviewing ||
                          recovering ||
                          correctionConflict ||
                          sourceUnavailable
                      ? null
                      : save,
                ),
              ] else if (!loadingEntry) ...[
                ...feedback(showSaving: false),
                if (initialized && needsSource && !loadedExisting)
                  LedgerAction(
                    label: context.l10n.retryAction,
                    onPressed: () {
                      setState(() {
                        loadingEntry = true;
                        error = null;
                      });
                      unawaited(loadExisting());
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
