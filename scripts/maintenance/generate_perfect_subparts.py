import os
import uuid
from datetime import date, datetime, timedelta

def run():
    NAMESPACE = uuid.UUID("7ca8250a-9077-4bef-8cf3-78cf26c30705")
    BRANCH_ID = "7ca8250a-9077-4bef-8cf3-78cf26c30705"
    CO1_ID = "7ca80002-9077-4bef-8cf3-78cf26c30705"
    CO2_ID = "7ca80003-9077-4bef-8cf3-78cf26c30705"

    PRODUCTS = {
        "D60": {"id": "2493f7d4-82d3-4004-8f67-537e6eb880dd", "type": "daily", "dur": 60, "rate": 0.12, "gap": 1000.0},
        "D120": {"id": "c41b5775-6e19-4302-bd42-c14342f52592", "type": "daily", "dur": 120, "rate": 0.21, "gap": 4000.0},
        "W12": {"id": "d466e92b-d35f-46b2-acdb-2c55aabf9fb3", "type": "weekly", "dur": 12, "rate": 0.12, "gap": 1000.0},
        "W24": {"id": "c090f418-d2c1-4855-ab87-88e25589c471", "type": "weekly", "dur": 24, "rate": 0.21, "gap": 4000.0},
        "M3": {"id": "b788e502-3787-4d51-8eb7-0ac9ea88c7a9", "type": "monthly", "dur": 3, "rate": 0.12, "gap": 0.0},
        "M6": {"id": "7cb6379d-43e7-4984-9223-1f45aee6e3ab", "type": "monthly", "dur": 6, "rate": 0.21, "gap": 400.0},
    }

    CLIENT_CONFIGS = [
        # Group 1 (Daily - CO 1)
        {"code": "CLI-IBA-001", "name": "Adewale Adeleke", "grp": 1, "off": CO1_ID, "p": "D60", "amt": 100000.0, "paid_pct": 0.333, "status": "On Loan"},
        {"code": "CLI-IBA-002", "name": "Bisi Akande", "grp": 1, "off": CO1_ID, "p": "D120", "amt": 100000.0, "paid_pct": 0.167, "status": "On Loan"},
        {"code": "CLI-IBA-003", "name": "Chidinma Okon", "grp": 1, "off": CO1_ID, "p": "D60", "amt": 50000.0, "paid_pct": 0.500, "status": "On Loan"},
        {"code": "CLI-IBA-004", "name": "Damilola Alabi", "grp": 1, "off": CO1_ID, "p": "D60", "amt": 100000.0, "paid_pct": 1.000, "status": "Completed"},
        # Group 2 (Daily - CO 1)
        {"code": "CLI-IBA-005", "name": "Ebenezer Ojo", "grp": 2, "off": CO1_ID, "p": "D60", "amt": 150000.0, "paid_pct": 0.250, "status": "On Loan"},
        {"code": "CLI-IBA-006", "name": "Folake Balogun", "grp": 2, "off": CO1_ID, "p": "D120", "amt": 100000.0, "paid_pct": 0.083, "status": "On Loan"},
        {"code": "CLI-IBA-007", "name": "Gboyega Famakin", "grp": 2, "off": CO1_ID, "p": "D60", "amt": 100000.0, "paid_pct": 0.600, "status": "On Loan"},
        {"code": "CLI-IBA-008", "name": "Hauwa Garba", "grp": 2, "off": CO1_ID, "p": None, "amt": 0.0, "paid_pct": 0.0, "status": "Inactive (Savings Only)"},
        # Group 3 (Weekly - CO 2)
        {"code": "CLI-IBA-009", "name": "Ibrahim Danjuma", "grp": 3, "off": CO2_ID, "p": "W12", "amt": 100000.0, "paid_pct": 0.333, "status": "On Loan"},
        {"code": "CLI-IBA-010", "name": "Jumoke Soyinka", "grp": 3, "off": CO2_ID, "p": "W24", "amt": 100000.0, "paid_pct": 0.167, "status": "On Loan"},
        {"code": "CLI-IBA-011", "name": "Kehinde Ogundipe", "grp": 3, "off": CO2_ID, "p": "W12", "amt": 200000.0, "paid_pct": 0.500, "status": "On Loan"},
        {"code": "CLI-IBA-012", "name": "Lateef Adebayo", "grp": 3, "off": CO2_ID, "p": "W12", "amt": 100000.0, "paid_pct": 1.000, "status": "Completed"},
        # Group 4 (Weekly - CO 2)
        {"code": "CLI-IBA-013", "name": "Modupeola Fagbemi", "grp": 4, "off": CO2_ID, "p": "W12", "amt": 100000.0, "paid_pct": 0.250, "status": "On Loan"},
        {"code": "CLI-IBA-014", "name": "Nafisat Bello", "grp": 4, "off": CO2_ID, "p": "W24", "amt": 150000.0, "paid_pct": 0.125, "status": "On Loan"},
        {"code": "CLI-IBA-015", "name": "Oluwaseun Bakare", "grp": 4, "off": CO2_ID, "p": "W12", "amt": 100000.0, "paid_pct": 0.0, "status": "Registered"}, # Pending loan
        {"code": "CLI-IBA-016", "name": "Peter Obioma", "grp": 4, "off": CO2_ID, "p": None, "amt": 0.0, "paid_pct": 0.0, "status": "Dormant"},
        # Group 5 (Monthly - CO 2)
        {"code": "CLI-IBA-017", "name": "Quadri Salami", "grp": 5, "off": CO2_ID, "p": "M3", "amt": 300000.0, "paid_pct": 0.667, "status": "On Loan"},
        {"code": "CLI-IBA-018", "name": "Rashida Aliyu", "grp": 5, "off": CO2_ID, "p": "M6", "amt": 100000.0, "paid_pct": 0.333, "status": "On Loan"},
        {"code": "CLI-IBA-019", "name": "Sulaimon Adeleke", "grp": 5, "off": CO2_ID, "p": None, "amt": 0.0, "paid_pct": 0.0, "status": "Inactive (Savings Only)"},
        {"code": "CLI-IBA-020", "name": "Taiwo Bankole", "grp": 5, "off": CO2_ID, "p": None, "amt": 0.0, "paid_pct": 0.0, "status": "Closed"},
    ]

    total_disbursed = 0.0
    total_upfront_fees = 0.0
    total_repayments_collected = 0.0
    
    sched_values = []
    repay_values = []
    payoff_values = []

    for c in CLIENT_CONFIGS:
        c_code = c["code"]
        c_id = str(uuid.uuid5(NAMESPACE, f"client_{c_code}"))
        
        if c["amt"] > 0:
            p_code = c["p"]
            p_cfg = PRODUCTS[p_code]
            p_id = p_cfg["id"]
            amt = c["amt"]
            dur = p_cfg["dur"]
            rate = p_cfg["rate"]
            gap = p_cfg["gap"]
            is_completed = (c["status"] == "Completed")
            is_pending = (c["status"] == "Registered")

            # Active credit formula
            if amt == 100000.0:
                active_credit = amt - gap
            elif amt == 50000.0:
                active_credit = 48000.0
            elif amt == 150000.0:
                active_credit = 150000.0
            elif amt == 200000.0:
                active_credit = 198000.0
            elif amt == 300000.0:
                active_credit = 300000.0
            else:
                active_credit = amt

            installment = round(active_credit / dur, -1)
            active_credit = installment * dur

            # Dates
            if is_completed:
                if p_cfg["type"] == "daily":
                    disb_date = date(2026, 8, 10)
                    start_date = date(2026, 8, 11)
                else:
                    disb_date = date(2026, 7, 20)
                    start_date = date(2026, 7, 21)
            elif is_pending:
                disb_date = date(2026, 11, 9)
                start_date = date(2026, 11, 12)
            else:
                if p_cfg["type"] == "monthly":
                    if dur == 3:
                        disb_date = date(2026, 9, 1)
                        start_date = date(2026, 10, 1)
                    else:
                        disb_date = date(2026, 8, 3)
                        start_date = date(2026, 9, 3)
                elif c["grp"] == 4:
                    disb_date = date(2026, 10, 19)
                    start_date = date(2026, 10, 22)
                else:
                    disb_date = date(2026, 10, 12)
                    start_date = date(2026, 10, 13)

            paid_count = dur if is_completed else (0 if is_pending else int(round(dur * c["paid_pct"])))
            loan_id = str(uuid.uuid5(NAMESPACE, f"loan_{c_code}"))

            if not is_pending:
                total_disbursed += amt
                upfront_fee = (amt * rate) + gap
                total_upfront_fees += upfront_fee

            # Amortization schedules & repayments
            curr_date = start_date
            if p_cfg["type"] == "daily":
                day_increment = timedelta(days=1)
            elif p_cfg["type"] == "weekly":
                day_increment = timedelta(weeks=1)
            else:
                day_increment = timedelta(days=30)

            for inst_no in range(1, dur + 1):
                sched_id = str(uuid.uuid5(NAMESPACE, f"sched_{c_code}_{inst_no}"))
                if inst_no <= paid_count:
                    s_status = "Paid"
                    p_date_str = f"'{curr_date.isoformat()}'"
                    p_amt = installment
                else:
                    s_status = "Pending"
                    p_date_str = "NULL"
                    p_amt = 0.0

                sched_values.append(
                    f"('{sched_id}', '{loan_id}', {inst_no}, '{curr_date.isoformat()}', {installment}, 0.0, 0.0, {installment}, '{s_status}', {p_date_str}, {p_amt}, 1, NOW())"
                )

                if inst_no <= paid_count:
                    repay_id = str(uuid.uuid5(NAMESPACE, f"repay_{c_code}_{inst_no}"))
                    total_repayments_collected += installment
                    repay_values.append(
                        f"('{repay_id}', '{curr_date.isoformat()} 10:00:00+00', '{loan_id}', '{c_id}', {installment}, '{c['off']}', '{BRANCH_ID}', 'Installment #{inst_no} Collection', 'Cash', NOW())"
                    )

                    if is_completed and inst_no == dur:
                        payoff_id = str(uuid.uuid5(NAMESPACE, f"payoff_{c_code}"))
                        payoff_values.append(
                            f"('{payoff_id}', '{repay_id}', '{loan_id}', '{c_id}', '{c['off']}', '{BRANCH_ID}', '{curr_date.isoformat()}', 'FULL_PAYOFF', {installment}, {installment}, {active_credit}, 0.0, {installment}, 0.0, 'Full loan completion settlement', NOW())"
                        )

                curr_date += day_increment

    print(f"Total schedules: {len(sched_values)}")
    print(f"Total repayments: {len(repay_values)}")
    print(f"Total payoffs: {len(payoff_values)}")
    print(f"Total disbursed: {total_disbursed}")
    print(f"Total upfront fees: {total_upfront_fees}")
    print(f"Total repayments: {total_repayments_collected}")

    out_dir = "scripts/maintenance"

    # Write schedule batches (4 batches)
    batch_size = (len(sched_values) + 3) // 4
    for b_idx in range(4):
        batch = sched_values[b_idx*batch_size : (b_idx+1)*batch_size]
        stmt = (
            "INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)\n"
            "VALUES\n" + ",\n".join(batch) + "\n"
            "ON CONFLICT (id) DO UPDATE SET\n"
            "    status = EXCLUDED.status,\n"
            "    paid_date = EXCLUDED.paid_date,\n"
            "    paid_amount = EXCLUDED.paid_amount;"
        )
        p = os.path.join(out_dir, f"clean_sched_part_{b_idx+1}.sql")
        with open(p, "w", encoding="utf-8") as f:
            f.write(stmt)
        print(f"Wrote {p} ({len(batch)} rows, {len(stmt)} bytes)")

    # Write repayments batches (2 batches)
    r_batch_size = (len(repay_values) + 1) // 2
    for b_idx in range(2):
        batch = repay_values[b_idx*r_batch_size : (b_idx+1)*r_batch_size]
        stmt = (
            "INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)\n"
            "VALUES\n" + ",\n".join(batch) + "\n"
            "ON CONFLICT (id) DO UPDATE SET\n"
            "    amount_paid = EXCLUDED.amount_paid;"
        )
        p = os.path.join(out_dir, f"clean_repay_part_{b_idx+1}.sql")
        with open(p, "w", encoding="utf-8") as f:
            f.write(stmt)
        print(f"Wrote {p} ({len(batch)} rows, {len(stmt)} bytes)")

    # Write payoffs
    payoff_stmt = (
        "INSERT INTO loan_payoff_excess_records (id, repayment_id, loan_id, client_id, officer_id, branch_id, date, record_type, amount_paid, expected_installment, active_credit_settled, excess_amount, remaining_balance_before, remaining_balance_after, notes, created_at)\n"
        "VALUES\n" + ",\n".join(payoff_values) + "\n"
        "ON CONFLICT (id) DO UPDATE SET\n"
        "    payoff_amount = EXCLUDED.payoff_amount,\n"
        "    excess_amount = EXCLUDED.excess_amount;"
    )
    p = os.path.join(out_dir, "clean_payoff.sql")
    with open(p, "w", encoding="utf-8") as f:
        f.write(payoff_stmt)
    print(f"Wrote {p} ({len(payoff_values)} rows, {len(payoff_stmt)} bytes)")

    # Write Ledger and Cashbook
    # Total savings in Ibadan: 315,500 (individual) + 75,000 (group) + 40,000 (laps) = 430,500
    # Let's verify exact savings from Step 3:
    # 20 individual: 315,500
    # 5 group: 75,000
    # 16 laps: 40,000
    # Total = 430,500.00
    total_savings = 430500.0
    net_cash = 2000000.0 - total_disbursed + total_upfront_fees + total_repayments_collected + total_savings
    TARGET_VAULT = 350000.0
    remit_to_bank = net_cash - TARGET_VAULT
    print(f"Net cash: {net_cash}, Remittance needed: {remit_to_bank}, Target vault: {TARGET_VAULT}")

    tx1 = str(uuid.uuid5(NAMESPACE, "tx_capital"))
    tx2 = str(uuid.uuid5(NAMESPACE, "tx_disb"))
    tx3 = str(uuid.uuid5(NAMESPACE, "tx_fees"))
    tx4 = str(uuid.uuid5(NAMESPACE, "tx_repay"))
    tx5 = str(uuid.uuid5(NAMESPACE, "tx_savings"))
    tx6 = str(uuid.uuid5(NAMESPACE, "tx_remit"))
    cb1 = str(uuid.uuid5(NAMESPACE, "cb_fri"))
    cb2 = str(uuid.uuid5(NAMESPACE, "cb_mon"))

    ledger_sql = f"""
INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
VALUES 
    ('{uuid.uuid5(NAMESPACE, "entry_cap_dr")}', '{tx1}', '{BRANCH_ID}', '1000', 'Debit', 2000000.0, 'Capital', '{BRANCH_ID}', '2026-08-01 08:00:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_cap_cr")}', '{tx1}', '{BRANCH_ID}', '3100', 'Credit', 2000000.0, 'Capital', '{BRANCH_ID}', '2026-08-01 08:00:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_disb_dr")}', '{tx2}', '{BRANCH_ID}', '1200', 'Debit', {total_disbursed}, 'Disbursement', '{BRANCH_ID}', '2026-10-12 09:00:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_disb_cr")}', '{tx2}', '{BRANCH_ID}', '1000', 'Credit', {total_disbursed}, 'Disbursement', '{BRANCH_ID}', '2026-10-12 09:00:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_fee_dr")}', '{tx3}', '{BRANCH_ID}', '1000', 'Debit', {total_upfront_fees}, 'FeeIncome', '{BRANCH_ID}', '2026-10-12 09:30:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_fee_cr")}', '{tx3}', '{BRANCH_ID}', '3000', 'Credit', {total_upfront_fees}, 'FeeIncome', '{BRANCH_ID}', '2026-10-12 09:30:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_rep_dr")}', '{tx4}', '{BRANCH_ID}', '1000', 'Debit', {total_repayments_collected}, 'Repayment', '{BRANCH_ID}', '2026-11-06 14:00:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_rep_cr")}', '{tx4}', '{BRANCH_ID}', '1200', 'Credit', {total_repayments_collected}, 'Repayment', '{BRANCH_ID}', '2026-11-06 14:00:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_sav_dr")}', '{tx5}', '{BRANCH_ID}', '1000', 'Debit', {total_savings}, 'SavingsDeposit', '{BRANCH_ID}', '2026-11-06 15:00:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_sav_cr")}', '{tx5}', '{BRANCH_ID}', '2100', 'Credit', {total_savings}, 'SavingsDeposit', '{BRANCH_ID}', '2026-11-06 15:00:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_rem_dr")}', '{tx6}', '{BRANCH_ID}', '1050', 'Debit', {remit_to_bank}, 'BankRemittance', '{BRANCH_ID}', '2026-11-06 16:30:00+00'),
    ('{uuid.uuid5(NAMESPACE, "entry_rem_cr")}', '{tx6}', '{BRANCH_ID}', '1000', 'Credit', {remit_to_bank}, 'BankRemittance', '{BRANCH_ID}', '2026-11-06 16:30:00+00')
ON CONFLICT (entry_id) DO NOTHING;

INSERT INTO master_cashbook (id, date, branch_id, opening_balance, total_inflows, total_outflows, closing_balance, status, version, created_at)
VALUES 
    ('{cb1}', '2026-11-06', '{BRANCH_ID}', 0.0, {TARGET_VAULT}, 0.0, {TARGET_VAULT}, 'Closed', 1, '2026-11-06 18:00:00+00'),
    ('{cb2}', '2026-11-09', '{BRANCH_ID}', {TARGET_VAULT}, 0.0, 0.0, {TARGET_VAULT}, 'Open', 1, '2026-11-09 07:00:00+00')
ON CONFLICT (id) DO UPDATE SET
    opening_balance = EXCLUDED.opening_balance,
    closing_balance = EXCLUDED.closing_balance,
    status = EXCLUDED.status;
""".strip()
    
    p = os.path.join(out_dir, "clean_ledger_cashbook.sql")
    with open(p, "w", encoding="utf-8") as f:
        f.write(ledger_sql)
    print(f"Wrote {p} ({len(ledger_sql)} bytes)")

if __name__ == "__main__":
    run()
