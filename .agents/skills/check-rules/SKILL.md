---
name: check-rules
description: Mandatory skill to discover, check, and strictly enforce all available architectural invariants, accounting rules, business rules, and development protocols across the ICARE codebase before proposing or modifying any code. Activate whenever @rules or rules are mentioned, or before making code changes, designing solutions, diagnosing bugs, or evaluating financial transactions and ledger integrity.
---

# ICARE Rules Enforcement Skill

## Overview
This skill provides the mandatory protocol for discovering, reading, and enforcing all system invariants, architectural standards, and business rules defined in `.agents/rules/`.

Whenever the user references `@rules:` or asks to check rules, you MUST execute this protocol before writing or proposing code changes.

---

## 1. Complete Rule Inventory & Reference Map

All authoritative rules are stored under `.agents/rules/`. Before modifying any module, consult the relevant rule files:

### A. Mandatory Constitution
- **[00-READ-FIRST.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/00-READ-FIRST.md)**: Authoritative governance constitution, core invariants, and change protocol entry point.

### B. Architecture Rules (`.agents/rules/architecture/`)
- **[source-of-truth.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/architecture/source-of-truth.md)**: Defines Account `1000` (`financial_ledger_entries`) as the sole financial truth for vault cash.
- **[transaction-atomicity.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/architecture/transaction-atomicity.md)**: Rules for atomic execution via database RPCs (`atomic_execute_operations`), failure closing, and immutability.
- **[event-sourcing.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/architecture/event-sourcing.md)**: Event payloads, domain event types, aggregate mapping, and event store appending.
- **[projection-rules.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/architecture/projection-rules.md)**: Invariants governing CO Cashbook (`co_cashbooks`) and Master Cashbook (`master_cashbook`) derived projections.

### C. Business Rules (`.agents/rules/business-rules/`)
- **[ACCOUNTING_RULES.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/ACCOUNTING_RULES.md)**: Double-entry debit/credit rules, Chart of Accounts, and Account 1000 physical cash movements.
- **[CASHBOOK_RULES.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/CASHBOOK_RULES.md)**: Inflow/Outflow classification, opening/closing balance formulas (`BR-CASH-001` - `005`), and product cycle routing.
- **[SAVINGS_RULES.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/SAVINGS_RULES.md)**: Individual savings, group savings, LAPS savings, automatic deductions, and withdrawal approval lifecycle (`BR-SAV-001` - `006`).
- **[DASHBOARD_AND_REPORTING_RULES.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/DASHBOARD_AND_REPORTING_RULES.md)**: Dashboard data source authority (`BR-DASH-001` - `006`), separation of savings from loan repayments, and portfolio calculations.
- **[FEE_RULES.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/FEE_RULES.md)**: Fee structures (Markup 11%/20%, Contingency, Processing Fee, Passbook, Credit Form Damage, Bonus, etc.).
- **[RECONCILIATION_RULES.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/RECONCILIATION_RULES.md)**: 6-way independent reconciliation, orphan detection, and balance integrity verification.
- **[ERROR_CORRECTION_RULES.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/ERROR_CORRECTION_RULES.md)**: Reversal transactions, non-destructive error corrections, and audit trailing.

### D. Development & Verification Protocols (`.agents/rules/development/`)
- **[change-protocol.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/development/change-protocol.md)**: The mandatory 12-step pre-implementation analysis and flow tracing.
- **[forbidden-patterns.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/development/forbidden-patterns.md)**: "THE AGENT MUST NEVER GUESS" and forbidden antipatterns (`FP-001` to `FP-010`).
- **[regression-protocol.md](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/development/regression-protocol.md)**: Post-implementation verification checklist and downstream invariant testing.

---

## 2. Mandatory Protocol: When `@rules:` Is Triggered

When executing any task or modifying any file:

### Step 1: Identify Domain & Read Governing Rules
1. Identify the domain of the task (e.g., Collection, Savings, Loan Origination, Cashbook, Dashboard, Accounting, Auth).
2. Call `view_file` on `00-READ-FIRST.md` and the relevant rule files listed above.

### Step 2: Trace End-to-End Flow
Trace the exact sequence:
`UI Input → Service / Engine → Operational Tables → Domain Events → Financial Posting Engine → Ledger (Account 1000) → Projection Builders → Read Tables / Dashboards`

### Step 3: Check Non-Negotiable Core Invariants
- [ ] **Financial Truth**: Does this touch physical vault cash? If yes, it MUST debit or credit Account 1000 in `financial_ledger_entries`.
- [ ] **Zero Guessing / Fail-Closed**: No hardcoded branch IDs (`FP-001`), no silent fallbacks. Unresolvable identities must throw explicit exceptions.
- [ ] **Atomicity**: Multi-write financial flows must be wrapped in atomic database RPCs (`atomic_execute_operations`).
- [ ] **Immutability**: Never delete or update posted ledger transactions as compensation (`FP-002`).
- [ ] **Amortization Dates**: First loan repayment due date starts on the NEXT valid collection/meeting day after disbursement. Disbursement date ≠ First repayment date (`FP-008`).
- [ ] **Projections**: CO Cashbook and Master Cashbook MUST derive physical cash strictly from Account 1000 entries (`FP-004`).
- [ ] **Savings & Repayment Separation**: Savings deposits must NEVER be merged into loan repayment amounts (`repayments.amount_paid`).

### Step 4: Propose Minimal Architectural Fix & Request Approval
- Create or update the `implementation_plan.md` artifact outlining the exact rule IDs governed.
- DO NOT patch symptoms. Address the root invariant violation at the earliest point in the flow.

### Step 5: Post-Implementation Verification
- Run automated unit and integration tests.
- Rebuild projections and verify balances against ICARE formulas.
- Clean all test data after verification.
