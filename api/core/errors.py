"""
api/core/errors.py
Centralized Enterprise Error Taxonomy and Human-Friendly Messaging Framework for ICARE Core Banking.
Translates domain exceptions, PostgREST/Postgres codes, and HTTP errors into structured, actionable responses.
"""
from typing import Optional, Dict, Any
from fastapi import HTTPException, status
import re


class ICAREException(Exception):
    """Authoritative domain and application exception for ICARE."""
    def __init__(
        self,
        error_code: str,
        title: str,
        message: str,
        action: str = "Please verify your input and try again, or contact your supervisor.",
        status_code: int = status.HTTP_400_BAD_REQUEST,
        details: Optional[Any] = None
    ):
        self.error_code = error_code
        self.title = title
        self.message = message
        self.action = action
        self.status_code = status_code
        self.details = details
        super().__init__(f"[{error_code}] {title}: {message}")

    def to_dict(self) -> Dict[str, Any]:
        payload = {
            "error_code": self.error_code,
            "title": self.title,
            "message": self.message,
            "action": self.action
        }
        if self.details is not None:
            payload["details"] = str(self.details)
        return payload


# Standard enterprise error templates
ERROR_REGISTRY: Dict[str, Dict[str, str]] = {
    # Auth
    "AUTH_INVALID_CREDENTIALS": {
        "title": "Invalid Login Credentials",
        "message": "The username or password provided does not match our records.",
        "action": "Please check your branch prefix (e.g. OGI_CO1, BM_Ogijo) and enter your correct password."
    },
    "AUTH_ACCOUNT_DEACTIVATED": {
        "title": "Account Deactivated",
        "message": "This user account is currently deactivated or suspended.",
        "action": "Please contact your Branch Manager or System Administrator to reactivate your access."
    },
    "AUTH_BRANCH_ACCESS_DENIED": {
        "title": "Branch Access Denied",
        "message": "You do not have permission to view or modify records outside your assigned branch.",
        "action": "Please switch to your assigned operational branch or request Area Manager escalation."
    },
    
    # Client Profile & Approvals
    "CLIENT_NOT_FOUND": {
        "title": "Client Record Not Found",
        "message": "The requested client does not exist or has been deleted.",
        "action": "Please refresh your client search list and verify the client ID."
    },
    "CLIENT_EDIT_PENDING_APPROVAL": {
        "title": "Update Pending Approval",
        "message": "A profile modification request for this client is already pending Branch Manager approval.",
        "action": "Please await Branch Manager sign-off before submitting further modifications."
    },
    "CLIENT_TRANSFER_SAME_OFFICER": {
        "title": "Identical Officer Transfer",
        "message": "The selected recipient Credit Officer is already the assigned officer for this client.",
        "action": "Please select a different Credit Officer to reassign this portfolio."
    },
    "CLIENT_TRANSFER_BRANCH_MISMATCH": {
        "title": "Branch Destination Mismatch",
        "message": "The destination officer does not belong to the selected destination branch.",
        "action": "Please choose an officer stationed at the destination branch."
    },

    # Loans & Defaulter
    "LOAN_NOT_FOUND": {
        "title": "Loan Not Found",
        "message": "The specified loan account could not be found.",
        "action": "Please verify the loan reference code."
    },
    "LOAN_ALREADY_ACTIVE": {
        "title": "Existing Active Loan",
        "message": "This client already has an active loan with an outstanding balance.",
        "action": "Clients must complete their current loan cycle before a new loan can be disbursed."
    },
    "LOAN_DEFAULTER_RESTRICTION": {
        "title": "Client Defaulter Warning",
        "message": "This client has missed 3 or more scheduled repayments and is classified as a Defaulter.",
        "action": "This loan application requires explicit Branch Manager review and physical sign-off."
    },

    # Savings & LAPS
    "SAVINGS_INSUFFICIENT_BALANCE": {
        "title": "Insufficient Savings Balance",
        "message": "The requested withdrawal or transfer amount exceeds the client's available savings.",
        "action": "Please enter an amount within the verified savings balance."
    },
    "SAVINGS_LAPS_SWEEP_INELIGIBLE": {
        "title": "LAPS Sweep Ineligible",
        "message": "This client has active operations within the last 90 days and cannot be swept to LAPS.",
        "action": "LAPS transfers apply exclusively to members with 3+ months of total inactivity."
    },

    # Ledger & Vault
    "LEDGER_VAULT_DISCREPANCY": {
        "title": "Vault Cash Imbalance",
        "message": "The physical vault cash in Account 1000 does not match the transactional total.",
        "action": "Please verify cashbook closing records before posting EOD."
    },

    # Database & System
    "DB_DUPLICATE_ENTRY": {
        "title": "Duplicate Record Found",
        "message": "A record with this identifier (username, client code, or phone number) already exists.",
        "action": "Please provide a unique code or check for existing registrations."
    },
    "DB_FOREIGN_KEY_VIOLATION": {
        "title": "Reference Not Found",
        "message": "The linked branch, officer, group, or status reference is missing from the database.",
        "action": "Please refresh your dropdown options to ensure you are selecting active records."
    },
    "DB_NETWORK_TIMEOUT": {
        "title": "Database Connection Timeout",
        "message": "The system encountered a brief network delay while communicating with Supabase.",
        "action": "Please wait a moment and retry your submission. Your data has not been lost."
    }
}


