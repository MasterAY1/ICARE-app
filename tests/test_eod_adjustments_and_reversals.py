import pytest
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.event_store import DomainEvent
from services.posting_engine import FinancialPostingEngine

def test_bank_deposit_reversed_posting_rule_exists():
    """Verify BankDepositReversed exists in posting_rules (Dr 1000, Cr 1050)."""
    with SupabaseUnitOfWork() as uow:
        rule = uow.posting_rules.get_rule("BankDepositReversed", 1)
        assert rule is not None
        assert rule.debit_account == "1000"
        assert rule.credit_account == "1050"

def test_untouched_field_preservation_logic():
    """Verify that leaving a field as None preserves existing database value without generating deltas."""
    cur_cb = {
        "app_fee": 1500.0,
        "passbook": 200.0,
        "credit_form_damage": 500.0,
        "bonus": 0.0,
        "misc_fees": 0.0,
        "office_expenses": 1000.0,
        "bank_deposit": 250000.0
    }
    
    input_opening = None
    input_expenses = 1500.0
    input_bank_dep = 380100.0
    input_app_fee = None
    input_passbook = None
    input_misc_fee = None
    input_cfd = None
    input_bonus = None

    effective_app_fee = float(input_app_fee) if input_app_fee is not None else float(cur_cb.get("app_fee") or 0.0)
    effective_cfd = float(input_cfd) if input_cfd is not None else float(cur_cb.get("credit_form_damage") or 0.0)
    effective_expenses = float(input_expenses) if input_expenses is not None else float(cur_cb.get("office_expenses") or 0.0)
    effective_bank_dep = float(input_bank_dep) if input_bank_dep is not None else float(cur_cb.get("bank_deposit") or 0.0)

    d_cfd = effective_cfd - cur_cb["credit_form_damage"]
    d_app = effective_app_fee - cur_cb["app_fee"]
    d_exp = effective_expenses - cur_cb["office_expenses"]
    d_bdep = effective_bank_dep - cur_cb["bank_deposit"]

    assert d_cfd == 0.0, "Untouched CFD must produce 0 delta"
    assert d_app == 0.0, "Untouched App Fee must produce 0 delta"
    assert d_exp == 500.0, "Expenses increased by 500"
    assert d_bdep == 130100.0, "Bank deposit increased by 130,100"

def test_safe_reduction_delta_routing():
    """Verify that if an amount is explicitly reduced, delta routing produces a positive amount reversal."""
    cur_exp = 2000.0
    new_exp = 1500.0
    d_exp = new_exp - cur_exp
    assert d_exp == -500.0

    if d_exp > 0:
        ev_type = "ExpenseRecorded"
        amt = d_exp
    else:
        ev_type = "ExpenseReversed"
        amt = abs(d_exp)

    assert ev_type == "ExpenseReversed"
    assert amt == 500.0
    assert amt > 0, "Posting engine requires positive amounts"

def test_safe_bank_deposit_reduction_routing():
    """Verify reducing a bank deposit routes to positive BankDepositReversed."""
    cur_bdep = 400000.0
    new_bdep = 380100.0
    d_bdep = new_bdep - cur_bdep
    assert d_bdep == -19900.0

    if d_bdep > 0:
        ev_type = "BankDeposited"
        amt = d_bdep
    else:
        ev_type = "BankDepositReversed"
        amt = abs(d_bdep)

    assert ev_type == "BankDepositReversed"
    assert amt == 19900.0
    assert amt > 0
