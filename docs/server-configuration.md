# Server configuration

## Read-only endpoint

The app opens directly without server setup. Settings displays the normalized API Endpoint from `AppConfig.apiBaseUrl` as plain text, with no editor or save action. The old `/settings/endpoint` route is removed. Missing or invalid configuration displays a localized “Not configured” state; the shell remains accessible and network client creation fails.

`API_BASE_URL` is supplied through Dart Define. Local debug runs can fall back to the App's `.env.local`; explicit defines, including empty ones, take precedence. Release/profile startup only reads Dart Define. Changes require restart/rebuild. Legacy `ledger.api_endpoint` preferences are no longer read or written and cannot override deployment configuration.

## Address rules

- Require an absolute `http://` or `https://` URL with a host and a valid port when specified.
- Trim outer whitespace; reject embedded whitespace, backslashes, URL credentials, query parameters, and fragments.
- Permit local hosts, IP addresses and reverse-proxy base paths.
- Normalize path dot segments and trailing slashes; use a trailing slash, for example `https://ledger.example.com/proxy/`.

The address is a server base URL, not a single resource URL. Parsing performs syntax validation only. It does not contact `/healthz`, authenticate, or verify reachability. HTTP is accepted for development; native transport policies still apply for network requests. No blanket transport-security exception is introduced by this feature.

## Runtime consumers and testing

`apiEndpointProvider` derives a validated URI from `appConfigProvider`. HTTP consumers use this URI. `httpClientProvider` is lazy, rejects missing/invalid configuration, and closes its client when disposed or configuration is replaced in tests. Once authentication has an active session, the identity controller requests `/api/v1/me`; it never bootstraps without explicit user confirmation. All business requests preserve the configured base path and add the pinned date-version header.

Offline and device tests override public AppConfig with fixture values. Cover direct startup, read-only display, missing configuration, removed editor routes, and both languages at small viewport/large text sizes. No developer configuration, preferences or live services are needed.

## Clerk frontend configuration

`CLERK_PUBLISHABLE_KEY` identifies the Clerk frontend instance. The pinned SDK derives its HTTPS host from this key. `CLERK_API_ENDPOINT` is optional and, when supplied, must equal that origin (an optional trailing slash is accepted). It cannot override the SDK host and must not point at the Clerk backend API. An invalid/mismatched configuration disables authentication rather than making a request to an unintended instance.

Register the iOS and Android applications in Clerk Native applications. Hosted login uses the official native SDK callback defaults documented in [authentication](authentication.md); the retired Flutter callback scheme is no longer used.
