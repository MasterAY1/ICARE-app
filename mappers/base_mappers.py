from domain.entities.loan import Loan
from domain.enums import LoanStatus, ClientStatus, SavingsStatus
from domain.entities.repayment import Repayment
from domain.entities.user import User
from domain.entities.audit_event import AuditEvent
from domain.entities.cashbook_entry import CashbookEntry
from domain.entities.branch_closure import BranchClosure
from domain.entities.client import Client
from domain.entities.guarantor import Guarantor, LoanGuarantor
from datetime import datetime, date

def _parse_date(date_str):
    if not date_str: return None
    if isinstance(date_str, (date, datetime)):
        return date_str if isinstance(date_str, date) else date_str.date()
    try:
        return datetime.strptime(str(date_str).split('T')[0], "%Y-%m-%d").date()
    except Exception:
        return None

def _parse_datetime(dt_str):
    if not dt_str: return None
    if isinstance(dt_str, datetime):
        return dt_str
    try:
        return datetime.fromisoformat(str(dt_str).replace("Z", "+00:00"))
    except Exception:
        return None

class LoanMapper:
    @staticmethod
    def to_domain(dto: dict) -> Loan:
        # Resolve client profile details from joined table if present
        c_dto = dto.get("clients") or {}
        if not isinstance(c_dto, dict):
            c_dto = {}
            
        # Resolve branch name from join
        b_name = dto.get("branch", "")
        if dto.get("branches") and isinstance(dto.get("branches"), dict):
            b_name = dto.get("branches", {}).get("name", b_name)

        # Resolve officer name from join
        o_name = dto.get("officer", dto.get("credit_officer", ""))
        if dto.get("app_users") and isinstance(dto.get("app_users"), dict):
            o_name = dto.get("app_users", {}).get("full_name", dto.get("app_users", {}).get("username", o_name))

        # Check loan product from product mapping or join if we add it
        prod_name = dto.get("loan_product", dto.get("product_type", ""))
        if dto.get("loan_products") and isinstance(dto.get("loan_products"), dict):
            prod_name = dto.get("loan_products", {}).get("name", prod_name)

        # Build extra_fields with fallback client columns
        extra = {
            "nickname": c_dto.get("nickname") or dto.get("nickname", ""),
            "phone": c_dto.get("phone") or dto.get("phone", ""),
            "address": c_dto.get("address") or dto.get("address", ""),
            "marital_status": c_dto.get("marital_status") or dto.get("marital_status", ""),
            "business_type": c_dto.get("business_type") or dto.get("business_type", ""),
            "average_monthly_income": float(c_dto.get("average_monthly_income") or dto.get("average_monthly_income", 0.0) or 0.0),
            "other_obligations": c_dto.get("other_obligations") or dto.get("other_obligations", ""),
            "guarantor_name": dto.get("guarantor_name", ""),
            "guarantor_nickname": dto.get("guarantor_nickname", ""),
            "guarantor_marital_status": dto.get("guarantor_marital_status", ""),
            "guarantor_home_address": dto.get("guarantor_home_address", ""),
            "guarantor_occupation": dto.get("guarantor_occupation", ""),
            "guarantor_office_address": dto.get("guarantor_office_address", ""),
            "guarantor_phone": dto.get("guarantor_phone", ""),
            "guarantor_relationship": dto.get("guarantor_relationship", ""),
            "group_location": dto.get("group_location", ""),
            "group_leader_name": dto.get("group_leader_name", ""),
            "group_formation_date": dto.get("group_formation_date", ""),
            "group_savings": float(dto.get("group_savings") or 0.0),
            "branch_contingency": float(dto.get("branch_contingency") or 0.0),
            "branch_contingency_2": float(dto.get("branch_contingency_2") or 0.0),
            "disbursement_date": dto.get("disbursement_date"),
            "meeting_day": dto.get("meeting_day", ""),
            "processing_fee": float(dto.get("processing_fee") or 0.0),
            "markup": float(dto.get("markup") or 0.0),
            "pass_book_fee": float(dto.get("pass_book_fee") or 0.0),
            "active_credit": float(dto.get("active_credit", dto.get("loan_amount", 0.0)) or 0.0),
            "loan_repay": float(dto.get("loan_repay", dto.get("expected_installment", 0.0)) or 0.0),
            "total_due": float(dto.get("total_due", dto.get("total_payable", 0.0)) or 0.0),
            "date": dto.get("date", dto.get("start_date"))
        }
        # merge any other extra fields from JSONB
        if dto.get("extra_fields") and isinstance(dto.get("extra_fields"), dict):
            extra.update(dto.get("extra_fields"))

        loan_id = str(dto.get("loan_id", dto.get("id") or ""))
        client_id = c_dto.get("client_code") or str(dto.get("client_id", ""))
        client_name = c_dto.get("name") or dto.get("client_name", "")

        return Loan(
            id=loan_id,
            client_id=client_id,
            client_name=client_name,
            product_type=prod_name,
            amount=float(dto.get("loan_amount", dto.get("amount", 0))),
            duration=int(dto.get("duration", 0)),
            frequency=str(dto.get("frequency", "")),
            gap_fee=float(dto.get("gap_fee", 0)),
            expected_installment=float(dto.get("expected_installment", 0)),
            total_payable=float(dto.get("total_payable", 0)),
            status=LoanStatus(dto.get("status", LoanStatus.DRAFT.value)) if dto.get("status") else LoanStatus.DRAFT,
            client_status=ClientStatus(dto.get("client_status", ClientStatus.ACTIVE.value)) if dto.get("client_status") else ClientStatus.ACTIVE,
            savings_status=SavingsStatus(dto.get("savings_status", SavingsStatus.NORMAL.value)) if dto.get("savings_status") else SavingsStatus.NORMAL,
            branch=b_name,
            credit_officer=o_name,
            start_date=_parse_date(dto.get("start_date")),
            end_date=_parse_date(dto.get("expected_end_date", dto.get("end_date"))),
            created_at=_parse_datetime(dto.get("created_at")),
            group_name=dto.get("group_name"),
            is_asset=bool(dto.get("is_asset", False)),
            officer_id=str(dto.get("officer_id") or "") if dto.get("officer_id") else None,
            branch_id=str(dto.get("branch_id") or "") if dto.get("branch_id") else None,
            extra_fields=extra
        )
        
    @staticmethod
    def to_database(entity: Loan) -> dict:
        db_dict = {
            "id": entity.id,
            "client_id": entity.client_id,
            "client_name": entity.client_name,
            "loan_product": entity.product_type,
            "loan_amount": entity.amount,
            "duration": entity.duration,
            "frequency": entity.frequency,
            "gap_fee": entity.gap_fee,
            "expected_installment": entity.expected_installment,
            "total_payable": entity.total_payable,
            "status": entity.status.value if hasattr(entity.status, 'value') else entity.status,
            "client_status": entity.client_status.value if hasattr(entity.client_status, 'value') else entity.client_status,
            "savings_status": entity.savings_status.value if hasattr(entity.savings_status, 'value') else entity.savings_status,
            "branch": entity.branch,
            "officer": entity.credit_officer,
            "start_date": entity.start_date.isoformat() if entity.start_date else None,
            "expected_end_date": entity.end_date.isoformat() if entity.end_date else None,
            "group_name": getattr(entity, 'group_name', None),
            "is_asset": getattr(entity, 'is_asset', False),
            "officer_id": getattr(entity, 'officer_id', None),
            "branch_id": getattr(entity, 'branch_id', None),
            "active_credit": entity.extra_fields.get("active_credit", entity.amount),
            "loan_repay": entity.extra_fields.get("loan_repay", entity.expected_installment),
            "total_due": entity.extra_fields.get("total_due", entity.total_payable),
            "date": entity.extra_fields.get("date", entity.start_date.isoformat() if entity.start_date else None)
        }
        # Keep client profile columns flattened for UI database representations
        db_dict.update(entity.extra_fields)
        return db_dict

