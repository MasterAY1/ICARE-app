# ICARE System Rules & Governance

> [!IMPORTANT]
> **MANDATORY GOVERNANCE DIRECTIVE**:
> Whenever `@rules` or any rule requirement is mentioned, or before making any architectural decisions, bug diagnoses, or code modifications, the agent MUST read and strictly adhere to all authoritative rules in `.agents/rules/` and follow the `check-rules` and `business-impact-analysis` skills.

## 1. Governance Rules Directory
- Mandatory entry point: [`.agents/rules/00-READ-FIRST.md`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/00-READ-FIRST.md)
- Architecture: [`.agents/rules/architecture/`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/architecture/)
- Business Rules: [`.agents/rules/business-rules/`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/)
- Development Protocols: [`.agents/rules/development/`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/development/)

## 2. Core Non-Negotiable Invariants
1. **Account 1000 is the Financial Source of Truth**: Physical vault cash positions must come from `financial_ledger_entries` (Account 1000), not operational tables.
2. **Never Guess / Fail Closed**: Do not hardcode branch fallbacks (`FP-001`) or infer missing metadata without explicit permission.
3. **Atomic Operations**: Operational writes and financial postings must succeed or fail together atomically via RPCs (`atomic_execute_operations`).
4. **Ledger Immutability**: Never delete or update posted ledger transactions as compensation (`FP-002`). Corrections require reversing entries.
5. **Repayment Schedule Start Date**: The first loan repayment date starts on the NEXT valid collection/meeting day after disbursement (`FP-008`).
6. **Savings & Repayments Separation**: Savings deposits and loan repayments must be handled independently. Never merge savings into `repayments.amount_paid`.
7. **Projections**: Cashbooks must derive 100% of physical cash movements from Account 1000 journal entries.
