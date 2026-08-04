import re

with open('services/portfolio_service.py', 'r', encoding='utf-8') as f:
    content = f.read()

old_agg = '''        total_active_credit = sum(float(l.get("disbursed_amount") or l.get("principal") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])
        total_outstanding_balance = sum(float(l.get("active_credit") or l.get("balance") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])'''

new_agg = '''        total_active_credit = sum(float(l.get("disbursed_amount") or l.get("principal") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])
        total_outstanding_balance = sum(float(l.get("active_credit") or l.get("balance") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])
        total_expected_repayment = sum(float(l.get("loan_repay") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])
        total_savings_balance = total_savings_deposit - total_savings_withdrawal'''

content = content.replace(old_agg, new_agg)

with open('services/portfolio_service.py', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed portfolio_service.py")
