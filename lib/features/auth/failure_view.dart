import 'package:flutter/material.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Localized errors without raw proxy or authentication bodies.
class FailureView extends StatelessWidget {
  /// An application or transport failure.
  const FailureView(this.failure, {this.action, super.key});

  /// Sanitized metadata for this failure.
  final ApiFailure failure;

  /// Recovery belongs to the same region as the failure it resolves.
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch (failure.type) {
      '${ApiFailure.prefix}accounting-conflict' => l10n.accountingConflict,
      'pending-write' => l10n.pendingWriteBody,
      '${ApiFailure.prefix}user-disabled' => l10n.userDisabled,
      '${ApiFailure.prefix}access-denied' => l10n.accessDenied,
      '${ApiFailure.prefix}api-version-unsupported' ||
      '${ApiFailure.prefix}api-major-version-unsupported' ||
      '${ApiFailure.prefix}api-version-required' ||
      '${ApiFailure.prefix}api-version-invalid' => l10n.unsupportedVersion,
      '${ApiFailure.prefix}invalid-request' => l10n.invalidRequest,
      '${ApiFailure.prefix}not-found' => l10n.notFoundError,
      '${ApiFailure.prefix}service-unavailable' => l10n.serviceUnavailable,
      'network-error' => l10n.networkError,
      'authentication-error' => l10n.authenticationError,
      'signout-error' => l10n.signoutError,
      'invalid-response' => l10n.invalidResponse,
      _ when failure.status == 401 => l10n.sessionExpired,
      _ when failure.status == 503 => l10n.serviceUnavailable,
      _ => l10n.genericError,
    };
    final fields = failure.fields
        .map(
          (field) => switch (field) {
            'base_currency' => l10n.currencyLabel,
            'timezone' => l10n.timezoneLabel,
            'locale' => l10n.languageTitle,
            'theme' => l10n.appearanceTitle,
            _ => null,
          },
        )
        .nonNulls
        .toSet();
    return Semantics(
      liveRegion: true,
      child: LedgerGroup(
        children: [
          Padding(
            padding: const EdgeInsets.all(LedgerTokens.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.circleAlert,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: LedgerTokens.md),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          failure.status == 401
                              ? l10n.sessionErrorTitle
                              : l10n.requestErrorTitle,
                          key: const ValueKey('failure-title'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LedgerTokens.md),
                Text(text, key: const ValueKey('failure-message')),
                if (fields.isNotEmpty)
                  Text('${l10n.invalidFieldsLabel}: ${fields.join(', ')}'),
                if (failure.requestId ?? failure.instance
                    case final String reference)
                  ExpansionTile(
                    title: Text(
                      l10n.supportDetailsLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      SelectableText('${l10n.correlationLabel}: $reference'),
                    ],
                  ),
                if (action != null) ...[
                  const SizedBox(height: LedgerTokens.lg),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
