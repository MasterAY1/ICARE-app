---
name: business-impact-analysis
description: Performs forensic page-by-page business-rule, data-flow, root-cause, dependency, and regression-impact analysis for ICARE before code changes. Use when auditing any role (CO, BM, AM, Admin, Director), page, section, or metric, resolving data-source mismatches, column mapping discrepancies, reconciliation issues, or evaluating blast radius.
---

# ICARE Business Impact Analysis Skill
## Page-by-Page Data Integrity, Metric Verification, Root-Cause, Dependency & Regression Control

---

## 1. Core Purpose of This Skill

This skill is the authoritative operational protocol for ensuring absolute data integrity, business-rule compliance, and regression safety across the ICARE Banking System.

It operates as a:
- **Business Rule Analyst**: Verifies implementation against codified ICARE business rules.
- **Data Flow Analyst**: Maps end-to-end data transmission from the physical database to the UI.
- **Root Cause Analyst**: Pinpoints the exact origin where correct business logic diverges.
- **Financial Data Integrity Analyst**: Protects General Ledger (`Account 1000`), double-entry balance, and cashbook projections.
- **UI-to-Database Trace Tool**: Audits code line-by-line across presentation, service, repository, and database layers.
- **Dependency / Blast Radius Analyzer**: Identifies all upstream, downstream, and cross-role consumers of modified logic.
- **Regression Prevention System**: Guarantees that fixing one metric never degrades another.

### Primary Governing Question:
> *"Why is this UI value wrong, where did it become wrong, what is the correct ICARE authoritative source, what else depends on it, and what will change if we fix it?"*

**Anti-Reduction Directive**: Never reduce an analysis to *"Change the query until the number looks correct."*

---

## 2. ICARE Business Rule Authority

Always read and strictly adhere to:
1. Mandatory entry point: [`.agents/rules/00-READ-FIRST.md`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/00-READ-FIRST.md)
2. Authoritative business rules: [`.agents/rules/business-rules/`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/)
3. Architectural invariants: [`.agents/rules/architecture/`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/architecture/)
4. Metric contracts & reference baselines: [`.agents/references/metric-contracts/`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/references/metric-contracts/)

### Non-Negotiable Governance Invariants:
- **Business Rules ALWAYS outrank current UI implementations.**
- **Never infer ICARE behavior from generic banking software.** Do not replace ICARE logic with Mambu, Temenos, LAPO, FINCA, Oradian, or any other external banking model.
- Generic banking concepts may be used for UI/UX inspiration **ONLY** when they do not conflict with ICARE business rules.

---

## 3. Page-by-Page Audit Mode

Audits proceed methodically through single-focus units. Every investigation must declare its explicit context:

```text
ROLE:            [CO | BM | AM | Admin | Director | Auditor]
PAGE:            [Dashboard | Portfolio | Field Operations | Cashbook | Audit | Reports | Settings]
SECTION:         [e.g., Executive KPI Banner, Today's Collections Table, Loan Product Summary]
METRIC / FIELD:  [e.g., Collection Today, Outstanding Balance, Active Credit, 12-Week Repayment]
STATUS:          [UNDER_INVESTIGATION | VERIFIED | FIX_PROPOSED | FIX_APPROVED | FIXED | REGRESSION_VERIFIED]
```

**Scope Constraint**: Do not expand the investigation unnecessarily into unrelated features unless blast-radius analysis proves a shared dependency is affected.

---

## 4. Role-Aware Analysis (RBAC Scope Verification)

Every metric investigation must verify that the calculation respects the authenticated user's Role-Based Access Control (RBAC) boundary:

- **Credit Officer (CO)**:
  - Own assigned client portfolio only.
  - Own officer scope (`officer_id` / `credit_officer`).
  - Own daily collections and physical vault custody.
  - Own CO Cashbook projection.
- **Branch Manager (BM)**:
  - Assigned branch boundary (`branch_id`).
  - All credit officers within that branch.
  - Branch-wide portfolio aggregation.
  - Branch Master Cashbook and treasury transactions.
  - Operational approval authority.
