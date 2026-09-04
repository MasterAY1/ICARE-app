# Current Streamlit data-dependency & FastAPI contract catalogue

`MIGRATION_AUTHORITY.md` and `ZERO_REDESIGN_CONSTITUTION.md` are the governing contracts. This catalogue indexes the backend data dependencies, source evidence, and verified FastAPI adapter endpoints.

## 1. Verified FastAPI Adapter Endpoints (Phase 1, Phase 2, and Phase 3 Complete)

The complete suite of Credit Officer endpoints is fully implemented in `api/` and verified with 100% passing automated tests (25/25) in `tests/test_api/`:

| Endpoint | HTTP Method | Streamlit Source (`app.py`) | Domain Service / Repository | RBAC Scope | Verified Contract Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/api/v1/auth/login` | `POST` | `auth/login.py` L1–102 | `AuthService.login`, `uow.users` | Public / All Roles | 🟢 **VERIFIED** |
| `/api/v1/co/dashboard` | `GET` | L2383–2458 | `DashboardService.get_co_dashboard_data` | Scoped Officer / Branch | 🟢 **VERIFIED** |
| `/api/v1/co/portfolio` | `GET` | L8599–9299 | `PortfolioService.get_portfolio_data_for_scope` | Scoped Officer / Branch | 🟢 **VERIFIED** |
| `/api/v1/co/collections/sheet` | `GET` | L4051–4350 | `uow.client.table("clients")`, `uow.loans` | Scoped Officer Solidarity Groups | 🟢 **VERIFIED** |
| `/api/v1/co/collections/batch-submit` | `POST` | L4800–4939 | `save_repayments`, `FinancialPostingEngine.post_event` (Account 1000) | Scoped Officer Group Meeting | 🟢 **VERIFIED** |
| `/api/v1/co/collections/reversal-request` | `POST` | L5062–5157 | `CorrectionService.request_correction` (BR-ERR-001) | Creates `Pending` BM reversal | 🟢 **VERIFIED** |
| `/api/v1/co/cashbook` | `GET` | L7200–7648 | `uow.client.table("co_cashbooks")` (Account 1000) | Scoped Officer Cashbook | 🟢 **VERIFIED** |
| `/api/v1/co/cashbook/eod-adjustments` | `POST` | L7330–7500 | `FinancialPostingEngine.post_event`, `rebuild_projection` | Scoped Officer EOD Ledger | 🟢 **VERIFIED** |
| `/api/v1/co/cashbook/reversal-request` | `POST` | L7563–7648 | `CorrectionService.request_correction` (BR-ERR-001) | Creates `Pending` BM reversal | 🟢 **VERIFIED** |
| `/api/v1/co/withdrawals/individual-options` | `GET` | L5189–5267 | `uow.individual_savings`, `uow.loans` | Scoped Officer Clients | 🟢 **VERIFIED** |
| `/api/v1/co/withdrawals/group-options` | `GET` | L5340–5440 | `uow.group_savings`, `uow.client_memberships` | Scoped Officer Groups | 🟢 **VERIFIED** |
| `/api/v1/co/withdrawals/misc-balance` | `GET` | L5474–5480 | `uow.misc_savings.get_total_balance` | Scoped Branch (Read: CO, Write: BM) | 🟢 **VERIFIED** |
| `/api/v1/co/withdrawals/laps-options` | `GET` | L5511–5538 | `uow.client.table("laps_savings")` | Scoped LAPS Pool | 🟢 **VERIFIED** |
| `/api/v1/co/withdrawals/requests` | `GET` | L5573–5588 | `uow.client.table("withdrawal_requests")` | Scoped User Requests | 🟢 **VERIFIED** |
| `/api/v1/co/withdrawals/request` | `POST` | L5280–5570 | `BusinessDateService`, `withdrawal_requests` | Creates `PENDING` BM request | 🟢 **VERIFIED** |
| `/api/v1/co/origination/register-client` | `POST` | L2562–2800 | `uow.clients.create`, `client_memberships` | Scoped Officer / Branch | 🟢 **VERIFIED** |
| `/api/v1/co/origination/apply` | `POST` | L3412–3794 | `LoanProductEngine`, `uow.loans.create`, `ScheduleService` | Creates `Pending` BM loan | 🟢 **VERIFIED** |

---

## 2. All CO Features Verified — Zero Missing API Contracts for Credit Officer Scope!

All 17 backend API endpoints powering the Streamlit Credit Officer flow (Authentication, Dashboard, Origination, Collections, Withdrawals, Portfolio, and CO Cashbook) are implemented, wired to real domain engines and Account 1000, and verified with 100% test coverage.
