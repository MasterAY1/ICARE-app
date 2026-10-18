---
name: icare-flutter-design
description: Upgrade Flutter mobile, tablet, and web interfaces with a modern responsive design system while preserving existing application behavior, data contracts, and financial controls. Use for ICARE Core Banking UI/UX work and comparable Flutter app design tasks.
---

# Flutter UI/UX for Antigravity

Create polished, calm, task-oriented Flutter experiences that work equally well on phones, tablets, and desktop web. For ICARE Core Banking, favor speed, clarity, error prevention, traceability, and accessible data density over decorative complexity.

## Scope and non-negotiable safeguards

This skill changes presentation and interaction design only unless the user separately authorizes a business or backend change. Before modifying a screen, identify the existing route, state source, actions, roles, and data models. Reuse them rather than replacing them.

Do not change, bypass, simulate, or duplicate:

- CO workflows, authorization levels, maker-checker/confirmation rules, or role-based access;
- Account 1000 behavior, cashbook rules, journal posting, double-entry balancing, reconciliation, or approval states;
- transaction calculations, validation, dates, identifiers, audit fields, reports, exports, or financial totals;
- Supabase schema, RLS policies, RPCs, Edge Functions, authentication/session behavior, API payloads, repositories, or backend error semantics;
- production, testing, or branch database configuration, environment files, secrets, migrations, or data.

Never replace a real balance, status, ledger entry, confirmation, or permission decision with client-side display logic. A redesigned control must call the same approved command, service, or callback and preserve its loading, success, error, disabled, and retry behavior. If a UI improvement requires any change above, stop and state the dependency and the smallest safe proposed change.

---

## Start with the screen contract

Inspect the screen and its adjacent flows before coding. Record a concise UI contract in the change plan or PR description:

1. **Users and roles** who can view or act.
2. **Inputs, read-only values, formatting rules**, and required confirmations.
3. **Existing commands, state transitions, backend calls**, and errors.
4. **Critical invariants**: amount/currency integrity, balanced entries, auditability, status accuracy, and no accidental submission.
5. **Target form factors** and the acceptance checks below.

Treat unknown financial meaning as an open question, not a design assumption. Do not infer that two statuses, amounts, or actions are interchangeable because they look similar.

---

## Design direction

Use Material 3 as the implementation baseline, adapted to the product's existing brand rather than overwritten wholesale. Build a restrained financial-product visual language:

- **Clear visual hierarchy**: page title and primary action first; totals and exceptions next; supporting detail last.
- **Semantic colors**: Use semantic colors for success, warning, error, info, and neutral surfaces. Never use color alone to convey a financial status.
- **Restrained token set**: Prefer a small token set: `colorScheme`, text styles, spacing, radii, elevations, state overlays, and component themes. Extend the existing theme before adding local hard-coded values.
- **Rhythm & Touch Targets**: Use a 4 or 8 dp spacing rhythm, generous touch targets ($\ge 44 \times 44\text{ dp}$), readable numeric typography, and aligned columns for amounts.
- **Clarity over Prominence**: Keep account numbers, balances, posting dates, status, and confirmation state visually distinct but never overly prominent in ways that could cause misreading.
- **Vector Icons Only**: Use familiar icons only when paired with a label or accessible tooltip for important actions. Avoid novelty, excessive animation, gradients that reduce contrast, and dense card nesting.

### Financial Value Formatting & Anti-Wrapping Invariant
- **Currency Symbol**: Standard Nigerian Naira (`₦`) prefix.
- **Thousand Separators**: Required for all numbers $\ge 1,000$ (e.g., `₦5,000`, `₦150,000`, `₦2,500,000`).
- **Decimals**: Whole Naira (`0` decimals) for standard repayments, savings, and loan balances unless fractional kobo values exist.
- **Anti-Wrapping Invariant**: A financial amount must **never wrap across lines** character-by-character:
  ```text
  // FORBIDDEN WRAPPING:
  ₦
  50,
  000

  // STRICTLY REQUIRED:
  ₦50,000
  ```
- **Tabular Figures**: Use tabular figures (`fontFeatures: [FontFeature.tabularFigures()]`) or monospaced font features that align digits vertically in tables and lists.

### Information patterns for banking screens

- **Dashboards**: show actionable exceptions and a concise status summary; make data provenance and refresh state visible when relevant.
- **Lists and registers**: use search, filters, sort, pagination/virtualization as already supported, visible empty/loading/error states, and stable column labels. Preserve exact server order and filter semantics unless separately authorized.
- **Financial rows**: use tabular figures or another font feature that aligns digits; right-align amounts, label currency consistently, preserve signs and decimal precision, and do not truncate critical identifiers without an accessible full value.
- **Detail pages**: group identity, amounts, entries, approvals, and audit information into clearly named sections. Keep status history and immutable references available.
- **Destructive or irreversible actions**: require the existing confirmation flow, describe the consequence plainly, and prevent double submission. A dialog must not create a new confirmation or authorization rule.
- **Forms**: label every field persistently, mark required fields in text, validate close to the field, retain entered data after non-destructive errors, and focus the first actionable error on submit.

