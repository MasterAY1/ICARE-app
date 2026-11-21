"""
Loan Origination and Client Registration schemas.
"""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, model_validator


class GroupOption(BaseModel):
    group_id: str
    name: str
    group_number: str
    meeting_day: str
    display_label: str


class ClientSearchItem(BaseModel):
    client_id: str
    client_code: str
    name: str
    group_name: Optional[str] = "Individual (No Group)"
    officer_name: Optional[str] = "Unknown"
    savings_balance: float = 0.0


class GuarantorDetails(BaseModel):
    full_name: str
    nickname: Optional[str] = None
    phone: str
    address: Optional[str] = None
    marital_status: Optional[str] = "Married"
    occupation: Optional[str] = "Trader"
    relationship: Optional[str] = None
    office_address: Optional[str] = None
    id_means: Optional[str] = "National ID (NIN)"
    id_number: Optional[str] = None
    id_card_url: Optional[str] = None
    passport_url: Optional[str] = None


class ClientProfileDetails(BaseModel):
    client_id: str
    client_code: str
    name: str
    nickname: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    marital_status: str = "Single"
    business_type: str = "Trader"
    business_address: Optional[str] = None
    average_monthly_income: float = 0.0
    other_obligations: Optional[str] = None
    id_means: str = "National ID (NIN)"
    id_number: Optional[str] = None
    id_card_url: Optional[str] = None
    passport_url: Optional[str] = None
    branch_name: str = "Unknown"
    group_name: str = "Individual (No Group)"
    officer_name: str = "Unknown"
    savings_balance: float = 0.0
    guarantor: Optional[GuarantorDetails] = None


class GuarantorInput(BaseModel):
    full_name: Optional[str] = None
    nickname: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    occupation: Optional[str] = "Trader"
    relationship: Optional[str] = None
    office_address: Optional[str] = None
    marital_status: Optional[str] = "Single"
    id_means: Optional[str] = "National ID (NIN)"
    id_number: Optional[str] = None


class RegisterClientInput(BaseModel):
    full_name: str = Field(..., min_length=1)
    nickname: Optional[str] = None
    phone: str = Field(..., min_length=1)
    address: Optional[str] = ""
    marital_status: str = "Single"
    business_type: str = "Trader"
    business_address: Optional[str] = None
    average_monthly_income: float = 0.0
    other_obligations: Optional[str] = None
    id_means: str = "National ID (NIN)"
    id_number: Optional[str] = None
    id_card_url: Optional[str] = None
    passport_url: Optional[str] = None
    guarantor_id_card_url: Optional[str] = None
    guarantor_passport_url: Optional[str] = None
    group_mode: str = "Individual (No Group)"  # "Individual (No Group)", "+ Create New Group", or existing group name/label
    group_id: Optional[str] = None
    new_group_name: Optional[str] = None
    new_group_number: Optional[str] = None
    new_group_meeting_day: Optional[str] = "Daily"
    registration_date: Optional[str] = None
    guarantor: Optional[GuarantorInput] = None



class RegisterClientResponse(BaseModel):
    success: bool
    client_id: str
    client_code: str
    message: str


class EligibilityCheckRequest(BaseModel):
    client_id: str = Field(..., min_length=1)
    requested_amount: float = Field(..., gt=0)
    product_type: str = Field("Weekly 12W")
    product_category: str = Field("Finance")


class EligibilityCheckResponse(BaseModel):
    is_eligible: bool
    reasons: List[str]
    warnings: List[str]


class SelectedAssetItemInput(BaseModel):
    item_id: str = Field(..., min_length=1)
    sku_code: Optional[str] = None
    item_name: Optional[str] = None
    quantity: int = Field(1, ge=1)
    unit_cash_price: Optional[float] = None


