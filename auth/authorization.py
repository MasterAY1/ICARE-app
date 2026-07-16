from functools import wraps
import streamlit as st
from auth.session import get_current_user
from config.roles import *

# ---------------------------------------------------------------------------
# Centralized Permission Matrix
# ---------------------------------------------------------------------------
PERMISSIONS = {
    ROLE_SUPER_ADMIN: {"all"},
    ROLE_ADMIN: {"all"},
    ROLE_AREA_MANAGER: {
        "branch.view", "branch.performance",
        "loan.approve", "loan.view",
        "collections.view", "par.view",
        "savings.view", "cashbook.view",
        "officer.view", "report.view", "audit.view",
    },
    ROLE_BRANCH_MANAGER: {
        "client.view",
        "loan.view", "loan.approve", "loan.disburse",
        "savings.view", "savings.withdraw_approve",
        "cashbook.view", "cashbook.manage",
        "user.activate", "user.deactivate", "user.reset_password",
        "client.assign",
        "report.view", "collections.view", "par.view", "officer.view",
    },
    ROLE_CREDIT_OFFICER: {
        "client.register", "client.view", "client.search",
        "loan.view", "loan.apply",
        "repayment.record",
        "savings.record", "savings.withdraw_apply",
        "collections.view", "collections.edit",
    },
    ROLE_ACCOUNT_MANAGER: {
        "cashbook.view", "cashbook.edit", "report.view",
    },
}

# ---------------------------------------------------------------------------
# Permission helpers
# ---------------------------------------------------------------------------

def has_permission(user, permission: str) -> bool:
    """Return True if *user* holds *permission* (or the wildcard 'all')."""
    user_perms = PERMISSIONS.get(user.role, set())
    return "all" in user_perms or permission in user_perms


# ---------------------------------------------------------------------------
# Decorators (kept from original)
# ---------------------------------------------------------------------------

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

            if not has_permission(user, permission):
                st.error("You do not have permission to perform this action.")
                st.stop()

            return func(*args, **kwargs)
        return wrapper
    return decorator


# ---------------------------------------------------------------------------
# Dashboard widget access
# ---------------------------------------------------------------------------

DASHBOARD_WIDGETS = {
    "assigned_clients":       {"client.view"},
    "todays_collections":     {"collections.view"},
    "pending_loans":          {"loan.view"},
    "active_loans":           {"loan.view"},
    "branch_kpis":            {"branch.view"},
    "cash_position":          {"cashbook.view"},
    "par_ranking":            {"par.view"},
    "officer_performance":    {"officer.view"},
    "multi_branch_perf":      {"branch.performance"},
    "branch_comparison":      {"branch.performance"},
    "collection_efficiency":  {"collections.view"},
    "loan_portfolio":         {"loan.view"},
    "system_wide":            {"all"},
    "user_management_widget": {"all"},
    "audit_logs_widget":      {"all"},
    "financial_summary":      {"all"},
}


def can_render_widget(user, widget_name: str) -> bool:
    """Return True if *user* may see the given dashboard widget."""
    required = DASHBOARD_WIDGETS.get(widget_name)
    if required is None:
        return False
    user_perms = PERMISSIONS.get(user.role, set())
    if "all" in user_perms:
        return True
    return bool(required & user_perms)


# ---------------------------------------------------------------------------
# Navigation permissions
# ---------------------------------------------------------------------------

NAV_PERMISSIONS = {
    "Dashboard":          set(),          # all roles see dashboard
    "Loan Origination":   {"loan.apply", "loan.view"},
    "Collections":        {"collections.view"},
    "Portfolio":          {"loan.view"},
    "Master Cashbook":    {"cashbook.view"},
    "Audit Ledger":       {"loan.view"},
    "Reports & Export":   {"report.view"},
    "User Management":    {"all", "user.activate"},
    "WhatsApp Cashbook":  {"collections.view"},
}


def get_nav_options(user) -> list:
    """Return the list of page names the *user* is allowed to navigate to."""
    user_perms = PERMISSIONS.get(user.role, set())
    is_admin = "all" in user_perms
    pages = []
    for page, required in NAV_PERMISSIONS.items():
        if not required:
            # Empty set → everyone can see this page
            pages.append(page)
        elif is_admin:
            pages.append(page)
        elif required & user_perms:
            pages.append(page)
    return pages
