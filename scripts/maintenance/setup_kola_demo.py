"""
ICARE Core Banking — Kola Branch 6-Client Director Presentation Simulation
===========================================================================
Populates the empty Kola branch (dd09c735-3b1e-4eeb-89a8-d27a85e02156) using real
authoritative domain services so every table balances across:
  - Operational Tables (groups, clients, memberships, guarantors, loans, loan_schedule,
    repayments, individual_savings, group_savings, fees, withdrawal_requests,
    loan_overdue_recovery_records, collection_performance, treasury_transactions)
  - Double-Entry Financial Ledger (event_store -> financial_transactions ->
    financial_ledger_entries, Account 1000 physical vault truth)
  - Projections (co_cashbooks, master_cashbook, area_eod_confirmations)

Client Mix (6 Clients under KOL_CO1):
  1. Daily 60 Days   - KOL-01-001 Mrs. Funke Adewale   (On Loan, prior overdue recovery record, due Friday)
  2. Daily 60 Days   - KOL-01-002 Mr. Tunde Bakare      (Defaulter, 6+ missed days arrears -> live recovery demo)
  3. Weekly 12W      - KOL-02-001 Mrs. Chinyere Okafor  (On Loan, Friday group due Friday + Pending Withdrawal)
  4. Weekly 24W      - KOL-02-002 Mr. Musa Ibrahim      (On Loan, Friday group due Friday)
  5. Weekly 12W      - KOL-03-001 Mrs. Blessing Eze     (On Loan, Monday group, 2 wks overdue -> weekly recovery demo)
  6. Monthly 3M      - KOL-04-001 Alhaji Rasheed Bello  (On Loan, Month 1 due Friday Presentation Day)

Strictly scoped to Kola branch_id. Zero mutations to Ogijo or any other branch.
"""
from __future__ import annotations

import json
import os
import sys
import uuid
from datetime import date, datetime, timedelta
from typing import Dict, List, Optional

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from auth.password import hash_password
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.loan import Loan
from domain.enums import ClientStatus, LoanStatus, SavingsStatus
from services.business_date_service import BusinessDateService, get_nigerian_holidays
from services.client_status_service import ClientStatusService
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.collection_batch_service import save_repayment
from services.loan_product_engine import LoanProductEngine
from services.loan_service import LoanService
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
from services.posting_engine import FinancialPostingEngine
from services.reconciliation_service import DailyReconciliationService
from services.savings_service import SavingsService
from services.schedule_service import ScheduleService
from services.treasury_service import TreasuryService

# ---------------------------------------------------------------------------
# Authoritative Live Database Identifiers (Verified against zkphpwixqpebsctfklpd)
# ---------------------------------------------------------------------------
KOLA_BRANCH_ID = "dd09c735-3b1e-4eeb-89a8-d27a85e02156"
KOLA_BRANCH_NAME = "Kola"
KOLA_BRANCH_CODE = "KOL"
OGIJO_BRANCH_ID = "997d504e-7f5c-4772-887d-fdd5a4c1183b"

NS = uuid.UUID(KOLA_BRANCH_ID)

BM_ROLE_ID = "3ea1496a-0498-4a1d-872a-1c7ecdf77b06"
CO_ROLE_ID = "bd8790ee-c0eb-485a-8b6a-93f54519965d"
AM_USER_ID = "e6a77cdb-6012-4506-8240-7e46e81d954d"  # AM_Area_1 (Mrs. Shobande)

STATUS_REGISTERED = "11111111-1111-1111-1111-111111110001"

DEMO_PASSWORD = os.getenv("KOLA_DEMO_PASSWORD", "KolaDemo@2026")
PASSWORD_HASH = hash_password(DEMO_PASSWORD)

BM_ID = str(uuid.uuid5(NS, "user_BM_Kola"))
CO1_ID = str(uuid.uuid5(NS, "user_KOL_CO1"))
BM_USERNAME = "BM_Kola"
CO1_USERNAME = "KOL_CO1"

GRP_DAILY_ID = str(uuid.uuid5(NS, "group_KOL_01_DAILY"))
GRP_WEEKLY_FRI_ID = str(uuid.uuid5(NS, "group_KOL_02_WEEKLY_FRI"))
GRP_WEEKLY_MON_ID = str(uuid.uuid5(NS, "group_KOL_03_WEEKLY_MON"))
GRP_MONTHLY_ID = str(uuid.uuid5(NS, "group_KOL_04_MONTHLY"))

PRESENTATION_DATE = date(2026, 11, 27)  # Friday Director Presentation Day


def det_id(key: str) -> str:
    return str(uuid.uuid5(NS, key))


def _snapshot_ogijo(uow: SupabaseUnitOfWork) -> Dict[str, int]:
    return {
        "clients": uow.client.table("clients").select("client_id", count="exact").eq("branch_id", OGIJO_BRANCH_ID).execute().count or 0,
        "groups": uow.client.table("groups").select("group_id", count="exact").eq("branch_id", OGIJO_BRANCH_ID).execute().count or 0,
        "loans": uow.client.table("loans").select("loan_id", count="exact").eq("branch_id", OGIJO_BRANCH_ID).execute().count or 0,
        "repayments": uow.client.table("repayments").select("id", count="exact").eq("branch_id", OGIJO_BRANCH_ID).execute().count or 0,
        "ledger": uow.client.table("financial_ledger_entries").select("entry_id", count="exact").eq("branch_id", OGIJO_BRANCH_ID).execute().count or 0,
    }


