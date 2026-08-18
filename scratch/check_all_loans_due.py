import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

def check_all_10_loans():
    with SupabaseUnitOfWork() as uow:
        res_l = uow.client.table("loans").select("loan_id, client_id, loan_amount, active_credit, total_due, loan_repay, status, clients(name, client_code), loan_products(name)").eq("status", "Active").execute()
        
        print(f"{'Client Code':<12} | {'Name':<20} | {'Product':<12} | {'Active Credit':>14} | {'Total Due (Bal)':>16} | {'Already Paid':>14} | {'Weekly Repay':>12}")
        print("-" * 105)
        
        tot_active = 0.0
        tot_due = 0.0
        tot_paid = 0.0
        
        for l in res_l.data:
            c = l.get("clients") or {}
            p = l.get("loan_products") or {}
            c_code = c.get("client_code", "N/A")
            name = c.get("name", "N/A")
            prod = p.get("name", "N/A")
            
            act_cred = float(l.get("active_credit") or 0.0)
            t_due = float(l.get("total_due") if l.get("total_due") is not None else act_cred)
            paid = max(0.0, act_cred - t_due)
            repay = float(l.get("loan_repay") or 0.0)
            
            tot_active += act_cred
            tot_due += t_due
            tot_paid += paid
            
            print(f"{c_code:<12} | {name:<20} | {prod:<12} | NGN {act_cred:>13,.2f} | NGN {t_due:>15,.2f} | NGN {paid:>13,.2f} | NGN {repay:>11,.2f}")
            
        print("-" * 105)
        print(f"{'TOTAL':<48} | NGN {tot_active:>13,.2f} | NGN {tot_due:>15,.2f} | NGN {tot_paid:>13,.2f}")

if __name__ == "__main__":
    check_all_10_loans()
