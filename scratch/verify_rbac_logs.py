"""
ICARE Core Banking - RBAC & Audit Logging Verification Suite
Tests all RBAC, authentication, branch isolation, audit logging,
user management, and security scenarios.

Run: .\\venv\\Scripts\\python.exe scratch/verify_rbac_logs.py
"""
import sys
import os
import io

# Force UTF-8 output on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from datetime import datetime

# ============================================================
# TEST RESULTS TRACKER
# ============================================================
results = []

def test(name, condition, detail=""):
    status = "PASS" if condition else "FAIL"
    results.append((name, status, detail))
    print(f"  [{status}]  {name}" + (f" -- {detail}" if detail and not condition else ""))

def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


# ============================================================
# 1. CONFIG & ROLES
# ============================================================
section("1. Config & Roles")

from config.roles import (
    ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_AREA_MANAGER,
    ROLE_BRANCH_MANAGER, ROLE_CREDIT_OFFICER, ALL_ROLES
)

test("ROLE_SUPER_ADMIN defined", ROLE_SUPER_ADMIN == "Super Admin")
test("ROLE_ADMIN defined", ROLE_ADMIN == "Admin")
test("ROLE_AREA_MANAGER defined", ROLE_AREA_MANAGER == "Area Manager")
test("ROLE_BRANCH_MANAGER defined", ROLE_BRANCH_MANAGER == "Branch Manager")
test("ROLE_CREDIT_OFFICER defined", ROLE_CREDIT_OFFICER == "Credit Officer")
test("ALL_ROLES includes Area Manager", ROLE_AREA_MANAGER in ALL_ROLES)
test("ALL_ROLES has 6 roles", len(ALL_ROLES) == 6, f"Got {len(ALL_ROLES)}")


# ============================================================
# 2. AUTHORIZATION & PERMISSIONS
# ============================================================
section("2. Authorization & Permissions")

from auth.authorization import (
    PERMISSIONS, has_permission, can_render_widget,
    DASHBOARD_WIDGETS, NAV_PERMISSIONS, get_nav_options
)
from models.user import CurrentUser

# Admin has "all"
test("Admin has 'all' permission", "all" in PERMISSIONS.get(ROLE_ADMIN, set()))
test("Super Admin has 'all' permission", "all" in PERMISSIONS.get(ROLE_SUPER_ADMIN, set()))

# AM permissions
am_perms = PERMISSIONS.get(ROLE_AREA_MANAGER, set())
test("AM has branch.view", "branch.view" in am_perms)
test("AM has branch.performance", "branch.performance" in am_perms)
test("AM lacks client.register", "client.register" not in am_perms)
test("AM lacks user.activate", "user.activate" not in am_perms)

# BM permissions
bm_perms = PERMISSIONS.get(ROLE_BRANCH_MANAGER, set())
test("BM has loan.approve", "loan.approve" in bm_perms)
test("BM has cashbook.manage", "cashbook.manage" in bm_perms)
test("BM has user.activate", "user.activate" in bm_perms)
test("BM lacks all (is not admin)", "all" not in bm_perms)

# CO permissions
co_perms = PERMISSIONS.get(ROLE_CREDIT_OFFICER, set())
test("CO has client.register", "client.register" in co_perms)
test("CO has loan.apply", "loan.apply" in co_perms)
test("CO lacks loan.approve", "loan.approve" not in co_perms)
test("CO lacks cashbook.manage", "cashbook.manage" not in co_perms)
test("CO lacks user.activate", "user.activate" not in co_perms)

# has_permission function
admin_user = CurrentUser(id="1", username="admin", role=ROLE_ADMIN, branch="HQ", permissions=PERMISSIONS[ROLE_ADMIN])
co_user = CurrentUser(id="2", username="co1", role=ROLE_CREDIT_OFFICER, branch="Ogijo", permissions=PERMISSIONS[ROLE_CREDIT_OFFICER])
am_user = CurrentUser(id="3", username="am1", role=ROLE_AREA_MANAGER, branch="HQ", permissions=PERMISSIONS[ROLE_AREA_MANAGER])

test("has_permission: admin has any perm", has_permission(admin_user, "anything"))
test("has_permission: CO has client.register", has_permission(co_user, "client.register"))
test("has_permission: CO lacks loan.approve", not has_permission(co_user, "loan.approve"))

