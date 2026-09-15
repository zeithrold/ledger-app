# Authentication and personal identity

## Hosted browser authentication

The Flutter `AuthGateway` boundary exposes initialization, `signIn`, `token`,
`signOut`, session identity and login progress/failure. `ClerkGateway` bridges to
ClerkKit 1.5.4 on iOS and clerk-android-api 1.1.6 on Android. There is no embedded
Clerk form or WebView. The official SDK opens Account Portal with
`startHostedAuth`: ASWebAuthenticationSession on iOS and Custom Tabs on Android.

`ledger/auth` is the method channel. Its methods are `initialize` with the public
key, `signIn`, `token` with a `refresh` boolean, and `signOut`.
`ledger/auth/events` publishes revisioned snapshots with `active`, `userId` and
`sessionId`. Tokens cross the method channel only when requested, and never
appear in event snapshots or application logs. Native SDKs own PKCE, state,
callback redemption, secure persistence, and cache-bypassing token refresh.
The Dart adapter ignores stale revisions and rejects token responses from a
previous session. Only active sessions enter the identity flow.

Cancellation returns to the welcome page without an error. Other failures show
a localized retryable error. A single login can run at a time. If the process
dies during browser authentication, restart the incomplete flow; completed SDK
sessions restore on startup. SDK telemetry is disabled independently of Sentry.

## Platform and Clerk configuration

Minimum versions are iOS 17 and Android API 24. Android builds use Kotlin 2.4.20
and JDK 21 with JVM target 17. Only the core native SDK is linked; native Clerk
UI packages are not used. Swift Package.resolved and pubspec.lock are tracked.

In Clerk Dashboard, enable Native API and register both applications:

| Platform | Application identifier | Hosted-auth callback |
| --- | --- | --- |
| iOS | `com.zeithrold.ledgerApp` | `com.zeithrold.ledgerApp://callback` |
| Android | `com.zeithrold.ledger_app` | `clerk://com.zeithrold.ledger_app.callback` |

These are the SDK defaults. iOS delivers the callback directly to its
ASWebAuthenticationSession. Android's SDK manifest registers its callback
receiver. The retired `ledger-app://auth/callback` handler is removed.
Application identifiers and the production Clerk Native applications entries
must match. Enable desired sign-in/sign-up methods in Clerk. Social providers
use their web flows; production Apple sign-in requires the appropriate Services
ID and web configuration. See [Clerk hosted auth](https://clerk.com/docs/android/guides/account-portal/hosted-auth).

Registration also requires the Apple App ID prefix (normally the Team ID) and
the Android signing certificate SHA-256 fingerprint. Register the certificate
used by the installed build; do not treat a debug fingerprint as production
registration. Store release signing material outside the repository.

Existing installations sign in once after upgrading. Initialization removes only
old `ledger.clerk.` secure-storage entries; it does not migrate credentials or
remove unrelated secrets. New SDK credential storage is authoritative. Android
backup stays disabled and the existing iOS keychain entitlement remains enabled.

## Identity and onboarding

`IdentityController` reads `/me` after authentication or restoration. Only the
full `bootstrap-required` Problem Details type enters the two-step wizard.
Existing identities go directly to the protected application.

Step one selects ledger currency and explains that it cannot currently change.
Step two selects language and timezone, shows the currency summary and submits
`base_currency`, `timezone` and `locale` only after the final action. Draft state
survives step navigation and recoverable failures, but resets on session changes.
Changing language updates the wizard immediately; the submitted codes are `en`
or `zh-CN`. The server's successful response remains authoritative.

Selects open dismissible bottom sheets. Currency and timezone support search;
languages use native labels. Reference data is bundled and documented under
`assets/reference/README.md`. Region and timezone inference is validated against
the catalog once, with a visible USD/UTC fallback. Later device-data updates never
overwrite a draft. Timezone offsets reflect daylight saving at display time.
Settings reuse these selects, preserving previous preferences after save failure;
book base currency is read-only.

## Requests and isolation

API requests retain the existing versioned contract and configured endpoint.
A 401 forces one SDK token refresh and one retry. A persistent 401 means the API rejected authentication; it does not by itself prove session expiration. The backend allows five seconds of token clock skew. Login changes and sign-out
invalidate in-flight identity work and clear account context. Failed sign-out
keeps protected data cleared and offers retry without claiming revocation.
Errors expose only safe localized messages and support correlation metadata.

No backend API, database migration, book naming, financial operations or offline
business persistence is added. Real account login, social-provider callbacks,
revocation and process-restoration acceptance require the intended Clerk instance;
offline fixtures and native compilation do not establish those results.
