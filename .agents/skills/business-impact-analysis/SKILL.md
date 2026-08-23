---
name: business-impact-analysis
description: Performs forensic page-by-page business-rule, data-flow, root-cause, dependency, and regression-impact analysis for ICARE before code changes. Supports multi-agent parallel investigation with specialized subagents (Business Rules, Database, Code Trace, Cross-System Impact, Regression, Accounting). Use when auditing any role (CO, BM, AM, Admin, Director), page, section, or metric, resolving data-source mismatches, column mapping discrepancies, reconciliation issues, or evaluating blast radius. Operates as an enforced Analysis-Only state machine by default.
---

# ICARE Business Impact Analysis Skill
## Enforced Forensic Analysis, Business-Rule Verification, Root-Cause, Dependency & Regression Control

---

## 0. IMMUTABLE SAFETY RULE & STATE MACHINE

```
                    ┌─────────────────────────────────────────┐
                    │      NEW SESSION / SKILL INVOCATION     │
                    └────────────────────┬────────────────────┘
                                         │ (Automatic Mode Reset)
                                         ▼
                    ┌─────────────────────────────────────────┐
                    │             MODE: ANALYSIS              │
                    │         (Strict Read-Only Lock)         │
                    │   • All write / edit tools BLOCKED      │
                    │   • All DB mutations / scripts BLOCKED  │
                    │   • All git mutations / push BLOCKED    │
                    └────────────────────┬────────────────────┘
                                         │
                                         ▼
                    ┌─────────────────────────────────────────┐
                    │          FORENSIC INVESTIGATION         │
                    │   • Read files & trace data pipeline    │
                    │   • Match codified ICARE rules          │
                    │   • Identify first point of divergence  │
                    │   • Calculate blast radius & risks      │
                    └────────────────────┬────────────────────┘
                                         │
                                         ▼
                    ┌─────────────────────────────────────────┐
                    │     REPORT WITH UNIQUE ANALYSIS ID      │
                    │   • Format: BIA-[ROLE]-[PAGE]-[SEQ]     │
                    │   • Append mandatory Hard-Stop Footer   │
                    └────────────────────┬────────────────────┘
                                         │
                                         ▼
                    ┌─────────────────────────────────────────┐
                    │      STATE: WAITING_FOR_APPROVAL        │
                    │      (Explicit Approval Required)       │
                    └────────────────────┬────────────────────┘
                                         │
                   User says: "Approve BIA-..." / "Implement BIA-..."
                                         │
                                         ▼
                    ┌─────────────────────────────────────────┐
                    │          MODE: IMPLEMENTATION           │
                    │        (Scope-Locked Execution)         │
                    │   • Implement ONLY approved fix         │
                    │   • Modify ONLY approved files/methods  │
                    │   • Run verification tests              │
                    │   • Record Fix History                  │
                    └────────────────────┬────────────────────┘
                                         │
                                         │ (Execution Complete)
                                         ▼
                    ┌─────────────────────────────────────────┐
                    │       AUTOMATIC RETURN TO ANALYSIS      │
                    └─────────────────────────────────────────┘
```

> [!CAUTION]
> **GOVERNING INVARIANT: ANALYSIS MODE NEVER WRITES.**
> When in `ANALYSIS` mode, the agent is strictly prohibited from modifying source files, executing database writes/migrations, committing/pushing git changes, or executing state-mutating test scripts. There are **ZERO EXCEPTIONS** for "obvious fixes", "one-line changes", "failing tests", or "simple bugs".

---

## 1. Analysis Mode as Default & Bug Report Disambiguation

### Rule 1.1: Default Mode is Always ANALYSIS
Every new invocation of this skill starts in `MODE: ANALYSIS`. Previous implementation approvals from earlier conversation turns **NEVER** persist into a new investigation.

### Rule 1.2: User Bug Report $\neq$ Implementation Approval
A user reporting a bug, anomaly, or discrepancy is an instruction to **INVESTIGATE**, never an authorization to modify code.

| User Statement | Meaning | Allowed Action | Prohibited Action |
|---|:---:|---|---|
| *"The BM dashboard collection figure is wrong"* | **INVESTIGATE** | Forensic trace & data contract audit. | Editing `app.py` or service files. |
| *"Why is this value negative?"* | **INVESTIGATE** | Query schema & calculate root cause. | Applying quick fix or patch. |
| *"Check the Cashbook for CO2"* | **INVESTIGATE** | Rebuild trace & compare with Ledger. | Mutating cashbook rows or code. |
| *"Audit this page"* | **INVESTIGATE** | Full 10-point page audit. | Modifying queries or formatting. |
| *"Find the bug in loan schedule"* | **INVESTIGATE** | Trace `loan_schedule` generation. | Modifying schedule algorithms. |
| *"Fix this now"* (No prior approved BIA) | **INVESTIGATE FIRST** | Perform analysis, output BIA report, request approval. | Writing code before approval. |
| *"Approve BIA-BM-DASH-001. Implement the fix."* | **IMPLEMENT** | Execute ONLY approved scope for `BIA-BM-DASH-001`. | Modifying unrelated files/metrics. |

