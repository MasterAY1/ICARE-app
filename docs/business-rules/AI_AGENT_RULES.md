# AI Agent Rules

## Rules

### BR-AI-001
**Name:** Before Changing Code Checklist
**Description:** Protocol AI Agents must follow before modifying application code.
**Required Behavior:** The Agent must:
1. Identify the relevant business rules in `docs/business-rules/`.
2. Ensure the proposed change aligns with documented rules.
3. Review the current code architecture and `Implementation Location`.
4. Run static analysis or search for potential impact on existing modules.
5. Provide a summary of changes and how they fulfill the rule.
**Prohibited Behavior:** Making speculative changes without consulting business rule documents.
**Related Entities:** Codebase, Documentation
**Status:** Confirmed
**Implementation Location:** `docs/business-rules/AI_AGENT_RULES.md`

### BR-AI-002
**Name:** The NEVER List
**Description:** Absolute restrictions for AI Agent code modifications.
**Required Behavior:** The AI Agent must NEVER:
- Hardcode business logic that should be parameter-driven.
- Bypass established RBAC rules (e.g., adding backdoor access).
- Drop or alter historical financial data structures.
- Ignore the 6-way financial verification protocol when touching financial data.
- Introduce arbitrary metrics not defined in `REPORTING_RULES.md`.
**Prohibited Behavior:** Violating any item on the NEVER list.
**Related Entities:** AI Agent, Codebase
**Status:** Confirmed
**Implementation Location:** `docs/business-rules/AI_AGENT_RULES.md`

### BR-AI-003
**Name:** Rule Change Protocol
**Description:** Protocol for when an AI Agent needs to update or proposes a change to a business rule.
**Required Behavior:** The Agent must:
1. Propose the rule change explicitly to the user.
2. Wait for explicit user confirmation before updating the `docs/business-rules/` files.
3. Document the discrepancy between the code and the current rule if code disagrees with a confirmed rule.
4. Update the Rule's `Status` and `Implementation Location` accurately.
**Prohibited Behavior:** Silently altering business rules without user approval.
**Related Entities:** AI Agent, Business Rule Documents
**Status:** Confirmed
**Implementation Location:** `docs/business-rules/AI_AGENT_RULES.md`

### BR-AI-004
**Name:** Bug Fix Protocol
**Description:** Protocol for handling identified bugs.
**Required Behavior:** The Agent must:
1. Identify which specific Business Rule the bug violates.
2. Formulate a fix that strictly adheres to the violated rule.
3. Ensure no regression to other rules (e.g., RBAC or Reporting).
4. Clearly state the Rule ID when describing the fix.
**Prohibited Behavior:** Fixing bugs using workarounds that violate other established rules.
**Related Entities:** AI Agent, Bug Tracker, Codebase
**Status:** Confirmed
**Implementation Location:** `docs/business-rules/AI_AGENT_RULES.md`
