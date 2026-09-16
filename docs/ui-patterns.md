# Page and component contracts

These rules implement [DESIGN.md](../DESIGN.md) and the [design system](design-system.md).
They apply to each page, expanded section and modal surface, including empty and
failure states. Retain Material 3, Inter, Lucide and the existing semantic palette.

## Choose composition by intent

| Content or behavior | Use | Avoid |
| --- | --- | --- |
| Navigation or entity collection | Complete padded rows inside `LedgerGroup` | Bare text, fields or spacer rows inside a group |
| Prose, empty content or summary | `LedgerSurface` with explicit content insets | A decorative container whose child determines all geometry |
| Contextual guidance or recovery | `LedgerNotice` or `FailureView(action: ...)` | Unbounded text floating between unrelated sections |
| Business form | `LedgerFormSection`, `LedgerTextField`, `LedgerSelectField` | Per-page label, border and error styling |
| Fixed value | `LedgerReadOnlyField` | Disabled-looking input or misleading navigation arrow |
| Financial entity | `LedgerFinancialRow` and `LedgerMoneyText` | Truncating amount, currency or account metadata to fit |
| Equally important actions on one object | `LedgerButtonGroup` | Selection semantics or grouping solely by visual proximity |
| Primary action with secondary operations | Primary button and More actions sheet | Flattening all operations into equally prominent buttons |
| Preference or catalog choice | `ChoiceSelect` or `LedgerSelectField`, respectively | Action buttons masquerading as selected choices |

Reuse the shared component before adding page-specific decoration. If a correction
applies to several pages, fix the shared contract and verify its other callers.

## Space ownership

| Owner | Contract |
| --- | --- |
| `LedgerPage` | Gutters 20, or 16 below 360; content width 640; forms 520 |
| Section | Heading gap 12; section gap 24; major separation 32 |
| `LedgerGroup` | One boundary; complete padded rows; dividers between entities |
| `LedgerSurface` | 16 content inset, minimum height 56, natural text growth |
| `LedgerFormSection` | One content surface, optional heading, no field dividers |
| `LedgerFieldFrame` | Persistent label, gap 8, control, helper/error, bottom gap 16 |

Do not add global padding to a row group: its rows already own their insets.
Do not pass bare text, input fields or spacers as individual grouped rows. A fee
is a business entity whose explanation, checkbox and expanded fields stay together.
Use flat rows within a group instead of creating a separate card for every value.
For a heading followed by lazy rows, assign the gap once using
`LedgerPage.contentBottomSpacing`; do not add both a section spacer and the
page's default trailing gap. Long scaled page titles move below header controls
to use the full reading width.

## Empty and conditional content geometry

An empty state is a designed state of the same surface. In particular, the home
This Month summary must retain its available width, content inset and meaningful
minimum height when there is no activity. Let content grow with translated labels
and text scaling; do not enforce a fixed height or add invisible placeholder text
to hold a card open. Distinguish a known zero from missing or failed data.

Required spacing belongs to the surrounding layout, not to an optional notice,
error, fee or amount. Check both presence and absence of conditional children.
A notice owns its boundary and content inset; its parent owns separation from the
next section. A row group already contains padded rows and must not acquire a
second blanket inset as a shortcut for fixing an incorrectly composed child.

## Connected action groups

Use `LedgerButtonGroup` for peer actions on the same object with equal emphasis. Each `LedgerButtonGroupAction` retains its own
callback, disabled state and progress. The group is an action surface, never a
selection control; do not replace it with `SegmentedButton` or toggle semantics.

The group owns one outline, outer corner radius and internal separators. Buttons
use the existing Material focus, pressed and hover treatments. Labels determine
whether the whole group fits horizontally; otherwise it becomes a full-width
vertical group with natural text wrapping. Logical order is preserved in RTL.
Every target remains at least 48 by 48. Busy shows progress in the unchanged label
footprint and retains the accessible action name, without moving other buttons.

Keep primary submission, cancellation/confirmation pairs and destructive actions
separate. Do not group unrelated actions merely because they share a `Row`.

## Transaction detail actions

Keep Edit as a primary action beside an independent outlined More actions button.
Measure translated labels at the active text scale; stack both buttons when both
labels and their padding cannot fit. Keep at least 48-pixel targets and full text.
More actions opens a root-owned, content-sized, scrollable bottom sheet. Group
Record refund and Add fee under New records; group Link transaction and Link fee
under Link existing records. Fee actions explain creating versus selecting an
existing record. Omit unavailable actions and empty groups, preserving accounting
eligibility. A voided transaction still exposes its existing ordinary link action.
Keep destructive actions separate and retain relation results in the detail.