---

## 2. Hard Pre-Flight Execution Check

Before executing ANY tool call that can modify project state (files, database, git, configs), the agent MUST verify this internal execution check:

```text
================ PRE-FLIGHT CHECK ================
CURRENT MODE:      [ANALYSIS | IMPLEMENTATION]
APPROVAL STATUS:   [APPROVED (with exact Analysis ID) | NOT GRANTED]
APPROVED SCOPE:    [Exact Analysis ID, Issue, Files, Functions]
TARGET TOOL:       [Tool Name]
IS TOOL MUTATING:  [YES / NO]
DECISION:          [PROCEED / BLOCK]
==================================================
```

### If `CURRENT MODE == ANALYSIS`:
**ALL WRITE AND MUTATING TOOLS ARE HARD BLOCKED.**

- 🚫 **Forbidden Actions**:
  - `replace_file_content` / `multi_replace_file_content` / `write_to_file` on source code, tests, configs, migrations, SQL.
  - Database mutations (`INSERT`, `UPDATE`, `DELETE`, `UPSERT`, `ALTER`, `DROP`, running migration scripts).
  - Git mutations (`git add`, `git commit`, `git push`, `git reset`, `git checkout` modifying files, `git merge`).
  - Executing scripts that mutate the database or file system.
- ✅ **Allowed Read-Only Actions**:
  - `view_file`, `grep_search`, `list_dir`.
  - Read-only database queries (`SELECT`, schema inspection, metadata queries, `EXPLAIN`).
  - Read-only git commands (`git status`, `git diff`, `git log`, `git show`).
  - Running purely read-only diagnostic scripts that make zero database/file writes.

---

## 3. Explicit Implementation Command & Analysis ID Requirement

### Rule 3.1: Unique Analysis ID Generation
Every investigation report generated by this skill must assign and display a unique **Analysis ID** formatted as:
$$\text{BIA-}[\text{ROLE}]-[\text{PAGE/AREA}]-[\text{SEQ}]$$
*(e.g., `BIA-BM-DASH-001`, `BIA-CO-OPS-002`, `BIA-AM-RECON-001`)*

### Rule 3.2: Approval Linked to Analysis ID
Implementation is permitted **ONLY** when the user explicitly approves the specific Analysis ID (e.g., *"Approve BIA-BM-DASH-001"*, *"Proceed with implementation for BIA-BM-DASH-001"*).

### Rule 3.3: Ambiguity Stop Protocol
If the user provides an ambiguous command (e.g., *"Okay fix it"*) when multiple analyses are pending or when no specific Analysis ID is mentioned:
> **STOP AND ASK**: Prompt the user to confirm the exact Analysis ID and scope before taking any action.

---

## 4. Implementation Scope Lock

When explicit approval is granted for an Analysis ID, an **Implementation Scope Lock** is established:

```text
================ IMPLEMENTATION SCOPE LOCK ================
APPROVED ANALYSIS:   BIA-BM-DASH-001
APPROVED METRIC:     Collection Today
APPROVED FIX:        [Exact summary of proposed surgical fix]
APPROVED FILES:      [services/dashboard_service.py]
APPROVED FUNCTIONS:  [get_bm_dashboard_data()]
UNAPPROVED:          ALL OTHER FILES, FUNCTIONS, AND PAGES
===========================================================
```

### Rules During Implementation:
1. **Zero Scope Creep**: The agent MUST NOT modify any file or function outside the approved scope.
2. **Discovered Issues Protocol**: If another bug or divergence is discovered while implementing the approved fix:
   - **DO NOT** silently fix it.
   - **DO NOT** expand the current implementation scope.
   - **STOP** and document the new issue as a separate `BIA-[ROLE]-[PAGE]-[SEQ]` analysis for subsequent user review.
3. **Automatic Return to Analysis Mode**: Immediately upon completing implementation, running verification tests, and recording Fix History, the agent MUST automatically reset its state to `MODE: ANALYSIS`.

---

## 5. Mandatory Analysis Hard-Stop Footer

Every investigation report produced in `ANALYSIS` mode MUST terminate with this exact, verbatim block. **No implementation code, file edits, or patch executions are permitted after this block:**

