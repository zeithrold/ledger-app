# Ledger UI design system

This is the implementation specification for [DESIGN.md](../DESIGN.md). Values
below are project decisions. They are not claims that Flutter or Material requires
these exact visual dimensions. The current Flutter pages use the app-owned
Material themes described here.

## 1. Information architecture

### Current application

```text
Entry
  Configuration unavailable -> recovery guidance + display settings
  Signed out -> Welcome -> hosted sign-in -> return to app
  New identity -> Base currency -> Language and timezone -> Create space
  Returning identity -> Home / Books

Authenticated shell
  Home -> Month summary / Recent transactions / Transaction entry
  Transactions -> Filters / Detail / Corrections / Relations
  Accounts -> Account detail / Maintenance
  Settings -> Account / Preferences / App information / Sign out

Shared surfaces
  Searchable currency or timezone selector
  Compact language selector
  Inline feedback, loading, empty, permission, and session-expiry states
```

Preserve Home, Transactions, Accounts and Settings and their localized names.
Book detail gets a contextual title and a leading back control.
Opening detail uses a push and must preserve a return path. Indexed tab branches
retain detail stacks and the book-list scroll position. A direct link must still have a safe
Home fallback. Test system back, iOS back swipe, and Android predictive back.

### Capability map

Phase 2 implements manual asset accounting; debt and imports remain future work.

| Capability | Placement and interaction | Gate |
| --- | --- | --- |
| Transaction list and entry | Within the selected book; one visible Add transaction action | Transaction API and amount model ready |
| Accounts and credit cards | Account list and detail; distinguish asset and liability labels | Accounts and balances available |
| Import and reconciliation | Import -> inspect drafts -> resolve required fields -> confirm posting | Draft persistence and confirmation contract ready |
| Transfers and repayments | Dedicated transaction type, source/destination, currency and fee fields | Entry semantics agreed; avoid counting them again as expense |
| Borrowing and lending | Outstanding principal and repayment history | Debt allocation model ready |
| Reporting | Period/filter controls, actual totals, accessible chart alternative | Aggregation and exchange-rate contract ready |

The shell contains Home, Transactions, Accounts and Settings. Scaled labels use
two navigation rows when four columns would clip them. Books select the shared
accounting context. Drafts do not affect balances; totals remain separated by
currency. Actual transfer details show direction, rate and business date.

## 2. Tokens and theme ownership

### Semantic colors

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| canvas | `#F6F7F9` | `#121318` | Screen background |
| surface | `#FFFFFF` | `#1B1D24` | Group, sheet, navigation |
| surfaceRaised | `#ECEEF2` | `#242730` | Hover, inset area, skeleton |
| textPrimary | `#1B1D24` | `#EEF0F4` | Values and titles |
| textSecondary | `#636874` | `#ADB2BF` | Helpful secondary information |
| divider | `#DDE0E6` | `#343946` | Decorative grouping |
| controlBorder | `#7A808E` | `#7E8596` | Required control boundary |
| accent | `#365CCE` | `#9DACFF` | Primary action, link, focus |
| onAccent | `#FFFFFF` | `#182044` | Text on primary action |
| accentSubtle | `#EBEFFE` | `#252E54` | Selected background |
| success (reserved) | `#23734E` | `#80D4AA` | Successful completion |
| warning (reserved) | `#825714` | `#E8BD72` | Review required |
| danger | `#B33A38` | `#F49C98` | Error and destructive operation |

Use foreground/background role pairs. Decorative dividers may be subtle; an input
boundary or focus indicator needs stronger contrast. Income, expense, transfer,
and repayment must be recognizable from text and signs, without relying on color.
Do not make brand blue mean income. Do not use missing data as a zero balance.

### Typography

| Role | Size / line-height | Weight | Example |
| --- | --- | --- | --- |
| Page title | 28 / 1.25 | 600 | Books, Settings |
| Onboarding title | 28 / 1.25 | 600 | Choose your base currency |
| Section title | 18 / 1.4 | 600 | Preferences |
| Row title | 16 / 1.4 | 500 | Main book |
| Body | 16 / 1.5 | 400 | Instructions and explanation |
| Supporting text | 14 / 1.45 | 400 | Base currency, last update |
| Control label | 15 / 1.4 | 500 | Continue |
| Financial emphasis | 32 / 1.2 | 600 | Locale-formatted amount |

