# MANDATORY OPERATIONAL CONSTITUTION: READ FIRST BEFORE TOUCHING ANY CODE

> [!CAUTION]
> **THIS IS THE AUTHORITATIVE GOVERNANCE CONSTITUTION FOR THE ICARE SYSTEM.**
> Every AI agent and developer working on this repository MUST strictly obey all rules, protocols, and architectural invariants defined in this directory. 
> Passing unit tests or resolving immediate symptoms does NOT constitute a successful task. Success requires total preservation of system-wide business invariants.

---

## 1. Directory Structure & Map

```
.agents/rules/
├── 00-READ-FIRST.md                    <-- YOU ARE HERE (Mandatory Entry Point)
├── architecture/
│   ├── source-of-truth.md              <-- Ledger Account 1000 rules & canonical hierarchy
│   ├── transaction-atomicity.md        <-- Atomic writes, no silent fallbacks, immutability
│   ├── event-sourcing.md              <-- Domain events, event payload completeness
│   └── projection-rules.md             <-- CO & Master Cashbook projection invariants
├── business-rules/
│   ├── ACCOUNTING_RULES.md             <-- Double entry & physical cash principles
│   ├── CASHBOOK_RULES.md               <-- Cashbook operational rules
│   ├── LOAN_RULES.md                   <-- Loan origination & product rules
│   ├── RECONCILIATION_RULES.md         <-- Independent verification & orphan rules
│   ├── DASHBOARD_AND_REPORTING_RULES.md <-- Dashboard source authority & impact map
│   ├── SAVINGS_RULES.md                <-- Savings, LAPS & withdrawal classifications
│   ├── FEE_RULES.md                    <-- Fee categories & splits
│   ├── WORKFLOW_RULES.md               <-- Lifecycle workflows
│   ├── BUSINESS_DATE_RULES.md          <-- Business date advancing & EOD
│   └── ROLE_AND_PERMISSION_RULES.md    <-- RBAC scopes & authorization
└── development/
    ├── change-protocol.md              <-- 12-step pre-implementation protocol
    ├── regression-protocol.md          <-- Post-implementation verification checklist
    └── forbidden-patterns.md           <-- "THE AGENT MUST NEVER GUESS" & anti-patterns
```

---

## 2. Core Business Invariants (Non-Negotiable)

1. **Ledger is the Financial Source of Truth**: Account `1000` in `financial_ledger_entries` represents the authoritative physical CO vault cash position. Operational tables describe business objects; they DO NOT establish financial truth.
2. **One Event Per Cash Movement**: Every physical cash movement is triggered by a Domain Event, recorded by a Posting Rule in the Ledger, and projected to CO & Master Cashbooks.
3. **Atomic Operations**: Operational record writes and financial ledger postings MUST succeed or fail atomically via database transactions/RPCs. No "save first, try ledger later".
4. **No Silent Fallbacks**: Missing IDs, unresolvable branch names, unknown events, or failed postings MUST fail closed with an explicit error. Hardcoded branch fallbacks are strictly prohibited.
5. **Ledger Immutability**: Committed ledger entries MUST NEVER be updated or deleted. Corrections require reversing entries. Projection failure must never rewrite financial history.
6. **Schedule Correctness**: First repayment date begins on the NEXT valid meeting/collection day after disbursement. Disbursement date ≠ first repayment date.
7. **Projection Integrity**: Cashbooks derive 100% of physical cash movements from Account 1000. Master Cashbook MUST NOT query operational tables (`loans`, `treasury_transactions`) independently.
8. **Dashboard & Report Integrity**: All dashboards and reports must query authoritative sources. No hardcoded financial metrics or faked reconciliation totals.

---

## 3. THE AGENT MUST NEVER GUESS

If the existing implementation conflicts with a business rule:
> **DO NOT assume the implementation is correct.**

If two tables disagree:
> **DO NOT choose whichever value makes the UI look correct.**

If the Ledger disagrees with an operational table:
> **DO NOT silently synchronize one to the other.**

If a business rule is unclear:
> **DO NOT invent a rule.**

If an event is missing required metadata:
> **DO NOT infer it from narration unless the business rule explicitly permits this.**

If a transaction cannot be assigned to a branch:
> **DO NOT use a default branch.**

If a financial posting fails:
> **DO NOT mark the operational transaction as successful.**

If a projection fails:
> **DO NOT delete or modify immutable Ledger history.**

If historical data is inconsistent:
> **DO NOT automatically repair it.**

**STOP. REPORT THE INCONSISTENCY. REQUEST A DECISION.**

---

## 4. Change Protocol Summary

### BEFORE MODIFYING CODE:
1. Identify the business operation involved.
2. Identify the authoritative business rule.
3. Identify the authoritative source of truth.
4. Trace the complete flow:
   `UI → Service → Operational Record → Domain Event → Posting Rule → Ledger → Projection → Cashbook → Dashboard/Report`
5. Identify every table affected.
6. Identify every downstream projection affected.
7. Determine whether the reported issue is a business-rule, accounting, data-integrity, projection, UI/state, or test bug.
8. **DO NOT PATCH THE SYMPTOM.**
9. Find the earliest point in the flow where the invariant is violated.
10. Propose the smallest architectural correction that restores the invariant without changing unrelated business behavior.
11. List files to change, files that must NOT change, database changes, existing rules affected, possible regressions, and required tests.
12. **OBTAIN EXPLICIT USER APPROVAL BEFORE CODING.**

### AFTER MODIFYING CODE:
1. Run targeted unit tests.
2. Run affected integration tests.
3. Run financial reconciliation (`verify_6way_financial_integrity`).
4. Check ledger balance (`debits == credits`).
5. Check Account 1000 net position.
6. Check CO Cashbook projections.
7. Check Master Cashbook projections.
8. Check affected dashboard metrics.
9. Test the original scenario again.
10. Test at least two adjacent scenarios.
11. Report any remaining discrepancy.

**NEVER declare a fix successful merely because the original error disappeared. Verify every downstream invariant.**