Dismiss the sheet before navigation, prevent duplicate opens/selections, and
recheck scope and availability before accepting the result. Dismissal writes
nothing; returning from a child refreshes the detail. Keep Close reachable above
the scrolling options and support platform back, barrier and drag dismissal.

## Inputs and selection

`LedgerTextField` and `LedgerSelectField` share persistent external labels,
control boundaries, focus/error roles and supporting text. Selection uses the
existing root-owned choice sheet; preferences continue to use `ChoiceSelect`.

- Keep input keys stable. Use `LedgerTextField.inputKey` when callers or tests
  address the underlying `TextFormField`.
- Forms use `LedgerPage.eagerChildren: true`; lazy slivers must not unregister
  fields that still need validation. Data lists retain lazy builders.
- Validate required selection and monetary precision at the field. Register a
  focus target and scroll the first error into the available viewport on submit.
- Amounts identify their ISO currency and precision near the input, use exact
  integer arithmetic and appropriate signed-value rules, and never silently round.
- Dates have an explicit input format and a calendar affordance. Business dates
  are distinct from timestamp display in the user's time zone.
- Read-only values use `LedgerReadOnlyField`, with no navigation arrow or editing
  semantics. Temporary saving disables the editable control while preserving its value.
- Missing catalog entries show an unavailable-selection state, never an internal ID.
- Choosing commits once; dismissing writes nothing. Preserve the pinned search,
  visible close action, current selection, theme updates and single keyboard-inset
  ownership. A long catalog must remain explicitly dismissible after scrolling.

## Money, details and confirmation

`LedgerMoneyText` owns tabular figures. `LedgerFinancialRow` preserves a full-width
value area and independent metadata; a narrow viewport changes arrangement, never
which facts exist. Transfer principals remain distinct and each includes currency.

A transaction detail identifies kind, status, original amount, account, business
date, category and counterparty where present. Notes do not replace classifications.
Transfers identify both accounts and amounts. History includes currency and both
transfer sides, with accounting entries available as secondary detail.

The final confirmation is understandable without remembering the previous page:
show the operation, principals, every selected fee, per-account net changes and
which fees remain unchanged. Corrections compare old and new values. Reversals
show their actual effect. Fees default to unselected. Do not aggregate currencies
without an explicit business conversion contract.

## States and recovery

| State | Contract |
| --- | --- |
| Initial load | Stable scaffold and content-shaped placeholder |
| Refresh | Keep existing data, loaded range and reading position; local progress |
| Pagination | Footer progress/error and retry with the original cursor |
| Empty | Distinguish first use, no activity, no matches, unavailable and archived |
| Validation | Visible field error, first-error focus and semantic announcement |
| Saving | Stable action position, saving label and inline busy; no duplicate writes |
| Definite failure | Keep input, contextual explanation and retry |
| Unknown outcome | Preserve original payload/key, explain frozen inputs, recover that request |
| Conflict | Keep draft and current server snapshot; explicit review before replacing either |
| Partial read failure | Show available content; retry the failed region independently |

Use `LedgerNotice` for embedded guidance and `FailureView(action: ...)` for a
sanitized failure and its recovery. Full-page welcome/recovery content can remain
more spacious. A dependent write must remain unavailable until its required data
is complete. Returning from a changed child detail must refresh parent snapshots.

## Acceptance checklist

Each UI change includes behavior tests and appropriate native captures:

1. Render English and Chinese in light/dark; test 320 at 100%/200%, 390 at
   100%/200%, 360 at 130%, landscape and a width requiring navigation rail.
2. Assert all amounts, currencies and metadata remain accessible; no-exception
   assertions alone do not prove content completeness.
3. Measure meaningful geometry: content inset, label alignment, refresh position,
   error within viewport and reachable actions under keyboard constraints.
4. Exercise expanded fees, every confirmation, history and support detail; a
   route's first frame does not cover its hidden branches.
5. Exercise deterministic failure, unknown outcome, conflict, pagination retry,
   child-return refresh and session changes with fakes.
6. Run `bash tool/check.sh` and affected device tests. Inspect native captures for
   hierarchy, borders, padding and text. Record physical-device accessibility and
   live integrations separately, never infer them from widget tests.

Use golden tests when pixels are the intended contract, while preserving behavior
tests for actions and recovery. Store dated evidence in `ledger-manuscript`; keep
these reusable rules and application source in English.
