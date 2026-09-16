# Architecture and quality governance

The public entry point is `just`; its Go bootstrap verifies the pinned shared
`ledger-tool` source bundle and compiles a temporary executable using Go's build
cache. The same
versioned CLI serves the backend and future web client. Each checkout remains
independently usable. Do not introduce Python, shell pipelines, sibling-checkout
runtime dependencies, or a second orchestration framework.

## Tools and ownership

Use Flutter 3.41.7 / Dart 3.11.5, Go 1.26.6 as declared by the shared tool
bundle, and just. Standard `GOTOOLCHAIN=auto` selects/downloads the required
project Go toolchain without replacing the machine-wide installation; `just`
exports `GOTOOLCHAIN=go1.26.6` locally for its commands and version probes.
Offline hosts must provision it first. Android requires JDK 21 and an Android SDK; iOS requires macOS,
Xcode, CocoaPods and a simulator runtime. `just doctor` reports native capability;
unavailable platforms remain explicitly blocked. Windows, Linux and macOS share
the offline/static gate; this does not make iOS builds possible on Windows.

`just bootstrap` resolves the committed lockfile. `just generate` regenerates
localizations. `just fmt` changes formatting; `just lint` only checks it.
`just arch`, `just test`, `just property` and `just check` run the versioned
policy in `governance.json`. Native targets remain explicit:

```sh
just test-device integration_test/button_group_test.dart DEVICE_ID
just capture-ui integration_test/button_group_test.dart DEVICE_ID
```

Keep `test_driver/visual_driver.dart`: it owns integration screenshot callbacks
and the optional local native screenshot server. A native SDK-generated shell
file is not an authored orchestration dependency and must not be removed.

## Required gates

- All authored Dart passes formatting and `dart analyze --fatal-infos`.
- Every production checkout independently requires 70% full line coverage and
  90% changed executable-line coverage against the PR target merge base. A
  docs-only diff has no executable denominator. Missing coverage evidence is
  not a pass. Thresholds only rise; any below-70 migration baseline needs an
  explicit measured floor, owner/reason and expiry no later than 2026-10-16.
- Exclude only generated localization code. The AST source inventory includes
  files never imported by tests, so adding an untested file cannot hide it from
  the denominator. Flutter line coverage is not branch or mutation coverage.
- AST architecture checks reject core-to-presentation dependencies, shared-to-
  feature dependencies, presentation HTTP/storage/IO, composition-root imports,
  and another feature's private implementation. Public feature entrypoints are
  `lib/features/<name>/<name>.dart`. Theme/locale/preferences are existing shared
  foundations; do not add feature behavior there to bypass boundaries.
- Current cross-feature exceptions are individual edges with owner, reason and
  2026-10-16 expiry. Stale or expired entries fail. New exceptions require review;
  broad wildcards are not an alternative to fixing a boundary.
- Deterministic exact-money properties run on each PR. Reproduce a failure with
  its printed seed and sample; preserve a minimal regression example. These are
  bounded property checks, not a claim of coverage-guided fuzzing.
- Device tests cover changed critical flows on Android and iOS. UI changes need
  before/after/diff artifacts for the same scenarios, with base/head revisions,
  device/runtime, locale, theme, viewport and text scale. Use both languages,
  light/dark and 200% text where relevant. Review typography and clipping;
  percentage image differences alone cannot approve a visual change.
- Native keyboard tests must observe actual OS insets. Flutter-surface captures
  do not establish OS keyboard appearance, real authentication or backend writes.

Mutation testing is a separate quality signal for pure logic: preserve
killed/survived/invalid/timeout counts and equivalent-mutant explanations. This
repository configures **no** Dart mutation adapter, so mutation coverage is
**blocked** and recorded as such in the development records; it is never
reported as a score or as a passing gate, and no `just` recipe pretends to run
one. Do not label manually edited examples, random property tests or screenshot
differences as mutation coverage. See the shared governance tool documentation
for the supported adapter.

## Git and independent review

