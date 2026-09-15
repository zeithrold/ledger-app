// Business entry controls remain separate from the immutable posting
// representation.
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
import 'package:ledger_app/shared/choice_select.dart';
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
  final LedgerTransaction? transaction;
  String account;
  String category;
  bool selected = false;
  final TextEditingController amount;
  final TextEditingController date;
  final TextEditingController note;
  void dispose() {
    amount.dispose();
    date.dispose();
    note.dispose();
  }
}

class _EntryEditorState extends LedgerMutationState<EntryEditor> {
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
  LedgerTransaction? existing;
  bool initialized = false;
  bool loadingEntry = false;
  bool loadedExisting = false;
  _FeeDraft? newFee;
  final List<_FeeDraft> relatedFees = [];

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
            .where((v) => !v.archived && v.kind == 'expense')
            .firstOrNull
            ?.id ??
        '';
    originalId = widget.originalId;
    if (originalId != null) kind = 'refund';
    if (widget.editId != null || originalId != null) {
      loadingEntry = true;
      unawaited(Future<void>.microtask(loadExisting));
    }
  }

  Future<void> loadExisting() async {
    final scope = ledger.scope;
    try {
      final detail = await ledger.api.detail(
        ledger.bookId!,
        widget.editId ?? originalId!,
      );
      if (!mounted || scope != ledger.scope) return;
      final t = detail.transaction;
      if (widget.editId != null) {
        existing = t;
        kind = t.kind;
        account = t.accountId;
        amount.text = t.amount;
        destination = t.data['to_account_id'] as String? ?? '';
        toAmount.text = t.data['to_amount'] as String? ?? '';
        date.text = t.date;
        note.text = t.note;
        originalId = t.data['original_id'] as String?;
        counterparty = t.data['counterparty_id'] as String? ?? '';
        for (final f in relatedFees) {
          f.dispose();
        }
        relatedFees.clear();
        for (final link in detail.links.where(
          (v) => v.kind == 'fee' && v.sourceId == t.id,
        )) {
          final fee = await ledger.api.detail(ledger.bookId!, link.targetId);
          if (!mounted || scope != ledger.scope) return;
          if (fee.transaction.status == 'posted') {
            relatedFees.add(
              _FeeDraft(
                transaction: fee.transaction,
                account: fee.transaction.accountId,
                category: fee.transaction.data['category_id'] as String,
                date: fee.transaction.date,
                amount: fee.transaction.amount,
              ),
            );
          }
        }
      } else {
        refundCurrency = ledger.account(t.accountId)?.currency;
        account = t.accountId;
        amount.text = detail.refundableAmount ?? '';
      }
      category = t.data['category_id'] as String? ?? '';
      loadedExisting = true;
    } on ApiFailure catch (e) {
      ledger.identity.handleFailure(e);
      if (mounted && scope == ledger.scope) setState(() => error = e);
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

  List<Choice> accountChoices(String selected) => [
    for (final a in ledger.accounts.where(
      (v) => !v.archived || v.id == selected,
    ))
      Choice(
        a.id,
        '${a.name} · '
        '${a.currency}'
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

  Future<void> save() async {
    if (request != null) {
      await perform(request!.method, request!.path, request!.body);
      return;
    }
    if (!formKey.currentState!.validate()) return;
    if (account.isEmpty ||
        ((kind == 'income' || kind == 'expense' || kind == 'refund') &&
            category.isEmpty) ||
        (kind == 'transfer' && destination.isEmpty)) {
      setState(() => validation = context.l10n.selectRequired);
      return;
    }
    if (kind == 'transfer' && account == destination) {
      setState(() => validation = context.l10n.sameAccountError);
      return;
    }
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
        for (final f in relatedFees.where((v) => v.selected))
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
            if (existing != null) ...[
              Text(context.l10n.unselectedFeesRemain),
              accountingGap,
            ],
            Text(
              context.l10n.netAccountChanges,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...previewChanges(input, fee, fees),
            if (kind == 'transfer') ...[
              accountingGap,
              AccountingReviewLine(
                title: context.l10n.sourcePrincipal,
                value: amountText(
                  ledger,
                  input['amount'] as String,
                  ledger.account(account)!.currency,
                ),
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
            if (fee != null)
              AccountingReviewLine(
                title: context.l10n.feeAmount,
                subtitle: ledger.account(fee['account_id'] as String)!.name,
                value: amountText(
                  ledger,
                  fee['amount'] as String,
                  ledger.account(fee['account_id'] as String)!.currency,
                ),
              ),
            for (final f in relatedFees.where((v) => !v.selected))
              AccountingReviewLine(
                title: context.l10n.unselectedFeesRemain,
                subtitle: ledger.account(f.account)?.name,
                value: f.transaction!.amount,
              ),
            if (fee != null) ...[
              accountingGap,
              Text(context.l10n.feeSeparateHint),
            ],
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
    if (accepted != true || !mounted || scope != ledger.scope) return;
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

  List<Widget> feeFields(_FeeDraft f) => [
    ChoiceSelect(
      key: ValueKey('fee-account-${f.transaction?.id ?? 'new'}'),
      label: context.l10n.feeAccount,
      value: f.account,
      choices: accountChoices(f.account),
      onChanged: frozen ? null : (v) => setState(() => f.account = v),
    ),
    ChoiceSelect(
      label: context.l10n.feeCategory,
      value: f.category,
      choices: categoryChoices('expense', f.category),
      onChanged: frozen ? null : (v) => setState(() => f.category = v),
    ),
    accountingGap,
    field(
      context.l10n.feeAmount,
      f.amount,
      money: true,
      validator: requiredText,
      keyName: f.transaction == null
          ? 'fee-amount'
          : 'fee-amount-${f.transaction!.id}',
    ),
    field(context.l10n.dateLabel, f.date, validator: dateText),
    if (f.transaction != null)
      field(context.l10n.noteLabel, f.note, multiline: true),
  ];

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        initialize(c);
        return Form(
          key: formKey,
          child: LedgerPage(
            title: widget.editId != null
                ? context.l10n.saveChanges
                : kind == 'refund'
                ? context.l10n.addRefund
                : widget.feeForId != null
                ? context.l10n.addFee
                : context.l10n.addTransaction,
            leading: accountingBack(context),
            maxWidth: LedgerTokens.formWidth,
            children: [
              if (!initialized) AccountingFeedback(c),
              ...feedback(),
              if (loadingEntry) const LedgerLoading(),
              if (initialized &&
                  !loadingEntry &&
                  (widget.editId == null && widget.originalId == null ||
                      loadedExisting)) ...[
                if (widget.editId == null &&
                    originalId == null &&
                    widget.feeForId == null)
                  ChoiceSelect(
                    key: const ValueKey('entry-kind'),
                    label: context.l10n.transactionType,
                    value: kind,
                    searchable: false,
                    choices: [
                      for (final k in ['expense', 'income', 'transfer'])
                        Choice(k, transactionKind(context, k)),
                    ],
                    onChanged: frozen
                        ? null
                        : (v) => setState(() {
                            kind = v;
                            category = '';
                          }),
                  ),
                ChoiceSelect(
                  key: const ValueKey('entry-account'),
                  label: kind == 'transfer'
                      ? context.l10n.sourceAccount
                      : context.l10n.accountLabel,
                  value: account,
                  choices: accountChoices(account)
                      .where(
                        (v) =>
                            kind != 'refund' ||
                            refundCurrency == null ||
                            ledger.account(v.value)?.currency == refundCurrency,
                      )
                      .toList(),
                  onChanged: frozen || kind == 'opening'
                      ? null
                      : (v) => setState(() => account = v),
                ),
                accountingGap,
                field(
                  kind == 'transfer'
                      ? context.l10n.sourcePrincipal
                      : context.l10n.amountLabel,
                  amount,
                  money: true,
                  validator: requiredText,
                  keyName: 'entry-amount',
                ),
                if (kind == 'transfer') ...[
                  ChoiceSelect(
                    key: const ValueKey('entry-destination'),
                    label: context.l10n.destinationAccount,
                    value: destination,
                    choices: accountChoices(
                      destination,
                    ).where((v) => v.value != account).toList(),
                    onChanged: frozen
                        ? null
                        : (v) => setState(() => destination = v),
                  ),
                  accountingGap,
                  field(
                    context.l10n.destinationPrincipal,
                    toAmount,
                    money: true,
                    validator: requiredText,
                    keyName: 'entry-to-amount',
                  ),
                  Text(context.l10n.feeSeparateHint),
                  accountingGap,
                ],
                if (kind == 'expense' ||
                    kind == 'income' ||
                    kind == 'refund') ...[
                  ChoiceSelect(
                    key: const ValueKey('entry-category'),
                    label: context.l10n.categoryLabel,
                    value: category,
                    choices: categoryChoices(
                      kind == 'refund' ? 'expense' : kind,
                      category,
                    ),
                    onChanged: frozen || kind == 'refund'
                        ? null
                        : (v) => setState(() => category = v),
                  ),
                  if (kind != 'refund')
                    TextButton(
                      onPressed: frozen
                          ? null
                          : () async {
                              final result = await context.push<Json>(
                                '/categories/new?kind=$kind',
                              );
                              if (mounted && result != null) {
                                setState(
                                  () => category = result['id'] as String,
                                );
                              }
                            },
                      child: Text(context.l10n.addCategory),
                    ),
                ],
                ChoiceSelect(
                  label: context.l10n.counterpartyLabel,
                  value: counterparty,
                  choices: [
                    Choice('', context.l10n.noneOption),
                    for (final v in c.counterparties.where(
                      (v) => !v.archived || v.id == counterparty,
                    ))
                      Choice(v.id, v.name),
                  ],
                  onChanged: frozen
                      ? null
                      : (v) => setState(() => counterparty = v),
                ),
                TextButton(
                  onPressed: frozen
                      ? null
                      : () async {
                          final result = await context.push<Json>(
                            '/counterparties/new',
                          );
                          if (mounted && result != null) {
                            setState(
                              () => counterparty = result['id'] as String,
                            );
                          }
                        },
                  child: Text(context.l10n.addCounterparty),
                ),
                accountingGap,
                field(
                  context.l10n.dateLabel,
                  date,
                  validator: dateText,
                  keyName: 'entry-date',
                ),
                field(
                  context.l10n.noteLabel,
                  note,
                  multiline: true,
                  keyName: 'entry-note',
                ),
                if (existing == null &&
                    widget.feeForId == null &&
                    kind != 'opening') ...[
                  SwitchListTile(
                    key: const ValueKey('add-fee-toggle'),
                    title: Text(context.l10n.addFee),
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
                  if (newFee?.selected == true) ...feeFields(newFee!),
                ],
                if (relatedFees.isNotEmpty)
                  LedgerSection(
                    title: context.l10n.includeFeesTitle,
                    children: [
                      Text(context.l10n.includeFeesHint),
                      for (final f in relatedFees) ...[
                        CheckboxListTile(
                          value: f.selected,
                          title: Text(
                            '${context.l10n.feeLabel} · '
                            '${ledger.account(f.account)?.name ?? ''} · '
                            '${f.transaction!.amount}',
                          ),
                          onChanged: frozen
                              ? null
                              : (v) => setState(() => f.selected = v ?? false),
                        ),
                        if (f.selected) ...feeFields(f),
                      ],
                    ],
                  ),
                accountingGap,
                LedgerAction(
                  key: const ValueKey('save-entry'),
                  label: request != null
                      ? context.l10n.retryAction
                      : context.l10n.saveEntry,
                  onPressed: saving ? null : save,
                ),
                if (error?.status == 409 && widget.editId != null)
                  TextButton(
                    onPressed: loadingEntry
                        ? null
                        : () {
                            setState(() {
                              loadingEntry = true;
                              error = null;
                            });
                            unawaited(loadExisting());
                          },
                    child: Text(context.l10n.reloadDetail),
                  ),
              ],
              if (initialized &&
                  !loadingEntry &&
                  (widget.editId != null || widget.originalId != null) &&
                  !loadedExisting)
                LedgerAction(
                  label: context.l10n.retryAction,
                  onPressed: () {
                    setState(() => loadingEntry = true);
                    unawaited(loadExisting());
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
