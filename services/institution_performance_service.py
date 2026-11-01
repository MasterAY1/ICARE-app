"""
services/institution_performance_service.py
Authoritative Multi-Pillar Performance Ranking Engine for Branches and Credit Officers.
Strict adherence to ICARE Governance Invariants:
1. Double-entry ledger truth (Account 1000 Vault Cash).
2. Permanent payoff and excess records (BR-DASH-005, public.loan_payoff_excess_records).
3. Overdue Recovery System (public.loan_overdue_recovery_records, Invariants 8 & 9).
4. Zero-Emoji corporate banking governance.
5. Abstracted technical rule identifiers.
"""
from datetime import date, timedelta
from typing import Dict, Any, List, Optional
from collections import defaultdict
from database.repositories.unit_of_work import UnitOfWork
from services.dashboard_service import DashboardService
from services.collection_performance_service import CollectionPerformanceService
from services.business_date_service import BusinessDateService


class InstitutionPerformanceService:
    """
    Computes institutional performance rankings across all branches and field officers.
    Uses a 6-Pillar Balanced Composite Scorecard (0–100 Points):
    - Pillar 1: Capital Deployment / Disbursement (20%)
    - Pillar 2: Delinquency & PAR Containment (25%)
    - Pillar 3: Overdue Debt Recovery & Rehabilitation (20%)
    - Pillar 4: Active Borrower Outreach & Retention (15%)
    - Pillar 5: Repayment Compliance Rate (10%)
    - Pillar 6: Vault & Operational Discipline (10%)
    """

    @classmethod
    def compute_institution_performance(
        cls,
        uow: UnitOfWork,
        year: int
    ) -> Dict[str, Any]:
        """
        Calculates consolidated institution performance including both branch rankings
        and officer rankings for a target year.
        """
        b_res = cls.get_branch_performance_rankings(uow, year)
        o_res = cls.get_officer_performance_rankings(uow, year)
        return {
            "year": year,
            "branch_performance": b_res,
            "officer_performance": o_res,
            "branch_rankings": b_res.get("rankings", []),
            "officer_rankings": o_res.get("rankings", [])
        }

    @classmethod
    def get_branch_performance_rankings(
        cls,
        uow: UnitOfWork,
        year: int
    ) -> Dict[str, Any]:
        """
        Calculates authoritative 1st-to-last branch performance rankings for a target year.
        """
        s_date = date(year, 1, 1).isoformat()
        e_date = min(date.today(), date(year, 12, 31)).isoformat()

        # 1. Fetch all branches
        branches_data = []
        try:
            res_branches = uow.client.table("branches").select("branch_id, name").execute()
            branches_data = res_branches.data or []
        except Exception:
            branches_data = []

        if not branches_data:
            try:
                res_lb = uow.client.table("loans").select("branch_id").limit(200).execute()
                seen_bids = set(str(r["branch_id"]) for r in (res_lb.data or []) if r.get("branch_id"))
                branches_data = [{"branch_id": bid, "name": f"Branch {bid[:6]}"} for bid in seen_bids]
            except Exception:
                pass

        # Exclude Head Office: Head Office is the central administrative headquarters, not an operational branch
        branches_data = [
            b for b in branches_data
            if str(b.get("name", "")).strip().lower() not in ["head office", "headquarters", "headoffice"]
        ]

        if not branches_data:
            return {
                "year": year,
                "total_branches": 0,
                "top_three": [],
                "rankings": [],
                "summary": {}
            }

        # 2. Fetch all branch managers to map branch -> manager name
        bm_map = {}
        try:
            res_users = uow.client.table("app_users").select("id, username, full_name, role, branch_id").in_("role", ["BM", "Branch Manager"]).execute()
            for u in (res_users.data or []):
                bid = u.get("branch_id")
                if bid and bid not in bm_map:
                    bm_map[bid] = u.get("full_name") or u.get("username") or "Manager"
        except Exception:
            pass

        branch_stats = []

        for b in branches_data:
            bid = str(b.get("branch_id") or b.get("id") or "")
            bname = b.get("name") or "Branch"
            bcode = b.get("code") or bname[:3].upper()
            bm_name = bm_map.get(bid, "Branch Manager")

            # A. Capital Deployment (Disbursements in period)
            disb_principal = 0.0
            disb_count = 0
            try:
                q_disb = uow.client.table("loans") \
                    .select("loan_id, loan_amount, active_credit, extra_fields, disbursement_date, start_date, status") \
                    .eq("branch_id", bid) \
                    .gte("disbursement_date", s_date) \
                    .lte("disbursement_date", e_date) \
                    .execute()
                disb_rows = q_disb.data or []
                if not disb_rows:
                    q_disb_fb = uow.client.table("loans") \
                        .select("loan_id, loan_amount, active_credit, extra_fields, disbursement_date, start_date, status") \
                        .eq("branch_id", bid) \
                        .gte("start_date", s_date) \
                        .lte("start_date", e_date) \
                        .execute()
                    disb_rows = q_disb_fb.data or []

                for l in disb_rows:
                    st = str(l.get("status") or "").upper()
                    if st not in ["ACTIVE", "APPROVED", "COMPLETED", "CLOSED"]:
                        continue
                    ef = l.get("extra_fields")
                    if isinstance(ef, dict) and ef.get("is_legacy") is True:
                        continue
                    disb_count += 1
                    disb_principal += float(l.get("loan_amount") or 0.0)
            except Exception:
                pass

            # B. Active Borrowers Count & Active Credit Book
            active_members = 0
            active_credit_book = 0.0
            try:
                res_act = uow.client.table("loans") \
                    .select("client_id, active_credit, loan_amount, status") \
                    .eq("branch_id", bid) \
                    .in_("status", ["ACTIVE", "Active", "Approved"]) \
                    .execute()
                act_rows = res_act.data or []
                cids = set()
                for l in act_rows:
                    cid = str(l.get("client_id") or "")
                    if cid:
                        cids.add(cid)
                    active_credit_book += float(l.get("active_credit") or l.get("loan_amount") or 0.0)
                active_members = len(cids)
            except Exception:
                pass

            # C. Overdue, PAR% & Defaulters
            overdue_amount = 0.0
            par_pct = 0.0
            defaulters_count = 0
            try:
                par_str = DashboardService.calculate_par_pct(uow, bid)
                par_pct = float(par_str.replace("%", "").strip() or 0.0)
            except Exception:
                pass

            try:
                d_res = uow.client.table("loans") \
                    .select("loan_id, total_due") \
                    .eq("branch_id", bid) \
                    .in_("status", ["DEFAULTER", "Defaulter"]) \
                    .execute()
                def_rows = d_res.data or []
                defaulters_count = len(def_rows)
                overdue_amount = sum(float(r.get("total_due") or 0.0) for r in def_rows)
            except Exception:
                pass

            # D. Overdue Recovery & Client Rehabilitation (Pillar 3)
            overdue_recovered = 0.0
            recoveries_count = 0
            full_recoveries_count = 0
            try:
                q_rec = uow.client.table("loan_overdue_recovery_records") \
                    .select("recovered_amount, recovery_type") \
                    .eq("branch_id", bid) \
                    .gte("recovery_date", s_date) \
                    .lte("recovery_date", e_date) \
                    .execute()
                rec_rows = q_rec.data or []
                recoveries_count = len(rec_rows)
                for r in rec_rows:
                    overdue_recovered += float(r.get("recovered_amount") or 0.0)
                    if str(r.get("recovery_type") or "").upper() == "FULL_RECOVERY":
                        full_recoveries_count += 1
            except Exception:
                pass

            total_overdue_pool = overdue_recovered + overdue_amount
            recovery_rate_pct = round((overdue_recovered / total_overdue_pool * 100.0), 1) if total_overdue_pool > 0 else 100.0

            # E. Collections & Compliance Rate
            collected_amount = 0.0
            expected_amount = 0.0
            try:
                res_rep = uow.client.table("repayments") \
                    .select("amount_paid, transaction_type, note") \
                    .eq("branch_id", bid) \
                    .gte("date", s_date) \
                    .lte("date", e_date) \
                    .execute()
                for r in (res_rep.data or []):
                    if str(r.get("transaction_type", "")).upper() == "ONBOARDING_LEGACY" or str(r.get("note", "")).strip() == "Legacy Repayments Onboarded":
                        continue
                    collected_amount += float(r.get("amount_paid") or 0.0)
            except Exception:
                pass

            try:
                summary = CollectionPerformanceService.get_branch_meeting_summary(uow, bid, date.today())
                comp_pct = float(summary.get("compliance_pct", 95.0))
            except Exception:
                comp_pct = 95.0

            # F. Vault Cash in Custody (Account 1000) & Discrepancies
            vault_cash = 0.0
            cash_variance = 0.0
            try:
                res_leg = uow.client.table("financial_ledger_entries") \
                    .select("amount, side") \
                    .eq("branch_id", bid) \
                    .eq("account_code", "1000") \
                    .lte("created_at", f"{e_date}T23:59:59") \
                    .execute()
                leg_rows = res_leg.data or []
                deb = sum(float(r["amount"]) for r in leg_rows if r.get("side") == "Debit")
                crd = sum(float(r["amount"]) for r in leg_rows if r.get("side") == "Credit")
                vault_cash = max(0.0, deb - crd)
            except Exception:
                pass

            try:
                mc_q = uow.client.table("master_cashbook").select("difference").eq("branch_id", bid).execute()
                diffs = [abs(float(r.get("difference") or 0.0)) for r in (mc_q.data or []) if r.get("difference") is not None]
                cash_variance = sum(diffs)
            except Exception:
                pass

            # G. Net Savings Balance (Deposits - Withdrawals)
            net_savings = 0.0
            try:
                for tbl in ["individual_savings", "group_savings", "internal_savings"]:
                    res_s = uow.client.table(tbl).select("deposit_amount, withdrawal_amount").eq("branch_id", bid).execute()
                    for s in (res_s.data or []):
                        net_savings += float(s.get("deposit_amount") or 0.0) - float(s.get("withdrawal_amount") or 0.0)
            except Exception:
                pass

            # H. Full Payoff Settled Early
            full_payoff_count = 0
            full_payoff_amount = 0.0
            try:
                res_po = uow.client.table("loan_payoff_excess_records").select("full_payoff_amount").eq("branch_id", bid).execute()
                for p in (res_po.data or []):
                    amt = float(p.get("full_payoff_amount") or 0.0)
                    if amt > 0:
                        full_payoff_count += 1
                        full_payoff_amount += amt
            except Exception:
                pass

            # I. Top Performing Officer in Branch
            top_officer = "Lead Officer"
            try:
                res_co_l = uow.client.table("loans").select("officer_id").eq("branch_id", bid).in_("status", ["ACTIVE", "Active"]).execute()
                co_counts = {}
                for l in (res_co_l.data or []):
                    oid = str(l.get("officer_id") or "")
                    if oid:
                        co_counts[oid] = co_counts.get(oid, 0) + 1
                if co_counts:
                    top_oid = max(co_counts, key=co_counts.get)
                    res_u = uow.client.table("app_users").select("full_name, username").eq("id", top_oid).execute()
                    if res_u.data:
                        top_officer = res_u.data[0].get("full_name") or res_u.data[0].get("username") or "Lead Officer"
            except Exception:
                pass

            branch_stats.append({
                "branch_id": bid,
                "branch_name": bname,
                "branch_code": bcode,
                "bm_name": bm_name,
                "disb_principal": disb_principal,
                "disb_count": disb_count,
                "active_members": active_members,
                "active_credit_book": active_credit_book,
                "par_pct": par_pct,
                "overdue_amount": overdue_amount,
                "defaulters_count": defaulters_count,
                "overdue_recovered": overdue_recovered,
                "recoveries_count": recoveries_count,
                "full_recoveries_count": full_recoveries_count,
                "recovery_rate_pct": recovery_rate_pct,
                "collected_amount": collected_amount,
                "compliance_pct": comp_pct,
                "vault_cash": vault_cash,
                "cash_variance": cash_variance,
                "net_savings_balance": net_savings,
                "full_payoffs_count": full_payoff_count,
                "full_payoffs_amount": full_payoff_amount,
                "top_officer_name": top_officer,
            })

        # 3. Calculate Normalized 6-Pillar Composite Scores
        max_disb = max([b["disb_principal"] for b in branch_stats] or [1.0])
        max_active = max([b["active_members"] for b in branch_stats] or [1.0])
        max_rec = max([b["overdue_recovered"] for b in branch_stats] or [1.0])

        for b in branch_stats:
            # Pillar 1: Capital Deployment (Weight: 20 pts)
            score_disb = min(20.0, (b["disb_principal"] / max_disb * 20.0)) if max_disb > 0 else 10.0

            # Pillar 2: Delinquency & PAR Containment (Weight: 25 pts)
            # 0% PAR = 25 pts; 5% PAR = 12.5 pts; >= 10% PAR = 0 pts; minus 1 pt per defaulter
            score_quality = max(0.0, 25.0 - (b["par_pct"] * 2.5) - (b["defaulters_count"] * 0.5))

            # Pillar 3: Overdue Debt Recovery & Rehabilitation (Weight: 20 pts)
            # 10 pts for volume recovered + 6 pts for recovery rate % + 4 pts for full client restorations
            score_rec_vol = min(10.0, (b["overdue_recovered"] / max_rec * 10.0)) if max_rec > 0 else 5.0
            score_rec_rate = (b["recovery_rate_pct"] / 100.0) * 6.0
            score_rec_full = min(4.0, b["full_recoveries_count"] * 0.8)
            score_recovery = min(20.0, score_rec_vol + score_rec_rate + score_rec_full)

            # Pillar 4: Active Borrower Outreach & Retention (Weight: 15 pts)
            score_outreach = min(15.0, (b["active_members"] / max_active * 15.0)) if max_active > 0 else 8.0

            # Pillar 5: Repayment Compliance Rate (Weight: 10 pts)
            score_repay = (min(100.0, b["compliance_pct"]) / 100.0) * 10.0

            # Pillar 6: Vault & Operational Discipline (Weight: 10 pts)
            # Deduct points for physical cashbook differences
            variance_penalty = min(6.0, (b["cash_variance"] / 50000.0) * 2.0) if b["cash_variance"] > 0 else 0.0
            score_vault = max(0.0, 10.0 - variance_penalty)

            total_composite = round(score_disb + score_quality + score_recovery + score_outreach + score_repay + score_vault, 1)

            b["scorecard"] = {
                "capital_deployment_score": round(score_disb, 1),
                "delinquency_control_score": round(score_quality, 1),
                "overdue_recovery_score": round(score_recovery, 1),
                "borrower_outreach_score": round(score_outreach, 1),
                "repayment_compliance_score": round(score_repay, 1),
                "vault_discipline_score": round(score_vault, 1),
                "composite_score": total_composite
            }
            b["composite_score"] = total_composite

        # 4. Sort descending by composite score and assign 1st-to-last ranks
        branch_stats.sort(key=lambda x: x["composite_score"], reverse=True)

        for idx, b in enumerate(branch_stats, start=1):
            b["rank"] = idx

        top_three = branch_stats[:3] if len(branch_stats) >= 3 else branch_stats

        total_disb = sum(b["disb_principal"] for b in branch_stats)
        total_disb_count = sum(b["disb_count"] for b in branch_stats)
        total_recovered = sum(b["overdue_recovered"] for b in branch_stats)
        total_active_borrowers = sum(b["active_members"] for b in branch_stats)
        total_active_credit = sum(b["active_credit_book"] for b in branch_stats)
        total_net_savings = sum(b["net_savings_balance"] for b in branch_stats)
        total_full_payoffs_count = sum(b["full_payoffs_count"] for b in branch_stats)
        total_full_payoffs_amount = sum(b["full_payoffs_amount"] for b in branch_stats)
        total_overdue = sum(b["overdue_amount"] for b in branch_stats)
        avg_par = round(sum(b["par_pct"] for b in branch_stats) / len(branch_stats), 2) if branch_stats else 0.0

        return {
            "year": year,
            "total_branches": len(branch_stats),
            "top_three": top_three,
            "rankings": branch_stats,
            "summary": {
                "total_disbursed_ytd": total_disb,
                "total_disbursed_count": total_disb_count,
                "total_overdue_recovered_ytd": total_recovered,
                "total_active_borrowers": total_active_borrowers,
                "total_active_credit": total_active_credit,
                "total_net_savings": total_net_savings,
                "total_full_payoffs_count": total_full_payoffs_count,
                "total_full_payoffs_amount": total_full_payoffs_amount,
                "total_overdue": total_overdue,
                "average_par": avg_par
            }
        }

    @classmethod
    def get_officer_performance_rankings(
        cls,
        uow: UnitOfWork,
        year: int,
        branch_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Calculates individual Credit Officer performance rankings across the institution
        or filtered by a specific branch.
        """
        s_date = date(year, 1, 1).isoformat()
        e_date = min(date.today(), date(year, 12, 31)).isoformat()

        # Query all Credit Officers
        co_users = []
        try:
            u_query = uow.client.table("app_users").select("id, username, full_name, role, branch_id").in_("role", ["CO", "Credit Officer", "Officer"])
            if branch_id and branch_id != "all":
                u_query = u_query.eq("branch_id", branch_id)
            res_users = u_query.execute()
            co_users = res_users.data or []
        except Exception:
            pass

        # Resolve branch names
        branch_map = {}
        try:
            res_branches = uow.client.table("branches").select("branch_id, name").execute()
            branch_map = {str(b.get("branch_id") or b.get("id")): b["name"] for b in (res_branches.data or [])}
        except Exception:
            pass

        officer_stats = []

        for co in co_users:
            cid = str(co.get("id"))
            cname = co.get("full_name") or co.get("username") or "Officer"
            cuname = co.get("username") or "CO"
            cbid = str(co.get("branch_id") or "")
            cbname = branch_map.get(cbid, "Branch")

            # Active Clients & Active Credit
            active_clients = 0
            active_credit = 0.0
            try:
                res_act = uow.client.table("loans") \
                    .select("client_id, active_credit, loan_amount") \
                    .eq("officer_id", cid) \
                    .in_("status", ["ACTIVE", "Active", "Approved"]) \
                    .execute()
                act_rows = res_act.data or []
                cids = set()
                for l in act_rows:
                    clid = str(l.get("client_id") or "")
                    if clid:
                        cids.add(clid)
                    active_credit += float(l.get("active_credit") or l.get("loan_amount") or 0.0)
                active_clients = len(cids)
            except Exception:
                pass

            # Disbursements in period
            disb_principal = 0.0
            disb_count = 0
            try:
                q_disb = uow.client.table("loans") \
                    .select("loan_amount, status") \
                    .eq("officer_id", cid) \
                    .gte("disbursement_date", s_date) \
                    .lte("disbursement_date", e_date) \
                    .execute()
                disb_rows = q_disb.data or []
                for l in disb_rows:
                    st = str(l.get("status") or "").upper()
                    if st in ["ACTIVE", "APPROVED", "COMPLETED", "CLOSED"]:
                        disb_count += 1
                        disb_principal += float(l.get("loan_amount") or 0.0)
            except Exception:
                pass

            # Overdue & Defaulters
            overdue_amount = 0.0
            defaulters_count = 0
            try:
                d_res = uow.client.table("loans") \
                    .select("total_due") \
                    .eq("officer_id", cid) \
                    .in_("status", ["DEFAULTER", "Defaulter"]) \
                    .execute()
                d_rows = d_res.data or []
                defaulters_count = len(d_rows)
                overdue_amount = sum(float(r.get("total_due") or 0.0) for r in d_rows)
            except Exception:
                pass

            par_pct = round((overdue_amount / active_credit * 100.0), 2) if active_credit > 0 else 0.0

            # Overdue Recovery
            overdue_recovered = 0.0
            full_recoveries_count = 0
            try:
                q_rec = uow.client.table("loan_overdue_recovery_records") \
                    .select("recovered_amount, recovery_type") \
                    .eq("officer_id", cid) \
                    .gte("recovery_date", s_date) \
                    .lte("recovery_date", e_date) \
                    .execute()
                rec_rows = q_rec.data or []
                for r in rec_rows:
                    overdue_recovered += float(r.get("recovered_amount") or 0.0)
                    if str(r.get("recovery_type") or "").upper() == "FULL_RECOVERY":
                        full_recoveries_count += 1
            except Exception:
                pass

            # Collections & Compliance
            collected_amount = 0.0
            try:
                res_rep = uow.client.table("repayments") \
                    .select("amount_paid, transaction_type, note") \
                    .eq("officer_id", cid) \
                    .gte("date", s_date) \
                    .lte("date", e_date) \
                    .execute()
                for r in (res_rep.data or []):
                    if str(r.get("transaction_type", "")).upper() == "ONBOARDING_LEGACY" or str(r.get("note", "")).strip() == "Legacy Repayments Onboarded":
                        continue
                    collected_amount += float(r.get("amount_paid") or 0.0)
            except Exception:
                pass

            compliance_pct = 95.0

            officer_stats.append({
                "officer_id": cid,
                "officer_name": cname,
                "officer_username": cuname,
                "branch_id": cbid,
                "branch_name": cbname,
                "active_clients": active_clients,
                "active_credit": active_credit,
                "disb_principal": disb_principal,
                "disb_count": disb_count,
                "overdue_amount": overdue_amount,
                "par_pct": par_pct,
                "defaulters_count": defaulters_count,
                "overdue_recovered": overdue_recovered,
                "full_recoveries_count": full_recoveries_count,
                "collected_amount": collected_amount,
                "compliance_pct": compliance_pct,
            })

        max_co_disb = max([o["disb_principal"] for o in officer_stats] or [1.0])
        max_co_rec = max([o["overdue_recovered"] for o in officer_stats] or [1.0])
        max_co_clients = max([o["active_clients"] for o in officer_stats] or [1.0])

        for o in officer_stats:
            score_disb = (o["disb_principal"] / max_co_disb * 25.0) if max_co_disb > 0 else 12.0
            score_quality = max(0.0, 30.0 - (o["par_pct"] * 3.0) - (o["defaulters_count"] * 1.0))
            score_rec = (o["overdue_recovered"] / max_co_rec * 20.0) if max_co_rec > 0 else 10.0
            score_outreach = (o["active_clients"] / max_co_clients * 15.0) if max_co_clients > 0 else 8.0
            score_comp = (o["compliance_pct"] / 100.0) * 10.0

            o["composite_score"] = round(score_disb + score_quality + score_rec + score_outreach + score_comp, 1)

        officer_stats.sort(key=lambda x: x["composite_score"], reverse=True)
        for idx, o in enumerate(officer_stats, start=1):
            o["rank"] = idx

        return {
            "year": year,
            "branch_id": branch_id or "all",
            "total_officers": len(officer_stats),
            "top_three": officer_stats[:3] if len(officer_stats) >= 3 else officer_stats,
            "rankings": officer_stats
        }

    @classmethod
    def get_working_days_financial_activity(
        cls,
        uow: UnitOfWork,
        target_date: date
    ) -> List[Dict[str, Any]]:
        """
        Computes daily collections and disbursements for the active working week,
        adhering strictly to BR-DATE-001 and BR-DATE-004. Weekends (Saturdays & Sundays)
        and Nigerian public holidays are flagged as non-working days.
        """
        monday = target_date - timedelta(days=target_date.weekday())
        sunday = monday + timedelta(days=6)

        rep_map = defaultdict(float)
        try:
            q_rep = uow.client.table("repayments") \
                .select("amount_paid, date, transaction_type, note") \
                .gte("date", monday.isoformat()) \
                .lte("date", sunday.isoformat()) \
                .execute()
            for r in (q_rep.data or []):
                if str(r.get("transaction_type", "")).upper() == "ONBOARDING_LEGACY" or str(r.get("note", "")).strip() == "Legacy Repayments Onboarded":
                    continue
                d_str = str(r.get("date") or "")
                rep_map[d_str] += float(r.get("amount_paid") or 0.0)
        except Exception:
            pass

        disb_map = defaultdict(float)
        try:
            q_disb = uow.client.table("loans") \
                .select("loan_amount, disbursement_date, start_date, status") \
                .gte("disbursement_date", monday.isoformat()) \
                .lte("disbursement_date", sunday.isoformat()) \
                .execute()
            for l in (q_disb.data or []):
                st = str(l.get("status") or "").upper()
                if st in ["ACTIVE", "APPROVED", "COMPLETED"]:
                    d_str = str(l.get("disbursement_date") or l.get("start_date") or "")
                    disb_map[d_str] += float(l.get("loan_amount") or 0.0)
        except Exception:
            pass

        days = []
        day_labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        for i in range(7):
            cur_d = monday + timedelta(days=i)
            cur_iso = cur_d.isoformat()
            is_work, reason = BusinessDateService.is_working_day(cur_d)
            days.append({
                "day": day_labels[i],
                "date": cur_iso,
                "is_working_day": is_work,
                "status_reason": reason,
                "collections": rep_map.get(cur_iso, 0.0),
                "disbursements": disb_map.get(cur_iso, 0.0)
            })
        return days

    @classmethod
    def get_branch_detail_metrics(
        cls,
        uow: UnitOfWork,
        branch_id: str,
        business_date: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Gathers comprehensive operational and portfolio performance metrics for a single
        branch when drilled down by Global Admin.
        Derived strictly from Account 1000 for vault cash and dedicated payoff/recovery records.
        """
        p_date = date.fromisoformat(business_date) if business_date else date.today()
        p_date_str = p_date.isoformat()

        # 1. Resolve Branch Name & Manager
        branch_name = "Branch"
        manager_name = "Branch Manager"
        try:
            res_b = uow.client.table("branches").select("branch_id, name").eq("branch_id", branch_id).execute()
            if res_b.data:
                branch_name = res_b.data[0].get("name") or "Branch"
        except Exception:
            pass

        try:
            res_mgr = uow.client.table("app_users").select("full_name, username").in_("role", ["BM", "Branch Manager"]).eq("branch_id", branch_id).execute()
            if res_mgr.data:
                manager_name = res_mgr.data[0].get("full_name") or res_mgr.data[0].get("username") or "Branch Manager"
        except Exception:
            pass

        # 2. Vault Cash in Custody (Account 1000 Double-Entry Truth)
        vault_cash = 0.0
        try:
            res_leg = uow.client.table("financial_ledger_entries") \
                .select("amount, side") \
                .eq("branch_id", branch_id) \
                .eq("account_code", "1000") \
                .lte("created_at", f"{p_date_str}T23:59:59") \
                .execute()
            for r in (res_leg.data or []):
                amt = float(r.get("amount") or 0.0)
                vault_cash += amt if r.get("side") == "Debit" else -amt
            vault_cash = max(0.0, vault_cash)
        except Exception:
            pass

        # 3. Active Loans, Credit Book & Overdue
        active_credit_book = 0.0
        active_borrowers_set = set()
        overdue_amount = 0.0
        defaulters_set = set()
        total_disbursed_ytd = 0.0
        disb_count_ytd = 0
        try:
            res_loans = uow.client.table("loans") \
                .select("loan_id, client_id, loan_amount, active_credit, total_outstanding, status, end_date") \
                .eq("branch_id", branch_id) \
                .execute()
            for l in (res_loans.data or []):
                st = str(l.get("status") or "").upper()
                l_amt = float(l.get("loan_amount") or 0.0)
                ac_amt = float(l.get("active_credit") or l_amt)
                out_amt = float(l.get("total_outstanding") or 0.0)

                if st in ["ACTIVE", "APPROVED", "COMPLETED"]:
                    total_disbursed_ytd += l_amt
                    disb_count_ytd += 1

                if st in ["ACTIVE"]:
                    active_credit_book += ac_amt
                    if l.get("client_id"):
                        active_borrowers_set.add(str(l.get("client_id")))

                    ed_str = str(l.get("end_date") or "")
                    if ed_str and ed_str < p_date_str and out_amt > 0.0:
                        overdue_amount += out_amt
                        if l.get("client_id"):
                            defaulters_set.add(str(l.get("client_id")))
        except Exception:
            pass

        par_pct = round((overdue_amount / active_credit_book * 100.0), 2) if active_credit_book > 0 else 0.0

        # 4. Collections Today (Excluding legacy onboarding per BR-DASH-006)
        today_collections = 0.0
        try:
            res_rep = uow.client.table("repayments") \
                .select("amount_paid, transaction_type, note") \
                .eq("branch_id", branch_id) \
                .eq("date", p_date_str) \
                .execute()
            for r in (res_rep.data or []):
                if str(r.get("transaction_type", "")).upper() == "ONBOARDING_LEGACY" or str(r.get("note", "")).strip() == "Legacy Repayments Onboarded":
                    continue
                today_collections += float(r.get("amount_paid") or 0.0)
        except Exception:
            pass

        # 5. Overdue Recoveries & Settlements (Dedicated Tables)
        overdue_recovered = 0.0
        full_recoveries_count = 0
        try:
            res_rec = uow.client.table("loan_overdue_recovery_records") \
                .select("recovered_amount, recovery_type") \
                .eq("branch_id", branch_id) \
                .execute()
            for rec in (res_rec.data or []):
                overdue_recovered += float(rec.get("recovered_amount") or 0.0)
                if str(rec.get("recovery_type") or "").upper() == "FULL_RECOVERY":
                    full_recoveries_count += 1
        except Exception:
            pass

        # 6. Branch Operating Status
        op_state = "OPEN"
        try:
            res_eod = uow.client.table("area_eod_confirmations").select("status").eq("branch_id", branch_id).eq("closure_date", p_date_str).execute()
            if res_eod.data:
                eod_st = str(res_eod.data[0].get("status") or "").upper()
                if eod_st in ["CONFIRMED", "CLOSED"]:
                    op_state = "CLOSED"
                elif eod_st in ["PENDING", "READY_FOR_REVIEW"]:
                    op_state = "EOD_PENDING"
        except Exception:
            pass

        # 7. Credit Officers Roster for this Branch
        officers_list = []
        try:
            res_co = uow.client.table("app_users").select("id, username, full_name").in_("role", ["CO", "Credit Officer"]).eq("branch_id", branch_id).execute()
            for co in (res_co.data or []):
                officers_list.append({
                    "officer_id": str(co.get("id")),
                    "name": co.get("full_name") or co.get("username") or "Officer",
                    "username": co.get("username") or ""
                })
        except Exception:
            pass

        return {
            "branch_id": branch_id,
            "branch_name": branch_name,
            "manager_name": manager_name,
            "operational_status": op_state,
            "vault_cash_in_custody": vault_cash,
            "active_credit_book": active_credit_book,
            "active_borrowers_count": len(active_borrowers_set),
            "today_collections": today_collections,
            "overdue_amount": overdue_amount,
            "par_pct": par_pct,
            "defaulters_count": len(defaulters_set),
            "overdue_recovered": overdue_recovered,
            "full_recoveries_count": full_recoveries_count,
            "total_disbursed_ytd": total_disbursed_ytd,
            "total_disbursed_count": disb_count_ytd,
            "officers_count": len(officers_list),
            "officers": officers_list
        }