`check` includes the shared `policy-check` ratchet, the `skills-check` comparison
against the pinned skill templates, the `recipes-check` agreement between this
repository's `justfile`, `governance.json` and the workflows, and `security`
commands. Coverage thresholds
and baseline floors cannot decrease against the target revision; source roots
cannot shrink, exclusions cannot be added, baseline expiry cannot extend, and a
gate step or command that existed in the base policy cannot disappear without a
`command_migrations` entry naming an owner, a reason and an expiry within 30
days. Baselines require a start date and at most 30 days.
Gitleaks v8.30.1 scans an isolated source copy with fully redacted findings,
without local environment files. `flutter pub outdated --json` provides advisory
dependency information, including the package service's advisories when present;
it neither proves comprehensive Dart vulnerability coverage nor requires every
available dependency upgrade. Govulncheck is used only by Go repositories.
Network failures remain blocked or failed checks.

Use a short-lived `codex/<topic>` branch and squash each reviewed PR into one
traceable change. Titles use `type(scope): imperative summary`, with
`feat`, `fix`, `refactor`, `test`, `docs`, `build`, `ci` or `chore`; use `!` and a
`BREAKING CHANGE:` footer for incompatible contracts. Link the issue or written
requirement, describe the behavior before/after, and record exact validation
results. Keep generated output with the source change. Do not commit local
configuration, credentials, runtime captures or unrelated edits.

Every code change requires an independent architecture subagent review after
implementation. Give the reviewer the diff, relevant contracts and test evidence,
not a requested conclusion. The reviewer reports severity, source location,
violated boundary, user impact and the smallest actionable repair. The author
fixes findings or records a reasoned disposition. Bind final review evidence to
the current shared-tool fingerprint; any subsequent code edit requires refresh.
An automated rule pass does not establish that independent review occurred.
See the project `ledger-architecture-review` skill for the procedure.

## Reproduce, repair, verify

Use the project `ledger-debug` skill and the shared `debug-start`, `debug-run`,
`debug-verify` and `debug-report` commands. Each session records the named
profile, revision/diff identity, hypothesis and verification result. Process
streams remain on the terminal; deliberately save sanitized additional evidence
when needed. Record environment capability and the regression. Reproduce before editing;
a non-reproducing attempt remains an observation, never proof of a fix.

Use deterministic fakes and an isolated checkout for exploratory mutations.
Do not read `.env.local`, call production, or execute financial writes through
a debug recipe. A request to inspect only never authorizes a repair. Keep durable
rules here and dated results in the manuscript repository. Report passed, failed,
blocked and unrun checks separately, including remote CI and device boundaries.

CI provisions a named iPhone 16 simulator on macOS and an Android API 35 emulator
on Linux for native smoke flows. Missing runtimes fail the job; they are not
silently skipped. These smoke jobs do not replace affected-flow acceptance or
live authentication validation. No remote CI result is established by authoring
a workflow.

The tracked UI evidence descriptor is `.governance/ui.json` (schema version 1).
It binds `base`, `head` and the current `fingerprint`, and contains `captures`
with `scenario`, `device`, `runtime`, `locale`, `theme`, `text_scale`, repository-
relative `before` and `after` PNG paths, and `assertions_passed: true` only after
those assertions ran. `just ui-report .governance/ui.json` creates
`build/ui-report/index.html`, copied PNGs, differences and an output manifest.
Missing before evidence fails rather than treating the new image as its own
baseline. Store only synthetic fixtures in committed evidence.

For a deterministic debug example:

```sh
just debug-start exact-money-roundtrip
# Fill expected, actual, hypotheses and the specific failure_pattern regex in
# build/debug/SESSION/session.json; record any temporary probes in probes.
# Use the session identifier returned by the preceding command.
just debug-run SESSION money
# After a reproduced failure has a regression and authorized repair:
just debug-verify SESSION money
just debug-report SESSION
```

`money` and `architecture` are explicit `debug_profiles` in `governance.json`.
Add a narrowly scoped reproducer profile when needed; do not turn the debug
runner into an unrestricted production shell.
