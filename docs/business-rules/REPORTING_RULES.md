# Reporting Rules

## Rules

### BR-RPT-001
**Name:** Dashboard Data Authority
**Description:** Ensures dashboards reflect actual, authoritative data.
**Required Behavior:** Dashboards must calculate from authoritative operational data tables/views.
**Prohibited Behavior:** Dashboards must not use ad-hoc loops or manual recalculations from UI layers.
**Related Entities:** Dashboard, Data View
**Status:** Confirmed
**Implementation Location:** `services/dashboard_service.py`

### BR-RPT-002
**Name:** Metric Definition Requirements
**Description:** Strict requirement for defining any financial metric.
**Required Behavior:** Every financial metric must have a explicitly documented source, calculation formula, filter criteria, and business date rule.
**Prohibited Behavior:** Undocumented, ad-hoc metrics in reports.
**Related Entities:** Financial Metric, Report
**Status:** Confirmed
**Implementation Location:** `services/dashboard_service.py`, `services/financial_reconciliation_service.py`

### BR-RPT-003
**Name:** Portfolio at Risk (PAR) Calculation
**Description:** Defines the formula for calculating Portfolio at Risk.
**Required Behavior:** Portfolio at Risk (PAR%) must be calculated as: `(Total Overdue / Total Active Credit) × 100`.
**Prohibited Behavior:** Deviating from the standard PAR% formula.
**Related Entities:** Loan Portfolio, Loan Account, Dashboard
**Status:** Confirmed
**Implementation Location:** `services/dashboard_service.py`

### BR-RPT-004
**Name:** Collection Performance Tracking
**Description:** Tracks how well collections are performing at the meeting level.
**Required Behavior:** Collection Performance must track Paid, Part Payment, and Not Paid statuses per client per meeting.
**Prohibited Behavior:** Aggregating collection performance without client/meeting granularity.
**Related Entities:** Collection, Meeting, Client
**Status:** Confirmed
**Implementation Location:** `domain/entities/collection_performance.py`

### BR-RPT-005
**Name:** Compliance Percentage Calculation
**Description:** Defines the formula for calculating meeting compliance.
**Required Behavior:** Compliance % must be calculated as: `(Paid meetings / Total expected meetings) × 100`.
**Prohibited Behavior:** Excluding expected meetings from the denominator.
**Related Entities:** Meeting, Collection
**Status:** Confirmed
**Implementation Location:** `domain/entities/collection_performance.py`

### BR-RPT-006
**Name:** 6-Way Financial Verification
**Description:** Ensures data consistency across all financial views.
**Required Behavior:** The system must implement a 6-Way Financial Verification process reconciling: GL, Audit Views, CO Cashbooks, Master Cashbook, Dashboard, and Reports.
**Prohibited Behavior:** Generating reports with irreconcilable discrepancies between these 6 sources.
**Related Entities:** GL, Audit View, Cashbook, Dashboard, Report
**Status:** Confirmed
**Implementation Location:** `services/financial_reconciliation_service.py`

### BR-RPT-007
**Name:** Historical Record Inclusion
**Description:** Requirements for comprehensive historical reporting.
**Required Behavior:** Reports must accurately account for all historical records, including completed loans, historical repayments, and past fees.
**Prohibited Behavior:** Reports dropping closed or historical accounts from relevant aggregates.
**Related Entities:** Report, Loan Account, Transaction
**Status:** Confirmed
**Implementation Location:** `services/dashboard_service.py`

### BR-RPT-008
**Name:** Client Risk Rating Tiers
**Description:** Defines the client risk rating percentage thresholds.
**Required Behavior:** Client Risk Rating must use the following tiers: ≥95% Excellent, ≥85% Good, ≥70% Fair, ≥50% Risky, <50% High Risk.
**Prohibited Behavior:** Using arbitrary rating names or alternative percentage thresholds.
**Related Entities:** Client, Risk Rating
**Status:** Confirmed
**Implementation Location:** `domain/entities/client_risk_rating.py`

### BR-RPT-009
**Name:** Upgrade Eligibility Requirements
**Description:** Defines criteria for a client to be eligible for loan upgrades.
**Required Behavior:** Upgrade eligibility strictly requires an 'Excellent' rating (≥95%) AND zero consecutive misses.
**Prohibited Behavior:** Suggesting or allowing upgrades for clients not meeting both criteria.
**Related Entities:** Client, Loan Account, Risk Rating
**Status:** Confirmed
**Implementation Location:** `domain/entities/client_risk_rating.py`
