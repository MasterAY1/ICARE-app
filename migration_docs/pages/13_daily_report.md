# PAGE IDENTITY

- Route: `Daily Report`
- Exact page title: `Daily Collections Report`
- Source: `app.py` 5666–5910
- Sidebar label: none in the current `ROLE_NAVIGATION` menu

# VERIFIED LAYOUT AND CONTROLS

1. Page title.
2. Credit-officer selector for authorized managers (`Select Credit Officer`).
3. Three summary columns headed `🐷 Savings Summary`, `🏦 Credit Summary`, and `💵 Cashbook (Teller)`.
4. Detailed report dataframe.
5. `Flag an Error / Request Reversal` expander with `Select Transaction` and `Submit Correction Request`.

# RBAC / DATA / STATES

The manager credit-officer selector is conditional. The report uses current Streamlit services/repositories and direct data access; no HTTP API is proven. Source shows errors/success notifications around correction submission. Full table-column and service-chain inventory remains required before Flutter implementation.