def translate_error_to_icare_response(exc: Exception) -> Dict[str, Any]:
    """Translates any exception into a human-friendly structured ICARE error dictionary."""
    if isinstance(exc, ICAREException):
        return exc.to_dict()

    if isinstance(exc, HTTPException):
        detail = exc.detail
        if isinstance(detail, dict) and "error_code" in detail:
            return detail
        # Map common HTTP status codes
        msg = str(detail) if detail else "An HTTP error occurred."
        if exc.status_code == status.HTTP_404_NOT_FOUND:
            return {
                "error_code": "RESOURCE_NOT_FOUND",
                "title": "Resource Not Found",
                "message": msg,
                "action": "Please verify your selection or search query."
            }
        if exc.status_code in [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN]:
            return {
                "error_code": "PERM_ACCESS_DENIED",
                "title": "Access Not Permitted",
                "message": msg,
                "action": "Please log in with appropriate role permissions."
            }
        return {
            "error_code": f"HTTP_{exc.status_code}",
            "title": "Request Failed",
            "message": msg,
            "action": "Please check your request parameters and retry."
        }

    err_str = str(exc)

    # Detect PostgreSQL code 23505 (unique violation)
    if "23505" in err_str or "unique constraint" in err_str.lower():
        template = ERROR_REGISTRY["DB_DUPLICATE_ENTRY"]
        return {
            "error_code": "DB_DUPLICATE_ENTRY",
            "title": template["title"],
            "message": template["message"],
            "action": template["action"]
        }

    # Detect PostgreSQL code 23503 (foreign key violation)
    if "23503" in err_str or "foreign key constraint" in err_str.lower():
        template = ERROR_REGISTRY["DB_FOREIGN_KEY_VIOLATION"]
        return {
            "error_code": "DB_FOREIGN_KEY_VIOLATION",
            "title": template["title"],
            "message": template["message"],
            "action": template["action"]
        }

    # Detect Cloudflare 500 / Worker exception / Connection error
    if "cloudflare" in err_str.lower() or "worker threw exception" in err_str.lower() or "connection" in err_str.lower():
        template = ERROR_REGISTRY["DB_NETWORK_TIMEOUT"]
        return {
            "error_code": "DB_NETWORK_TIMEOUT",
            "title": template["title"],
            "message": template["message"],
            "action": template["action"]
        }

    # Clean ValueError
    if isinstance(exc, ValueError):
        clean_msg = err_str.strip()
        return {
            "error_code": "VALIDATION_ERROR",
            "title": "Invalid Input Data",
            "message": clean_msg,
            "action": "Please correct the highlighted value and try again."
        }

    # Clean fallback for any generic exception
    return {
        "error_code": "SYSTEM_UNEXPECTED_ERROR",
        "title": "Operation Could Not Be Completed",
        "message": "An unexpected system error occurred while processing this transaction.",
        "action": "Please check your network and retry. If the issue persists, contact technical support."
    }