---

## Responsive layout rules

Use the available width, not a device name, to select layout. Preserve the same data, permissions, and action semantics at every size.

| Available width | Layout intent | Navigation and content |
| :--- | :--- | :--- |
| **Compact: under 600 dp** | One-handed, sequential tasks | Bottom navigation for 3-5 top-level destinations; single-column forms; sheets for supporting filters/details; primary action fixed only when it cannot obscure fields. |
| **Medium: 600-1023 dp** | Tablet and narrow desktop | Navigation rail when it reduces context switching; two-column detail/form layouts when each column remains readable; master-detail only for complementary content. |
| **Expanded: 1024 dp and above** | Desktop web, high information density | Persistent rail or drawer; constrained readable content width; table/list + detail split where useful; inline secondary actions and keyboard-friendly data work. |

Do not branch by platform alone or hard-code common device widths. Use `LayoutBuilder`, `MediaQuery.sizeOf`, and design tokens; keep breakpoints centralized. Test widths immediately below and above each breakpoint, plus large text and browser zoom. On web, set sensible max widths for forms and readable text while allowing data tables to use space or scroll horizontally with an obvious affordance.

### Adaptive navigation

- Keep destinations, badges, selected state, deep links, and role visibility identical across bottom navigation, rail, and drawer variants.
- Do not hide a required workflow merely because the layout changes. Move secondary destinations into an explicit "More"/drawer destination only when discoverability remains adequate.
- Preserve the current route and unsaved form state when navigation adapts after resize or rotation.
- Give each destination a text label, current-location indication, accessible name, and predictable back behavior.

---

## Flutter component patterns

Compose reusable, semantic components around existing models and controllers. Favor small presentation widgets with explicit inputs and callbacks; do not relocate domain logic into widgets.

- **App shell**: adaptive navigation, responsive content constraints, consistent page title/actions, and a safe place for feedback banners.
- **Page scaffold**: handles loading, empty, error, and content states without changing the data-fetching contract.
- **Metric/summary card**: label, formatted value, context, semantic state, and optional drill-down callback; never calculates financial values itself.
- **Data table/list**: stable row identity, keyboard/focus support on web, responsive columns, and a compact row alternative that exposes the same fields/actions.
- **Status badge**: maps existing canonical statuses to label/icon/color in one location; unknown states remain explicit rather than silently mapped.
- **Amount display**: receives an already-correct amount, currency, and precision; formats according to existing product rules only.
- **Form field group**: label, help text, error text, enabled/read-only state, and validation supplied by the established form/controller layer.
- **Confirm action**: reuses the current authorization and command path, displays the provided impact summary, blocks repeat taps while pending, and reports the backend outcome verbatim enough to remain actionable.

Use `const` widgets where practical, keys for stateful/reorderable financial rows, and theme extensions only when repeated semantics need them. Avoid a new state-management framework, new dependency, new routing package, or generic "design system rewrite" unless the user approves it separately.

---

## Accessibility and inclusive operation

Meet WCAG 2.2 AA intent for user-facing screens, including Flutter web:

- **Contrast**: Maintain at least 4.5:1 contrast for normal text and 3:1 for large text and meaningful UI boundaries; verify custom brand colors.
- **Text Scaling**: Support text scaling to at least 200% without clipped controls, hidden errors, or lost primary actions.
- **Target Sizes**: Ensure all actionable targets are at least $44 \times 44$ logical pixels where feasible, with visible focus indicators and logical keyboard traversal on web.
- **Semantics**: Supply meaningful `Semantics` labels, hints, values, selected/expanded state, and button names. Exclude purely decorative icons from semantics.
- **Non-Color Indicators**: Do not convey success, warning, error, balance direction, or required fields using color, position, or icon alone.
- **Live Regions**: Announce asynchronous status/error changes appropriately; avoid auto-dismissing important financial errors before users can read them.
- **Reduced Motion**: Respect reduced motion and avoid animation that obscures number changes or confirmation outcomes.

---

## ICARE Governance Standards

### 1. Strict Zero-Emoji Corporate Governance (Rule 10)
Emojis are **strictly prohibited** across all UI elements (tab headers, buttons, cards, expanders, tables, alerts, dialogs, form controls, or markdown text). Do NOT use emoji characters. Use clean, professional corporate typography or SVG vector / Material Icons instead.

