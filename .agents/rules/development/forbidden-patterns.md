# Forbidden Patterns

## THE AGENT MUST NEVER GUESS

If the existing implementation conflicts with a business rule:
> DO NOT assume the implementation is correct.

If two tables disagree:
> DO NOT choose whichever value makes the UI look correct.

If the Ledger disagrees with an operational table:
> DO NOT silently synchronize one to the other.

If a business rule is unclear:
> DO NOT invent a rule.

If an event is missing required metadata:
> DO NOT infer it from narration unless the business rule explicitly permits this.

If a transaction cannot be assigned to a branch:
> DO NOT use a default branch.

If a financial posting fails:
> DO NOT mark the operational transaction as successful.

If a projection fails:
> DO NOT delete or modify immutable Ledger history.

If historical data is inconsistent:
> DO NOT automatically repair it.

**STOP. REPORT THE INCONSISTENCY. REQUEST A DECISION.**

---

## Explicitly Forbidden Code Patterns

### FP-001: Hardcoded Branch Fallback
```python
# FORBIDDEN
def _resolve_branch_id(branch_name):
    ...
    return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d"  # default
```
MUST raise an error instead.

### FP-002: Ledger Deletion as Compensation
```python
# FORBIDDEN
try:
    uow.client.table("financial_ledger_entries").delete().eq("transaction_id", tx_id).execute()
except:
    pass
```
MUST raise the original error and leave the Ledger intact.

### FP-003: Nested Unit of Work
```python
# FORBIDDEN
def rebuild_projection(self, branch_id, date):
    with SupabaseUnitOfWork() as uow:  # creates new UOW inside existing pipeline
        ...
```
MUST accept and use the existing UOW.

### FP-004: Operational Table as Financial Source
```python
# FORBIDDEN
loans_res = uow.client.table("loans").select("amount, product_category").execute()
fund_to_asset = sum(l["amount"] for l in loans_res.data if l["product_category"] == "Asset")
```
MUST query Account 1000 Ledger entries instead.

### FP-005: Faked Reconciliation
```python
# FORBIDDEN
dashboard_total = master_cashbook_total
reports_total = master_cashbook_total
```
MUST query each source independently.

### FP-006: Hardcoded Dashboard Metrics
```python
# FORBIDDEN
return {"today_collections": 3500000.0, "par": "0.0%"}
```
MUST calculate from actual data.

### FP-007: Silent Exception Swallowing in Financial Pipelines
```python
# FORBIDDEN
try:
    post_financial_event(...)
except Exception:
    pass  # silently continues
```
MUST propagate or explicitly handle with logging and state rollback.

### FP-008: Same-Day Repayment Start
```python
# FORBIDDEN
loan.start_date = disbursement_date  # first repayment on disbursement day
```
MUST calculate first repayment from the next valid meeting/collection day.

### FP-009: Holiday Week Skip
```python
# FORBIDDEN
if is_holiday(due_date):
    due_date += timedelta(weeks=1)  # skips entire week
```
MUST shift to the next working day, not skip a full period.

### FP-010: "While I'm Here" Improvements
```text
# FORBIDDEN
"While I'm fixing this bug, I'll also refactor the fee structure."
"I noticed this could be improved, so I'll change it too."
```
MUST only change what is explicitly approved. Unrelated improvements require separate approval.
