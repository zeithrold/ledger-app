// Forms freeze an ambiguous submission and retry its original idempotency key.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/accounting/accounting_api.dart';
import 'package:ledger_app/core/accounting/controller.dart';
import 'package:ledger_app/core/accounting/models.dart';
import 'package:ledger_app/core/accounting/money.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/choice_select.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

abstract class LedgerMutationState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  final formKey = GlobalKey<FormState>();
  PendingLedgerWrite? request;
  ApiFailure? error;
  String? validation;
  bool saving = false;
  bool get frozen => saving || request != null;
  AccountingController get ledger => ref.read(accountingProvider);

  Future<void> perform(
    String method,
    String path,
    Json? body, {
    bool close = true,
  }) async {
    if (saving) return;
    final scope = ledger.scope;
    request ??= PendingLedgerWrite(method, path, body);
    setState(() {
      saving = true;
      error = null;
      validation = null;
    });
    try {
      final result = await ledger.write(request!);
      if (mounted && ledger.scope == scope) {
        request = null;
        if (close) {
          if (context.canPop()) {
            context.pop(result);
          } else {
            context.go('/');
          }
        }
      }
    } on ApiFailure catch (e) {
      if (mounted && ledger.scope == scope) {
        setState(() {
          error = e;
          if (!identical(ledger.pendingWrite, request)) request = null;
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<Widget> feedback() => [
    if (validation != null) ...[
      Text(
        validation!,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
      accountingGap,
    ],
    if (error != null) ...[FailureView(error!), accountingGap],
    if (request != null && !saving) ...[
      Text(context.l10n.pendingWriteBody),
      accountingGap,
    ],
    if (saving) ...[const LedgerLoading(), accountingGap],
  ];
  String? requiredText(String? v) =>
      v == null || v.trim().isEmpty ? context.l10n.fieldRequired : null;
  String? dateText(String? v) {
    if (v == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
      return context.l10n.invalidDate;
    }
    final date = DateTime.tryParse(v);
    return date == null || date.toIso8601String().substring(0, 10) != v
        ? context.l10n.invalidDate
        : null;
  }

  Widget field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    bool money = false,
    bool multiline = false,
    String? keyName,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: LedgerTokens.lg),
    child: TextFormField(
      key: keyName == null ? null : ValueKey(keyName),
      controller: controller,
      enabled: !frozen,
      decoration: InputDecoration(labelText: label),
      validator: validator,
      keyboardType: money
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      minLines: 1,
      maxLines: multiline ? 4 : 1,
    ),
  );
}

class ReferenceEditor extends ConsumerStatefulWidget {
  const ReferenceEditor({
    required this.kind,
    this.id,
    this.categoryKind,
    super.key,
  });
  final String kind;
  final String? id;
  final String? categoryKind;
  @override
  ConsumerState<ReferenceEditor> createState() => _ReferenceEditorState();
}

class _ReferenceEditorState extends LedgerMutationState<ReferenceEditor> {
  final name = TextEditingController();
  final opening = TextEditingController(text: '0');
  final openingDate = TextEditingController();
  bool initialized = false;
  String kind = 'bank';
  String currency = '';
  String parent = '';
  bool archived = false;
  int revision = 1;
  @override
  void dispose() {
    name.dispose();
    opening.dispose();
    openingDate.dispose();
    super.dispose();
  }

  void initialize(AccountingController c) {
    if (initialized || c.page == null) return;
    initialized = true;
    openingDate.text = c.today;
    currency =
        c.books.where((b) => b.id == c.bookId).firstOrNull?.baseCurrency ??
        c.identity.context!.defaultBook.baseCurrency;
    if (!c.currencies.any((v) => v.code == currency)) {
      currency = c.currencies.first.code;
    }
    if (widget.kind == 'categories') kind = widget.categoryKind ?? 'expense';
    if (widget.id == null) return;
    if (widget.kind == 'accounts') {
      final a = c.account(widget.id!);
      if (a != null) {
        name.text = a.name;
        kind = a.kind;
        currency = a.currency;
        archived = a.archived;
        revision = a.revision;
      }
    } else if (widget.kind == 'categories') {
      final c = ledger.categories.where((v) => v.id == widget.id).firstOrNull;
      if (c != null) {
        name.text = c.name;
        kind = c.kind;
        parent = c.parentId ?? '';
        archived = c.archived;
        revision = c.revision;
      }
    } else {
      final c = ledger.counterparties
          .where((v) => v.id == widget.id)
          .firstOrNull;
      if (c != null) {
        name.text = c.name;
        archived = c.archived;
        revision = c.revision;
      }
    }
  }

  Future<void> save() async {
    if (request != null) {
      await perform(request!.method, request!.path, request!.body);
      return;
    }
    if (!formKey.currentState!.validate()) return;
    final creating = widget.id == null;
    final body = <String, dynamic>{'name': name.text.trim()};
    if (!creating) {
      body.addAll({'expected_revision': revision, 'archived': archived});
    } else if (widget.kind == 'accounts') {
      try {
        body['opening_amount'] = LedgerMoney.parse(
          opening.text,
          ledger.scale(currency),
        ).decimal;
      } on FormatException {
        setState(() => validation = context.l10n.invalidAmount);
        return;
      }
      body.addAll({
        'kind': kind,
        'currency': currency,
        'opening_date': openingDate.text,
      });
    } else if (widget.kind == 'categories') {
      body.addAll({'kind': kind, if (parent.isNotEmpty) 'parent_id': parent});
    }
    final resource =
        '${widget.kind}'
        '${creating ? '' : '/${Uri.encodeComponent(widget.id!)}'}';
    final path = widget.kind == 'counterparties'
        ? resource
        : ledger.api.bookPath(ledger.bookId!, resource);
    await perform(creating ? 'POST' : 'PATCH', path, body);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(accountingProvider);
    final reference = ref.watch(referenceChoicesProvider).value;
    final currencyLocale = ref.watch(currencyLocaleProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        initialize(c);
        final creating = widget.id == null;
        final title = switch (widget.kind) {
          'accounts' =>
            creating ? context.l10n.addAccount : context.l10n.editAccount,
          'categories' =>
            creating ? context.l10n.addCategory : context.l10n.editCategory,
          _ =>
            creating
                ? context.l10n.addCounterparty
                : context.l10n.editCounterparty,
        };
        return Form(
          key: formKey,
          child: LedgerPage(
            title: title,
            leading: accountingBack(context),
            maxWidth: LedgerTokens.formWidth,
            children: [
              if (!initialized) AccountingFeedback(c),
              if (initialized) ...[
                ...feedback(),
                field(
                  switch (widget.kind) {
                    'accounts' => context.l10n.accountName,
                    'categories' => context.l10n.categoryName,
                    _ => context.l10n.counterpartyName,
                  },
                  name,
                  validator: requiredText,
                  keyName: 'reference-name',
                ),
                if (creating && widget.kind == 'accounts') ...[
                  ChoiceSelect(
                    label: context.l10n.accountKind,
                    value: kind,
                    searchable: false,
                    choices: [
                      for (final k in ['cash', 'bank', 'wallet', 'other'])
                        Choice(k, accountKind(context, k)),
                    ],
                    onChanged: frozen ? null : (v) => setState(() => kind = v),
                  ),
                  ChoiceSelect(
                    key: const ValueKey('account-currency'),
                    label: context.l10n.currencyLabel,
                    value: currency,
                    choices: [
                      for (final v in c.currencies)
                        reference?.currencyChoice(v.code, currencyLocale) ??
                            Choice(v.code, v.code),
                    ],
                    onChanged: frozen
                        ? null
                        : (v) => setState(() => currency = v),
                  ),
                  accountingGap,
                  field(
                    context.l10n.openingBalance,
                    opening,
                    money: true,
                    validator: requiredText,
                    keyName: 'opening-amount',
                  ),
                  field(
                    context.l10n.openingDate,
                    openingDate,
                    validator: dateText,
                  ),
                ],
                if (creating && widget.kind == 'categories') ...[
                  ChoiceSelect(
                    label: context.l10n.transactionType,
                    value: kind,
                    searchable: false,
                    choices: [
                      for (final k in ['expense', 'income'])
                        Choice(k, transactionKind(context, k)),
                    ],
                    onChanged: frozen
                        ? null
                        : (v) => setState(() {
                            kind = v;
                            parent = '';
                          }),
                  ),
                  ChoiceSelect(
                    label: context.l10n.parentCategory,
                    value: parent,
                    choices: [
                      Choice('', context.l10n.rootCategory),
                      for (final v in c.categories.where(
                        (v) =>
                            !v.archived && v.kind == kind && v.parentId == null,
                      ))
                        Choice(
                          v.id,
                          v.label(Localizations.localeOf(context).languageCode),
                        ),
                    ],
                    onChanged: frozen
                        ? null
                        : (v) => setState(() => parent = v),
                  ),
                ],
                if (!creating) ...[
                  SwitchListTile(
                    title: Text(context.l10n.archiveLabel),
                    value: archived,
                    onChanged: frozen
                        ? null
                        : (v) => setState(() => archived = v),
                  ),
                  Text(
                    widget.kind == 'categories'
                        ? context.l10n.categoryArchiveHint
                        : context.l10n.archiveHint,
                  ),
                  accountingGap,
                ],
                LedgerAction(
                  key: const ValueKey('save-reference'),
                  label: request != null
                      ? context.l10n.retryAction
                      : context.l10n.saveChanges,
                  onPressed: saving ? null : save,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ReferencesPage extends ConsumerWidget {
  const ReferencesPage({required this.kind, super.key});
  final String kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(accountingProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final categories = kind == 'categories';
        final size = categories ? c.categories.length : c.counterparties.length;
        return LedgerPage(
          title: categories
              ? context.l10n.categoriesTitle
              : context.l10n.counterpartiesTitle,
          leading: accountingBack(context),
          itemCount: size,
          itemBuilder: (context, i) {
            final id = categories ? c.categories[i].id : c.counterparties[i].id;
            final archived = categories
                ? c.categories[i].archived
                : c.counterparties[i].archived;
            final type = categories
                ? transactionKind(context, c.categories[i].kind)
                : '';
            return LedgerRow(
              title: categories
                  ? c.categoryName(
                      id,
                      Localizations.localeOf(context).languageCode,
                    )
                  : c.counterparties[i].name,
              subtitle:
                  '$type'
                  '${archived ? ' · ${context.l10n.archivedLabel}' : ''}',
              onTap: () =>
                  context.push('/$kind/${Uri.encodeComponent(id)}/edit'),
            );
          },
          children: [
            AccountingBookSelector(c),
            AccountingFeedback(c),
            if (c.page != null)
              LedgerAction(
                label: categories
                    ? context.l10n.addCategory
                    : context.l10n.addCounterparty,
                onPressed: () => context.push('/$kind/new'),
              ),
          ],
        );
      },
    );
  }
}
