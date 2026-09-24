---
name: icare-flutter-design
description: Authoritative design, presentation-layer, responsiveness, and parity skill for ICARE Flutter frontend development. Enforces Streamlit parity, responsive breakpoints (<600px phone, 600-899px tablet, >=900px desktop), financial metric card formatting, zero-emoji corporate aesthetics, shared component governance, and zero-redesign principles. Activate before designing, creating, or modifying any Flutter UI screen, layout, or widget.
---

# ICARE Flutter Frontend Design & Parity Skill

## Overview
This skill provides the mandatory, authoritative design principles, responsive layout rules, financial formatting constraints, and parity standards for the **ICARE Flutter frontend**.

ICARE is an existing microfinance and core-banking application. The Flutter frontend is a direct migration and client-layer reproduction of the existing Streamlit application (`app.py`).

Whenever you design, create, modify, inspect, or review any Flutter screen, widget, dialog, or layout, you **MUST** strictly adhere to this skill.

---

## 0. THE CORE RULE

> [!IMPORTANT]
> **A beautiful ICARE screen that produces the wrong number or hides important information is a failed implementation.**
> **A simple ICARE screen that preserves the correct workflow, data, financial information, and usability is a successful implementation.**
>
> Always prioritize:
> $$\text{CORRECTNESS} \longrightarrow \text{READABILITY} \longrightarrow \text{PARITY} \longrightarrow \text{RESPONSIVENESS} \longrightarrow \text{POLISH}$$
>
> Before reporting completion of any UI task, verify that the implementation satisfies these principles in this exact order of priority.

---

## 1. Principle 1: Existing System First

The existing Streamlit implementation is the **visual and behavioural reference** unless an explicitly approved Flutter design decision overrides it.

Do **not** redesign ICARE simply because Flutter allows a different design.

### Preserve Existing:
- **Terminology & Labels**: Use exact button names, section headers, input labels, and table column titles from Streamlit.
- **Buttons & Actions**: Preserve existing placement, action order, and confirmation dialogs.
- **Information Hierarchy**: Keep the logical order of sections, summaries, and detail breakdowns.
- **Navigation & Menus**: Maintain role-based sidebar items and sequence from `RBACScopeService.get_permitted_menu_items`.
- **Workflows**: Preserve multi-step collection, loan origination, withdrawal, and EOD cashbook flows.
- **Metric Meanings**: Do not invent new metrics or re-calculate existing metrics differently.
- **Status Meanings**: Respect canonical client and loan statuses (`Registered`, `On Loan`, `Completed`, `Dormant`, `Inactive (Savings Only)`, `Closed`, `Suspended`, `Defaulter`).
- **Content & Financial Values**: Present real values exactly as formatted by the backend and Streamlit reference.

When uncertain about any visual or behavioural detail, **inspect the actual Streamlit implementation (`app.py`) before inventing anything.**

---

## 2. Principle 2: Flutter is the Presentation Layer

Flutter is strictly the **presentation and client layer**.

### Prohibited in Flutter:
Do **not** move backend business logic into Flutter. Do **not** modify or reimplement:
- Financial calculations (amortization, interest markup, penalty fees, excess allocations)
- Ledger posting logic (Account 1000 physical vault cash rules)
- Double-entry accounting invariants
- Database rules, foreign keys, or triggers
- API contracts or backend schemas
- Approval rules and operational locks (business date freeze, weekend/holiday locks)
- RBAC permissions and role scopes
- Event-sourcing and audit log dispatch

**Rule**: UI problems must be solved at the **presentation/layout level** unless there is clear, verified evidence that the backend API itself is incorrect.

---

## 3. Principle 3: Responsive Design

Mobile must **NOT** be treated as a shrunken desktop.

### Layout Priority:
$$\text{READABILITY} \longrightarrow \text{USABILITY} \longrightarrow \text{CONSISTENCY} \longrightarrow \text{COMPACTNESS}$$

**Never sacrifice readability simply to fit more components on one row.**

### Target Breakpoints:

| Device Target | Breakpoint Range | Shell Navigation | Form Inputs | Metric Cards & Tables |
|---|---|---|---|---|
| **Phone** | `< 600px` | Top `AppBar` with hamburger toggle + slide-out `Drawer` | Single-column (full width) | Prioritize readable single-column or comfortable 2-column layouts. Never force 3–4 cards into narrow rows. Wrap tables in horizontal scroll. |
| **Tablet** | `600px – 899px` | Top `AppBar` with hamburger toggle + slide-out `Drawer` | 2 columns | Balanced multi-column (2-column grids) where content remains fully readable. |
| **Desktop** | `≥ 900px` | Fixed 240px–280px corporate sidebar | Multi-column (original layout) | Original multi-column rows (3, 4, or 8 cards) matching Streamlit baseline. |