Inter 400/500/600/700 ships in local font assets with its OFL license.
Use explicit role styles; use platform CJK fallback and test both locales. Do not force Chinese
tracking to match Latin. Do not use monospaced text for entire screens. Financial
amounts use `FontFeature.tabularFigures()`, explicit currency, locale-aware
formatting, and a precise amount representation agreed with the API. Long names
wrap; only redundant metadata may truncate with an accessible full value.

### Geometry and adaptation

- Compact below 600 logical pixels: one column, bottom navigation, 20-pixel
  horizontal gutters (16 below 360). Minimum control target 48. Standard text
  rows start at 56; rows with supporting content start at 72 and grow naturally.
- Medium 600-839: rail if it improves navigation; center content with max width
  640. Setup forms cap at 520. Use the actual available window width.
- Expanded 840 and above: optional list/detail presentation when meaningful;
  settings and forms still cap at 640/520. This is an adaptive layout requirement,
  not a commitment to a new desktop platform release.
- Related content uses 8-12 gaps, rows use 16 internal spacing, sections use
  24-32 gaps. Use 48 for rare major separations, never to fill missing content.
- Safe areas and keyboard insets are accounted for once at the owning surface.
  Use `LayoutBuilder` constraints for modal height. Never calculate a fixed
  fraction of the entire screen and then independently subtract the keyboard.
- Page surfaces paint the full route canvas to prevent underlying content showing
through platform transitions. Header titles and controls align by vertical center.
Keep ordinary headers visible. If a measured title needs over 40% of the
  available height, it joins the scrolling content. Long book names must not
  consume a fixed header and hide the detail body.
- At large text sizes, allow growth and scrolling. Segments become radio rows.
  A persistent action area may move into scrolling content if space is too small.

### Flutter ownership

Maintained implementation boundaries:

```text
lib/app/theme/ledger_tokens.dart   Spacing, width, radius and motion tokens
lib/app/theme/ledger_theme.dart    Palette, type roles and Material component themes
lib/app/preferences.dart           Locale/theme wiring and the core preference seam
lib/shared/ui/ledger_ui.dart       Pages, actions, groups, rows, badges and states
lib/shared/choice_select.dart     Compact and searchable radio selection
lib/app/router.dart               Persistent tab stacks and adaptive navigation
lib/features/                     Data ownership and page composition
```

Dependency direction: primitives -> semantic theme -> shared components ->
feature pages and application assembly. `lib/core` holds configuration, identity
state, transport and reference data; it must not import `lib/app`, `lib/features`
or `lib/shared`. Core reaches the shell only through narrow seams that it declares
itself and the application overrides at the `ProviderScope`:

- `preferenceApplierProvider` applies an authenticated preference snapshot; the
  application supplies the locale and theme controllers.
- `currencyLocaleProvider` defaults to the device language; the application
  overrides it so translated reference data follows the chosen display language.

Feature pages own data and actions, not colors or component style. Do not create
wrappers that expose every underlying parameter without enforcing a useful
contract. Keep existing identity providers as the state authority.

`LedgerTheme.light` and `LedgerTheme.dark` return complete `ThemeData` values.
Material 3 is the only component foundation. Fonts and Lucide icons are bundled
independently; no Forui widgets, theme bridge or localization delegate remains.
Material and Cupertino SDK localization delegates come from AppLocalizations.

Theme button variants, inputs, radios, navigation, sheets and expansion controls
centrally. Ordinary surfaces use zero elevation and transparent tint. Pressed
backgrounds replace ripples; focus remains visible. In-place feedback is 160 ms;
reduced motion makes app theme, tab indicator and modal changes immediate.
Preserve real platform navigation transitions and text editing behavior.

Compact navigation uses Material NavigationBar with a 72-pixel minimum height.
Labels and tooltip text are explicitly scaled before the navigation-only unit
scaler, bypassing Material's built-in label clamp without restricting page text.
The bar grows with label height and owns its bottom safe area. NavigationRail
begins at 600 pixels; pages remain bounded at 640 and forms at 520.

## 3. Component contracts

Use [UI patterns](ui-patterns.md) for the maintained content, field, financial and
recovery contracts. `LedgerGroup` is for complete rows. `LedgerSurface` and
`LedgerFormSection` own content padding and never divide fields or spacers.