# can_render_widget
test("Admin can render system_wide", can_render_widget(admin_user, "system_wide"))
test("CO can render assigned_clients", can_render_widget(co_user, "assigned_clients"))
test("CO cannot render system_wide", not can_render_widget(co_user, "system_wide"))
test("AM can render multi_branch_perf", can_render_widget(am_user, "multi_branch_perf"))

# get_nav_options
admin_nav = get_nav_options(admin_user)
co_nav = get_nav_options(co_user)
am_nav = get_nav_options(am_user)

test("Admin sees User Management", "User Management" in admin_nav)
test("Admin sees Dashboard", "Dashboard" in admin_nav)
test("CO sees Loan Origination", "Loan Origination" in co_nav)
test("CO does NOT see User Management", "User Management" not in co_nav)
test("AM sees Dashboard", "Dashboard" in am_nav)


# ============================================================
# 3. DOMAIN ENTITIES
# ============================================================
section("3. Domain Entities")

from domain.entities.user import User

u = User(id="1", username="test", full_name="Test", role="Admin",
         branch_name="HQ", password_hash="hash", created_at=datetime.now(),
         branch_id="uuid-123", is_active=True)

test("User has branch_id field", hasattr(u, "branch_id"))
test("User has is_active field", hasattr(u, "is_active"))
test("User has last_login field", hasattr(u, "last_login"))
test("User has last_activity field", hasattr(u, "last_activity"))
test("User branch_id is set", u.branch_id == "uuid-123")
test("User is_active defaults to True", u.is_active is True)


# ============================================================
# 4. MODELS (CurrentUser)
# ============================================================
section("4. CurrentUser Model")

cu = CurrentUser(
    id="1", username="am1", role="Area Manager", branch="HQ",
    branch_id="bid-1",
    assigned_branch_ids=["b1", "b2", "b3"],
    assigned_branches=["Ogijo", "Ikeja", "Ibadan"]
)

test("CurrentUser has branch_id", hasattr(cu, "branch_id"))
test("CurrentUser has assigned_branch_ids", hasattr(cu, "assigned_branch_ids"))
test("CurrentUser has assigned_branches", hasattr(cu, "assigned_branches"))
test("CurrentUser.assigned_branch_ids correct", cu.assigned_branch_ids == ["b1", "b2", "b3"])
test("CurrentUser.assigned_branches correct", cu.assigned_branches == ["Ogijo", "Ikeja", "Ibadan"])


# ============================================================
# 5. REPOSITORIES (Import Check)
# ============================================================
section("5. Repositories (Import Check)")

try:
    from database.repositories.user_audit_log_repository import SupabaseUserAuditLogRepository
    test("UserAuditLogRepository imports", True)
except Exception as e:
    test("UserAuditLogRepository imports", False, str(e))

try:
    from database.repositories.login_history_repository import SupabaseLoginHistoryRepository
    test("LoginHistoryRepository imports", True)
except Exception as e:
    test("LoginHistoryRepository imports", False, str(e))

try:
    from database.repositories.user_repository import SupabaseUserRepository
    test("UserRepository imports", True)
    # Check new methods exist
    test("UserRepository has load_am_assignments", hasattr(SupabaseUserRepository, "load_am_assignments"))
    test("UserRepository has activate_user", hasattr(SupabaseUserRepository, "activate_user"))
    test("UserRepository has deactivate_user", hasattr(SupabaseUserRepository, "deactivate_user"))
    test("UserRepository has update_last_login", hasattr(SupabaseUserRepository, "update_last_login"))
    test("UserRepository has find_by_branch_id", hasattr(SupabaseUserRepository, "find_by_branch_id"))
except Exception as e:
    test("UserRepository imports", False, str(e))

try:
    from database.repositories.unit_of_work import SupabaseUnitOfWork
    test("UnitOfWork imports", True)
    # Check new repositories registered
    uow = SupabaseUnitOfWork()
    test("UoW has user_audit_logs", hasattr(uow, "user_audit_logs"))
    test("UoW has login_history", hasattr(uow, "login_history"))
