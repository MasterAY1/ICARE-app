# Regression Protocol

## REG-001: Every Fix Must Prove It Did Not Break Downstream Invariants

**Status:** MANDATORY

After every code change, the agent MUST verify:

### Financial Invariants
- [ ] `SUM(Ledger Debits) == SUM(Ledger Credits)` globally
- [ ] Account 1000 net balance per branch is non-negative and reconciles to expected vault cash
- [ ] No new orphaned operational records (operational record exists but Ledger posting is missing)
- [ ] No new ghost Ledger entries (Ledger entry exists but event_store reference is null)

### Projection Invariants  
- [ ] CO Cashbook `closing_balance = opening_balance + total_inflows - total_outflows`
- [ ] Master Cashbook `closing_balance = opening_balance + total_inflows - total_outflows`
- [ ] CO Cashbook totals for branch == relevant Account 1000 officer-level Ledger entries
- [ ] Master Cashbook totals for branch >= CO Cashbook totals (Master includes Treasury/Disbursement)

### Business Invariants
- [ ] Active loans have corresponding `LoanDisbursed` events
- [ ] Repayments have corresponding `RepaymentReceived` events
- [ ] No loan has `start_date == disbursement_date` (unless explicitly required by product)
- [ ] No repayment scheduled on a weekend or holiday
- [ ] Savings balances are non-negative

### Dashboard Invariants
- [ ] "Collection Today" uses the same definition in every dashboard view
- [ ] PAR is calculated from actual portfolio data, not hardcoded
- [ ] No hardcoded financial metric values

## REG-002: Adjacent Scenario Testing

When fixing a bug in one product type or flow, always test at least:
- A different product type (e.g., if fixing Daily 60, also test Weekly 12W)
- A different branch
- A different user role (CO vs BM)
- The same operation with edge-case amounts (₦0, ₦1, large amounts)

## REG-003: Cascading Impact Check

For every fix, ask: "What other component depends on this behavior?"

Use the Business Impact Map to identify all downstream effects.

Example: If `LoanDisbursed` posting logic changes, verify:
- Loan operational status
- CO Cashbook (should NOT have this entry)
- Master Cashbook (should have fund_to_asset/finance)
- Dashboard (active loans count, disbursement amounts)
- Reconciliation (Ledger vs Cashbook)
- Repayment schedule (was it generated?)
- Audit log (was the action logged?)
