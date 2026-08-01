from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.financial_reconciliation_service import FinancialReconciliationService

if __name__ == "__main__":
    with SupabaseUnitOfWork() as uow:
        res = FinancialReconciliationService.verify_6way_financial_integrity(uow, None, date.today())
        print(f"Is Balanced: {res['is_balanced']}")
        print(f"Status: {res['status_text']}")
        print(f"Ledger: {res['ledger_total']}")
        print(f"Audit Views: {res['audit_views_total']}")
        print(f"CO Cashbooks: {res['co_cashbooks_total']}")
        print(f"Master Cashbook: {res['master_cashbook_total']}")
        print(f"Dashboard: {res['dashboard_total']}")
        print(f"Reports: {res['reports_total']}")
        if res.get('variances'):
            print("Variances:", res['variances'])
