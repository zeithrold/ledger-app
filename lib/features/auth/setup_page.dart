import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/identity/device_defaults.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/core/identity/providers.dart';
import 'package:ledger_app/core/reference/choices.dart';
import 'package:ledger_app/core/reference/display_locale.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/choice_select.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';

/// Two steps with a session-scoped draft; the final action writes.
class SetupPage extends ConsumerStatefulWidget {
  /// Creates the personal ledger wizard.
  const SetupPage({super.key});
  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  String? _currency;
  String? _timezone;
  bool _fallback = false;
  int _step = 0;
  final _scroll = ScrollController();

  void _moveTo(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaults = ref.watch(deviceDefaultsProvider);
    final reference = ref.watch(referenceChoicesProvider);
    final identity = ref.watch(identityProvider);
    final locale = ref.watch(localeControllerProvider);
    final currencyLocale = ref.watch(currencyLocaleProvider);
    final language = locale.languageCode == 'zh' ? 'zh' : 'en';
    final l10n = context.l10n;
    final catalog = reference.asData?.value;
    final suggested = defaults.asData?.value;
    if (catalog != null &&
        (suggested != null || defaults.hasError) &&
        _currency == null) {
      _currency = catalog.currencies.containsKey(suggested?.currency)
          ? suggested!.currency
          : 'USD';
      final zones = catalog.timezoneChoices(language);
      _timezone = zones.any((z) => z.value == suggested?.timezone)
          ? suggested!.timezone
          : 'UTC';
      _fallback =
          suggested == null ||
          suggested.usedFallback ||
          _currency != suggested.currency ||
          _timezone != suggested.timezone;
    }
    final busy = identity.saving || identity.signingOut;
    final ready = catalog != null && _currency != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1 && !busy) _moveTo(0);
      },
      child: LedgerPage(
        title: l10n.appTitle,
        maxWidth: LedgerTokens.formWidth,
        controller: _scroll,
        children: [
          Text(
            _step == 0 ? l10n.setupStepOne : l10n.setupStepTwo,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: LedgerTokens.md),
          LinearProgressIndicator(
            value: _step == 0 ? .5 : 1,
            minHeight: LedgerTokens.progressHeight,
          ),
          const SizedBox(height: LedgerTokens.xl),
          Text(
            _step == 0 ? l10n.setupCurrencyTitle : l10n.setupPreferencesTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: LedgerTokens.md),
          Text(
            _step == 0 ? l10n.setupCurrencyBody : l10n.setupPreferencesBody,
          ),
          const SizedBox(height: LedgerTokens.xl),
          if (reference.hasError) ...[
            LedgerNotice(
              title: l10n.loadErrorTitle,
              body: l10n.catalogError,
              isError: true,
              action: LedgerAction(
                label: l10n.retryAction,
                secondary: true,
                onPressed: () => ref.invalidate(referenceChoicesProvider),
              ),
            ),
          ] else if (!ready)
            const LedgerLoading()
          else ...[
            if (_step == 0) ...[
              LedgerGroup(
                children: [
                  ChoiceSelect(
                    key: const ValueKey('base-currency'),
                    label: l10n.currencyLabel,
                    value: _currency!,
                    choices: catalog.currencyChoices(currencyLocale),
                    suggested: suggested?.currency,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => _currency = value),
                  ),
                ],
              ),
              const SizedBox(height: LedgerTokens.lg),
              LedgerNotice(
                title: l10n.setupReviewNotice,
                body: l10n.currencyWarning,
              ),
            ] else ...[
              LedgerGroup(
                children: [
                  ChoiceSelect(
                    key: const ValueKey('setup-language'),
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
                        : (value) => ref
                              .read(localeControllerProvider.notifier)
                              .setLocale(Locale(value)),
                  ),
                  ChoiceSelect(
                    key: const ValueKey('setup-timezone'),
                    label: l10n.timezoneLabel,
                    value: _timezone!,
                    choices: catalog.timezoneChoices(language),
                    suggested: suggested?.timezone,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => _timezone = value),
                  ),
                ],
              ),
              const SizedBox(height: LedgerTokens.xl),
              LedgerSurface(
                child: LedgerReadOnlyField(
                  label: l10n.currencySummary,
                  value: catalog
                      .currencyChoices(currencyLocale)
                      .firstWhere((c) => c.value == _currency)
                      .label,
                ),
              ),
            ],
            if (_fallback) ...[
              const SizedBox(height: LedgerTokens.lg),
              LedgerNotice(
                title: l10n.setupFallbackNotice,
                body:
                    '${l10n.defaultsWarning}\n'
                    '${l10n.currencyLabel}: $_currency\n'
                    '${l10n.timezoneLabel}: $_timezone',
              ),
            ],
          ],
          if (identity.error case final error?) ...[
            const SizedBox(height: LedgerTokens.lg),
            FailureView(error),
          ],
          const SizedBox(height: LedgerTokens.xxl),
          LedgerAction(
            key: ValueKey(_step == 0 ? 'setup-next' : 'create-space'),
            onPressed: !ready || busy
                ? null
                : () async {
                    if (_step == 0) {
                      _moveTo(1);
                      return;
                    }
                    await identity.bootstrap(
                      BootstrapInput(
                        baseCurrency: _currency!,
                        timezone: _timezone!,
                        locale: locale.toLanguageTag(),
                      ),
                    );
                  },
            busy: busy,
            label: _step == 0 ? l10n.nextAction : l10n.startLedgerAction,
          ),
          if (_step == 1) ...[
            const SizedBox(height: LedgerTokens.md),
            TextButton(
              key: const ValueKey('setup-back'),
              onPressed: busy ? null : () => _moveTo(0),
              child: Text(l10n.previousAction),
            ),
          ],
          const SizedBox(height: LedgerTokens.lg),
          TextButton(
            onPressed: busy ? null : identity.signOut,
            child: Text(l10n.signOutAction),
          ),
        ],
      ),
    );
  }
}
