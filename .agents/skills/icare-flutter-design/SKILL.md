---
name: icare-flutter-design
description: Authoritative multi-platform design, responsiveness, and UI/UX skill for the ICARE Flutter frontend. Enforces mobile-first simplicity, multi-platform responsiveness (<600px phone, 600-899px tablet, >=900px desktop/web), financial typography standards, zero-emoji corporate aesthetics, shared component governance, and generative UI prototyping. Activate before designing, creating, or modifying any Flutter UI screen, layout, or widget.
---

# ICARE Flutter Multi-Platform Design & Responsiveness Skill

## Overview
This skill defines the authoritative design principles, multi-platform responsiveness guidelines, financial typography standards, and UI/UX simplification rules for the **ICARE Flutter application**.

ICARE is a production core-banking and microfinance system. The Flutter application (`frontend_flutter/`) is the **sole primary frontend** across all user roles (CO, BM, AM, Admin, Director, Auditor). Legacy Streamlit (`app.py`) is officially **deprecated and sunsetted**; it serves solely as an archival/read-only logic reference for historical financial formulas.

Whenever you design, simplify, create, refactor, or review any Flutter screen, widget, dialog, or layout, you **MUST** strictly adhere to this skill.

---

## 0. The Core Rule: Priority Order

> [!IMPORTANT]
> **A beautiful screen that misleads on financial numbers or hides critical data is a failed implementation.**
> **A simple, clean screen that ensures fast, accurate operations across mobile, tablet, and desktop is a successful implementation.**
>
> Always prioritize:
> $$\text{CORRECTNESS} \longrightarrow \text{READABILITY} \longrightarrow \text{USABILITY} \longrightarrow \text{RESPONSIVENESS} \longrightarrow \text{POLISH}$$
>
> 1. **Correctness**: Financial data, ledger balances (Account 1000), client lifecycle statuses, and transactional state must be 100% accurate.
> 2. **Readability**: Financial numbers and labels must be legible without awkward wrapping, microscopic fonts, or clipping.
> 3. **Usability**: Workflows must be intuitive, frictionless, and fast—especially for field officers using mobile devices under sunlight and network constraints.
> 4. **Responsiveness**: The interface must adapt natively to Phones (<600px), Tablets (600–899px), and Desktop/Web (≥900px).
> 5. **Polish**: Clean typography, consistent spacing, high contrast, subtle borders, and professional corporate styling.

---

## 1. Flutter-First Modern Fintech Architecture

With Streamlit sunsetted:
1. **Full Design Freedom**: You are completely liberated from Streamlit's desktop-first tables, cramped web expanders, and cluttered legacy layouts.
2. **Mobile-First Simplification**: Design for a field officer holding a phone with one hand. Eliminate unnecessary clicks, dense multi-column spreadsheets, and redundant metric cards.
3. **No Dual-Frontend UI Burden**: UI code is written exclusively in Flutter. Do not write, port, or maintain UI code in Streamlit.
4. **Logic Reference Only**: If historical calculation rules need clarification, inspect the Python services (`services/`) or `app.py` for underlying math, but design the Flutter presentation freely and modernly.

---

## 2. Presentation Layer Separation

Flutter is strictly the **presentation and client application layer**.

### Prohibited in Flutter:
Do **not** move backend financial or business invariants into Flutter. Flutter must never implement or alter:
* Double-entry bookkeeping logic or Account 1000 vault rules
* Amortization, interest formulas, penalty calculations, or excess payoff derivation
* Database foreign keys, triggers, or schema definitions
* Direct database updates bypassing FastAPI/atomic RPCs
* Role permissions and authorization matrix (governed by backend RBAC)
* Business date closure or operational locks

**Rule**: Address UI and UX challenges at the presentation, state management, and layout level using Riverpod, clean widgets, and responsive layouts. Backend APIs provide the authoritative data contracts.

---

## 3. Multi-Platform Responsive Design Engine

ICARE runs across three distinct form factors: **Mobile Phones**, **Tablets**, and **Desktop/Web Browsers**. Mobile must **never** feel like a squeezed desktop, and desktop must **never** feel like a stretched mobile phone.

### A. Responsive Breakpoints

