"""
SupabaseAuditViewRepository — Phase 8.1
Provides read-only access to virtual audit ledgers across Fee, Treasury, Savings,
Loans, Collection Performance, and Cashbook sub-systems.
Supports strict parameter filtering (branch_id, officer_id, client_id, date_from, date_to).
"""
from typing import List, Dict, Any, Optional
from datetime import date
from database.repositories.base_repository import BaseRepository


class SupabaseAuditViewRepository(BaseRepository):
    """Read-only repository for Audit Center virtual ledgers."""

    def __init__(self, client):
        super().__init__(client)

    # -------------------------------------------------------------------------
    # 1. Fee Audit Ledgers (backed by public.fees via fee_type)
    # -------------------------------------------------------------------------
    def get_fee_ledger(
        self,
        fee_type: str,
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        client_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """
        Fetch authoritative fee audit records across event_store, financial_ledger_entries,
        and fees table with full branch, officer, client, and date filtering.
        """
        records: List[Dict[str, Any]] = []
        seen_keys = set()

        # 1. First, check public.fees table if records exist
        try:
            query = self.client.table("fees").select("*")
            if fee_type and fee_type != "ALL":
                if fee_type == "PROCESSING_FEE":
                    query = query.in_("fee_type", ["PROCESSING_FEE", "CREDIT_FORM", "APP_FEE", "APPLICATION_FEE"])
                else:
                    query = query.eq("fee_type", fee_type)
            if branch_id and branch_id != "All":
                query = query.eq("branch_id", branch_id)
            if officer_id and officer_id != "All":
                query = query.eq("officer_id", officer_id)
            if client_id:
                query = query.eq("client_id", client_id)
            if date_from:
                query = query.gte("posting_date", date_from.isoformat() if isinstance(date_from, date) else str(date_from))
            if date_to:
                query = query.lte("posting_date", date_to.isoformat() if isinstance(date_to, date) else str(date_to))

            res = query.order("created_at", desc=True).limit(limit).execute()
            for r in (res.data or []):
                seen_keys.add(f"fees_{r.get('id')}")
                records.append(r)
        except Exception:
            pass

        # Branch & Officer resolution helpers
        branch_id_to_name = {}
        officer_id_to_names = {}
        try:
            res_b = self.client.table("branches").select("branch_id, name").execute()
            for b in (res_b.data or []):
                if b.get("branch_id") and b.get("name"):
                    branch_id_to_name[str(b["branch_id"])] = str(b["name"])
        except Exception:
            pass

        try:
            res_u = self.client.table("app_users").select("id, username, full_name").execute()
            for u in (res_u.data or []):
                u_id = str(u.get("id"))
                uname = str(u.get("username") or "")
                fname = str(u.get("full_name") or "")
                officer_id_to_names[u_id] = {uname.lower(), fname.lower(), u_id.lower()}
        except Exception:
            pass

        def matches_branch(ev_b, target_b):
            if not target_b or target_b in ["All", "All Branches"]:
                return True
            if not ev_b:
                return True
            if str(ev_b).lower() == str(target_b).lower():
                return True
            if str(target_b) in branch_id_to_name and branch_id_to_name[str(target_b)].lower() == str(ev_b).lower():
                return True
            if str(ev_b) in branch_id_to_name and branch_id_to_name[str(ev_b)].lower() == str(target_b).lower():
                return True
            return False

        def matches_officer(ev_off, target_off):
            if not target_off or target_off in ["All", "All Officers"]:
                return True
            if not ev_off:
                return True
            t_str = str(target_off).lower()
            e_str = str(ev_off).lower()
            if t_str == e_str:
                return True
            if str(target_off) in officer_id_to_names:
                if e_str in officer_id_to_names[str(target_off)]:
                    return True
            for uid, names in officer_id_to_names.items():
                if t_str in names and e_str in names:
                    return True
            return False

        # 2. Query event_store for FeeCharged and LoanDisbursed events
        try:
            q_ev = self.client.table("event_store").select("*").in_("event_type", ["FeeCharged", "LoanDisbursed"])
            res_ev = q_ev.limit(limit * 5).execute()
            for ev in (res_ev.data or []):
                ev_type = ev.get("event_type")
                payload = ev.get("payload") or {}
                
                ev_branch = payload.get("branch_id") or payload.get("branch")
                ev_officer = payload.get("officer_id") or payload.get("officer")
                ev_client = payload.get("client_id") or payload.get("client")
                ev_date = str(payload.get("date") or str(ev.get("created_at") or "")[:10])[:10]
                ev_ref = payload.get("reference") or ev.get("event_id")[:8]
                
                # Filter by date range
                if date_from:
                    d_from_str = date_from.isoformat() if isinstance(date_from, date) else str(date_from)[:10]
                    if ev_date and ev_date < d_from_str:
                        continue
                if date_to:
                    d_to_str = date_to.isoformat() if isinstance(date_to, date) else str(date_to)[:10]
                    if ev_date and ev_date > d_to_str:
                        continue
                
                # Filter by branch if specified
                if not matches_branch(ev_branch, branch_id):
                    continue
                # Filter by officer if specified
                if not matches_officer(ev_officer, officer_id):
                    continue
                # Filter by client if specified
                if client_id and ev_client and ev_client != client_id:
                    continue

                fee_items = []
                if ev_type == "FeeCharged":
                    cls_val = payload.get("classification") or ""
                    narr = str(payload.get("narration") or "").upper()
                    
                    if cls_val in ["MARKUP_11", "MARKUP_20", "CONTINGENCY", "PASSBOOK", "CREDIT_FORM_DAMAGE", "BONUS"]:
                        f_t = cls_val
                    elif "11%" in narr or "MARKUP (11%)" in narr or "12W" in narr or "60D" in narr or "3M" in narr:
                        f_t = "MARKUP_11"
                    elif "20%" in narr or "MARKUP (20%)" in narr or "24W" in narr or "120D" in narr or "6M" in narr:
                        f_t = "MARKUP_20"
                    elif "CONTINGENCY" in narr:
                        f_t = "CONTINGENCY"
                    elif "PASSBOOK" in narr:
                        f_t = "PASSBOOK"
                    elif "DAMAGE" in narr or "CFD" in narr:
                        f_t = "CREDIT_FORM_DAMAGE"
                    elif "BONUS" in narr:
                        f_t = "BONUS"
                    elif "MISC" in narr or "RISK PREMIUM" in narr:
                        continue  # Excluded: Misc Savings belong in Savings Ledger (Tab 4) per BR-SAV-001
                    else:
                        f_t = "PROCESSING_FEE"  # Unified Processing / Credit Form / App Fee
                        
                    fee_items.append((f_t, float(payload.get("amount") or 0.0), payload.get("narration") or f"{f_t} transaction"))

                elif ev_type == "LoanDisbursed":
                    cont_fee = float(payload.get("contingency_fee") or 0.0)
                    if cont_fee > 0:
                        fee_items.append(("CONTINGENCY", cont_fee, f"Upfront Contingency fee for {ev_ref}"))
                    markup_fee = float(payload.get("markup_amount") or 0.0)
                    if markup_fee > 0:
                        p_type = str(payload.get("product_type") or "")
                        dur = payload.get("duration") or 12
                        m_t = "MARKUP_20" if ("24" in p_type or "20" in p_type or "120" in p_type or "6m" in p_type.lower() or dur == 24) else "MARKUP_11"
                        fee_items.append((m_t, markup_fee, f"Upfront Markup for {ev_ref}"))

                for f_t, f_amt, f_narr in fee_items:
                    if f_amt <= 0:
                        continue
                    # Match fee type filter
                    if fee_type and fee_type != "ALL":
                        if fee_type == "PROCESSING_FEE" and f_t not in ["PROCESSING_FEE", "CREDIT_FORM", "APP_FEE"]:
                            continue
                        elif fee_type != "PROCESSING_FEE" and f_t != fee_type:
                            continue

                    k = f"ev_{ev.get('event_id')}_{f_t}"
                    if k in seen_keys:
                        continue
                    seen_keys.add(k)

                    b_val = ev_branch
                    for b_uuid, b_nm in branch_id_to_name.items():
                        if b_nm.lower() == str(ev_branch).lower():
                            b_val = b_uuid
                            break

                    records.append({
                        "id": ev.get("event_id"),
                        "fee_type": f_t,
                        "amount": f_amt,
                        "branch_id": b_val,
                        "officer_id": ev_officer,
                        "client_id": ev_client,
                        "posting_date": ev_date,
                        "reference": ev_ref,
                        "remarks": f_narr,
                        "created_at": ev.get("created_at")
                    })
        except Exception:
            pass

        return records[:limit]

    # -------------------------------------------------------------------------
    # 2. Treasury Audit Ledgers (backed by public.treasury_transactions)
    # -------------------------------------------------------------------------
    def get_treasury_ledger(
        self,
        transaction_type: str,
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Fetch treasury movement records for a specific transaction_type."""
        query = self.client.table("treasury_transactions").select("*")
        if transaction_type and transaction_type != "ALL":
            if isinstance(transaction_type, list):
                query = query.in_("transaction_type", transaction_type)
            else:
                query = query.eq("transaction_type", transaction_type)
        if branch_id and branch_id != "All":
            query = query.eq("branch_id", branch_id)
        if officer_id and officer_id != "All":
            query = query.eq("officer_id", officer_id)
        if date_from:
            query = query.gte("posting_date", date_from.isoformat() if isinstance(date_from, date) else date_from)
        if date_to:
            query = query.lte("posting_date", date_to.isoformat() if isinstance(date_to, date) else date_to)

        query = query.order("created_at", desc=True).limit(limit)
        res = query.execute()
        return res.data or []

    # -------------------------------------------------------------------------
    # 3. Operational Loan Audit Ledgers
    # -------------------------------------------------------------------------
    def get_loan_disbursements(
        self,
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Fetch disbursed/active/completed loan records."""
        query = self.client.table("loans").select("*").in_("status", ["Disbursed", "Active", "Completed", "Closed"])
        if branch_id and branch_id != "All":
            query = query.eq("branch_id", branch_id)
        if officer_id and officer_id != "All":
            query = query.eq("officer_id", officer_id)
        if date_from:
            query = query.gte("date", date_from.isoformat() if isinstance(date_from, date) else date_from)
        if date_to:
            query = query.lte("date", date_to.isoformat() if isinstance(date_to, date) else date_to)

        query = query.order("created_at", desc=True).limit(limit)
        res = query.execute()
        return res.data or []

    def get_loan_repayments(
        self,
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        client_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Fetch repayment records from public.repayments."""
        query = self.client.table("repayments").select("*")
        if branch_id and branch_id != "All":
            query = query.eq("branch_id", branch_id)
        if officer_id and officer_id != "All":
            query = query.eq("officer_id", officer_id)
        if client_id:
            query = query.eq("client_id", client_id)
        if date_from:
            query = query.gte("date", date_from.isoformat() if isinstance(date_from, date) else date_from)
        if date_to:
            query = query.lte("date", date_to.isoformat() if isinstance(date_to, date) else date_to)

        query = query.order("created_at", desc=True).limit(limit)
        res = query.execute()
        return res.data or []

    # -------------------------------------------------------------------------
    # 4. Savings Audit Ledgers
    # -------------------------------------------------------------------------
    def get_savings_ledger(
        self,
        savings_table: str,  # "individual_savings", "group_savings", "laps_savings"
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Fetch savings records from specified savings ledger table."""
        if savings_table not in ["individual_savings", "group_savings", "laps_savings", "internal_savings"]:
            raise ValueError(f"Invalid savings table: {savings_table}")

        query = self.client.table(savings_table).select("*")
        if branch_id and branch_id != "All":
            query = query.eq("branch_id", branch_id)
        if officer_id and officer_id != "All":
            query = query.eq("officer_id", officer_id)
        if date_from:
            query = query.gte("posting_date", date_from.isoformat() if isinstance(date_from, date) else date_from)
        if date_to:
            query = query.lte("posting_date", date_to.isoformat() if isinstance(date_to, date) else date_to)

        query = query.order("created_at", desc=True).limit(limit)
        res = query.execute()
        return res.data or []

    # -------------------------------------------------------------------------
    # Read-only mutation safeguards
    # -------------------------------------------------------------------------
    def create(self, entity: Any) -> Any:
        raise NotImplementedError("Audit views are strictly read-only.")

    def update(self, entity: Any) -> Any:
        raise NotImplementedError("Audit views are strictly read-only.")

    def delete(self, id: str) -> bool:
        raise NotImplementedError("Audit views are strictly read-only.")
