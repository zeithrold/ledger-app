// Filter drafts remain local until a complete result set is available.
// ignore_for_file: public_member_api_docs
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/accounting/forms.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

class TransactionFiltersPage extends ConsumerStatefulWidget {
  const TransactionFiltersPage({super.key});
  @override
  ConsumerState<TransactionFiltersPage> createState() =>
      _TransactionFiltersPageState();
}

class _TransactionFiltersPageState
    extends LedgerMutationState<TransactionFiltersPage> {
  final from = TextEditingController();
  final to = TextEditingController();
  final Map<String, String> values = {};
  final GlobalKey _actionAnchor = GlobalKey();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    values.addAll(ledger.filters);
    from.text = values['from'] ?? '';
    to.text = values['to'] ?? '';
  }

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget choice(String key, String label, List<Choice> choices) => selectField(
    id: 'filter-$key',
    label: label,
    value: values[key] ?? '',
    choices: [Choice('', context.l10n.allOption), ...choices],
    searchable: choices.length > 5,
    onChanged: (value) => setState(() => values[key] = value),
  );

  String? optionalDate(String? value) =>
      value == null || value.isEmpty ? null : dateText(value);

  String? endDate(String? value) {
    final error = optionalDate(value);
    if (error != null || value == null || value.isEmpty) return error;
    if (from.text.isNotEmpty &&
        dateText(from.text) == null &&
        from.text.compareTo(value) > 0) {
      return context.l10n.invalidDateRange;
    }
    return null;
  }

  Future<void> apply() async {
    if (saving || !validateForm()) return;
    final c = ledger;
    final scope = c.scope;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    final candidate = Map<String, String>.fromEntries(
      {...values, 'from': from.text, 'to': to.text}.entries.where(
        (entry) => entry.value.isNotEmpty,
      ),
    );
    final applied = await c.filter(candidate);
    if (!mounted || scope != c.scope) return;
    if (applied) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/transactions');
      }
      return;
    }
    setState(() {
      saving = false;
      error = c.filterFailure;
    });
    if (error != null) {
      final dateFailure = error!.fields.any(
        (field) => field == 'from' || field == 'to',
      );
      if (dateFailure) {
        mapServerErrors(error!);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final target = _actionAnchor.currentContext;
          if (target != null) {
            unawaited(Scrollable.ensureVisible(target, alignment: .2));
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ledger;
    final reference = ref.watch(referenceChoicesProvider).value;
    final locale = ref.watch(currencyLocaleProvider);
    final action = LedgerAction(
      key: const ValueKey('apply-transaction-filters'),
      label: context.l10n.applyFilters,
      busy: saving,
      onPressed: apply,
    );
    return Form(
      key: formKey,
      child: LedgerPage(
        title: context.l10n.filtersTitle,
        leading: accountingBack(context),
        controller: _scrollController,
        maxWidth: LedgerTokens.formWidth,
        children: [
          // All fields remain registered even when a later section is visible.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LedgerFormSection(
                title: context.l10n.dateRangeTitle,
                children: [
                  field(
                    context.l10n.fromDate,
                    from,
                    date: true,
                    keyName: 'filter-from',
                    aliases: ['from'],
                    helperText: context.l10n.filterDateFormatHint,
                    validator: optionalDate,
                  ),
                  field(
                    context.l10n.toDate,
                    to,
                    date: true,
                    keyName: 'filter-to',
                    aliases: ['to'],
                    helperText: context.l10n.filterDateFormatHint,
                    validator: endDate,
                    last: true,
                  ),
                ],
              ),
              LedgerFormSection(
                title: context.l10n.transactionConditionsTitle,
                children: [
                  choice('account_id', context.l10n.accountLabel, [
                    for (final account in c.accounts)
                      Choice(
                        account.id,
                        '${account.name} · ${account.currency}',
                        subtitle: account.archived
                            ? context.l10n.archivedLabel
                            : null,
                      ),
                  ]),
                  choice('kind', context.l10n.transactionType, [
                    for (final kind in [
                      'income',
                      'expense',
                      'transfer',
                      'refund',
                      'opening',
                    ])
                      Choice(kind, transactionKind(context, kind)),
                  ]),
                  choice('currency', context.l10n.currencyLabel, [
                    for (final value in c.currencies)
                      reference?.currencyChoice(value.code, locale) ??
                          Choice(value.code, value.code),
                  ]),
                  choice('category_id', context.l10n.categoryLabel, [
                    for (final value in c.categories)
                      Choice(
                        value.id,
                        c.categoryName(
                          value.id,
                          Localizations.localeOf(context).languageCode,
                        ),
                      ),
                  ]),
                  choice('counterparty_id', context.l10n.counterpartyLabel, [
                    for (final value in c.counterparties)
                      Choice(value.id, value.name),
                  ]),
                ],
              ),
              LedgerFormSection(
                title: context.l10n.displayOptionsTitle,
                children: [
                  SwitchListTile(
                    key: const ValueKey('filter-include-voided'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.includeDeleted),
                    value: values['include_voided'] == 'true',
                    onChanged: frozen
                        ? null
                        : (value) => setState(
                            () =>
                                values['include_voided'] = value ? 'true' : '',
                          ),
                  ),
                ],
              ),
              KeyedSubtree(
                key: _actionAnchor,
                child: error == null
                    ? action
                    : FailureView(error!, action: action),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
