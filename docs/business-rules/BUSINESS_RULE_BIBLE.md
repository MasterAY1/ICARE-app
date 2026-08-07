# ICARE Business Rule Bible

## 1. Authority Statement

ICARE Business Rules are authoritative. Generic banking assumptions, AI assumptions, developer assumptions and inferred workflows must never override an explicit ICARE rule. Before changing business logic, the agent must consult the Business Rule Bible. If the requested behavior conflicts with an existing rule, stop and identify the conflict. Never silently invent a business rule.

## 2. ICARE Core Operating Model

Credit Officer Operations → Collections/Savings → CO Cashbook → Master/Credit Cashbook → Financial Ledger → Reports/Dashboards

## 3. Organizational Hierarchy

Director → Area Manager → Branch Manager → Credit Officer

## 4. Architecture

Clean Architecture + DDD + Event Sourcing + CQRS projections + Repository Pattern + Unit of Work

## 5. Rule Index

- [PRODUCT_RULES.md](PRODUCT_RULES.md)
- [LOAN_RULES.md](LOAN_RULES.md)
- [COLLECTION_RULES.md](COLLECTION_RULES.md)
- [SAVINGS_RULES.md](SAVINGS_RULES.md)
- [CASHBOOK_RULES.md](CASHBOOK_RULES.md)
- [FEE_RULES.md](FEE_RULES.md)
- [ROLE_AND_PERMISSION_RULES.md](ROLE_AND_PERMISSION_RULES.md)
- [WORKFLOW_RULES.md](WORKFLOW_RULES.md)
- [REPORTING_RULES.md](REPORTING_RULES.md)
- [BUSINESS_DATE_RULES.md](BUSINESS_DATE_RULES.md)
- [DATA_INTEGRITY_RULES.md](DATA_INTEGRITY_RULES.md)
- [AI_AGENT_RULES.md](AI_AGENT_RULES.md)

## 6. Rule Status Definitions

- **CONFIRMED**: The rule is clearly stated, understood, and serves as a valid business rule.
- **IMPLEMENTATION-VERIFIED**: The rule is confirmed AND it has been verified that the codebase successfully and correctly implements this rule.
- **REQUIRES-CLARIFICATION**: The rule is unclear, contradictory, or lacks necessary details to be actionable or verifiable.

## 7. Rule Change Protocol & Bug Fix Protocol

**Rule Change Protocol:** Any proposed change to business rules must be documented, reviewed, and transitioned through status definitions before code implementation. 

**Bug Fix Protocol:** When fixing bugs, the current implemented behavior must be verified against the rules in this document. If code violates a CONFIRMED rule, it is a bug. If the code behavior is desired but contradicts a rule, the rule MUST be updated through the Rule Change Protocol.

## 8. No Product Redesign Directive

The existing operational tables and cashbooks are to be preserved. The objective is STABILIZE → CORRECT → TEST → DOCUMENT → IMPROVE. No major re-architecting of the core operational flow or database schema is permitted unless explicitly directed.
