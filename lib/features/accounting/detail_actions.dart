part of 'detail.dart';

enum _DetailAction { refund, addFee, link, linkFee }

class _DetailActionButtons extends StatelessWidget {
  const _DetailActionButtons({
    required this.showEdit,
    required this.onEdit,
    required this.onMore,
    super.key,
  });

  final bool showEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final edit = LedgerAction(
      key: const ValueKey('transaction-edit'),
      label: context.l10n.editAction,
      onPressed: onEdit,
    );
    final more = OutlinedButton(
      key: const ValueKey('transaction-more'),
      onPressed: onMore,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              context.l10n.detailMoreActions,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: LedgerTokens.sm),
          const ExcludeSemantics(
            child: Icon(LucideIcons.ellipsis, size: LedgerTokens.icon),
          ),
        ],
      ),
    );
    if (!showEdit) return more;
    return LayoutBuilder(
      builder: (context, constraints) {
        double labelWidth(String label) {
          final painter = TextPainter(
            text: TextSpan(
              text: label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final width = painter.width.ceilToDouble();
          painter.dispose();
          return width;
        }

        final editWidth =
            (labelWidth(context.l10n.editAction) + LedgerTokens.lg * 2).clamp(
              LedgerTokens.target,
              double.infinity,
            );
        final moreWidth =
            labelWidth(context.l10n.detailMoreActions) +
            LedgerTokens.lg * 2 +
            LedgerTokens.sm +
            LedgerTokens.icon;
        final extra =
            (constraints.maxWidth - editWidth - moreWidth - LedgerTokens.md) /
            2;
        final fits = extra >= 0;
        return fits
            ? Row(
                children: [
                  SizedBox(width: editWidth + extra, child: edit),
                  const SizedBox(width: LedgerTokens.md),
                  SizedBox(width: moreWidth + extra, child: more),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  edit,
                  const SizedBox(height: LedgerTokens.md),
                  more,
                ],
              );
      },
    );
  }
}

class _DetailActionSheet extends StatefulWidget {
  const _DetailActionSheet({required this.actions});
  final List<_DetailAction> actions;

  @override
  State<_DetailActionSheet> createState() => _DetailActionSheetState();
}

class _DetailActionSheetState extends State<_DetailActionSheet> {
  bool closing = false;

  void close([_DetailAction? action]) {
    if (closing) return;
    closing = true;
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LedgerTokens.lg,
        vertical: LedgerTokens.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
    Widget item(_DetailAction action) {
      final (key, title, subtitle) = switch (action) {
        _DetailAction.refund => ('transaction-refund', l10n.addRefund, null),
        _DetailAction.addFee => (
          'transaction-add-fee',
          l10n.detailAddFee,
          l10n.detailAddFeeHint,
        ),
        _DetailAction.link => (
          'transaction-link',
          l10n.detailLinkTransaction,
          null,
        ),
        _DetailAction.linkFee => (
          'transaction-link-fee',
          l10n.detailLinkFee,
          l10n.detailMenuLinkFeeHint,
        ),
      };
      return LedgerRow(
        key: ValueKey(key),
        title: title,
        subtitle: subtitle,
        onTap: () => close(action),
      );
    }

    final create = widget.actions.where(
      (a) => a == _DetailAction.refund || a == _DetailAction.addFee,
    );
    final link = widget.actions.where(
      (a) => a == _DetailAction.link || a == _DetailAction.linkFee,
    );
    return SafeArea(
      top: false,
      child: Column(
        key: const ValueKey('transaction-action-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(LedgerTokens.lg),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.detailMoreActions,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-transaction-actions'),
                  tooltip: l10n.detailCloseActions,
                  onPressed: close,
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: LedgerTokens.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (create.isNotEmpty) ...[
                      heading(l10n.detailNewRecords),
                      ...create.map(item),
                    ],
                    if (create.isNotEmpty && link.isNotEmpty)
                      const SizedBox(height: LedgerTokens.xl),
                    if (link.isNotEmpty) ...[
                      heading(l10n.detailLinkExisting),
                      ...link.map(item),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