```markdown
---

### 🛑 ANALYSIS COMPLETE

- **ANALYSIS ID**: [e.g., BIA-BM-DASH-001]
- **CODE CHANGES**: NONE
- **DATABASE CHANGES**: NONE
- **FILES MODIFIED**: NONE
- **APPROVAL STATUS**: WAITING FOR APPROVAL
- **NEXT ACTION**: User must explicitly approve this Analysis ID (e.g. `Approve BIA-...`) before implementation can proceed.
```

---

## 6. Core Purpose & Operational Roles of This Skill

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

## 7. ICARE Business Rule Authority

Always read and strictly adhere to:
1. Mandatory entry point: [`.agents/rules/00-READ-FIRST.md`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/00-READ-FIRST.md)
2. Authoritative business rules: [`.agents/rules/business-rules/`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/business-rules/)
3. Architectural invariants: [`.agents/rules/architecture/`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/rules/architecture/)
4. Metric contracts & reference baselines: [`.agents/references/metric-contracts/`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/.agents/references/metric-contracts/)

### Non-Negotiable Governance Invariants:
- **Business Rules ALWAYS outrank current UI implementations.**
- **Never infer ICARE behavior from generic banking software.** Do not replace ICARE logic with external banking models.
- Generic banking concepts may be used for UI/UX inspiration **ONLY** when they do not conflict with ICARE business rules.

---

## 8. Role-Aware Analysis (RBAC Scope Verification)

Every metric investigation must verify that the calculation respects the authenticated user's Role-Based Access Control (RBAC) boundary:

- **Credit Officer (CO)**: Own assigned client portfolio and vault custody (`officer_id`).
- **Branch Manager (BM)**: Assigned branch boundary (`branch_id`) across all branch officers.
- **Area Manager (AM)**: Assigned multi-branch coverage (`assigned_branch_ids`).
- **System Administrator (ADMIN)**: Institution-wide administrative scope.
- **Executive Director (DIRECTOR)**: Institution-wide executive read-only analytics.

**Rule**: A metric can be mathematically accurate but still be **CRITICALLY WRONG** if calculated across the wrong RBAC scope.

---

## 9. Page Data Contract Specification

Every audited metric must produce a structured **Data Contract** as part of its investigation report:

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

## 10. Source-of-Truth Classification

For every metric, classify its architectural nature:

1. **Financial Metric (Physical Cash / Vault Liability)**: `financial_ledger_entries` (`Account 1000` for physical vault cash, `Account 1050` for bank). Never derive cash balances from operational tables (`loans`, `repayments`, `treasury_transactions`).
2. **CO Cashbook Projection**: `co_cashbooks` built strictly from `financial_ledger_entries` (Account 1000) and `event_store`.
3. **Master Cashbook Projection**: `master_cashbook` aggregating all branch CO cashbooks plus branch treasury events.
4. **Operational Entity State (Lifecycle & Ownership)**: Operational tables (`loans`, `clients`, `groups`, `loan_products`).
5. **Scheduled Amortization**: `loan_schedule` generated using business meeting days.
6. **Outstanding / Remaining Loan Balance**: $\max(0.0, \text{loans.total\_due (baseline)} - \sum \text{post-migration repayments})$.
7. **Savings Balance**: $\sum(\text{deposits}) - \sum(\text{withdrawals})$ per category (`individual_savings`, `group_savings`, `internal_savings`).
8. **Reporting & Dashboard Aggregation**: Dedicated service methods respecting RBAC scope and business date filters.

---

## 11. UI → Data Pipeline Trace & Point of Divergence

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

### First Point of Divergence Checks:
- **Wrong Filter**: Branch, officer, date range, or status filter missing or misconfigured.
- **Wrong Column**: Using `active_credit` instead of `total_due` as the remaining balance baseline.
- **Wrong Aggregation**: `COUNT` instead of `SUM`, or lifetime cumulative instead of period-filtered.
- **Wrong Event Type / Account Code**: Filtering by wrong event name or chart of accounts code.
- **Wrong Scope**: Querying all branches instead of the officer's assigned scope.
- **Stale Projection**: Cashbook projection not rebuilt after an event was posted.
- **Duplicate / Missing Rows**: Cartesian join or improper group-by aggregation.
- **Hardcoded Value**: Static fallback values embedded in UI or service logic.

---

## 12. Blast-Radius Analysis & Shared Protection Protocol

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

### Shared Function Protection Protocol:
Before modifying any shared method in `services/`, `database/`, or `mappers/`:
1. Search all callers across the repository: `grep_search` across `*.py`.
2. Inspect every consumer page, role, and test file.
3. If two consumers require different business definitions:
   - **DO NOT** blindly edit the shared method.
   - Propose a specialized service method, dedicated projection, or explicit scope parameter.
   - Avoid creating duplicate business logic.

---