### Phone Guidelines (`< 600px`):
- Prioritize readable single-column or comfortable two-column layouts.
- Do not force 3–4 metric cards into narrow rows.
- Preserve readable text, badges, and financial values.
- Form input rows must collapse gracefully to single column.

### Tablet Guidelines (`600px – 899px`):
- Use balanced multi-column layouts where content remains readable.
- Metric cards should typically render in a 2x2 grid.

### Desktop Guidelines (`≥ 900px`):
- **Preserve the existing desktop layout 100%** unless an approved change requires otherwise.
- Mobile and tablet adaptations must never regress desktop parity.

---

## 4. Principle 4: Metric Cards & Financial Numbers

Metric cards are critically important in ICARE because they frequently display financial values.

### A. Non-Negotiable Financial Value Formatting
Financial values must **always remain readable as complete values**.

For example:
- `₦5,000`
- `₦50,000`
- `₦500,000`
- `₦5,000,000`
- `₦50,000,000`

**Forbidden Wrapping**: Financial values must **never** become character-by-character or fragmented layouts such as:
```text
₦
5
,
0
0
0
```
or:
```text
₦5
,000
,000
```

### B. Prevention Rules:
- **Never solve wrapping by making the number font extremely small** (minimum readable metric value font size: 15–16px).
- Metric **labels** may wrap naturally onto 2 lines when necessary.
- Financial **numbers** must have stronger protection against wrapping (`softWrap: false`, `overflow: TextOverflow.ellipsis` with sufficient container width, or wrapped in responsive grid).
- **Cards within the same metric section must have consistent**:
  - Padding (e.g. `horizontal: 14, vertical: 12`)
  - Alignment (cross-axis start)
  - Visual height
  - Spacing between cards (e.g. 10–12px)

$$\textbf{READABILITY FIRST. NUMBER OF COLUMNS SECOND.}$$

---

## 5. Principle 5: Shared Components Over Screen-Specific Hacks

Before fixing a UI problem on an individual screen, inspect whether the problem originates from a **shared component**.

### Examples of Shared Components & Layouts:
- `MetricCard` / `_buildTallyKpi` / `_buildSummaryKpiCard`
- Responsive grid containers (`LayoutBuilder`, `GridView.builder`)
- `Wrap` vs. `Row` vs. `Flex`
- Parent constraints and padding
- Breakpoint logic helper widgets (`_buildResponsiveInputRow`)
- Data table containers (`SingleChildScrollView(scrollDirection: Axis.horizontal)`)

### Rules:
1. If a shared component causes the issue, **fix the shared component and its responsive parent** rather than creating multiple screen-specific patches.
2. Do **not** create a second parallel component system unless there is a genuine, documented architectural reason.
3. Keep component APIs unified across all role dashboards and operations.

---

## 6. Principle 6: No Arbitrary UI Fixes

Do **NOT** solve responsive problems with:
- Arbitrary fixed pixel widths on fluid elements
- Hardcoded screen coordinates or magic numbers
- Tiny, unreadable fonts (< 11px for data, < 14px for metrics)
- Horizontal page scrolling on the main viewport (only individual data tables may scroll horizontally)
- Excessive truncation that hides meaningful financial figures
- Hiding important financial columns or metrics to make a layout fit
- Duplicated widgets with divergent logic
- Hardcoded financial values or fake production data

### Rule:
Use the available screen width **intelligently**. Cards and containers should expand appropriately while maintaining comfortable, readable content.

---

## 7. Principle 7: No Unnecessary Redesign (Zero-Redesign Constitution)

Do **NOT** introduce:
- Decorative gradients or glassmorphism
- Excessive, distracting animations
- Random emojis (see **Rule 10: Strict Zero-Emoji Governance**)
- Invented sections or cards that do not exist in the Streamlit baseline
- Invented terminology, labels, or abbreviations
- Unnecessary decorative icons
- Speculative "modern UI" changes unsupported by the existing ICARE design

**The goal is a professional, clean corporate banking application, not an AI-generated showcase UI.**

---

## 8. Principle 8: Data Integrity & No Fake Data

1. **Real API Data Only**: Dynamic business values must be supplied by real backend endpoints. Never replace API data with hardcoded values simply because the UI is easier to construct.
2. **Missing Endpoints = Missing Contract**: If a backend endpoint does not exist, report **MISSING API CONTRACT**. Never invent fake responses or placeholder numbers.
3. **Mock Data Isolation**: Mock/fixture data is permitted **only** when explicitly isolated in unit test files (`test/`). Never silently substitute fake values for real API data in application code.

