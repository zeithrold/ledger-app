import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/core/config/api_endpoint.dart';
import 'package:ledger_app/core/identity/identity_controller.dart';
import 'package:ledger_app/core/identity/providers.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/choice_select.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Account information and immediately saved, single-selection preferences.
class SettingsPage extends ConsumerWidget {
  /// Creates the SettingsPage screen.
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endpoint = ref.watch(apiEndpointProvider);
    final selectedMode = ref.watch(themeModeControllerProvider);
    final selectedLocale = ref.watch(localeControllerProvider);
    final l10n = context.l10n;
    final reference = ref.watch(referenceChoicesProvider);
    final language = selectedLocale.languageCode == 'zh' ? 'zh' : 'en';
    final identity = ref.watch(identityProvider);
    return ListenableBuilder(
      listenable: identity,
      builder: (context, _) {
        final personal = identity.context;
        final session = identity.auth.sessionKey;
        final busy = identity.saving || identity.signingOut;
        Future<void> save(Map<String, String> patch) async {
          if (context.mounted && identity.auth.sessionKey == session && !busy) {
            await identity.savePreferences(patch);
          }
        }

        Widget preferenceRow(String field, Widget child) {
          final pending = identity.pendingPreferences?[field];
          var value = pending ?? '';
          if (field == 'theme') {
            value = switch (pending) {
              'dark' => l10n.themeDark,
              'light' => l10n.themeLight,
              _ => l10n.themeSystem,
            };
          } else if (field == 'locale') {
            value = pending == 'zh'
                ? l10n.languageChinese
                : l10n.languageEnglish;
          } else if (field == 'timezone' && pending != null) {
            value =
                reference.asData?.value
                    .timezoneChoices(language)
                    .where((choice) => choice.value == pending)
                    .firstOrNull
                    ?.displayLabel ??
                pending;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              if (pending != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LedgerTokens.lg,
                    0,
                    LedgerTokens.lg,
                    LedgerTokens.lg,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (identity.saving)
                          Text(l10n.savingPreferencesLabel)
                        else ...[
                          Text(
                            l10n.preferencesSaveFailed,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                          const SizedBox(height: LedgerTokens.sm),
                          Text(l10n.preferencesPreviousKept),
                          const SizedBox(height: LedgerTokens.sm),
                          Text('${l10n.preferencesPendingValue}: $value'),
                          const SizedBox(height: LedgerTokens.md),
                          LedgerAction(
                            key: const ValueKey('retry-preferences'),
                            label: l10n.preferencesRetrySave,
                            secondary: true,
                            onPressed: busy ? null : identity.retryPreferences,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        }

        return LedgerPage(
          title: l10n.settingsTitle,
          actions: identity.phase != IdentityPhase.ready
              ? [
                  IconButton(
                    key: const ValueKey('home-tab'),
                    tooltip: l10n.homeTab,
                    onPressed: () => context.go('/'),
                    icon: const Icon(LucideIcons.house),
                  ),
                ]
              : [],
          children: [
            if (personal != null) ...[
              LedgerRow(
                title: personal.displayName.isEmpty
                    ? l10n.personalAccountLabel
                    : personal.displayName,
                subtitle: personal.tenantName,
                leading: const Icon(LucideIcons.userRound),
              ),
              const SizedBox(height: LedgerTokens.lg),
            ],
            if (identity.signingOut) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.signingOutLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: LedgerTokens.sm),
            ],
            if (identity.pendingPreferences == null &&
                identity.error != null) ...[
              FailureView(identity.error!),
              const SizedBox(height: LedgerTokens.lg),
            ],
            LedgerSection(
              title: l10n.preferencesTitle,
              children: [
                preferenceRow(
                  'theme',
                  ChoiceSelect(
                    key: const ValueKey('settings-appearance'),
                    label: l10n.appearanceTitle,
                    value: selectedMode.name,
                    searchable: false,
                    optionKeyPrefix: 'theme',
                    choices: [
                      Choice('system', l10n.themeSystem),
                      Choice('light', l10n.themeLight),
                      Choice('dark', l10n.themeDark),
                    ],
                    onChanged: busy
                        ? null
                        : (value) async {
                            if (!context.mounted ||
                                identity.auth.sessionKey != session ||
                                identity.saving) {
                              return;
                            }
                            if (personal != null) {
                              await save({'theme': value});
                            } else {
                              ref
                                  .read(themeModeControllerProvider.notifier)
                                  .setMode(ThemeMode.values.byName(value));
                            }
                          },
                  ),
                ),
                preferenceRow(
                  'locale',
                  ChoiceSelect(
                    key: const ValueKey('settings-language'),
                    label: l10n.languageTitle,
                    value: language,
                    searchable: false,
                    optionKeyPrefix: 'locale',
                    choices: [
                      Choice('en', l10n.languageEnglish),
                      Choice('zh', l10n.languageChinese),
                    ],
                    onChanged: busy
                        ? null
                        : (value) async {
                            if (!context.mounted ||
                                identity.auth.sessionKey != session ||
                                identity.saving) {
                              return;
                            }
                            if (personal != null) {
                              await save({'locale': value});
                            } else {
                              ref
                                  .read(localeControllerProvider.notifier)
                                  .setLocale(Locale(value));
                            }
                          },
                  ),
                ),
                if (personal != null)
                  if (reference.asData?.value case final catalog?)
                    preferenceRow(
                      'timezone',
                      ChoiceSelect(
                        key: const ValueKey('edit-timezone'),
                        label: l10n.timezoneLabel,
                        value: personal.preferences.timezone,
                        choices: catalog.timezoneChoices(language),
                        onChanged: busy
                            ? null
                            : (value) => save({'timezone': value}),
                      ),
                    )
                  else if (reference.hasError)
                    LedgerRow(
                      title: l10n.catalogError,
                      onTap: () => ref.invalidate(referenceChoicesProvider),
                    )
                  else
                    const LedgerLoading(),
              ],
            ),
            if (personal != null)
              LedgerSection(
                title: l10n.bookManagement,
                children: [
                  LedgerRow(
                    title: l10n.booksTitle,
                    onTap: () => context.push('/books'),
                  ),
                  LedgerRow(
                    title: l10n.categoriesTitle,
                    onTap: () => context.push('/categories'),
                  ),
                  LedgerRow(
                    title: l10n.counterpartiesTitle,
                    onTap: () => context.push('/counterparties'),
                  ),
                ],
              ),
            LedgerSection(
              title: l10n.appInformationTitle,
              children: [
                LedgerRow(
                  key: const ValueKey('current-endpoint'),
                  title: l10n.serverTitle,
                  subtitle: endpoint?.toString() ?? l10n.endpointUnavailable,
                ),
                if (personal != null)
                  LedgerRow(
                    title: l10n.currencyLabel,
                    subtitle: personal.defaultBook.baseCurrency,
                  ),
              ],
            ),
            if (personal != null)
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: LedgerTokens.lg,
                ),
                title: Text(
                  l10n.supportDetailsLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                children: [
                  LedgerRow(
                    title: l10n.identityLabel,
                    subtitle: personal.userId,
                  ),
                ],
              ),
            if (identity.auth.sessionKey != null) ...[
              const SizedBox(height: LedgerTokens.lg),
              TextButton(
                key: const ValueKey('sign-out'),
                onPressed: busy ? null : identity.signOut,
                child: Text(l10n.signOutAction),
              ),
            ],
          ],
        );
      },
    );
  }
}
