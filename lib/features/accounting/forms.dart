// Forms freeze an ambiguous submission and retry its original idempotency key.
// ignore_for_file: public_member_api_docs
import 'dart:async';
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
import 'package:ledger_app/core/reference/display_locale.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/choice_select.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

abstract class LedgerMutationState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  final formKey = GlobalKey<FormState>();
  final _anchors = <String, GlobalKey>{};
  final _focusNodes = <String, FocusNode>{};
  final _aliases = <String, Set<String>>{};
  final _serverErrors = <String, String>{};
  final _invalidFields = <String>[];
  PendingLedgerWrite? request;
  ApiFailure? error;
  String? validation;
  bool saving = false;
  bool revisionReviewRequired = false;
  bool get frozen => saving || request != null;
  AccountingController get ledger => ref.read(accountingProvider);

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode fieldFocus(String id) =>
      _focusNodes.putIfAbsent(id, () => FocusNode(debugLabel: id));

  Widget anchorField(
    String id,
    Widget child, {
    List<String> aliases = const [],
  }) {
    _aliases[id] = aliases.toSet();
    return KeyedSubtree(
      key: _anchors.putIfAbsent(id, GlobalKey.new),
      child: child,
    );
  }

  String? Function(String?) fieldValidator(
    String id,
    String? Function(String?)? validator,
  ) => (value) {
    final result = validator?.call(value) ?? _serverErrors[id];
    if (result != null && !_invalidFields.contains(id)) _invalidFields.add(id);
    return result;
  };

  void fieldChanged(String id) {
    if (_serverErrors.remove(id) != null) setState(() {});
  }

  bool validateForm() {
    _invalidFields.clear();
    final valid = formKey.currentState?.validate() ?? true;
    if (!valid) revealFirstError();
    return valid;
  }

  void revealFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _invalidFields.isEmpty) return;
      final id = _invalidFields.first;
      final target = _anchors[id]?.currentContext;
      if (target == null) return;
      fieldFocus(id).requestFocus();
      unawaited(Scrollable.ensureVisible(target, alignment: .1));
    });
  }

  void mapServerErrors(ApiFailure failure) {
    for (final path in failure.fields) {
      final matches = _aliases.entries.where(
        (entry) =>
            entry.value.contains(path) &&
            _anchors[entry.key]?.currentContext != null,
      );
      // Unqualified server paths can describe either a principal or a fee.
      // Keep ambiguous failures in the form summary instead of guessing.
      if (matches.length == 1) {
        _serverErrors[matches.single.key] = context.l10n.formReviewField;
      }
    }
    if (_serverErrors.isNotEmpty) validateForm();
  }

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
          if (e.status == 409) revisionReviewRequired = true;
          if (!identical(ledger.pendingWrite, request)) request = null;
        });
        if (request == null) mapServerErrors(e);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String actionLabel(String normal) => saving
      ? context.l10n.formSaving
      : request != null
      ? context.l10n.formResolveSave
      : normal;

  List<Widget> feedback({bool showSaving = true, bool showError = true}) => [
    if (validation != null) ...[
      LedgerNotice(
        title: context.l10n.formReviewFields,
        body: validation!,
      ),
      accountingGap,
    ],
    if (request != null && !saving) ...[
      LedgerNotice(
        title: context.l10n.pendingWriteTitle,
        body: context.l10n.formPendingBody,
      ),
      accountingGap,
    ] else if (error != null && showError) ...[
      FailureView(error!),
      accountingGap,
    ],
    if (saving && showSaving) ...[const LedgerLoading(), accountingGap],
  ];

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? context.l10n.fieldRequired : null;

  String? dateText(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return context.l10n.invalidDate;
    }
    final date = DateTime.tryParse(value);
    return date == null || date.toIso8601String().substring(0, 10) != value
        ? context.l10n.invalidDate
        : null;
  }

  String? amountValidator(
    String? value,
    String currency, {
    bool signed = false,
    bool allowZero = false,
    bool optional = false,
    String? maximum,
  }) {
    if (value == null || value.trim().isEmpty) {
      return optional ? null : context.l10n.fieldRequired;
    }
    if (currency.isEmpty) return context.l10n.formChooseCurrencyAccount;
    try {
      final money = LedgerMoney.parse(value, ledger.scale(currency));
      if ((!allowZero && money.units == BigInt.zero) ||
          (!signed && money.units.isNegative)) {
        return context.l10n.formPositiveAmount;
      }
      if (maximum != null &&
          money.units > LedgerMoney.parse(maximum, money.scale).units) {
        return context.l10n.formRefundLimitError;
      }
    } on FormatException {
      return context.l10n.invalidAmount;
    }
    return null;
  }

  Widget selectField({
    required String id,
    required String label,
    required String value,
    required List<Choice> choices,
    required ValueChanged<String>? onChanged,
    bool searchable = true,
    bool readOnly = false,
    String? helperText,
    String? Function(String?)? validator,
    List<String> aliases = const [],
  }) => anchorField(
    id,
    LedgerSelectField(
      key: ValueKey(id),
      label: label,
      value: value,
      choices: choices,
      searchable: searchable,
      readOnly: readOnly,
      helperText: helperText,
      focusNode: fieldFocus(id),
      validator: fieldValidator(id, validator),
      onChanged: frozen || onChanged == null
          ? null
          : (value) {
              fieldChanged(id);
              onChanged(value);
            },
    ),
    aliases: aliases,
  );

  Widget field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    bool money = false,
    bool signed = false,
    bool multiline = false,
    bool date = false,
    bool last = false,
    String? currency,
    String? helperText,
    String? keyName,
    List<String> aliases = const [],
  }) {
    final id = keyName ?? 'field-${controller.hashCode}';
    final scale = currency == null || currency.isEmpty
        ? 0
        : ledger.scale(currency);
    final example = LedgerMoney(BigInt.from(10).pow(scale), scale).decimal;
    final amountHint = signed
        ? context.l10n.formSignedAmountHint
        : context.l10n.formPositiveAmount;
    return anchorField(
      id,
      LedgerTextField(
        inputKey: ValueKey(id),
        label: label,
        controller: controller,
        enabled: !frozen,
        focusNode: fieldFocus(id),
        validator: fieldValidator(id, validator),
        onChanged: (_) => fieldChanged(id),
        monetary: money,
        suffix: date
            ? IconButton(
                tooltip: context.l10n.formChooseDate,
                onPressed: frozen ? null : () => chooseDate(controller, id),
                icon: const Icon(LucideIcons.calendarDays),
              )
            : currency == null || currency.isEmpty
            ? null
            : Text(currency),
        helperText:
            helperText ??
            (date
                ? context.l10n.formDateHint
                : money && currency != null && currency.isNotEmpty
                ? '${context.l10n.formAmountExample} $example $currency. '
                      '$amountHint'
                : null),
        keyboardType: money
            ? TextInputType.numberWithOptions(
                decimal: scale > 0,
                signed: signed,
              )
            : date
            ? TextInputType.datetime
            : multiline
            ? TextInputType.multiline
            : TextInputType.text,
        textInputAction: multiline
            ? TextInputAction.newline
            : last
            ? TextInputAction.done
            : TextInputAction.next,
        maxLines: multiline ? 4 : 1,
      ),
      aliases: aliases,
    );
  }

  Future<void> chooseDate(TextEditingController controller, String id) async {
    final initial = dateText(controller.text) == null
        ? DateTime.parse(controller.text)
        : DateTime.parse(ledger.today);
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: context.l10n.formChooseDate,
    );
    if (!mounted || result == null || frozen) return;
    controller.text =
        '${result.year.toString().padLeft(4, '0')}-'
        '${result.month.toString().padLeft(2, '0')}-'
        '${result.day.toString().padLeft(2, '0')}';
    fieldChanged(id);
  }
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

