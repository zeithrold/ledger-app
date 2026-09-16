# Testing and quality gates

UI tests are part of feature implementation, not optional follow-up work. New behavior needs tests in the same change; a bug fix needs a regression scenario. Documentation-only edits need relevant document checks, while behavioral, visual and localization edits require the appropriate automated coverage.

## Test layers

| Layer | Required coverage | Dependencies |
| --- | --- | --- |
| Unit/resource | Nontrivial state/data behavior, ARB key completeness | No credentials or services |
| Widget | Rendering, navigation, user actions, state changes, localized empty/error states | Flutter test runner; fake external boundaries |
| Layout | Changed pages in both languages at small viewport / large text | Flutter test runner |
| Device integration | Critical user flows and platform/plugin interactions | A named simulator or device |
| Golden, when appropriate | Deliberate pixel-level visual contracts | Controlled fonts and rendering environment |

Do not assert private implementation details merely to increase test counts. Prefer visible outputs and user interaction. Keep tests deterministic; never read developer `.env.local` files, contact production services, or send real telemetry. Endpoint tests override public AppConfig with fixture values and never use stored endpoint preferences. Use Riverpod overrides and HTTP fakes. Test keys should be semantic and independent of translated text.

## Local quality gate

```sh
just check
```

The pinned Go CLI verifies the currency contract, rejects gate-policy weakening
and skill copies that drifted from the pinned templates, resolves locked
dependencies, generates localization classes, checks formatting and architecture,
runs static analysis and offline tests, and enforces coverage. Generation can
update `lib/l10n/generated`; review and retain those files with the change. CI
additionally rejects committed generation and lockfile drift. The required floors
are 70% full and 90% incremental executable-line coverage, with a complete
handwritten-source inventory. These gates supplement behavioral and native
testing; they do not prove correctness. See [governance](governance.md) for
measurement and review rules.

`just --list` shows the daily surface only: `check`, `changes`, `test`, `lint`,
`fmt` and `arch`. Every other recipe is private, hidden from that list but still
invocable, for example `just test-device`, `just generate-check`, `just ios-smoke`
and `just android-smoke`. New recipes stay private until a daily need is proven.

Native smoke needs an environment that the repository does not create on Android:

```sh
flutter emulators --launch Pixel_10_Pro_XL   # local arm64 AVD, becomes emulator-5554
just android-smoke                          # waits for the device, then runs the smoke
just ios-smoke                              # creates and boots an ephemeral iOS simulator
```

The Android environment is not pinned by this repository: CI boots an x86_64 API
35 emulator through `reactivecircus/android-emulator-runner`, while a local Apple
silicon Mac runs an arm64 image such as API 37. Record which environment a result
came from; a local pass is not a CI pass. Stop the emulator with `adb emu kill`
when platform-tools is on `PATH`.

`flutter pub get --enforce-lockfile` may need network access to the pub host, so the gate is not fully offline on a cold caches. No step requires `.env.local`, a database, a device or credentials. The currency check reads the committed contract record and compares it with the contract revision the transport sends, which is what catches a stale export from the backend.

## Device and build checks

```sh
flutter devices
flutter test integration_test/app_test.dart -d <device-id>
flutter test integration_test/identity_test.dart -d <device-id>
flutter build ios --simulator --debug --no-codesign
flutter build apk --debug
```

For Android Studio installations using Java 25, select a compatible JDK 21 for the Gradle process without changing global Flutter settings:

```sh
JAVA_HOME=/path/to/jdk-21 \
GRADLE_OPTS=-Dorg.gradle.java.home=/path/to/jdk-21 \
flutter build apk --debug
```

The generated Android project uses Gradle 8.14 and NDK 28.2.13676358. Install required SDK components using the official Android SDK manager. A missing or partial NDK, Maven download failure, or unavailable device blocks that check; it is not an application test pass. Never disable TLS validation to resolve a download failure.

Run affected device tests for navigation/localization flow changes and native integrations. Run platform builds when native configuration or dependencies change. A successful build does not establish a successful device run. Real Clerk/Sentry integration requires explicit, separate validation and is not implied by offline tests.

