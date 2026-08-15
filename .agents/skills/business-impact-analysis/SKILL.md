---
name: business-impact-analysis
description: Performs forensic business-rule, data-flow, root-cause, and regression-impact analysis for TrustMicro before code changes. Use when investigating incorrect dashboard metrics, portfolio values, cashbook values, reconciliation discrepancies, wrong database columns, incorrect calculations, data-source mismatches, or any bug where changing one part of the system could affect other business areas.
---

# Business Impact Analysis Skill

## What This Skill Does

This skill defines **HOW** to investigate and fix bugs in the TrustMicro system.

It does NOT define business rules or metric definitions. Those live in:

- **Business rules**: `.agents/rules/business-rules/` — WHAT the system is supposed to do.
- **Metric contracts**: `.agents/references/metric-contracts/` — WHAT each number on the UI means.

This skill tells you HOW to trace a problem, determine root cause, assess blast radius, and safely fix it.

---

## Absolute Rules

### 1. Never guess business logic
Check `.agents/rules/business-rules/` before assuming existing code is correct. If code conflicts with a documented rule, the rule wins.

### 2. Do not modify code during investigation
Read, trace, query. Do not edit code, SQL, or database records until the root cause is documented and the user approves.

### 3. Never fix only the visible symptom
If the UI shows a wrong number, do not change the UI. Trace the full pipeline to find where the value first becomes incorrect.

### 4. Always identify the authoritative source
Before changing how a metric is calculated, look up its contract in `.agents/references/metric-contracts/`. If no contract exists, propose one.

---

## Investigation Workflow

### Step 1 — Define the Bug

Record:
- Page / section / metric name
- Current displayed value
- Expected value (if known)
- Date / branch / officer context

If the expected value is unknown, do not invent one.

### Step 2 — Read the Applicable Rules

Before looking at code, read:
1. The relevant file in `.agents/rules/business-rules/`
2. The relevant metric contract in `.agents/references/metric-contracts/`
3. `00-READ-FIRST.md` if architectural invariants may be involved

### Step 3 — Trace the Data Pipeline

Follow the value from display to storage:

```
UI label
→ app.py (page/section)
→ service layer (service function)
→ repository layer (query)
→ database table/column
→ business rule that defines correctness
```

For each stage, record: file, function, input, transformation, output.

### Step 4 — Find the First Point of Divergence

Determine where EXPECTED becomes ACTUAL. Common divergence points:

- Wrong filter (branch, officer, date, status)
- Wrong column (active_credit vs total_due vs outstanding_balance)
- Wrong aggregation (SUM vs COUNT, lifetime vs period)
- Wrong event type or account code
- Stale or missing projection
- Duplicate or missing records
- Hardcoded value
- Incorrect join

---

## Root-Cause Report Template

Before proposing any code change, produce this report:

```
## Bug
What the user observed.

## Expected Behaviour
What the business rules say should happen (cite rule ID).

## Actual Behaviour
What the code actually does.

## Root Cause
The first point where implementation diverges from the rule.

## Evidence
Files, functions, queries, and data that prove the root cause.

## Authoritative Source
Which metric contract or business rule defines correctness.

## Proposed Fix
The smallest safe change that corrects the root cause.

## Blast Radius
- Directly affected: [components changed]
- Indirectly affected: [consumers of changed logic]
- Potentially affected: [shared data/calculations]
- Not affected: [confirmed safe]
- Risk Level: LOW / MEDIUM / HIGH / CRITICAL

## Regression Risks
What could break.

## Required Tests
What to verify before and after.
```

Stop here. Wait for user approval before implementing.

---

## Blast-Radius Analysis

Every proposed fix must answer:

1. **What functions/queries am I changing?** Search all callers.
2. **Do other consumers use the same definition?** If not, do NOT change a shared function blindly.
3. **Does this change affect financial ledger integrity?** Check Account 1000 balance, debit/credit symmetry.
4. **Does this change affect cashbook projections?** Check both CO and Master cashbook projection builders.
5. **Does this change affect dashboard metrics?** Check every dashboard role (CO, BM, AM, Admin, Director).

### Consumer Search Protocol

When you find the source function of a bug, search the entire repository for every caller:

```
grep -rn "function_name" --include="*.py"
```

Classify each caller as: dashboard consumer, portfolio consumer, cashbook consumer, report, reconciliation service, or other.

Never modify a shared function without listing its consumers.

---

## Implementation Mode

Only after explicit user approval:

1. Re-read the investigation report.
2. Re-read affected business rules and metric contracts.
3. Implement the approved change only — no unrelated improvements.
4. Do not silently refactor surrounding code.
5. Preserve existing correct logic.
6. Verify all identified consumers still work correctly.

---

## Post-Implementation Verification

### Data integrity
- No duplicate or missing transactions
- No incorrect branch/officer/date assignment
- No incorrect event classification

### Financial integrity
- Account 1000 debits and credits remain balanced
- Cashbook closing balances remain correct
- Master Cashbook reconciles with CO cashbook aggregation

### UI integrity
- Every identified consumer of the changed logic displays correct values
- Do not declare success because one page looks right

---

## Stop Conditions

Immediately stop and ask the user if:

- Business rules conflict with each other
- Two possible authoritative sources exist for the same metric
- A database migration appears necessary
- Historical data must be modified
- A shared function has consumers with conflicting definitions
- Fixing one metric unexpectedly changes another
- The expected business definition is unclear

Never silently choose one interpretation.
