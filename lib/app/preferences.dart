import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/core/identity/identity_controller.dart';
import 'package:ledger_app/core/identity/providers.dart';
import 'package:ledger_app/core/reference/display_locale.dart';
import 'package:riverpod/misc.dart';

/// Applies an authenticated preference snapshot to the shell's locale
/// and theme.
///
/// Core hands the snapshot across [PreferenceApplier] instead of importing the
/// shell's controllers.
PreferenceApplier shellPreferenceApplier(Ref ref) => PreferenceApplier(
  apply: (preferences) {
    ref
        .read(localeControllerProvider.notifier)
        .setLanguageTag(preferences.locale);
    ref
        .read(themeModeControllerProvider.notifier)
        .setMode(themeModeOf(preferences.theme));
  },
  reset: () {
    ref.read(localeControllerProvider.notifier).resetToDevice();
    ref.read(themeModeControllerProvider.notifier).setMode(ThemeMode.system);
  },
);

/// Keeps translated reference data on the chosen display language.
///
/// Core defaults [currencyLocaleProvider] to the device language; the shell
/// refines it with the same canonical resolution the interface uses.
String shellCurrencyLocale(Ref ref) =>
    resolveDisplayLocale(ref.watch(localeControllerProvider)).toLanguageTag();

/// The application-level override that installs [shellPreferenceApplier].
final Override shellPreferenceOverride = preferenceApplierProvider.overrideWith(
  shellPreferenceApplier,
);

/// The application-level override that follows the chosen display language.
final Override shellCurrencyLocaleOverride = currencyLocaleProvider
    .overrideWith(
      shellCurrencyLocale,
    );

/// Maps a stored preference value to a Material theme mode.
ThemeMode themeModeOf(String theme) => ThemeMode.values.firstWhere(
  (mode) => mode.name == theme,
  orElse: () => ThemeMode.system,
);
