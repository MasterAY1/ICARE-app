"""
ICARE Core Banking — Centralized Audit Log Service
Provides a single entry point for all audit logging across the application.
All modules call this service instead of direct DB inserts.
"""
from datetime import datetime
from typing import Optional
import streamlit as st


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
    ) -> None:
        """Record an immutable audit log entry.
        
        Args:
            action: The action performed (e.g., 'LOGIN', 'LOAN_APPROVED', 'CLIENT_REGISTERED')
            module: The module where the action occurred (e.g., 'auth', 'loans', 'clients')
            status: 'SUCCESS', 'FAILURE', or 'ERROR'
            entity_type: Type of entity affected (e.g., 'Client', 'Loan', 'User')
            entity_id: UUID of the affected entity
            display_name: Human-readable identifier (e.g., 'OGI-01-023')
            previous_value: Dict of previous state (for updates/deletes)
            new_value: Dict of new state (for creates/updates)
            username_override: Override username (for pre-auth events like failed logins)
            role_override: Override role (for pre-auth events)
            branch_override: Override branch (for pre-auth events)
        """
        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork

            # Extract user context from session
            current_user = st.session_state.get('current_user')
            
            user_id = None
            username = username_override or "System"
            role = role_override or "Unknown"
            branch = branch_override or "Unknown"
            area_manager = None
            session_id = st.session_state.get('session_id', '')

            if current_user:
                user_id = current_user.id
                username = username_override or current_user.username
                role = role_override or current_user.role
                branch = branch_override or current_user.branch
                # If user is an AM, record their name as area_manager
                if current_user.role == "Area Manager":
                    area_manager = current_user.username

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
