# ICARE Streamlit → Flutter parity authority

## 1. Purpose and source precedence

This file governs the 1:1 Flutter migration. It is a replication contract, not a redesign brief.

When sources disagree, use this order:

1. Current executable Streamlit behavior in `app.py` and its imported authentication/router code.
2. `services/rbac_scope_service.py` for the role menu and page permission boundary.
3. The relevant Streamlit service/repository/Unit-of-Work call for workflow and data behavior.
4. ICARE rules in `.agents/rules/` for business, ledger, projection, and RBAC invariants.
5. This `migration_docs` directory, which must be corrected whenever 1–4 change.

Flutter code is never evidence that Streamlit has a control, label, card, endpoint, or workflow. Flutter must instead reproduce the proven Streamlit reference.

## 2. Non-negotiable parity rules

- Preserve exact displayed labels, page titles, tab/radio option order, table-column order, form field order, validation, success/error text, role visibility, and workflow order.
- Preserve the sidebar menu exactly as returned by `RBACScopeService.get_permitted_menu_items`; do not add a source route to navigation merely because a Flutter screen exists.
- Dynamic business values must be supplied by real backend data. No fixtures, placeholder balances, or invented Flutter calculations.
- A missing transport/API is **MISSING API CONTRACT**, not permission to create a fake response or alter a workflow.
- The Streamlit page’s operation/service remains the behavioral contract. Flutter must not duplicate financial posting, cashbook projection, repayment scheduling, or reversal logic client-side.

## 3. Exact current role navigation

| Role | Menu labels, in exact order |
|---|---|
| CO | `Dashboard`, `Loan Origination`, `Collections`, `Withdrawal Operations`, `Portfolio`, `CO Cashbook` |
| Branch Manager | `Dashboard`, `Portfolio`, `Master Cashbook`, `User Management`, `Audit Ledger`, `Reports & Export` |
| Area Manager | `Dashboard`, `Portfolio`, `Master Cashbook`, `CO Cashbook`, `User Management`, `Audit Ledger`, `Reports & Export` |
| Admin | `Dashboard`, `Portfolio`, `Loan Origination`, `Collections`, `Withdrawal Operations`, `Legacy LAPS Migration`, `CO Cashbook`, `Master Cashbook`, `User Management`, `Audit Ledger`, `Reports & Export` |
| Director | `Dashboard`, `Portfolio`, `Loan Origination`, `Collections`, `Withdrawal Operations`, `Audit Ledger`, `Reports & Export` |

`Calculator`, `Daily Report`, and `Audit Ledger Legacy` are present in `app.py` route conditions but are not in this current sidebar contract. They must be catalogued and resolved deliberately before a Flutter route is exposed.

## 4. Route-to-feature contract

Each feature may be split into presentation, state/controller, data, and domain files, but that split must not change the Streamlit UI contract.

| Streamlit route | Current exact title / role behavior | Flutter feature boundary | Current Flutter status |
|---|---|---|---|
| Login | authentication route from `auth/login.py` / router | `features/auth` | Screen exists; parity requires separate visual and behavior review |
| Dashboard | `Performance & Risk Dashboard`; role-specific body | role-specific dashboard features | CO screen exists; other roles not present in current `lib` tree |
| Loan Origination | `Origination & Registration` | `features/origination` | Not implemented |
| Collections | `Daily Collections` | `features/collections` | Not implemented |
| Withdrawal Operations | `Withdrawal Operations` | `features/withdrawals` | Not implemented |
| Portfolio | role-specific `CO/Branch/Regional/Enterprise Portfolio` title | `features/portfolio` | Not implemented |
| CO Cashbook | `📖 Credit Officer Daily Cashbook` | `features/cashbook/co` | Not implemented |
| Master Cashbook | `Branch Manager Master Cashbook` | `features/cashbook/master` | Not implemented |
| Audit Center / Ledger | role-specific audit title and tabs | `features/audit` | Not implemented |
| Reports & Export | `Reports & Data Export` | `features/reports` | Not implemented |
| User Management | `🔐 User Management` | `features/users` | Not implemented |
| Legacy LAPS Migration | `🏛️ Legacy LAPS Bulk Migration Console (Super Admin)` | `features/laps_migration` | Not implemented |
| Daily Report | `Daily Collections Report` | `features/daily_report` | Source route only; not sidebar-exposed |
| Calculator | `Loan Simulator` | `features/calculator` | Source route only; not sidebar-exposed |
| Audit Ledger Legacy | `📒 Audit Ledger` | `features/audit_legacy` | Source route only; not sidebar-exposed |

## 5. Current Flutter truth

The current Flutter root selects `LoginScreen` or `CoAppScaffold`. `CoAppScaffold` renders the six CO navigation labels but dispatches only `Dashboard` to `CoDashboardScreen`; every other CO navigation selection currently renders the literal placeholder `Page: $page (Awaiting Page Parity Specification & Implementation)`.

Therefore the Flutter project is structured for migration but is **not 1:1 parity-complete**. The existing CO scaffold and dashboard must themselves be compared against the source before they are marked verified.

## 6. Per-page implementation gate

Before marking any Flutter page complete, the corresponding page document must prove:

1. exact title, navigation label, sections, labels, forms, table columns, filters, buttons, and state messages;
2. Streamlit → service → repository → data-source trace for every dynamic field and action;
3. role visibility and read-only behavior;
4. actual backend transport contract or an explicit **MISSING API CONTRACT**;
5. screenshot/interactive comparison against Streamlit at desktop and the approved Flutter target layout.

Until all five pass, mark the page **PARITY NOT VERIFIED**.