class RepaymentMapper:
    @staticmethod
    def to_domain(dto: dict) -> Repayment:
        # Resolve branch name from join
        b_name = dto.get("branch", "")
        if dto.get("branches") and isinstance(dto.get("branches"), dict):
            b_name = dto.get("branches", {}).get("name", b_name)

        # Resolve officer name from join
        o_name = dto.get("officer", dto.get("credit_officer", ""))
        if dto.get("app_users") and isinstance(dto.get("app_users"), dict):
            o_name = dto.get("app_users", {}).get("full_name", dto.get("app_users", {}).get("username", o_name))

        # Resolve client name and code from join
        c_name = dto.get("client_name", "")
        c_code = dto.get("client_id", "")
        if dto.get("clients") and isinstance(dto.get("clients"), dict):
            c_name = dto.get("clients", {}).get("name", c_name)
            c_code = dto.get("clients", {}).get("client_code", c_code)

        tx_type = str(dto.get("transaction_type", "Loan"))
        if tx_type.startswith("GROUP-") or tx_type.startswith("GLOBAL-"):
            c_code = tx_type

        # Setup all collection fields expected by domain Repayment
        def safe_float(val, default=0.0):
            if val is None:
                return default
            try:
                return float(val)
            except (ValueError, TypeError):
                return default

        savings_dep = safe_float(dto.get("savings_amount"))
        if "savings_amount" not in dto or dto["savings_amount"] is None:
            if tx_type == "Savings" or tx_type.startswith("GROUP-"):
                savings_dep = safe_float(dto.get("amount_paid"))

        withdrawal_amt = safe_float(dto.get("withdrawal_amount"))
        if "withdrawal_amount" not in dto or dto["withdrawal_amount"] is None:
            if tx_type == "Withdrawal":
                withdrawal_amt = safe_float(dto.get("amount_paid"))

        others_amt = safe_float(dto.get("others_amount"))
        recovery_amt = safe_float(dto.get("recovery_amount"))
        initial_pay = safe_float(dto.get("initial_payment"))
        proc_fee = safe_float(dto.get("processing_fee_paid"))
        markup_fee = safe_float(dto.get("markup_paid"))
        passbook_fee = safe_float(dto.get("pass_book_paid"))
        mgt_fee = safe_float(dto.get("mgt_fee_paid"))

        if "loan_repayment_amount" in dto and dto["loan_repayment_amount"] is not None:
            loan_repay = safe_float(dto["loan_repayment_amount"])
        elif tx_type == "Savings" or tx_type.startswith("GROUP-") or tx_type.startswith("GLOBAL-") or tx_type == "Withdrawal":
            loan_repay = 0.0
        else:
            loan_repay = safe_float(dto.get("amount_paid"))

        amt_paid = safe_float(dto.get("amount_paid"))
        if amt_paid <= 0:
            amt_paid = savings_dep + loan_repay + proc_fee + withdrawal_amt + others_amt
            
        extra = {k: v for k, v in dto.items() if k not in ["id", "loan_id", "client_id", "amount_paid", "savings_amount", "loan_repayment_amount", "withdrawal_amount", "others_amount", "recovery_amount", "initial_payment", "date", "payment_date", "transaction_type", "branch", "officer", "credit_officer", "note", "created_at", "clients", "branches", "app_users"]}
        extra["client_name"] = c_name

        return Repayment(
            id=str(dto.get("id") or ""),
            loan_id=str(dto.get("loan_id", dto.get("client_id", ""))),
            client_id=str(c_code),
            amount_paid=amt_paid,
            savings_amount=savings_dep,
            loan_repayment_amount=loan_repay,
            withdrawal_amount=withdrawal_amt,
            others_amount=others_amt,
            recovery_amount=recovery_amt,
            initial_payment=initial_pay,
            payment_date=_parse_date(dto.get("date", dto.get("payment_date"))),
            transaction_type=str(dto.get("transaction_type", "Loan")),
            branch=b_name,
            credit_officer=o_name,
            note=str(dto.get("note") or ""),
            created_at=_parse_datetime(dto.get("created_at")),
            extra_fields=extra
        )
        
    @staticmethod
    def to_database(entity: Repayment) -> dict:
        db_dict = {
            "id": entity.id,
            "client_id": entity.client_id,
            "amount_paid": entity.amount_paid,
            "savings_amount": entity.savings_amount,
            "loan_repayment_amount": entity.loan_repayment_amount,
            "withdrawal_amount": entity.withdrawal_amount,
            "others_amount": entity.others_amount,
            "recovery_amount": entity.recovery_amount,
            "initial_payment": entity.initial_payment,
            "date": entity.payment_date.isoformat() if entity.payment_date else None,
            "transaction_type": entity.transaction_type,
            "branch": entity.branch,
            "officer": entity.credit_officer,
            "note": entity.note
        }
        db_dict.update(entity.extra_fields)
        return db_dict