class _ReferenceSnapshot {
  const _ReferenceSnapshot({
    required this.name,
    required this.archived,
    required this.revision,
    this.kind = '',
    this.currency = '',
    this.parent = '',
  });
  final String name;
  final bool archived;
  final int revision;
  final String kind;
  final String currency;
  final String parent;
}

class _ReferenceEditorState extends LedgerMutationState<ReferenceEditor> {
  final name = TextEditingController();
  final opening = TextEditingController(text: '0');
  final openingDate = TextEditingController();
  bool initialized = false;
  bool recovering = false;
  String kind = 'bank';
  String currency = '';
  String parent = '';
  bool archived = false;
  int revision = 1;
  bool get referenceConflict => revisionReviewRequired && widget.id != null;
  @override
  bool get frozen => super.frozen || recovering;

  @override
  void dispose() {
    name.dispose();
    opening.dispose();
    openingDate.dispose();
    super.dispose();
  }

  _ReferenceSnapshot? snapshot(
    List<AssetAccount> accounts,
    List<LedgerCategory> categories,
    List<LedgerCounterparty> counterparties,
  ) {
    if (widget.kind == 'accounts') {
      final item = accounts.where((v) => v.id == widget.id).firstOrNull;
      if (item != null) {
        return _ReferenceSnapshot(
          name: item.name,
          archived: item.archived,
          revision: item.revision,
          kind: item.kind,
          currency: item.currency,
        );
      }
    } else if (widget.kind == 'categories') {
      final item = categories.where((v) => v.id == widget.id).firstOrNull;
      if (item != null) {
        return _ReferenceSnapshot(
          name: item.name,
          archived: item.archived,
          revision: item.revision,
          kind: item.kind,
          parent: item.parentId ?? '',
        );
      }
    } else {
      final item = counterparties.where((v) => v.id == widget.id).firstOrNull;
      if (item != null) {
        return _ReferenceSnapshot(
          name: item.name,
          archived: item.archived,
          revision: item.revision,
        );
      }
    }
    return null;
  }

