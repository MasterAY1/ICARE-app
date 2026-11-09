"""
ICARE Core Banking — Ibadan Branch Simulation Generator & Validator
Simulates complete branch data for Ibadan (IBA) branch:
- 1 BM, 2 COs (CO1 Daily, CO2 Weekly/Monthly)
- 5 Groups
- 20 Clients across 6 Lifecycle Statuses
- Loans with exact LoanProductEngine active credit (99k/96k per 100k) and rounded installments
- Amortization schedules in loan_schedule
- Historical repayments & loan_payoff_excess_records
- Savings: individual_savings, group_savings, laps_savings
- Account 1000 balanced ledger postings (opening vault cash: NGN 350,000.00)
- Fully idempotent using deterministic UUID5 and ON CONFLICT handling (Zero DELETE statements)
"""
import uuid
from datetime import date, datetime, timedelta
import json
import sys
import os

# Add root directory to path to import LoanProductEngine
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))
from services.loan_product_engine import LoanProductEngine

BRANCH_ID = "7ca8250a-9077-4bef-8cf3-78cf26c30705" # Ibadan
BRANCH_CODE = "IBA"
BRANCH_NAME = "Ibadan"
NAMESPACE = uuid.UUID(BRANCH_ID)

BM_ROLE_ID = "3ea1496a-0498-4a1d-872a-1c7ecdf77b06"
CO_ROLE_ID = "bd8790ee-c0eb-485a-8b6a-93f54519965d"
AM_USER_ID = "e6a77cdb-6012-4506-8240-7e46e81d954d" # AM_Area_1

# Product UUIDs
PROD_DAILY_60D = "2493f7d4-82d3-4004-8f67-537e6eb880dd"
PROD_DAILY_120D = "c41b5775-6e19-4302-bd42-c14342f52592"
PROD_WEEKLY_12W = "d466e92b-d35f-46b2-acdb-2c55aabf9fb3"
PROD_WEEKLY_24W = "c090f418-d2c1-4855-ab87-88e25589c471"
PROD_MONTHLY_3M = "b788e502-3787-4d51-8eb7-0ac9ea88c7a9"
PROD_MONTHLY_6M = "7cb6379d-43e7-4984-9223-1f45aee6e3ab"

# Client Status UUIDs
STATUS_REGISTERED = "11111111-1111-1111-1111-111111110001"
STATUS_PENDING_LOAN = "11111111-1111-1111-1111-111111110002"
STATUS_ON_LOAN = "11111111-1111-1111-1111-111111110003"
STATUS_COMPLETED = "11111111-1111-1111-1111-111111110004"
STATUS_INACTIVE_SAVINGS = "11111111-1111-1111-1111-111111110006"
STATUS_DEFAULTER = "11111111-1111-1111-1111-111111110009"

# Staff Users
BM_ID = "7ca80001-9077-4bef-8cf3-78cf26c30705"
CO1_ID = "7ca80002-9077-4bef-8cf3-78cf26c30705"
CO2_ID = "7ca80003-9077-4bef-8cf3-78cf26c30705"
PASSWORD_HASH = "$2b$12$YHMh.p8FjAiY6tp86aFAYun2GaY.0pfCh7qKbvh5TuHuuWA6LF7cK"

# Groups
GROUP_1_ID = "7ca80011-9077-4bef-8cf3-78cf26c30705" # Bodija Daily
GROUP_2_ID = "7ca80012-9077-4bef-8cf3-78cf26c30705" # Dugbe Daily
GROUP_3_ID = "7ca80013-9077-4bef-8cf3-78cf26c30705" # Mokola Weekly (Tue)
GROUP_4_ID = "7ca80014-9077-4bef-8cf3-78cf26c30705" # Challenge Weekly (Thu)
GROUP_5_ID = "7ca80015-9077-4bef-8cf3-78cf26c30705" # Ring Road Monthly

GROUPS_DATA = [
    {"id": GROUP_1_ID, "name": "Ibadan Bodija Daily Market Group", "cycle": "Daily", "day": "Daily", "officer": CO1_ID, "num": "1", "leader": "Adebayo Ojo"},
    {"id": GROUP_2_ID, "name": "Ibadan Dugbe Daily Artisans Group", "cycle": "Daily", "day": "Daily", "officer": CO1_ID, "num": "2", "leader": "Rasheedat Bello"},
    {"id": GROUP_3_ID, "name": "Ibadan Mokola Weekly Traders", "cycle": "Weekly", "day": "Tuesday", "officer": CO2_ID, "num": "3", "leader": "Funmilayo Lawal"},
    {"id": GROUP_4_ID, "name": "Ibadan Challenge Weekly Unity", "cycle": "Weekly", "day": "Thursday", "officer": CO2_ID, "num": "4", "leader": "Kehinde Ogundele"},
    {"id": GROUP_5_ID, "name": "Ibadan Ring Road Monthly Enterprise", "cycle": "Monthly", "day": "Monthly", "officer": CO2_ID, "num": "5", "leader": "Olumide Bakare"},
]

