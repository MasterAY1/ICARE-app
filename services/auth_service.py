"""
ICARE Core Banking — Authentication Service
Handles login, logout, session management, and login history.
Uses app_users table with UUID-based branch/officer filtering.
"""
from auth.password import verify_password
from auth.session import create_session, destroy_session, get_current_user, is_authenticated
from auth.authorization import PERMISSIONS
from models.user import CurrentUser
from services.audit_log_service import AuditLogService
from datetime import datetime
import streamlit as st


class AuthService:
    """Production-grade authentication service for ICARE Core Banking."""

    @staticmethod
    def login(username: str, password: str) -> bool:
        """Authenticates a user and creates a session.
        
        - Verifies credentials against app_users table
        - Loads role, branch, branch_id
        - If Area Manager, loads assigned branches
        - Creates login_history record
        - Updates last_login on user table
        """
        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                user = uow.users.find_by_username(username)

            if not user:
                AuthService._record_failed_login(username, "User not found")
                AuditLogService.log_login(username, "FAILURE", "User not found")
                return False

            if not user.is_active:
                AuthService._record_failed_login(username, "Account deactivated")
                AuditLogService.log_login(username, "FAILURE", "Account deactivated")
                return False

            if not verify_password(password, user.password_hash):
                AuthService._record_failed_login(username, "Invalid password")
                AuditLogService.log_login(username, "FAILURE", "Invalid password")
                return False

            # Successful authentication — build session
            role = user.role
            user_permissions = PERMISSIONS.get(role, set())

            current_user = CurrentUser(
                id=user.id,
                username=user.username,
                role=role,
                branch=user.branch_name or 'Unknown',
                branch_id=user.branch_id or '',
                full_name=user.full_name or '',
                permissions=user_permissions,
            )

            # Load Area Manager assignments if applicable
            if role == "Area Manager":
                try:
                    from database.repositories.unit_of_work import SupabaseUnitOfWork as UoW
                    with UoW() as uow2:
                        assignments = uow2.users.load_am_assignments(user.id)
                    current_user.assigned_branch_ids = [a["branch_id"] for a in assignments]
                    current_user.assigned_branches = [a["name"] for a in assignments]
                except Exception:
                    current_user.assigned_branch_ids = []
                    current_user.assigned_branches = []

            create_session(current_user)

            # Update last_login on user table
            try:
                from database.repositories.unit_of_work import SupabaseUnitOfWork as UoW
                with UoW() as uow3:
                    uow3.users.update_last_login(user.id)
            except Exception:
                pass

            # Record login in login_history
            AuthService._record_successful_login(user.id, username)

            AuditLogService.log_login(username, "SUCCESS", "User authenticated successfully")
            return True

        except Exception as e:
            st.error(f"Login Error: {e}")
            AuditLogService.log_login(username, "ERROR", str(e))
            return False

    @staticmethod
    def logout():
        """Logs out the current user, records the event, and updates login_history."""
        user = get_current_user()
        if user:
            AuditLogService.log_logout(user.username)
            # Update logout_time in login_history
            session_id = st.session_state.get('session_id', '')
            if session_id:
                try:
                    from database.repositories.unit_of_work import SupabaseUnitOfWork
                    with SupabaseUnitOfWork() as uow:
                        uow.login_history.record_logout(session_id)
                except Exception:
                    pass
        destroy_session()

    @staticmethod
    def is_logged_in() -> bool:
        """Check if a user is currently authenticated."""
        return is_authenticated()

    @staticmethod
    def restore_session_from_url():
        """Attempt to restore a session from URL query parameters (deep linking)."""
        if not is_authenticated():
            if "auth" in st.query_params:
                auth_user = st.query_params["auth"]
                try:
                    from database.repositories.unit_of_work import SupabaseUnitOfWork
                    with SupabaseUnitOfWork() as uow:
                        user = uow.users.find_by_username(auth_user)
                    if user and user.is_active:
                        role = user.role
                        user_permissions = PERMISSIONS.get(role, set())

                        current_user = CurrentUser(
                            id=user.id,
                            username=user.username,
                            role=role,
                            branch=user.branch_name or 'Unknown',
                            branch_id=user.branch_id or '',
                            permissions=user_permissions,
                        )

                        # Load AM assignments
                        if role == "Area Manager":
                            try:
                                with SupabaseUnitOfWork() as uow2:
                                    assignments = uow2.users.load_am_assignments(user.id)
                                current_user.assigned_branch_ids = [a["branch_id"] for a in assignments]
                                current_user.assigned_branches = [a["name"] for a in assignments]
                            except Exception:
                                pass

                        create_session(current_user)
                except Exception:
                    pass

    @staticmethod
    def get_user() -> CurrentUser:
        """Get the current authenticated user from session."""
        return get_current_user()

    # ---- Private Helpers ----

    @staticmethod
    def _record_successful_login(user_id: str, username: str):
        """Record a successful login in login_history table."""
        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            session_id = st.session_state.get('session_id', '')
            with SupabaseUnitOfWork() as uow:
                uow.login_history.record_login({
                    "user_id": user_id,
                    "username": username,
                    "session_id": session_id,
                    "failed_attempts": 0,
                    "status": "SUCCESS",
                })
        except Exception:
            pass

    @staticmethod
    def _record_failed_login(username: str, reason: str):
        """Record a failed login attempt in login_history table."""
        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                uow.login_history.record_login({
                    "user_id": None,
                    "username": username,
                    "session_id": "",
                    "failed_attempts": 1,
                    "status": "FAILURE",
                })
        except Exception:
            pass
