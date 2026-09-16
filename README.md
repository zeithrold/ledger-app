# Ledger App

A Flutter client for Android and iOS that starts in a supported device language, with English fallback. Phase 2 adds exact multi-currency manual accounting to Clerk authentication, personal setup, books and preferences. Missing configuration keeps Settings available and shows a configuration message on protected pages. The API Endpoint is deployment-configured and read-only.

## Quick start

Use Flutter **3.41.7 stable** / Dart **3.11.5**. Android builds require a compatible JDK (21 is recommended); iOS requires Xcode, CocoaPods and a Simulator runtime.

```sh
# First checkout only; preserve an existing .env.local.
cp .env.example .env.local
flutter pub get
flutter gen-l10n
flutter devices
flutter run -d <device-id>
```

The app is named `Ledger`, with Dart package `ledger_app`. Development identifiers are `com.zeithrold.ledger_app` (Android) and `com.zeithrold.ledgerApp` (iOS). Distribution signing and store metadata are not configured.

## Included behavior

- Clerk prebuilt sign-in and sign-up, active-session restoration, secure credential storage, and sign-out.
- Explicit first-time personal-space setup with device-derived currency/timezone suggestions and manual review.
- Home, Transactions, Accounts and Settings share a selected-book context.
- Asset accounts with atomic opening balances, income, expenses and transfers.
- Separate fees, partial refunds, stable transaction links and immutable corrections.
- Per-currency balances and summaries, searchable catalogs and cursor filters.
- Exact BigInt amounts, session-isolated state, and original-key timeout retries.
- Personal context, default book, book list and detail backed by the versioned API.
- Server-backed theme, language and timezone preferences; signed-out display choices last only for the process.
- App-owned neutral light/dark themes, Riverpod state boundaries and persistent tab navigation.
- English and Simplified Chinese for application and Clerk messages, including loading and failure states.
- A single authenticated HTTP boundary with bounded refresh, safe errors, and session-change isolation.
- Optional Sentry initialization with default PII collection disabled.

See [authentication and identity](docs/authentication.md) for state transitions, callback configuration, persistence and testing boundaries.

## Design framework

Read [DESIGN.md](DESIGN.md), the [design system](docs/design-system.md), and the
[page and component contracts](docs/ui-patterns.md) before UI work. Follow the
[engineering rules](AGENTS.md). The application uses Flutter Material 3 with Ledger-owned
theme tokens, responsive page structure, semantic controls, and state
patterns. The earlier HTML study is archived outside the app in
`../ledger-manuscript/design/`; Flutter widgets and their tests are the maintained
implementation and acceptance evidence.

For implementation and review, use the project [ledger-ui skill](.agents/skills/ledger-ui/SKILL.md)
(`$ledger-ui` in an agent that supports project skills). It provides the workflow
and test entry points; component contracts remain in `docs/ui-patterns.md`.

## Public client configuration

Prefer Dart Define for API and Clerk endpoints. Release and profile startup use only Dart Define. Local debug startup can fall back to dotenv.

Copy `.env.example` to `.env.local` once, fill in public client values, then run normally:

```sh
cp .env.example .env.local
# Edit .env.local, then:
flutter run
```

Debug startup loads `.env.local` with `flutter_dotenv`. The file is ignored by Git but bundled
as a Flutter asset, so it must exist before running or building (empty values are
valid). Fresh checkouts and CI need the copy step; `tool/check.sh` creates the
empty template only when `.env.local` is absent and never overwrites an existing file.
Changes require a full restart/rebuild. The existing installed app is unaffected.

Explicit `--dart-define` values override `.env.local`, including an empty value such as
`--dart-define=SENTRY_DSN=` to disable reporting. Supported values:

| Variable | Default | Current behavior |
| --- | --- | --- |
| `API_BASE_URL` | Empty | Read-only runtime API base URL |
| `CLERK_API_ENDPOINT` | Empty | Optional public Clerk origin; must match the host encoded in the publishable key |
| `CLERK_PUBLISHABLE_KEY` | Empty | Initializes Clerk authentication when valid |
| `APP_ENV` | `stage` | `stage`: 100% traces; `production`: 50%; other values fail startup |
| `SENTRY_DSN` | Empty | A non-empty value enables Sentry errors, navigation and HTTP tracing |

```sh
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=CLERK_API_ENDPOINT=https://your-instance.clerk.accounts.dev \
  --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_replace_me
```