class UserMapper:
    @staticmethod
    def to_domain(dto: dict) -> User:
        b_name = dto.get("branch_name", "")
        if dto.get("branches") and isinstance(dto.get("branches"), dict):
            b_name = dto.get("branches", {}).get("name", b_name)
            
        role_name = dto.get("role", "")
        ur = dto.get("user_roles")
        if ur and isinstance(ur, list) and len(ur) > 0:
            role_name = ur[0].get("roles", {}).get("name", role_name)
            
        pwd = dto.get("password_hash", dto.get("password", ""))
        
        return User(
            id=str(dto.get("id")),
            username=str(dto.get("username")),
            full_name=str(dto.get("full_name")),
            role=role_name,
            branch_name=b_name,
            password_hash=pwd,
            created_at=_parse_datetime(dto.get("created_at")),
            branch_id=str(dto.get("branch_id", "")),
            is_active=dto.get("is_active", True),
            last_login=_parse_datetime(dto.get("last_login")),
            last_activity=_parse_datetime(dto.get("last_activity"))
        )

class CashbookMapper:
    @staticmethod
    def to_domain(dto: dict) -> CashbookEntry:
        b_name = dto.get("branch", "")
        if dto.get("branches") and isinstance(dto.get("branches"), dict):
            b_name = dto.get("branches", {}).get("name", b_name)

        return CashbookEntry(
            id=dto.get("id"),
            date=_parse_date(dto.get("date")),
            branch=b_name,
            opening_balance=float(dto.get("opening_balance", 0)),
            rep_daily=float(dto.get("rep_daily", 0)),
            rep_12_weeks=float(dto.get("rep_12_weeks", 0)),
            rep_24_weeks=float(dto.get("rep_24_weeks", 0)),
            rep_monthly=float(dto.get("rep_monthly", 0)),
            savings_deposit=float(dto.get("savings_deposit", 0)),
            laps_reserve=float(dto.get("laps_reserve", 0)),
            funds_received_ho=float(dto.get("funds_received_ho", 0)),
            funds_received_other_branch=float(dto.get("funds_received_other_branch", 0)),
            loan_received_asset=float(dto.get("loan_received_asset", 0)),
            loan_received_finance=float(dto.get("loan_received_finance", 0)),
            daily_11_pct=float(dto.get("daily_11_pct", 0)),
            weekly_11_pct=float(dto.get("weekly_11_pct", 0)),
            savings_adj_no=float(dto.get("savings_adj_no", 0)),
            savings_adj_amount=float(dto.get("savings_adj_amount", 0)),
            risk_premium_returns=float(dto.get("risk_premium_returns", 0)),
            passbook=float(dto.get("passbook", 0)),
            app_fee=float(dto.get("app_fee", 0)),
            asset_credit_sales=float(dto.get("asset_credit_sales", 0)),
            cash_and_carry=float(dto.get("cash_and_carry", 0)),
            contingency=float(dto.get("contingency", 0)),
            credit_form=float(dto.get("credit_form", 0)),
            credit_form_damage=float(dto.get("credit_form_damage", 0)),
            bonus=float(dto.get("bonus", 0)),
            misc_fees=float(dto.get("misc_fees", 0)),
            fund_transferred_other_branch=float(dto.get("fund_transferred_other_branch", 0)),
            fund_transferred_ho=float(dto.get("fund_transferred_ho", 0)),
            fund_to_other_area=float(dto.get("fund_to_other_area", 0)),
            fund_to_asset_program=float(dto.get("fund_to_asset_program", 0)),
            fund_to_product_finance=float(dto.get("fund_to_product_finance", 0)),
            savings_withdrawal=float(dto.get("savings_withdrawal", 0)),
            staff_salaries=float(dto.get("staff_salaries", 0)),
            office_expenses=float(dto.get("office_expenses", 0)),
            laps_returns=float(dto.get("laps_returns", 0)),
            bank_deposit=float(dto.get("bank_deposit", 0)),
            bank_withdrawal=float(dto.get("bank_withdrawal", 0)),
            product_withdrawal=float(dto.get("product_withdrawal", 0)),
            total_inflows=float(dto.get("total_inflows", 0)),
            total_outflows=float(dto.get("total_outflows", 0)),
            closing_balance=float(dto.get("closing_balance", 0)),
            adjustment_in=float(dto.get("adjustment_in", 0)),
            adjustment_out=float(dto.get("adjustment_out", 0)),
            adjustment_reason=str(dto.get("adjustment_reason", ""))
        )
        
    @staticmethod
    def to_database(entity: CashbookEntry) -> dict:
        d = {
            "date": entity.date.isoformat() if entity.date else None,
            "branch": entity.branch,
            "opening_balance": entity.opening_balance,
            "rep_daily": entity.rep_daily,
            "rep_12_weeks": entity.rep_12_weeks,
            "rep_24_weeks": entity.rep_24_weeks,
            "rep_monthly": entity.rep_monthly,
            "savings_deposit": entity.savings_deposit,
            "laps_reserve": entity.laps_reserve,
            "funds_received_ho": entity.funds_received_ho,
            "funds_received_other_branch": entity.funds_received_other_branch,
            "loan_received_asset": entity.loan_received_asset,
            "loan_received_finance": entity.loan_received_finance,
            "daily_11_pct": entity.daily_11_pct,
            "weekly_11_pct": entity.weekly_11_pct,
            "savings_adj_no": entity.savings_adj_no,
            "savings_adj_amount": entity.savings_adj_amount,
            "risk_premium_returns": entity.risk_premium_returns,
            "passbook": entity.passbook,
            "app_fee": entity.app_fee,
            "asset_credit_sales": entity.asset_credit_sales,
            "cash_and_carry": entity.cash_and_carry,
            "contingency": entity.contingency,
            "credit_form": entity.credit_form,
            "credit_form_damage": entity.credit_form_damage,
            "bonus": entity.bonus,
            "misc_fees": entity.misc_fees,
            "fund_transferred_other_branch": entity.fund_transferred_other_branch,
            "fund_transferred_ho": entity.fund_transferred_ho,
            "fund_to_other_area": entity.fund_to_other_area,
            "fund_to_asset_program": entity.fund_to_asset_program,
            "fund_to_product_finance": entity.fund_to_product_finance,
            "savings_withdrawal": entity.savings_withdrawal,
            "staff_salaries": entity.staff_salaries,
            "office_expenses": entity.office_expenses,
            "laps_returns": entity.laps_returns,
            "bank_deposit": entity.bank_deposit,
            "bank_withdrawal": entity.bank_withdrawal,
            "product_withdrawal": entity.product_withdrawal,
            "total_inflows": entity.total_inflows,
            "total_outflows": entity.total_outflows,
            "closing_balance": entity.closing_balance,
            "adjustment_in": entity.adjustment_in,
            "adjustment_out": entity.adjustment_out,
            "adjustment_reason": entity.adjustment_reason
        }
        if entity.id: d["id"] = entity.id
        return d