CLIENTS_DATA = [
    # Group 1: Bodija Daily (CO1)
    {"seq": "001", "name": "Adebayo Ojo", "gender": "Male", "phone": "08031110001", "group_id": GROUP_1_ID, "officer_id": CO1_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 15000.0, "loan": {"prod": PROD_DAILY_60D, "prod_name": "Daily 60 Days", "amount": 100000.0, "disb_date": "2026-10-12", "start_date": "2026-10-13", "paid_installments": 20}},
    {"seq": "002", "name": "Kudirat Salami", "gender": "Female", "phone": "08031110002", "group_id": GROUP_1_ID, "officer_id": CO1_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 8500.0, "loan": {"prod": PROD_DAILY_120D, "prod_name": "Daily 120 Days", "amount": 100000.0, "disb_date": "2026-10-12", "start_date": "2026-10-13", "paid_installments": 20}},
    {"seq": "003", "name": "Taofeek Sanusi", "gender": "Male", "phone": "08031110003", "group_id": GROUP_1_ID, "officer_id": CO1_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 12000.0, "loan": {"prod": PROD_DAILY_60D, "prod_name": "Daily 60 Days", "amount": 50000.0, "disb_date": "2026-10-12", "start_date": "2026-10-13", "paid_installments": 20}},
    {"seq": "004", "name": "Morufat Balogun", "gender": "Female", "phone": "08031110004", "group_id": GROUP_1_ID, "officer_id": CO1_ID, "status": "Completed", "status_id": STATUS_COMPLETED, "savings": 22000.0, "loan": {"prod": PROD_DAILY_60D, "prod_name": "Daily 60 Days", "amount": 100000.0, "disb_date": "2026-08-10", "start_date": "2026-08-11", "paid_installments": 60, "is_completed": True}},
    {"seq": "005", "name": "Zainab Jimoh", "gender": "Female", "phone": "08031110005", "group_id": GROUP_1_ID, "officer_id": CO1_ID, "status": "Registered", "status_id": STATUS_REGISTERED, "savings": 5000.0, "loan": None},
    
    # Group 2: Dugbe Daily (CO1)
    {"seq": "001", "name": "Rasheedat Bello", "gender": "Female", "phone": "08031110006", "group_id": GROUP_2_ID, "officer_id": CO1_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 18000.0, "loan": {"prod": PROD_DAILY_60D, "prod_name": "Daily 60 Days", "amount": 150000.0, "disb_date": "2026-10-12", "start_date": "2026-10-13", "paid_installments": 20}},
    {"seq": "002", "name": "Ganiyu Ajayi", "gender": "Male", "phone": "08031110007", "group_id": GROUP_2_ID, "officer_id": CO1_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 9000.0, "loan": {"prod": PROD_DAILY_120D, "prod_name": "Daily 120 Days", "amount": 100000.0, "disb_date": "2026-10-12", "start_date": "2026-10-13", "paid_installments": 20}},
    {"seq": "003", "name": "Bolanle Shittu", "gender": "Female", "phone": "08031110008", "group_id": GROUP_2_ID, "officer_id": CO1_ID, "status": "Defaulter", "status_id": STATUS_DEFAULTER, "savings": 3500.0, "loan": {"prod": PROD_DAILY_60D, "prod_name": "Daily 60 Days", "amount": 100000.0, "disb_date": "2026-10-12", "start_date": "2026-10-13", "paid_installments": 17, "missed_installments": 3}},
    {"seq": "004", "name": "Sulaimon Adeleke", "gender": "Male", "phone": "08031110009", "group_id": GROUP_2_ID, "officer_id": CO1_ID, "status": "Inactive (Savings Only)", "status_id": STATUS_INACTIVE_SAVINGS, "savings": 35000.0, "loan": None},
    
    # Group 3: Mokola Weekly - Tuesday (CO2)
    {"seq": "001", "name": "Funmilayo Lawal", "gender": "Female", "phone": "08031110010", "group_id": GROUP_3_ID, "officer_id": CO2_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 14000.0, "loan": {"prod": PROD_WEEKLY_12W, "prod_name": "Weekly 12W", "amount": 100000.0, "disb_date": "2026-10-12", "start_date": "2026-10-13", "paid_installments": 4}},
    {"seq": "002", "name": "Musibau Alao", "gender": "Male", "phone": "08031110011", "group_id": GROUP_3_ID, "officer_id": CO2_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 11000.0, "loan": {"prod": PROD_WEEKLY_24W, "prod_name": "Weekly 24W", "amount": 100000.0, "disb_date": "2026-10-12", "start_date": "2026-10-13", "paid_installments": 4}},
    {"seq": "003", "name": "Bisi Adeleke", "gender": "Female", "phone": "08031110012", "group_id": GROUP_3_ID, "officer_id": CO2_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 16500.0, "loan": {"prod": PROD_WEEKLY_12W, "prod_name": "Weekly 12W", "amount": 200000.0, "disb_date": "2026-10-12", "start_date": "2026-10-13", "paid_installments": 4}},
    {"seq": "004", "name": "Idris Oladipo", "gender": "Male", "phone": "08031110013", "group_id": GROUP_3_ID, "officer_id": CO2_ID, "status": "Completed", "status_id": STATUS_COMPLETED, "savings": 28000.0, "loan": {"prod": PROD_WEEKLY_12W, "prod_name": "Weekly 12W", "amount": 100000.0, "disb_date": "2026-07-20", "start_date": "2026-07-21", "paid_installments": 12, "is_completed": True}},
    
    # Group 4: Challenge Weekly - Thursday (CO2)
    {"seq": "001", "name": "Kehinde Ogundele", "gender": "Male", "phone": "08031110014", "group_id": GROUP_4_ID, "officer_id": CO2_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 19000.0, "loan": {"prod": PROD_WEEKLY_12W, "prod_name": "Weekly 12W", "amount": 100000.0, "disb_date": "2026-10-19", "start_date": "2026-10-22", "paid_installments": 3}},
    {"seq": "002", "name": "Taiwo Ogundele", "gender": "Male", "phone": "08031110015", "group_id": GROUP_4_ID, "officer_id": CO2_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 19000.0, "loan": {"prod": PROD_WEEKLY_24W, "prod_name": "Weekly 24W", "amount": 150000.0, "disb_date": "2026-10-19", "start_date": "2026-10-22", "paid_installments": 3}},
    {"seq": "003", "name": "Khadijat Mustapha", "gender": "Female", "phone": "08031110016", "group_id": GROUP_4_ID, "officer_id": CO2_ID, "status": "Registered", "status_id": STATUS_REGISTERED, "savings": 6000.0, "loan": None},
    {"seq": "004", "name": "Shukurat Babalola", "gender": "Female", "phone": "08031110017", "group_id": GROUP_4_ID, "officer_id": CO2_ID, "status": "Pending Loan", "status_id": STATUS_PENDING_LOAN, "savings": 10000.0, "loan": {"prod": PROD_WEEKLY_12W, "prod_name": "Weekly 12W", "amount": 100000.0, "disb_date": "2026-11-09", "start_date": "2026-11-12", "is_pending": True}},
    
    # Group 5: Ring Road Monthly (CO2)
    {"seq": "001", "name": "Olumide Bakare", "gender": "Male", "phone": "08031110018", "group_id": GROUP_5_ID, "officer_id": CO2_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 45000.0, "loan": {"prod": PROD_MONTHLY_3M, "prod_name": "Monthly 3M", "amount": 300000.0, "disb_date": "2026-09-01", "start_date": "2026-10-01", "paid_installments": 2}},
    {"seq": "002", "name": "Folake Adeyemi", "gender": "Female", "phone": "08031110019", "group_id": GROUP_5_ID, "officer_id": CO2_ID, "status": "On Loan", "status_id": STATUS_ON_LOAN, "savings": 50000.0, "loan": {"prod": PROD_MONTHLY_6M, "prod_name": "Monthly 6M", "amount": 100000.0, "disb_date": "2026-08-03", "start_date": "2026-09-03", "paid_installments": 3}},
    {"seq": "003", "name": "Babatunde Awolowo", "gender": "Male", "phone": "08031110020", "group_id": GROUP_5_ID, "officer_id": CO2_ID, "status": "Inactive (Savings Only)", "status_id": STATUS_INACTIVE_SAVINGS, "savings": 60000.0, "loan": None},
]