## 13. Cross-Role Root Cause Status Taxonomy

Classify every identified root cause:

- **`NEW`**: First time this root cause has been identified in any role/page.
- **`ALREADY_IDENTIFIED`**: Root cause was previously identified in another role's audit but has not yet been fixed.
- **`ALREADY_FIXED`**: Root cause was already fixed during a previous role/page audit.
- **`REGRESSION_DETECTED`**: A previously fixed root cause has reappeared.
- **`SHARED_FIX_REQUIRED`**: Root cause affects multiple roles/pages and requires a single coordinated fix at the shared service/repository/projection layer rather than per-page patches.

---

## 14. Fix History Record Schema (Post-Implementation Only)

When an approved fix is implemented during `MODE: IMPLEMENTATION`, document:

```text
FIX ID:                 [e.g., FIX-BM-DASH-001]
ANALYSIS ID:            [e.g., BIA-BM-DASH-001]
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

## 15. System-Wide Verified Metric Registry

### Metric Lifecycle States:
$$\text{UNKNOWN} \longrightarrow \text{UNDER\_INVESTIGATION} \longrightarrow \text{FIX\_PROPOSED} \longrightarrow \text{FIX\_APPROVED} \longrightarrow \text{FIXED} \longrightarrow \text{REGRESSION\_VERIFIED} \longrightarrow \mathbf{VERIFIED}$$

*Rule*: Never mark a metric `VERIFIED` without verified test script execution. Once verified, the contract is locked across all roles.

---

## 16. Mandatory UI & Interactive State Verification Protocol

Whenever a bug fix, metric correction, or feature implementation is executed, the agent MUST explicitly verify the user interface (UI) layers in addition to database and backend verification:

1. **Component & Tab Routing**:
   - Confirm that programmatic updates to session state (e.g. `st.session_state["orig_tab"]`) match the exact string literals in tab/radio options (including whitespace and absence of emoji prefixes).
   - Ensure form submissions and redirections do not bounce or fallback to unintended tabs or pages.
2. **Form Controls & Inputs**:
   - Inspect all input fields, number inputs, placeholders, validation alerts, and form submit buttons.
   - Confirm proper default states, disabled/enabled states, and currency formatters (`₦{:,.2f}`).
3. **Reactive & Interactive State**:
   - Verify that dynamic selectboxes (officer filters, group selectors, client dropdowns, loan pickers) update reactively without requiring multiple clicks or causing session state resets.
   - Ensure external interactive controls (e.g., "Expand All") operate outside form barriers to preserve instant reactivity.
4. **Typography & Corporate Styling**:
   - Enforce clean corporate typography across headers, buttons, and badges.
   - Strictly adhere to the emoji governance: keep `👤` (Client/Officer profile) and `📋` (Asset/Documentation) indicators where specified, while eliminating informal emoji clutter from action buttons and operational forms.
5. **Cross-Role UI Confirmation**:
   - Verify that the rendered UI aligns strictly with the role's RBAC scope (e.g. Credit Officer sees field collection views; Branch Manager sees branch approvals and oversight; Area Manager and Admin see multi-branch aggregation).

---

## 17. Required Metric Investigation Output Format

For every investigation, return this exact structure:

```markdown
# METRIC INVESTIGATION

**ANALYSIS ID:** [e.g., BIA-BM-DASH-001]  
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
[Full Data Contract specification per Section 9]

## 5. COMPLETE DATA TRACE
[End-to-end tier-by-tier pipeline trace per Section 11]

## 6. FIRST POINT OF DIVERGENCE
[Exact location where expected logic diverges]

## 7. ROOT CAUSE
[Precise technical and business root cause]

## 7b. COMMON ROOT CAUSE STATUS
[NEW | ALREADY_IDENTIFIED | ALREADY_FIXED | REGRESSION_DETECTED | SHARED_FIX_REQUIRED]

## 8. AUTHORITATIVE SOURCE
[The true source of truth for this metric]

## 9. CURRENT SOURCE
[The current faulty source used]

## 10. COLUMN / FIELD MAPPING
[Database to UI column mapping audit]

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

## 18. CROSS-ROLE IMPACT & VERIFIED METRIC COMPARISON
[Impact on CO, BM, AM, Admin, and Director views]

---

### 🛑 ANALYSIS COMPLETE

