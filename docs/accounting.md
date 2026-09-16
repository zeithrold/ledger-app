# Accounting client

The current API date is `2026-09-16`. `LedgerTransport` owns authenticated HTTP,
bounded refresh, request tracing and session isolation for identity and accounting.
The API endpoint remains deployment-controlled and read-only.

`AccountingController` owns the selected book and clears protected state on logout
or session changes. Book changes reset book data and filters; late reads from old
sessions/books cannot repopulate current state. Home recent transactions are
independent of list filters. Refresh preserves existing content and surfaces errors.

`LedgerMoney` stores `BigInt` minor units and a catalog scale. Inputs reject
over-precision, exponents, special values and absolute amounts of `10^18` or more.
Aggregate display can exceed the individual-entry bound. Financial arithmetic
never uses binary floating point. Currency metadata comes from `/currencies`;
both amounts of a transfer remain independently entered decimal strings.

## Writing and correction

All mutations use `PendingLedgerWrite`: a frozen method, path, JSON body and UUID
idempotency key. The transport and explicit timeout retries reuse them. While the
outcome is unknown, editing that request is disabled and another write is blocked.
The pending request remains available across navigation until resolved. Known 4xx
responses allow corrections; 409 explains stale revisions and offers reload.
Business drafts and pending writes live in memory only; this phase has no offline
queue or disk persistence. Process termination ends that in-memory retry context.

An account can post its opening balance atomically. The common entry form handles
income, expense and transfers; refunds start from an original expense. Catalog
selectors search and can open creation forms. Fee capture uses a separate expense
and can choose another account/currency. Confirmation shows source principal,
destination principal, fee and exact net change per account.

Transaction details show typed links, remaining refundable amount, immutable
revisions and original/reversal journals. Selected directly linked fees can be
edited or voided with a principal. Checkboxes default to unselected, and unselected
fees remain explicit in confirmation. The backend owns refund caps, membership,
revision checks and atomicity; the client never writes arbitrary postings.

## Screens and accessibility

Home, Transactions, Accounts and Settings share one selected book. Transactions
support date/account/type/currency/category/counterparty filters, deleted-state
inspection and stable cursor pagination. Account details filter that same ledger.
Category and counterparty maintenance live in Settings. Book creation is absent.

The existing Material 3 tokens, Inter fonts and Lucide icons remain in use.
Financial confirmations use intrinsic-size-safe text controls. Forms scroll with
keyboard insets. Navigation switches to two rows when scaled labels cannot fit.
Translations, light/dark themes, 320px width and 200% text are verified by tests.

## Checks

```sh
just check
```

Start the backend's `TestAccountingDeviceServer` with a fresh temporary
`LEDGER_DEVICE_FIXTURE` path (see its testing guide). Supply the returned URL below;
the Android emulator substitutes `10.0.2.2` for `127.0.0.1`. Keep screenshots outside
the repository.

```sh
LEDGER_VISUAL_OUTPUT=/absolute/manuscript/captures flutter drive --no-pub \
  --driver=test_driver/visual_driver.dart \
  --target=integration_test/accounting_test.dart -d <device-id> \
  --dart-define=ACCOUNTING_TEST_URL=http://127.0.0.1:<port> \
  --dart-define=CAPTURE_VISUALS=true
```

Then run `integration_test/accounting_accessibility_test.dart` against the same
fixture for large text, native keyboard and back navigation. The test waits for
positive native keyboard insets before capturing. Enable the simulator/emulator's
software keyboard when a hardware keyboard is attached, and restore that device
preference afterward. Set `LEDGER_NATIVE_CAPTURE_PLATFORM=ios` or `android`,
`LEDGER_NATIVE_CAPTURE_DEVICE=<device-id>` and
`LEDGER_NATIVE_CAPTURE_PORT=<unused-local-port>` to enable synchronized OS captures
with `simctl` or `adb`. Also pass `--dart-define=NATIVE_CAPTURE_URL=http://127.0.0.1:<port>`
(Android: `10.0.2.2`) to the accessibility test. Its local capture handshake waits
for the OS screenshot before proceeding, so screenshots include the active
keyboard. The driver listens only on host loopback and validates capture names.
`LEDGER_ADB` can specify the SDK's absolute adb path. The creation flow
requires an empty fixture for each platform. Finish the fixture by creating its
`.stop` file. Tests exercise actual HTTP and PostgreSQL with a test-only verifier;
live Clerk authentication, Sentry ingestion and production deployment are separate.
