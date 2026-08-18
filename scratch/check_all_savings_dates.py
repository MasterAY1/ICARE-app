import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
import json

uow = SupabaseUnitOfWork()

# Check all posting dates in individual_savings
res_ind = uow.client.table("individual_savings").select("posting_date, deposit_amount, withdrawal_amount, reference, remarks").execute()
ind_dates = {}
for r in (res_ind.data or []):
    d = r.get("posting_date")
    ind_dates[d] = ind_dates.get(d, 0) + float(r.get("deposit_amount") or 0)
print("Individual Savings by posting_date:", ind_dates)

# Check all posting dates in group_savings
res_grp = uow.client.table("group_savings").select("posting_date, deposit_amount, withdrawal_amount, reference, remarks").execute()
grp_dates = {}
for r in (res_grp.data or []):
    d = r.get("posting_date")
    grp_dates[d] = grp_dates.get(d, 0) + float(r.get("deposit_amount") or 0)
print("Group Savings by posting_date:", grp_dates)

# Check all posting dates in internal_savings
res_int = uow.client.table("internal_savings").select("posting_date, deposit_amount, withdrawal_amount, reference, remarks").execute()
int_dates = {}
for r in (res_int.data or []):
    d = r.get("posting_date")
    int_dates[d] = int_dates.get(d, 0) + float(r.get("deposit_amount") or 0)
print("Internal Savings by posting_date:", int_dates)

# Check savings recorded in repayments table
res_rep = uow.client.table("repayments").select("date, savings_amount, group_savings_deposit").execute()
rep_sav_dates = {}
for r in (res_rep.data or []):
    d = r.get("date")
    s = float(r.get("savings_amount") or 0) + float(r.get("group_savings_deposit") or 0)
    if s > 0:
        rep_sav_dates[d] = rep_sav_dates.get(d, 0) + s
print("Repayments Table Savings by date:", rep_sav_dates)

