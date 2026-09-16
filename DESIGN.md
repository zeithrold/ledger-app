# Ledger design contract

Status: standing design contract for the Flutter implementation. The user selected a restrained, refined
direction with neutral surfaces, limited brand color, and emphasis on books and
financial information.

## Product character

Ledger is a personal finance utility for Android and iOS. It should feel clear,
quiet, precise, and dependable. Familiar controls and readable content take
priority over decorative composition. Use light mode as the primary review
canvas, with equally intentional dark and system modes.

The main action is recording a transaction in the selected book. Before an
account exists, guide the user to create one. First-time setup has a separate
primary action: reviewing preferences and creating the personal space.

Design dials: variance 3/10, motion 2/10, density 5/10. These are design choices,
not quality scores. Onboarding may have more space, but uses the same components.

## Foundation decisions

- Use Flutter Material 3 as the only component foundation. Ledger owns ThemeData,
  semantic colors, text roles and component states. Keep the pinned Flutter version.
- Use neutral surfaces with a restrained blue accent: `#365CCE` in light mode,
  `#9DACFF` in dark mode. Reserve it for primary actions, selection, and focus.
- Retain Inter for Latin text; use platform CJK fallbacks. Define a single type
  scale owned by Ledger. Financial values use tabular figures.
- Use the spacing scale `4, 8, 12, 16, 20, 24, 32, 48` logical pixels. Default
  compact screen gutter: 20; small screens below 360: 16.
- Use radii 8 for small controls, 12 for buttons/groups, and 24 for modal sheets.
  Use borders and surface contrast for grouping; keep ordinary data rows flat.
- Use one Lucide icon family through `lucide_icons_flutter`. Standard glyphs are 22 pixels, with 18-pixel accessories;
  interactive targets have a minimum 48 by 48 logical pixels.
- Short in-place feedback: 160 ms. Preserve platform route transitions, focus,
  back gestures, and reduced-motion preferences. No entrance choreography.
- Keep English as canonical UI copy with matching Simplified Chinese resources.

## Component language

| Intent | Ledger pattern |
| --- | --- |
| Perform an action | Primary, secondary, or quiet action button |
| Open a book or detail | Leading icon, title, metadata, trailing chevron in a row |
| Choose one of 2-3 options | Radio group, or segments only when all labels fit |
| Choose from many options | Labeled field opening a searchable selection surface |
| Display a fixed value | Read-only information row without a chevron |
| Change a boolean | Switch with a persistent label |
| Explain an error | Inline state with a useful recovery action |
| Show a larger independent summary | Summary surface; never a card around every row |

Selected state is not a primary action. Refresh is a secondary operation. Sign
out belongs at the end of account settings. Technical support information belongs
under a low-emphasis, read-only section.

## Scope and acceptance

Phase 2 has Home, Transactions, Accounts and Settings with a shared selected book.
Home shows per-currency monthly totals, recent transactions and one primary entry
action. Account creation includes an optional opening balance. Income, expense,
transfer, refund and fee entry share form patterns. Confirmations separate both
principals, independent fees and each account's net change. Corrections and voids
retain history and explicitly select affected fees, defaulting to none.

Use BigInt amounts with catalog precision. Preserve inputs on failure and original
idempotency keys on ambiguous retries; clear financial state on session changes.
Use two navigation rows when scaled labels cannot fit in one row. Base currencies,
account currencies and the deployed endpoint remain immutable in their respective
maintenance screens. Do not introduce fictional financial data.

Every migrated screen must pass the matrix and state checklist in
[the design system](docs/design-system.md). A preview is a design reference, not
evidence that the Flutter implementation or native device behavior has passed.

## References and decision record

- [Detailed design system and rollout](docs/design-system.md)
- [Page, field and financial component contracts](docs/ui-patterns.md)
- [Community audit method: beautify-flutter](https://github.com/parasvishwa/beautify-flutter)
- [Flutter accessibility](https://docs.flutter.dev/ui/accessibility)
- [Material themes](https://api.flutter.dev/flutter/material/ThemeData-class.html)

2026-09-15: user chose restrained neutral visual direction and a light primary
review canvas. The palette, type scale, and migration sequence guide implementation
within that direction. Community guidance informs the review; this contract and
the project requirements control implementation. No global Skill installation is required
to use this design framework.

2026-09-15: user approved full Material unification and a review of every existing
page. Remove Forui widgets, themes, localization and font/icon resources. Bundle
Inter 400/500/600/700 locally with its license. Share brand visuals across iOS and
Android while preserving platform navigation, scrolling and editing behavior.
Use flat surfaces without tint/elevation, soft pressed backgrounds without
ripples, and visible focus. Appearance joins language/timezone as a preference
row opening a compact choice sheet. Navigation labels honor system text scaling.

2026-09-15: page titles align vertically with header controls. Every page paints
an opaque canvas during platform transitions. Searchable selectors pin the search
field while the heading may scroll; timezone rows separate city titles from UTC
offsets and IANA identifiers in supporting text.

2026-09-15: complete Phase 2 pages with semantic content surfaces, persistent
form labels, explicit financial rows and local recovery. Responsive layouts
retain every value. Row groups accept complete rows; content and form surfaces
own their padding. Preserve drafts on conflict and original requests when their
outcome is unknown. Native evidence covers expanded states and modal surfaces.

2026-09-16: transaction details expose independent Edit and More actions buttons.
Secondary actions move into a root-owned bottom sheet grouped by new records
and linking existing records, preserving business eligibility and recovery.
Buttons stack when scaled labels cannot fit; destructive actions stay separate.
