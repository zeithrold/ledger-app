import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Material navigation with labels and height that honor system text scaling.
class LedgerNavigation extends StatelessWidget {
  /// Creates the compact, four-destination navigation surface.
  const LedgerNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  /// Active branch index.
  final int selectedIndex;

  /// Switches branches without losing their navigation stacks.
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = theme.textTheme.labelSmall!;
    final labelSize = scaler.scale(labelStyle.fontSize!);
    final labelHeight = labelSize * labelStyle.height!;
    final labels = [
      context.l10n.homeTab,
      context.l10n.transactionsTab,
      context.l10n.accountsTab,
      context.l10n.settingsTitle,
    ];
    final availableWidth = MediaQuery.sizeOf(context).width;
    final widestLabel = labels
        .map((label) {
          final painter = TextPainter(
            text: TextSpan(
              text: label,
              style: labelStyle.copyWith(fontSize: labelSize),
            ),
            textDirection: Directionality.of(context),
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        })
        .reduce(math.max);
    if (widestLabel + LedgerTokens.sm * 2 > availableWidth / 4) {
      final icons = [
        LucideIcons.house,
        LucideIcons.list,
        LucideIcons.wallet,
        LucideIcons.settings,
      ];
      final keys = [
        'home-tab',
        'transactions-tab',
        'accounts-tab',
        'settings-tab',
      ];
      return Material(
        key: const ValueKey('expanded-navigation'),
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Wrap(
            children: [
              for (var i = 0; i < labels.length; i++)
                SizedBox(
                  width: availableWidth / 2,
                  child: Semantics(
                    key: ValueKey(keys[i]),
                    selected: i == selectedIndex,
                    button: true,
                    child: InkWell(
                      onTap: () => onDestinationSelected(i),
                      child: Padding(
                        padding: const EdgeInsets.all(LedgerTokens.sm),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icons[i],
                              color: i == selectedIndex
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            Text(
                              labels[i],
                              textAlign: TextAlign.center,
                              style: labelStyle.copyWith(
                                color: i == selectedIndex
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    // Material 3 clamps destination labels internally. Scale these labels
    // explicitly, then use a unit scaler only within this navigation surface.
    // Tooltips receive the same explicit scaling; content keeps its own scaler.
    return MediaQuery.withNoTextScaling(
      child: Theme(
        data: theme.copyWith(
          navigationBarTheme: theme.navigationBarTheme.copyWith(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => theme.navigationBarTheme.labelTextStyle!
                  .resolve(states)!
                  .copyWith(fontSize: labelSize),
            ),
          ),
          tooltipTheme: theme.tooltipTheme.copyWith(
            textStyle: theme.textTheme.bodySmall!.copyWith(
              fontSize: scaler.scale(theme.textTheme.bodySmall!.fontSize!),
              color: theme.colorScheme.onInverseSurface,
            ),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: NavigationBar(
            height: math.max(
              LedgerTokens.navigationHeight,
              LedgerTokens.xxl +
                  LedgerTokens.xs +
                  labelHeight +
                  LedgerTokens.lg,
            ),
            animationDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : LedgerTokens.feedback,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelPadding: const EdgeInsets.only(top: LedgerTokens.xs),
            destinations: [
              NavigationDestination(
                key: const ValueKey('home-tab'),
                icon: const Icon(LucideIcons.house),
                label: labels[0],
              ),
              NavigationDestination(
                key: const ValueKey('transactions-tab'),
                icon: const Icon(LucideIcons.list),
                label: labels[1],
              ),
              NavigationDestination(
                key: const ValueKey('accounts-tab'),
                icon: const Icon(LucideIcons.wallet),
                label: labels[2],
              ),
              NavigationDestination(
                key: const ValueKey('settings-tab'),
                icon: const Icon(LucideIcons.settings),
                label: labels[3],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