- **Area Manager (AM)**:
  - Assigned multi-branch coverage (`assigned_branch_ids`).
  - Regional cross-branch filtering and comparative summaries.
  - Regional portfolio exposure and aggregated cash positions.
- **System Administrator (ADMIN)**:
  - Institution-wide read/write scope across all branches and zones.
  - Global user management, product configuration, chart of accounts.
- **Executive Director (DIRECTOR)**:
  - Institution-wide executive read-only analytics, financial statements, and PAR reports.

**Rule**: A metric can be mathematically accurate but still be **CRITICALLY WRONG** if calculated across the wrong RBAC scope.

---

## 5. Page Data Contract

Every audited metric must produce a structured **Data Contract** before modifying code:

```text
METRIC:                           [Name of Metric]
ROLE:                             [Target Role]
PAGE:                             [Target Page]
SECTION:                          [Target UI Section]

BUSINESS MEANING:                 [Plain English operational definition]
EXPECTED VALUE:                   [Expected numerical/text value with proof]
AUTHORITATIVE SOURCE:             [Source category: Ledger | Event Store | Operational Table | Projection]
AUTHORITATIVE TABLE / PROJECTION: [e.g., financial_ledger_entries, loans, co_cashbooks]
AUTHORITATIVE FIELD:              [e.g., total_due, amount_paid, account_code=1000]
EVENTS INCLUDED:                  [e.g., RepaymentReceived, SavingsDeposited]
EVENTS EXCLUDED:                  [e.g., Historical legacy imports, Non-cash sweeps]
DATE DEFINITION:                  [e.g., Operational Business Date vs Created_at UTC timestamp]
BRANCH SCOPE:                     [Filtered by branch_id | All Branches]
OFFICER SCOPE:                    [Filtered by officer_id | All Officers]
PRODUCT SCOPE:                    [All Products | Specific Loan Product]
CALCULATION:                      [Exact mathematical formula]
DISPLAY FORMAT:                   [e.g., Currency ₦{:,.2f}, Percentage {:.2f}%, Integer]
OTHER CONSUMERS:                  [List of all other pages/services reading this field]
KNOWN DEPENDENCIES:               [Upstream services/repositories]
KNOWN RISKS:                      [Potential regression vectors]
```

---

## 6. Source-of-Truth Identification

For every metric, classify its architectural nature:

1. **Financial Metric (Physical Cash / Vault Liability)**:
   - **Authoritative Source**: `financial_ledger_entries` (`Account 1000` for physical vault cash, `Account 1050` for bank).
   - *Rule*: Never derive physical cash balances from operational tables (`loans`, `repayments`, `treasury_transactions`).
2. **CO Cashbook Projection**:
   - **Authoritative Source**: `co_cashbooks` built strictly from `financial_ledger_entries` (Account 1000) and `event_store`.
3. **Master Cashbook Projection**:
   - **Authoritative Source**: `master_cashbook` aggregating all branch CO cashbooks plus branch treasury events.
4. **Operational Entity State (Lifecycle & Ownership)**:
   - **Authoritative Source**: Operational tables (`loans`, `clients`, `groups`, `loan_products`).
5. **Scheduled Amortization**:
   - **Authoritative Source**: `loan_schedule` generated using business meeting days.
6. **Outstanding / Remaining Loan Balance**:
   - **Authoritative Source**: $\max(0.0, \text{loans.total\_due (baseline)} - \sum \text{post-migration repayments})$.
7. **Savings Balance**:
   - **Authoritative Source**: $\sum(\text{deposits}) - \sum(\text{withdrawals})$ per category (`individual_savings`, `group_savings`, `internal_savings`).
8. **Reporting & Dashboard Aggregation**:
   - **Authoritative Source**: Dedicated service methods respecting RBAC scope and business date filters.

---

## 7. UI → Data Pipeline Trace

Trace every metric through all architectural tiers:

