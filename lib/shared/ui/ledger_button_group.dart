import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/l10n/l10n.dart';

/// An independent action inside a connected group, without selection state.
@immutable
class LedgerButtonGroupAction {
  /// Creates an action; a null callback disables only this action.
  const LedgerButtonGroupAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.key,
  });

  /// Localized visible and accessible action name.
  final String label;

  /// Independent action callback.
  final VoidCallback? onPressed;

  /// Replaces the visible label with progress while retaining its semantics.
  final bool busy;

  /// Stable key for the underlying Material button.
  final Key? key;
}

/// Connected peer actions that stack when their labels cannot fit horizontally.
///
/// Keep primary submission and destructive actions outside this group. The
/// group has no selected state and never changes its geometry because of busy.
class LedgerButtonGroup extends StatelessWidget {
  /// Creates a group in logical reading and keyboard traversal order.
  const LedgerButtonGroup({required this.actions, super.key});

  /// Related actions of equal prominence, in reading order.
  final List<LedgerButtonGroupAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style =
        theme.textButtonTheme.style?.textStyle?.resolve({}) ??
        theme.textTheme.labelLarge;
    final outline = theme.colorScheme.outline;
    final widths = actions.map((action) {
      final painter = TextPainter(
        text: TextSpan(text: action.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = math.max(
        LedgerTokens.target,
        painter.width.ceilToDouble() + LedgerTokens.lg * 2,
      );
      painter.dispose();
      return width;
    }).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimum =
            widths.fold<double>(0, (sum, width) => sum + width) +
            actions.length -
            1;
        final horizontal = minimum <= constraints.maxWidth;
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : minimum;
        final extra = horizontal ? (width - minimum) / actions.length : 0.0;
        final children = <Widget>[];
        for (var i = 0; i < actions.length; i++) {
          if (i > 0) {
            children.add(
              horizontal
                  ? VerticalDivider(width: 1, thickness: 1, color: outline)
                  : Divider(height: 1, thickness: 1, color: outline),
            );
          }
          final action = actions[i];
          final button = Semantics(
            liveRegion: action.busy,
            child: TextButton(
              key: action.key,
              onPressed: action.busy ? null : action.onPressed,
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(
                  Size(LedgerTokens.target, LedgerTokens.target),
                ),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(
                    horizontal: LedgerTokens.lg,
                    vertical: LedgerTokens.md,
                  ),
                ),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Semantics(
                value: action.busy ? context.l10n.loadingLabel : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: action.busy ? 0 : 1,
                      alwaysIncludeSemantics: true,
                      child: Text(action.label, textAlign: TextAlign.center),
                    ),
                    if (action.busy)
                      const SizedBox.square(
                        dimension: LedgerTokens.smallIcon,
                        child: ExcludeSemantics(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          children.add(
            horizontal
                ? SizedBox(width: widths[i] + extra, child: button)
                : button,
          );
        }
        return SizedBox(
          width: width,
          child: Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: LedgerTokens.radius,
              side: BorderSide(color: outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: horizontal
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
          ),
        );
      },
    );
  }
}