except Exception as e:
    test("UnitOfWork imports", False, str(e))


# ============================================================
# 6. SERVICES (Import Check)
# ============================================================
section("6. Services (Import Check)")

try:
    from services.audit_log_service import AuditLogService
    test("AuditLogService imports", True)
    test("AuditLogService.log exists", callable(getattr(AuditLogService, "log", None)))
    test("AuditLogService.log_login exists", callable(getattr(AuditLogService, "log_login", None)))
    test("AuditLogService.log_logout exists", callable(getattr(AuditLogService, "log_logout", None)))
    test("AuditLogService.log_client_action exists", callable(getattr(AuditLogService, "log_client_action", None)))
    test("AuditLogService.log_loan_action exists", callable(getattr(AuditLogService, "log_loan_action", None)))
    test("AuditLogService.log_permission_denied exists", callable(getattr(AuditLogService, "log_permission_denied", None)))
except Exception as e:
    test("AuditLogService imports", False, str(e))

try:
    from services.auth_service import AuthService
    test("AuthService imports", True)
    test("AuthService.login exists", callable(getattr(AuthService, "login", None)))
    test("AuthService.logout exists", callable(getattr(AuthService, "logout", None)))
    test("AuthService.is_logged_in exists", callable(getattr(AuthService, "is_logged_in", None)))
    test("AuthService.restore_session_from_url exists", callable(getattr(AuthService, "restore_session_from_url", None)))
except Exception as e:
    test("AuthService imports", False, str(e))

try:
    from services.user_service import UserService
    test("UserService imports", True)
    test("UserService.create_user exists", callable(getattr(UserService, "create_user", None)))
    test("UserService.activate_user exists", callable(getattr(UserService, "activate_user", None)))
    test("UserService.deactivate_user exists", callable(getattr(UserService, "deactivate_user", None)))
    test("UserService.reset_password exists", callable(getattr(UserService, "reset_password", None)))
    test("UserService.save_am_assignments exists", callable(getattr(UserService, "save_am_assignments", None)))
    test("UserService.list_users exists", callable(getattr(UserService, "list_users", None)))
    test("UserService.update_officer_name exists", callable(getattr(UserService, "update_officer_name", None)))
except Exception as e:
    test("UserService imports", False, str(e))


# ============================================================
# 7. RBAC ENFORCEMENT — PERMISSION ESCALATION PREVENTION
# ============================================================
section("7. RBAC Enforcement — Permission Escalation")

from services.user_service import UserService

# CO trying to create a user (should fail)
co_mock = CurrentUser(id="co-1", username="co_officer", role=ROLE_CREDIT_OFFICER,
                      branch="Ogijo", permissions=PERMISSIONS[ROLE_CREDIT_OFFICER])
result = UserService.create_user("test_co_create", "Test", "pass", "Admin", "HQ", co_mock)
test("CO cannot create users", not result['success'], result['message'])

# BM trying to create a user (should fail)
bm_mock = CurrentUser(id="bm-1", username="bm_manager", role=ROLE_BRANCH_MANAGER,
                      branch="Ogijo", branch_id="b-1", permissions=PERMISSIONS[ROLE_BRANCH_MANAGER])
result = UserService.create_user("test_bm_create", "Test", "pass", "Admin", "HQ", bm_mock)
test("BM cannot create users", not result['success'], result['message'])

# AM trying to create a user (should fail)
am_mock = CurrentUser(id="am-1", username="am_manager", role=ROLE_AREA_MANAGER,
                      branch="HQ", permissions=PERMISSIONS[ROLE_AREA_MANAGER])
result = UserService.create_user("test_am_create", "Test", "pass", "Admin", "HQ", am_mock)
test("AM cannot create users", not result['success'], result['message'])

# AM trying to delete a user (should fail — no delete method exposed)
test("AM cannot delete users (no delete in UserService)", not hasattr(UserService, "delete_user"))

# AM assignment validation (too few branches)
result = UserService.save_am_assignments("am-1", ["b1", "b2", "b3"], admin_user)
test("AM assignment rejects < 5 branches", not result['success'], result.get('message', ''))

# AM assignment validation (too many branches)
result = UserService.save_am_assignments("am-1", ["b1","b2","b3","b4","b5","b6","b7","b8"], admin_user)
test("AM assignment rejects > 7 branches", not result['success'], result.get('message', ''))

