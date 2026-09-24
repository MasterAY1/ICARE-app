"""
Portfolio & 360° Client Dossier Schemas.
Authoritative models for hierarchical portfolio analytics and client drilldowns (app.py L12192–13178).
"""
from typing import List, Dict, Any, Optional
from pydantic import BaseModel


class PortfolioMetrics(BaseModel):
    total_clients: int = 0
    total_active_credit: float = 0.0
    total_outstanding: float = 0.0
    total_fixed_repayment: float = 0.0
    total_paid: float = 0.0
    collection_rate: float = 0.0
    par_30_amount: float = 0.0
    par_30_count: int = 0


class GroupPortfolioItem(BaseModel):
    group_name: str
    total_clients: int
    total_savings_balance: float
    total_active_loan: float
    total_outstanding_balance: float
    total_fixed_repayment: float
    total_paid: float


class ClientPortfolioItem(BaseModel):
    client_id: str
    client_code: str
    client_name: str
    group_name: str
    savings_balance: float
    active_loan: float
    outstanding_balance: float
    status: str


class FilterOptions(BaseModel):
    available_branches: List[str] = []
    available_officers: List[Dict[str, str]] = []
    allowed_products: List[str] = []
    available_groups: List[str] = []
    time_periods: List[str] = ["Today", "Yesterday", "Current Month", "Last Month", "Custom Date Range"]


class PortfolioOverviewResponse(BaseModel):
    # Core Streamlit PortfolioService data structures (1:1 parity)
    summary: Dict[str, Any] = {}
    category_summary: Dict[str, Any] = {}
    group_matrix: List[Dict[str, Any]] = []
    client_table: List[Dict[str, Any]] = []
    group_table: List[Dict[str, Any]] = []
    payoff_excess_table: List[Dict[str, Any]] = []
    client_codes: List[str] = []
    client_lookup: Dict[str, str] = {}
    filter_options: FilterOptions = FilterOptions()

    # Backward-compatible fields
    metrics: PortfolioMetrics = PortfolioMetrics()
    groups: List[GroupPortfolioItem] = []
    clients: List[ClientPortfolioItem] = []


class ClientDossierResponse(BaseModel):
    client_code: str
    customer_info: Dict[str, Any] = {}
    guarantor_info: Dict[str, Any] = {}
    executive_banner: Dict[str, Any] = {}
    loan_history: List[Dict[str, Any]] = []
    repayment_ledger: List[Dict[str, Any]] = []
    savings_ledger: List[Dict[str, Any]] = []
    collection_compliance: Dict[str, Any] = {}
    lifecycle_status: Dict[str, Any] = {}
    audit_history: List[Dict[str, Any]] = []


class ChangeClientStatusRequest(BaseModel):
    client_id: str
    target_status: str
    reason: str


class DossierReversalRequest(BaseModel):
    record_id: str
    reason: str