  void applySnapshot(_ReferenceSnapshot item, {bool keepDraft = false}) {
    revision = item.revision;
    kind = item.kind;
    currency = item.currency;
    parent = item.parent;
    if (!keepDraft) {
      name.text = item.name;
      archived = item.archived;
    }
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
    final item = snapshot(c.accounts, c.categories, c.counterparties);
    if (item != null) applySnapshot(item);
  }

  Future<void> resolveConflict() async {
    if (frozen) return;
    final scope = ledger.scope;
    setState(() => recovering = true);
    try {
      final latest = snapshot(
        widget.kind == 'accounts'
            ? await ledger.api.accounts(ledger.bookId!)
            : [],
        widget.kind == 'categories'
            ? await ledger.api.categories(ledger.bookId!)
            : [],
        widget.kind == 'counterparties'
            ? await ledger.api.counterparties()
            : [],
      );
      if (!mounted || ledger.scope != scope) return;
      if (latest == null) {
        throw const ApiFailure('${ApiFailure.prefix}not-found', status: 404);
      }
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
              AccountingReviewLine(
                title: context.l10n.formLatestValues,
                value: latest.name,
                subtitle: latest.archived
                    ? context.l10n.archivedLabel
                    : context.l10n.formActive,
              ),
              AccountingReviewLine(
                title: context.l10n.formYourDraft,
                value: name.text,
                subtitle: archived
                    ? context.l10n.archivedLabel
                    : context.l10n.formActive,
              ),
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
      if (!mounted || ledger.scope != scope || keep == null) return;
      setState(() {
        applySnapshot(latest, keepDraft: keep);
        revisionReviewRequired = false;
        error = null;
      });
    } on ApiFailure catch (failure) {
      if (mounted && ledger.scope == scope) {
        ledger.identity.handleFailure(failure);
        if (mounted && ledger.scope == scope) setState(() => error = failure);
      }
    } finally {
      if (mounted) setState(() => recovering = false);
    }
  }

