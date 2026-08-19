# Change Protocol

## BEFORE MODIFYING CODE

Every code change MUST follow this protocol. No exceptions.

### Step 1: Identify
1. Identify the business operation involved.
2. Identify the authoritative business rule (cite the Rule ID from `.agents/rules/business-rules/`).
3. Identify the authoritative source of truth (Ledger, operational table, or projection).

### Step 2: Trace the Complete Flow
Trace the COMPLETE data flow for the affected operation:

```
UI
 → Service
   → Operational Record
     → Domain Event
       → Posting Rule
         → Ledger Entry
           → Projection Rebuild
             → CO Cashbook
               → Master Cashbook
                 → Dashboard / Report
```

### Step 3: Identify All Affected Components
- List every table affected.
- List every downstream projection affected.
- List every dashboard metric affected.
- List every report affected.

### Step 4: Classify the Bug
Determine whether the reported issue is:
- Business-rule violation (code contradicts a documented business rule)
- Accounting violation (Ledger entries are incorrect or missing)
- Data-integrity violation (orphaned records, partial commits)
- Projection violation (Cashbook/Dashboard shows wrong values from correct Ledger data)
- UI/state bug (display issue, session state, component rendering)
- Test bug (test asserts wrong behavior)

### Step 5: Find the Root Cause
DO NOT PATCH THE SYMPTOM.

Find the EARLIEST point in the flow where the business invariant is violated.

### Step 6: Propose the Fix
Propose the smallest architectural correction that restores the invariant without changing unrelated business behavior.

### Step 7: Pre-Implementation Checklist
Before writing any code, list:
- [ ] Files to change
- [ ] Files that MUST NOT change
- [ ] Database changes (migrations, RPCs)
- [ ] Existing rules affected
- [ ] Possible regressions
- [ ] Tests required
- [ ] Business Impact Map entries affected

### Step 8: Request Approval
Present the diagnosis and proposed fix. WAIT FOR EXPLICIT APPROVAL.

### Step 9: Implement
Only after approval, implement the approved changes.

---

## AFTER MODIFYING CODE

### Post-Implementation Verification

1. Run targeted unit tests.
2. Run affected integration tests.
3. Run financial reconciliation checks:
   - [ ] Ledger balance: total debits == total credits
   - [ ] Account 1000 net balance per branch
   - [ ] CO Cashbook totals match Account 1000 officer-level entries
   - [ ] Master Cashbook totals match Account 1000 branch-level entries
   - [ ] Master Cashbook == sum(CO Cashbooks) + branch-level treasury/disbursement
4. Check affected dashboard metrics.
5. **Mandatory UI & Interactive State Verification**:
   - [ ] Verify tab routing and session state keys match exact string literals.
   - [ ] Verify form controls, inputs, validation error alerts, and submit buttons.
   - [ ] Verify dropdowns, filters, and dynamic selections update reactively.
   - [ ] Verify typography, formatting (`₦{:,.2f}`), and emoji compliance (`👤` preserved, buttons clean).
   - [ ] Verify cross-role UI visibility (CO vs BM vs AM vs Admin).
6. Test the ORIGINAL reported scenario.
7. Test at least TWO adjacent scenarios (e.g., different product types, different branches).
8. Report any remaining discrepancy.

### Success Criteria

**NEVER declare a fix successful merely because the original error disappeared.**

A fix is successful ONLY when:
- The original error is resolved.
- All UI components, tab routings, and form controls are confirmed working and cleanly formatted.
- All downstream business invariants are preserved.
- No new orphaned records exist.
- Ledger balance remains balanced.
- Cashbook projections reconcile to the Ledger.
- No unrelated behavior has changed.