## Endpoint configuration coverage

Cover direct startup, configuration-derived endpoint normalization, missing/invalid configuration disabling networking, read-only Settings display, and rejection of the removed editor route. Exercise both languages on a small screen with large text.

Device acceptance verifies direct startup, read-only endpoint display, theme/language navigation and the same configured address after app/provider scope recreation. It does not certify backend connectivity.

## Delivery evidence

Report passed, failed, blocked and unrun checks separately. Record the environment, commands, results and limitations in `../ledger-manuscript/development-records/` and update its index. Keep run dates and one-off logs out of this repository's maintained guides. Remote CI must not be reported as passed until it actually runs.

## Identity coverage

Offline tests replace `AuthGateway`, HTTP and device defaults. Native gateway
contract tests mock method/event channels, cover cancellation, duplicate starts,
active/pending snapshots, refresh, old-account response rejection and credential
cleanup. Reference tests verify currencies and date-sensitive timezone offsets.
Wizard tests exercise both languages and themes with narrow screens and large
text, searchable selectors, back navigation, final payload and account changes.

`integration_test/identity_test.dart` checks the registered native channel without
credentials, secure-storage cleanup, the real timezone plugin and a fake-session
welcome-to-wizard-to-home flow. Run it and `integration_test/app_test.dart` on iOS
and Android. These tests do not establish real Clerk login, browser callbacks,
revocation or restoration across process termination. Those remain explicit live
acceptance scenarios with a configured test instance.

For native-font layout acceptance, run
`integration_test/onboarding_visual_test.dart` on a simulator or emulator. It
covers both locales and themes. Optional `--dart-define=CAPTURE_VISUALS=true`
captures PNGs into the test process temporary directory; widget-test captures use
test fonts, so native device rendering is the visual acceptance source.

When Flutter discovers an incompatible bundled Android Studio JDK, use a
per-process Gradle override without changing global Flutter settings:

```sh
GRADLE_OPTS=-Dorg.gradle.java.home=/path/to/jdk21 flutter test integration_test/identity_test.dart -d DEVICE_ID
```

## Design regression coverage

`test/ui_design_test.dart` covers the maintained page matrix in
`design-system.md`, semantic radio selection, system-theme changes inside a root
sheet, cancellation without writes, keyboard-constrained selection, tab stacks,
scroll restoration, cached refresh content, action targets, color contrast, Material navigation at 200% text, appearance-sheet
commit/cancel behavior, keyboard focus and reduced motion.
Existing identity and onboarding suites continue to verify save timing, draft
retention and account isolation.

Run native page, keyboard and recovery flows with deterministic boundary fakes:

```sh
flutter test integration_test/ui_refresh_test.dart -d <device-id>
```

To retain screenshots on the host before the device test sandbox is removed:

```sh
LEDGER_VISUAL_OUTPUT=/path/to/manuscript/evidence \
flutter drive --driver=test_driver/visual_driver.dart \
  --target=integration_test/ui_refresh_test.dart -d <device-id> \
  --dart-define=CAPTURE_VISUALS=true
```

The driver defaults to the ignored `build/ui-captures` directory when no output
is supplied. Copy dated evidence to the manuscript repository. These native
captures supplement interaction assertions and must be inspected for typography,
content clipping and component hierarchy. They are not pixel-golden contracts.
Capture mode supports iOS and Android. On Android the fixture converts the
Flutter surface before capture and the integration binding restores it at test
teardown. Captures contain the Flutter surface; OS keyboard and system chrome
need separate device inspection.
This fixture flow does not validate the real hosted authentication service.

## Accounting page refinement

The `phase2_*_refinement_test.dart` suites cover financial content retention,
surface insets, field validation and focus, exact fee and reversal review,
conflict draft recovery, transactional filtering, pagination and child-return
refresh. `design_harness.reveal` completes scheduled caret scrolling before
moving to the next control; `press` asserts that its target is actually hittable.

For native page, large-text, calendar and recovery acceptance, run:

