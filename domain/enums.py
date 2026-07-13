from enum import Enum

class LoanStatus(str, Enum):
    DRAFT = "Draft"
    PENDING_APPROVAL = "Pending Approval"
    PENDING = "Pending"
    APPROVED = "Approved"
    DISBURSED = "Disbursed"
    ACTIVE = "Active"
    COMPLETED = "Completed"
    REJECTED = "Rejected"
    CANCELLED = "Cancelled"
    WRITTEN_OFF = "Written Off"
    CLOSED = "Closed"
    INTERNAL_ACCOUNT = "Internal Account"

class ClientStatus(str, Enum):
    ACTIVE = "Active"
    INACTIVE = "Inactive"
    DORMANT = "Dormant"
    CLOSED = "Closed"

class SavingsStatus(str, Enum):
    NORMAL = "Normal"
    LAPS = "LAPS"
    WITHDRAWN = "Withdrawn"
