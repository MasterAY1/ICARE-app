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
        """Authenticates a user and creates a session."""
        try:
            res = supabase.table("users").select("*").eq("username", username).execute()
            
            if res.data and len(res.data) > 0:
                user_record = res.data[0]
                hashed_password = user_record.get('password', '')
                
                if verify_password(password, hashed_password):
                    # Load User
                    role = user_record.get('role', 'Unknown')
                    
                    # Load Permissions
                    user_permissions = PERMISSIONS.get(role, set())
                    
                    current_user = CurrentUser(
                        id=str(user_record.get('id', '')),
                        username=user_record.get('username'),
                        role=role,
                        branch=user_record.get('branch', 'Unknown'),
                        permissions=user_permissions
                    )
                    
                    # Create Session
                    create_session(current_user)
                    
                    # Audit Login
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
                    res = supabase.table("app_users").select("*").eq("username", auth_user).execute()
                    if res.data and len(res.data) > 0:
                        user_record = res.data[0]
                        role = user_record.get('role', 'Unknown')
                        user_permissions = PERMISSIONS.get(role, set())
                        
                        current_user = CurrentUser(
                            id=str(user_record.get('id', '')),
                            username=user_record.get('username'),
                            role=role,
                            branch=user_record.get('branch_name', 'Unknown'), # Note: DB column is branch_name
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
