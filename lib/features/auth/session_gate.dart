import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/identity/identity_controller.dart';
import 'package:ledger_app/core/identity/providers.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/features/auth/setup_page.dart';
import 'package:ledger_app/features/auth/welcome_page.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Protects data while keeping display preferences and recovery accessible.
class SessionGate extends ConsumerWidget {
  /// Creates the SessionGate screen.
  const SessionGate({required this.child, super.key});

  /// Protected content shown only for a ready identity.
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityProvider);
    return ListenableBuilder(
      listenable: identity,
      builder: (context, _) {
        final l10n = context.l10n;
        if (identity.phase == IdentityPhase.ready) {
          return KeyedSubtree(
            key: ValueKey(identity.context!.userId),
            child: child,
          );
        }
        if (identity.phase == IdentityPhase.signedOut) {
          return const WelcomePage();
        }
        if (identity.phase == IdentityPhase.onboarding) {
          return SetupPage(key: ValueKey(identity.auth.sessionKey));
        }
        return LedgerPage(
          title: l10n.appTitle,
          maxWidth: LedgerTokens.formWidth,
          actions: [
            IconButton(
              key: const ValueKey('settings-tab'),
              tooltip: l10n.settingsTitle,
              onPressed: () => context.go('/settings'),
              icon: const Icon(LucideIcons.settings),
            ),
          ],
          children: [
            if (identity.phase == IdentityPhase.configuration)
              LedgerStateView(
                title: l10n.configurationTitle,
                body: l10n.configurationNeeded,
                icon: LucideIcons.wifiOff,
              ),
            if (identity.phase == IdentityPhase.loading ||
                identity.phase == IdentityPhase.authentication) ...[
              const LedgerLoading(),
              const SizedBox(height: LedgerTokens.lg),
              Text(
                identity.signingOut ? l10n.signingOutLabel : l10n.loadingLabel,
              ),
            ],
            if (identity.phase == IdentityPhase.error) ...[
              if (identity.error case final error?)
                FailureView(
                  error,
                  action: LedgerAction(
                    label: l10n.retryAction,
                    onPressed: identity.retry,
                  ),
                ),
            ],
            if (identity.auth.sessionKey != null) ...[
              const SizedBox(height: LedgerTokens.lg),
              TextButton(
                onPressed: identity.signingOut ? null : identity.signOut,
                child: Text(l10n.signOutAction),
              ),
            ],
          ],
        );
      },
    );
  }
}
