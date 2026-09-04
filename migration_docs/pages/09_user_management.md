# PAGE IDENTITY — CORRECTED

- Route/sidebar label: `User Management`
- Exact heading: `🔐 User Management` (HTML heading)
- Source: `app.py` 9488–9929

## Source-verified RBAC and controls

- Admin tabs: `Users Directory`, `Create User`, `Password Reset`, `Officer Turnover`, `Product Assignment`, `AM Assignments`, `Branch Closures`, `Audit Logs`, `Login History`.
- BM tabs: `Branch Staff`, `Password Reset`, `Product Assignment`, `Branch Closures`, `Branch Activity Logs`.
- AM tab: `Branch Staff (Read Only)`.

The users directory includes `Select User`, `✅ Activate`, `❌ Deactivate`, and, for Admin only, the `⚠️ Danger Zone (Permanent Deletion)` expander plus confirmation checkbox and `🔥 Permanently Delete User`. User creation fields are `Username (e.g. CO5, BM_Ikeja)`, `Full Name (e.g. Mr. Ayomide)`, `Role`, `Branch Name (e.g. Ogijo)`, and `Password`, submitted with `Create User`.

The current UI uses `UserService`; no `/api/v1/admin/users` contract is established by this source trace.

> The remainder is superseded wherever it conflicts with this source-verified correction.

# Superseded document content

* **Exact page title**: `Staff & User Management`
* **Sidebar label**: `User Management`
* **Role(s)**: `Branch Manager`, `Area Manager`, `Administrator`
* **Navigation location**: Fourth menu item for BM, ninth for Admin
* **Streamlit source**: `app.py` L9488–9930
* **Relevant line ranges**: L9488–9930

# PAGE PURPOSE

Enables administrators and branch managers to onboard staff members, create system user accounts, assign RBAC security roles (`Credit Officer`, `Branch Manager`, `Area Manager`, `Admin`), link officers to physical branches, manage passwords, and activate/deactivate accounts.

# PAGE LAYOUT

1. **Header**: `st.title("Staff & User Management")`
2. **Tab Navigation**:
   * Tab 1: `👥 Staff Directory`
   * Tab 2: `➕ Create New User`
   * Tab 3: `🔑 Role & Branch Assignments`
3. **Staff Directory Table**: Active staff listing with status indicators.
4. **User Creation & Edit Forms**.

# SECTION INVENTORY

1. **Staff Directory**: Master list of staff with role badges, branch assignments, and last login dates.
2. **User Onboarding Form**: Full Name, Username, Email, Phone Number, Password, Role, Assigned Branch.
3. **Account Status Controls**: Deactivate/Reactivate button, Reset Password modal.

# UI COMPONENT INVENTORY

* **User Creation Form**: Input fields with validation.
* **Role Dropdown**: `Credit Officer`, `Branch Manager`, `Area Manager`, `Administrator`, `Director`.
* **Branch Dropdown**: Active branch list from `branches` table.
* **Data Table**: Staff directory with actions.

# LABEL INVENTORY

* Page Title: `Staff & User Management`
* Tabs: `👥 Staff Directory`, `➕ Create New User`, `🔑 Role & Branch Assignments`
* Fields: `Full Name`, `Username`, `Email`, `Phone`, `Password`, `Role`, `Assigned Branch`
* Buttons: `Create User Account`, `Update Role / Branch`, `Deactivate Account`, `Reset Password`

# FORM INVENTORY

* **`create_user_form`**: Inserts record into `app_users` and `user_roles`.
* **`edit_user_form`**: Updates user assignments.

# TABLE INVENTORY

* **Staff Directory Table**: `[User ID, Username, Full Name, Role, Branch, Status, Created At, Action]`

# BUTTON INVENTORY

* `Create User Account`: Posts new user payload to backend.

# FILTER INVENTORY

* Branch Filter & Role Filter.

# NAVIGATION BEHAVIOUR

* Accessible to administrative and management roles.

# RBAC BEHAVIOUR

* `CO`: Access Denied.
* `BM`: Can only manage officers in assigned branch.
* `Admin`: Global user administration across all roles and branches.

# DATA CONTRACT

* `GET /api/v1/admin/users`
* `POST /api/v1/admin/users/create`
* `PUT /api/v1/admin/users/{id}/status`

# WORKFLOW

1. Admin/BM opens `User Management`.
2. Fills in new officer details $\rightarrow$ Assigns role `Credit Officer` and branch.
3. Submits form $\rightarrow$ User created and immediately available in officer dropdowns.

# STATES

* Success: `User account created successfully!`
* Error: `Username or Email already exists.`

# VISUAL CHARACTERISTICS

* Clean administrative dashboard with user avatar placeholders and role badges.

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L9488–9930.
