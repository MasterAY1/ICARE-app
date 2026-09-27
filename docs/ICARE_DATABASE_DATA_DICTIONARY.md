# ICARE Database Data Dictionary & Architecture Reference

> **Governance Notice**: In compliance with ICARE core governance directives (`FP-001`, `FP-002`, `FP-008`), no tables are ever removed or renamed without explicit authorization. All 45 base tables in the PostgreSQL schema are actively categorized and documented below.

---

## 1. Executive Summary & Schema Domains

The ICARE PostgreSQL database (hosted on Supabase) is organized into 5 primary domains:

| Domain | Table Count | Primary Purpose |
|---|---|---|
| **Core Operations** | 16 | Clients, groups, memberships, loan lifecycle, savings accounts, repayments |
| **Financial Ledger** | 8 | Chart of Accounts, atomic journal entries, Account 1000 vault cash, cashbooks |
| **Security & RBAC** | 8 | Branches, zones, app users, roles, permissions, supervisor assignments |
| **Audit & Logs** | 5 | Operational audits, login sessions, collection performance history |
| **System & Events** | 8 | Domain event store, processing deduplication, settings, regions |
| **Curated Views** | 3 | High-level aggregated views for multi-branch monitoring and reporting |

---

## 2. Table Data Dictionary (All 45 Tables)

### Domain 1: Financial Ledger & Source of Truth
*In accordance with Core Invariant 1: Account 1000 is the Financial Source of Truth for physical vault cash.*

| Table Name | Primary Key | Key Foreign Keys | Purpose & Invariants |
|---|---|---|---|
| `chart_of_accounts` | `account_code` | — | Master Chart of Accounts (Account 1000 = Vault Cash, 1010 = Bank, 1200 = Loans, 2000 = Savings). |
| `financial_transactions` | `transaction_id` | `branch_id`, `officer_id` | Atomic double-entry financial transaction headers (journal entries). |
| `financial_ledger_entries` | `entry_id` | `transaction_id`, `branch_id` | Immutable double-entry legs (Debits & Credits). **Strictly immutable (`FP-002`)**. |
| `master_cashbook` | `id` | `branch_id` | Daily branch master cashbook projections and physical vault cash positions. |
| `co_cashbooks` | `id` | `branch_id`, `officer_id` | Credit officer daily collection sheets and settlement summaries. |
| `posting_rules` | `id` | — | Accounting rules governing automated double-entry postings for domain events. |
| `treasury_transactions` | `id` | `branch_id` | Preserved treasury transfer log for bank allocations and vault funding. |
| `fees` | `fee_id` | `loan_id` | Preserved specialized fee registry for historical fee accounting. |

---

### Domain 2: Core Credit & Savings Operations

| Table Name | Primary Key | Key Foreign Keys | Purpose & Invariants |
|---|---|---|---|
| `clients` | `client_id` | `branch_id`, `group_id`, `officer_id`, `status_id` | Registered borrowers, KYC, biometric references, and primary profile details. |
| `client_memberships` | `membership_id` | `client_id`, `group_id`, `branch_id`, `officer_id` | Association connecting clients to solidarity groups with branch isolation. |
| `client_statuses` | `status_id` | — | Authoritative client lifecycle statuses (`Registered`, `On Loan`, `Completed`, `Dormant`, etc.). |
| `client_status_history` | `id` | `client_id`, `status_id`, `changed_by` | Immutable audit trail tracking client lifecycle transitions over time. |
| `groups` | `group_id` | `branch_id`, `officer_id` | Solidarity credit groups, meeting days (Mon–Fri), and officer assignments. |
| `loans` | `loan_id` | `client_id`, `branch_id`, `officer_id`, `product_id` | Master loan contracts, principal amount, total repayable, and balance. |
| `loan_products` | `product_id` | — | Credit product specifications, terms, tenor weeks, and interest structures. |
| `loan_schedule` | `schedule_id` | `loan_id` | Installment repayment schedules starting on next valid collection day (`FP-008`). |
| `repayments` | `repayment_id` | `loan_id`, `branch_id`, `officer_id` | Repayment collection entries, amounts collected, and split allocations. |
| `loan_payoff_excess_records` | `id` | `loan_id`, `client_id`, `branch_id` | Dedicated audit registry for full payoff events and surplus collections (`BR-DASH-005/007`). |
| `individual_savings` | `savings_id` | `client_id`, `branch_id`, `officer_id` | Member individual savings ledger for deposits, withdrawals, and balances. |
| `group_savings` | `savings_id` | `group_id`, `branch_id`, `officer_id` | Communal group savings ledger for meeting collections and disbursements. |
| `internal_savings` | `id` | `branch_id`, `officer_id` | Internal / miscellaneous savings managed per branch. |
| `laps_savings` | `id` | `client_id`, `branch_id` | LAPS savings records, transfers, and payout records. |
| `guarantors` | `guarantor_id` | `client_id` | Guarantor profiles, relationship descriptions, and contact credentials. |
| `loan_guarantors` | `id` | `loan_id`, `guarantor_id` | Cross-reference mapping linking loans to collateral guarantors. |
| `withdrawal_requests` | `request_id` | `client_id`, `branch_id` | Savings withdrawal requests queued for Branch Manager authorization. |
| `correction_requests` | `request_id` | `branch_id`, `requested_by` | Reversal/correction requests requiring Branch Manager approval (`FP-002`). |

