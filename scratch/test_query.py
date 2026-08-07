from database.repositories.unit_of_work import SupabaseUnitOfWork
import json
with SupabaseUnitOfWork() as uow:
    res = uow.client.table('posting_rules').select('*').in_('event_type', ['FeeCharged', 'RepaymentReceived', 'BankWithdrawn', 'BankDeposited', 'LoanDisbursed', 'AssetSoldCash']).execute()
    for row in res.data:
        print(row)
