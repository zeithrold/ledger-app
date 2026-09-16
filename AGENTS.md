# Ledger App engineering rules

## Language and documentation

- Maintain source code, identifiers, comments, README, and durable documentation in English.
- Use English as the canonical UI message source and the fallback app language; initialize display language from the device locale list. Native language names and translated resources are intentional exceptions.
- Put all authored user-visible UI copy in `lib/l10n/app_en.arb` and provide corresponding translations in every supported ARB. Do not hardcode UI copy in widgets; use the generated `AppLocalizations` API.
- Keep reusable architecture, configuration, localization and testing guides in this repository. Write dated development journals, validation results, blockers and retrospectives in the sibling `../ledger-manuscript/development-records/` directory and update its index. Do not put development records in application docs.

## Design and component rules

- Follow the project workflow in [ledger-ui](.agents/skills/ledger-ui/SKILL.md) for UI implementation and audits. Keep reusable component contracts in `docs/ui-patterns.md`; update them when a fix establishes a reusable rule.
- Read `DESIGN.md` and `docs/design-system.md` before UI work. These are the maintained design contract; HTML mockups live only in `../ledger-manuscript/design/` and are historical references.
- Use [beautify-flutter](https://github.com/parasvishwa/beautify-flutter/blob/main/SKILL.md) for Flutter design, UI audits, and redesigns. Read the relevant theme, component, redesign and accessibility references when applying it. This is community guidance, adapted to Ledger's pinned Flutter version and this repository's requirements; it does not authorize dependency upgrades or external installation.
- Keep the restrained neutral, light-first direction with intentional dark/system modes. Use the app-owned palette, typography, spacing, radius and motion tokens; no one-off screen styling.
- Choose controls by behavior: rows for navigation, single-selection controls for preferences, buttons for actions, and labeled searchable selection for catalogs. Keep read-only data visibly distinct from editing.
- Use Flutter Material 3 as the only component foundation, styled through Ledger ThemeData and shared components. Bundle Inter locally and use the independent Lucide icon family. Respect 48-pixel targets, 200% text, keyboard constraints, root modal ownership and platform back navigation.
- Design loading, empty, error, saving and recovery states together. Preserve existing content during refresh and drafts on failure. Never invent financial data or future actions.
- Follow `docs/ui-patterns.md` for component composition. `LedgerGroup` accepts complete padded rows; use `LedgerSurface` or `LedgerFormSection` for text and forms. Never pass bare text, fields or spacers as separate grouped rows.
- Give each gap and inset one owner. Notices and empty content need an explicit surface boundary and content inset; empty summaries retain their width and minimum geometry without fabricated amounts or fixed heights that clip scaled text.
- Group only peer actions on the same object with `LedgerButtonGroup`. A shared `Row` alone is not a reason to group buttons. Preserve primary/secondary hierarchy, keep destructive actions separate, and follow the current Edit + More actions contract for transaction details.
- Business forms use `LedgerTextField` and `LedgerSelectField` with persistent labels, validation and stable field IDs. Keep settings preference rows distinct. Use `LedgerPage.eagerChildren` for forms so offscreen fields remain registered for validation.
- Financial rows must retain title, metadata, amount and currency together at narrow widths and 200% text. Use `LedgerMoneyText` and financial rows; never hide values or reduce the user's text scale to fit.
- Keep saving feedback at the action, pagination recovery at the list footer and field errors next to their fields. Regression tests must assert visible content and recovery, not only absence of layout exceptions.
- Add new user-facing copy to every supported ARB. Verify both languages and themes, narrow/large-text layouts, and relevant native flows. Native Flutter captures, not HTML mockups, are the visual acceptance evidence.

## UI testing is part of implementation

- Every new or changed UI behavior must include appropriate automated tests in the same change. Bug fixes require a regression test that exercises the failing behavior.
- Cover observable behavior: navigation, user actions, state transitions, localization and relevant loading/empty/error states. Exercise both supported languages and small-screen/large-text layouts for layout or copy changes.
- Add unit tests for new nontrivial state/data logic and device integration tests for critical flows or platform/plugin interactions. Use golden tests only when pixel-level appearance is the actual contract; do not replace interaction tests with snapshots.
- Tests must be deterministic and must not use developer credentials, production services or real telemetry. Use provider overrides and fakes at external boundaries.
- Run `just check` before delivery. Run affected device tests when UI flows or platform integrations change. A build is not evidence of a successful device run.
- Report passed, failed, blocked and unrun checks separately. Missing SDKs, credentials, devices or network access are blockers, never silently skipped passes. Remote CI is unverified until it actually runs.
- Do not hand-edit generated localization classes; regenerate them with `flutter gen-l10n` and retain them with the dependency lockfiles in version control. State and models are hand-written: declare providers with `NotifierProvider` or plain `Provider` and keep JSON parsing explicit. Do not add `build_runner`, `riverpod_generator` or `json_serializable`.

## Local configuration and debugging

- Local configuration is never bundled. `.env.local` must not return to `pubspec.yaml` assets: a release artifact must not be able to carry whatever happens to sit in a developer's working tree.
- Start a debug run against a local backend with an explicit file:

  ```sh
  flutter run -d <device-id> --dart-define-from-file=.env.local
  ```

  Keep `.env.local` untracked, and keep `.env.example` limited to empty values and public defaults.
- `--dart-define` always wins over `.env.local`, so a single value can be overridden inline, including `--dart-define=SENTRY_DSN=` to disable reporting.
- `just check` must not require `.env.local` to exist, and no check may read it.
- The contract revision the client sends lives in `ledger_transport.dart` and is verified against the exported pack by the shared `currency --app-check` command. Change it only together with a backend contract revision, and re-export the pack.

## Scope

- Preserve unrelated changes. Do not modify the sibling backend or copy its `.env.local` unless explicitly requested.
- Phase 2 includes Clerk authentication, secure session persistence, personal bootstrap, read-only books, server-backed preferences and manual multi-currency asset accounting. Use the 2026-09-16 contract and exact BigInt amounts. Administrator screens, credit cards/debt, automatic FX, AI imports, new-book creation and offline business-data persistence remain out of scope. Signed-out theme/language choices remain process-local.
- Treat `API_BASE_URL` from AppConfig as the only runtime server source. Settings must display the endpoint read-only; do not add endpoint editing, endpoint setup gates or endpoint preference overrides. Dart Define takes precedence over local debug `.env.local` values. Missing or invalid configuration disables network client creation.

## Mechanical governance and independent review

- Follow `docs/governance.md`; `governance.json` is the machine-readable policy.
- Use `just` and the pinned Go governance CLI. Do not introduce Python or shell
  orchestration. Keep platform-native generated build scripts intact.
- Require 70% full and 90% incremental line coverage with explicit production
  inventory; never hide new files or expand generated-code exclusions.
- Every code change requires an independent architecture subagent review using
  `.agents/skills/ledger-architecture-review/SKILL.md`. Record actionable findings,
  dispositions and evidence bound to the final source fingerprint.
- Use `.agents/skills/ledger-debug/SKILL.md` for reproducible diagnosis and repair.
- Squash reviewed PRs using Conventional Commit titles. Keep unrelated work out
  of the change and distinguish locally passed checks from unrun remote CI.
