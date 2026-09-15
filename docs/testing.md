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
bash tool/check.sh
```

The script resolves the locked dependencies, generates ARB and Riverpod code, checks formatting, runs static analysis including Riverpod lint, and runs offline tests with coverage output. Generation can update generated files; review and retain them with the change. CI runs the same command and additionally rejects generated/lockfile drift or untracked generated files. Coverage is diagnostic; the client does not claim an arbitrary coverage percentage as a quality guarantee.

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