---

## 9. Principle 9: Desktop Parity

A mobile or tablet improvement must **never** unnecessarily alter or degrade the desktop experience.

When modifying any responsive behaviour, you **must verify all three form factors**:
1. **Phone** (`< 600px`): Verify single-column flow, hamburger drawer, readable metrics, horizontally scrollable tables.
2. **Tablet** (`600px – 899px`): Verify 2-column balanced layouts, drawer navigation, no clipping.
3. **Desktop** (`≥ 900px`): Verify fixed sidebar, full multi-column grid, 100% visual parity with desktop baseline.

A responsive task is **NOT complete** until all three viewports are verified.

---

## 10. Principle 10: Inspection Before Implementation

Before modifying any existing screen or widget:

1. **Inspect Current Flutter Implementation**: Read the widget tree, constraints, controllers, and state.
2. **Identify Actual Failing Component**: Determine whether the issue is parent constraints, `Row` vs `Column`, missing scroll wrapper, or shared component sizing.
3. **Inspect Corresponding Streamlit Implementation**: Verify labels, hierarchy, and business logic in `app.py`.
4. **Understand Current Responsive Constraints**: Check `MediaQuery.sizeOf(context).width` or `LayoutBuilder` constraints.
5. **Make Smallest Appropriate Change**: Apply minimal, surgical layout fixes without touching unrelated code.
6. **Verify Unrelated Behaviour**: Confirm that other tabs, viewports, and role permissions remain completely unaffected.

**Do not immediately replace an existing implementation because rewriting it looks easier.**

---

## 11. Principle 11: Fail Closed

If the correct layout, behaviour, or data mapping is unclear:

$$\textbf{STOP. DO NOT GUESS.}$$

1. Inspect the existing Streamlit source code (`app.py`).
2. Inspect the authoritative rules in `.agents/rules/`.
3. Inspect `migration_docs/`.
4. If still ambiguous, document the ambiguity and ask for clarification.

**Do not invent business rules, UI behaviour, terminology, financial values, or role permissions.**

---

## 12. Principle 12: ICARE Quality Standard

The final Flutter interface must feel like a deliberate, professional microfinance and core-banking application across:
- **Phone**
- **Tablet**
- **Desktop**

It must **never** look like:
- *"A desktop squeezed into a phone."*
- *"A mobile app stretched across a desktop."*

It must **never** sacrifice financial readability simply to make the interface look more compact.

---

## 13. Strict Zero-Emoji Governance (Rule 10 Invariant)

Emojis are **strictly prohibited** anywhere in the system UI:
- Tab headers
- Button labels
- Card titles and bodies
- Expanders and accordions
- Data tables and cells
- Alerts, snackbars, and banners
- Dialog titles and contents
- Form labels and hints
- Markdown text

**Use clean corporate typography or Material / SVG icons instead.**

---

## 14. Page Parity Specification Protocol

Before implementing or significantly refactoring any Flutter page, create or consult the **PAGE PARITY SPECIFICATION**:

```markdown
PAGE: [Exact Page Name]
ROLE: [CO | BM | AM | Admin | Director]
STREAMLIT SOURCE: [app.py line range]

PAGE TITLE: [Exact text]
NAVIGATION LABEL: [Exact text]
SECTIONS: [Exact order]
COMPONENTS: [Every visible component]
FIELDS: [Exact labels, hints, and types]
TABLES: [Exact columns, alignments, and widths]
BUTTONS: [Exact labels, variants, and actions]
FILTERS: [Exact controls and defaults]
MESSAGES: [Exact success/error/warning texts]
ROLE VISIBILITY: [Exact permissions]
DATA SOURCE: [Exact service/repository/API endpoint]
RESPONSIVE BEHAVIOUR:
  - Phone (<600px): [Single column / wrapped]
  - Tablet (600-899px): [2-column grid]
  - Desktop (>=900px): [Full desktop layout]
WORKFLOW: [Exact user action sequence]
```

### Parity Gate Checklist:
- [ ] **Visual**: Structure, labels, controls, tables, and ordering match Streamlit.
- [ ] **Functional**: Actions, validation, permissions, navigation, and error handling work.
- [ ] **Data**: Real API data, no hardcoded financial values, correct field mappings.
- [ ] **Responsive**: Verified on Phone, Tablet, and Desktop with zero clipping or unreadable metrics.
- [ ] **Zero-Emoji**: Zero emojis in any label, button, or message.
- [ ] **Zero Business Logic**: Flutter remains strictly presentation; backend rules untouched.
