from functools import wraps
import streamlit as st
from auth.session import get_current_user
from config.roles import *

# Centralized Permission Matrix
PERMISSIONS = {
    ROLE_SUPER_ADMIN: {"all"},
    ROLE_ADMIN: {"all"},
    ROLE_BRANCH_MANAGER: {"loan.view", "loan.approve", "client.view", "repayment.add", "cashbook.view"},
    ROLE_CREDIT_OFFICER: {"loan.view", "loan.create", "client.view", "repayment.add"},
    ROLE_ACCOUNT_MANAGER: {"cashbook.view", "cashbook.edit", "report.view"}
}

def require_role(*roles):
    """Decorator to restrict access by role."""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            user = get_current_user()
            if not user or user.role not in roles:
                st.error("You do not have permission to access this resource.")
                st.stop()
            return func(*args, **kwargs)
        return wrapper
    return decorator

def require_permission(permission: str):
    """Decorator to restrict access by specific permission."""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            user = get_current_user()
            if not user:
                st.error("Authentication required.")
                st.stop()
            
            user_perms = PERMISSIONS.get(user.role, set())
            if "all" not in user_perms and permission not in user_perms:
                st.error("You do not have permission to perform this action.")
                st.stop()
                
            return func(*args, **kwargs)
        return wrapper
    return decorator
