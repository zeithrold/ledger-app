---
name: ledger-ui
description: Implement or audit Flutter UI in Ledger App using its shared component, layout, state and accessibility contracts. Use for page design, visual regressions, forms, financial rows, empty states, action groups and modal flows. Also use when recording reusable lessons from Ledger UI fixes. Does not apply to backend-only work.
---

# Ledger UI workflow

## Establish scope and current contracts

1. Read [engineering rules](../../../AGENTS.md), [design direction](../../../DESIGN.md),
   [tokens and foundations](../../../docs/design-system.md) and
   [component contracts](../../../docs/ui-patterns.md). These are the maintained
   rules; historical mockups and dated completion reports are not current evidence.
2. Inspect the working diff and affected widgets before editing. Preserve unrelated
   changes. Honor review-only requests; an audit produces findings and a repair
   plan unless implementation is authorized.
3. Inventory affected routes, shared callers, expanded sections and modals. For a
   full UI audit cover every route; for a local fix keep the inventory bounded to
   affected behavior. Record the trigger, visible defect, component owner and
   expected behavior for each finding.

## Review composition and state together

- Choose components with the intent table in `docs/ui-patterns.md`. Trace every
  inset, section gap and boundary to one owner before changing spacing.
- Compare loading, empty, populated, error and optional-child states. Empty home
  summaries need stable geometry; missing data must not become invented totals.
- Verify persistent field labels, error placement, stable input identity and
  first-error focus. Keep offscreen form fields registered with eager children;
  retain lazy construction for data lists.
- Preserve complete amounts, currencies and metadata at large text. Reflow content
  instead of shrinking the user's text scale or hiding financial facts.
- Determine action relationships before choosing a layout. Peer actions may use
  `LedgerButtonGroup`; primary/secondary operations need hierarchy. A shared Row
  is insufficient justification. Transaction details currently use Edit + More
  actions; destructive actions remain separate.
- Inspect expanded fees, confirmations and selection sheets, not just the first
  page frame. Verify dismissal, root navigation, keyboard insets and child-return
  refresh. Recovery must preserve drafts and already loaded content.
- Use existing tokens and translated ARBs. Follow repository regeneration rules;
  a visual correction does not authorize new dependencies or a design-system swap.

## Verify the affected contract

Read [testing guidance](../../../docs/testing.md) for commands and device setup.
Choose the suite by the behavior being changed:

| Area | Existing test entry points |
| --- | --- |
| Surfaces, fields and shared states | `test/phase2_shared_refinement_test.dart`, `test/ui_design_test.dart` |
| Overview, account and transaction lists | `test/phase2_lists_refinement_test.dart` |
| Forms, validation and confirmation | `test/phase2_forms_refinement_test.dart` |
| Details, relations and recovery | `test/phase2_detail_refinement_test.dart` |
| Peer action group | `test/button_group_test.dart` |
| Transaction Edit + More actions | `test/transaction_actions_test.dart` |
| Header and searchable choice sheet | `test/ui_header_search_regression_test.dart` |

Add a regression at the appropriate layer that fails for the original defect.
Assert visible content and meaningful geometry, not just absence of exceptions.
For example, verify the empty summary's width and inset, the first invalid field
inside the viewport, or all action labels remaining reachable at 200% text.
Use deterministic fakes for failures and recovery; do not use production data.

Apply the locale, theme and viewport matrix in `docs/ui-patterns.md`. Run
`just check` and affected native flows when UI behavior changes. Inspect
native captures of affected states. A simulated keyboard inset is not evidence of
an actual OS keyboard interaction; a build is not a successful device test.
Documentation-only changes require link/instruction validation and the repository
gate, but do not require rerunning unchanged native UI flows.

## Record the reusable result

- Put mandatory constraints in `AGENTS.md`, component contracts and anti-patterns
  in `docs/ui-patterns.md`, and execution procedures here. Link between them
  instead of duplicating full checklists or token tables.
- Keep these files in English. Put dated evidence, screenshots and blockers in
  the sibling `ledger-manuscript` development records, following `AGENTS.md`.
- Report what changed, why, and which checks passed, failed, were blocked or were
  not run. Do not reuse a previous test count as evidence for the current change.
