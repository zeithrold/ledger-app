import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

export 'ledger_button_group.dart';
export 'ledger_fields.dart';
export 'ledger_patterns.dart';

/// A bounded page with a header that scrolls when its content needs more room.
class LedgerPage extends StatelessWidget {
  /// Creates this shared presentation component.
  const LedgerPage({
    required this.title,
    required this.children,
    this.actions = const [],
    this.leading,
    this.controller,
    this.maxWidth = LedgerTokens.contentWidth,
    this.itemBuilder,
    this.itemCount = 0,
    this.eagerChildren = false,
    this.contentBottomSpacing = LedgerTokens.xl,
    super.key,
  });

  /// Localized heading or primary row text.
  final String title;

  /// Content in reading order.
  final List<Widget> children;

  /// Contextual actions displayed in the page header.
  final List<Widget> actions;

  /// Optional leading icon or back action.
  final Widget? leading;

  /// Optional scroll controller for preserving position.
  final ScrollController? controller;

  /// Maximum readable width.
  final double maxWidth;

  /// Optional lazy data rows rendered after the page's introductory content.
  final IndexedWidgetBuilder? itemBuilder;

  /// Number of lazy data rows, including any pagination control.
  final int itemCount;

  /// Keeps a form's fields registered while scrolling beyond the viewport.
  final bool eagerChildren;

  /// Space after introductory content; lazy-list pages can own this gap.
  final double contentBottomSpacing;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final gutter = LedgerTokens.pageGutter(constraints.maxWidth);
        final titleStyle = Theme.of(context).textTheme.headlineMedium;
        final width = math.min(constraints.maxWidth, maxWidth);
        final titleWidth = math.max<double>(
          1,
          width -
              gutter * 2 -
              (leading == null ? 0 : LedgerTokens.target + LedgerTokens.sm) -
              actions.length * LedgerTokens.target,
        );
        final measure = TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: titleWidth);
        final stackedHeader =
            (leading != null || actions.isNotEmpty) &&
            measure.computeLineMetrics().length > 1;
        if (stackedHeader) measure.layout(maxWidth: width - gutter * 2);
        final scrollHeader =
            (stackedHeader
                    ? measure.height + LedgerTokens.target + LedgerTokens.sm
                    : math.max(measure.height, LedgerTokens.target)) +
                LedgerTokens.lg * 2 >
            constraints.maxHeight * .4;
        measure.dispose();
        final heading = Semantics(
          header: true,
          child: Text(title, style: titleStyle),
        );
        final header = Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            LedgerTokens.lg,
            gutter,
            LedgerTokens.lg,
          ),
          child: stackedHeader
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ?leading,
                        const Spacer(),
                        ...actions,
                      ],
                    ),
                    const SizedBox(height: LedgerTokens.sm),
                    heading,
                  ],
                )
              : Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: LedgerTokens.sm),
                    ],
                    Expanded(child: heading),
                    ...actions,
                  ],
                ),
        );
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!scrollHeader) header,
                Expanded(
                  child: CustomScrollView(
                    controller: controller,
                    slivers: [
                      if (scrollHeader) SliverToBoxAdapter(child: header),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          LedgerTokens.sm,
                          gutter,
                          contentBottomSpacing,
                        ),
                        sliver: eagerChildren
                            ? SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: children,
                                ),
                              )
                            : SliverList.list(children: children),
                      ),
                      if (itemBuilder != null)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            gutter,
                            0,
                            gutter,
                            LedgerTokens.xl,
                          ),
                          sliver: SliverList.builder(
                            itemBuilder: itemBuilder!,
                            itemCount: itemCount,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Actions share busy feedback and a minimum touch target.
class LedgerAction extends StatelessWidget {
  /// Creates this shared presentation component.
  const LedgerAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.secondary = false,
    super.key,
  });

  /// Localized control label.
  final String label;

  /// Action callback; null disables the action.
  final VoidCallback? onPressed;

  /// Whether a request is pending.
  final bool busy;

  /// Whether to use the quieter outlined action style.
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          const SizedBox.square(
            dimension: LedgerTokens.smallIcon,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: LedgerTokens.md),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return Semantics(
      liveRegion: busy,
      child: secondary
          ? OutlinedButton(onPressed: busy ? null : onPressed, child: content)
          : FilledButton(onPressed: busy ? null : onPressed, child: content),
    );
  }
}

/// A semantic section heading and one group boundary.
class LedgerSection extends StatelessWidget {
  /// Creates this shared presentation component.
  const LedgerSection({required this.title, required this.children, super.key});

  /// Localized heading or primary row text.
  final String title;

