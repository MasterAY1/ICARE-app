# Business Date Rules

## BR-BDATE-001
- **Name:** ICARE Business Date Standard
- **Description:** Financial operations use ICARE business date, NOT system timestamp.
- **Required Behavior:** All financial transactions and calculations must be tied to the current business date of the branch.
- **Prohibited Behavior:** Do not use `current_date` or `now()` system timestamps for recording financial periods.
- **Related Entities:** Business Date Service, Financial Transactions
- **Status:** Active
- **Implementation Location:** `services/business_date_service.py`

## BR-BDATE-002
- **Name:** Business Date Storage
- **Description:** Business date is stored in `branches.cashbook_defaults` JSONB.
- **Required Behavior:** Read and write the current business date from the branch configuration.
- **Prohibited Behavior:** Do not hardcode or store the business date in arbitrary locations.
- **Related Entities:** Branches
- **Status:** Active
- **Implementation Location:** `services/business_date_service.py`, `branches` table

## BR-BDATE-003
- **Name:** Business Date Advancement
- **Description:** Business date advances when Branch Manager (BM) closes the day.
- **Required Behavior:** Increment the business date to the next valid working day upon EOD closure.
- **Prohibited Behavior:** Do not advance the business date automatically at midnight.
- **Related Entities:** End of Day, Business Date Service
- **Status:** Active
- **Implementation Location:** `services/business_date_service.py`

## BR-BDATE-004
- **Name:** Working Day Validation
- **Description:** Working Day validation excludes weekends, Nigerian public holidays, custom branch closures.
- **Required Behavior:** Check against a defined calendar of holidays and weekends when determining valid business days.
- **Prohibited Behavior:** Do not treat every sequential calendar day as a working day.
- **Related Entities:** Branch Closures, Calendar
- **Status:** Active
- **Implementation Location:** `services/business_date_service.py`, `branch_closures` table

## BR-BDATE-005
- **Name:** Schedule Adjustment
- **Description:** Schedule dates adjust to the next working day if they fall on a non-working day.
- **Required Behavior:** Roll forward any scheduled payments or events to the next valid business date.
- **Prohibited Behavior:** Do not schedule obligations on holidays or weekends.
- **Related Entities:** Loan Schedules, Business Date Service
- **Status:** Active
- **Implementation Location:** `services/business_date_service.py`

## BR-BDATE-006
- **Name:** Branch Close Process
- **Description:** Branch Close freezes CO and Master cashbooks (status='Closed'), advances date, and carries closing balance forward.
- **Required Behavior:** Lock the day's cashbooks to prevent further postings during the EOD routine.
- **Prohibited Behavior:** Do not allow new backdated transactions to an already closed business date.
- **Related Entities:** EOD Closure, CO Cashbook, Master Cashbook
- **Status:** Active
- **Implementation Location:** `services/business_date_service.py`, `co_cashbooks`, `master_cashbook`