| Platform Target | Viewport Width ($W$) | Navigation Pattern | Form Layout | Metrics & Cards | Data Presentation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Mobile Phone** | $W < 600\text{ px}$ | Clean Bottom Nav (3–4 tabs max) OR Top `AppBar` with slide-out `Drawer` | Single-column (full width), sticky action buttons at bottom | 1-column cards or compact 2-column grid. Never 3–4 cards per row. | Card lists, expandable summary cards, swipeable rows. Wrap raw tables in horizontal scroll. |
| **Tablet** | $600\text{ px} \le W < 900\text{ px}$ | Collapsible Navigation Rail or slide-out Drawer | 2 balanced columns | 2-column or 3-column grid with generous breathing room. | Responsive cards or hybrid data tables with fixed key columns. |
| **Desktop / Web** | $W \ge 900\text{ px}$ | Permanent Sidebar ($240\text{–}280\text{ px}$) with corporate branding | Multi-column grids (2–3 columns), right-side detail panes | 3 to 5 KPI cards per row in fluid grid containers. | Rich data tables with sorting, filtering, and fixed sticky headers. |

### B. Mobile Phone Implementation Rules ($W < 600\text{ px}$)
* **Touch Target Size**: Minimum interactive target size is $48 \times 48\text{ dp}$ (buttons, chips, list items, checkboxes).
* **Thumb Zone Architecture**: Place primary action buttons (e.g., "Submit Collection", "Approve Loan", "Add Entry") at the bottom of the screen within comfortable thumb reach.
* **Eliminate Horizontal Scroll Fatigue**: Avoid wide tabular data on phones. Convert rows of tables into clean, readable **Client Cards** showing Name, ID, Expected Amount, and Status.
* **Avoid Nested Scroll Conflicts**: Never place unconstrained `ListView` inside `SingleChildScrollView` without `shrinkWrap: true` and `physics: const NeverScrollableScrollPhysics()`.
* **Keyboard Insets**: Wrap forms in `SafeArea` and ensure inputs scroll automatically into view above the virtual keyboard (`resizeToAvoidBottomInset: true`).

### C. Tablet Implementation Rules ($600\text{ px} \le W < 900\text{ px}$)
* Take advantage of additional screen width by showing master-detail splits or 2-column forms.
* Ensure dialogs and modal bottom sheets have maximum width constraints (`maxWidth: 560`) rather than stretching awkwardly across the screen.

### D. Desktop & Web Implementation Rules ($W \ge 900\text{ px}$)
* Use a fixed corporate sidebar containing user profile, branch badge, online/offline pill, and menu links.
* Provide maximum content width clamping (e.g., `max-width: 1400px` centered) on ultra-wide monitors to prevent content from stretching across 4K displays.
* Support mouse wheel scrolling, hover states on interactive buttons, and keyboard navigation (Tab through form inputs).

---

## 4. Financial Typography & Metric Cards

Financial numbers represent real money and must **never** be visually truncated, clipped, or ambiguously wrapped.

### A. Non-Negotiable Financial Value Formatting
* **Currency Symbol**: Standard Nigerian Naira (`₦`) prefix.
* **Thousand Separators**: Required for all numbers $\ge 1,000$ (e.g., `₦5,000`, `₦150,000`, `₦2,500,000`).
* **Decimals**: Whole Naira (`0` decimals) for standard repayments, savings, and loan balances unless fractional kobo values exist.
* **Anti-Wrapping Invariant**: A financial amount must **never wrap across lines** character-by-character:
  ```text
  // FORBIDDEN WRAPPING:
  ₦
  50,
  000

  // STRICTLY REQUIRED:
  ₦50,000
  ```

### B. Metric Card Sizing & Typography Rules:
* Value font size: `20–24px` on desktop, `16–18px` on mobile phones. Never use micro-text below `13px` for financial numbers.
* Number text styles must specify `softWrap: false`, `overflow: TextOverflow.ellipsis` with a tooltip/modal if container is constrained.
* Labels may wrap to 2 lines cleanly:
  ```dart
  Text(
    'Total Collections (Today)',
    style: theme.textTheme.bodySmall,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  )
  ```
* Cards within the same section must share uniform height, padding (`14px horizontal, 12px vertical`), border radius (`12px`), and subtle border strokes (`1px solid #E2E8F0`).

---

## 5. UI/UX Simplification & Cognitive Load Reduction

The most common field complaint is that screens "look complicated" because too much raw data is dumped onto one screen. Apply these 4 principles to simplify every interface:

### 1. The One Primary Action Rule
Every screen must have **ONE obvious primary action**.
* **Collections Screen**: Primary action is "Record Collection" or "Submit Group". Everything else (history, filters, exports) is secondary.
* **Dashboard**: Primary action is "View Today's Schedule" or "Start Field Collection".
* Highlight primary actions with solid brand buttons (`ElevatedButton` in primary blue/indigo); secondary actions use outline or ghost styles.