def _reset_kola_only(uow: SupabaseUnitOfWork) -> None:
    """Safely removes ONLY Kola-scoped transactional/demo rows so reruns are 100% idempotent."""
    assert KOLA_BRANCH_ID != OGIJO_BRANCH_ID
    c = uow.client

    kola_loan_ids = [r["loan_id"] for r in (c.table("loans").select("loan_id").eq("branch_id", KOLA_BRANCH_ID).execute().data or [])]
    kola_client_ids = [r["client_id"] for r in (c.table("clients").select("client_id").eq("branch_id", KOLA_BRANCH_ID).execute().data or [])]
    kola_tx_rows = c.table("financial_transactions").select("transaction_id, event_id").eq("branch_id", KOLA_BRANCH_ID).execute().data or []
    kola_event_ids = list({r["event_id"] for r in kola_tx_rows if r.get("event_id")})

    # Add aggregate event_ids linked directly to Kola loans/clients/branch
    if kola_loan_ids + kola_client_ids + [KOLA_BRANCH_ID]:
        ev_extra = c.table("event_store").select("event_id, payload").in_("aggregate_id", kola_loan_ids + kola_client_ids + [KOLA_BRANCH_ID]).execute().data or []
        for er in ev_extra:
            if er.get("event_id") and er["event_id"] not in kola_event_ids:
                kola_event_ids.append(er["event_id"])

    # Also capture events from fees/withdrawals/treasury whose payload branch_id == KOLA_BRANCH_ID
    kola_guarantor_ids = []
    if kola_loan_ids:
        lg_rows = c.table("loan_guarantors").select("guarantor_id").in_("loan_id", kola_loan_ids).execute().data or []
        kola_guarantor_ids = list({r["guarantor_id"] for r in lg_rows if r.get("guarantor_id")})

    # Child-to-parent deletion strictly scoped to Kola
    if kola_client_ids or kola_loan_ids:
        if kola_client_ids:
            c.table("collection_performance").delete().in_("client_id", kola_client_ids).execute()
            c.table("client_status_history").delete().in_("client_id", kola_client_ids).execute()
            c.table("client_profile_update_requests").delete().eq("branch_id", KOLA_BRANCH_ID).execute()
        if kola_loan_ids:
            c.table("collection_performance").delete().in_("loan_id", kola_loan_ids).execute()
            c.table("loan_guarantors").delete().in_("loan_id", kola_loan_ids).execute()
            c.table("loan_schedule").delete().in_("loan_id", kola_loan_ids).execute()

    for tbl in (
        "loan_overdue_recovery_records",
        "loan_payoff_excess_records",
        "repayments",
        "withdrawal_requests",
        "fees",
        "individual_savings",
        "group_savings",
        "laps_savings",
        "treasury_transactions",
        "client_memberships",
        "financial_ledger_entries",
        "financial_transactions",
        "co_cashbooks",
        "master_cashbook",
        "area_eod_confirmations",
        "idempotency_keys",
        "loans",
        "clients",
        "groups",
    ):
        c.table(tbl).delete().eq("branch_id", KOLA_BRANCH_ID).execute()

    if kola_guarantor_ids:
        c.table("guarantors").delete().in_("guarantor_id", kola_guarantor_ids).execute()

    if kola_event_ids:
        for i in range(0, len(kola_event_ids), 100):
            chunk = kola_event_ids[i : i + 100]
            c.table("event_processing").delete().in_("event_id", chunk).execute()
            c.table("event_store").delete().in_("event_id", chunk).execute()

    c.table("audit_logs").delete().in_("user_id", [BM_ID, CO1_ID]).execute()
    c.table("user_audit_logs").delete().eq("branch", KOLA_BRANCH_NAME).execute()

    # Clear cached metadata cleanly
    FinancialPostingEngine._branch_cache.clear()
    FinancialPostingEngine._officer_cache.clear()
    FinancialPostingEngine._rules_cache.clear()
    ClientStatusService._status_cache.clear()
    ClientStatusService._status_by_id_cache.clear()
    BusinessDateService.invalidate_operational_cache()