```
UI DISPLAY LABEL
  ↓ (Variable name in UI)
PAGE PRESENTATION LOGIC (`app.py`)
  ↓ (Method invocation & arguments)
SERVICE LAYER (`services/*_service.py`)
  ↓ (Domain logic & transformations)
REPOSITORY LAYER (`database/repositories/*_repository.py`)
  ↓ (SQL query & filter parameters)
DATABASE / PROJECTION TABLE
  ↓ (Underlying schema column & constraints)
RAW DATA / POSTED EVENTS
```

**Audit Checks**:
- Flag if the UI bypasses the service layer and queries the database/DataFrame directly.
- Flag if the UI performs ad-hoc mathematical transformations on unrelated merged DataFrames.
- Flag if column names are renamed inconsistently across layers.

---

## 8. First Point of Divergence

Identify the earliest stage where **EXPECTED ICARE VALUE** becomes **ACTUAL IMPLEMENTED VALUE**:

- **Wrong Filter**: Branch, officer, date range, or status filter missing or misconfigured.
- **Wrong Column**: Using `active_credit` instead of `total_due` as the remaining balance baseline.
- **Wrong Aggregation**: `COUNT` instead of `SUM`, or lifetime cumulative instead of period-filtered.
- **Wrong Event Type / Account Code**: Filtering by wrong event name or chart of accounts code.
- **Wrong Scope**: Querying all branches instead of the officer's assigned scope.
- **Stale Projection**: Cashbook projection not rebuilt after an event was posted.
- **Duplicate / Missing Rows**: Cartesian join or improper group-by aggregation.
- **Hardcoded Value**: Static fallback values embedded in UI or service logic.

*Rule*: Do not identify the UI as the root cause merely because the UI displays the wrong result. Find the first point of divergence in the data pipeline.

---

## 9. Database Column Mapping Audit

When data is correct in the database but appears in the wrong column or fails to render:

```text
SOURCE DB FIELD:       [e.g., loans.total_due]
EXPECTED UI FIELD:     [e.g., Remaining Balance]
ACTUAL UI FIELD:       [e.g., Active Credit / Loan Principal]
MAPPING FILE:          [File where mapping occurs]
MAPPING FUNCTION:      [Function / Transformer name]
ROOT CAUSE:            [Why the field was misrouted]
AFFECTED PAGES:        [All UI pages displaying this mapping]
AFFECTED REPORTS:      [All exports / CSVs containing this field]
```

**Rule**: Never fix a column mapping bug by renaming a UI label unless the mapping logic is correct and only presentation styling was wrong.

---

## 10. Shared Metric Detection & Conflict Flagging

When a metric name (e.g., *"Collection Today"*, *"Active Credit"*, *"Total Savings"*) appears on multiple screens:
1. Search all implementations across CO, BM, AM, Admin, Director, Portfolio, Cashbook, and Audit views.
2. Verify:
   - Do they share the same business definition?
   - Do they read from the same authoritative source?
   - Are their RBAC scopes appropriate for each role?
   - Are their date definitions identical?
3. If two pages use conflicting formulas for the same business metric:
   - **FLAG**: `METRIC DEFINITION CONFLICT`.
   - Resolve to the single authoritative ICARE rule rather than applying quick patches to individual pages.

---

## 11. Blast-Radius Analysis

Every proposed modification must include a complete blast-radius assessment:

```text
DIRECT IMPACT:      [Exact functions, methods, and files being edited]
INDIRECT IMPACT:    [All upstream/downstream callers and consumers]
PAGE IMPACT:        [Which UI pages/views will reflect changes]
ROLE IMPACT:        [Which user roles (CO, BM, AM, Admin, Director) are affected]
DATA IMPACT:        [Which database tables or projections are modified]
ACCOUNTING IMPACT:  [Does Account 1000 or General Ledger balance change?]
CASHBOOK IMPACT:    [Impact on CO Cashbook and Master Cashbook]
REPORTING IMPACT:   [Impact on CSV exports, audit trails, and financial statements]
TEST IMPACT:        [Which unit/regression test suites must be updated or added]
REGRESSION RISK:    [LOW / MEDIUM / HIGH / CRITICAL]
```

---

## 12. Shared Function Protection Protocol

Before modifying any shared method in `services/`, `database/`, or `mappers/`:
1. Search all callers across the repository: `grep_search` across `*.py`.
2. Inspect every consumer page, role, and test file.
3. If two consumers require different business definitions:
   - **DO NOT** blindly edit the shared method.
   - Propose a specialized service method, dedicated projection, or explicit scope parameter.
   - Avoid creating duplicate business logic.

---

## 13. Page-Local vs System-Wide Classification

Classify the issue into one of 10 structural tiers:

- **A. UI Rendering Bug**: Presentation, styling, HTML/CSS container, or badge formatting.
- **B. UI Mapping Bug**: Correct data fetched, but assigned to the wrong DataFrame column.
- **C. Page Calculation Bug**: Page-specific ad-hoc formula error in presentation script.
- **D. Shared Service Bug**: Error inside a core service method in `services/`.
- **E. Repository / Query Bug**: Malformed SQL query, missing join, or incorrect WHERE clause.
- **F. Projection Bug**: Error in projection builders (`co_cashbooks`, `master_cashbook`).
- **G. Database Data Problem**: Missing seed, corrupt foreign key, or legacy data artifact.
- **H. Domain / Business-Rule Problem**: Implementation conflicts with codified ICARE rule.
- **I. Accounting / Ledger Problem**: Imbalance between debits/credits or wrong account code.
- **J. Cross-Page Metric Conflict**: Two views use contradictory definitions for the same metric.

---

## 14. Cumulative Knowledge Management

Findings from earlier audits must be preserved and cross-referenced when moving across roles:

$$\text{Phase A: CO Audit} \longrightarrow \text{Phase B: BM Audit} \longrightarrow \text{Phase C: AM Audit} \longrightarrow \text{Phase D: Admin} \longrightarrow \text{Phase E: Director}$$

### Audit Knowledge Trace Matrix:
$$\text{ROLE} \longrightarrow \text{PAGE} \longrightarrow \text{METRIC} \longrightarrow \text{ROOT CAUSE} \longrightarrow \text{STATUS} \longrightarrow \text{FIX} \longrightarrow \text{IMPACT}$$

*Rule*: When investigating a BM issue, cross-check whether the service, repository, projection, or column mapping was already audited in the CO audit. Fix the root cause at the authoritative source once.

---

## 15. Cross-Page Root Cause Detection

If a bug is discovered in one view:
1. Search if the same source query/field is used in other views.
2. If `loans.active_credit` or `ScheduleService.get_total_paid` is used in both CO Portfolio and BM Dashboard, report a **COMMON ROOT CAUSE**.
3. Fix the underlying service/projection once, and verify all consuming views simultaneously.

---

## 16. Page Completion Rule (10-Point Checklist)

A page is **NOT** complete merely because visible cards display values. A page is verified only when:
1. [ ] Every major metric has a defined Data Contract.
2. [ ] Every metric reads from its Authoritative Source of Truth.
3. [ ] Every underlying query and filter is verified against database records.
4. [ ] RBAC scope filtering is enforced for all roles accessing the page.
5. [ ] Operational Business Date semantics are respected.
6. [ ] Column mappings between DB $\rightarrow$ Service $\rightarrow$ UI are 100% verified.
7. [ ] Shared consumers across other pages are identified and protected.
8. [ ] Blast radius is documented with risk level.
9. [ ] Automated regression test script is written, executed, and passing.
10. [ ] Zero unexplained metric discrepancies remain.

---

## 17. Role Completion Rule

A role is complete only when its full operational lifecycle is verified:

$$\text{Sidebar Navigation} \longrightarrow \text{Dashboard} \longrightarrow \text{Portfolio} \longrightarrow \text{Operations} \longrightarrow \text{Cashbook} \longrightarrow \text{Audit} \longrightarrow \text{Reports}$$

---

## 18. Production Safety & Data Invariants

During analysis and stabilization:
- **DO NOT** modify live transactional data without explicit user instruction.
- **DO NOT** alter historical financial ledger entries (`FP-002`).
- **DO NOT** invent fallback values or bypass missing metadata (`FP-001`).
- **DO NOT** change an ICARE business rule to match dirty or incomplete test data.
- If data corruption or legacy migration anomalies are found, report them separately in the investigation report.

---

## 19. Two-Mode Execution Protocol

### Mode A: ANALYSIS (Default)
- **Zero code modifications.**
- Perform forensic tracing, query live schema, verify business rules.
- Output the complete **Metric Investigation Report**.
- Set approval status to `WAITING FOR APPROVAL`.

### Mode B: IMPLEMENTATION (Post-Approval Only)
1. Re-read the approved analysis and confirmed Data Contract.
2. Implement **ONLY** the approved fix at the correct architectural layer.
3. Avoid unrelated refactorings or cosmetic changes.
4. Run targeted regression test scripts (`scratch/test_*.py`).
5. Run tests for all identified downstream consumers.
6. Verify cross-role compatibility.
7. Record the fix in the Fix History Record.

---

## 20. Fix History Record Schema

Every applied fix must document:

```text
FIX ID:                 [e.g., FIX-BM-DASH-001]
DATE:                   [YYYY-MM-DD]
ROLE:                   [e.g., BM]
PAGE:                   [e.g., Dashboard]
SECTION:                [e.g., Branch Performance]
METRIC:                 [e.g., Total Outstanding Balance]
ROOT CAUSE:             [Detailed summary of root cause]
BUSINESS RULE:          [Rule ID: e.g., BR-DASH-006]
FILES CHANGED:          [List of modified files]
METHODS CHANGED:        [List of modified methods]
DATABASE IMPACT:        [Schema/table impact]
LEDGER IMPACT:          [Account 1000 / Journal impact]
CASHBOOK IMPACT:        [CO/Master cashbook impact]
OTHER PAGES AFFECTED:   [List of other views affected]
ROLES AFFECTED:         [List of roles affected]
TESTS ADDED:            [Test script filename]
TESTS RUN:              [Test execution results]
RESULT:                 [100% Passed]
REGRESSION CHECK:       [Zero regressions confirmed]
STATUS:                 [FIXED]
```

---

## 21. Metric Registry Lifecycle

Metrics progress through explicit lifecycle states:

$$\text{UNKNOWN} \longrightarrow \text{UNDER\_INVESTIGATION} \longrightarrow \text{FIX\_PROPOSED} \longrightarrow \text{FIX\_APPROVED} \longrightarrow \text{FIXED} \longrightarrow \text{REGRESSION\_VERIFIED} \longrightarrow \mathbf{VERIFIED}$$

*Rule*: Never mark a metric `VERIFIED` without verified test script execution.

---

## 22. Current Working Strategy & Phase Progression

 stabilization proceeds sequentially:

```
PHASE A: Credit Officer (CO)
  ├── Dashboard Metrics
  ├── Portfolio & Loan History
  ├── Daily Collections / Operations
  └── CO Cashbook Projections

PHASE B: Branch Manager (BM) [CURRENT FOCUS]
  ├── Branch Performance Dashboard
  ├── Branch Portfolio & Risk Analytics
  ├── End of Day Operations & Approval Queue
  ├── Master Cashbook & Vault Reconciliation
  └── Branch Audit & Exports

PHASE C: Area Manager (AM)
  ├── Multi-Branch Regional Dashboard
  ├── Cross-Branch Comparative Portfolio
  └── Regional Cash & Treasury Overview

PHASE D: System Administrator (Admin)
  ├── System-Wide Financial Aggregation
  ├── User Management & RBAC Hierarchy
  └── Chart of Accounts & Posting Rules

PHASE E: Executive Director
  ├── Institutional KPI Dashboard
  └── Audited Financial Statements & PAR Analytics
```

---

## 23. Streamlit & Future Frontend Migration Readiness

When investigating and fixing bugs:
- **Cleanly decouple Business Logic from Presentation Logic.**
- Business rules, financial calculations, and metric formulas belong in `services/`, `domain/`, or `projections/`.
- UI files (`app.py` or future React/Next.js components) must only consume verified service/API outputs.
- Never embed financial or double-entry calculations directly inside Streamlit or React components.

---

## 24. Streamlit-Specific Legacy Code Rule

- `app.py` is a large presentation layer.
- **DO NOT** rewrite or refactor `app.py` simply because of its size during a metric audit.
- Make targeted, surgical modifications at the smallest correct layer (Presentation $\rightarrow$ Service $\rightarrow$ Projection $\rightarrow$ Repository).

---

## 25. Stop Conditions

Immediately **STOP** and request clarification when:
1. Documented business rules conflict with each other.
2. Two authoritative sources exist for the same metric without clear precedence.
3. Historical data prevents safe calculation.
4. Shared consumers require mutually exclusive business definitions.
5. A proposed fix carries high financial or ledger risk.
6. A database migration appears necessary.
7. A fix would alter posted financial history.

---

## 26. Required Metric Investigation Output Format

For every metric audit, return this exact structure:

```markdown
# METRIC INVESTIGATION

**ROLE:** [CO | BM | AM | Admin | Director]  
**PAGE:** [Page Name]  
**SECTION:** [Section Name]  
**METRIC:** [Metric Name]  

## 1. USER-REPORTED PROBLEM
[Clear description of the reported symptom]

## 2. EXPECTED ICARE BEHAVIOUR
[Codified business rule requirement and expected value]

## 3. CURRENT DISPLAYED BEHAVIOUR
[Current incorrect value/behavior displayed in UI]

## 4. DATA CONTRACT
[Full Data Contract specification per Section 5]

## 5. COMPLETE DATA TRACE
[End-to-end tier-by-tier pipeline trace per Section 7]

## 6. FIRST POINT OF DIVERGENCE
[Exact location where expected logic diverges]

## 7. ROOT CAUSE
[Precise technical and business root cause]

## 8. AUTHORITATIVE SOURCE
[The true source of truth for this metric]

## 9. CURRENT SOURCE
[The current faulty source used]

## 10. COLUMN / FIELD MAPPING
[Database to UI column mapping audit per Section 9]

## 11. SHARED CONSUMERS
[List of all other pages, roles, and reports consuming this logic]

## 12. BLAST RADIUS
[Direct, indirect, accounting, and cashbook impact assessment]

## 13. PROPOSED FIX
[Targeted, surgical implementation plan]

## 14. FILES TO CHANGE
[Exact files and line ranges to modify]

## 15. FILES NOT TO CHANGE
[Shared files explicitly protected from modification]

## 16. REGRESSION RISKS
[Identified risk factors and mitigation strategy]

## 17. TESTS REQUIRED
[Specific test scripts to write and run]

## 18. CROSS-ROLE IMPACT
[Impact on CO, BM, AM, Admin, and Director views]

## 19. APPROVAL STATUS
**WAITING FOR APPROVAL**
```

---

## 27. Final Governing Principle

### Anti-Pattern to Prevent:
$$\text{Bug A} \longrightarrow \text{Quick Patch} \longrightarrow \text{Bug B} \longrightarrow \text{Quick Patch} \longrightarrow \text{System Drift \& Ledger Inconsistency}$$

### Enforced Standard:
$$\mathbf{Business\ Rule} \longrightarrow \mathbf{Metric\ Contract} \longrightarrow \mathbf{Source\ of\ Truth} \longrightarrow \mathbf{Trace} \longrightarrow \mathbf{Root\ Cause} \longrightarrow \mathbf{Blast\ Radius} \longrightarrow \mathbf{Approved\ Fix} \longrightarrow \mathbf{Regression\ Verification}$$

The goal is a permanently consistent ICARE Core Banking System where every business fact has exactly **one unambiguous, verified truth** across all roles, pages, cashbooks, audit logs, and future frontends.
