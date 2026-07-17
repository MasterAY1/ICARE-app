"""
ICARE Core Banking — User Management Service
Handles user CRUD, activation, deactivation, password resets,
and Area Manager branch assignments.

Access Rules:
- Super Admin / Admin: Full CRUD on all users
- Branch Manager: Activate/deactivate branch staff, reset passwords (own branch only)
- Area Manager: Read-only view of users in assigned branches; CANNOT create/delete users
- Credit Officer: No user management access
"""
from typing import List, Optional, Dict
from auth.password import hash_password
from domain.entities.user import User
from services.audit_log_service import AuditLogService
from config.roles import (
    ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_AREA_MANAGER,
    ROLE_BRANCH_MANAGER, ROLE_CREDIT_OFFICER
)


class UserService:
    """Production-grade user management service for ICARE Core Banking."""

    # ---- User CRUD (Admin Only) ----

    @staticmethod
    def create_user(
        username: str,
        full_name: str,
        password: str,
        role: str,
        branch_name: str,
        requesting_user=None,
    ) -> Dict:
        """Create a new user. Only Super Admin / Admin may call this.
        
        Returns:
            dict with 'success' (bool) and 'message' (str), optionally 'user' (User)
        """
        # Authorization check
        if requesting_user and requesting_user.role not in (ROLE_SUPER_ADMIN, ROLE_ADMIN):
            AuditLogService.log_permission_denied("CREATE_USER", "user_management")
            return {"success": False, "message": "Only Head Office administrators can create users."}

        if not username or not password or not full_name:
            return {"success": False, "message": "Username, Full Name, and Password are required."}

        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                # Check for duplicate username
                existing = uow.users.find_by_username(username)
                if existing:
                    return {"success": False, "message": f"Username '{username}' already exists."}

                hashed_pw = hash_password(password)
                new_user = User(
                    id='',
                    username=username,
                    full_name=full_name,
                    role=role,
                    branch_name=branch_name,
                    password_hash=hashed_pw,
                    created_at=None,
                )
                created = uow.users.create(new_user)

                AuditLogService.log_user_action(
                    action="USER_CREATED",
                    target_user_id=created.id,
                    display_name=username,
                    new={"username": username, "role": role, "branch": branch_name},
                )

                return {"success": True, "message": f"User {username} created successfully.", "user": created}

        except Exception as e:
            return {"success": False, "message": f"Failed to create user: {e}"}

    # ---- Activate / Deactivate ----

    @staticmethod
    def activate_user(user_id: str, requesting_user=None) -> Dict:
        """Activate a user. Admin or BM (own branch only) may call this."""
        return UserService._toggle_user_active(user_id, True, requesting_user)

    @staticmethod
    def deactivate_user(user_id: str, requesting_user=None) -> Dict:
        """Deactivate a user. Admin or BM (own branch only) may call this."""
        return UserService._toggle_user_active(user_id, False, requesting_user)

    @staticmethod
    def _toggle_user_active(user_id: str, activate: bool, requesting_user=None) -> Dict:
        """Internal helper for activate/deactivate."""
        action_word = "activate" if activate else "deactivate"
        allowed_roles = (ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_BRANCH_MANAGER)

        if requesting_user and requesting_user.role not in allowed_roles:
            AuditLogService.log_permission_denied(f"{action_word.upper()}_USER", "user_management")
            return {"success": False, "message": f"You do not have permission to {action_word} users."}

        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                target = uow.users.find_by_id(user_id)
                if not target:
                    return {"success": False, "message": "User not found."}

                # BM can only manage users in their own branch
                if requesting_user and requesting_user.role == ROLE_BRANCH_MANAGER:
                    if target.branch_id != requesting_user.branch_id:
                        AuditLogService.log_permission_denied(f"{action_word.upper()}_USER", "user_management")
                        return {"success": False, "message": "You can only manage staff in your own branch."}

                if activate:
                    uow.users.activate_user(user_id)
                else:
                    uow.users.deactivate_user(user_id)

                AuditLogService.log_user_action(
                    action=f"USER_{action_word.upper()}D",
                    target_user_id=user_id,
                    display_name=target.username,
                    previous={"is_active": not activate},
                    new={"is_active": activate},
                )

                return {"success": True, "message": f"User {target.username} {action_word}d successfully."}

        except Exception as e:
            return {"success": False, "message": f"Failed to {action_word} user: {e}"}

    # ---- Password Reset ----

    @staticmethod
    def reset_password(username: str, new_password: str, requesting_user=None) -> Dict:
        """Reset a user's password. Admin or BM (own branch only) may call this."""
        allowed_roles = (ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_BRANCH_MANAGER)

        if requesting_user and requesting_user.role not in allowed_roles:
            AuditLogService.log_permission_denied("RESET_PASSWORD", "user_management")
            return {"success": False, "message": "You do not have permission to reset passwords."}

        if not new_password:
            return {"success": False, "message": "New password is required."}

        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                target = uow.users.find_by_username(username)
                if not target:
                    return {"success": False, "message": f"User '{username}' not found."}

                # BM scope: own branch only
                if requesting_user and requesting_user.role == ROLE_BRANCH_MANAGER:
                    if target.branch_id != requesting_user.branch_id:
                        AuditLogService.log_permission_denied("RESET_PASSWORD", "user_management")
                        return {"success": False, "message": "You can only reset passwords for staff in your own branch."}

                hashed_pw = hash_password(new_password)
                uow.users.update_password(username, hashed_pw)

                AuditLogService.log_user_action(
                    action="PASSWORD_RESET",
                    target_user_id=target.id,
                    display_name=username,
                )

                return {"success": True, "message": f"Password reset for {username}."}

        except Exception as e:
            return {"success": False, "message": f"Failed to reset password: {e}"}

    # ---- Area Manager Branch Assignments ----

    @staticmethod
    def get_am_assignments(am_id: str) -> List[Dict]:
        """Get branches assigned to an Area Manager."""
        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                return uow.users.load_am_assignments(am_id)
        except Exception:
            return []

    @staticmethod
    def save_am_assignments(am_id: str, branch_ids: List[str], requesting_user=None) -> Dict:
        """Assign branches to an Area Manager. Admin only.
        
        Validates the 5-7 branch constraint.
        """
        if requesting_user and requesting_user.role not in (ROLE_SUPER_ADMIN, ROLE_ADMIN):
            AuditLogService.log_permission_denied("ASSIGN_AM_BRANCHES", "user_management")
            return {"success": False, "message": "Only administrators can assign branches to Area Managers."}

        if len(branch_ids) < 5:
            return {"success": False, "message": f"Area Managers must supervise at least 5 branches. Got {len(branch_ids)}."}
        if len(branch_ids) > 7:
            return {"success": False, "message": f"Area Managers cannot supervise more than 7 branches. Got {len(branch_ids)}."}

        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                target = uow.users.find_by_id(am_id)
                if not target:
                    return {"success": False, "message": "Area Manager not found."}

                old_assignments = uow.users.load_am_assignments(am_id)
                old_ids = [a["branch_id"] for a in old_assignments]

                uow.users.save_am_assignments(am_id, branch_ids)

                AuditLogService.log_user_action(
                    action="AM_BRANCHES_ASSIGNED",
                    target_user_id=am_id,
                    display_name=target.username,
                    previous={"branch_ids": old_ids},
                    new={"branch_ids": branch_ids},
                )

                return {"success": True, "message": f"Assigned {len(branch_ids)} branches to {target.username}."}

        except Exception as e:
            return {"success": False, "message": f"Failed to assign branches: {e}"}

    # ---- Update Officer Name (Turnover) ----

    @staticmethod
    def update_officer_name(username: str, new_name: str, requesting_user=None) -> Dict:
        """Update the display name for an officer (staff turnover scenario)."""
        if requesting_user and requesting_user.role not in (ROLE_SUPER_ADMIN, ROLE_ADMIN):
            AuditLogService.log_permission_denied("UPDATE_OFFICER_NAME", "user_management")
            return {"success": False, "message": "Only administrators can update officer names."}

        if not new_name:
            return {"success": False, "message": "New name is required."}

        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                user = uow.users.find_by_username(username)
                if not user:
                    return {"success": False, "message": f"User '{username}' not found."}

                old_name = user.full_name
                user.full_name = new_name
                uow.users.update(user)

                AuditLogService.log_user_action(
                    action="OFFICER_NAME_UPDATED",
                    target_user_id=user.id,
                    display_name=username,
                    previous={"full_name": old_name},
                    new={"full_name": new_name},
                )

                return {"success": True, "message": f"Updated {username} from '{old_name}' to '{new_name}'."}

        except Exception as e:
            return {"success": False, "message": f"Failed to update officer name: {e}"}

    # ---- List Users (Scoped by Role) ----

    @staticmethod
    def list_users(requesting_user=None) -> List[Dict]:
        """List users scoped by the requesting user's role.
        
        - Admin: sees all users
        - AM: sees users in assigned branches
        - BM: sees users in own branch
        """
        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            from mappers.base_mappers import UserMapper

            with SupabaseUnitOfWork() as uow:
                all_users = uow.users.find_all()

            # Convert to dicts for display
            user_dicts = []
            for u in all_users:
                user_dicts.append({
                    "id": u.id,
                    "username": u.username,
                    "full_name": u.full_name,
                    "role": u.role,
                    "branch_name": u.branch_name,
                    "branch_id": u.branch_id,
                    "is_active": u.is_active,
                    "created_at": str(u.created_at) if u.created_at else "",
                    "last_login": str(u.last_login) if u.last_login else "Never",
                })

            if not requesting_user:
                return user_dicts

            if requesting_user.role in (ROLE_SUPER_ADMIN, ROLE_ADMIN):
                return user_dicts

            if requesting_user.role == ROLE_AREA_MANAGER:
                am_branch_ids = set(requesting_user.assigned_branch_ids)
                return [u for u in user_dicts if u["branch_id"] in am_branch_ids]

            if requesting_user.role == ROLE_BRANCH_MANAGER:
                return [u for u in user_dicts if u["branch_id"] == requesting_user.branch_id]

            return []

        except Exception:
            return []

    # ---- Remove User (Admin Only) ----

    @staticmethod
    def remove_user_permanently(user_id: str, requesting_user=None) -> Dict:
        """Permanently delete a user from the system."""
        try:
            if not requesting_user or requesting_user.role not in (ROLE_SUPER_ADMIN, ROLE_ADMIN):
                return {"success": False, "message": "Unauthorized. Only Administrators can delete users."}

            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                user = uow.users.find_by_id(user_id)
                if not user:
                    return {"success": False, "message": "User not found."}

                if user.id == requesting_user.id:
                    return {"success": False, "message": "You cannot delete your own account."}

                deleted = uow.users.delete(user.id)
                if not deleted:
                    return {"success": False, "message": "Failed to delete user from database."}

                AuditLogService.log_user_action(
                    action="USER_DELETED",
                    target_user_id=user.id,
                    display_name=user.username,
                    previous={"username": user.username, "full_name": user.full_name, "role": user.role},
                    new=None
                )

                return {"success": True, "message": f"Successfully deleted user '{user.username}' permanently."}

        except Exception as e:
            return {"success": False, "message": f"Failed to delete user: {e}"}
