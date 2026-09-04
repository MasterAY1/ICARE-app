# ICARE FLUTTER MIGRATION - ZERO REDESIGN CONSTITUTION

This migration is a REPLICATION exercise.

The existing Streamlit frontend is the reference implementation.

The agent MUST NOT make design decisions based on its own preferences.

The agent MUST NOT invent UI.

The agent MUST NOT redesign UI.

The agent MUST NOT rename UI.

The agent MUST NOT simplify UI.

The agent MUST NOT modernize UI.

The agent MUST NOT add placeholder UI that pretends to represent
functionality that has not yet been connected.

The agent MUST NOT hardcode business data, financial values, portfolio
values, cashbook values, dashboard metrics, client records, or API
responses.

The agent MUST NOT invent page names.

The agent MUST NOT invent navigation structures.

The agent MUST NOT add dashboard cards that do not exist in Streamlit.

The agent MUST NOT remove existing controls unless they are explicitly
approved.

The agent MUST NOT change field labels.

The agent MUST NOT change table columns.

The agent MUST NOT change workflow order.

The agent MUST NOT create fake/sample data in production-facing screens.

The only acceptable reason for something to look different from Streamlit
during the parity stage is a technical limitation of Flutter.

When that occurs, document the difference.

DO NOT "improve" it.

==================================================
FORBIDDEN
==================================================

NO:
- AI-generated design
- speculative redesign
- invented page titles
- invented metrics
- hardcoded financial values
- fake dashboards
- placeholder business logic presented as real
- arbitrary icons
- unnecessary emojis
- decorative gradients
- glassmorphism
- unrelated animations
- invented navigation
- invented workflows
- fake API responses
- duplicate business logic
- guessed database values

==================================================
MANDATORY
==================================================

Before creating ANY Flutter page:

1. Locate the exact Streamlit page.
2. Read its complete relevant implementation.
3. Record its visible elements.
4. Record its exact labels.
5. Record its layout hierarchy.
6. Record its controls.
7. Record its tables.
8. Record its data sources.
9. Record its API/backend dependencies.
10. Record its role permissions.
11. Record its actions.
12. Record its validation behaviour.

Then create a PAGE PARITY SPECIFICATION.

Do not write Flutter code yet.

The page must first exist as a documented specification.

==================================================
PAGE PARITY SPECIFICATION

PAGE:
ROLE:

STREAMLIT SOURCE:

PAGE TITLE:
Exact text.

NAVIGATION LABEL:
Exact text.

SECTIONS:
Exact order.

COMPONENTS:
Every visible component.

FIELDS:
Exact labels and types.

TABLES:
Exact columns and ordering.

BUTTONS:
Exact labels and actions.

FILTERS:
Exact controls.

MESSAGES:
Exact success/error/warning behaviour.

ROLE VISIBILITY:
Exact permissions.

DATA:
Where each displayed value originates.

API:
Required endpoint.

WORKFLOW:
Exact sequence of user actions.

==================================================
NO HARDCODED DATA RULE

Flutter may display:

- API data
- authenticated user data
- local UI state
- explicit constants such as labels and configuration

Flutter MUST NOT hardcode:

- client records
- loan records
- cashbook balances
- collections
- savings
- portfolio values
- dashboard financial numbers
- officer performance
- branch values
- audit records

If the backend endpoint does not exist:

STOP.

Report:

MISSING API CONTRACT

Do not invent a response.

==================================================
NO PAGE CREATION WITHOUT EVIDENCE

If the agent cannot identify the corresponding Streamlit page:

STOP.

Do not create an equivalent page from imagination.

Report the ambiguity.

==================================================
NO RENAMING

Flutter names must initially match the Streamlit application.

Example:

Streamlit:
Audit Ledger

Flutter:
Audit Ledger

NOT:

Activity Center
Transaction Monitor
Audit Dashboard
My Activity

Any future naming improvement belongs to a separate post-parity phase.

==================================================
NO ARCHITECTURAL EXPANSION

Do not create additional business layers merely because Flutter
architecture patterns recommend them.

Use the smallest architecture necessary to reproduce the page.

Do not create:

- fake repositories
- speculative domain models
- duplicate business engines
- unused abstractions
- placeholder services

==================================================
PARITY GATE

A page is not complete until:

VISUAL:
- structure matches
- labels match
- controls match
- tables match
- ordering matches

FUNCTIONAL:
- actions work
- validation works
- permissions work
- navigation works
- errors work

DATA:
- real API data
- no hardcoded business values
- correct field mapping

ROLE:
- correct visibility
- correct permissions

If any category fails:

PARITY NOT VERIFIED.

==================================================
FINAL RULE

If the agent is unsure what Streamlit does:

DO NOT GUESS.

READ MORE CODE.