def _setup_staff_and_groups(uow: SupabaseUnitOfWork) -> None:
    c = uow.client
    all_products = [
        "Daily 60 Days",
        "Daily 120 Days",
        "Weekly 12W",
        "Weekly 24W",
        "Monthly 3M",
        "Monthly 6M",
    ]
    bm_extra = {
        "allowed_products": all_products,
        "must_change_password": False,
        "mfa_enabled": False,
        "phone": "08030001001",
    }
    co_extra = {
        "allowed_products": all_products,
        "must_change_password": False,
        "mfa_enabled": False,
        "phone": "08030001002",
    }

    c.table("app_users").upsert(
        [
            {
                "id": BM_ID,
                "username": BM_USERNAME,
                "password_hash": PASSWORD_HASH,
                "full_name": "Mr. Adewale Ogunleye",
                "branch_id": KOLA_BRANCH_ID,
                "is_active": True,
                "is_deleted": False,
                "extra_fields": bm_extra,
            },
            {
                "id": CO1_ID,
                "username": CO1_USERNAME,
                "password_hash": PASSWORD_HASH,
                "full_name": "Miss. Toluwase Adeyemi",
                "branch_id": KOLA_BRANCH_ID,
                "is_active": True,
                "is_deleted": False,
                "extra_fields": co_extra,
            },
        ],
        on_conflict="id",
    ).execute()

    c.table("user_roles").upsert(
        [
            {"user_id": BM_ID, "role_id": BM_ROLE_ID},
            {"user_id": CO1_ID, "role_id": CO_ROLE_ID},
        ],
        on_conflict="user_id,role_id",
    ).execute()

    # Ensure AM_Area_1 covers Kola
    c.table("area_manager_assignments").upsert(
        {"am_id": AM_USER_ID, "branch_id": KOLA_BRANCH_ID},
        on_conflict="am_id,branch_id",
    ).execute()

    # Assign Misc Savings Manager and clear initial business_date to 2026-10-19 for chronological replay
    c.table("branches").update(
        {
            "officer_assignments": [
                {
                    "officer_id": CO1_ID,
                    "full_name": "Miss. Toluwase Adeyemi",
                    "phone": "08030001002",
                    "role": "Credit Officer",
                    "is_misc_savings_manager": True,
                }
            ],
            "cashbook_defaults": {"business_date": "2026-10-19"},
        }
    ).eq("branch_id", KOLA_BRANCH_ID).execute()

    groups = [
        {
            "group_id": GRP_DAILY_ID,
            "name": "Kola Daily Market Traders",
            "meeting_day": "Daily",
            "branch_id": KOLA_BRANCH_ID,
            "officer_id": CO1_ID,
            "status": "Active",
            "group_number": "1",
            "current_member_sequence": 2,
            "leader_name": "Mrs. Funke Adewale",
            "is_deleted": False,
        },
        {
            "group_id": GRP_WEEKLY_FRI_ID,
            "name": "Kola Weekly Peace",
            "meeting_day": "Friday",
            "branch_id": KOLA_BRANCH_ID,
            "officer_id": CO1_ID,
            "status": "Active",
            "group_number": "2",
            "current_member_sequence": 2,
            "leader_name": "Mrs. Chinyere Okafor",
            "is_deleted": False,
        },
        {
            "group_id": GRP_WEEKLY_MON_ID,
            "name": "Kola Weekly Unity",
            "meeting_day": "Monday",
            "branch_id": KOLA_BRANCH_ID,
            "officer_id": CO1_ID,
            "status": "Active",
            "group_number": "3",
            "current_member_sequence": 1,
            "leader_name": "Mrs. Blessing Eze",
            "is_deleted": False,
        },
        {
            "group_id": GRP_MONTHLY_ID,
            "name": "Kola Monthly Enterprise",
            "meeting_day": "Monthly",
            "branch_id": KOLA_BRANCH_ID,
            "officer_id": CO1_ID,
            "status": "Active",
            "group_number": "4",
            "current_member_sequence": 1,
            "leader_name": "Alhaji Rasheed Bello",
            "is_deleted": False,
        },
    ]
    c.table("groups").upsert(groups, on_conflict="group_id").execute()


