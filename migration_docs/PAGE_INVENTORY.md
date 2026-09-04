# Streamlit page inventory — source-verified amendment

> Authority: follow `MIGRATION_AUTHORITY.md` and `PAGE_DOCUMENT_STATUS.md`. This inventory records routes; it does not certify page parity.

## Correction

The authoritative route list is the `app.py` condition chain. It contains the following distinct authenticated route conditions: `Dashboard`, `Loan Origination`, `Collections`, `Withdrawal Operations`, `Legacy LAPS Migration`, `Daily Report`, `Audit Ledger Legacy`, `Audit Center` / `Audit Ledger`, `CO Cashbook`, `Master Cashbook`, `Portfolio`, `Calculator`, `Reports` / `Reports & Export`, and `User Management`.

The following prior records are incorrect and must not be used as parity evidence:

- `Calculator` title is `Loan Simulator` (`app.py` 9300), not “Loan Schedule Calculator”.
- `Legacy LAPS Migration` title is `🏛️ Legacy LAPS Bulk Migration Console (Super Admin)` (`app.py` 5589).
- User Management uses an HTML heading `🔐 User Management` (`app.py` 9493), not “Staff & User Management”.
- `Daily Report` is a real route (`app.py` 5666) and has its own document at `pages/13_daily_report.md`; it cannot be silently merged into Reports.

Calculator, Daily Report, and Audit Ledger Legacy are source routes but are not present in the current central `ROLE_NAVIGATION` sidebar list.

---

# Superseded inventory content

> **MANDATORY REFERENCE**: Discovered and verified directly from `app.py`, `auth/login.py`, and `services/rbac_scope_service.py`.

---

## 1. Complete Route Inventory

| Page ID | Exact Streamlit Page Title | Sidebar Label | Roles Permitted | Route / Condition | Source File | Line Range | Status |
|---|---|---|---|---|---|---|---|
| `PAGE-00` | **ICARE — Core Banking** | N/A (Unauthenticated) | All (Public) | `not logged_in` | `auth/login.py` | L1–102 | Discovered |
| `PAGE-01` | **Performance & Risk Dashboard** | `Dashboard` | CO, BM, AM, Admin, Director | `if page == "Dashboard":` | `app.py` | L2013–2459 | Discovered |
| `PAGE-02` | **Origination & Registration** | `Loan Origination` | CO, Admin, Director | `elif page == "Loan Origination":` | `app.py` | L2460–4050 | Discovered |
| `PAGE-03` | **Daily Collections** | `Collections` | CO, Admin, Director | `elif page == "Collections":` | `app.py` | L4051–5157 | Discovered |
| `PAGE-04` | **Withdrawal Operations** | `Withdrawal Operations` | CO, Admin, Director | `elif page == "Withdrawal Operations":` | `app.py` | L5158–5588 | Discovered |
| `PAGE-05` | **Legacy LAPS Migration** | `Legacy LAPS Migration` | Admin | `elif page == "Legacy LAPS Migration":` | `app.py` | L5589–5665 | Discovered |
| `PAGE-06` | **Daily Collections Report** | `Daily Report` | BM, AM, Admin (Legacy) | `elif page == "Daily Report":` | `app.py` | L5666–5910 | Discovered |
| `PAGE-07` | **Audit Ledger** / **Audit Center** | `Audit Ledger` | BM, AM, Admin, Director | `elif page in ["Audit Center", "Audit Ledger"]:` | `app.py` | L6588–7199 | Discovered |
| `PAGE-08` | **📖 Credit Officer Daily Cashbook** | `CO Cashbook` | CO, AM, Admin | `elif page == "CO Cashbook":` | `app.py` | L7200–7648 | Discovered |
| `PAGE-09` | **Branch Manager Master Cashbook** | `Master Cashbook` | BM, AM, Admin | `elif page == "Master Cashbook":` | `app.py` | L7649–8598 | Discovered |
| `PAGE-10` | **CO Portfolio** / **Branch Portfolio** / **Regional Portfolio** / **Enterprise Portfolio** | `Portfolio` | CO, BM, AM, Admin, Director | `elif page == "Portfolio":` | `app.py` | L8599–9299 | Discovered |
| `PAGE-11` | **Loan Schedule Calculator** | `Calculator` | Standalone utility | `elif page == "Calculator":` | `app.py` | L9300–9342 | Discovered |
| `PAGE-12` | **Reports & Data Export** | `Reports & Export` | BM, AM, Admin, Director | `elif page in ["Reports", "Reports & Export"]:` | `app.py` | L9343–9487 | Discovered |
| `PAGE-13` | **Staff & User Management** | `User Management` | BM, AM, Admin | `elif page == "User Management":` | `app.py` | L9488–9930 | Discovered |

---

## 2. Dashboard Sub-Dispatches (`PAGE-01`)

Streamlit dispatches 5 distinct functional dashboards under the single `Dashboard` route based on active user role (`app.py` L2034–2458):

1. **Executive Board Dashboard**: Rendered for `Director`, `Executive`, `Board` (L2035–2067)
2. **Global Administrator Dashboard**: Rendered for `Admin`, `Super Admin` (L2068–2128)
3. **Area Manager Dashboard**: Rendered for `AM`, `Area Manager` (L2129–2148)
4. **Branch Manager Dashboard**: Rendered for `BM`, `Branch Manager` (L2149–2382)
5. **Credit Officer Dashboard**: Rendered for `CO`, `Officer`, `Credit Officer` (L2383–2458)
