# Page-document authority status

`MIGRATION_AUTHORITY.md` and `ZERO_REDESIGN_CONSTITUTION.md` are the governing contracts. This index records the authoritative parity status of every route. A page is marked `PARITY VERIFIED` only after visual, functional, real backend data, validation, and RBAC checks pass.

| Document | Streamlit Source | Authority Status | Backend API Contract Status | Parity Notes |
|---|---|---|---|---|
| `00_login.md` | `auth/login.py` L1–102 | **PARITY VERIFIED** | Live (`/api/v1/auth/login`) | Authenticated session & RBAC shell verified. |
| `01_dashboard.md` (CO) | `app.py` L2383–2458 | **PARITY VERIFIED** | Live (`/api/v1/co/dashboard`) | Backed by `DashboardService.get_co_dashboard_data`. |
| `02_loan_origination.md` | `app.py` L2460–4050 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | All mock data & client calculations removed. Requires `POST /api/v1/clients/register`, `POST /api/v1/loans/apply`, `GET /api/v1/loans/simulate`, `GET /api/v1/loans/pending`. |
| `03_collections.md` | `app.py` L4051–5157 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | All mock data & client calculations removed. Requires `GET /api/v1/collections/sheet`, `POST /api/v1/collections/batch-post`, `POST /api/v1/collections/reversal-request`. |
| `04_withdrawal_operations.md` | `app.py` L5158–5588 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | All mock balances & requests removed. Requires `GET /api/v1/withdrawals/client-balance/{id}`, `POST /api/v1/withdrawals/process`. |
| `05_portfolio.md` | `app.py` L8599–9299 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | All mock client arrays removed. Requires `GET /api/v1/portfolio/overview`, `GET /api/v1/portfolio/client/{id}/dossier`, `POST /api/v1/portfolio/client/{id}/status-update`. |
| `06_co_cashbook.md` | `app.py` L7200–7648 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | Client-side calculations removed. Requires `GET /api/v1/cashbook/co/daily`, `POST /api/v1/cashbook/co/eod`, `POST /api/v1/cashbook/co/reversal-request`. |
| `07_master_cashbook.md` | `app.py` L7649–8598 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | Baseline documented; awaiting backend contracts for tabs 1–3 and EOD Day Close. |
| `08_audit_ledger.md` | `app.py` L6588–7199 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | Requires transaction audit and forensic query endpoints. |
| `09_user_management.md` | `app.py` L9488–9929 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | Requires user provisioning and branch assignment endpoints. |
| `10_reports_export.md` | `app.py` L9344–9487 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | Requires reporting queries and document generation. |
| `11_legacy_laps_migration.md` | `app.py` L5589–5665 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | Requires migration ingestion endpoints. |
| `12_calculator.md` | `app.py` L9300–9343 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | Requires server-side calculation contract. |
| `13_daily_report.md` | `app.py` L5666–5910 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | Source route only; not sidebar-exposed. |
| Missing: Audit Ledger Legacy | `app.py` L5911–6300 | **PARITY NOT VERIFIED** | **MISSING API CONTRACT** | Source route only; not sidebar-exposed. |