def _create_clients(uow: SupabaseUnitOfWork) -> Dict[str, dict]:
    """Creates the 6 Kola clients in Registered state prior to chronological savings/disbursement."""
    specs = [
        {
            "code": "KOL-01-001",
            "name": "Mrs. Funke Adewale",
            "phone": "08032210001",
            "gender": "Female",
            "business": "Provision & Foodstuff Store",
            "address": "14 Alagbado Market Road, Kola",
            "income": 180000.0,
            "group_id": GRP_DAILY_ID,
            "group_name": "Kola Daily Market Traders",
            "guarantor": ("Mr. Kayode Adewale", "08035510001", "Husband", "Trader"),
            "reg_date": "2026-10-19",
            "product": "Daily 60 Days",
            "principal": 120000.0,
            "extra_savings": 15000.0,
            "disb_date": date(2026, 11, 11),
        },
        {
            "code": "KOL-01-002",
            "name": "Mr. Tunde Bakare",
            "phone": "08032210002",
            "gender": "Male",
            "business": "Automobile Spare Parts",
            "address": "82 Abeokuta Expressway, Kola",
            "income": 165000.0,
            "group_id": GRP_DAILY_ID,
            "group_name": "Kola Daily Market Traders",
            "guarantor": ("Mrs. Shakirat Bakare", "08035510002", "Spouse", "Tailor"),
            "reg_date": "2026-10-19",
            "product": "Daily 60 Days",
            "principal": 100000.0,
            "extra_savings": 4500.0,
            "disb_date": date(2026, 11, 4),
        },
        {
            "code": "KOL-02-001",
            "name": "Mrs. Chinyere Okafor",
            "phone": "08032210003",
            "gender": "Female",
            "business": "Wholesale Textile & Ankara",
            "address": "5 Old Ota Road, Kola",
            "income": 210000.0,
            "group_id": GRP_WEEKLY_FRI_ID,
            "group_name": "Kola Weekly Peace",
            "guarantor": ("Mr. Emeka Okafor", "08035510003", "Spouse", "Electronics Dealer"),
            "reg_date": "2026-10-19",
            "product": "Weekly 12W",
            "principal": 120000.0,
            "extra_savings": 20000.0,
            "disb_date": date(2026, 11, 6),
        },
        {
            "code": "KOL-02-002",
            "name": "Mr. Musa Ibrahim",
            "phone": "08032210004",
            "gender": "Male",
            "business": "Frozen Foods & Cold Room",
            "address": "27 Command Bus Stop, Kola",
            "income": 240000.0,
            "group_id": GRP_WEEKLY_FRI_ID,
            "group_name": "Kola Weekly Peace",
            "guarantor": ("Alhaji Danladi Ibrahim", "08035510004", "Brother", "Logistics"),
            "reg_date": "2026-10-19",
            "product": "Weekly 24W",
            "principal": 120000.0,
            "extra_savings": 16000.0,
            "disb_date": date(2026, 10, 30),
        },
        {
            "code": "KOL-03-001",
            "name": "Mrs. Blessing Eze",
            "phone": "08032210005",
            "gender": "Female",
            "business": "Hair Salon & Cosmetics",
            "address": "11 AIT Road, Kola",
            "income": 150000.0,
            "group_id": GRP_WEEKLY_MON_ID,
            "group_name": "Kola Weekly Unity",
            "guarantor": ("Mr. Chukwudi Eze", "08035510005", "Brother", "Pharmacist"),
            "reg_date": "2026-10-19",
            "product": "Weekly 12W",
            "principal": 100000.0,
            "extra_savings": 12000.0,
            "disb_date": date(2026, 10, 19),
        },
        {
            "code": "KOL-04-001",
            "name": "Alhaji Rasheed Bello",
            "phone": "08032210006",
            "gender": "Male",
            "business": "Building Materials Distribution",
            "address": "3 Station Road, Kola",
            "income": 350000.0,
            "group_id": GRP_MONTHLY_ID,
            "group_name": "Kola Monthly Enterprise",
            "guarantor": ("Mrs. Halimat Bello", "08035510006", "Spouse", "Boutique Owner"),
            "reg_date": "2026-10-19",
            "product": "Monthly 3M",
            "principal": 150000.0,
            "extra_savings": 25000.0,
            "disb_date": date(2026, 10, 27),
        },
    ]

    registry: Dict[str, dict] = {}
    client_rows = []
    membership_rows = []
    guarantor_rows = []

    for s in specs:
        cid = det_id(f"client_{s['code']}")
        gid = det_id(f"guarantor_{s['code']}")
        g_name, g_phone, g_rel, g_occ = s["guarantor"]

        nok_meta = {
            "guarantor_name": g_name,
            "guarantor_phone": g_phone,
            "guarantor_relationship": g_rel,
            "guarantor_occupation": g_occ,
            "guarantor_home_address": s["address"],
            "guarantor_office_address": "Kola Central Market",
            "guarantor_id_means": "NIN",
            "guarantor_id_number": f"NIN-{s['code'].replace('-', '')}99",
        }
        client_rows.append(
            {
                "client_id": cid,
                "name": s["name"],
                "phone": s["phone"],
                "address": s["address"],
                "business_address": s["address"],
                "business_type": s["business"],
                "occupation": s["business"],
                "marital_status": "Married",
                "average_monthly_income": s["income"],
                "gender": s["gender"],
                "id_means": "NIN",
                "id_number": f"NIN-{s['code'].replace('-', '')}01",
                "next_of_kin": json.dumps(nok_meta),
                "client_code": s["code"],
                "registration_date": s["reg_date"],
                "branch_id": KOLA_BRANCH_ID,
                "group_id": s["group_id"],
                "officer_id": CO1_ID,
                "status": "Registered",
                "status_id": STATUS_REGISTERED,
                "status_changed_at": f"{s['reg_date']}T08:00:00+00:00",
                "status_changed_by": CO1_ID,
                "version": 1,
                "is_deleted": False,
            }
        )
        membership_rows.append(
            {
                "membership_id": det_id(f"membership_{s['code']}"),
                "client_id": cid,
                "group_id": s["group_id"],
                "branch_id": KOLA_BRANCH_ID,
                "officer_id": CO1_ID,
                "start_date": s["reg_date"],
                "version": 1,
            }
        )
        guarantor_rows.append(
            {
                "guarantor_id": gid,
                "name": g_name,
                "phone": g_phone,
                "address": s["address"],
                "occupation": g_occ,
                "business_address": "Kola Central Market",
                "id_means": "NIN",
                "id_number": f"NIN-{s['code'].replace('-', '')}99",
            }
        )

        setup = LoanProductEngine.calculate_loan_setup(s["principal"], s["product"], "Finance")
        s["client_id"] = cid
        s["guarantor_id"] = gid
        s["loan_id"] = det_id(f"loan_{s['code']}")
        s["setup"] = setup
        registry[s["code"]] = s

    uow.client.table("clients").upsert(client_rows, on_conflict="client_id").execute()
    uow.client.table("client_memberships").upsert(membership_rows, on_conflict="membership_id").execute()
    uow.client.table("guarantors").upsert(guarantor_rows, on_conflict="guarantor_id").execute()
    return registry


def _sync_kola_timestamps_to_posting_date(uow: SupabaseUnitOfWork) -> None:
    """Aligns created_at on Kola ledger/transaction rows to posting_date for time-bounded EOD checks."""
    c = uow.client
    tx_rows = (
        c.table("financial_transactions")
        .select("transaction_id, event_id, posting_date")
        .eq("branch_id", KOLA_BRANCH_ID)
        .execute()
        .data
        or []
    )
    for tx in tx_rows:
        p_date = str(tx.get("posting_date") or "")[:10]
        if not p_date:
            continue
        ts = f"{p_date}T12:00:00+00:00"
        c.table("financial_ledger_entries").update({"created_at": ts}).eq("transaction_id", tx["transaction_id"]).execute()
        c.table("financial_transactions").update({"created_at": ts}).eq("transaction_id", tx["transaction_id"]).execute()
        if tx.get("event_id"):
            c.table("event_store").update({"created_at": ts}).eq("event_id", tx["event_id"]).execute()