| Pattern | Flutter direction | Contract |
| --- | --- | --- |
| Primary action | `FilledButton` / `OutlinedButton` through `LedgerAction` | One emphasized action where a screen has one; stable label and inline busy indicator; disable duplicate writes |
| Quiet action | Themed icon/text button; outlined `LedgerAction` | Refresh, previous step, and optional supporting actions |
| Book row | `LedgerRow` inside `LedgerGroup` | Title first, currency as metadata, default status badge, chevron; entire row tappable |
| Settings group | `LedgerSection` / labeled `LedgerRow` | One group boundary and separators; no card per field |
| Theme choice | Preference row opening a compact `RadioGroup` / `RadioListTile` sheet | Current mode on the entry row; exactly one checked choice; selecting commits once |
| Language choice | Two radio rows in a content-sized surface | Native language names; no search, no 70%-height empty sheet |
| Currency/timezone | Search field and lazy result list | Current selection visible, recommendation explicit, query retained while open, distinct empty-search state |
| Static information | Label/value row | No tap styling, no chevron; value can wrap or be copied if useful |
| Feedback | Inline state component | Meaningful title, explanation, recovery; correlation ID in expandable support details |

Single-choice sheets use trailing radio controls with checked and mutually
exclusive semantics. `LedgerRow` owns wrapping and target geometry. Preference
values align beside labels at normal phone widths and stack below them on narrow
screens or at large text sizes. Long book names always wrap; the Default badge
moves below the name when necessary. Right-side accessories share an aligned
edge. Timezone entries show the city and UTC offset; full IANA identifiers remain
in the selection list. Read-only rows have no chevrons or ink.

The existing app already commits a choice when its result row is selected.
Preserve this behavior: Cancel/dismiss writes nothing; choosing one row commits
once. Do not add a second Save step without changing the contract and tests.
For remote preferences, indicate saving, retain the previous committed value on
failure, and expose retry. Preserve onboarding draft state and account isolation.

For searchable mobile selectors, use the root navigation overlay when the surface
needs to cover the entire app. Include a title, close control, current/recommended
selection, search field, and lazy scrollable results. Sort the current result
first and the suggested result second. Selecting the current item also closes
the sheet. Search uses a persistent label; an empty result has an announced state.

The sheet uses the root navigator and owns the keyboard inset exactly once.
Its available height comes from constraints. The heading and results share one sliver scroll view. The search field uses a
pinned sliver with an opaque surface, so it stays available while the heading
scrolls away when a keyboard or 200% text reduces space. Timezone rows use the
city as the title and the UTC offset plus IANA identifier as supporting text. Short choices use a content-sized
scrolling sheet. The underlying shell does not also shrink for this keyboard;
inline form screens added later must explicitly define their own inset ownership.
Open selectors observe theme changes instead of keeping captured theme colors.

## 4. Page specifications

### Welcome and authentication return

Use a small recognizable Ledger book mark, one clear heading, a short explanation,
and one sign-in/sign-up action. Replace the oversized generic icon slab. Keep
browser handoff information directly below the action. Signing-in feedback stays
inside the action; cancellation allows retry without presenting a system failure.
Authentication return/loading receives a clear status and recovery when needed.
Clerk's hosted browser UI is outside the Flutter component tree and needs separate
native and browser acceptance.

### First-time setup

Keep the two steps: base currency, then language/timezone review. Use small step
text and a restrained progress indicator. Explain currency immutability next to
the field as a review note. Put Continue/Create personal space in a safe action
area; use a TextButton for Previous, with a quiet sign-out escape. Final review
must show the selected currency, language and timezone before the write. A save
failure retains values, explains what failed, and allows retry.

### Home and books

Home uses a shared book selector, one primary Add transaction action, this-month
income/expense per currency and recent transactions. The first-use empty state
leads to account creation. Transaction rows identify date, type, original amounts
and typed relations; linking never changes totals. Refresh preserves current data.
Book management retains read-only book rows and details; no Create book action is
shown. Accounts and Transactions each retain the selected book and their state.

### Book detail

Leading back control, book name title, Default status when applicable, and a
read-only Base currency row. Use Refresh as a quiet header action. Retry appears
only after a relevant failure. Keep a fallback Home action for direct links with
no back stack. Future transaction content occupies a separate body section.

### Settings

