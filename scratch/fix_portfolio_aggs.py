import os

PORTFOLIO_SVC = 'C:/Users/DELL/Desktop/Master_ AY Projects/trustmicro-credit/services/portfolio_service.py'

with open(PORTFOLIO_SVC, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: Fetch Lifetime Repayments using loan_id instead of client_id
old_lt = '''        # 4. Fetch Lifetime Repayments for Dynamic Outstanding Balance
        lifetime_repayments_map = {}
        try:
            active_cids = list(set([str(l.get("client_id")) for l in loans_raw if l.get("client_id") and str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"]]))
            if active_cids:
                lt_query = uow.client.table("repayments").select("client_id, amount_paid").in_("client_id", active_cids).execute()
                for r in (lt_query.data or []):
                    cid_s = str(r.get("client_id"))
                    amt = float(r.get("amount_paid") or 0.0)
                    lifetime_repayments_map[cid_s] = lifetime_repayments_map.get(cid_s, 0.0) + amt
        except Exception:
            lifetime_repayments_map = {}'''

new_lt = '''        # 4. Fetch Lifetime Repayments for Dynamic Outstanding Balance
        lifetime_repayments_map = {}
        try:
            active_loan_ids = list(set([str(l.get("loan_id")) for l in loans_raw if l.get("loan_id") and str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"]]))
            if active_loan_ids:
                lt_query = uow.client.table("repayments").select("loan_id, amount_paid").in_("loan_id", active_loan_ids).execute()
                for r in (lt_query.data or []):
                    lid_s = str(r.get("loan_id"))
                    amt = float(r.get("amount_paid") or 0.0)
                    lifetime_repayments_map[lid_s] = lifetime_repayments_map.get(lid_s, 0.0) + amt
        except Exception:
            lifetime_repayments_map = {}'''

# Fix 2: Calculate dynamic outstanding balance using loan_id
old_ob = '''        # Calculate overall dynamic outstanding balance
        total_outstanding_balance = 0.0
        for l in loans_raw:
            if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"]:
                cid_s = str(l.get("client_id") or "")
                act_cred = float(l.get("active_credit") or 0.0)
                tot_paid = lifetime_repayments_map.get(cid_s, 0.0)
                total_outstanding_balance += max(0.0, act_cred - tot_paid)'''

new_ob = '''        # Calculate overall dynamic outstanding balance
        total_outstanding_balance = 0.0
        for l in loans_raw:
            if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"]:
                lid_s = str(l.get("loan_id") or "")
                act_cred = float(l.get("active_credit") or 0.0)
                tot_paid = lifetime_repayments_map.get(lid_s, 0.0)
                total_outstanding_balance += max(0.0, act_cred - tot_paid)'''

# Fix 3: In the product summary generation
old_ps = '''                loan_id = l.get("loan_id")
                if loan_id and len(str(loan_id)) > 10:
                    tot_paid_loan, has_schedule = ScheduleService.get_total_paid(uow, str(loan_id))
                    if not has_schedule:
                        tot_paid_loan = lifetime_repayments_map.get(cid_str, 0.0)
                else:
                    tot_paid_loan = lifetime_repayments_map.get(cid_str, 0.0)'''

new_ps = '''                loan_id = l.get("loan_id")
                if loan_id and len(str(loan_id)) > 10:
                    tot_paid_loan, has_schedule = ScheduleService.get_total_paid(uow, str(loan_id))
                    if not has_schedule:
                        tot_paid_loan = lifetime_repayments_map.get(str(loan_id), 0.0)
                else:
                    tot_paid_loan = lifetime_repayments_map.get(str(loan_id), 0.0)'''

if old_lt in content:
    content = content.replace(old_lt, new_lt)
    print("Fixed lt_query map logic")
if old_ob in content:
    content = content.replace(old_ob, new_ob)
    print("Fixed total_outstanding_balance aggregation loop")
if old_ps in content:
    content = content.replace(old_ps, new_ps)
    print("Fixed product summary lifetime map usage")

with open(PORTFOLIO_SVC, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated portfolio_service.py successfully!")
