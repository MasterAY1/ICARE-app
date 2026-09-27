# Parity Catalogue: 10 — User Management

**Source Implementation**: `app.py` L13862–14316  
**Navigation & Sidebar Source**: `services/rbac_scope_service.py` L34–45 (`ROLE_NAVIGATION`), `app.py` L1925–2000  
**Backend Domain Authority**:
- `services/user_service.py` (`UserService`)
- `services/audit_log_service.py` (`AuditLogService`)
- `services/schedule_service.py` (`ScheduleService.reschedule_branch_loans_on_closure`)
- `database/repositories/user_repository.py` (`SupabaseUserRepository`)
- `database/repositories/branch_closure_repository.py` (`SupabaseBranchClosureRepository`)
- `database/repositories/user_audit_log_repository.py` (`SupabaseUserAuditLogRepository`)
- `database/repositories/login_history_repository.py` (`SupabaseLoginHistoryRepository`)  
**Target Screen**: `frontend_flutter/lib/features/bm/presentation/user_management_screen.dart`  
**API Routes Prefix**: `/api/v1/users`  
- `GET /api/v1/users` — List users scoped to caller's role (`UserService.list_users`)
- `POST /api/v1/users` — Create new user (Admin only)
- `POST /api/v1/users/{user_id}/status` — Activate / Deactivate user (Admin or BM for own branch staff)
- `DELETE /api/v1/users/{user_id}` — Permanently delete user with confirmation (Admin only)
- `POST /api/v1/users/password-reset` — Reset user password (Admin or BM for branch staff)
- `POST /api/v1/users/officer-turnover` — Update officer display name (Admin only)
- `GET /api/v1/users/products/meta` — Get available products & COs with assigned products
- `POST /api/v1/users/products/assign` — Update CO allowed products (Admin or BM)
- `GET /api/v1/users/am-assignments` — Get AM users & assigned branches (Admin only)
- `POST /api/v1/users/am-assignments` — Save AM branch assignments (Admin only, 5–7 branches)
- `GET /api/v1/users/closures` — List branch closures (scoped for BM, global for Admin)
- `POST /api/v1/users/closures` — Add closure & auto-reschedule loans
- `DELETE /api/v1/users/closures/{closure_id}` — Delete custom closure
- `GET /api/v1/users/audit-logs` — Query recent audit logs (scoped for BM, system-wide for Admin)
- `GET /api/v1/users/login-history` — Query recent login history (Admin only)

---

## 1. Page Title & Subtitle
* **Title**: `User Management` (`<h1>User Management</h1>`, `app.py` L13873)
* **Subtitle**: `Manage application users, reset passwords, and handle officer turnover.` (`app.py` L13874)
* **Zero-Emoji Governance (Rule 10)**: Strict zero emoji characters in tabs, form buttons, table headers, alerts, badges, or modals. Use clean corporate typography and Flutter Material/SVG icons.

---

## 2. Role-Adaptive Navigation & Tab Configuration

### 2.1 Admin / Super Admin (`is_admin`) — 9 Tabs
1. `Users Directory` (`app.py` L13921–13975)
2. `Create User` (`app.py` L13977–14004)
3. `Password Reset` (`app.py` L14006–14024)
4. `Officer Turnover` (`app.py` L14026–14055)
5. `Product Assignment` (`app.py` L14056–14115)
6. `AM Assignments` (`app.py` L14117–14165)
7. `Branch Closures` (`app.py` L14166–14253)
8. `Audit Logs` (`app.py` L14279–14297)
9. `Login History` (`app.py` L14298–14316)

### 2.2 Branch Manager (`is_bm`) — 5 Tabs
1. `Branch Staff` (`app.py` L13921–13975 scoped to branch)
2. `Password Reset` (`app.py` L14006–14024 scoped to branch staff)
3. `Product Assignment` (`app.py` L14056–14115 scoped to branch COs)
4. `Branch Closures` (`app.py` L14166–14253 scoped to branch closures)
5. `Branch Activity Logs` (`app.py` L14254–14277 scoped to branch audit logs)

### 2.3 Area Manager (`is_am`) — 1 Tab
1. `Branch Staff (Read Only)` (`app.py` L13915, read-only table across assigned branches)

### 2.4 Credit Officer (`CO`) — Access Prohibited
* Error callout: `You do not have permission to access User Management.` (fails closed per `FP-001`).

---

## 3. Tab Specifications

### Tab 1: Users Directory / Branch Staff
* **Header**: `Current Users`
* **DataTable Columns**:
  - `Username` (`username`)
  - `Full Name` (`full_name`)
  - `Role` (`role`)
  - `Branch` (`branch_name`)
  - `Status` (`Active` / `Inactive` badge)
  - `Last Login` (`last_login` or `Never`)
  - `Created At` (`created_at`)
* **Status Management Section** (Admin & BM):
  - Subheader: `Manage User Status & Deletion`
  - Select User dropdown (`selectUser`)
  - Current Status indicator (`Active` in green vs `Inactive` in red)
  - Action Buttons (2 columns):
    - `Activate` (Primary green, disabled if already active)
    - `Deactivate` (Amber/Orange, disabled if already inactive)
* **Danger Zone (Permanent Deletion)** (Admin Only):
  - Collapsible red-accented expander: `Danger Zone (Permanent Deletion)`
  - Explanatory text: `Deleting a user permanently removes them from the database. If this user has logged transactions, clients, or loans, their reference will be preserved as empty/null in historical audit logs.`
  - Confirmation Checkbox: `Confirm I want to permanently delete the user '{username}'`
  - Action Button: `Permanently Delete User` (Red `#DC2626`, disabled until confirmation checkbox is checked)