Use the same defines with `flutter build` for release builds. You can also pass public values using `--dart-define-from-file=.env.local`. For release builds, use an empty `.env.local` template in a clean checkout: the asset remains bundled even though release startup does not read it.

Both repositories use separate `.env.local` files and `.env.example` templates. Rename any existing App `.env` to `.env.local`; the old filename is no longer loaded. The App Clerk endpoint is public client configuration; the backend `CLERK_API_ENDPOINT` separately targets Clerk’s backend API.

Optionally add `--dart-define=SENTRY_DSN=<client-dsn>`. These values are embedded in the app. Never supply Clerk secret keys, database passwords or other backend secrets, and never copy the backend `.env.local`.

`API_BASE_URL` is the sole runtime server source. Settings displays its normalized value without editing controls. Missing or invalid configuration displays “Not configured” and disables HTTP client creation. Previously saved endpoint preferences are ignored. See [server configuration](docs/server-configuration.md).

## Development

```sh
bash tool/check.sh
# Run actual device acceptance separately:
flutter test integration_test -d <device-id>
```

Every UI behavior change must ship with matching tests. See [engineering rules](AGENTS.md), [testing](docs/testing.md), and [localization](docs/localization.md). CI runs the local quality checks and verifies generated output against checked-in files; device acceptance remains a separate check.

The UI foundation is Flutter Material 3 with app-owned ThemeData, locally bundled Inter fonts and `lucide_icons_flutter` 3.1.19. Authentication remains isolated behind a testable hosted-browser adapter. See `pubspec.yaml` and `pubspec.lock` for the compatible dependency set. No `dependency_overrides` are used. `fl_chart` is retained for a later reporting phase and no widget imports it yet. There is no code generation: state, models and localization-adjacent resources are written by hand, so `build_runner`, `riverpod_generator` and `json_serializable` are deliberately absent.

Retain `pubspec.lock`, `ios/Podfile.lock` and the generated localization classes in version control. Providers are declared by hand with `NotifierProvider` and plain `Provider`, so no `*.g.dart` files are produced or committed, and `analysis_options.yaml` registers no analyzer plugins.

## Layout and boundaries

```text
lib/app/          Application assembly, routing, theme and locale state
lib/core/         Configuration, authentication, identity state and API client
lib/features/     Authentication, first-time setup, books and settings
lib/l10n/         English template, translations and generated localization
lib/main.dart     Optional Sentry initialization and root ProviderScope
test/             Offline behavior and resource tests
integration_test/ Device acceptance tests
tool/             Local quality-check entrypoint
docs/             Durable English development guides
```

The client implements the current `2026-09-16` backend contract. Deploy the matching backend through migration `00004_currency_metadata.sql`. Currency display names come from the versioned local CLDR pack; the API supplies language-neutral accounting metadata. Administrator screens, credit cards/debt, automatic exchange rates, AI imports, new-book creation and offline business-data persistence remain later work.

Dated development and validation records belong in the sibling `ledger-manuscript/development-records/` directory, outside this source repository. Keep this README and `docs/` focused on maintained reference material.

## Sentry tracing

Flutter uses the backend environment policy: `APP_ENV=stage` by default, 100% trace sampling in stage and 50% in production, independent of debug/profile/release mode. Errors use 100% SDK sampling. The environment sampler overrides parent sampling decisions. An empty `SENTRY_DSN` disables SDK initialization. The Flutter project keeps its own DSN.

`SentryWidgetsFlutterBinding`, `SentryWidget`, navigation observers on the root and branch navigators, and `SentryHttpClient` provide framework, route and HTTP instrumentation. Named routes avoid book IDs in transaction names. HTTP child spans require an active transaction; these integrations do not trace every function or every retained-tab activation. Trace headers are restricted to the configured API origin. HTTP breadcrumbs and automatic failed-response issue capture are disabled; request payloads and HTTP span query/fragment fields are removed. Handled API errors remain UI state unless explicitly reported.

For release/profile builds, supply both `APP_ENV` and `SENTRY_DSN` via Dart Define (or a public build configuration file). `.env.local` is only loaded at runtime in debug. Configuration changes require a full restart. Sampling and SDK buffering do not guarantee server acceptance or bypass Sentry quotas.

## Accounting verification

Run `bash tool/check.sh` for generated resources, static checks and tests. See
[accounting](docs/accounting.md) for API and state boundaries, and the native
HTTP/PostgreSQL test commands. Screenshots and dated results live in the sibling
ledger-manuscript directory. Native tests use synthetic authentication against an
isolated database; live Clerk and production deployment remain separate checks.
