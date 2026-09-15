import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/auth/clerk_gateway.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A focused entry into browser-hosted authentication.
class WelcomePage extends ConsumerWidget {
  /// Creates the WelcomePage screen.
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authGatewayProvider);
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => LedgerPage(
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
          const SizedBox(height: LedgerTokens.xxl),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.all(LedgerTokens.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: LedgerTokens.radius,
              ),
              child: Icon(
                LucideIcons.bookOpen,
                size: LedgerTokens.xxl,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: LedgerTokens.xxl),
          Semantics(
            header: true,
            child: Text(
              l10n.welcomeTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: LedgerTokens.lg),
          Text(
            l10n.welcomeBody,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: LedgerTokens.xxxl),
          LedgerAction(
            key: const ValueKey('browser-sign-in'),
            label: auth.signingIn ? l10n.browserSigningIn : l10n.browserSignIn,
            busy: auth.signingIn,
            onPressed: auth.signIn,
          ),
          const SizedBox(height: LedgerTokens.lg),
          Text(
            l10n.browserSignInHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (auth.signInFailed) ...[
            const SizedBox(height: LedgerTokens.lg),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.browserSignInError,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