Order: Account -> Preferences -> Book management -> App information -> Support -> Sign out. Display a friendly
name when available; if absent, use a localized account label and put the internal
identifier in support details. Preferences contains appearance, language and timezone. Appearance opens a compact
three-choice sheet; the current mode is visible on its entry row. Base currency is read-only book information, not a preference editor.
Server endpoint remains read-only under App information and wraps long values.
Preserve process-local display preferences while signed out; show timezone only
when a personal identity is available.

## 5. State and interaction matrix

| State | Appearance and action |
| --- | --- |
| Initial load | Stable page scaffold and modest content-shaped placeholders; announce loading |
| Refresh | Keep stale content visible, mark refreshing, preserve scroll position |
| Empty | Specific explanation and an available action; distinguish no books from no search results |
| Error with content | Inline message near the affected region; retry without clearing useful content |
| Error without content | Localized title/body, retry where possible, optional support details |
| Permission denied | Explain unavailable access; return to a safe page; do not present as an empty list |
| Session expired | Preserve a safe return target, clear protected data, offer sign-in |
| Saving | Disable duplicate writes, label progress, keep dimensions stable |
| Saved | Show the new committed value; small transient confirmation only when needed |
| Save failed | Preserve prior committed value and local draft where appropriate; retry |
| Configuration unavailable | App-level recovery guidance and accessible display settings |

Every control defines default, pressed, focused, disabled, and selected states
when applicable. Hover is additional for pointer devices. Error announcements
use semantic live regions; composed rows must not announce their label twice.
No control may be identified only by color. Brand accents and financial status
colors have distinct semantic roles. Reduced motion uses immediate state changes
where needed while keeping information visible.

## 6. Migration sequence and completion gates

1. **Foundation:** tokens, typography, Material component themes, page width and icon
   family. Component interaction tests and native captures prove both themes
   and text scaling.
2. **Interaction safety:** searchable selection under keyboard constraints, radio
   choice semantics, root overlay ownership, detail back navigation.
3. **Current pages:** Home, account/transaction lists, all form branches,
   details/relations/history/confirmations, settings, books and entry states.
   Preserve endpoint, identity, save timing and localization contracts.
4. **Validation:** render and inspect financial entry, fee/refund relations,
   corrections, history, pagination and conflict states against the dated API.
   Credit cards, debt and import components remain specifications.

For every changed behavior, add observable widget tests with fake boundaries and
run `bash tool/check.sh`. Before declaring the migration complete, require:

- English and Simplified Chinese; light, dark, and system modes.
- 390x844 at 100%; 320x568 at 100% and 200%; 360x800 at 130%; 844x390 landscape;
  768x1024 and 1280x800 for width adaptation.
- Keyboard-visible currency/timezone search; long labels; empty query results;
  dismissal; exactly one commit; current selection accessible on open.
- Back navigation from tapped detail and direct link; tab state retention.
- Theme switching both directions while a selector is open, and while preferences
  are saving/failing. No foreground remains from the previous theme.
- Target-size and label guidelines and explicit contrast checks. Before a
  platform release, also perform physical-device VoiceOver/TalkBack acceptance;
  record this separately, because widget and simulator tests cannot prove it.
- Existing-user login bypass, new-user setup, retry, account switching, sign-out
  and protected-state clearing on a native target when these flows change.
- No visible overflow, no essential clipped text, no fabricated financial data,
  and no technical identifiers occupying primary product hierarchy.

## Sources

The audit workflow used the community
[beautify-flutter Skill](https://github.com/parasvishwa/beautify-flutter/blob/main/SKILL.md)
and its theme, redesign, component, anti-pattern and accessibility references.
The [Material Design 3 UI Skill](https://github.com/skydashnet/material-design-3-ui-skill)
was also evaluated for component semantics. Neither is an official Flutter Skill.
Material recipes are adapted to Ledger's restrained brand and pinned Flutter SDK.

Primary references: [Flutter accessibility](https://docs.flutter.dev/ui/accessibility),
[accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing),
[adaptive layout practices](https://docs.flutter.dev/ui/adaptive-responsive/best-practices),
[Material themes](https://api.flutter.dev/flutter/material/ThemeData-class.html), and
[platform adaptations](https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations).
Online API examples can be newer than Ledger's locked dependencies; inspect local
package source before implementation.
