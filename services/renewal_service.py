from typing import Tuple, List
from database.repositories.unit_of_work import SupabaseUnitOfWork

class RenewalService:
    @staticmethod
    def check_eligibility(uow: SupabaseUnitOfWork, client_id: str, requested_amount: float, product_type: str) -> Tuple[bool, List[str]]:
        """
        Evaluates a client's eligibility for loan renewal.
        Returns (is_eligible: bool, reasons: List[str]).
        """
        reasons = []
        is_eligible = True

        # 1. Fetch active loans for the client
        res_loans = uow.client.table("loans").select("*").eq("client_id", client_id).eq("status", "Active").execute()
        
        if res_loans.data:
            for loan in res_loans.data:
                orig_amount = float(loan.get("loan_amount") or 0)
                outstanding = float(loan.get("total_due") or 0)
                
                # Rule: Client cannot renew if they have an active loan with outstanding balance > 10% of original amount
                threshold = 0.10 * orig_amount
                if outstanding > threshold:
                    is_eligible = False
                    reasons.append(f"Outstanding balance (₦{outstanding:,.2f}) on active loan is above the 10% threshold (₦{threshold:,.2f}).")

        # 2. Fetch client savings balance
        # Sum all individual savings deposits minus withdrawals for this client
        res_dep = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", client_id).execute()
        res_wd = uow.client.table("individual_savings").select("withdrawal_amount").eq("client_id", client_id).execute()

        total_savings = sum(float(d.get("deposit_amount") or 0) for d in res_dep.data) - sum(float(w.get("withdrawal_amount") or 0) for w in res_wd.data)

        # Fetch product savings requirement
        res_prod = uow.client.table("loan_products").select("savings_requirement").eq("name", product_type).execute()
        req_percentage = 0.0
        if res_prod.data:
            req_percentage = float(res_prod.data[0].get("savings_requirement") or 0)

        required_savings = req_percentage * requested_amount
        if total_savings < required_savings:
            is_eligible = False
            reasons.append(f"Insufficient savings balance (₦{total_savings:,.2f}). Required is ₦{required_savings:,.2f} ({req_percentage*100:.1f}% of requested loan).")

        # 3. Check repayment history quality
        # Count the number of 'Partial' or 'Overdue' installments in the client's past loans
        # We can search all schedule rows for loans belonging to the client
        res_past_loans = uow.client.table("loans").select("loan_id").eq("client_id", client_id).execute()
        if res_past_loans.data:
            loan_ids = [L["loan_id"] for L in res_past_loans.data]
            # Query schedule rows
            res_schedule = uow.client.table("loan_schedule").select("status").in_("loan_id", loan_ids).execute()
            late_count = sum(1 for row in res_schedule.data if row.get("status") in ["Partial", "Overdue"])
            if late_count > 3:
                is_eligible = False
                reasons.append(f"Repayment history has {late_count} partial or overdue installments. Maximum allowed is 3.")

        if is_eligible:
            reasons.append("Client is fully eligible for loan renewal.")

        return is_eligible, reasons
