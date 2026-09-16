import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/identity/identity_controller.dart';
import 'package:ledger_app/core/identity/providers.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/accounting/detail.dart';
import 'package:ledger_app/features/accounting/entry_editor.dart';
import 'package:ledger_app/features/accounting/filters.dart';
import 'package:ledger_app/features/accounting/forms.dart';
import 'package:ledger_app/features/accounting/pages.dart';
import 'package:ledger_app/features/auth/session_gate.dart';
import 'package:ledger_app/features/books/books_page.dart';
import 'package:ledger_app/features/home/home_page.dart';
import 'package:ledger_app/features/settings/settings_page.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_navigation.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Owns routing and tab stacks independently of theme rebuilds.
final routerProvider = Provider<GoRouter>((ref) {
  final telemetryEnabled = ref
      .watch(appConfigProvider)
      .sentryDsn
      .trim()
      .isNotEmpty;
  List<NavigatorObserver> observers() => [
    if (telemetryEnabled) SentryNavigatorObserver(),
  ];
  final router = GoRouter(
    observers: observers(),
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: LedgerPage(
          title: context.l10n.appTitle,
          children: [
            LedgerStateView(
              title: context.l10n.pageNotFoundTitle,
              body: context.l10n.pageNotFoundBody,
              action: LedgerAction(
                label: context.l10n.backToHome,
                onPressed: () => context.go('/'),
              ),
            ),
          ],
        ),
      ),
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            observers: observers(),
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(name: 'home', child: HomePage()),
                routes: [
                  GoRoute(
                    path: 'books',
                    builder: (context, state) =>
                        const SessionGate(child: BooksPage()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        name: 'book-detail',
                        builder: (context, state) => SessionGate(
                          child: BookDetailPage(
                            id: state.pathParameters['id']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            observers: observers(),
            routes: [
              GoRoute(
                path: '/transactions',
                name: 'transactions',
                pageBuilder: (context, state) => const NoTransitionPage(
                  name: 'transactions',
                  child: AccountingGate(child: TransactionsPage()),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: observers(),
            routes: [
              GoRoute(
                path: '/accounts',
                name: 'accounts',
                pageBuilder: (context, state) => const NoTransitionPage(
                  name: 'accounts',
                  child: AccountingGate(child: AccountsPage()),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: observers(),
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  name: 'settings',
                  child: SettingsPage(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/entry',
        name: 'transaction-entry',
        builder: (context, state) => AccountingGate(
          fullscreen: true,
          child: EntryEditor(
            key: ValueKey(state.uri.toString()),
            editId: state.uri.queryParameters['edit'],
            originalId: state.uri.queryParameters['original'],
            feeForId: state.uri.queryParameters['fee_for'],
          ),
        ),
      ),
      GoRoute(
        path: '/transaction-filters',
        name: 'transaction-filters',
        builder: (context, state) => const AccountingGate(
          fullscreen: true,
          child: TransactionFiltersPage(),
        ),
      ),
      GoRoute(
        path: '/link-transaction',
        name: 'transaction-link',
        builder: (context, state) => AccountingGate(
          fullscreen: true,
          child: LinkTransactionPage(
            sourceId: state.uri.queryParameters['source'] ?? '',
            kind: state.uri.queryParameters['kind'] ?? 'related',
          ),
        ),
      ),
      GoRoute(
        path: '/transactions/:transactionId',
        name: 'transaction-detail',
        builder: (context, state) => AccountingGate(
          fullscreen: true,
          child: TransactionDetailPage(
            id: state.pathParameters['transactionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/accounts/new',
        name: 'account-create',
        builder: (context, state) => const AccountingGate(
          fullscreen: true,
          child: ReferenceEditor(kind: 'accounts'),
        ),
      ),
      GoRoute(
        path: '/accounts/:accountId/edit',
        name: 'account-edit',
        builder: (context, state) => AccountingGate(
          fullscreen: true,
          child: ReferenceEditor(
            kind: 'accounts',
            id: state.pathParameters['accountId'],
          ),
        ),
      ),
      GoRoute(
        path: '/accounts/:accountId',
        name: 'account-detail',
        builder: (context, state) => AccountingGate(
          fullscreen: true,
          child: AccountDetailPage(id: state.pathParameters['accountId']!),
        ),
      ),
      for (final kind in ['categories', 'counterparties']) ...[
        GoRoute(
          path: '/$kind',
          name: '$kind-list',
          builder: (context, state) => AccountingGate(
            fullscreen: true,
            child: ReferencesPage(kind: kind),
          ),
        ),
        GoRoute(
          path: '/$kind/new',
          name: '$kind-create',
          builder: (context, state) => AccountingGate(
            fullscreen: true,
            child: ReferenceEditor(
              kind: kind,
              categoryKind: state.uri.queryParameters['kind'],
            ),
          ),
        ),
        GoRoute(
          path: '/$kind/:referenceId/edit',
          name: '$kind-edit',
          builder: (context, state) => AccountingGate(
            fullscreen: true,
            child: ReferenceEditor(
              kind: kind,
              id: state.pathParameters['referenceId'],
            ),
          ),
        ),
      ],
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityProvider);
    return ListenableBuilder(
      listenable: identity,
      builder: (context, _) {
        final ready = identity.phase == IdentityPhase.ready;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                ready && constraints.maxWidth >= LedgerTokens.railBreakpoint;
            void navigate(int index) => shell.goBranch(
              index,
              initialLocation: index == shell.currentIndex,
            );
            final body = identity.phase == IdentityPhase.onboarding
                ? const SessionGate(child: SizedBox.shrink())
                : shell;
            return Scaffold(
              resizeToAvoidBottomInset: false,
              bottomNavigationBar: ready && !wide
                  ? LedgerNavigation(
                      selectedIndex: shell.currentIndex,
                      onDestinationSelected: navigate,
                    )
                  : null,
              body: SafeArea(
                child: Row(
                  children: [
                    if (wide) ...[
                      NavigationRail(
                        selectedIndex: shell.currentIndex,
                        onDestinationSelected: navigate,
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(
                              LucideIcons.house,
                              key: ValueKey('home-tab'),
                            ),
                            label: Text(context.l10n.homeTab),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(
                              LucideIcons.list,
                              key: ValueKey('transactions-tab'),
                            ),
                            label: Text(context.l10n.transactionsTab),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(
                              LucideIcons.wallet,
                              key: ValueKey('accounts-tab'),
                            ),
                            label: Text(context.l10n.accountsTab),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(
                              LucideIcons.settings,
                              key: ValueKey('settings-tab'),
                            ),
                            label: Text(context.l10n.settingsTitle),
                          ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(child: body),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