- **ANALYSIS ID**: [e.g., BIA-BM-DASH-001]
- **CODE CHANGES**: NONE
- **DATABASE CHANGES**: NONE
- **FILES MODIFIED**: NONE
- **APPROVAL STATUS**: WAITING FOR APPROVAL
- **NEXT ACTION**: User must explicitly approve this Analysis ID (e.g. `Approve BIA-...`) before implementation can proceed.
```

---

# PART II — MULTI-AGENT INVESTIGATION ARCHITECTURE

> [!IMPORTANT]
> **The following sections EXTEND the existing skill. All rules from Part I (Sections 0–17) remain fully in force. Part II adds a controlled multi-agent orchestration system for complex investigations.**

---

## 18. Primary Purpose Reinforcement

The skill remains an **INVESTIGATION AND BUSINESS-ANALYSIS** skill.

Its primary job is:

```
UNDERSTAND → INVESTIGATE → TRACE → CROSS-CHECK → IDENTIFY ROOT CAUSE
→ ANALYSE IMPACT → PROPOSE FIX → REPORT → STOP
```

It is **NOT** an implementation skill.

The skill must **NEVER** automatically:
- Modify application code
- Edit files
- Create migrations
- Modify database records
- Modify business rules
- Refactor code
- "Fix" the issue
- Run destructive commands
- Implement its proposed solution

...unless the user explicitly exits investigation mode and gives approval to implement per Section 3.

---

## 19. Multi-Agent Orchestration Architecture

When a problem is sufficiently complex, the skill acts as an **ORCHESTRATOR** and delegates investigation to multiple specialized subagents.

### 19.1 Orchestrator Responsibilities

1. Define the investigation question.
2. Break the problem into independent investigation tasks.
3. Assign tasks to specialized subagents.
4. Run independent investigations in parallel where possible.
5. Compare their findings.
6. Detect contradictions.
7. Resolve contradictions using evidence.
8. Produce one consolidated investigation report.
9. Perform final blast-radius analysis.
10. **STOP** before implementation.

### 19.2 When to Use Multiple Subagents

Do **NOT** create unnecessary subagents for trivial questions.

Use multiple subagents when a problem involves **two or more** of:

- Business rules
- Database data
- UI behaviour
- Service logic
- Projections
- Accounting
- Cashbooks
- Dashboards
- Portfolios
- Cross-role behaviour
- Shared services
- Historical data
- Reconciliation
- Multiple files
- Potential cross-page impact

### 19.3 Subagent Invocation Policy

Use **parallel** subagents when investigations are independent.

**Example — BM Dashboard "Collection Today":**

Launch in parallel:
- Business Rules Analyst
- Database Analyst
- Code Trace Analyst
- Accounting Analyst
- Cross-System Impact Analyst

Then let the orchestrator reconcile the results.

**Example — Simple UI mapping issue:**

- Code Trace Analyst + Database Analyst may be sufficient.

**Example — Financial cashbook issue:**

- Business Rules + Database + Code Trace + Accounting + Impact + Regression should normally be used.

---

## 20. Specialized Investigation Subagents

These are **INVESTIGATION ROLES**, not coding roles. Each subagent is a deliberately suspicious investigator that independently questions and verifies claims.

---

### 20.1 AGENT 1 — BUSINESS RULES ANALYST

**Purpose:** Determine what the system **SHOULD** do.

**Responsibilities:**
- Read the authoritative business rules in `.agents/rules/business-rules/*`.
- Read `00-READ-FIRST.md` and other constitution files.
- Identify the exact rule governing the issue.
- Identify relevant business definitions.
- Identify calculation rules.
- Identify balancing rules.
- Identify source-of-truth rules.
- Identify role-specific behaviour.

**Output — BUSINESS EXPECTATION:**

| Field | Content |
|---|---|
| Rule ID/Name | [e.g., BR-DASH-006] |
| Business Definition | [Plain English definition] |
| Expected Behaviour | [What should happen] |
| Expected Calculation | [Formula/logic] |
| Expected Source | [Authoritative table/column] |
| Expected Output | [Expected value/format] |
| Related Rules | [Cross-references] |
| Ambiguities | [Unresolved questions, if any] |

**DO NOT** modify anything. Read-only investigation.

---

### 20.2 AGENT 2 — DATABASE / DATA SOURCE ANALYST

**Purpose:** Determine where the **CORRECT** data actually exists.

**Trace Chain:**
```
UI requirement → database tables → relevant columns → relationships
→ operational records → event records → ledger records → projection records
```

**Investigate:**
- Schema, tables, columns, joins, foreign keys
- `event_store`
- `financial_ledger_entries`
- `financial_transactions`
- Operational tables
- Projection tables
- Historical records

**Determine:**
- Authoritative source
- Current source used by application
- Whether data exists
- Whether data is missing
- Whether data is duplicated
- Whether data is stored in the wrong column
- Whether the values reconcile

**Output — DATA SOURCE FINDING:**

| Field | Content |
|---|---|
| Correct Source | [Authoritative table.column] |
| Current Source | [What app currently uses] |
| Relevant Tables | [All involved tables] |
| Relevant Columns | [All involved columns] |
| Sample Evidence | [Actual record excerpts] |
| Data Mismatch | [Discrepancy description] |
| Reconciliation Result | [Match / Mismatch / Partial] |
| Data Integrity Concerns | [Orphans, duplicates, nulls] |

**READ ONLY.** No database mutations.

---

### 20.3 AGENT 3 — CODE TRACE ANALYST

**Purpose:** Determine exactly how the application obtains and transforms the data.

**Trace Chain:**
```
UI → page/component → state → service → repository → query
→ transformation → calculation → displayed metric
```

**Look For:**
- Wrong table / column / filter / date / branch / officer / role
- Wrong aggregation / duplicate aggregation / missing aggregation
- Incorrect joins
- Stale state
- Hardcoded values
- Incorrect aliases / mapping
- Incorrect projection usage
- Fallback behaviour
- Inconsistent definitions across consumers

**Output — CODE TRACE:**

| Field | Content |
|---|---|
| UI Location | [Page, section, line range] |
| Function | [Function name and file] |
| Service | [Service class and method] |
| Repository | [Repository class and method] |
| Query | [Actual query/filter used] |
| Source Column | [Column being read] |
| Transformation | [Any post-query logic] |
| Final Displayed Value | [What the UI shows] |
| Point of Divergence | [Exact location where value becomes incorrect] |

**READ ONLY.** No file modifications.

---

### 20.4 AGENT 4 — CROSS-SYSTEM IMPACT ANALYST

**Purpose:** Determine what else could be affected by the proposed fix.

**Search Across:**
- CO, BM, AM, Admin, Director
- Dashboard, Portfolio, Cashbook, Reports, Reconciliation
- Shared services, shared repositories, shared calculations
- Database functions, projections

**Impact Classification:**

| Level | Meaning |
|---|---|
| NONE | No dependency exists |
| LOW | Dependency exists but behaviour unchanged |
| MEDIUM | Behaviour may change; testing required |
| HIGH | Behaviour will change; careful coordination required |
| CRITICAL | Core financial integrity or multi-role stability at risk |

**Output — BLAST RADIUS:**

For every affected area:
- Why it is affected
- What dependency exists
- What could change
- Whether current behaviour is stable
- Whether regression testing is required

> [!CAUTION]
> **CO STABILITY RULE:** CO is currently considered **STABLE** unless the user explicitly says otherwise. Never recommend changing shared code that affects CO without explicitly identifying and quantifying the CO impact.

**READ ONLY.** No file modifications.

---

### 20.5 AGENT 5 — REGRESSION / TEST ANALYST

**Purpose:** Determine how the proposed fix can be verified without breaking existing behaviour.

**Review:**
- Existing tests
- Regression tests
- Business-rule tests
- Integration tests
- Previous fixes
- Known stable workflows

**Output — REGRESSION PLAN:**

| Field | Content |
|---|---|
| Existing Tests | [Tests that already cover this area] |
| Tests To Add | [New tests recommended] |
| Expected Result | [What passing looks like] |
| Affected Workflows | [End-to-end flows impacted] |
| Cross-Role Tests | [CO→BM, BM→AM, AM→Admin, Admin→Director] |
| Edge Cases | [Boundary conditions to verify] |
| Transaction Chain | [transaction → ledger → cashbook → portfolio → dashboard → reports] |

**DO NOT write tests.** Only recommend them during investigation mode.

---

### 20.6 AGENT 6 — ACCOUNTING / RECONCILIATION ANALYST

**Use when the issue involves:** cashbook, ledger, portfolio balances, repayments, savings, loan disbursement, treasury, dashboard financial metrics, reconciliation, debit/credit, Account 1000, financial projections.

**Purpose:** Verify the financial meaning independently.

**Check:**
- Debit / Credit
- Inflow / Outflow
- Opening Balance / Closing Balance
- Expected Balance vs. Actual Balance
- Ledger Balance vs. Cashbook Balance
- Operational Balance vs. Projection Balance

**Rule:** Never accept a displayed value merely because it "looks reasonable." **Prove the calculation.**

**Output — FINANCIAL RECONCILIATION FINDING:**

```text
METRIC:              [Name]
EXPECTED BALANCE:    [Calculated from authoritative source]
LEDGER BALANCE:      [From financial_ledger_entries]
CASHBOOK BALANCE:    [From co_cashbooks / master_cashbook]
OPERATIONAL BALANCE: [From operational tables]
PROJECTION BALANCE:  [From projection tables]
DIFFERENCE:          [Variance]
RECONCILED:          [YES / NO]
ROOT CAUSE:          [If NO, explain discrepancy]
```

**READ ONLY.** No database mutations.

---

## 21. Orchestrator Reconciliation Rules

The orchestrator must **NOT** blindly trust any single subagent.

It must compare:

```
Business Rules Evidence
  vs
Database Evidence
  vs
Code Trace Evidence
  vs
Accounting Evidence
  vs
Cross-System Impact
  vs
Regression Analysis
```

### Confidence Matrix:

| Condition | Confidence |
|---|---|
| All agents agree | **HIGH** |
| Minor disagreements on non-critical details | **MEDIUM** |
| Major contradictions on source, calculation, or impact | **LOW** |

When confidence is **LOW**, the orchestrator must investigate the contradiction before proposing a fix. Never paper over disagreements.

---

## 22. Evidence-First Rule

No conclusion may be based solely on:
- Assumptions
- Filenames
- Function names
- Comments
- UI labels
- What a developer intended
- What "looks correct"

Where possible, prove the conclusion through:
- Actual code (with file and line references)
- Actual database schema
- Actual records (sample data)
- Actual queries
- Actual business rules (with rule IDs)
- Actual calculations (with formulas)
- Actual dependency relationships

Clearly distinguish:

| Classification | Meaning |
|---|---|
| **FACT** | Directly observed and independently verifiable |
| **INFERENCE** | Logically derived from facts but not directly observed |
| **HYPOTHESIS** | Plausible explanation that requires further investigation |

**Never present an inference as a confirmed fact.**

---

## 23. Metric Contract Investigation Mode (Extended)

For every dashboard, portfolio, cashbook, report, or card metric, investigate using a **METRIC CONTRACT** that extends the Data Contract from Section 9:

```text
METRIC NAME:
ROLE:
PAGE:
BUSINESS DEFINITION:
EXPECTED VALUE:
SOURCE OF TRUTH:
TABLE:
COLUMN:
FILTER:
DATE LOGIC:
BRANCH LOGIC:
OFFICER LOGIC:
CALCULATION:
EXCLUSIONS:
UI COMPONENT:
CURRENT SOURCE:
CURRENT CALCULATION:
CURRENT RESULT:
EXPECTED RESULT:
ROOT CAUSE:
IMPACT:
REGRESSION RISK:
CONFIDENCE:
```

**Anti-Vagueness Rule:** The agent must never say *"Use the correct column."*

It must identify:

```
CURRENT COLUMN → WHY IT IS WRONG → CORRECT COLUMN → WHY IT IS CORRECT
→ WHAT OTHER CODE USES THAT COLUMN → WHAT THE CHANGE WILL AFFECT
```

---

## 24. Cashbook Investigation Mode (Extended)

For cashbook problems, explicitly map:

$$\text{Opening Balance} + \sum\text{Inflows} - \sum\text{Outflows} = \text{Closing Balance}$$

Then independently reconcile each source:

| Source | Verified Independently |
|---|---|
| Operational Data | YES / NO |
| Ledger (`financial_ledger_entries`) | YES / NO |
| CO Cashbook (`co_cashbooks`) | YES / NO |
| Master Cashbook (`master_cashbook`) | YES / NO |
| Dashboard | YES / NO |
| Portfolio | YES / NO |

**Do not combine these sources merely because they currently produce the same number. Each source must be independently verified.**

For every cashbook column identify:

```text
COLUMN NAME → BUSINESS MEANING → SOURCE EVENT → SOURCE TABLE → SOURCE COLUMN
→ DEBIT/CREDIT → INFLOW/OUTFLOW → EXPECTED VALUE → ACTUAL VALUE → DIFFERENCE
```

---

## 25. CO Stability Protection Protocol

**CURRENT STATUS: CO PAGE = STABLE / LIVE-TESTED**

The CO page has been successfully live-tested and should be treated as a protected stable workflow.

Therefore:
- **DO NOT** modify CO simply because BM/AM/Admin/Director is being investigated.
- If a BM issue appears to originate from shared code:

1. Identify the shared dependency.
2. **Prove** that it affects CO.
3. Explain the impact.
4. Explain the regression risk.
5. Propose the **minimum safe change**.
6. **STOP.**

No implementation without explicit approval.

---

## 26. No Cascading Fixes Rule

**NEVER** fix a symptom before determining the root cause.

**Example:** If BM Dashboard displays the wrong number:

**DO NOT** immediately change the BM query.

First determine:

1. Is the database value correct?
2. Is the business definition correct?
3. Is the source table correct?
4. Is the backend calculation correct?
5. Is the UI fetching the wrong value?
6. Is the projection stale?
7. Is the same metric calculated differently elsewhere?
8. Is the problem shared across roles?

Only after answering those questions may a fix be proposed.

---

## 27. Subagent Output Format

Every subagent must return:

```text
ROLE:            [Subagent role name]
QUESTION:        [The specific investigation question assigned]
EVIDENCE:        [Raw facts observed with file/line/record references]
FINDINGS:        [Interpreted results]
FACTS:           [Directly observed, independently verifiable]
INFERENCES:      [Logically derived from facts]
UNKNOWN:         [Questions that remain unanswered]
IMPACT:          [Assessment of severity and scope]
RECOMMENDATION:  [Proposed action — investigation only, no code]
```

The subagent **must not** modify files.

---

## 28. Final Orchestrator Consolidated Report

The orchestrator must consolidate all subagent findings into a single unified report:

```markdown
# ICARE MULTI-AGENT INVESTIGATION REPORT

**ANALYSIS ID:** [e.g., BIA-BM-DASH-062]
**INVESTIGATION MODE:** Multi-Agent Orchestrated
**AGENTS DEPLOYED:** [List of agents used]
**CONFIDENCE:** [HIGH | MEDIUM | LOW]

## 1. Problem
[User-reported issue]

## 2. Business Rule
[Governing rule from .agents/rules/]

## 3. Expected Behaviour
[What the system SHOULD do]

## 4. Current Behaviour
[What the system ACTUALLY does]

## 5. Database Evidence
[Data Source Analyst findings]

## 6. Code Trace
[Code Trace Analyst findings]

## 7. Root Cause
[Precise technical and business root cause]

## 8. Financial / Reconciliation Analysis
[Accounting Analyst findings — if applicable]

## 9. Cross-System Impact
[Impact Analyst findings]

## 10. CO Impact
[Explicit CO stability assessment]

## 11. Proposed Fix
[Targeted, surgical fix — description only]

## 12. Files Affected
[Exact files and line ranges]

## 13. Database Changes Required
[Schema or data changes, if any]

## 14. Regression Risks
[Regression Analyst findings]

## 15. Test Plan
[Recommended tests]

## 16. Confidence
[HIGH | MEDIUM | LOW with justification]

## 17. Agent Agreement Matrix
| Agent | Agrees with Root Cause | Notes |
|---|---|---|
| Business Rules | YES/NO | ... |
| Database | YES/NO | ... |
| Code Trace | YES/NO | ... |
| Accounting | YES/NO | ... |
| Impact | YES/NO | ... |
| Regression | YES/NO | ... |

## 18. Implementation Status

**NOT IMPLEMENTED**

**WAITING FOR EXPLICIT APPROVAL.**

---

### 🛑 ANALYSIS COMPLETE

- **ANALYSIS ID**: [e.g., BIA-BM-DASH-062]
- **CODE CHANGES**: NONE
- **DATABASE CHANGES**: NONE
- **FILES MODIFIED**: NONE
- **APPROVAL STATUS**: WAITING FOR APPROVAL
- **NEXT ACTION**: User must explicitly approve this Analysis ID (e.g. `Approve BIA-...`) before implementation can proceed.
```

---

## 29. Critical Anti-Coding Safeguard (Reinforced)

> [!CAUTION]
> **THIS IS THE MOST IMPORTANT RULE.**
>
> When this skill is invoked:
>
> **DO NOT** CODE. **DO NOT** PATCH. **DO NOT** EDIT. **DO NOT** REFACTOR.
> **DO NOT** CREATE FILES. **DO NOT** MODIFY DATABASE DATA. **DO NOT** IMPLEMENT.
>
> The skill's job is to **INVESTIGATE** and **REPORT**.
>
> Even if the correct fix appears obvious, report the fix and **STOP**.
>
> Only an explicit user instruction outside the investigation workflow may authorize implementation.

---

## 30. Final Operating Principle

ICARE must be treated as a **financial system**, not an ordinary CRUD application.

Therefore, never optimize for *"making the screen look right."*

Optimize for:

```
BUSINESS RULE
  → SOURCE OF TRUTH
    → DATA INTEGRITY
      → ACCOUNTING INTEGRITY
        → CORRECT CALCULATION
          → CORRECT UI REPRESENTATION
            → CROSS-SYSTEM CONSISTENCY
              → REGRESSION SAFETY
```

The goal is not merely to make one page display the expected number.

**The goal is to prove that the number is correct throughout the entire ICARE system.**

---

## 31. Protected Files (Extended)

In addition to the original protected files from Part I, the following are also protected:

- `.agents/rules/business-rules/*` — Business rule definitions
- `.agents/rules/architecture/*` — Architectural invariants
- `.agents/rules/00-READ-FIRST.md` — Constitution entry point
- `.agents/skills/business-impact-analysis/SKILL.md` — This skill file
- `.agents/references/metric-contracts/*` — Verified metric contracts

These files may only be modified with explicit user authorization.
