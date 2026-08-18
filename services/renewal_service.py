from typing import Tuple, List
from database.repositories.unit_of_work import SupabaseUnitOfWork

class RenewalService:
    @staticmethod
    def check_eligibility(uow: SupabaseUnitOfWork, client_id: str, requested_amount: float, product_type: str, product_category: str = "Finance") -> Tuple[bool, List[str], List[str]]:
        """
        Evaluates a client's eligibility for a loan.
        Returns (is_eligible: bool, reasons: List[str], warnings: List[str]).
        """
        reasons = []
        warnings = []
        is_eligible = True
        
        is_requested_asset = (product_category == "Asset")

        # 1. Fetch all loans and client status
        res_loans = uow.client.table("loans").select("*").eq("client_id", client_id).execute()
        all_loans = res_loans.data if res_loans.data else []
        
        # Check dynamic remaining balance for active loans (BR-CLI-005)
        active_loans = []
        for L in all_loans:
            if L.get("status") in ["Active", "ACTIVE", "Approved"]:
                lid = str(L.get("loan_id") or L.get("id") or "")
                act_c = float(L.get("active_credit") or L.get("loan_amount") or 0.0)
                tot_due = float(L.get("total_due") if L.get("total_due") is not None else act_c)
                rep_res = uow.client.table("repayments").select("amount_paid").eq("loan_id", lid).execute()
                tot_p = sum(float(r.get("amount_paid") or 0.0) for r in (rep_res.data or []))
                if max(0.0, tot_due - tot_p) > 0:
                    active_loans.append(L)

        past_loans = [L for L in all_loans if L not in active_loans and L.get("status") != "Pending"]
        pending_loans = [L for L in all_loans if L.get("status") == "Pending" and float(L.get("loan_amount") or 0.0) > 0]

        # Check client lifecycle status for Defaulter warning (BR-CLI-009)
        try:
            c_status_res = uow.client.table("clients").select("status_id, client_statuses(name)").eq("client_id", client_id).execute()
            if c_status_res.data:
                cs_obj = c_status_res.data[0].get("client_statuses") or {}
                cs_name = cs_obj.get("name") if isinstance(cs_obj, dict) else ""
                if cs_name == "Defaulter":
                    warnings.append("⚠️ DEFAULTER WARNING: Client has past default history. BM must make final approval decision.")
        except Exception:
            pass

        has_any_loan = len(all_loans) > 0

        # NEW CLIENT CHECK
        if not has_any_loan:
            if requested_amount > 100000:
                warnings.append("⚠️ NEW CLIENT: Requested amount is above the ₦100,000 standard limit for new clients. Proceed only if authorized.")
        
        # EXISTING CLIENT CHECK
        else:
            # Active Loan Check (same category)
            for loan in active_loans:
                loan_is_asset = loan.get("is_asset", False)
                if not isinstance(loan_is_asset, bool):
                    loan_is_asset = str(loan_is_asset).lower() == "true"
                
                if loan_is_asset == is_requested_asset:
                    is_eligible = False
                    reasons.append(f"Client currently has an active {product_category} loan with outstanding balance.")
                    break
            
            for loan in pending_loans:
                loan_is_asset = loan.get("is_asset", False)
                if not isinstance(loan_is_asset, bool):
                    loan_is_asset = str(loan_is_asset).lower() == "true"
                if loan_is_asset == is_requested_asset:
                    is_eligible = False
                    reasons.append(f"Client already has a pending {product_category} loan application awaiting BM approval.")
                    break
            
            # Check past loans for bad standing (Warning only per BR-CLI-009)
            for loan in past_loans:
                loan_status = loan.get("status", "")
                if loan_status in ["Defaulter", "Written Off"]:
                    warnings.append(f"⚠️ PAST LOAN WARNING: Client has a previous loan with status '{loan_status}'.")
                        
        # 2. Fetch client savings balance (to ensure they meet required percentage)
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
        if has_any_loan:
            loan_ids = [L.get("loan_id", L.get("id")) for L in all_loans if L.get("loan_id") or L.get("id")]
            if loan_ids:
                res_schedule = uow.client.table("loan_schedule").select("status").in_("loan_id", loan_ids).execute()
                late_count = sum(1 for row in res_schedule.data if row.get("status") in ["Partial", "Overdue"])
                if late_count > 3:
                    warnings.append(f"⚠️ REPAYMENT WARNING: Repayment history has {late_count} partial/overdue installments.")

        if is_eligible:
            reasons.append("Eligible to apply for this loan.")

        return is_eligible, reasons, warnings