class ApplyLoanInput(BaseModel):
    client_id: str = Field(..., min_length=1)
    product_category: str = Field("Finance", description="Finance or Asset")
    product_type: str = Field("Weekly 12W")
    product_name: Optional[str] = None
    requested_amount: float = Field(..., gt=0)
    downpayment_mode: Optional[str] = "Cash (Physical Payment)"
    cash_downpayment: float = 0.0
    savings_downpayment: float = 0.0
    gap_fee: float = 0.0
    application_date: Optional[str] = None
    notes: Optional[str] = ""
    selected_assets: Optional[List[SelectedAssetItemInput]] = None

    @model_validator(mode="before")
    @classmethod
    def populate_product_type(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "product_name" in data and "product_type" not in data:
                data["product_type"] = data["product_name"]
        return data


class ApplyLoanResponse(BaseModel):
    success: bool
    loan_id: str
    active_credit: float
    expected_installment: float
    status: str
    message: str


class SchedulePreviewRequest(BaseModel):
    product_category: str = Field("Finance")
    product_type: str = Field("Weekly 12W")
    requested_amount: float = Field(..., gt=0)
    downpayment_mode: Optional[str] = "Cash (Physical Payment)"
    cash_downpayment: float = 0.0
    savings_downpayment: float = 0.0
    gap_fee: float = 0.0
    application_date: Optional[str] = None
    client_id: Optional[str] = None
    selected_assets: Optional[List[SelectedAssetItemInput]] = None


class SchedulePreviewItem(BaseModel):
    installment_number: int
    due_date: str
    principal: float
    interest: float
    total_due: float


class SchedulePreviewResponse(BaseModel):
    product_type: str
    product_category: str
    frequency: str
    duration: int
    interest: float
    active_credit: float
    expected_installment: float
    gap_fee: float
    total_upfront_required: float
    first_due_date: Optional[str] = None
    expected_end_date: Optional[str] = None
    installments: List[SchedulePreviewItem] = []


class PendingLoanItem(BaseModel):
    loan_id: str
    client_id: str
    client_name: str
    client_code: Optional[str] = None
    group_name: str
    date: Optional[str] = None
    credit_officer: str
    loan_amount: float
    loan_product: str
    product_category: str = "Finance"
    exceeds_bm_limit: bool = False
    asset_summary: Optional[str] = None
    selected_assets: Optional[List[Dict[str, Any]]] = None


class PendingDisbursementsResponse(BaseModel):
    pending_loans: List[PendingLoanItem]
    can_authorize: bool


class DisburseLoanRequest(BaseModel):
    loan_id: str
    disbursement_date: str  # YYYY-MM-DD


class DisburseLoanResponse(BaseModel):
    success: bool
    message: str
    schedule_adjusted: bool = False
    final_start_date: Optional[str] = None
    shift_reason: Optional[str] = None


class RejectLoanApplicationRequest(BaseModel):
    loan_id: str = Field(..., min_length=1)
    reason: str = Field("Not approved", min_length=1)


class RejectLoanApplicationResponse(BaseModel):
    success: bool
    message: str


class AssetCatalogItemSchema(BaseModel):
    item_id: str
    sku_code: str
    category: str
    item_name: str
    unit_cost_price: float = 0.0
    has_cost_price: bool = False
    cash_and_carry_price: float
    easy_buy_60d_price: float
    easy_buy_120d_price: float
    retail_margin_amount: float = 0.0
    retail_margin_pct: float = 0.0
    easy_buy_60d_markup: float = 0.0
    easy_buy_120d_markup: float = 0.0
    easy_buy_60d_total_profit: float = 0.0
    easy_buy_120d_total_profit: float = 0.0
    supplier_name: Optional[str] = None
    is_custom_price_allowed: bool = False
    in_master_pdf: bool = True
    branch_item_alias: Optional[str] = None
    quantity_on_hand: int = 0
    quantity_reserved: int = 0
    quantity_available: int = 0
    in_stock: bool = False


class AssetCategorySummarySchema(BaseModel):
    category: str
    catalog_skus: int
    in_stock_skus: int
    units_available: int


class BranchAssetSummarySchema(BaseModel):
    total_catalog_skus: int
    branch_stocked_skus: int
    total_units_on_hand: int
    total_units_reserved: int
    total_units_available: int
    total_inventory_cash_value: float
    total_inventory_easy_buy_60d_value: float
    total_inventory_easy_buy_120d_value: float


class BranchAssetCatalogResponse(BaseModel):
    branch_id: Optional[str] = None
    branch_name: str
    db_backed: bool = False
    categories: List[AssetCategorySummarySchema]
    items: List[AssetCatalogItemSchema]
    summary: BranchAssetSummarySchema


class AdjustBranchInventoryInput(BaseModel):
    item_id: str = Field(..., min_length=1)
    branch_id: Optional[str] = None
    quantity_delta: int = 0
    new_cash_price: Optional[float] = None
    new_cost_price: Optional[float] = None
    supplier_name: Optional[str] = None
    reference_code: Optional[str] = None
    remarks: Optional[str] = ""


class AdjustBranchInventoryResponse(BaseModel):
    success: bool
    message: str
    item: AssetCatalogItemSchema


class UpdateClientGuarantorInput(BaseModel):
    name: str = Field(..., min_length=1)
    nickname: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    business_address: Optional[str] = None
    marital_status: str = "Married"
    business_type: Optional[str] = "Trader"
    average_monthly_income: float = 0.0
    other_obligations: Optional[str] = None
    id_means: str = "National ID (NIN)"
    id_number: Optional[str] = None
    guarantor_name: Optional[str] = None
    guarantor_nickname: Optional[str] = None
    guarantor_phone: Optional[str] = None
    guarantor_address: Optional[str] = None
    guarantor_marital_status: Optional[str] = "Married"
    guarantor_occupation: Optional[str] = None
    guarantor_relationship: Optional[str] = None
    guarantor_office_address: Optional[str] = None
    guarantor_id_means: Optional[str] = "None"
    guarantor_id_number: Optional[str] = None


class UpdateClientGuarantorResponse(BaseModel):
    success: bool
    message: str
    status: Optional[str] = "APPLIED"
    request_id: Optional[str] = None
