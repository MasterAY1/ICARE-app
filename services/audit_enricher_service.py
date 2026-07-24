"""
AuditEnricher — Phase 8.4 Executive Banking Experience & Presentation Enrichment
Resolves raw UUIDs and foreign keys into business-friendly codes and names:
- client_id -> Client Code (e.g. OGI-12-005) & Client Name (e.g. Adewale Musa)
- branch_id -> Branch Name (e.g. Ijebu Ode Branch)
- officer_id -> Officer Name (e.g. Adenuga Ayomide)
- product_id -> Product Name (e.g. Micro Business Loan)

Enforces strict commercial banking presentation rules:
- Currency always formatted as ₦45,000.00
- Dates always formatted as 24 Jul 2026
- Statuses formatted as clean executive badges (🟢 Paid, 🟡 Part Payment, 🔴 Not Paid)
"""

from typing import List, Dict, Any, Optional
from datetime import datetime, date


class AuditEnricher:
    """High-performance lookup enricher for executive audit reporting."""

    def __init__(self, uow=None):
        self.uow = uow
        self._clients_by_id: Dict[str, Dict[str, str]] = {}
        self._clients_by_code: Dict[str, Dict[str, str]] = {}
        self._branches_by_id: Dict[str, str] = {}
        self._users_by_id: Dict[str, str] = {}
        self._users_by_username: Dict[str, str] = {}
        self._products_by_id: Dict[str, str] = {}
        self._is_loaded = False

    def load_lookups(self):
        """Load lookup dictionaries from database for instant memory resolution."""
        if self._is_loaded:
            return

        db_client = getattr(self.uow, 'client', None) if hasattr(self.uow, 'client') else None

        # 1. Load Clients
        try:
            if db_client:
                res = db_client.table("clients").select("client_id, client_code, name").execute()
                for c in (res.data or []):
                    c_id = c.get("client_id")
                    code = c.get("client_code") or c_id or "UNKNOWN"
                    name = c.get("name") or "Unknown Client"
                    entry = {"code": code, "name": name, "full_label": f"{code} — {name}"}
                    if c_id:
                        self._clients_by_id[str(c_id)] = entry
                    if code:
                        self._clients_by_code[str(code)] = entry
        except Exception:
            pass

        # 2. Load Branches
        try:
            if db_client:
                res_b = db_client.table("branches").select("branch_id, name, code").execute()
                for b in (res_b.data or []):
                    b_id = b.get("branch_id")
                    b_name = b.get("name") or b.get("code") or "Unknown Branch"
                    if b_id:
                        self._branches_by_id[str(b_id)] = b_name
        except Exception:
            pass

        # 3. Load App Users (Officers)
        try:
            if db_client:
                res_u = db_client.table("app_users").select("id, username, full_name").execute()
                for u in (res_u.data or []):
                    u_id = u.get("id")
                    uname = u.get("username")
                    fname = u.get("full_name") or uname or "Unassigned"
                    if u_id:
                        self._users_by_id[str(u_id)] = fname
                    if uname:
                        self._users_by_username[str(uname)] = fname
        except Exception:
            pass

        # 4. Load Loan Products
        try:
            if db_client:
                res_p = db_client.table("loan_products").select("product_id, name").execute()
                for p in (res_p.data or []):
                    p_id = p.get("product_id")
                    p_name = p.get("name") or "Standard Loan"
                    if p_id:
                        self._products_by_id[str(p_id)] = p_name
        except Exception:
            pass

        self._is_loaded = True

    # -------------------------------------------------------------------------
    # Individual Resolution Helpers
    # -------------------------------------------------------------------------

    def resolve_client(self, client_id_raw: Optional[str]) -> Dict[str, str]:
        """Resolves raw client_id or client_code to {code, name, full_label}."""
        if not client_id_raw or str(client_id_raw) in ["None", "null", ""]:
            return {"code": "N/A", "name": "N/A", "full_label": "N/A"}

        cid = str(client_id_raw).strip()
        if cid in self._clients_by_id:
            return self._clients_by_id[cid]
        if cid in self._clients_by_code:
            return self._clients_by_code[cid]

        if "-" in cid and len(cid) < 20:
            return {"code": cid, "name": cid, "full_label": cid}

        short_id = cid[:8] + "..." if len(cid) > 12 else cid
        return {"code": short_id, "name": "Client (" + short_id + ")", "full_label": short_id}

    def resolve_branch(self, branch_id_raw: Optional[str]) -> str:
        """Resolves raw branch_id to Branch Name."""
        if not branch_id_raw or str(branch_id_raw) in ["None", "null", ""]:
            return "Head Office"

        bid = str(branch_id_raw).strip()
        if bid in self._branches_by_id:
            return self._branches_by_id[bid]

        if len(bid) < 30 and not bid.count("-") == 4:
            return bid

        return "Branch (" + bid[:8] + ")"

    def resolve_officer(self, officer_id_raw: Optional[str]) -> str:
        """Resolves raw officer_id or username to Officer Full Name."""
        if not officer_id_raw or str(officer_id_raw) in ["None", "null", "", "00000000-0000-0000-0000-000000000000"]:
            return "Unassigned"

        oid = str(officer_id_raw).strip()
        if oid in self._users_by_id:
            return self._users_by_id[oid]
        if oid in self._users_by_username:
            return self._users_by_username[oid]

        if len(oid) < 25 and not oid.count("-") == 4:
            return oid

        return "Officer (" + oid[:8] + ")"

    def resolve_product(self, product_id_raw: Optional[str]) -> str:
        """Resolves raw product_id to Loan Product Name."""
        if not product_id_raw or str(product_id_raw) in ["None", "null", ""]:
            return "General Loan"

        pid = str(product_id_raw).strip()
        if pid in self._products_by_id:
            return self._products_by_id[pid]

        if len(pid) < 25 and not pid.count("-") == 4:
            return pid

        return "Product (" + pid[:8] + ")"

    @staticmethod
    def format_currency(val: Any) -> str:
        """Format monetary value as ₦X,XXX.XX."""
        try:
            amt = float(val or 0)
            return f"₦{amt:,.2f}"
        except (ValueError, TypeError):
            return "₦0.00"

    @staticmethod
    def format_date(date_val: Any) -> str:
        """Format date into clean business format: 24 Jul 2026."""
        if not date_val:
            return "N/A"
        try:
            if isinstance(date_val, (date, datetime)):
                return date_val.strftime("%d %b %Y")
            s = str(date_val).split("T")[0]
            dt = datetime.strptime(s, "%Y-%m-%d")
            return dt.strftime("%d %b %Y")
        except Exception:
            return str(date_val)[:10]

    @staticmethod
    def format_status_badge(status_raw: Any) -> str:
        """Return executive color status badge: 🟢 Paid, 🟡 Part Payment, 🔴 Not Paid."""
        if not status_raw:
            return "🟡 Pending"

        st_str = str(status_raw).upper().strip()
        if st_str in ["PAID", "ACTIVE", "DISBURSED", "APPROVED", "COMPLETED", "CLOSED", "SUCCESS", "PERFECT_MATCH", "BALANCED", "100%"]:
            return "🟢 Paid" if st_str == "PAID" else ("🟢 Approved" if st_str == "APPROVED" else f"🟢 {status_raw.capitalize() if isinstance(status_raw, str) else status_raw}")
        elif st_str in ["PART_PAYMENT", "PENDING", "REVIEW", "UNDER_REVIEW", "PARTIAL", "PARTIAL_MATCH", "50%"]:
            return "🟡 Part Payment" if st_str == "PART_PAYMENT" else ("🟡 Pending" if st_str == "PENDING" else f"🟡 {status_raw.capitalize() if isinstance(status_raw, str) else status_raw}")
        elif st_str in ["NOT_PAID", "OVERDUE", "REJECTED", "DEFAULTER", "MISMATCH", "FAILED", "0%"]:
            return "🔴 Not Paid" if st_str == "NOT_PAID" else ("🔴 Rejected" if st_str == "REJECTED" else f"🔴 {status_raw.capitalize() if isinstance(status_raw, str) else status_raw}")

        return f"🔵 {status_raw}"

    # -------------------------------------------------------------------------
    # Batch Record Sets Enrichment
    # -------------------------------------------------------------------------

    def enrich_fee_records(self, records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enrich raw fee records for executive reporting."""
        self.load_lookups()
        enriched = []
        for r in records:
            client_info = self.resolve_client(r.get("client_id"))
            amount = float(r.get("amount") or r.get("fee_amount") or 0)
            row = {
                "Date": self.format_date(r.get("posting_date") or r.get("created_at")),
                "Client Code": client_info["code"],
                "Client Name": client_info["name"],
                "Fee Type": r.get("fee_type") or "FEE",
                "Amount": self.format_currency(amount),
                "Amount_Raw": amount,
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": self.resolve_branch(r.get("branch_id")),
                "Reference": r.get("reference") or r.get("id") or "N/A",
                "Status": self.format_status_badge("PAID"),
                "_raw_record": r
            }
            enriched.append(row)
        return enriched

    def enrich_treasury_records(self, records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enrich raw treasury records for executive reporting."""
        self.load_lookups()
        enriched = []
        for r in records:
            amount = float(r.get("amount") or 0)
            row = {
                "Date": self.format_date(r.get("posting_date") or r.get("created_at")),
                "Category": r.get("transaction_type") or "TREASURY",
                "Amount": self.format_currency(amount),
                "Amount_Raw": amount,
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": self.resolve_branch(r.get("branch_id")),
                "Reference": r.get("reference") or r.get("id") or "N/A",
                "Narration": r.get("narration") or r.get("remarks") or "Treasury transaction",
                "Status": self.format_status_badge("COMPLETED"),
                "_raw_record": r
            }
            enriched.append(row)
        return enriched

    def enrich_savings_records(self, records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enrich raw savings records for executive reporting."""
        self.load_lookups()
        enriched = []
        for r in records:
            client_info = self.resolve_client(r.get("client_id") or r.get("group_id"))
            dep = float(r.get("deposit_amount") or 0)
            wth = float(r.get("withdrawal_amount") or 0)
            bal = float(r.get("balance") or (dep - wth))
            row = {
                "Date": self.format_date(r.get("posting_date") or r.get("created_at")),
                "Client Code": client_info["code"],
                "Client Name": client_info["name"],
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": self.resolve_branch(r.get("branch_id")),
                "Deposit": self.format_currency(dep),
                "Withdrawal": self.format_currency(wth),
                "Balance": self.format_currency(bal),
                "Deposit_Raw": dep,
                "Withdrawal_Raw": wth,
                "Status": self.format_status_badge("ACTIVE"),
                "_raw_record": r
            }
            enriched.append(row)
        return enriched

    def enrich_loan_records(self, records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enrich raw loan disbursement records for executive reporting."""
        self.load_lookups()
        enriched = []
        for r in records:
            client_info = self.resolve_client(r.get("client_id"))
            principal = float(r.get("amount") or r.get("principal") or 0)
            loan_code = r.get("loan_code") or ("LN-" + str(r.get("id"))[:8] if r.get("id") else "LN-N/A")
            row = {
                "Disbursement Date": self.format_date(r.get("date") or r.get("disbursement_date") or r.get("created_at")),
                "Loan Number": loan_code,
                "Client Code": client_info["code"],
                "Client Name": client_info["name"],
                "Product": self.resolve_product(r.get("product_id")),
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": self.resolve_branch(r.get("branch_id")),
                "Principal": self.format_currency(principal),
                "Principal_Raw": principal,
                "Status": self.format_status_badge(r.get("status") or "Disbursed"),
                "_raw_record": r
            }
            enriched.append(row)
        return enriched

    def enrich_repayment_records(self, records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enrich raw loan repayment records for executive reporting."""
        self.load_lookups()
        enriched = []
        for r in records:
            client_info = self.resolve_client(r.get("client_id"))
            paid = float(r.get("amount_paid") or r.get("amount") or 0)
            row = {
                "Repayment Date": self.format_date(r.get("date") or r.get("created_at")),
                "Client Code": client_info["code"],
                "Client Name": client_info["name"],
                "Amount Paid": self.format_currency(paid),
                "Amount_Raw": paid,
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": self.resolve_branch(r.get("branch_id")),
                "Transaction Type": r.get("transaction_type") or "Repayment",
                "Status": self.format_status_badge("PAID"),
                "_raw_record": r
            }
            enriched.append(row)
        return enriched

    def enrich_collection_records(self, records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enrich raw collection performance records for executive reporting."""
        self.load_lookups()
        enriched = []
        for r in records:
            client_info = self.resolve_client(r.get("client_id"))
            expected = float(r.get("expected_amount") or 0)
            paid = float(r.get("collected_amount") or r.get("amount_paid") or 0)
            ratio = (paid / expected * 100) if expected > 0 else (100.0 if paid > 0 else 0.0)
            status_tag = "PAID" if ratio >= 99.0 else ("PART_PAYMENT" if ratio > 0 else "NOT_PAID")

            row = {
                "Meeting Date": self.format_date(r.get("meeting_date") or r.get("created_at")),
                "Client Code": client_info["code"],
                "Client Name": client_info["name"],
                "Group": r.get("group_name") or r.get("group_id") or "Individual",
                "Expected": self.format_currency(expected),
                "Paid": self.format_currency(paid),
                "Compliance %": f"{ratio:.1f}%",
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": self.resolve_branch(r.get("branch_id")),
                "Status": self.format_status_badge(status_tag),
                "_raw_record": r
            }
            enriched.append(row)
        return enriched