  /// Content in reading order.
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: LedgerTokens.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: LedgerTokens.md),
        LedgerGroup(children: children),
      ],
    ),
  );
}

/// Grouped rows have one surface and subtle internal separators.
class LedgerGroup extends StatelessWidget {
  /// Creates this shared presentation component.
  const LedgerGroup({required this.children, super.key});

  /// Content in reading order.
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: LedgerTokens.radius,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(),
          children[i],
        ],
      ],
    ),
  );
}

/// Rows wrap long values; navigation is distinct from static information.
class LedgerRow extends StatelessWidget {
  /// Creates this shared presentation component.
  const LedgerRow({
    required this.title,
    this.subtitle,
    this.value,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  /// Localized heading or primary row text.
  final String title;

  /// Optional supporting value; wraps without truncation.
  final String? subtitle;

  /// Current preference value, aligned beside the label when space permits.
  final String? value;

  /// Optional leading icon or back action.
  final Widget? leading;

  /// Optional compact status accessory.
  final Widget? trailing;

  /// Navigation or selection callback; null makes the row read-only.
  final VoidCallback? onTap;

  /// Whether the interactive row accepts input.
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Theme.of(context).textTheme;
        final inlineValue =
            value != null &&
            constraints.maxWidth >= LedgerTokens.preferenceValueBreakpoint &&
            MediaQuery.textScalerOf(context).scale(16) <= 20;
        final stackTrailing = MediaQuery.textScalerOf(context).scale(16) > 20;
        final child = ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LedgerTokens.rowHeight),
          child: Padding(
            padding: const EdgeInsets.all(LedgerTokens.lg),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: LedgerTokens.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: LedgerTokens.xs),
                        Text(
                          subtitle!,
                          style: text.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (value != null && !inlineValue) ...[
                        const SizedBox(height: LedgerTokens.xs),
                        Text(
                          value!,
                          style: text.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (trailing != null && stackTrailing) ...[
                        const SizedBox(height: LedgerTokens.sm),
                        trailing!,
                      ],
                    ],
                  ),
                ),
                if (inlineValue) ...[
                  const SizedBox(width: LedgerTokens.md),
                  Expanded(
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (trailing != null && !stackTrailing) ...[
                  const SizedBox(width: LedgerTokens.sm),
                  trailing!,
                ],
                if (onTap != null) ...[
                  const SizedBox(width: LedgerTokens.sm),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: LedgerTokens.smallIcon,
                  ),
                ],
              ],
            ),
          ),
        );
        return MergeSemantics(
          child: onTap == null
              ? child
              : Semantics(
                  button: true,
                  enabled: enabled,
                  child: _FocusedRow(
                    onTap: enabled ? onTap : null,
                    child: child,
                  ),
                ),
        );
      },
    );
  }
}

class _FocusedRow extends StatefulWidget {
  const _FocusedRow({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;
  @override
  State<_FocusedRow> createState() => _FocusedRowState();
}

class _FocusedRowState extends State<_FocusedRow> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: widget.onTap,
    onFocusChange: (value) => setState(() => focused = value),
    child: Ink(
      decoration: BoxDecoration(
        border: Border.all(
          color: focused
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: widget.child,
    ),
  );
}

/// A subtle badge carries text as well as color.
class LedgerBadge extends StatelessWidget {
  /// Creates this shared presentation component.
  const LedgerBadge(this.label, {super.key});

  /// Localized control label.
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: LedgerTokens.smallRadius,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LedgerTokens.sm,
        vertical: LedgerTokens.xs,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    ),
  );
}

/// Content-shaped loading without a permanently spinning page.
class LedgerLoading extends StatelessWidget {
  /// Creates this shared presentation component.
  const LedgerLoading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: context.l10n.loadingLabel,
    child: ExcludeSemantics(
      child: LedgerGroup(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.all(LedgerTokens.lg),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: i == 0 ? .7 : .45,
                  child: Container(
                    height: LedgerTokens.lg,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: LedgerTokens.smallRadius,
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

/// Informational state with a clear title and an optional recovery action.
class LedgerStateView extends StatelessWidget {
  /// Creates this shared presentation component.
  const LedgerStateView({
    required this.title,
    required this.body,
    this.icon = LucideIcons.info,
    this.action,
    super.key,
  });

  /// Localized heading or primary row text.
  final String title;

  /// Localized explanation.
  final String body;

  /// Supporting icon from the shared icon family.
  final IconData icon;

  /// Optional recovery action.
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: LedgerTokens.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: LedgerTokens.lg),
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: LedgerTokens.sm),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: LedgerTokens.xl),
          action!,
        ],
      ],
    ),
  );
}
