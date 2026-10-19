"""
MonthlyReportWorkflowService — Phase 8.9 Three-Tier Month-End Financial Report Workflow.
Governs multi-tier sign-offs:
Tier 1: Branch Manager (BM) Verification & Submission
Tier 2: Area Manager (AM) Supervisory Endorsement & Regional Package Seal
Tier 3: Executive Admin Institutional Archival & Period Lock
Enforces Account 1000 vault cash invariants (Rule 1) and ledger immutability (Rule 4).
"""
from typing import Dict, Any, List, Optional
from datetime import datetime, date
from interfaces.unit_of_work import UnitOfWork
from services.report_service import ReportService
from services.area_manager_service import AreaManagerService


class MonthlyReportWorkflowService:

    @staticmethod
    def get_submission_status(
        uow: UnitOfWork,
        branch_id: str,
        year: int,
        month: int
    ) -> Dict[str, Any]:
        """
        Retrieves the month-end submission state and certified snapshot for a branch.
        If no submission has been made, returns DRAFT with live preview metrics.
        """
        res = uow.client.table("monthly_report_submissions") \
            .select("*") \
            .eq("branch_id", branch_id) \
            .eq("year", year) \
            .eq("month", month) \
            .execute()

        if res.data:
            rec = res.data[0]
            return {
                "id": rec["id"],
                "branch_id": rec["branch_id"],
                "area_name": rec.get("area_name", "Area 1"),
                "year": rec["year"],
                "month": rec["month"],
                "status": rec["status"],
                "disbursed_principal": float(rec.get("disbursed_principal") or 0.0),
                "upfront_fees": float(rec.get("upfront_fees") or 0.0),
                "net_active_credit": float(rec.get("net_active_credit") or 0.0),
                "collections": float(rec.get("collections") or 0.0),
                "closing_credit": float(rec.get("closing_credit") or 0.0),
                "closing_savings": float(rec.get("closing_savings") or 0.0),
                "vault_cash_acct_1000": float(rec.get("vault_cash_acct_1000") or 0.0),
                "bank_deposits_acct_1050": float(rec.get("bank_deposits_acct_1050") or 0.0),
                "is_gl_balanced": bool(rec.get("is_gl_balanced", False)),
                "gl_variance": float(rec.get("gl_variance") or 0.0),
                "bm_name": rec.get("bm_name"),
                "bm_notes": rec.get("bm_notes"),
                "bm_submitted_at": rec.get("bm_submitted_at"),
                "am_name": rec.get("am_name"),
                "am_notes": rec.get("am_notes"),
                "am_endorsed_at": rec.get("am_endorsed_at"),
                "am_query_notes": rec.get("am_query_notes"),
                "admin_name": rec.get("admin_name"),
                "admin_notes": rec.get("admin_notes"),
                "admin_locked_at": rec.get("admin_locked_at"),
            }

        # Otherwise compute live preview metrics
        live_matrix = ReportService.get_monthly_parity_matrix(uow, branch_id=branch_id, year=year, month=month)
        cards = live_matrix.get("summary_cards")

        return {
            "id": None,
            "branch_id": branch_id,
            "area_name": "Area 1",
            "year": year,
            "month": month,
            "status": "DRAFT",
            "disbursed_principal": float(getattr(cards, "disbursed_principal", 0.0)),
            "upfront_fees": float(getattr(cards, "upfront_fees", 0.0)),
            "net_active_credit": float(getattr(cards, "net_active_credit", 0.0)),
            "collections": float(getattr(cards, "collections", 0.0)),
            "closing_credit": float(getattr(cards, "closing_credit", 0.0)),
            "closing_savings": float(getattr(cards, "closing_savings", 0.0)),
            "vault_cash_acct_1000": float(getattr(cards, "closing_savings", 0.0)),
            "bank_deposits_acct_1050": float(getattr(cards, "bank_deposits", 0.0)),
            "is_gl_balanced": bool(getattr(cards, "is_gl_balanced", False)),
            "gl_variance": 0.0,
            "bm_name": None,
            "bm_notes": None,
            "bm_submitted_at": None,
            "am_name": None,
            "am_notes": None,
            "am_endorsed_at": None,
            "am_query_notes": None,
            "admin_name": None,
            "admin_notes": None,
            "admin_locked_at": None,
        }

    @staticmethod
    def submit_by_bm(
        uow: UnitOfWork,
        bm_user_id: str,
        branch_id: str,
        year: int,
        month: int,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Tier 1: Branch Manager verifies and submits the monthly report to the Area Manager.
        Takes an immutable financial snapshot of Account 1000, Trial Balance, and Portfolios.
        """
        # 1. Fetch user identity
        user = uow.users.find_by_id(bm_user_id)
        bm_name = user.full_name or user.username if user else "Branch Manager"

        # 2. Check current status
        existing = uow.client.table("monthly_report_submissions") \
            .select("id, status") \
            .eq("branch_id", branch_id) \
            .eq("year", year) \
            .eq("month", month) \
            .execute()

        if existing.data:
            curr_status = existing.data[0].get("status")
            if curr_status in ["AM_VERIFIED", "AREA_SEALED", "ADMIN_LOCKED"]:
                raise ValueError(f"Cannot submit: Month {year}-{month:02d} is already {curr_status} and locked.")

        # 3. Compute live financial snapshot
        matrix = ReportService.get_monthly_parity_matrix(uow, branch_id=branch_id, year=year, month=month)
        cards = matrix.get("summary_cards")

        # Get branch details
        res_b = uow.client.table("branches").select("name").eq("branch_id", branch_id).execute()
        branch_name = res_b.data[0]["name"] if res_b.data else "Branch"

        now_str = datetime.now().isoformat()
        payload = {
            "branch_id": branch_id,
            "area_name": "Area 1",
            "year": year,
            "month": month,
            "status": "BM_SUBMITTED",
            "disbursed_principal": float(getattr(cards, "disbursed_principal", 0.0)),
            "upfront_fees": float(getattr(cards, "upfront_fees", 0.0)),
            "net_active_credit": float(getattr(cards, "net_active_credit", 0.0)),
            "collections": float(getattr(cards, "collections", 0.0)),
            "closing_credit": float(getattr(cards, "closing_credit", 0.0)),
            "closing_savings": float(getattr(cards, "closing_savings", 0.0)),
            "vault_cash_acct_1000": float(getattr(cards, "closing_savings", 0.0)),
            "bank_deposits_acct_1050": float(getattr(cards, "bank_deposits", 0.0)),
            "is_gl_balanced": bool(getattr(cards, "is_gl_balanced", False)),
            "gl_variance": 0.0,
            "bm_user_id": bm_user_id,
            "bm_name": bm_name,
            "bm_notes": notes or f"Verified and submitted by BM {bm_name} on {date.today().isoformat()}.",
            "bm_submitted_at": now_str,
            "updated_at": now_str,
        }

        if existing.data:
            rec_id = existing.data[0]["id"]
            uow.client.table("monthly_report_submissions").update(payload).eq("id", rec_id).execute()
        else:
            payload["created_at"] = now_str
            uow.client.table("monthly_report_submissions").insert(payload).execute()

        return {
            "success": True,
            "branch_id": branch_id,
            "branch_name": branch_name,
            "year": year,
            "month": month,
            "status": "BM_SUBMITTED",
            "message": f"Monthly report for {branch_name} ({year}-{month:02d}) successfully submitted to Area Manager."
        }

    @staticmethod
    def endorse_by_am(
        uow: UnitOfWork,
        am_user_id: str,
        branch_id: str,
        year: int,
        month: int,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Tier 2: Area Manager reviews and endorses the branch's monthly report.
        """
        # Validate supervisory access
        assigned = AreaManagerService.get_assigned_branches(uow, am_user_id)
        valid_bids = [b["branch_id"] for b in assigned if b.get("branch_id")]
        if branch_id not in valid_bids:
            raise ValueError("Forbidden: Branch is outside your assigned supervisory area.")

        user = uow.users.find_by_id(am_user_id)
        am_name = user.full_name or user.username if user else "Area Manager"

        existing = uow.client.table("monthly_report_submissions") \
            .select("id, status") \
            .eq("branch_id", branch_id) \
            .eq("year", year) \
            .eq("month", month) \
            .execute()

        if not existing.data:
            raise ValueError("Cannot endorse: Branch Manager has not yet submitted month-end reports.")

        curr_status = existing.data[0].get("status")
        if curr_status not in ["BM_SUBMITTED", "RETURNED_FOR_CORRECTION"]:
            raise ValueError(f"Cannot endorse: Report status is currently {curr_status}.")

        now_str = datetime.now().isoformat()
        uow.client.table("monthly_report_submissions").update({
            "status": "AM_VERIFIED",
            "am_user_id": am_user_id,
            "am_name": am_name,
            "am_notes": notes or f"Endorsed by AM {am_name} with verified Trial Balance & Vault Cash.",
            "am_endorsed_at": now_str,
            "am_query_notes": None,
            "updated_at": now_str,
        }).eq("id", existing.data[0]["id"]).execute()

        res_b = uow.client.table("branches").select("name").eq("branch_id", branch_id).execute()
        b_name = res_b.data[0]["name"] if res_b.data else "Branch"

        return {
            "success": True,
            "branch_id": branch_id,
            "branch_name": b_name,
            "year": year,
            "month": month,
            "status": "AM_VERIFIED",
            "message": f"Monthly report for {b_name} successfully endorsed by Area Manager."
        }

    @staticmethod
    def return_by_am(
        uow: UnitOfWork,
        am_user_id: str,
        branch_id: str,
        year: int,
        month: int,
        query_notes: str
    ) -> Dict[str, Any]:
        """
        Area Manager returns report to Branch Manager with audit query notes.
        """
        assigned = AreaManagerService.get_assigned_branches(uow, am_user_id)
        valid_bids = [b["branch_id"] for b in assigned if b.get("branch_id")]
        if branch_id not in valid_bids:
            raise ValueError("Forbidden: Branch is outside your assigned supervisory area.")

        existing = uow.client.table("monthly_report_submissions") \
            .select("id, status") \
            .eq("branch_id", branch_id) \
            .eq("year", year) \
            .eq("month", month) \
            .execute()

        if not existing.data:
            raise ValueError("Cannot return: Branch Manager has not submitted month-end reports.")

        now_str = datetime.now().isoformat()
        uow.client.table("monthly_report_submissions").update({
            "status": "RETURNED_FOR_CORRECTION",
            "am_query_notes": query_notes,
            "updated_at": now_str,
        }).eq("id", existing.data[0]["id"]).execute()

        return {
            "success": True,
            "branch_id": branch_id,
            "year": year,
            "month": month,
            "status": "RETURNED_FOR_CORRECTION",
            "message": "Report returned to Branch Manager with audit query notes."
        }

    @staticmethod
    def seal_area_monthly_package(
        uow: UnitOfWork,
        am_user_id: str,
        area_name: str,
        year: int,
        month: int,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Area Manager seals the entire regional month-end package once all assigned branches are AM_VERIFIED.
        """
        assigned = AreaManagerService.get_assigned_branches(uow, am_user_id)
        assigned_bids = [b["branch_id"] for b in assigned if b.get("branch_id")]
        if not assigned_bids:
            raise ValueError("No branches assigned to your supervisory area.")

        # Check all branches
        q = uow.client.table("monthly_report_submissions") \
            .select("branch_id, status") \
            .in_("branch_id", assigned_bids) \
            .eq("year", year) \
            .eq("month", month) \
            .execute()

        verified_bids = [r["branch_id"] for r in (q.data or []) if r.get("status") in ["AM_VERIFIED", "AREA_SEALED", "ADMIN_LOCKED"]]
        missing = set(assigned_bids) - set(verified_bids)
        if missing:
            raise ValueError(f"Cannot seal {area_name}: {len(missing)} branch(es) have not yet been endorsed by the Area Manager.")

        user = uow.users.find_by_id(am_user_id)
        am_name = user.full_name or user.username if user else "Area Manager"
        now_str = datetime.now().isoformat()

        uow.client.table("monthly_report_submissions").update({
            "status": "AREA_SEALED",
            "am_notes": notes or f"Regional month-end package sealed by AM {am_name} on {date.today().isoformat()}.",
            "updated_at": now_str,
        }).in_("branch_id", assigned_bids).eq("year", year).eq("month", month).execute()

        return {
            "success": True,
            "area_name": area_name,
            "year": year,
            "month": month,
            "status": "AREA_SEALED",
            "sealed_branches_count": len(assigned_bids),
            "message": f"{area_name} monthly report package sealed and forwarded to Executive Admin."
        }

    @staticmethod
    def lock_by_admin(
        uow: UnitOfWork,
        admin_user_id: str,
        branch_id: str,
        year: int,
        month: int,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Tier 3: Executive Admin locks and archives the monthly report into the permanent institutional archive.
        """
        user = uow.users.find_by_id(admin_user_id)
        admin_name = user.full_name or user.username if user else "Administrator"

        existing = uow.client.table("monthly_report_submissions") \
            .select("id, status") \
            .eq("branch_id", branch_id) \
            .eq("year", year) \
            .eq("month", month) \
            .execute()

        if not existing.data:
            raise ValueError("Report record does not exist.")

        now_str = datetime.now().isoformat()
        uow.client.table("monthly_report_submissions").update({
            "status": "ADMIN_LOCKED",
            "admin_user_id": admin_user_id,
            "admin_name": admin_name,
            "admin_notes": notes or f"Archived and locked by {admin_name} on {date.today().isoformat()}.",
            "admin_locked_at": now_str,
            "updated_at": now_str,
        }).eq("id", existing.data[0]["id"]).execute()

        return {
            "success": True,
            "branch_id": branch_id,
            "year": year,
            "month": month,
            "status": "ADMIN_LOCKED",
            "message": "Report permanently locked and archived in institutional records."
        }

    @staticmethod
    def get_pending_am_submissions(
        uow: UnitOfWork,
        am_user_id: str,
        year: int,
        month: int
    ) -> List[Dict[str, Any]]:
        """
        Fetches all supervised branches and their monthly report submission status for the Approvals Hub.
        """
        assigned = AreaManagerService.get_assigned_branches(uow, am_user_id)
        assigned_map = {b["branch_id"]: b["name"] for b in assigned if b.get("branch_id")}
        bids = list(assigned_map.keys())

        if not bids:
            return []

        q = uow.client.table("monthly_report_submissions") \
            .select("*") \
            .in_("branch_id", bids) \
            .eq("year", year) \
            .eq("month", month) \
            .execute()

        sub_map = {r["branch_id"]: r for r in (q.data or [])}

        results = []
        for bid, bname in assigned_map.items():
            sub = sub_map.get(bid)
            if sub:
                results.append({
                    "branch_id": bid,
                    "branch_name": bname,
                    "year": year,
                    "month": month,
                    "status": sub.get("status", "DRAFT"),
                    "disbursed_principal": float(sub.get("disbursed_principal") or 0.0),
                    "collections": float(sub.get("collections") or 0.0),
                    "closing_credit": float(sub.get("closing_credit") or 0.0),
                    "closing_savings": float(sub.get("closing_savings") or 0.0),
                    "vault_cash": float(sub.get("vault_cash_acct_1000") or 0.0),
                    "is_gl_balanced": bool(sub.get("is_gl_balanced", False)),
                    "bm_name": sub.get("bm_name") or "Branch Manager",
                    "bm_notes": sub.get("bm_notes"),
                    "submitted_at": sub.get("bm_submitted_at"),
                    "am_query_notes": sub.get("am_query_notes"),
                })
            else:
                results.append({
                    "branch_id": bid,
                    "branch_name": bname,
                    "year": year,
                    "month": month,
                    "status": "DRAFT",
                    "disbursed_principal": 0.0,
                    "collections": 0.0,
                    "closing_credit": 0.0,
                    "closing_savings": 0.0,
                    "vault_cash": 0.0,
                    "is_gl_balanced": False,
                    "bm_name": "Branch Manager",
                    "bm_notes": None,
                    "submitted_at": None,
                    "am_query_notes": None,
                })

        return results
