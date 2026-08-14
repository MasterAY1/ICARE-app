from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== INSPECTING TRANSACTIONS TO CLEAR FOR CLEAN TEST ===")

# 1. Repayments (non-onboarding)
res_r = uow.client.table("repayments").select("*").neq("date", "1970-01-01").execute()
print(f"Non-onboarding repayments: {len(res_r.data or [])}")
for r in (res_r.data or []):
    print("  Repayment:", r.get("id"), r.get("client_id"), r.get("amount_paid"), r.get("date"), r.get("note"))

# 2. Individual Savings (non-onboarding)
res_s = uow.client.table("individual_savings").select("*").neq("remarks", "Initial Onboarding Savings").execute()
print(f"Non-onboarding individual savings: {len(res_s.data or [])}")
for s in (res_s.data or []):
    print("  Savings:", s.get("id"), s.get("client_id"), s.get("deposit_amount"), s.get("posting_date"), s.get("remarks"))

# 3. Loans created today
res_l_today = uow.client.table("loans").select("*").gte("created_at", "2026-08-14T00:00:00").execute()
print(f"Loans created today: {len(res_l_today.data or [])}")

# 4. Check existing 10 onboarding loans
res_loans = uow.client.table("loans").select("*").execute()
print(f"Total loans in DB: {len(res_loans.data or [])}")
for l in (res_loans.data or []):
    print(f"  Loan: {l.get('loan_id')} | Client: {l.get('client_id')} | Principal: {l.get('principal_amount')} | Active: {l.get('active_credit')} | Paid: {l.get('total_paid')} | Rem: {l.get('remaining_balance')}")

# 5. Financial Transactions created today
res_tx = uow.client.table("financial_transactions").select("transaction_id, narration, posting_date").gte("posting_date", "2026-08-14").execute()
print(f"Financial transactions on/after 2026-08-14: {len(res_tx.data or [])}")

# 6. Event Store created today
res_ev = uow.client.table("event_store").select("event_id, event_type, created_at").gte("created_at", "2026-08-14T00:00:00").execute()
print(f"Event Store on/after 2026-08-14: {len(res_ev.data or [])}")
