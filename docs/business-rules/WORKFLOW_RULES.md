# Workflow Rules

## BR-WF-001
**Name:** Canonical Loan Workflow
**Description:** The standard sequence of steps from application to collections.
**Required Behavior:** The workflow must strictly follow: Client selection → Guarantor assignment → Application submission → Product selection/calculations → Branch Manager Approval → Disbursement → Schedule generation → Collections.
**Prohibited Behavior:** Bypassing any of the mandated steps in the loan origination and lifecycle process.
**Related Entities:** Client, Guarantor, Loan, User (BM, CO).
**Status:** Confirmed.
**Implementation Location:** Application wide workflow orchestration.

## BR-WF-002
**Name:** Withdrawal Workflow
**Description:** Process for handling savings and other withdrawals.
**Required Behavior:** A Credit Officer submits a withdrawal request, the Branch Manager approves or rejects it, and upon approval, the system executes the specified transaction type (Cash Withdrawal, Loan Offset, LAPS Transfer, LAPS Payout).
**Prohibited Behavior:** Execution of a withdrawal without Branch Manager approval.
**Related Entities:** Withdrawal Request, User (CO, BM), Transaction/Ledger.
**Status:** Confirmed.
**Implementation Location:** Withdrawal services/modules.

## BR-WF-003
**Name:** EOD (End of Day) Workflow
**Description:** Process for daily reconciliation and cashbook updates.
**Required Behavior:** The Credit Officer enters global fees/collections, the system saves these to repayments, and the cashbook projection rebuilds to reflect the daily activities.
**Prohibited Behavior:** Failing to rebuild cashbook projections after daily repayments are saved.
**Related Entities:** Repayment, Cashbook, User (CO).
**Status:** Confirmed.
**Implementation Location:** EOD/Reconciliation modules.

## BR-WF-004
**Name:** Branch Close Workflow
**Description:** The process for finalizing a business day at a branch.
**Required Behavior:** The Branch Manager initiates day close. The system must freeze CO and Master cashbooks, set the next day's opening balance to today's closing balance, and advance the business date.
**Prohibited Behavior:** Allowing further transactions on a closed day or failing to carry forward balances correctly.
**Related Entities:** Branch, Cashbook, System Date.
**Status:** Confirmed.
**Implementation Location:** Branch management/EOD services.

## BR-WF-005
**Name:** Bulk Onboarding Workflow
**Description:** Process for onboarding multiple clients and data via Excel.
**Required Behavior:** An Admin uploads an Excel file. The system must parse the file and correctly create records for clients, groups, loans, and savings.
**Prohibited Behavior:** Partial imports without rollback on failure, or bypassing validation rules during import.
**Related Entities:** Client, Group, Loan, Savings, User (Admin).
**Status:** Confirmed.
**Implementation Location:** Bulk import/Admin services.

## BR-WF-006
**Name:** Transaction Reversal Workflow
**Description:** Process for correcting erroneous transactions.
**Required Behavior:** A Manager must post a negative mirror entry to reverse an error. The ledger must self-correct based on this double-entry reversal.
**Prohibited Behavior:** Hard deleting ledger entries or modifying existing immutable transaction records.
**Related Entities:** Ledger, Transaction, User (Manager).
**Status:** Confirmed.
**Implementation Location:** Ledger/Transaction services.