  Future<void> save() async {
    if (saving || recovering) return;
    if (request != null) {
      await perform(request!.method, request!.path, request!.body);
      return;
    }
    if (!validateForm() || referenceConflict) return;
    final creating = widget.id == null;
    final body = <String, dynamic>{'name': name.text.trim()};
    if (!creating) {
      body.addAll({'expected_revision': revision, 'archived': archived});
    } else if (widget.kind == 'accounts') {
      body.addAll({
        'opening_amount': LedgerMoney.parse(
          opening.text.trim().isEmpty ? '0' : opening.text,
          ledger.scale(currency),
        ).decimal,
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
            eagerChildren: true,
            children: [
              if (!initialized) AccountingFeedback(c),
              if (initialized) ...[
                LedgerFormSection(
                  children: [
                    field(
                      switch (widget.kind) {
                        'accounts' => context.l10n.accountName,
                        'categories' => context.l10n.categoryName,
                        _ => context.l10n.counterpartyName,
                      },
                      name,
                      validator: requiredText,
                      keyName: 'reference-name',
                      aliases: const ['name'],
                      last: widget.kind == 'counterparties' || !creating,
                    ),
                    if (widget.kind == 'accounts') ...[
                      if (creating)
                        selectField(
                          id: 'account-kind',
                          label: context.l10n.accountKind,
                          value: kind,
                          searchable: false,
                          choices: [
                            for (final k in ['cash', 'bank', 'wallet', 'other'])
                              Choice(k, accountKind(context, k)),
                          ],
                          onChanged: (v) => setState(() => kind = v),
                          validator: requiredText,
                          aliases: const ['kind'],
                        )
                      else
                        LedgerReadOnlyField(
                          label: context.l10n.accountKind,
                          value: accountKind(context, kind),
                        ),
                      selectField(
                        id: 'account-currency',
                        label: context.l10n.formAccountCurrency,
                        value: currency,
                        readOnly: !creating,
                        helperText: context.l10n.formAccountCurrencyHint,
                        choices: [
                          for (final v in c.currencies)
                            reference?.currencyChoice(v.code, currencyLocale) ??
                                Choice(v.code, v.code),
                        ],
                        onChanged: (v) => setState(() => currency = v),
                        validator: requiredText,
                        aliases: const ['currency'],
                      ),
                    ],
                    if (widget.kind == 'categories') ...[
                      selectField(
                        id: 'category-kind',
                        label: context.l10n.transactionType,
                        value: kind,
                        searchable: false,
                        readOnly: !creating || widget.categoryKind != null,
                        helperText: widget.categoryKind != null
                            ? context.l10n.formCategoryTypeFixed
                            : null,
                        choices: [
                          for (final k in ['expense', 'income'])
                            Choice(k, transactionKind(context, k)),
                        ],
                        onChanged: (v) => setState(() {
                          kind = v;
                          parent = '';
                        }),
                        validator: requiredText,
                        aliases: const ['kind'],
                      ),
                      selectField(
                        id: 'category-parent',
                        label: context.l10n.parentCategory,
                        value: parent,
                        readOnly: !creating,
                        choices: [
                          Choice('', context.l10n.rootCategory),
                          for (final v in c.categories.where(
                            (v) =>
                                (!v.archived || v.id == parent) &&
                                v.kind == kind &&
                                v.parentId == null,
                          ))
                            Choice(
                              v.id,
                              v.label(
                                Localizations.localeOf(context).languageCode,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => parent = v),
                        aliases: const ['parent_id'],
                      ),
                    ],
                  ],
                ),
                if (creating && widget.kind == 'accounts')
                  LedgerFormSection(
                    title: context.l10n.openingBalance,
                    children: [
                      field(
                        context.l10n.openingBalance,
                        opening,
                        money: true,
                        signed: true,
                        currency: currency,
                        keyName: 'opening-amount',
                        helperText: context.l10n.formOpeningHint,
                        validator: (v) => amountValidator(
                          v,
                          currency,
                          signed: true,
                          allowZero: true,
                          optional: true,
                        ),
                        aliases: const ['opening_amount'],
                      ),
                      field(
                        context.l10n.openingDate,
                        openingDate,
                        date: true,
                        last: true,
                        validator: dateText,
                        keyName: 'opening-date',
                        aliases: const ['opening_date', 'occurred_on'],
                      ),
                    ],
                  ),
                if (!creating)
                  LedgerFormSection(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.archiveLabel),
                        subtitle: Text(
                          widget.kind == 'categories'
                              ? context.l10n.categoryArchiveHint
                              : context.l10n.archiveHint,
                        ),
                        value: archived,
                        onChanged: frozen
                            ? null
                            : (v) => setState(() => archived = v),
                      ),
                    ],
                  ),
                ...feedback(
                  showSaving: false,
                  showError: error?.status != 409 || !referenceConflict,
                ),
                if (referenceConflict) ...[
                  LedgerNotice(
                    title: context.l10n.formConflictTitle,
                    body: context.l10n.formConflictBody,
                  ),
                  accountingGap,
                  LedgerAction(
                    key: const ValueKey('reference-review-conflict'),
                    label: context.l10n.formReviewLatest,
                    secondary: true,
                    busy: recovering,
                    onPressed: resolveConflict,
                  ),
                  accountingGap,
                ],
                LedgerAction(
                  key: const ValueKey('save-reference'),
                  label: actionLabel(
                    creating ? title : context.l10n.saveChanges,
                  ),
                  busy: saving,
                  onPressed: recovering || referenceConflict ? null : save,
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
            accountingGap,
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
