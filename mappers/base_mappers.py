from domain.entities.loan import Loan
from domain.entities.repayment import Repayment
from domain.entities.user import User
from domain.entities.audit_event import AuditEvent
from domain.entities.cashbook_entry import CashbookEntry
from domain.entities.branch_closure import BranchClosure
from datetime import datetime

def _parse_date(date_str):
    if not date_str: return None
    try:
        return datetime.strptime(str(date_str).split('T')[0], "%Y-%m-%d").date()
    except Exception:
        return None

def _parse_datetime(dt_str):
    if not dt_str: return None
    try:
        return datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
    except Exception:
        return None

class LoanMapper:
    @staticmethod
    def to_domain(dto: dict) -> Loan:
        return Loan(
            id=str(dto.get("id")),
            client_id=str(dto.get("client_id")),
            client_name=str(dto.get("client_name", "")),
            product_type=str(dto.get("product_type", "")),
            amount=float(dto.get("amount", 0)),
            duration=int(dto.get("duration", 0)),
            frequency=str(dto.get("frequency", "")),
            gap_fee=float(dto.get("gap_fee", 0)),
            expected_installment=float(dto.get("expected_installment", 0)),
            total_payable=float(dto.get("total_payable", 0)),
            status=str(dto.get("status", "")),
            branch=str(dto.get("branch", "")),
            credit_officer=str(dto.get("credit_officer", "")),
            start_date=_parse_date(dto.get("start_date")),
            end_date=_parse_date(dto.get("end_date")),
            created_at=_parse_datetime(dto.get("created_at")),
            group_name=dto.get("group_name"),
            is_asset=bool(dto.get("is_asset", False))
        )
        
    @staticmethod
    def to_database(entity: Loan) -> dict:
        return {
            "id": entity.id,
            "client_id": entity.client_id,
            "client_name": entity.client_name,
            "product_type": entity.product_type,
            "amount": entity.amount,
            "duration": entity.duration,
            "frequency": entity.frequency,
            "gap_fee": entity.gap_fee,
            "expected_installment": entity.expected_installment,
            "total_payable": entity.total_payable,
            "status": entity.status,
            "branch": entity.branch,
            "credit_officer": entity.credit_officer,
            "start_date": entity.start_date.isoformat() if entity.start_date else None,
            "end_date": entity.end_date.isoformat() if entity.end_date else None,
            "group_name": entity.group_name,
            "is_asset": entity.is_asset
        }

class RepaymentMapper:
    @staticmethod
    def to_domain(dto: dict) -> Repayment:
        return Repayment(
            id=str(dto.get("id")),
            loan_id=str(dto.get("loan_id")),
            client_id=str(dto.get("client_id")),
            amount_paid=float(dto.get("amount_paid", 0)),
            savings_amount=float(dto.get("savings_amount", 0)),
            loan_repayment_amount=float(dto.get("loan_repayment_amount", 0)),
            withdrawal_amount=float(dto.get("withdrawal_amount", 0)),
            others_amount=float(dto.get("others_amount", 0)),
            recovery_amount=float(dto.get("recovery_amount", 0)),
            initial_payment=float(dto.get("initial_payment", 0)),
            payment_date=_parse_date(dto.get("payment_date")),
            transaction_type=str(dto.get("transaction_type", "")),
            branch=str(dto.get("branch", "")),
            credit_officer=str(dto.get("credit_officer", "")),
            created_at=_parse_datetime(dto.get("created_at"))
        )
        
    @staticmethod
    def to_database(entity: Repayment) -> dict:
        return {
            "id": entity.id,
            "loan_id": entity.loan_id,
            "client_id": entity.client_id,
            "amount_paid": entity.amount_paid,
            "savings_amount": entity.savings_amount,
            "loan_repayment_amount": entity.loan_repayment_amount,
            "withdrawal_amount": entity.withdrawal_amount,
            "others_amount": entity.others_amount,
            "recovery_amount": entity.recovery_amount,
            "initial_payment": entity.initial_payment,
            "payment_date": entity.payment_date.isoformat() if entity.payment_date else None,
            "transaction_type": entity.transaction_type,
            "branch": entity.branch,
            "credit_officer": entity.credit_officer
        }

class UserMapper:
    @staticmethod
    def to_domain(dto: dict) -> User:
        return User(
            id=str(dto.get("id")),
            username=str(dto.get("username")),
            full_name=str(dto.get("full_name")),
            role=str(dto.get("role")),
            branch_name=str(dto.get("branch_name")),
            password_hash=str(dto.get("password")),
            created_at=_parse_datetime(dto.get("created_at"))
        )

class CashbookMapper:
    @staticmethod
    def to_domain(dto: dict) -> CashbookEntry:
        return CashbookEntry(
            id=dto.get("id"),
            date=_parse_date(dto.get("date")),
            branch=str(dto.get("branch")),
            opening_balance=float(dto.get("opening_balance", 0)),
            savings_deposit=float(dto.get("savings_deposit", 0)),
            loan_recovery=float(dto.get("loan_recovery", 0)),
            disbursement=float(dto.get("disbursement", 0)),
            savings_withdrawal=float(dto.get("savings_withdrawal", 0)),
            office_expenses=float(dto.get("office_expenses", 0)),
            bank_deposit=float(dto.get("bank_deposit", 0)),
            staff_salary=float(dto.get("staff_salary", 0)),
            closing_balance=float(dto.get("closing_balance", 0)),
            shortage=float(dto.get("shortage", 0)),
            excess=float(dto.get("excess", 0)),
            is_balanced=bool(dto.get("is_balanced", False)),
            status=str(dto.get("status", ""))
        )
        
    @staticmethod
    def to_database(entity: CashbookEntry) -> dict:
        d = {
            "date": entity.date.isoformat() if entity.date else None,
            "branch": entity.branch,
            "opening_balance": entity.opening_balance,
            "savings_deposit": entity.savings_deposit,
            "loan_recovery": entity.loan_recovery,
            "disbursement": entity.disbursement,
            "savings_withdrawal": entity.savings_withdrawal,
            "office_expenses": entity.office_expenses,
            "bank_deposit": entity.bank_deposit,
            "staff_salary": entity.staff_salary,
            "closing_balance": entity.closing_balance,
            "shortage": entity.shortage,
            "excess": entity.excess,
            "is_balanced": entity.is_balanced,
            "status": entity.status
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
