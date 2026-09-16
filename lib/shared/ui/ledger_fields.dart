/// Form fields share a persistent label and state geometry.
library;

// Public field options follow the shared design-system contract.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';

class LedgerFieldFrame extends StatelessWidget {
  const LedgerFieldFrame({
    required this.label,
    required this.child,
    this.helperText,
    this.errorText,
    super.key,
  });
  final String label;
  final Widget child;
  final String? helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: LedgerTokens.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: LedgerTokens.sm),
        child,
        if (errorText ?? helperText case final String text) ...[
          const SizedBox(height: LedgerTokens.sm),
          Semantics(
            liveRegion: errorText != null,
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: errorText != null
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class LedgerTextField extends StatelessWidget {
  const LedgerTextField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.helperText,
    this.suffix,
    this.inputKey,
    this.monetary = false,
    super.key,
  });
  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? helperText;
  final Widget? suffix;
  final Key? inputKey;
  final bool monetary;

  @override
  Widget build(BuildContext context) => LedgerFieldFrame(
    label: label,
    helperText: helperText,
    child: Semantics(
      label: label,
      child: TextFormField(
        key: inputKey,
        controller: controller,
        validator: validator,
        enabled: enabled,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        style: monetary
            ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              )
            : null,
        decoration: InputDecoration(
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LedgerTokens.sm,
                  ),
                  child: Center(widthFactor: 1, heightFactor: 1, child: suffix),
                ),
          errorMaxLines: 6,
          constraints: const BoxConstraints(minHeight: LedgerTokens.rowHeight),
        ),
      ),
    ),
  );
}

class LedgerReadOnlyField extends StatelessWidget {
  const LedgerReadOnlyField({
    required this.label,
    required this.value,
    this.helperText,
    super.key,
  });
  final String label;
  final String value;
  final String? helperText;

  @override
  Widget build(BuildContext context) => LedgerFieldFrame(
    label: label,
    helperText: helperText,
    child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
  );
}