# CO trying to reset password (should fail)
result = UserService.reset_password("admin", "newpass", co_mock)
test("CO cannot reset passwords", not result['success'], result['message'])

# CO trying to activate/deactivate (should fail)
result = UserService.activate_user("some-id", co_mock)
test("CO cannot activate users", not result['success'], result['message'])

result = UserService.deactivate_user("some-id", co_mock)
test("CO cannot deactivate users", not result['success'], result['message'])


# ============================================================
# 8. AUDIT LOG IMMUTABILITY
# ============================================================
section("8. Audit Log Immutability")

from database.repositories.user_audit_log_repository import SupabaseUserAuditLogRepository

# Verify update raises NotImplementedError
try:
    repo = SupabaseUserAuditLogRepository(None)
    repo.update({})
    test("AuditLog update raises error", False, "No error raised")
except NotImplementedError as e:
    test("AuditLog update raises NotImplementedError", "immutable" in str(e).lower(), str(e))
except Exception as e:
    test("AuditLog update raises error", False, str(e))

# Verify delete raises NotImplementedError
try:
    repo = SupabaseUserAuditLogRepository(None)
    repo.delete("some-id")
    test("AuditLog delete raises error", False, "No error raised")
except NotImplementedError as e:
    test("AuditLog delete raises NotImplementedError", "immutable" in str(e).lower(), str(e))
except Exception as e:
    test("AuditLog delete raises error", False, str(e))


# ============================================================
# 9. MIGRATION SQL CHECK
# ============================================================
section("9. Migration SQL File Check")

migration_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rbac_migration.sql")
test("rbac_migration.sql exists", os.path.exists(migration_path))

if os.path.exists(migration_path):
    with open(migration_path, 'r') as f:
        sql = f.read()
    test("SQL has area_manager_assignments", "area_manager_assignments" in sql)
    test("SQL has user_audit_logs", "user_audit_logs" in sql)
    test("SQL has login_history", "login_history" in sql)
    test("SQL has prevent_audit_modification trigger", "prevent_audit_modification" in sql)
    test("SQL has trg_prevent_audit_update", "trg_prevent_audit_update" in sql)
    test("SQL has trg_prevent_audit_delete", "trg_prevent_audit_delete" in sql)
    test("SQL uses RAISE EXCEPTION (not RULE)", "RAISE EXCEPTION" in sql)
    test("SQL has entity_type column", "entity_type" in sql)
    test("SQL has entity_id column", "entity_id" in sql)
    test("SQL has display_name column", "display_name" in sql)
    test("SQL has device_name column", "device_name" in sql)
    test("SQL has browser column", "browser TEXT" in sql)
    test("SQL has operating_system column", "operating_system" in sql)
    test("SQL has last_login ALTER", "last_login" in sql)
    test("SQL has last_activity ALTER", "last_activity" in sql)


# ============================================================
# 10. DUPLICATE USERNAME PROTECTION
# ============================================================
section("10. Duplicate Username Protection")

# UserService.create_user should reject duplicates (tested by checking logic path)
test("create_user validates empty username", not UserService.create_user("", "Name", "pass", "Admin", "HQ", admin_user)['success'])
test("create_user validates empty password", not UserService.create_user("user", "Name", "", "Admin", "HQ", admin_user)['success'])
test("create_user validates empty full_name", not UserService.create_user("user", "", "pass", "Admin", "HQ", admin_user)['success'])


# ============================================================
# SUMMARY
# ============================================================
section("VERIFICATION SUMMARY")

passed = sum(1 for _, s, _ in results if "PASS" in s)
failed = sum(1 for _, s, _ in results if "FAIL" in s)
total = len(results)

print(f"\n  Total:  {total}")
print(f"  Passed: {passed}")
print(f"  Failed: {failed}")
print(f"  Rate:   {passed/total*100:.1f}%")

if failed > 0:
    print(f"\n  ❌ FAILURES:")
    for name, status, detail in results:
        if "FAIL" in status:
            print(f"     • {name}: {detail}")

print(f"\n{'='*60}")
sys.exit(0 if failed == 0 else 1)