class BranchClosureMapper:
    @staticmethod
    def to_domain(dto: dict) -> BranchClosure:
        return BranchClosure(
            id=dto.get("id"),
            start_date=_parse_date(dto.get("start_date")),
            end_date=_parse_date(dto.get("end_date")),
            reason=str(dto.get("reason"))
        )

class ClientMapper:
    @staticmethod
    def to_domain(dto: dict) -> Client:
        return Client(
            id=str(dto.get("client_id", "") or dto.get("id", "")),
            name=str(dto.get("name", "")),
            client_code=str(dto.get("client_code", "")),
            nickname=dto.get("nickname"),
            phone=dto.get("phone"),
            address=dto.get("address"),
            business_address=dto.get("business_address"),
            dob=_parse_date(dto.get("dob")),
            gender=dto.get("gender"),
            marital_status=dto.get("marital_status"),
            occupation=dto.get("occupation"),
            business_type=dto.get("business_type"),
            id_means=dto.get("id_means"),
            id_number=dto.get("id_number"),
            id_card_url=dto.get("id_card_url"),
            next_of_kin=dto.get("next_of_kin"),
            passport_url=dto.get("passport_url"),
            signature_url=dto.get("signature_url"),
            registration_date=_parse_date(dto.get("registration_date")),
            branch_id=dto.get("branch_id"),
            group_id=dto.get("group_id"),
            officer_id=dto.get("officer_id"),
            status=str(dto.get("status", "Active")),
            average_monthly_income=float(dto.get("average_monthly_income") or 0.0),
            other_obligations=dto.get("other_obligations")
        )

    @staticmethod
    def to_database(entity: Client) -> dict:
        return {
            "client_id": entity.id,
            "name": entity.name,
            "client_code": entity.client_code,
            "nickname": entity.nickname,
            "phone": entity.phone,
            "address": entity.address,
            "business_address": entity.business_address,
            "dob": entity.dob.isoformat() if entity.dob else None,
            "gender": entity.gender,
            "marital_status": entity.marital_status,
            "occupation": entity.occupation,
            "business_type": entity.business_type,
            "id_means": entity.id_means,
            "id_number": entity.id_number,
            "id_card_url": entity.id_card_url,
            "next_of_kin": entity.next_of_kin,
            "passport_url": entity.passport_url,
            "signature_url": entity.signature_url,
            "registration_date": entity.registration_date.isoformat() if entity.registration_date else None,
            "branch_id": entity.branch_id,
            "group_id": entity.group_id,
            "officer_id": entity.officer_id,
            "status": entity.status,
            "average_monthly_income": entity.average_monthly_income,
            "other_obligations": entity.other_obligations
        }