### 2. Progressive Disclosure
* Do not display 20 fields or 8 metric cards at once on mobile.
* Show the essential high-level summary upfront.
* Use clean **collapsible accordions**, **tabs**, or **modal bottom sheets** to reveal granular audit trails, loan history, or fee breakdowns on demand.

### 3. Clutter Pruning
* If a metric card is rarely used by a field officer (e.g., complex variance percentages, redundant sub-totals), move it to a dedicated "Analytics/Report" tab or detail sheet.
* Keep the main operational viewport focused on what the officer needs **right now**.

### 4. Fast Data Entry Patterns
* For group collections: auto-fill expected amounts with 1-tap "Mark Paid All" or "Mark Paid", allowing manual entry only for exceptions (part-paid or excess).
* Numeric fields must automatically open the numeric keyboard (`keyboardType: const TextInputType.numberWithOptions(decimal: true)`).

---

## 6. Shared Component Architecture

Never create screen-specific layout hacks. All screens must be built using modular, shared components located in `frontend_flutter/lib/core/` and `features/shared/`:

1. **`AppScaffold` / `ResponsiveScaffold`**:
   * Handles platform detection, adaptive drawer/sidebar, offline banner, and sync status bar.
2. **`MetricCard`**:
   * Standardized KPI card with icon, title, formatted value, subtitle badge, and optional tap callback.
3. **`StatusBadge`**:
   * Standard color-coded badges for loan/client/sync states:
     * **Success (Green)**: `Active`, `Paid`, `Synced`, `Completed`
     * **Warning (Amber)**: `Part Paid`, `Pending Approval`, `Pending Sync`
     * **Danger (Red)**: `Overdue`, `Not Paid`, `Defaulter`, `Failed`
     * **Neutral (Slate/Blue)**: `Registered`, `Dormant`, `Draft`
4. **`AmountInputField`**:
   * Formatted currency text field with Naira prefix, auto-formatting, and validation.
5. **`OfflineIndicatorBar`**:
   * Persistent top banner indicating network mode (Online, Offline Cache, Pending Outbox Count).

---

## 7. Strict Zero-Emoji Corporate Governance (Rule 10)

Emojis are **strictly prohibited** across all UI elements:
* Buttons, tab bars, headers, alerts, badges, dialogs, empty states, and toast messages.
* **Use Material Icons or clean SVG vector assets only.**
* Maintain a polished, professional fintech appearance suitable for central bank audits and corporate enterprise use.

---

## 8. Interactive Prototyping Workflow (`generative_ui`)

When proposing significant layout overhauls or exploring UX simplifications with the user:
1. **Interactive HTML Prototype**: Use the `generative_ui` skill to create a self-contained, interactive Tailwind CSS HTML artifact in the conversation directory.
2. **Simulate Mobile & Desktop**: Include an interactive toggle or responsive container in the prototype showing both Phone (<600px) and Desktop views.
3. **Solicit User Feedback**: Let the user review, interact with, and approve the simplified UX prototype before modifying production Flutter widgets.
4. **Implement in Flutter**: Once approved, translate the validated layout into clean, production-grade Flutter widgets.

---

## 9. Page Design & Responsiveness Verification Checklist

Before considering any Flutter UI task complete, verify this checklist:

- [ ] **Mobile Responsiveness (<600px)**:
  * No horizontal page scroll or overflow errors (`RenderFlex overflowed`).
  * Primary action buttons sticky or comfortably in thumb zone.
  * Inputs and cards collapse into clean single-column or 2-column grid.
  * Interactive elements $\ge 48\text{ dp}$ touch target.
- [ ] **Tablet Responsiveness (600–899px)**:
  * 2-column balanced layouts.
  * Dialogs and modal sheets constrained to comfortable widths (`<560px`).
- [ ] **Desktop/Web Responsiveness (≥900px)**:
  * Persistent sidebar navigation with active route highlighting.
  * Fluid multi-column cards and full-featured data tables.
  * Max width container applied on ultra-wide screens.
- [ ] **Financial Value Integrity**:
  * Naira symbol (`₦`) and commas formatted correctly.
  * Anti-wrapping applied; zero character-split amounts.
  * Real API data bound; zero fake/hardcoded numbers.
- [ ] **Clutter & Usability**:
  * Screen has ONE clear primary action.
  * Secondary details tucked into progressive disclosure (bottom sheets/accordions).
  * High contrast typography and legible text.
- [ ] **Zero-Emoji Compliance**:
  * 100% SVG or Material Icons. Zero emoji characters anywhere in UI.
- [ ] **Clean Code & Shared Components**:
  * Reusable widgets utilized; no duplicate parallel styling systems.
  * Flutter test suite passes without compilation or layout assertion errors.
