# Localization

## Policy

English is the canonical message language and unsupported-locale fallback. The initial supported locales are `en` and `zh` (Simplified Chinese). Startup resolves the device language preference list against supported locales; users can select English or Simplified Chinese in Settings before or after login. Signed-out choices are process-local; signed-in choices are saved through the preference API and restored with the user context. Sign-out restores the device language and system appearance.

Flutter `gen-l10n` generates `AppLocalizations` from ARB files. `lib/l10n/app_en.arb` is the template and contains English translator descriptions. `app_zh.arb` supplies the Chinese translation. Language option names are intentionally shown in their native language. The application and Material widgets use the same resolved locale, and supported locales are limited to those supplied by the application.

## Adding or changing messages

1. Add a semantic key, English text, and an `@key` description to `app_en.arb`.
2. Add the same key to every translated ARB. Use ICU placeholders/plurals for variable messages instead of concatenating sentence fragments. Declare placeholder metadata in the English template.
3. Run `flutter gen-l10n`; import `package:ledger_app/l10n/l10n.dart` in widgets and read `context.l10n.<key>`.
4. Update tests for the affected text or behavior. Run `just check` and affected device tests.

Do not hardcode authored text in widgets or edit `lib/l10n/generated/` by hand. Resource tests reject missing, empty and obsolete keys; the generator checks message syntax and template metadata. Generated files are versioned and checked for drift in CI. Literal expected messages in tests are intentional assertions, not production message sources.

When adding another language, add its ARB, expose the option in Settings, register the language in iOS bundle localizations, and expand fallback, widget, layout and device acceptance scenarios. Supported locales are generated; do not advertise untranslated languages just because the Flutter SDK supports them.

Theme and locale state are independent. Changing language must not reset the selected theme or current route. Financial inputs use ungrouped decimal strings, and displays use exact BigInt grouping plus an explicit currency code; do not convert money to a double for intl formatting. Business dates remain YYYY-MM-DD. Preset categories use server English/Chinese labels; custom names display verbatim.

## Hosted authentication and reference labels

Currency API models contain only `code` and `minor_units`. Local names and symbols
are loaded from the generated CLDR 48 pack in `assets/reference/currencies/`.
`currencyLocaleProvider` shares one policy across onboarding, account creation and
transaction filters. It keeps requested script/region within a translated UI
language; unsupported UI languages use English reference labels too. Preferences
and bootstrap retain full language/script/region instead of inventing a region.

`CurrencyCatalog` resolves registered bundles through pinned aliases, likely
subtags and main-data parents, retaining script compatibility. The old `zh` tag
selects `zh-Hans`; `zh-TW` selects `zh-Hant`. English is the final product fallback,
followed by the code if an entry is missing. Only the selected and fallback bundles
are loaded. This is currency-name lookup, not a general ICU formatter; Unicode
extensions do not affect name selection.

The pack publishes `en`, `en-CA`, `zh-Hans` and `zh-Hant`. This does not add UI
translations or language choices. CLDR reference names can reflect a region or
script preference while authored UI copy still uses the existing ARBs. Search
includes the code, active name, English name and symbol. Switching language reloads
reference data and preserves form inputs. No amount is converted to floating point.

Export new packs from the backend's pinned generator, then run `just check`, which
verifies pack hashes, the exported contract record and coverage. Add regression
cases for new locale aliases, scripts and parent exceptions when changing the
registered bundles.

Ledger welcome, wizard, Select and error copy lives in ARB resources. Clerk
Account Portal owns its browser copy and localization; Flutter's retired Clerk
form adapter and its `clerk*` resources are removed. Offline currency and city
labels come from licensed Unicode CLDR data; see `assets/reference/README.md`.
