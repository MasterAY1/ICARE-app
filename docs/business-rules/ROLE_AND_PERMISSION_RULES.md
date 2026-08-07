# Role and Permission Rules

## System Roles
- **Super Admin**: Full system access, bulk onboarding, legacy migrations, user management
- **Admin**: Full system access, user management, bulk onboarding
- **Area Manager**: Multi-branch visibility (assigned branches), can approve disbursements, view area-level dashboards
- **Branch Manager**: Branch-scoped, approves loans/disbursements/withdrawals, closes business day, master cashbook access
- **Credit Officer**: Officer-scoped, creates loan applications, enters collections, CO cashbook, cannot approve anything
- **Account Manager**: Read-only variant

## Rules

### BR-RBAC-001
**Name:** Organizational Hierarchy
**Description:** Defines the core organizational hierarchy and reporting lines.
**Required Behavior:** The system must enforce the hierarchy: Director → Area Manager → Branch Manager → Credit Officer.
**Prohibited Behavior:** Users cannot bypass the hierarchy for approvals or reporting.
**Related Entities:** User, Role, Organization Hierarchy
**Status:** Confirmed
**Implementation Location:** `config/roles.py`, `app_users/user_roles/roles/permissions` tables

### BR-RBAC-002
**Name:** Credit Officer Scope
**Description:** Restricts Credit Officer visibility to their assigned entities.
**Required Behavior:** Credit Officers can only view and manage their assigned clients and groups.
**Prohibited Behavior:** Credit Officers must not view data belonging to other officers' clients.
**Related Entities:** Credit Officer, Client, Group
**Status:** Confirmed
**Implementation Location:** `services/rbac_scope_service.py`

### BR-RBAC-003
**Name:** Branch Manager Scope
**Description:** Defines the visibility scope for Branch Managers.
**Required Behavior:** Branch Managers must have visibility over the entire branch they are assigned to.
**Prohibited Behavior:** Branch Managers cannot view data of branches they do not manage.
**Related Entities:** Branch Manager, Branch, Client, Group
**Status:** Confirmed
**Implementation Location:** `services/rbac_scope_service.py`

### BR-RBAC-004
**Name:** Area Manager Scope
**Description:** Defines the visibility scope for Area Managers.
**Required Behavior:** Area Managers must have visibility over all branches assigned to their area.
**Prohibited Behavior:** Area Managers cannot view data outside their assigned branches.
**Related Entities:** Area Manager, Branch
**Status:** Confirmed
**Implementation Location:** `services/rbac_scope_service.py`

### BR-RBAC-005
**Name:** Loan Approval Authorization
**Description:** Restricts loan approval capabilities.
**Required Behavior:** Only Branch Managers, Area Managers, and Admins can approve loans.
**Prohibited Behavior:** Credit Officers or Account Managers must not be able to approve loans.
**Related Entities:** Loan Application, User, Role
**Status:** Confirmed
**Implementation Location:** `app.py` (navigation guards), `services/rbac_scope_service.py`

### BR-RBAC-006
**Name:** Withdrawal Approval Authorization
**Description:** Restricts savings withdrawal approval capabilities.
**Required Behavior:** Only Branch Managers, Area Managers, and Admins can approve savings withdrawals.
**Prohibited Behavior:** Credit Officers must not be able to approve withdrawals.
**Related Entities:** Savings Account, Transaction, User, Role
**Status:** Confirmed
**Implementation Location:** `app.py` (navigation guards), `services/rbac_scope_service.py`

### BR-RBAC-007
**Name:** Transaction Reversal Authorization
**Description:** Restricts transaction reversal capabilities.
**Required Behavior:** Only Manager-level users and above (Branch Manager, Area Manager, Admin) can reverse transactions.
**Prohibited Behavior:** Credit Officers cannot reverse any transactions.
**Related Entities:** Transaction, User, Role
**Status:** Confirmed
**Implementation Location:** `app.py` (navigation guards), `services/rbac_scope_service.py`

### BR-RBAC-008
**Name:** Bulk Onboarding and Migration Authorization
**Description:** Restricts access to bulk operations and legacy data migration.
**Required Behavior:** Only Admin and Super Admin users can bulk onboard or perform legacy migrations.
**Prohibited Behavior:** Managers and Officers cannot access bulk onboarding or migration tools.
**Related Entities:** User, Role, Bulk Operations, Migration Tools
**Status:** Confirmed
**Implementation Location:** `config/roles.py`, `app.py` (navigation guards)

### BR-RBAC-009
**Name:** End of Day Authorization
**Description:** Restricts capability to close the business day.
**Required Behavior:** Only the Branch Manager is authorized to close the business day for their branch.
**Prohibited Behavior:** Other roles cannot initiate or complete the end-of-day process.
**Related Entities:** Branch, End of Day, Role
**Status:** Confirmed
**Implementation Location:** `services/rbac_scope_service.py`, `app.py`

### BR-RBAC-010
**Name:** Strict Backend Authorization
**Description:** Enforces security at the application level.
**Required Behavior:** Authorization must be enforced at the application/API level (backend), not only via UI visibility.
**Prohibited Behavior:** Relying solely on hiding UI elements for security.
**Related Entities:** All System Endpoints, Services
**Status:** Confirmed
**Implementation Location:** `services/rbac_scope_service.py`, `app.py`

### BR-RBAC-011
**Name:** Product Access per Officer
**Description:** Determines which financial products an officer can offer.
**Required Behavior:** Allowed products per officer must be defined via `extra_fields`.
**Prohibited Behavior:** Officers cannot offer products not assigned to them in their `extra_fields`.
**Related Entities:** Credit Officer, Product, User
**Status:** Confirmed
**Implementation Location:** `config/roles.py`, `services/rbac_scope_service.py`