```sh
LEDGER_VISUAL_OUTPUT=/path/to/manuscript/evidence \
flutter drive --driver=test_driver/visual_driver.dart \
  --target=integration_test/phase2_ui_refinement_test.dart -d <device-id> \
  --dart-define=CAPTURE_VISUALS=true
```

This suite includes the authentication/settings visual flows and accounting
pages in both languages and themes. Its financial data and request failures
are deterministic HTTP fixtures. Review both initial and scrolled states,
including selected fees, history, confirmation and partial-load recovery.
The visual matrix does not assert OS keyboard visibility. Its captures contain
Flutter surfaces and cannot establish that a software keyboard was displayed.

The same target also runs `phase2_ui_mutation_test.dart`: account opening, a
transfer with a fee, original-key recovery after a lost response, a refund, a
correction and a reversal. That target can also run independently. These checks
assert native UI transitions and exact outgoing fixture requests; they do not
certify backend balance calculations. The isolated Go/PostgreSQL flow in
`accounting_test.dart` remains a separate integration check.

### Actual OS keyboard acceptance

Run `phase2_keyboard_test.dart` in a separate native test process. It uses the
same deterministic accounting HTTP fixture, opens the amount field by tapping,
and never uses `tester.enterText`, whose synthetic editing values can desynchronize
the real input method state.
A single test checks both languages and themes at 200% text. It requires positive
native keyboard insets, a focused visible amount field above the keyboard,
keyboard dismissal and a platform back event returning to Home. Enable the
simulator or emulator software keyboard; missing keyboard insets fail the test.
No real backend or financial writes are involved.

```sh
LEDGER_VISUAL_OUTPUT=/path/to/manuscript/keyboard-evidence \
LEDGER_NATIVE_CAPTURE_PORT=18765 \
LEDGER_NATIVE_CAPTURE_DEVICE=<device-id> \
LEDGER_NATIVE_CAPTURE_PLATFORM=ios \
flutter drive --driver=test_driver/visual_driver.dart \
  --target=integration_test/phase2_keyboard_test.dart -d <device-id> \
  --dart-define=CAPTURE_VISUALS=true \
  --dart-define=NATIVE_CAPTURE_URL=http://127.0.0.1:18765
```

The driver's optional local capture server saves `*-native.png` using the device
screenshot command while the keyboard remains open. Inspect those files for OS
keyboard appearance and native chrome. Ordinary `*.png` files still contain only
the Flutter surface. Without `NATIVE_CAPTURE_URL`, the strict keyboard-inset and
navigation assertions still run, but OS screenshots are not produced.

For Android, set `LEDGER_NATIVE_CAPTURE_PLATFORM=android` and use `adb reverse`
for the chosen port so the device can reach the driver's loopback server. Set
`LEDGER_ADB` when adb is outside PATH. Remove the reverse mapping after the run.
Use only local ephemeral fixture ports, and close them after the run.

## Action groups and transaction action menu

`test/button_group_test.dart` verifies responsive geometry, label retention,
independent callbacks, disabled/busy state, accessible names and loading values,
RTL order and keyboard activation. It covers both languages and themes at narrow,
large-text and wide sizes. Busy must not move or resize the group.

Run the affected native transaction-detail flows on both platforms:

```sh
LEDGER_VISUAL_OUTPUT=/path/to/manuscript/transaction-actions \
flutter drive --no-pub --driver=test_driver/visual_driver.dart \
  --target=integration_test/button_group_test.dart -d <device-id> \
  --dart-define=CAPTURE_VISUALS=true --dart-define=SENTRY_DSN=
```

The four language/theme cases each exercise 100% and 200% text, capture the action buttons and
grouped bottom sheet, open all five applicable actions and return to the
transaction. Data comes from a deterministic read-only HTTP fixture. These
checks complement the shared component contract in [ui-patterns.md](ui-patterns.md).

`test/transaction_actions_test.dart` covers menu routing, dismissal, duplicate
activation, eligibility, scope changes, refresh blocking, and both locales in
light/dark/system themes at narrow, large-text, landscape and wide sizes.