def main() -> None:
    ng_holidays = get_nigerian_holidays([2026])

    def _next_open_day(d: date) -> date:
        while d.weekday() >= 5 or d in ng_holidays:
            d += timedelta(days=1)
        return d

    with SupabaseUnitOfWork() as uow:
        before_ogijo = _snapshot_ogijo(uow)
        print(f"[PRE-CHECK] Ogijo baseline: {before_ogijo}")

        print("[1/6] Cleaning any prior Kola-only data (Ogijo untouched)...")
        _reset_kola_only(uow)

        print("[2/6] Provisioning BM_Kola, KOL_CO1, AM_Area_1 link, and 4 solidarity groups...")
        _setup_staff_and_groups(uow)

        print("[3/6] Registering 6 Kola clients + KYC + guarantors...")
        clients = _create_clients(uow)

        # Build chronological daily event plan from 2026-10-19 through 2026-11-25
        day_actions: Dict[date, List] = {}

        def add_action(d: date, fn):
            d_open = _next_open_day(d)
            day_actions.setdefault(d_open, []).append((d_open, fn))

        # Day 1 Capital Injection & Initial Group Savings
        def _cap_injection(d: date):
            TreasuryService.post_treasury_transaction(
                uow,
                tx_type="HO_TRANSFER_IN",
                amount=1500000.0,
                branch=KOLA_BRANCH_NAME,
                officer=BM_USERNAME,
                reference="HO-KOL-CAP-001",
                remarks="Head Office Working Capital Float for Kola Branch Launch",
                posting_date=d,
            )
            for grp_name, amt, idx in (
                ("Kola Daily Market Traders", 10000.0, 1),
                ("Kola Weekly Peace", 12000.0, 2),
                ("Kola Weekly Unity", 8000.0, 3),
                ("Kola Monthly Enterprise", 10000.0, 4),
            ):
                SavingsService.post_group_savings(
                    uow,
                    group_name=grp_name,
                    branch=KOLA_BRANCH_NAME,
                    officer=CO1_USERNAME,
                    deposit_amount=amt,
                    withdrawal_amount=0.0,
                    reference=f"KOL-GRP-INIT-{idx}",
                    remarks=f"Group security savings deposit - {grp_name}",
                    posting_date=d,
                    idempotency_key=det_id(f"grp_init_{idx}"),
                )

        add_action(date(2026, 10, 19), _cap_injection)

        # Schedule each client's upfront+personal savings deposit + disbursement + repayments
        # First deposit savings 1 step before disbursement on disbursement date
        for code, spec in clients.items():
            disb_d = _next_open_day(spec["disb_date"])
            setup = spec["setup"]
            upfront_req = float(setup["total_upfront_required"])
            init_deposit = upfront_req + float(spec["extra_savings"])

            def _make_disb_fn(c_spec=spec, c_setup=setup, dep_amt=init_deposit, d_ref=disb_d):
                def _run(d: date):
                    # 1. Personal Savings + Onboarding Passbook Fee
                    fee_amt = 1500.0 if c_spec["code"] == "KOL-01-001" else 500.0
                    save_repayment(
                        {
                            "tx_id": det_id(f"init_tx_{c_spec['code']}"),
                            "savings_tx_id": det_id(f"init_sav_{c_spec['code']}"),
                            "fee_reference": f"FEE-REG-{c_spec['code']}",
                            "Date": d.isoformat(),
                            "Client ID": c_spec["client_id"],
                            "Client Name": c_spec["name"],
                            "Group": c_spec["group_name"],
                            "Officer": CO1_USERNAME,
                            "Branch": KOLA_BRANCH_NAME,
                            "Loan Repayment Amount": 0.0,
                            "Savings Amount": dep_amt,
                            "App Fee": fee_amt,
                            "Pass Book Bonus": 500.0,
                            "Note": f"Initial savings & onboarding fees for {c_spec['name']}",
                            "Transaction Type": "Individual Savings Deposit",
                        },
                        override_uow=uow,
                    )

                    # 2. Originate & Disburse Loan atomically via LoanService
                    g_id_val = c_spec["guarantor_id"]
                    c_rel = c_spec["guarantor"][2]
                    loan_entity = Loan(
                        id=c_spec["loan_id"],
                        client_id=c_spec["client_id"],
                        client_name=c_spec["name"],
                        product_type=c_spec["product"],
                        amount=c_spec["principal"],
                        duration=int(c_setup["duration"]),
                        frequency=c_setup["freq"],
                        gap_fee=float(c_setup["gap_fee"]),
                        expected_installment=float(c_setup["loan_repayment"]),
                        total_payable=float(c_setup["active_credit"]),
                        status=LoanStatus.PENDING,
                        branch=KOLA_BRANCH_NAME,
                        branch_id=KOLA_BRANCH_ID,
                        credit_officer=CO1_USERNAME,
                        officer_id=CO1_ID,
                        client_status=ClientStatus.REGISTERED,
                        savings_status=SavingsStatus.NORMAL,
                        group_name=c_spec["group_name"],
                        extra_fields={
                            "product_category": "Finance",
                            "active_credit": float(c_setup["active_credit"]),
                            "loan_repay": float(c_setup["loan_repayment"]),
                            "total_due": float(c_setup["active_credit"]),
                            "upfront_interest": float(c_setup["interest"]),
                            "gap_fee": float(c_setup["gap_fee"]),
                            "total_upfront_required": float(c_setup["total_upfront_required"]),
                            "guarantor_name": c_spec["guarantor"][0],
                            "guarantor_phone": c_spec["guarantor"][1],
                            "guarantor_relationship": c_rel,
                            "guarantor_occupation": c_spec["guarantor"][3],
                        },
                    )
                    # Originate Pending loan application first, then BM approves & disburses via LoanService
                    pending_db_rec = uow.loans._prepare_db_data(loan_entity)
                    pending_db_rec["loan_id"] = c_spec["loan_id"]
                    pending_db_rec["status"] = "Pending"
                    pending_db_rec["disbursement_date"] = None
                    pending_db_rec["date"] = d.isoformat()
                    uow.client.table("loans").upsert(pending_db_rec, on_conflict="loan_id").execute()

                    LoanService.disburse_loan(uow, loan_entity, disbursement_date=d)
                    uow.client.table("loan_guarantors").upsert(
                        {
                            "id": det_id(f"loan_guar_{c_spec['code']}"),
                            "loan_id": c_spec["loan_id"],
                            "guarantor_id": g_id_val,
                            "relationship": c_rel,
                        },
                        on_conflict="id",
                    ).execute()

                return _run

            add_action(disb_d, _make_disb_fn())

        def _make_rep_fn(code: str, amount: float, expected: float, mark_not_paid: bool = False, extra_sav: float = 0.0, tag: str = ""):
            c_spec = clients[code]

            def _run(d: date):
                p_status = "NOT_PAID" if mark_not_paid else ("EXCESS" if amount > expected else "PAID")
                overdue_val = expected if mark_not_paid else 0.0
                save_repayment(
                    {
                        "tx_id": det_id(f"rep_{code}_{d.isoformat()}_{tag}"),
                        "savings_tx_id": det_id(f"sav_{code}_{d.isoformat()}_{tag}"),
                        "idempotency_key": det_id(f"idem_{code}_{d.isoformat()}_{tag}"),
                        "Date": d.isoformat(),
                        "Client ID": c_spec["client_id"],
                        "Client Name": c_spec["name"],
                        "Group": c_spec["group_name"],
                        "Loan Product": c_spec["product"],
                        "loan_id": c_spec["loan_id"],
                        "Officer": CO1_USERNAME,
                        "Branch": KOLA_BRANCH_NAME,
                        "Loan Repayment Amount": amount,
                        "Savings Amount": extra_sav,
                        "Expected Amount": expected,
                        "Overdue Amount": overdue_val,
                        "Payment Status": p_status,
                        "mark_not_paid": mark_not_paid,
                        "Transaction Type": "Loan" if (amount > 0 or mark_not_paid) else "Individual Savings Deposit",
                        "Note": f"{'Unpaid meeting mark' if mark_not_paid else 'Collection'} ({tag or d.isoformat()})",
                    },
                    override_uow=uow,
                )

            return _run

        # --- KOL-01-001 (Daily 60D, ₦2,000/day, disb 2026-11-11, start 2026-11-12) ---
        # Misses 2026-11-18, pays ₦4,000 recovery on 2026-11-19 (triggers automatic overdue recovery record),
        # pays double on 2026-11-25 (covers Wed 25 + Thu 26) so Friday 2026-11-27 is clean & Due Today!
        inst_01 = float(clients["KOL-01-001"]["setup"]["loan_repayment"])  # 2,000.0
        for dt_day in (
            date(2026, 11, 12),
            date(2026, 11, 13),
            date(2026, 11, 16),
            date(2026, 11, 17),
            date(2026, 11, 20),
            date(2026, 11, 23),
            date(2026, 11, 24),
        ):
            add_action(dt_day, _make_rep_fn("KOL-01-001", inst_01, inst_01, tag="daily_reg"))
        add_action(date(2026, 11, 18), _make_rep_fn("KOL-01-001", 0.0, inst_01, mark_not_paid=True, tag="missed_1"))
        add_action(date(2026, 11, 19), _make_rep_fn("KOL-01-001", inst_01 * 2, inst_01, tag="recovery_catchup"))
        add_action(date(2026, 11, 25), _make_rep_fn("KOL-01-001", inst_01 * 2, inst_01, extra_sav=1000.0, tag="wed_plus_thu"))

        # --- KOL-01-002 (Daily 60D, ₦1,650/day, disb 2026-11-04, start 2026-11-05) ---
        # Pays 10 installments (Nov 5..18), then misses Nov 19, 20, 23, 24, 25 -> Defaulter!
        inst_02 = float(clients["KOL-01-002"]["setup"]["loan_repayment"])  # 1,650.0
        for dt_day in (
            date(2026, 11, 5),
            date(2026, 11, 6),
            date(2026, 11, 9),
            date(2026, 11, 10),
            date(2026, 11, 11),
            date(2026, 11, 12),
            date(2026, 11, 13),
            date(2026, 11, 16),
            date(2026, 11, 17),
            date(2026, 11, 18),
        ):
            add_action(dt_day, _make_rep_fn("KOL-01-002", inst_02, inst_02, tag="daily_reg"))
        for dt_miss in (
            date(2026, 11, 19),
            date(2026, 11, 20),
            date(2026, 11, 23),
            date(2026, 11, 24),
            date(2026, 11, 25),
        ):
            add_action(dt_miss, _make_rep_fn("KOL-01-002", 0.0, inst_02, mark_not_paid=True, tag="daily_miss"))

        # --- KOL-02-001 (Weekly 12W Friday group, ₦10,000/wk, disb 2026-11-06) ---
        inst_03 = float(clients["KOL-02-001"]["setup"]["loan_repayment"])  # 10,000.0
        for dt_w in (date(2026, 11, 13), date(2026, 11, 20)):
            add_action(dt_w, _make_rep_fn("KOL-02-001", inst_03, inst_03, extra_sav=1000.0, tag="weekly_fri"))

        # --- KOL-02-002 (Weekly 24W Friday group, ₦5,000/wk, disb 2026-10-30) ---
        inst_04 = float(clients["KOL-02-002"]["setup"]["loan_repayment"])  # 5,000.0
        for dt_w in (date(2026, 11, 6), date(2026, 11, 13), date(2026, 11, 20)):
            add_action(dt_w, _make_rep_fn("KOL-02-002", inst_04, inst_04, tag="weekly_24w"))

        # --- KOL-03-001 (Weekly 12W Monday group, ₦8,250/wk, disb 2026-10-19) ---
        # Paid Wk 1..3 (Oct 26, Nov 2, Nov 9); Missed Wk 4 (Nov 16) & Wk 5 (Nov 23) -> ₦16,500 Weekly Overdue!
        inst_05 = float(clients["KOL-03-001"]["setup"]["loan_repayment"])  # 8,250.0
        for dt_w in (date(2026, 10, 26), date(2026, 11, 2), date(2026, 11, 9)):
            add_action(dt_w, _make_rep_fn("KOL-03-001", inst_05, inst_05, tag="weekly_mon"))
        for dt_w_miss in (date(2026, 11, 16), date(2026, 11, 23)):
            add_action(dt_w_miss, _make_rep_fn("KOL-03-001", 0.0, inst_05, mark_not_paid=True, tag="weekly_miss"))

        # --- KOL-04-001 (Monthly 3M, ₦50,000/mo, disb 2026-10-27 -> Month 1 due 2026-11-27 Friday) ---

        # Treasury: Bank Deposits & Office Expense (keep vault cash positive & realistic)
        add_action(
            date(2026, 11, 20),
            lambda d: TreasuryService.post_treasury_transaction(
                uow,
                tx_type="BANK_DEPOSIT",
                amount=350000.0,
                branch=KOLA_BRANCH_NAME,
                officer=BM_USERNAME,
                reference="BNK-KOL-001",
                remarks="Mid-cycle surplus vault cash banked to Zenith Bank",
                posting_date=d,
            ),
        )
        add_action(
            date(2026, 11, 24),
            lambda d: TreasuryService.post_treasury_transaction(
                uow,
                tx_type="OFFICE_EXPENSE",
                amount=4500.0,
                branch=KOLA_BRANCH_NAME,
                officer=BM_USERNAME,
                reference="EXP-KOL-001",
                remarks="Generator fuel & client passbook stationery",
                posting_date=d,
            ),
        )
        add_action(
            date(2026, 11, 25),
            lambda d: TreasuryService.post_treasury_transaction(
                uow,
                tx_type="BANK_DEPOSIT",
                amount=450000.0,
                branch=KOLA_BRANCH_NAME,
                officer=BM_USERNAME,
                reference="BNK-KOL-002",
                remarks="Wednesday pre-Friday safe sweep to bank",
                posting_date=d,
            ),
        )

        # Replay all days chronologically
        print("[4/6] Replaying chronological branch operations, ledger entries & cashbooks...")
        sorted_days = sorted(day_actions.keys())
        last_hist_day = sorted_days[-1]
        for day_dt in sorted_days:
            BusinessDateService.set_business_date(uow, KOLA_BRANCH_ID, day_dt)
            for _, act in day_actions[day_dt]:
                act(day_dt)

            if day_dt == date(2026, 11, 25):
                # Evaluate 3-default rule so KOL-01-002 cleanly becomes Defaulter via domain service
                ScheduleService.evaluate_branch_defaults(uow, branch_id=KOLA_BRANCH_ID, actor_id=BM_ID)

            CoCashbookProjectionBuilder.rebuild_co_projection(uow, KOLA_BRANCH_ID, CO1_ID, day_dt)
            MasterCashbookProjectionBuilder.rebuild_master_projection(uow, KOLA_BRANCH_ID, day_dt)
            BusinessDateService.close_business_date(
                uow,
                KOLA_BRANCH_ID,
                day_dt,
                closed_by=BM_USERNAME,
                notes=f"Kola Branch EOD reconciled for {day_dt.isoformat()}",
            )

        print("[5/6] Syncing timestamps, creating Pending Withdrawal Request & AM confirmations...")
        _sync_kola_timestamps_to_posting_date(uow)

        # Remove any auto-opened intermediate Open master_cashbook rows on skipped gap days before opening Friday PRESENTATION_DATE
        uow.client.table("master_cashbook").delete().eq("branch_id", KOLA_BRANCH_ID).eq("status", "Open").execute()

        # Recompute true Account 1000 balance across all Kola ledger entries
        gl_rows = (
            uow.client.table("financial_ledger_entries")
            .select("side, amount")
            .eq("branch_id", KOLA_BRANCH_ID)
            .eq("account_code", "1000")
            .execute()
            .data
            or []
        )
        acct_1000_bal = round(
            sum(float(r["amount"]) for r in gl_rows if r.get("side") == "Debit")
            - sum(float(r["amount"]) for r in gl_rows if r.get("side") == "Credit"),
            2,
        )

        # Update earlier area_eod_confirmations as AREA_LOCKED by AM_Area_1, keep 2026-11-25 PENDING for live AM demo!
        mb_25_res = (
            uow.client.table("master_cashbook")
            .select("closing_balance")
            .eq("branch_id", KOLA_BRANCH_ID)
            .eq("date", "2026-11-25")
            .execute()
            .data
            or []
        )
        mb_25_close = float(mb_25_res[0]["closing_balance"]) if mb_25_res else acct_1000_bal
        for d_dt in sorted_days:
            if d_dt < date(2026, 11, 25):
                uow.client.table("area_eod_confirmations").update(
                    {
                        "status": "AREA_LOCKED",
                        "confirmed_by": "Mrs. Shobande",
                        "confirmed_at": f"{d_dt.isoformat()}T18:30:00+00:00",
                        "notes": f"Kola Zone Daily Operations Locked and Sealed by AM Mrs. Shobande ({d_dt.isoformat()}).",
                    }
                ).eq("branch_id", KOLA_BRANCH_ID).eq("closure_date", d_dt.isoformat()).execute()
            else:
                uow.client.table("area_eod_confirmations").update(
                    {
                        "status": "PENDING",
                        "confirmed_by": None,
                        "confirmed_at": None,
                        "acct_1000_balance": acct_1000_bal,
                        "cash_variance": round(mb_25_close - acct_1000_bal, 2),
                        "notes": f"Branch EOD closed. Vault GL balance: ₦{acct_1000_bal:,.2f} — awaiting Area Manager sign-off.",
                    }
                ).eq("branch_id", KOLA_BRANCH_ID).eq("closure_date", d_dt.isoformat()).execute()

        # Open Friday 2026-11-27 cashbooks + business_date cleanly preserving projection carry-forward
        BusinessDateService.set_business_date(uow, KOLA_BRANCH_ID, PRESENTATION_DATE)
        CoCashbookProjectionBuilder.rebuild_co_projection(uow, KOLA_BRANCH_ID, CO1_ID, PRESENTATION_DATE)
        MasterCashbookProjectionBuilder.rebuild_master_projection(uow, KOLA_BRANCH_ID, PRESENTATION_DATE)

        # Pending Individual Withdrawal Request for Mrs. Chinyere Okafor (ready for BM 4-Eyes Approval)
        chinyere = clients["KOL-02-001"]
        uow.client.table("withdrawal_requests").upsert(
            {
                "id": det_id("wr_pending_chinyere"),
                "savings_type": "Individual",
                "operation_type": "Withdrawal",
                "client_id": chinyere["client_id"],
                "client_name": chinyere["name"],
                "group_name": chinyere["group_name"],
                "group_id": chinyere["group_id"],
                "loan_id": chinyere["loan_id"],
                "branch_id": KOLA_BRANCH_ID,
                "officer_id": CO1_ID,
                "requested_by": CO1_USERNAME,
                "amount": 5000.0,
                "reference": "WTH-KOL-001",
                "remarks": "School fees partial personal savings withdrawal",
                "payout_method": "Cash",
                "status": "PENDING",
                "operational_date": PRESENTATION_DATE.isoformat(),
                "idempotency_key": det_id("idem_wr_pending_chinyere"),
            },
            on_conflict="id",
        ).execute()

        # Verify Integrity
        print("[6/6] Running Integrity & Reconciliation Verification...")
        all_gl = (
            uow.client.table("financial_ledger_entries")
            .select("side, amount")
            .eq("branch_id", KOLA_BRANCH_ID)
            .execute()
            .data
            or []
        )
        total_dr = round(sum(float(r["amount"]) for r in all_gl if r.get("side") == "Debit"), 2)
        total_cr = round(sum(float(r["amount"]) for r in all_gl if r.get("side") == "Credit"), 2)
        assert abs(total_dr - total_cr) < 0.01, f"Ledger unbalanced: DR={total_dr}, CR={total_cr}"

        recon_last = DailyReconciliationService.reconcile_branch_day(uow, KOLA_BRANCH_ID, date(2026, 11, 25))
        after_ogijo = _snapshot_ogijo(uow)
        assert before_ogijo == after_ogijo, f"Ogijo modified! Before={before_ogijo}, After={after_ogijo}"

        print("\n=== KOLA SIMULATION COMPLETE ===")
        print(f"Branch: {KOLA_BRANCH_NAME} ({KOLA_BRANCH_ID}) | Active Business Date: {PRESENTATION_DATE.isoformat()}")
        print(f"Credentials -> CO: {CO1_USERNAME} / {DEMO_PASSWORD} | BM: {BM_USERNAME} / {DEMO_PASSWORD}")
        print(f"Double-Entry Ledger: DR=₦{total_dr:,.2f} == CR=₦{total_cr:,.2f}")
        print(f"Account 1000 Vault Cash Carry-Forward: ₦{acct_1000_bal:,.2f}")
        print(f"2026-11-25 3-Way Recon: GL Net=₦{recon_last['gl_net_flow']:,.2f}, MB Net=₦{recon_last['master_cashbook_net_flow']:,.2f}")
        print(f"Ogijo Unchanged Verified: {after_ogijo}")


if __name__ == "__main__":
    main()