---

### Domain 3: Security, Roles & Multi-Branch Architecture

| Table Name | Primary Key | Key Foreign Keys | Purpose & Invariants |
|---|---|---|---|
| `branches` | `branch_id` | `zone_id` | Physical branch offices (`Ogijo`, `Ikorodu`, `Kola`, `Ibadan`, `Head Office`). |
| `zones` | `zone_id` | `region_id` | Zonal groupings for branch network administration. |
| `app_users` | `id` | `branch_id` | Staff profiles, login credentials, and primary branch assignments. |
| `roles` | `role_id` | — | Master system roles (`Admin`, `Branch Manager`, `Area Manager`, `Credit Officer`, `Director`). |
| `user_roles` | `(user_id, role_id)` | `user_id`, `role_id` | Association mapping connecting staff members to system roles. |
| `permissions` | `permission_id` | — | Granular system action permissions. |
| `role_permissions` | `(role_id, permission_id)` | `role_id`, `permission_id` | Association mapping assigning system permissions to roles. |
| `area_manager_assignments` | `id` | `user_id`, `branch_id` | Multi-branch supervisory assignments granting Area Managers multi-branch scope. |
| `branch_closures` | `closure_id` | `branch_id` | Scheduled non-working days, branch holidays, and operational closures. |

---

### Domain 4: Audit & Logs

| Table Name | Primary Key | Key Foreign Keys | Purpose & Invariants |
|---|---|---|---|
| `audit_logs` | `log_id` | `user_id`, `branch_id` | Tamper-evident operational audit log recording entity mutations and events. |
| `audit_log` | `id` | — | Preserved legacy audit table for historical continuity. |
| `login_history` | `id` | `user_id` | Authentication session log capturing IP addresses, devices, and timestamps. |
| `user_audit_logs` | `id` | `user_id` | Secondary user activity logs. |
| `collection_performance` | `id` | `branch_id`, `officer_id` | Aggregated historical officer collection efficiency tracking. |

---

### Domain 5: System, Events & Regional Metadata

| Table Name | Primary Key | Key Foreign Keys | Purpose & Invariants |
|---|---|---|---|
| `event_store` | `event_id` | — | Append-only event store capturing domain events with JSON payloads. |
| `event_processing` | `event_id` | — | Deduplication and status tracker for asynchronous event subscribers. |
| `notifications` | `notification_id` | `user_id` | Staff notification dispatch queue. |
| `settings` | `key` | — | System-wide configuration key-value pairs. |
| `regions` | `region_id` | — | Regional geographical hierarchy reference. |
| `staff_salaries` | `salary_id` | `user_id` | Preserved staff salary schedule registry. |

---

## 3. Curated Database Views

To ensure clean and immediate clarity in Supabase Studio and backend queries, the following views provide human-readable aggregations:

### 1. `v_branch_portfolio_summary`
Aggregates key operational and financial figures per physical branch:
- **Columns**: `branch_id`, `branch_code`, `branch_name`, `is_active`, `total_staff`, `total_groups`, `total_clients`, `vault_cash_balance` (from Account 1000).
- **Use Case**: Executive dashboard for Area Managers, Directors, and Supabase Studio overview.

### 2. `v_staff_directory_by_branch`
Consolidates staff members with their branch assignment and active role:
- **Columns**: `user_id`, `username`, `full_name`, `role_name`, `branch_id`, `branch_name`, `branch_code`, `is_active`, `created_at`.
- **Use Case**: User management, HR oversight, and branch assignment verification.

### 3. `v_active_loans_directory`
Full relational view joining borrower KYC, credit group, branch, loan balance, and officer:
- **Columns**: `loan_id`, `client_id`, `client_code`, `client_name`, `client_phone`, `group_id`, `group_name`, `meeting_day`, `branch_id`, `branch_name`, `officer_name`, `principal_amount`, `total_repayable`, `total_paid`, `outstanding_balance`, `loan_status`, `disbursement_date`, `expected_end_date`.
- **Use Case**: Portfolio auditing, delinquency tracking, and collection reconciliations.

---

## 4. Multi-Branch Verification & Operational Testing Data

| Branch | Code | Branch ID | Primary Staff | Active Groups | Clients | Vault Cash Float |
|---|---|---|---|---|---|---|
| **Ogijo** | `OGI` | `997d504e-7f5c-4772-887d-fdd5a4c1183b` | `BM_Ogijo`, `CO1`, `CO2`, `CO3`, `CO4` | 51 Groups | 423 | Historical operational |
| **Ikorodu** | `IKD` | `4ab6e1c4-6783-4bb6-904f-9da51cfab505` | `BM_Ikorodu`, `CO_Ikorodu` | 2 Groups (`Ikorodu Central Traders`, `Ayangburen Market Group`) | 4 | ₦500,000.00 (Balanced journal entry) |
| **Head Office** | `HO` | `1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d` | `admin` | — | — | Funding account (Account 1010) |
| **Kola** | `KOL` | `dd09c735-3b1e-4eeb-89a8-d27a85e02156` | — | — | — | Ready for expansion |
| **Ibadan** | `IBA` | `7ca8250a-9077-4bef-8cf3-78cf26c30705` | — | — | — | Ready for expansion |
