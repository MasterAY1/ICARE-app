# ICARE GLOBAL NAVIGATION CATALOGUE

> Authority: `services/rbac_scope_service.py` and `MIGRATION_AUTHORITY.md` take precedence. This file may not be used to add a Flutter destination that is absent from the current Streamlit role menu.

> **MANDATORY REFERENCE**: Sourced from `services/rbac_scope_service.py` (`ROLE_NAVIGATION`) and `app.py` (`st.sidebar` L1925–1990).

---

## 1. Role-to-Sidebar Menu Structure

| Role | Permitted Menu Items (Exact Order) | Default Route | Scope Level |
|---|---|---|---|
| **Credit Officer (`CO`)** | 1. `Dashboard`<br>2. `Loan Origination`<br>3. `Collections`<br>4. `Withdrawal Operations`<br>5. `Portfolio`<br>6. `CO Cashbook` | `Dashboard` | `OFFICER` (Own clients, own groups, assigned branch) |
| **Branch Manager (`BM`)** | 1. `Dashboard`<br>2. `Portfolio`<br>3. `Master Cashbook`<br>4. `User Management`<br>5. `Audit Ledger`<br>6. `Reports & Export` | `Dashboard` | `BRANCH` (All officers, all clients, all groups in assigned branch) |
| **Area Manager (`AM`)** | 1. `Dashboard`<br>2. `Portfolio`<br>3. `Master Cashbook`<br>4. `CO Cashbook`<br>5. `User Management`<br>6. `Audit Ledger`<br>7. `Reports & Export` | `Dashboard` | `REGION` (All branches within assigned region) |
| **Administrator (`Admin`)** | 1. `Dashboard`<br>2. `Portfolio`<br>3. `Loan Origination`<br>4. `Collections`<br>5. `Withdrawal Operations`<br>6. `Legacy LAPS Migration`<br>7. `CO Cashbook`<br>8. `Master Cashbook`<br>9. `User Management`<br>10. `Audit Ledger`<br>11. `Reports & Export` | `Dashboard` | `INSTITUTION` (Global access across all branches and users) |
| **Executive Director (`Director`)** | 1. `Dashboard`<br>2. `Portfolio`<br>3. `Loan Origination`<br>4. `Collections`<br>5. `Withdrawal Operations`<br>6. `Audit Ledger`<br>7. `Reports & Export` | `Dashboard` | `INSTITUTION` (Global strategic read-only view) |

---

## 2. Navigation Behavior & Rules

1. **Active Route Selection**: Selected via Streamlit Radio widget (`st.sidebar.radio("Navigation", nav_options)`).
2. **Access Control Guard (`app.py` L1971–1976)**: If a user attempts to route to a page outside `RBACScopeService.is_page_permitted(scope.role, page)`, the execution halts immediately:
   * Error: `⚠️ Access Denied: You do not have permission to access this page.`
   * Info: `If you believe this is an error, please contact your System Administrator.`
   * Call: `st.stop()`.
3. **Cross-Page Quick Navigation Actions**:
   * *Dashboard $\rightarrow$ Collections*: Quick action buttons on `Today's Meeting Portfolio` set `session_state["Navigation"] = "Collections"` and `session_state["sel_group"] = group_name`.
   * *Dashboard $\rightarrow$ Audit Center*: Audit button on Executive/Admin dashboard sets `session_state["Navigation"] = "Audit Ledger"`.
4. **Sign Out Action (`app.py` L1980–1990)**: Clears auth tokens from URL query parameters (`auth`, `auth_token`), deletes all keys from `st.session_state`, sets `logged_in = False`, and reruns.

---

## 3. Parity Verification Evidence (Phase 2: App Shell & CO Sidebar)

* **Visual Parity**: 1:1 match to `media_1788063430479.png` (Top red bar `#FF4B4B`, circular logo, `CORE BANKING v3.0.0 (st v1.38.0)`, officer card with `Credit Officer` badge `#8CC63F` and branch name, `OPERATIONS` label, 6 radio options, divider, full-width `Sign Out` button).
* **Welcome Banner Parity**: Matches `app.py` L1991–2000 (Forest Green `#064E3B` container, dynamic greeting by hour, role label, branch name in gold/green accent, formatted system date).
* **Functional Parity**: Radio item selection switches active page state; `Sign Out` triggers `AuthController.logout()` and returns to `LoginScreen`.
* **RBAC Parity**: Exact 6 menu items matching `RBACScopeService.ROLE_NAVIGATION["CO"]`.
* **Flutter Implementation**: [`frontend_flutter/lib/features/shared/presentation/co_app_scaffold.dart`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/frontend_flutter/lib/features/shared/presentation/co_app_scaffold.dart)
* **Status**: **PARITY VERIFIED**

