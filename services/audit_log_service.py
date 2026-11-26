"""
ICARE Core Banking — Centralized Audit Log Service
Provides a single entry point for all audit logging across the application.
All modules call this service instead of direct DB inserts.
"""
from contextvars import ContextVar
from datetime import datetime
from typing import Any, Optional

_request_actor_var: ContextVar[Optional[Any]] = ContextVar("icare_audit_actor", default=None)
_request_session_var: ContextVar[str] = ContextVar("icare_audit_session_id", default="")


def set_audit_actor(user: Optional[Any], session_id: str = "") -> None:
    """Bind the authenticated FastAPI actor for downstream domain audit logs."""
    _request_actor_var.set(user)
    if session_id:
        _request_session_var.set(session_id)


def clear_audit_actor() -> None:
    """Clear the bound request actor context."""
    _request_actor_var.set(None)
    _request_session_var.set("")


class AuditLogService:
    """Centralized audit logging service for ICARE Core Banking.
    
    All audit events flow through this service to ensure consistent
    formatting, context population, and immutable storage.
    """

    @staticmethod
    def log(
        action: str,
        module: str,
        status: str = "SUCCESS",
        entity_type: Optional[str] = None,
        entity_id: Optional[str] = None,
        display_name: Optional[str] = None,
        previous_value: Optional[dict] = None,
        new_value: Optional[dict] = None,
        username_override: Optional[str] = None,
        role_override: Optional[str] = None,
        branch_override: Optional[str] = None,
        actor: Optional[Any] = None,
    ) -> None:
        """Record an immutable audit log entry.
        
        Args:
            action: The action performed (e.g., 'LOGIN', 'LOAN_APPROVED', 'CLIENT_REGISTERED')
            module: The module where the action occurred (e.g., 'auth', 'loans', 'clients')
            status: 'SUCCESS', 'FAILURE', or 'ERROR'
            entity_type: Type of entity affected (e.g., 'Client', 'Loan', 'User')
            entity_id: UUID of the affected entity
            display_name: Human-readable identifier
            previous_value: Dict of previous state (for updates/deletes)
            new_value: Dict of new state (for creates/updates)
            username_override: Override username (for pre-auth events like failed logins)
            role_override: Override role (for pre-auth events)
            branch_override: Override branch (for pre-auth events)
            actor: Explicit CurrentUser / User entity performing the action
        """
        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork

            # Resolve user context: explicit actor -> FastAPI ContextVar -> optional Streamlit session
            current_user = actor or _request_actor_var.get()
            session_id = _request_session_var.get() or ""

            if current_user is None:
                try:
                    import streamlit as st
                    current_user = st.session_state.get("current_user")
                    if not session_id:
                        session_id = st.session_state.get("session_id", "")
                except Exception:
                    current_user = None

            user_id = None
            username = username_override or "System"
            role = role_override or "Unknown"
            branch = branch_override or "Unknown"
            area_manager = None

            if current_user:
                user_id = getattr(current_user, "id", None)
                username = username_override or getattr(current_user, "username", None) or username
                role = role_override or getattr(current_user, "role", None) or role
                branch = (
                    branch_override
                    or getattr(current_user, "branch", None)
                    or getattr(current_user, "branch_name", None)
                    or branch
                )
                if role in ("Area Manager", "AM", "AREA_MANAGER"):
                    area_manager = username

            entry = {
                "user_id": user_id,
                "username": username,
                "role": role,
                "branch": branch,
                "area_manager": area_manager,
                "action": action,
                "module": module,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "display_name": display_name,
                "previous_value": previous_value,
                "new_value": new_value,
                "ip_session_id": session_id,
                "device_name": None,
                "browser": None,
                "operating_system": None,
                "status": status,
            }

            with SupabaseUnitOfWork() as uow:
                uow.user_audit_logs.create(entry)

        except Exception:
            # Audit logging must never break the application
            pass

    # ----- Convenience Methods -----

    @staticmethod
    def log_login(username: str, status: str = "SUCCESS", details: str = ""):
        """Log a login event."""
        AuditLogService.log(
            action="LOGIN",
            module="auth",
            status=status,
            username_override=username,
            new_value={"details": details} if details else None,
        )

    @staticmethod
    def log_logout(username: str):
        """Log a logout event."""
        AuditLogService.log(
            action="LOGOUT",
            module="auth",
            status="SUCCESS",
            username_override=username,
        )

    @staticmethod
    def log_client_action(action: str, client_id: str, display_name: str = "",
                          previous: dict = None, new: dict = None, status: str = "SUCCESS"):
        """Log a client-related action."""
        AuditLogService.log(
            action=action,
            module="clients",
            entity_type="Client",
            entity_id=client_id,
            display_name=display_name,
            previous_value=previous,
            new_value=new,
            status=status,
        )

    @staticmethod
    def log_loan_action(action: str, loan_id: str, display_name: str = "",
                        previous: dict = None, new: dict = None, status: str = "SUCCESS"):
        """Log a loan-related action."""
        AuditLogService.log(
            action=action,
            module="loans",
            entity_type="Loan",
            entity_id=loan_id,
            display_name=display_name,
            previous_value=previous,
            new_value=new,
            status=status,
        )

    @staticmethod
    def log_savings_action(action: str, entity_id: str, display_name: str = "",
                           previous: dict = None, new: dict = None, status: str = "SUCCESS"):
        """Log a savings-related action."""
        AuditLogService.log(
            action=action,
            module="savings",
            entity_type="Savings",
            entity_id=entity_id,
            display_name=display_name,
            previous_value=previous,
            new_value=new,
            status=status,
        )

    @staticmethod
    def log_cashbook_action(action: str, cashbook_id: str = "", display_name: str = "",
                            previous: dict = None, new: dict = None, status: str = "SUCCESS"):
        """Log a cashbook-related action."""
        AuditLogService.log(
            action=action,
            module="cashbook",
            entity_type="Cashbook",
            entity_id=cashbook_id or None,
            display_name=display_name,
            previous_value=previous,
            new_value=new,
            status=status,
        )

    @staticmethod
    def log_user_action(action: str, target_user_id: str, display_name: str = "",
                        previous: dict = None, new: dict = None, status: str = "SUCCESS"):
        """Log a user management action."""
        AuditLogService.log(
            action=action,
            module="user_management",
            entity_type="User",
            entity_id=target_user_id,
            display_name=display_name,
            previous_value=previous,
            new_value=new,
            status=status,
        )

    @staticmethod
    def log_permission_denied(action: str, module: str):
        """Log an unauthorized access attempt."""
        AuditLogService.log(
            action="PERMISSION_DENIED",
            module=module,
            status="FAILURE",
            new_value={"attempted_action": action},
        )
