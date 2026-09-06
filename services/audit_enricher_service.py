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


CHART_OF_ACCOUNTS_MAP: Dict[str, str] = {
    "1000": "Vault Cash",
    "1010": "Main Vault",
    "1020": "Branch Vault",
    "1050": "Bank",
    "1200": "Loan Portfolio",
    "1300": "Asset Inventory",
    "2000": "Individual Deposits",
    "2010": "Group Deposits",
    "2020": "Internal Savings",
    "2030": "LAPS Savings",
    "3000": "Fee Income",
    "3100": "Head Office Capital",
    "3200": "Asset Sales",
    "4000": "Office Expenses",
    "4100": "Salary Expenses"
}


class AuditEnricher:
    """High-performance lookup enricher for executive audit reporting."""

    def __init__(self, uow=None):
        self.uow = uow
        self._clients_by_id: Dict[str, Dict[str, str]] = {}
        self._clients_by_code: Dict[str, Dict[str, str]] = {}
        self._client_branches: Dict[str, str] = {}
        self._officer_branches: Dict[str, str] = {}
        self._groups_by_id: Dict[str, Dict[str, str]] = {}
        self._loans_by_id: Dict[str, Dict[str, Any]] = {}
        self._branches_by_id: Dict[str, str] = {}
        self._users_by_id: Dict[str, str] = {}
        self._users_by_username: Dict[str, str] = {}
        self._products_by_id: Dict[str, str] = {}
        self._chart_of_accounts: Dict[str, str] = dict(CHART_OF_ACCOUNTS_MAP)
        self._is_loaded = False

    def load_lookups(self):
        """Load lookup dictionaries from database for instant memory resolution."""
        if self._is_loaded:
            return

        db_client = getattr(self.uow, 'client', None) if hasattr(self.uow, 'client') else None

        # 1. Load Clients
        try:
            if db_client:
                res = db_client.table("clients").select("client_id, client_code, name, branch_id, group_id").execute()
                for c in (res.data or []):
                    c_id = c.get("client_id")
                    code = c.get("client_code") or c_id or "UNKNOWN"
                    name = c.get("name") or "Unknown Client"
                    entry = {
                        "code": code,
                        "name": name,
                        "full_label": f"{code} — {name}",
                        "branch_id": c.get("branch_id"),
                        "group_id": c.get("group_id")
                    }
                    if c_id:
                        self._clients_by_id[str(c_id)] = entry
                        if c.get("branch_id"):
                            self._client_branches[str(c_id)] = str(c["branch_id"])
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
                res_u = db_client.table("app_users").select("id, username, full_name, branch_id").execute()
                for u in (res_u.data or []):
                    u_id = u.get("id")
                    uname = u.get("username")
                    fname = u.get("full_name") or uname or "Unassigned"
                    if u_id:
                        self._users_by_id[str(u_id)] = fname
                        if u.get("branch_id"):
                            self._officer_branches[str(u_id)] = str(u["branch_id"])
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

        # 5. Load Groups
        try:
            if db_client:
                res_g = db_client.table("groups").select("group_id, name, group_code").execute()
                for g in (res_g.data or []):
                    g_id = g.get("group_id")
                    g_name = g.get("name") or "Unnamed Group"
                    g_code = g.get("group_code") or "GRP-N/A"
                    if g_id:
                        self._groups_by_id[str(g_id)] = {"code": g_code, "name": g_name}
        except Exception:
            pass

        # 6. Load Loans
        try:
            if db_client:
                res_l = db_client.table("loans").select("loan_id, product_id, client_id, loan_amount").execute()
                for l in (res_l.data or []):
                    l_id = l.get("loan_id")
                    if l_id:
                        self._loans_by_id[str(l_id)] = l
        except Exception:
            pass

        # 7. Load Chart of Accounts
        try:
            if db_client:
                res_coa = db_client.table("chart_of_accounts").select("account_code, account_name").execute()
                for a in (res_coa.data or []):
                    code = str(a.get("account_code", "")).strip()
                    name = a.get("account_name")
                    if code and name:
                        self._chart_of_accounts[code] = name
        except Exception:
            pass

        self._is_loaded = True

    # -------------------------------------------------------------------------
    # Individual Resolution Helpers
    # -------------------------------------------------------------------------

    def resolve_group(self, group_id_raw: Optional[str]) -> Dict[str, str]:
        """Resolves raw group_id to {code, name}."""
        if not group_id_raw or str(group_id_raw) in ["None", "null", ""]:
            return {"code": "N/A", "name": "N/A"}
        gid = str(group_id_raw).strip()
        if gid in self._groups_by_id:
            return self._groups_by_id[gid]
        return {"code": f"GRP-{gid[:6]}", "name": f"Group ({gid[:6]})"}

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

    def resolve_branch(self, branch_id_raw: Optional[str], officer_id: Optional[str] = None, client_id: Optional[str] = None) -> str:
        """Resolves raw branch_id to Branch Name, falling back to officer or client branch if missing."""
        bid = str(branch_id_raw).strip() if branch_id_raw else ""
        if not bid or bid in ["None", "null", ""]:
            if officer_id and str(officer_id) in self._officer_branches:
                bid = self._officer_branches[str(officer_id)]
            elif client_id and str(client_id) in self._client_branches:
                bid = self._client_branches[str(client_id)]
            else:
                return "Unassigned"

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

    def resolve_account(self, account_code_raw: Any) -> str:
        """Resolves account code to friendly Name (e.g. 1000 -> 1000 — Vault Cash)."""
        code = str(account_code_raw or "").strip()
        if not code:
            return "General Account"
        name = self._chart_of_accounts.get(code) or CHART_OF_ACCOUNTS_MAP.get(code)
        if name:
            return f"{code} — {name}"
        return f"Account {code}"

    @staticmethod
    def clean_reference(ref_raw: Any, prefix: str = "REF") -> str:
        """Formats references cleanly; replaces raw 36-character UUIDs with human-readable references."""
        if not ref_raw or str(ref_raw) in ["None", "null", ""]:
            return "N/A"
        s = str(ref_raw).strip()
        if len(s) == 36 and s.count("-") == 4:
            return f"{prefix}-{s[:8].upper()}"
        return s

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
            s = str(date_val).replace("T", " ").split(" ")[0].strip()
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
                "Branch": self.resolve_branch(r.get("branch_id"), officer_id=r.get("officer_id"), client_id=r.get("client_id")),
                "Reference": self.clean_reference(r.get("reference") or r.get("id"), prefix="FEE"),
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
                "Branch": self.resolve_branch(r.get("branch_id"), officer_id=r.get("officer_id")),
                "Reference": self.clean_reference(r.get("reference") or r.get("id"), prefix="TR"),
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
            ledger_type = r.get("_ledger_type") or "Savings"
            c_id = r.get("client_id")
            g_id = r.get("group_id")

            if c_id:
                client_info = self.resolve_client(c_id)
                code_disp = client_info["code"]
                name_disp = client_info["name"]
            elif g_id:
                grp_info = self.resolve_group(g_id)
                code_disp = grp_info["code"]
                name_disp = grp_info["name"]
            else:
                code_disp = "BRANCH-MISC" if ledger_type == "Misc Savings" else "N/A"
                name_disp = "Branch Internal Misc Savings" if ledger_type == "Misc Savings" else "Global Savings Pool"

            dep = float(r.get("deposit_amount") or 0)
            wth = float(r.get("withdrawal_amount") or 0)
            bal = float(r.get("balance") or (dep - wth))
            row = {
                "Date": self.format_date(r.get("posting_date") or r.get("created_at")),
                "Ledger": ledger_type,
                "Client Code": code_disp,
                "Client Name": name_disp,
                "Remarks": r.get("remarks") or r.get("reference") or ("Deposit" if dep > 0 else "Withdrawal"),
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": self.resolve_branch(r.get("branch_id"), officer_id=r.get("officer_id"), client_id=r.get("client_id")),
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
            principal = float(r.get("loan_amount") or r.get("amount") or r.get("principal") or 0)
            l_identifier = r.get("loan_id") or r.get("id") or ""
            loan_code = r.get("loan_code") or r.get("loan_number") or (f"LN-{str(l_identifier)[:8]}" if l_identifier else "LN-N/A")
            row = {
                "Disbursement Date": self.format_date(r.get("date") or r.get("disbursement_date") or r.get("created_at")),
                "Loan Number": loan_code,
                "Client Code": client_info["code"],
                "Client Name": client_info["name"],
                "Product": self.resolve_product(r.get("product_id")),
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": self.resolve_branch(r.get("branch_id"), officer_id=r.get("officer_id"), client_id=r.get("client_id")),
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
            l_id = str(r.get("loan_id") or "")
            loan_info = self._loans_by_id.get(l_id, {})
            p_id = loan_info.get("product_id") or r.get("product_id")
            loan_code = f"LN-{l_id[:8]}" if l_id and l_id != "None" else "LN-N/A"
            row = {
                "Repayment Date": self.format_date(r.get("date") or r.get("created_at")),
                "Loan Number": loan_code,
                "Client Code": client_info["code"],
                "Client Name": client_info["name"],
                "Product": self.resolve_product(p_id),
                "Amount Paid": self.format_currency(paid),
                "Amount_Raw": paid,
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": self.resolve_branch(r.get("branch_id"), officer_id=r.get("officer_id"), client_id=r.get("client_id")),
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

            grp_name = r.get("group_name")
            if not grp_name or str(grp_name) in ["None", "null", ""]:
                gid = r.get("group_id") or client_info.get("group_id")
                if gid:
                    grp_res = self.resolve_group(gid)
                    grp_name = grp_res.get("name")
            if not grp_name or str(grp_name) in ["None", "null", "N/A"] or str(grp_name).startswith("Group (0000"):
                grp_name = "Individual"

            b_name = self.resolve_branch(
                r.get("branch_id"),
                officer_id=r.get("officer_id"),
                client_id=r.get("client_id")
            )

            row = {
                "Meeting Date": self.format_date(r.get("meeting_date") or r.get("date") or r.get("created_at")),
                "Client Code": client_info["code"],
                "Client Name": client_info["name"],
                "Group": grp_name,
                "Expected": self.format_currency(expected),
                "Paid": self.format_currency(paid),
                "Compliance %": f"{ratio:.1f}%",
                "Officer": self.resolve_officer(r.get("officer_id")),
                "Branch": b_name,
                "Status": self.format_status_badge(status_tag),
                "Expected_Raw": expected,
                "Paid_Raw": paid,
                "Status_Raw": status_tag,
                "_raw_record": r
            }
            enriched.append(row)
        return enriched

    def enrich_ledger_records(self, records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enrich raw general ledger transactions and double-entry legs for executive reporting."""
        self.load_lookups()
        enriched = []
        for tx in records:
            tx_id = str(tx.get("transaction_id") or tx.get("id") or "")
            ref_raw = tx.get("reference") or tx_id
            ref_disp = self.clean_reference(ref_raw, prefix="JNL")
            b_name = self.resolve_branch(tx.get("branch_id"), officer_id=tx.get("officer_id"))
            o_name = self.resolve_officer(tx.get("officer_id"))
            p_date = self.format_date(tx.get("posting_date") or tx.get("created_at"))

            entries = tx.get("financial_ledger_entries") or []
            if isinstance(entries, dict):
                entries = [entries]

            debits = [e for e in entries if str(e.get("entry_type") or "").upper() == "DEBIT"]
            credits = [e for e in entries if str(e.get("entry_type") or "").upper() == "CREDIT"]
            tot_debit = sum(float(e.get("amount") or 0.0) for e in debits)
            tot_credit = sum(float(e.get("amount") or 0.0) for e in credits)
            amt = tot_debit if tot_debit > 0 else (tot_credit if tot_credit > 0 else float(tx.get("amount") or 0.0))

            dr_unique = list(dict.fromkeys([self.resolve_account(e.get("account_number")) for e in debits]))
            cr_unique = list(dict.fromkeys([self.resolve_account(e.get("account_number")) for e in credits]))

            is_balanced = (abs(tot_debit - tot_credit) < 0.01) and (tot_debit > 0)
            if is_balanced:
                status_badge = "🟢 Balanced"
            elif tot_debit == 0 and tot_credit == 0 and amt == 0:
                status_badge = "🟡 Non-Monetary"
            else:
                status_badge = "🔴 Unbalanced"

            # Pre-enrich double-entry legs so consumers / UI do not need to do lookups
            enriched_legs = []
            for e in entries:
                etype = str(e.get("entry_type") or "").upper()
                e_amt = float(e.get("amount") or 0.0)
                acct_name = self.resolve_account(e.get("account_number"))
                enriched_legs.append({
                    "Journal Ref": ref_disp,
                    "Account": acct_name,
                    "Leg": "📥 DEBIT" if etype == "DEBIT" else "📤 CREDIT",
                    "Debit (₦)": self.format_currency(e_amt) if etype == "DEBIT" else "—",
                    "Credit (₦)": self.format_currency(e_amt) if etype == "CREDIT" else "—",
                    "Debit_Raw": e_amt if etype == "DEBIT" else 0.0,
                    "Credit_Raw": e_amt if etype == "CREDIT" else 0.0,
                    "Line Narration": e.get("narration") or tx.get("narration") or "—"
                })

            enriched.append({
                "Posting Date": p_date,
                "Journal Ref": ref_disp,
                "Narration": tx.get("narration") or "General Ledger Journal Entry",
                "Debit Account": ", ".join(dr_unique) if dr_unique else "N/A",
                "Credit Account": ", ".join(cr_unique) if cr_unique else "N/A",
                "Amount": self.format_currency(amt),
                "Amount_Raw": amt,
                "Branch": b_name,
                "Officer": o_name,
                "Status": status_badge,
                "_entries": enriched_legs,
                "_raw_record": tx
            })
        return enriched

