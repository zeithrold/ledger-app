/// Semantic surfaces for content, notices, forms and financial information.
library;

// Public pattern options follow the shared design-system contract.
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A content surface owns padding; row groups deliberately do not.
class LedgerSurface extends StatelessWidget {
  const LedgerSurface({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: LedgerTokens.radius,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: LedgerTokens.rowHeight),
      child: Padding(
        padding: const EdgeInsets.all(LedgerTokens.lg),
        child: child,
      ),
    ),
  );
}

class LedgerNotice extends StatelessWidget {
  const LedgerNotice({
    required this.title,
    required this.body,
    this.action,
    this.icon = LucideIcons.info,
    this.isError = false,
    super.key,
  });
  final String title;
  final String body;
  final Widget? action;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: LedgerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  color: isError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: LedgerTokens.md),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: LedgerTokens.sm),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) ...[
            const SizedBox(height: LedgerTokens.lg),
            action!,
          ],
        ],
      ),
    ),
  );
}

/// A form section separates business groups without dividing individual fields.
class LedgerFormSection extends StatelessWidget {
  const LedgerFormSection({required this.children, this.title, super.key});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: LedgerTokens.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Semantics(
            header: true,
            child: Text(title!, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: LedgerTokens.md),
        ],
        LedgerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}

class LedgerMoneyText extends StatelessWidget {
  const LedgerMoneyText(this.value, {this.prominent = false, super.key});
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style:
        (prominent
                ? Theme.of(context).textTheme.headlineSmall
                : Theme.of(context).textTheme.titleMedium)
            ?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
  );
}

/// Financial values always have a full-width line and never replace metadata.
class LedgerFinancialRow extends StatelessWidget {
  const LedgerFinancialRow({
    required this.title,
    required this.value,
    this.subtitle,
    this.secondaryValue,
    this.trailing,
    this.onTap,
    this.enabled = true,
    super.key,
  });
  final String title;
  final String value;
  final String? subtitle;
  final String? secondaryValue;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(LedgerTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              if (onTap != null) ...[
                const SizedBox(width: LedgerTokens.sm),
                const Icon(
                  LucideIcons.chevronRight,
                  size: LedgerTokens.smallIcon,
                ),
              ],
            ],
          ),
          const SizedBox(height: LedgerTokens.sm),
          LedgerMoneyText(value),
          if (secondaryValue != null) LedgerMoneyText(secondaryValue!),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: LedgerTokens.xs),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(height: LedgerTokens.sm),
            Align(alignment: AlignmentDirectional.centerStart, child: trailing),
          ],
        ],
      ),
    );
    return MergeSemantics(
      child: onTap == null
          ? content
          : Semantics(
              button: true,
              enabled: enabled,
              child: InkWell(onTap: enabled ? onTap : null, child: content),
            ),
    );
  }
}
