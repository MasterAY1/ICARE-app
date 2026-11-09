"""
Divides the simulation SQL into clean logical blocks for execute_sql execution.
"""
import os

out_dir = os.path.dirname(__file__)

with open(os.path.join(out_dir, "ibadan_part2_clients_savings.sql"), "r", encoding="utf-8") as f:
    p2 = f.read()

# Split into Clients (first 40 stmts: 20 clients + 20 memberships) + Withdrawal Request (1 stmt)
p2_stmts = [s.strip() for s in p2.split(";\n\n") if s.strip()]
clients_stmts = [s for s in p2_stmts if "INSERT INTO clients" in s or "INSERT INTO client_memberships" in s or "INSERT INTO withdrawal_requests" in s]
savings_stmts = [s for s in p2_stmts if "INSERT INTO individual_savings" in s or "INSERT INTO group_savings" in s or "INSERT INTO laps_savings" in s]

with open(os.path.join(out_dir, "ibadan_step2_clients.sql"), "w", encoding="utf-8") as f:
    f.write(";\n\n".join(clients_stmts) + ";\n")

with open(os.path.join(out_dir, "ibadan_step3_savings.sql"), "w", encoding="utf-8") as f:
    f.write(";\n\n".join(savings_stmts) + ";\n")

print(f"Step 2 Clients: {len(clients_stmts)} stmts")
print(f"Step 3 Savings: {len(savings_stmts)} stmts")

with open(os.path.join(out_dir, "ibadan_part3_loans_schedules.sql"), "r", encoding="utf-8") as f:
    p3 = f.read()

p3_stmts = [s.strip() for s in p3.split(";\n\n") if s.strip()]
loans_stmts = [s for s in p3_stmts if "INSERT INTO loans " in s]
sched_stmts = [s for s in p3_stmts if "INSERT INTO loan_schedule" in s]
repay_stmts = [s for s in p3_stmts if "INSERT INTO repayments" in s or "INSERT INTO loan_payoff_excess_records" in s]

with open(os.path.join(out_dir, "ibadan_step4_loans.sql"), "w", encoding="utf-8") as f:
    f.write(";\n\n".join(loans_stmts) + ";\n")

# Sched stmts can be divided in 2 chunks
half = len(sched_stmts) // 2
with open(os.path.join(out_dir, "ibadan_step5_schedules_a.sql"), "w", encoding="utf-8") as f:
    f.write(";\n\n".join(sched_stmts[:half]) + ";\n")

with open(os.path.join(out_dir, "ibadan_step5_schedules_b.sql"), "w", encoding="utf-8") as f:
    f.write(";\n\n".join(sched_stmts[half:]) + ";\n")

with open(os.path.join(out_dir, "ibadan_step6_repayments.sql"), "w", encoding="utf-8") as f:
    f.write(";\n\n".join(repay_stmts) + ";\n")

print(f"Step 4 Loans: {len(loans_stmts)} stmts")
print(f"Step 5a Schedules: {len(sched_stmts[:half])} stmts")
print(f"Step 5b Schedules: {len(sched_stmts[half:])} stmts")
print(f"Step 6 Repayments: {len(repay_stmts)} stmts")

with open(os.path.join(out_dir, "ibadan_part4_ledger_cashbook.sql"), "r", encoding="utf-8") as f:
    p4 = f.read()

with open(os.path.join(out_dir, "ibadan_step7_ledger_cashbook.sql"), "w", encoding="utf-8") as f:
    f.write(p4 + ";\n")

print("All steps generated cleanly.")
