// Optional filters share the same explicit currency, category and
// business-date semantics.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/accounting/forms.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/choice_select.dart';
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
    super.dispose();
  }

  Widget choice(String key, String label, List<Choice> choices) => ChoiceSelect(
    label: label,
    value: values[key] ?? '',
    choices: [Choice('', context.l10n.allOption), ...choices],
    onChanged: (v) => setState(() {
      values[key] = v;
    }),
  );
  @override
  Widget build(BuildContext context) {
    final c = ledger;
    final reference = ref.watch(referenceChoicesProvider).value;
    final locale = ref.watch(currencyLocaleProvider);
    return Form(
      key: formKey,
      child: LedgerPage(
        title: context.l10n.filtersTitle,
        leading: accountingBack(context),
        maxWidth: LedgerTokens.formWidth,
        children: [
          ...feedback(),
          field(
            context.l10n.fromDate,
            from,
            validator: (v) => v == null || v.isEmpty ? null : dateText(v),
          ),
          field(
            context.l10n.toDate,
            to,
            validator: (v) => v == null || v.isEmpty ? null : dateText(v),
          ),
          choice('account_id', context.l10n.accountLabel, [
            for (final a in c.accounts)
              Choice(a.id, '${a.name} · ${a.currency}'),
          ]),
          choice('kind', context.l10n.transactionType, [
            for (final k in [
              'income',
              'expense',
              'transfer',
              'refund',
              'opening',
            ])
              Choice(k, transactionKind(context, k)),
          ]),
          choice('currency', context.l10n.currencyLabel, [
            for (final v in c.currencies)
              reference?.currencyChoice(v.code, locale) ??
                  Choice(v.code, v.code),
          ]),
          choice('category_id', context.l10n.categoryLabel, [
            for (final v in c.categories)
              Choice(
                v.id,
                c.categoryName(
                  v.id,
                  Localizations.localeOf(context).languageCode,
                ),
              ),
          ]),
          choice('counterparty_id', context.l10n.counterpartyLabel, [
            for (final v in c.counterparties) Choice(v.id, v.name),
          ]),
          SwitchListTile(
            title: Text(context.l10n.includeDeleted),
            value: values['include_voided'] == 'true',
            onChanged: (v) =>
                setState(() => values['include_voided'] = v ? 'true' : ''),
          ),
          accountingGap,
          LedgerAction(
            label: context.l10n.applyFilters,
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (from.text.isNotEmpty &&
                  to.text.isNotEmpty &&
                  from.text.compareTo(to.text) > 0) {
                setState(() => validation = context.l10n.invalidDate);
                return;
              }
              values['from'] = from.text;
              values['to'] = to.text;
              await c.filter(
                Map.fromEntries(
                  values.entries.where((v) => v.value.isNotEmpty),
                ),
              );
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
    );
  }
}