### Tab 2: Create User (Admin Only)
* **Header**: `Add New User`
* **Information Callout**: `Only Head Office administrators can create new users.`
* **Form Controls**:
  - `Username`: Text input (placeholder `e.g. CO5, BM_Ikeja`)
  - `Full Name`: Text input (placeholder `e.g. Mr. Ayomide`)
  - `Role`: Dropdown with `Credit Officer`, `Branch Manager`, `Area Manager`, `Admin`, `Super Admin`, `Account Manager`
  - `Branch Name`: Dropdown of active branches (or `All / Head Office`)
  - `Password`: Masked text input with eye icon toggle
* **Form Action**: Full-width `Create User` button (calls `UserService.create_user`)

### Tab 3: Password Reset (Admin & BM)
* **Header**: `Reset Password`
* **BM Notice** (if BM): `You can only reset passwords for staff in your branch.`
* **Form Controls**:
  - Select User dropdown
  - `New Password`: Masked text input
* **Form Action**: Full-width `Reset Password` button (calls `UserService.reset_password`)

### Tab 4: Officer Turnover (Admin Only)
* **Header**: `Update Officer Name (Turnover)`
* **Information Callout**: `When an officer leaves, update the Full Name tied to their generic username (e.g. CO2) so that historical data remains intact but the new officer's name is used going forward.`
* **Controls**:
  - Select Officer ID dropdown (filtered to Credit Officers only)
  - Display current name: `Current Name: {current_name}`
  - `New Full Name`: Text input
* **Form Action**: Full-width `Update Officer Name` button (calls `UserService.update_officer_name`)

### Tab 5: Product Assignment (Admin & BM)
* **Header**: `Assign Products to Credit Officers`
* **Information Callout**: `Assign specific loan products to a Credit Officer. If left completely blank, the officer will have access to ALL products.`
* **Controls**:
  - Select Credit Officer dropdown
  - Displays officer full name: `Name: {full_name}`
  - Allowed Products multiselect (checkbox chips) containing active loan products from `loan_products` table
* **Form Action**: Full-width `Save Assignments` button (updates `app_users.extra_fields["allowed_products"]`)

### Tab 6: AM Branch Assignments (Admin Only)
* **Header**: `Area Manager Branch Assignments`
* **Information Callout**: `Each Area Manager supervises 5-7 branches. Assign branches below.`
* **Controls**:
  - Select Area Manager dropdown
  - Current summary: `Currently Assigned ({count}): {branch_names}`
  - Multiselect Branches list with count validator badge (Must be between 5 and 7)
* **Form Action**: Full-width `Save Assignments` button (calls `UserService.save_am_assignments`)

### Tab 7: Branch Settings & Closures (Admin & BM)
* **Header**: `Branch Settings & Closures`
* **Description**: `Manage custom branch closures (e.g., operational shutdowns, end-of-year breaks). These dates will be strictly excluded when calculating loan repayment schedules.`
* **Dual-Column Layout**:
  - **Left Column: Add New Closure**:
    - Select Date Range (`Start Date` and `End Date` date pickers)
    - `Reason` text input (e.g., `End of Year Break`)
    - `Target Branch` dropdown (Global / All Branches option for Admin; pre-locked to branch for BM)
    - Action button: `Save Closure` (calls `uow.branch_closures.create` & `ScheduleService.reschedule_branch_loans_on_closure`)
  - **Right Column: Active Closures**:
    - Table displaying: `Start Date`, `End Date`, `Reason`, `Branch`
    - Action icon to delete closure with confirmation

### Tab 8: Audit Logs / Branch Activity Logs
* **Admin Header**: `System Audit Logs`
* **BM Header**: `Branch Activity Logs ({BRANCH})`
* **Subtitle**: `Immutable audit trail for operational activities within {BRANCH} branch.`
* **DataTable Columns**:
  - `Timestamp` (`timestamp`)
  - `Username` (`username`)
  - `Role` (`role`)
  - `Branch` (`branch`)
  - `Action` (`action`)
  - `Module` (`module`)
  - `Entity Type` (`entity_type`)
  - `Display Name` (`display_name`)
  - `Status` (`status` badge)

### Tab 9: Login History (Admin Only)
* **Header**: `Login History`
* **DataTable Columns**:
  - `Login Time` (`login_time`)
  - `Username` (`username`)
  - `Status` (`SUCCESS` in green vs `FAILURE` in red)
  - `Session ID` (`session_id`)
  - `Logout Time` (`logout_time` or `Active`)
  - `Failed Attempts` (`failed_attempts`)

---

## 4. Architectural & Financial Invariants
1. **Immutable Audit Trail**: All user actions (creates, activations, deactivations, password resets, turnover, deletions, branch assignments) must write to `user_audit_logs` via `AuditLogService`.
2. **Branch Closure Invariant**: Adding a branch closure must immediately invoke `ScheduleService.reschedule_branch_loans_on_closure` so future loan installments are pushed to the next valid working business day.
3. **AM 5–7 Branch Invariant**: Area Manager assignments must validate that `5 <= count <= 7`.
4. **Scope Isolation**: Branch Managers can NEVER view, edit, or reset passwords for Head Office Admin or Area Manager accounts.
5. **Zero Data Contamination**: Verification scripts must perform strictly read-only assertions against the live database.