### 2. Strict Zero Internal Code/Identity Leaks in Frontend UI (Rule 12)
Technical rule codes, database identities, and chart-of-accounts internal numbers belong exclusively to backend engines, database migrations, and architectural documentation:
- **Prohibited in UI**: Never show raw rule codes (e.g. `BR-SAV-002`, `BR-SAV-006`, `BR-DASH-005`, `FP-001`), database table/column names (`internal_savings`, `co_cashbooks`), or Chart of Accounts account numbers (`Account 1000`) in user-facing labels, badges, headers, dialogs, helper texts, pill tags, or alert banners.
- **Required in UI**: Use clean, human-friendly corporate banking terminology:
  - Instead of `"Designated Misc Manager (BR-SAV-006)"` $\longrightarrow$ `"Designated Misc Manager"`
  - Instead of `"BR-SAV-002 • BR-SAV-006"` $\longrightarrow$ `"Branch Reserve"` or `"Internal Fund"`
  - Instead of `"Inflows must flow via Account 1000"` $\longrightarrow$ `"All inflows are secured in primary vault cash."`
  - Instead of `"Account 1000 Vault"` $\longrightarrow$ `"Vault Cash (Primary Ledger)"` or `"Branch Vault Cash"`

### 3. Strict Conciseness & Zero Verbosity (Avoid Lengthy Descriptions)
Avoid lengthy descriptive paragraphs, wordy tutorial banners, and redundant subheadings. Financial professionals and banking operators require high-density, low-noise interfaces:
- **Microcopy Over Walls of Text**: Replace multi-line introductory paragraphs with concise, punchy titles and compact status badges.
- **Progressive Tooltips**: Place supplementary explanations, formula notes, or audit hints inside accessible tooltips (`Tooltip`) or contextual helper icons rather than printing paragraphs directly onto the main screen canvas.
- **Short Helper Text**: Field helper copy, subheaders, and card subtitles must remain under 60 characters and focus strictly on operational action.
- **One-Sentence Empty States**: Empty states must consist of exactly 1 clear sentence explaining the current state and 1 clear primary action button, avoiding decorative narratives.

---

## Implementation workflow

1. **Inspect**: Inspect existing theme, routes, responsive utilities, screen state, tests, and backend-facing code. Reuse local conventions.
2. **Define UI Contract**: Define the UI contract and a narrow visual plan. Name every screen/component to change and explicitly list the logic/data layers left untouched.
3. **Extend Tokens**: Establish or extend tokens and common components only when they eliminate real duplication across the requested scope.
4. **Responsive Composition**: Implement layouts with responsive composition, not duplicate feature flows per device class.
5. **Preserve Integrations**: Preserve integration points, command handlers, permission checks, selectors, error handling, analytics/audit hooks, and test identifiers.
6. **Validate Visual States**: Validate visual states: loading, populated, empty, slow/network error, validation error, permission-denied, pending, success, and backend-rejected using existing mechanisms.
7. **Run Tests & Checks**: Run the project's existing formatter, analyzer, unit/widget/integration tests, plus focused responsive and accessibility checks. Report any test that cannot be run.

---

## Definition of done / acceptance criteria

Accept UI work only when all applicable checks pass:

- The same role sees the same allowable actions and receives the same backend authorization outcome before and after the UI change.
- Identical input produces identical request payloads, calculations, transaction/posting behavior, ledger/cashbook effects, and audit data.
- No schema, RLS, RPC, API, environment, database-selection, migration, or secret change is included.
- Compact, medium, and expanded layouts expose the complete required workflow without overflow, clipped controls, accidental horizontal scrolling, or state loss.
- Financial amounts, signs, currency, precision, status, account identifiers, and timestamps render accurately and remain readable at 200% text scaling.
- Loading, empty, error, permission, pending, success, and double-tap/duplicate-submit behavior are explicit and correct.
- Keyboard navigation, focus visibility, semantic labels, contrast, and non-color status cues work for every changed interactive element.
- Existing automated tests pass; add or update widget/golden/integration tests for changed responsive layouts and critical visual states when the project test setup supports them.
- The handoff notes identify changed UI files, unchanged business/backend surfaces, tested form factors, and any remaining design assumptions.

---

## Antigravity request template

Use this prompt structure when delegating a UI task to Antigravity. Fill the bracketed fields from the actual project; do not invent business rules.

```text
Use $icare-flutter-design to improve the UI/UX of [screen/flow] in this Flutter app.

Scope: [specific UI files/screens and target roles].
Responsive targets: compact <600dp, medium 600-1023dp, expanded >=1024dp.
Preserve: existing routes, state management, API/Supabase contracts, role checks, commands, financial calculations, Account 1000, cashbook, double-entry ledger, reconciliation, confirmations, audit behavior, and all test/branch/production database configuration.

Deliver: a modern Material 3 presentation using existing theming where possible; adaptive navigation/layout; accessible fields, statuses, tables, and error states; and focused tests for changed states/layouts.
Do not change any business logic, backend/schema/RLS/RPCs, payloads, migrations, environments, secrets, or dependencies. If a desired design needs one, stop and explain the smallest safe dependency.

Before coding, state the UI contract and the integration points that will remain unchanged. After coding, report the tested widths, accessibility checks, test results, and confirmation that no financial/data-contract files changed.
```
