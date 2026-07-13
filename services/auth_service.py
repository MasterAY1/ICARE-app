from auth.password import verify_password
from auth.session import create_session, destroy_session, get_current_user, is_authenticated
from auth.authorization import PERMISSIONS
from models.user import CurrentUser
from database.connection import supabase
from datetime import datetime
import streamlit as st

class AuthService:
    @staticmethod
    def login(username, password) -> bool:
        """Authenticates a user and creates a session using UserRepository."""
        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                user = uow.users.find_by_username(username)
            
            if user:
                if verify_password(password, user.password_hash):
                    role = user.role
                    user_permissions = PERMISSIONS.get(role, set())
                    
                    current_user = CurrentUser(
                        id=user.id,
                        username=user.username,
                        role=role,
                        branch=user.branch_name or 'Unknown',
                        permissions=user_permissions
                    )
                    
                    create_session(current_user)
                    
                    AuthService.log_audit_event(
                        username=current_user.username,
                        branch=current_user.branch,
                        action="LOGIN",
                        status="SUCCESS",
                        details="User authenticated successfully."
                    )
                    return True
                else:
                    AuthService.log_audit_event(
                        username=username,
                        branch="Unknown",
                        action="LOGIN",
                        status="FAILURE",
                        details="Invalid password."
                    )
            else:
                AuthService.log_audit_event(
                    username=username,
                    branch="Unknown",
                    action="LOGIN",
                    status="FAILURE",
                    details="User not found."
                )
        except Exception as e:
            st.error(f"Login Error: {e}")
            AuthService.log_audit_event(
                username=username,
                branch="Unknown",
                action="LOGIN",
                status="ERROR",
                details=str(e)
            )
            
        return False

    @staticmethod
    def logout():
        user = get_current_user()
        if user:
            AuthService.log_audit_event(
                username=user.username,
                branch=user.branch,
                action="LOGOUT",
                status="SUCCESS",
                details="User logged out."
            )
        destroy_session()

    @staticmethod
    def is_logged_in() -> bool:
        return is_authenticated()

    @staticmethod
    
    @staticmethod
    def restore_session_from_url():
        if not is_authenticated():
            if "auth" in st.query_params:
                auth_user = st.query_params["auth"]
                try:
                    from database.repositories.unit_of_work import SupabaseUnitOfWork
                    with SupabaseUnitOfWork() as uow:
                        user = uow.users.find_by_username(auth_user)
                    if user:
                        role = user.role
                        user_permissions = PERMISSIONS.get(role, set())
                        
                        current_user = CurrentUser(
                            id=user.id,
                            username=user.username,
                            role=role,
                            branch=user.branch_name or 'Unknown',
                            permissions=user_permissions
                        )
                        create_session(current_user)
                except Exception:
                    pass

    @staticmethod
    def get_user() -> CurrentUser:
        return get_current_user()

    @staticmethod
    def log_audit_event(username: str, branch: str, action: str, status: str, details: str):
        """Simulated audit logging for Phase 4."""
        try:
            audit_entry = {
                "user": username,
                "branch": branch,
                "action": action,
                "old_value": status,
                "new_value": details,
                "timestamp": datetime.now().isoformat()
            }
            supabase.table("audit_ledger").insert(audit_entry).execute()
        except Exception:
            pass # Fail silently for audit logs if table is unavailable during transition