class GuarantorMapper:
    @staticmethod
    def to_domain(dto: dict) -> Guarantor:
        return Guarantor(
            guarantor_id=str(dto.get("guarantor_id", "") or dto.get("id", "")),
            name=str(dto.get("name", "")),
            phone=dto.get("phone"),
            address=dto.get("address"),
            occupation=dto.get("occupation"),
            business_address=dto.get("business_address"),
            id_means=dto.get("id_means"),
            id_number=dto.get("id_number"),
            id_card_url=dto.get("id_card_url"),
            passport_url=dto.get("passport_url")
        )

    @staticmethod
    def to_database(entity: Guarantor) -> dict:
        return {
            "guarantor_id": entity.guarantor_id,
            "name": entity.name,
            "phone": entity.phone,
            "address": entity.address,
            "occupation": entity.occupation,
            "business_address": entity.business_address,
            "id_means": entity.id_means,
            "id_number": entity.id_number,
            "id_card_url": entity.id_card_url,
            "passport_url": entity.passport_url
        }

class LoanGuarantorMapper:
    @staticmethod
    def to_domain(dto: dict) -> LoanGuarantor:
        return LoanGuarantor(
            id=str(dto.get("id", "")),
            loan_id=str(dto.get("loan_id", "")),
            guarantor_id=str(dto.get("guarantor_id", "")),
            relationship=dto.get("relationship"),
            signature_url=dto.get("signature_url")
        )

    @staticmethod
    def to_database(entity: LoanGuarantor) -> dict:
        return {
            "id": entity.id,
            "loan_id": entity.loan_id,
            "guarantor_id": entity.guarantor_id,
            "relationship": entity.relationship,
            "signature_url": entity.signature_url
        }
