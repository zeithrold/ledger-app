// Shared selection behavior for onboarding and remote preferences.
// ignore_for_file: public_member_api_docs
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/app/theme/ledger_theme.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChoiceSelect extends StatelessWidget {
  const ChoiceSelect({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.searchable = true,
    this.suggested,
    this.optionKeyPrefix = 'option',
    super.key,
  });
  final String label;
  final String value;
  final List<Choice> choices;
  final ValueChanged<String>? onChanged;
  final bool searchable;
  final String? suggested;
  final String optionKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final selected = choices
        .where((option) => option.value == value)
        .firstOrNull;
    return LedgerRow(
      title: label,
      value: selected?.displayLabel ?? selected?.label ?? value,
      enabled: onChanged != null,
      onTap: () async {
        final callback = onChanged;
        if (callback == null) return;
        final result = await showModalBottomSheet<String>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          useSafeArea: true,
          sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          builder: (_) => _ChoiceSheet(
            label: label,
            value: value,
            choices: choices,
            searchable: searchable,
            suggested: suggested,
            optionKeyPrefix: optionKeyPrefix,
          ),
        );
        if (result != null && context.mounted) callback(result);
      },
    );
  }
}

class _ChoiceSheet extends ConsumerStatefulWidget {
  const _ChoiceSheet({
    required this.label,
    required this.value,
    required this.choices,
    required this.searchable,
    required this.suggested,
    required this.optionKeyPrefix,
  });
  final String label;
  final String value;
  final List<Choice> choices;
  final bool searchable;
  final String? suggested;
  final String optionKeyPrefix;
  @override
  ConsumerState<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends ConsumerState<_ChoiceSheet> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeControllerProvider);
    final dark =
        mode == ThemeMode.dark ||
        mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final theme = dark ? LedgerTheme.dark : LedgerTheme.light;
    final options =
        widget.choices.where((option) {
          final searchable = [
            option.value,
            option.label,
            option.subtitle ?? '',
            option.search,
          ].join(' ').toLowerCase();
          return searchable.contains(query.trim().toLowerCase());
        }).toList()..sort((a, b) {
          int priority(Choice item) => item.value == widget.value
              ? 0
              : item.value == widget.suggested
              ? 1
              : 2;
          final order = priority(a).compareTo(priority(b));
          return order != 0 ? order : a.value.compareTo(b.value);
        });
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final header = Padding(
            padding: const EdgeInsets.fromLTRB(
              LedgerTokens.gutter,
              LedgerTokens.sm,
              LedgerTokens.sm,
              LedgerTokens.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.cancelAction,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          );
          Widget option(Choice choice) => RadioListTile<String>(
            key: ValueKey('${widget.optionKeyPrefix}-${choice.value}'),
            value: choice.value,
            toggleable: true,
            controlAffinity: ListTileControlAffinity.trailing,
            title: Text(
              choice.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: choice.value == widget.value
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            subtitle:
                choice.subtitle != null ||
                    choice.value == widget.value ||
                    choice.value == widget.suggested
                ? Text(
                    [
                      if (choice.subtitle != null) choice.subtitle!,
                      if (choice.value == widget.value)
                        context.l10n.currentSelectionLabel
                      else if (choice.value == widget.suggested)
                        context.l10n.suggestedSelectionLabel,
                    ].join('\n'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: LedgerTokens.gutter,
              vertical: LedgerTokens.xs,
            ),
            selected: choice.value == widget.value,
          );
          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxHeight = math.min(
                      constraints.maxHeight,
                      widget.searchable
                          ? LedgerTokens.sheetHeight
                          : LedgerTokens.compactSheetHeight,
                    );
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: LedgerTokens.contentWidth,
                        maxHeight: maxHeight,
                      ),
                      child: RadioGroup<String>(
                        groupValue: widget.value,
                        onChanged: (value) {
                          Navigator.pop(context, value ?? widget.value);
                        },
                        child: widget.searchable
                            ? CustomScrollView(
                                key: const ValueKey('choice-results-scroll'),
                                slivers: [
                                  SliverToBoxAdapter(child: header),
                                  PinnedHeaderSliver(
                                    child: ColoredBox(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          LedgerTokens.gutter,
                                          LedgerTokens.lg,
                                          LedgerTokens.gutter,
                                          LedgerTokens.lg,
                                        ),
                                        child: TextField(
                                          key: const ValueKey('choice-search'),
                                          textInputAction:
                                              TextInputAction.search,
                                          decoration: InputDecoration(
                                            labelText:
                                                context.l10n.searchOptions,
                                            prefixIcon: const Icon(
                                              LucideIcons.search,
                                            ),
                                          ),
                                          onChanged: (value) =>
                                              setState(() => query = value),
                                          onSubmitted: (_) =>
                                              FocusScope.of(context).unfocus(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (options.isEmpty)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          LedgerTokens.gutter,
                                        ),
                                        child: Semantics(
                                          liveRegion: true,
                                          child: Text(
                                            context.l10n.noOptionsFound,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    SliverList.builder(
                                      itemCount: options.length,
                                      itemBuilder: (context, index) =>
                                          option(options[index]),
                                    ),
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: LedgerTokens.lg),
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    header,
                                    for (final choice in options)
                                      option(choice),
                                    const SizedBox(height: LedgerTokens.lg),
                                  ],
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