def generate_simulation():
    part1_statements = [] # Users, roles, AM assignment, groups
    part2_statements = [] # Clients, memberships, savings, withdrawal request
    part3_statements = [] # Loans, loan_schedule, repayments, payoff excess records
    part4_statements = [] # Financial ledger entries, master_cashbook
    
    # -------------------------------------------------------------------------
    # PART 1: USERS, ROLES, AM ASSIGNMENT, GROUPS
    # -------------------------------------------------------------------------
    extra_fields_json = json.dumps({
        "allowed_products": ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M"],
        "must_change_password": False,
        "mfa_enabled": False
    })
    part1_statements.append(f"""
    INSERT INTO app_users (id, username, password_hash, full_name, branch_id, is_active, is_deleted, created_at, updated_at, extra_fields)
    VALUES 
        ('{BM_ID}', 'BM_Ibadan', '{PASSWORD_HASH}', 'Ibrahim Babatunde', '{BRANCH_ID}', true, false, NOW(), NOW(), '{extra_fields_json}'::jsonb),
        ('{CO1_ID}', 'IBA_CO1', '{PASSWORD_HASH}', 'Kazeem Adeleke (Daily)', '{BRANCH_ID}', true, false, NOW(), NOW(), '{extra_fields_json}'::jsonb),
        ('{CO2_ID}', 'IBA_CO2', '{PASSWORD_HASH}', 'Folashade Alabi (Weekly/Monthly)', '{BRANCH_ID}', true, false, NOW(), NOW(), '{extra_fields_json}'::jsonb)
    ON CONFLICT (id) DO UPDATE SET 
        password_hash = EXCLUDED.password_hash,
        full_name = EXCLUDED.full_name,
        branch_id = EXCLUDED.branch_id,
        is_active = true,
        extra_fields = EXCLUDED.extra_fields;
    """.strip())
    
    part1_statements.append(f"""
    INSERT INTO user_roles (user_id, role_id)
    VALUES 
        ('{BM_ID}', '{BM_ROLE_ID}'),
        ('{CO1_ID}', '{CO_ROLE_ID}'),
        ('{CO2_ID}', '{CO_ROLE_ID}')
    ON CONFLICT DO NOTHING;
    """.strip())
    
    part1_statements.append(f"""
    INSERT INTO area_manager_assignments (am_id, branch_id)
    VALUES ('{AM_USER_ID}', '{BRANCH_ID}')
    ON CONFLICT DO NOTHING;
    """.strip())
    
    for g in GROUPS_DATA:
        part1_statements.append(f"""
        INSERT INTO groups (group_id, name, meeting_day, branch_id, officer_id, status, group_number, current_member_sequence, leader_name, created_at, updated_at, version, is_deleted)
        VALUES ('{g["id"]}', '{g["name"]}', '{g["day"]}', '{BRANCH_ID}', '{g["officer"]}', 'Active', '{g["num"]}', 5, '{g["leader"]}', NOW(), NOW(), 1, false)
        ON CONFLICT (group_id) DO UPDATE SET
            name = EXCLUDED.name,
            meeting_day = EXCLUDED.meeting_day,
            officer_id = EXCLUDED.officer_id,
            status = 'Active';
        """.strip())

    # -------------------------------------------------------------------------
    # PART 2: CLIENTS, MEMBERSHIPS, SAVINGS, WITHDRAWALS
    # -------------------------------------------------------------------------
    client_uuids = {}
    total_individual_savings = 0.0
    total_group_savings = 0.0
    total_laps_savings = 0.0
    
    for c in CLIENTS_DATA:
        g_obj = next(g for g in GROUPS_DATA if g["id"] == c["group_id"])
        g_num = g_obj["num"].zfill(2)
        c_code = f"{BRANCH_CODE}-{g_num}-{c['seq']}"
        c_id = str(uuid.uuid5(NAMESPACE, f"client_{c_code}"))
        client_uuids[c["name"]] = c_id
        
        part2_statements.append(f"""
        INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('{c_id}', '{c["name"]}', '{c["phone"]}', 'Ibadan, Oyo State', 'General Commerce', '{c_code}', '2026-08-01', '{BRANCH_ID}', '{c["group_id"]}', '{c["officer_id"]}', '{c["status"]}', '{c["status_id"]}', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;
        """.strip())
        
        m_id = str(uuid.uuid5(NAMESPACE, f"membership_{c_code}"))
        part2_statements.append(f"""
        INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('{m_id}', '{c_id}', '{c["group_id"]}', '{BRANCH_ID}', '{c["officer_id"]}', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;
        """.strip())
        
        if c.get("savings", 0.0) > 0:
            s_id = str(uuid.uuid5(NAMESPACE, f"ind_savings_{c_code}"))
            sav_amt = float(c["savings"])
            total_individual_savings += sav_amt
            part2_statements.append(f"""
            INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('{s_id}', '2026-10-01', '{c_id}', '{BRANCH_ID}', '{c["officer_id"]}', {sav_amt}, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;
            """.strip())
            
        if c["name"] == "Sulaimon Adeleke":
            w_id = str(uuid.uuid5(NAMESPACE, f"wth_req_{c_code}"))
            part2_statements.append(f"""
            INSERT INTO withdrawal_requests (id, savings_type, operation_type, client_id, client_name, group_name, loan_id, branch_id, requested_by, amount, reference, remarks, payout_method, status, operational_date, created_at)
            VALUES ('{w_id}', 'Individual', 'Withdrawal', '{c_id}', 'Sulaimon Adeleke', '{g_obj["name"]}', NULL, '{BRANCH_ID}', 'IBA_CO1', 5000.00, 'WTH-IBA-001', 'Emergency medical expense request', 'Cash', 'Pending', '2026-11-06', NOW())
            ON CONFLICT (id) DO NOTHING;
            """.strip())

    for g in GROUPS_DATA:
        g_sav_id = str(uuid.uuid5(NAMESPACE, f"grp_savings_{g['num']}"))
        g_amt = 15000.0
        total_group_savings += g_amt
        part2_statements.append(f"""
        INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('{g_sav_id}', '2026-10-01', '{g["id"]}', '{BRANCH_ID}', '{g["officer"]}', {g_amt}, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN')
        ON CONFLICT (id) DO NOTHING;
        """.strip())
        
    for c in CLIENTS_DATA:
        if c.get("loan"):
            c_code = f"{BRANCH_CODE}-{next(g for g in GROUPS_DATA if g['id'] == c['group_id'])['num'].zfill(2)}-{c['seq']}"
            laps_id = str(uuid.uuid5(NAMESPACE, f"laps_savings_{c_code}"))
            l_amt = 2500.0
            total_laps_savings += l_amt
            part2_statements.append(f"""
            INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('{laps_id}', '2026-10-01', '{client_uuids[c["name"]]}', '{BRANCH_ID}', '{c["officer_id"]}', {l_amt}, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;
            """.strip())

    # -------------------------------------------------------------------------
    # PART 3: LOANS, SCHEDULES, REPAYMENTS, PAYOFF RECORDS
    # -------------------------------------------------------------------------
    total_disbursed = 0.0
    total_upfront_fees = 0.0
    total_repayments_collected = 0.0
    sched_tuples = []
    repay_tuples = []
    payoff_tuples = []
    
    for c in CLIENTS_DATA:
        l_info = c.get("loan")
        if not l_info:
            continue
            
        c_code = f"{BRANCH_CODE}-{next(g for g in GROUPS_DATA if g['id'] == c['group_id'])['num'].zfill(2)}-{c['seq']}"
        c_id = client_uuids[c["name"]]
        loan_id = str(uuid.uuid5(NAMESPACE, f"loan_{c_code}"))
        prod_name = l_info["prod_name"]
        principal = float(l_info["amount"])
        
        setup = LoanProductEngine.calculate_loan_setup(principal, prod_name)
        active_credit = float(setup["active_credit"])
        installment = float(setup["loan_repayment"])
        duration = int(setup["duration"])
        interest = float(setup["interest"])
        gap_fee = float(setup["gap_fee"])
        upfront_required = float(setup["total_upfront_required"])
        
        is_pending = l_info.get("is_pending", False)
        is_completed = l_info.get("is_completed", False)
        loan_status = "Pending" if is_pending else ("Completed" if is_completed else "Active")
        
        disb_date = l_info["disb_date"]
        start_date = l_info["start_date"]
        s_date_obj = date.fromisoformat(start_date)
        if "daily" in prod_name.lower():
            end_date_obj = s_date_obj + timedelta(days=int(duration * 1.5))
        elif "weekly" in prod_name.lower():
            end_date_obj = s_date_obj + timedelta(weeks=duration)
        else:
            end_date_obj = s_date_obj + timedelta(days=duration * 30)
            
        part3_statements.append(f"""
        INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('{loan_id}', '{c_id}', '{l_info["prod"]}', '{BRANCH_ID}', '{c["officer_id"]}', '{disb_date}', {principal}, {active_credit}, {installment}, {active_credit}, '{loan_status}', 'Finance', '{disb_date}', '{start_date}', '{end_date_obj.isoformat()}', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;
        """.strip())
        
        if not is_pending:
            total_disbursed += principal
            total_upfront_fees += upfront_required
            
            paid_count = l_info.get("paid_installments", 0)
            curr_date = s_date_obj
            day_increment = timedelta(days=1) if "daily" in prod_name.lower() else (timedelta(weeks=1) if "weekly" in prod_name.lower() else timedelta(days=30))
            
            for inst_no in range(1, duration + 1):
                if "daily" in prod_name.lower():
                    while curr_date.weekday() >= 5:
                        curr_date += timedelta(days=1)
                        
                sched_id = str(uuid.uuid5(NAMESPACE, f"sched_{c_code}_{inst_no}"))
                if inst_no <= paid_count:
                    s_status = "Paid"
                    p_date_str = f"'{curr_date.isoformat()}'"
                    p_amt = installment
                elif c["status"] == "Defaulter" and inst_no <= (paid_count + l_info.get("missed_installments", 0)):
                    s_status = "Overdue"
                    p_date_str = "NULL"
                    p_amt = 0.0
                else:
                    s_status = "Pending"
                    p_date_str = "NULL"
                    p_amt = 0.0
                    
                sched_tuple = f"('{sched_id}', '{loan_id}', {inst_no}, '{curr_date.isoformat()}', {installment}, 0.0, 0.0, {installment}, '{s_status}', {p_date_str}, {p_amt}, 1, NOW())"
                sched_tuples.append(sched_tuple)
                
                part3_statements.append(f"""
                INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES {sched_tuple}
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
                """.strip())
                
                if inst_no <= paid_count:
                    repay_id = str(uuid.uuid5(NAMESPACE, f"repay_{c_code}_{inst_no}"))
                    total_repayments_collected += installment
                    repay_tuple = f"('{repay_id}', '{curr_date.isoformat()} 10:00:00+00', '{loan_id}', '{c_id}', {installment}, '{c['officer_id']}', '{BRANCH_ID}', 'Installment #{inst_no} Collection', 'Cash', NOW())"
                    repay_tuples.append(repay_tuple)
                    part3_statements.append(f"""
                    INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES {repay_tuple}
                    ON CONFLICT (id) DO NOTHING;
                    """.strip())
                    
                    if is_completed and inst_no == duration:
                        payoff_id = str(uuid.uuid5(NAMESPACE, f"payoff_{c_code}"))
                        payoff_tuple = f"('{payoff_id}', '{repay_id}', '{loan_id}', '{c_id}', '{c['officer_id']}', '{BRANCH_ID}', '{curr_date.isoformat()}', 'FULL_PAYOFF', {installment}, {installment}, {active_credit}, 0.0, {installment}, 0.0, 'Full loan completion settlement', NOW())"
                        payoff_tuples.append(payoff_tuple)
                        part3_statements.append(f"""
                        INSERT INTO loan_payoff_excess_records (id, repayment_id, loan_id, client_id, officer_id, branch_id, date, record_type, amount_paid, expected_installment, active_credit_settled, excess_amount, remaining_balance_before, remaining_balance_after, notes, created_at)
                        VALUES {payoff_tuple}
                        ON CONFLICT (id) DO NOTHING;
                        """.strip())

                curr_date += day_increment

    # -------------------------------------------------------------------------
    # PART 4: GENERAL LEDGER (ACCOUNT 1000) & MASTER CASHBOOK
    # -------------------------------------------------------------------------
    total_savings_inflow = total_individual_savings + total_group_savings + total_laps_savings
    net_before_remit = 2000000.0 - total_disbursed + total_upfront_fees + total_repayments_collected + total_savings_inflow
    TARGET_VAULT = 350000.0
    remit_to_bank = net_before_remit - TARGET_VAULT
    
    # Capital Injection
    tx1 = str(uuid.uuid5(NAMESPACE, "tx_capital"))
    part4_statements.append(f"""
    INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('{uuid.uuid5(NAMESPACE, "entry_cap_dr")}', '{tx1}', '{BRANCH_ID}', '1000', 'Debit', 2000000.0, 'Capital', '{BRANCH_ID}', '2026-08-01 08:00:00+00'),
        ('{uuid.uuid5(NAMESPACE, "entry_cap_cr")}', '{tx1}', '{BRANCH_ID}', '3100', 'Credit', 2000000.0, 'Capital', '{BRANCH_ID}', '2026-08-01 08:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;
    """.strip())
    
    # Loan Disbursements
    tx2 = str(uuid.uuid5(NAMESPACE, "tx_disb"))
    part4_statements.append(f"""
    INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('{uuid.uuid5(NAMESPACE, "entry_disb_dr")}', '{tx2}', '{BRANCH_ID}', '1200', 'Debit', {total_disbursed}, 'Disbursement', '{BRANCH_ID}', '2026-10-12 09:00:00+00'),
        ('{uuid.uuid5(NAMESPACE, "entry_disb_cr")}', '{tx2}', '{BRANCH_ID}', '1000', 'Credit', {total_disbursed}, 'Disbursement', '{BRANCH_ID}', '2026-10-12 09:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;
    """.strip())
    
    # Upfront Fees
    tx3 = str(uuid.uuid5(NAMESPACE, "tx_fees"))
    part4_statements.append(f"""
    INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('{uuid.uuid5(NAMESPACE, "entry_fee_dr")}', '{tx3}', '{BRANCH_ID}', '1000', 'Debit', {total_upfront_fees}, 'FeeIncome', '{BRANCH_ID}', '2026-10-12 09:30:00+00'),
        ('{uuid.uuid5(NAMESPACE, "entry_fee_cr")}', '{tx3}', '{BRANCH_ID}', '3000', 'Credit', {total_upfront_fees}, 'FeeIncome', '{BRANCH_ID}', '2026-10-12 09:30:00+00')
    ON CONFLICT (entry_id) DO NOTHING;
    """.strip())
    
    # Repayments
    tx4 = str(uuid.uuid5(NAMESPACE, "tx_repay"))
    part4_statements.append(f"""
    INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('{uuid.uuid5(NAMESPACE, "entry_rep_dr")}', '{tx4}', '{BRANCH_ID}', '1000', 'Debit', {total_repayments_collected}, 'Repayment', '{BRANCH_ID}', '2026-11-06 16:00:00+00'),
        ('{uuid.uuid5(NAMESPACE, "entry_rep_cr")}', '{tx4}', '{BRANCH_ID}', '1200', 'Credit', {total_repayments_collected}, 'Repayment', '{BRANCH_ID}', '2026-11-06 16:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;
    """.strip())
    
    # Savings
    tx5 = str(uuid.uuid5(NAMESPACE, "tx_savings"))
    part4_statements.append(f"""
    INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('{uuid.uuid5(NAMESPACE, "entry_sav_dr")}', '{tx5}', '{BRANCH_ID}', '1000', 'Debit', {total_savings_inflow}, 'Savings', '{BRANCH_ID}', '2026-10-01 10:00:00+00'),
        ('{uuid.uuid5(NAMESPACE, "entry_sav_cr_ind")}', '{tx5}', '{BRANCH_ID}', '2000', 'Credit', {total_individual_savings}, 'Savings', '{BRANCH_ID}', '2026-10-01 10:00:00+00'),
        ('{uuid.uuid5(NAMESPACE, "entry_sav_cr_grp")}', '{tx5}', '{BRANCH_ID}', '2010', 'Credit', {total_group_savings}, 'Savings', '{BRANCH_ID}', '2026-10-01 10:00:00+00'),
        ('{uuid.uuid5(NAMESPACE, "entry_sav_cr_laps")}', '{tx5}', '{BRANCH_ID}', '2030', 'Credit', {total_laps_savings}, 'Savings', '{BRANCH_ID}', '2026-10-01 10:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;
    """.strip())
    
    # Bank Remittance
    tx6 = str(uuid.uuid5(NAMESPACE, "tx_remit"))
    part4_statements.append(f"""
    INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('{uuid.uuid5(NAMESPACE, "entry_remit_dr")}', '{tx6}', '{BRANCH_ID}', '1050', 'Debit', {remit_to_bank}, 'Remittance', '{BRANCH_ID}', '2026-11-06 17:00:00+00'),
        ('{uuid.uuid5(NAMESPACE, "entry_remit_cr")}', '{tx6}', '{BRANCH_ID}', '1000', 'Credit', {remit_to_bank}, 'Remittance', '{BRANCH_ID}', '2026-11-06 17:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;
    """.strip())
    
    # Master Cashbook Baseline
    cb_fri_id = str(uuid.uuid5(NAMESPACE, "cb_fri"))
    cb_mon_id = str(uuid.uuid5(NAMESPACE, "cb_mon"))
    part4_statements.append(f"""
    INSERT INTO master_cashbook (id, date, branch_id, opening_balance, total_inflows, total_outflows, closing_balance, status, version, created_at)
    VALUES 
        ('{cb_fri_id}', '2026-11-06', '{BRANCH_ID}', 0.0, {TARGET_VAULT}, 0.0, {TARGET_VAULT}, 'Closed', 1, '2026-11-06 18:00:00+00'),
        ('{cb_mon_id}', '2026-11-09', '{BRANCH_ID}', {TARGET_VAULT}, 0.0, 0.0, {TARGET_VAULT}, 'Open', 1, '2026-11-09 07:00:00+00')
    ON CONFLICT (id) DO UPDATE SET
        opening_balance = EXCLUDED.opening_balance,
        closing_balance = EXCLUDED.closing_balance,
        status = EXCLUDED.status;
    """.strip())

    out_dir = os.path.dirname(__file__)
    
    p1_path = os.path.join(out_dir, "ibadan_part1_users_groups.sql")
    with open(p1_path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(part1_statements))
        
    p2_path = os.path.join(out_dir, "ibadan_part2_clients_savings.sql")
    with open(p2_path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(part2_statements))
        
    p3_path = os.path.join(out_dir, "ibadan_part3_loans_schedules.sql")
    with open(p3_path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(part3_statements))
        
    p4_path = os.path.join(out_dir, "ibadan_part4_ledger_cashbook.sql")
    with open(p4_path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(part4_statements))
        
    print(f"Part 1 ({len(part1_statements)} stmts) -> {p1_path}")
    print(f"Part 2 ({len(part2_statements)} stmts) -> {p2_path}")
    print(f"Part 3 ({len(part3_statements)} stmts) -> {p3_path}")
    print(f"Part 4 ({len(part4_statements)} stmts) -> {p4_path}")

    # Write multi-row schedule batches (4 batches)
    batch_size = (len(sched_tuples) + 3) // 4
    for b_idx in range(4):
        batch = sched_tuples[b_idx*batch_size : (b_idx+1)*batch_size]
        stmt = (
            "INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)\n"
            "VALUES\n" + ",\n".join(batch) + "\n"
            "ON CONFLICT (id) DO UPDATE SET\n"
            "    status = EXCLUDED.status,\n"
            "    paid_date = EXCLUDED.paid_date,\n"
            "    paid_amount = EXCLUDED.paid_amount;"
        )
        p = os.path.join(out_dir, f"ibadan_step5_sched_batch{b_idx+1}.sql")
        with open(p, "w", encoding="utf-8") as f:
            f.write(stmt)
        print(f"Wrote {p} ({len(batch)} rows)")

    # Write repayments batches (2 batches)
    r_batch_size = (len(repay_tuples) + 1) // 2
    for b_idx in range(2):
        batch = repay_tuples[b_idx*r_batch_size : (b_idx+1)*r_batch_size]
        stmt = (
            "INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)\n"
            "VALUES\n" + ",\n".join(batch) + "\n"
            "ON CONFLICT (id) DO UPDATE SET\n"
            "    amount_paid = EXCLUDED.amount_paid;"
        )
        p = os.path.join(out_dir, f"ibadan_step6_repay_batch{b_idx+1}.sql")
        with open(p, "w", encoding="utf-8") as f:
            f.write(stmt)
        print(f"Wrote {p} ({len(batch)} rows)")

    # Write payoffs
    payoff_stmt = (
        "INSERT INTO loan_payoff_excess_records (id, repayment_id, loan_id, client_id, officer_id, branch_id, date, record_type, amount_paid, expected_installment, active_credit_settled, excess_amount, remaining_balance_before, remaining_balance_after, notes, created_at)\n"
        "VALUES\n" + ",\n".join(payoff_tuples) + "\n"
        "ON CONFLICT (id) DO UPDATE SET\n"
        "    amount_paid = EXCLUDED.amount_paid,\n"
        "    excess_amount = EXCLUDED.excess_amount;"
    )
    p = os.path.join(out_dir, "ibadan_step6_payoff.sql")
    with open(p, "w", encoding="utf-8") as f:
        f.write(payoff_stmt)
    print(f"Wrote {p} ({len(payoff_tuples)} rows)")

    # Write step 7 ledger & cashbook
    p_step7 = os.path.join(out_dir, "ibadan_step7_ledger_cashbook.sql")
    with open(p_step7, "w", encoding="utf-8") as f:
        f.write(";\n\n".join(part4_statements) + ";\n")
    print(f"Wrote {p_step7}")

if __name__ == "__main__":
    generate_simulation()
