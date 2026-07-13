import re

with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update save_repayment
new_save_repayment = """def save_repayment(data):
    \"\"\"Save repayment and route savings to respective buckets\"\"\"
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        from services.savings_service import SavingsService
        with SupabaseUnitOfWork() as uow:
            db_data = {UI_TO_DB_REP[k]: v for k, v in data.items() if k in UI_TO_DB_REP}
            from mappers.base_mappers import RepaymentMapper
            
            # Map old DB keys expected by mapper
            if 'credit_officer' not in db_data: db_data['credit_officer'] = db_data.get('officer', USER)
            if 'branch' not in db_data: db_data['branch'] = BRANCH
            
            client_id = db_data.get('client_id', '')
            client_name = db_data.get('client_name', client_id)
            branch = db_data.get('branch', BRANCH)
            officer = db_data.get('credit_officer', USER)
            
            # Extract Savings
            savings_dep = float(db_data.get('savings_amount', 0))
            savings_wd = float(db_data.get('withdrawal_amount', 0))
            group_dep = float(db_data.get('group_savings_dep', 0))
            group_wd = float(db_data.get('group_savings_wd', 0))
            laps_res = float(db_data.get('laps_reserved', 0))
            laps_trans = float(db_data.get('laps_transferred', 0))
            misc_fees = float(db_data.get('misc_fees', 0))
            loan_repay = float(db_data.get('loan_repayment_amount', 0))
            
            # Route Group Savings
            if client_id.startswith('GROUP-'):
                group_name = client_id.replace('GROUP-', '')
                SavingsService.post_group_savings(uow, group_name, branch, officer, group_dep, group_wd, remarks=db_data.get('note'))
                return # Do not insert a dummy loan or a repayment row
            
            # Route LAPS
            if client_id.startswith('GLOBAL-'):
                SavingsService.post_laps_savings(uow, client_id, client_name, branch, officer, laps_res, laps_trans)
                return # Do not insert a dummy loan or a repayment row

            # Route Individual Savings
            if savings_dep > 0 or savings_wd > 0:
                SavingsService.post_individual_savings(uow, client_id, client_name, branch, officer, savings_dep, savings_wd, remarks=db_data.get('note'))
                # clear it so it doesn't double count if repayment table still has it?
                # we'll leave it in the dict so the old table gets a copy for backward compatibility if needed,
                # but the dashboard will ONLY use the new tables.

            # Route Misc Savings if collected during collections
            if misc_fees > 0:
                SavingsService.post_misc_savings(uow, client_id, client_name, branch, officer, misc_fees, remarks=db_data.get('note'))

            # Proceed to insert into repayments table if there's actual repayment
            # or if it's a legacy record. We'll always insert it so history isn't lost.
            rep = RepaymentMapper.to_domain(db_data)
            try:
                uow.repayments.create(rep)
            except Exception as re:
                st.error(f"Error inserting repayment for {client_id}: {re}")
                return
    except Exception as e:
        st.error(f"Error in save_repayment logic: {e}")
"""

content = re.sub(r'def save_repayment\(data\):.*?st\.error\(f"Error in save_repayment logic: \{e\}"\)', new_save_repayment, content, flags=re.DOTALL)

# 2. Update save_new_loan to post Misc Savings
new_save_new_loan = """def save_new_loan(data):
    \"\"\"Save new loan and intercept upfront misc savings\"\"\"
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        from services.savings_service import SavingsService
        with SupabaseUnitOfWork() as uow:
            db_data = {UI_TO_DB_LOANS[k]: v for k, v in data.items() if k in UI_TO_DB_LOANS}
            from mappers.base_mappers import LoanMapper
            
            if 'id' not in db_data: db_data['id'] = ''
            if 'client_name' not in db_data: db_data['client_name'] = ''
            if 'branch' not in db_data: db_data['branch'] = BRANCH
            if 'credit_officer' not in db_data: db_data['credit_officer'] = db_data.get('officer', USER)
            
            loan = LoanMapper.to_domain(db_data)
            uow.loans.create(loan)
            
            # Post upfront Misc Fees to Misc Savings Bucket
            misc_fees = float(db_data.get('misc_fees', 0))
            if misc_fees > 0:
                SavingsService.post_misc_savings(
                    uow, 
                    client_id=loan.client_id, 
                    client_name=loan.client_name, 
                    branch=loan.branch, 
                    officer=loan.officer, 
                    deposit_amount=misc_fees, 
                    remarks="Upfront Misc Fee Collection"
                )
    except Exception as e:
        st.error(f"Error saving loan: {e}")
"""

content = re.sub(r'def save_new_loan\(data\):.*?st\.error\(f"Error saving loan: \{e\}"\)', new_save_new_loan, content, flags=re.DOTALL)

with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)
print("app.py patched.")
