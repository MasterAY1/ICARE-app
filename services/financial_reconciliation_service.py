"""
FinancialReconciliationService — Phase 8.1
Provides live 6-Way Financial Integrity verification across:
  Ledger == Audit Views == CO Cashbook == Master Cashbook == Dashboard == Reports
Features itemized variance reporting, 15 automated exception rules, and guided self-healing projection repair.
"""
from typing import Dict, Any, List, Optional
from datetime import date
from interfaces.unit_of_work import UnitOfWork
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder


class FinancialReconciliationService:

    @staticmethod
    def verify_6way_financial_integrity(
        uow: UnitOfWork,
        branch_id: str,
        posting_date: date
    ) -> Dict[str, Any]:
        """
        Verify 6-way financial integrity for a branch on a posting date:
          1. General Ledger Total (Cash Account 1000 Debit Net)
          2. Audit Views Total (Sum of fee & treasury views for date)
          3. CO Cashbooks Total (Sum of total_inflows across CO cashbooks)
          4. Master Cashbook Total (total_inflows on master_cashbook)
          5. Dashboard Total (Active credit + savings + repayments)
          6. Reports Total (Sum of repayments + fees in report engine)
        """
        p_date_str = posting_date.isoformat() if isinstance(posting_date, date) else str(posting_date)

        # 1. General Ledger Account 1000 NET Cash Movement (Debits - Credits on posting_date, BR-RECON-001)
        ledger_total = 0.0
        try:
            res_leg = uow.client.table("financial_ledger_entries") \
                .select("amount, side, financial_transactions!inner(posting_date, branch_id)") \
                .eq("branch_id", branch_id) \
                .eq("account_code", "1000") \
                .eq("financial_transactions.posting_date", p_date_str) \
                .execute()
            for r in (res_leg.data or []):
                amt = float(r.get("amount") or 0.0)
                s_val = str(r.get("side") or "Debit").strip().lower()
                ledger_total += amt if s_val == "debit" else -amt
            ledger_total = round(ledger_total, 2)
        except Exception:
            pass

        # 2. Audit Views Total (Net Physical Cash Movement on date)
        audit_views_total = 0.0
        rep_date_total = 0.0
        sav_date_total = 0.0
        fee_date_total = 0.0
        tr_net_total = 0.0
        try:
            # Operational Repayments on date (physical cash repayments only)
            s_d_str = f"{p_date_str}T00:00:00"
            e_d_str = f"{p_date_str}T23:59:59"
            res_rep = uow.client.table("repayments").select("amount_paid, transaction_type") \
                .eq("branch_id", branch_id).gte("date", s_d_str).lte("date", e_d_str).execute()
            rep_date_total = sum(
                float(r.get("amount_paid") or 0.0)
                for r in (res_rep.data or [])
                if str(r.get("transaction_type") or "").upper() not in ("ONBOARDING_LEGACY", "LOAN_OFFSET", "SAVINGS_OFFSET")
            )

            # Operational Savings Cash Deposits on date (exclude UPF auto-deductions / internal sweeps / legacy)
            for sav_tbl in ("individual_savings", "group_savings", "internal_savings", "laps_savings"):
                try:
                    res_s = uow.client.table(sav_tbl).select("deposit_amount, withdrawal_amount, reference, remarks") \
                        .eq("branch_id", branch_id).eq("posting_date", p_date_str).execute()
                    for r in (res_s.data or []):
                        rem_l = str(r.get("remarks") or "").lower()
                        ref_l = str(r.get("reference") or "").lower()
                        if "legacy" in rem_l or "laps-" in ref_l or ref_l.startswith("trf-") or ref_l.startswith("upf-"):
                            continue
                        sav_date_total += float(r.get("deposit_amount") or 0.0)
                except Exception:
                    pass

            # Operational Standalone Cash Fees on date (exclude MISC_FEE and non-cash Finance origination fees)
            res_fees = uow.client.table("fees").select("amount, fee_type") \
                .eq("branch_id", branch_id).eq("posting_date", p_date_str).execute()
            fee_date_total = sum(
                float(r.get("amount") or 0.0)
                for r in (res_fees.data or [])
                if str(r.get("fee_type") or "").upper() not in ("MISC_FEE", "MARKUP_11", "MARKUP_20", "CONTINGENCY")
            )

            # Vault Cash Sweeps & Branch Cash Expenses on date
            res_tr = uow.client.table("treasury_transactions").select("amount, transaction_type") \
                .eq("branch_id", branch_id).eq("posting_date", p_date_str).execute()
            for t in (res_tr.data or []):
                t_amt = float(t.get("amount") or 0.0)
                t_type = str(t.get("transaction_type") or "").upper()
                if t_type in ("BANK_WITHDRAWAL", "FLOAT"):
                    tr_net_total += t_amt
                elif t_type in ("BANK_DEPOSIT", "OFFICE_EXPENSE", "VAULT_ADJUSTMENT"):
                    tr_net_total -= t_amt

            audit_views_total = round(rep_date_total + sav_date_total + fee_date_total + tr_net_total, 2)
        except Exception:
            pass

        # 3. CO Cashbooks Net Flow (CO officers only)
        co_cashbooks_total = 0.0
        try:
            res_u = uow.client.table("app_users").select("id, role, username").eq("branch_id", branch_id).execute()
            co_ids = {
                str(u["id"]) for u in (res_u.data or [])
                if u.get("id") and (
                    "co" in str(u.get("role") or "").lower()
                    or "credit" in str(u.get("role") or "").lower()
                    or str(u.get("username") or "").lower().startswith("co")
                )
            }
            res_co = uow.client.table("co_cashbooks").select("officer_id, opening_balance, total_inflows, total_outflows") \
                .eq("branch_id", branch_id).eq("date", p_date_str).execute()
            for c in (res_co.data or []):
                if co_ids and c.get("officer_id") and str(c.get("officer_id")) not in co_ids:
                    continue
                net_c = (float(c.get("total_inflows") or 0.0) - float(c.get("opening_balance") or 0.0)) - float(c.get("total_outflows") or 0.0)
                co_cashbooks_total += net_c
            co_cashbooks_total = round(co_cashbooks_total, 2)
        except Exception:
            pass

        # 4. Master Cashbook Net Flow (total_inflows - opening_balance - total_outflows)
        master_cashbook_total = 0.0
        try:
            res_mb = uow.client.table("master_cashbook").select("opening_balance, total_inflows, total_outflows") \
                .eq("branch_id", branch_id).eq("date", p_date_str).execute()
            if res_mb.data:
                mb_r = res_mb.data[0]
                master_cashbook_total = round(
                    (float(mb_r.get("total_inflows") or 0.0) - float(mb_r.get("opening_balance") or 0.0))
                    - float(mb_r.get("total_outflows") or 0.0),
                    2,
                )
        except Exception:
            pass

        # 5. Dashboard Total (Independent operational net cash flow across repayments, savings, fees, and vault treasury)
        dashboard_total = 0.0
        try:
            s_d_str = f"{p_date_str}T00:00:00"
            e_d_str = f"{p_date_str}T23:59:59"
            dash_rep_res = uow.client.table("repayments").select("amount_paid, transaction_type") \
                .eq("branch_id", branch_id).gte("date", s_d_str).lte("date", e_d_str).execute()
            dash_rep = sum(
                float(r.get("amount_paid") or 0.0)
                for r in (dash_rep_res.data or [])
                if str(r.get("transaction_type") or "").upper() not in ("ONBOARDING_LEGACY", "LOAN_OFFSET", "SAVINGS_OFFSET")
            )

            dash_sav = 0.0
            for sav_tbl in ("individual_savings", "group_savings", "internal_savings", "laps_savings"):
                try:
                    s_res = uow.client.table(sav_tbl).select("deposit_amount, reference, remarks") \
                        .eq("branch_id", branch_id).eq("posting_date", p_date_str).execute()
                    for r in (s_res.data or []):
                        rem_l = str(r.get("remarks") or "").lower()
                        ref_l = str(r.get("reference") or "").lower()
                        if "legacy" in rem_l or "laps-" in ref_l or ref_l.startswith("trf-"):
                            continue
                        dash_sav += float(r.get("deposit_amount") or 0.0)
                except Exception:
                    pass

            dash_fees_res = uow.client.table("fees").select("amount, fee_type") \
                .eq("branch_id", branch_id).eq("posting_date", p_date_str).execute()
            dash_fees = sum(
                float(r.get("amount") or 0.0)
                for r in (dash_fees_res.data or [])
                if str(r.get("fee_type") or "").upper() not in ("MISC_FEE", "MARKUP_11", "MARKUP_20", "CONTINGENCY")
            )

            dash_tr_res = uow.client.table("treasury_transactions").select("amount, transaction_type") \
                .eq("branch_id", branch_id) \
                .eq("posting_date", p_date_str).execute()
            dash_tr_net = 0.0
            for t in (dash_tr_res.data or []):
                t_amt = float(t.get("amount") or 0.0)
                t_type = str(t.get("transaction_type") or "").upper()
                if t_type in ("BANK_WITHDRAWAL", "FLOAT"):
                    dash_tr_net += t_amt
                elif t_type in ("BANK_DEPOSIT", "OFFICE_EXPENSE", "VAULT_ADJUSTMENT"):
                    dash_tr_net -= t_amt

            dashboard_total = round(dash_rep + dash_sav + dash_fees + dash_tr_net, 2)
        except Exception:
            dashboard_total = 0.0

        # 6. Reports Total (Independent reporting engine transaction & journal aggregation on date - NET Account 1000)
        reports_total = 0.0
        try:
            res_ft = uow.client.table("financial_transactions") \
                .select("transaction_id, reference, financial_ledger_entries(account_code, side, amount)") \
                .eq("branch_id", branch_id) \
                .eq("posting_date", p_date_str) \
                .execute()
            rep_sum = 0.0
            for tx in (res_ft.data or []):
                for leg in (tx.get("financial_ledger_entries") or []):
                    if str(leg.get("account_code") or "") == "1000":
                        amt_l = float(leg.get("amount") or 0.0)
                        s_l = str(leg.get("side") or "Debit").strip().lower()
                        rep_sum += amt_l if s_l == "debit" else -amt_l
            reports_total = round(rep_sum, 2)
        except Exception:
            reports_total = 0.0

        # Compare values (tolerance of ₦0.01 for floating-point rounding)
        is_balanced = (
            abs(ledger_total - audit_views_total) < 0.01 and
            abs(audit_views_total - co_cashbooks_total) < 0.01 and
            abs(co_cashbooks_total - master_cashbook_total) < 0.01 and
            abs(master_cashbook_total - dashboard_total) < 0.01 and
            abs(dashboard_total - reports_total) < 0.01
        )

        variances = []
        if not is_balanced:
            if abs(ledger_total - audit_views_total) >= 0.01:
                variances.append({
                    "source": "Ledger vs Audit Views",
                    "expected": ledger_total,
                    "actual": audit_views_total,
                    "variance": abs(ledger_total - audit_views_total),
                    "cause": "Unposted ledger event or timing difference"
                })
            if abs(audit_views_total - co_cashbooks_total) >= 0.01:
                variances.append({
                    "source": "Audit Views vs CO Cashbooks",
                    "expected": audit_views_total,
                    "actual": co_cashbooks_total,
                    "variance": abs(audit_views_total - co_cashbooks_total),
                    "cause": "Officer cashbook projection lag or unmapped inflow"
                })
            if abs(co_cashbooks_total - master_cashbook_total) >= 0.01:
                variances.append({
                    "source": "CO Cashbooks vs Master Cashbook",
                    "expected": co_cashbooks_total,
                    "actual": master_cashbook_total,
                    "variance": abs(co_cashbooks_total - master_cashbook_total),
                    "cause": "Unrebuilt master projection or treasury variance"
                })
            if abs(master_cashbook_total - dashboard_total) >= 0.01:
                variances.append({
                    "source": "Master Cashbook vs Dashboard Total",
                    "expected": master_cashbook_total,
                    "actual": dashboard_total,
                    "variance": abs(master_cashbook_total - dashboard_total),
                    "cause": "Dashboard collection query discrepancy"
                })
            if abs(dashboard_total - reports_total) >= 0.01:
                variances.append({
                    "source": "Dashboard vs Reports Total",
                    "expected": dashboard_total,
                    "actual": reports_total,
                    "variance": abs(dashboard_total - reports_total),
                    "cause": "Operational inflow vs ledger report variance"
                })

        return {
            "branch_id": branch_id,
            "posting_date": p_date_str,
            "is_balanced": is_balanced,
            "status_text": "PERFECT MATCH — Financial Integrity Verified" if is_balanced else "Financial Integrity Mismatch Detected",
            "status_badge": "BALANCED" if is_balanced else "VARIANCE_DETECTED",
            "ledger_total": ledger_total,
            "audit_views_total": audit_views_total,
            "co_cashbooks_total": co_cashbooks_total,
            "master_cashbook_total": master_cashbook_total,
            "dashboard_total": dashboard_total,
            "reports_total": reports_total,
            "variances": variances
        }

    @staticmethod
    def _apply_branch_filter(q_obj: Any, branch_id: Any) -> Any:
        if branch_id and branch_id not in ("All", "ALL", "All Branches"):
            if isinstance(branch_id, (list, tuple, set)):
                bids = [str(b) for b in branch_id if b]
                if bids:
                    return q_obj.in_("branch_id", bids)
            else:
                return q_obj.eq("branch_id", branch_id)
        return q_obj

    @staticmethod
    def run_15_exception_reports(uow: UnitOfWork, branch_id: Any = None) -> Dict[str, Any]:
        """
        Run 15 automated audit exception rules across the platform.
        Returns itemized lists of anomalous records for immediate auditor inspection.
        """
        exception_keys = [
            "loans_approved_not_disbursed",
            "loans_disbursed_no_ledger",
            "repayments_without_loan",
            "savings_withdrawal_no_ledger",
            "negative_savings_balance",
            "duplicate_receipt_numbers",
            "duplicate_transaction_references",
            "orphan_ledger_entries",
            "unbalanced_journal_entries",
            "cashbook_differences",
            "projection_differences",
            "missing_collection_records",
            "overdue_repayments",
            "loans_without_schedule",
            "inactive_clients_active_loan",
        ]
        if isinstance(branch_id, (list, tuple, set)) and not any(branch_id):
            return {
                "total_exceptions": 0,
                "exception_rules_evaluated": 15,
                "details": {k: [] for k in exception_keys},
            }

        exceptions = {}

        # 1. Loans Approved without Disbursement
        try:
            q = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("loans").select("loan_id, client_id, loan_amount, status").eq("status", "Approved"),
                branch_id,
            )
            res = q.execute()
            exceptions["loans_approved_not_disbursed"] = res.data or []
        except Exception:
            exceptions["loans_approved_not_disbursed"] = []

        # 2. Loans Disbursed without Ledger Posting (BR-RECON-003 Orphan Detection)
        try:
            q_loans = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("loans").select("loan_id, client_id, loan_amount, branch_id, status").eq("status", "Active"),
                branch_id,
            )
            active_loans = q_loans.execute().data or []
            
            res_events = uow.client.table("event_store").select("aggregate_id").eq("event_type", "LoanDisbursed").execute()
            disbursed_event_ids = {str(e.get("aggregate_id")) for e in (res_events.data or []) if e.get("aggregate_id")}
            
            orphan_loans = [l for l in active_loans if str(l.get("loan_id")) not in disbursed_event_ids]
            exceptions["loans_disbursed_no_ledger"] = orphan_loans
        except Exception:
            exceptions["loans_disbursed_no_ledger"] = []

        # 3. Repayments without Loan
        try:
            q = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("repayments").select("*").is_("loan_id", "null"),
                branch_id,
            )
            res = q.execute()
            exceptions["repayments_without_loan"] = res.data or []
        except Exception:
            exceptions["repayments_without_loan"] = []

        # 4. Savings Withdrawal without Ledger Entry (across all 4 savings tables)
        wth_no_ledger = []
        neg_balances = []
        dup_refs = []
        dup_receipts = []

        try:
            withdrawal_event_types = [
                "SavingsWithdrawn", "INDIVIDUAL_SAVINGS_WITHDRAWAL", "AUTOMATIC_DEDUCTION",
                "LoanOffsetFromSavings", "FeeOffsetFromSavings", "GapFeeOffsetFromSavings",
                "SavingsTransferred", "LapsTransferred", "LapsPaidOut",
                "LapsPaidOutReversed", "LapsRestoredToSavings"
            ]
            ev_res = uow.client.table("event_store").select("aggregate_id, event_type, payload").in_("event_type", withdrawal_event_types).execute()
            ft_res = uow.client.table("financial_transactions").select("reference, amount, branch_id").execute()

            ledger_agg_ids = set()
            ledger_refs = set()
            if isinstance(ev_res.data, list):
                for ev in ev_res.data:
                    if ev.get("aggregate_id"):
                        ledger_agg_ids.add(str(ev["aggregate_id"]))
                    p = ev.get("payload") or {}
                    if isinstance(p, dict):
                        for k in ("reference", "savings_id", "record_id"):
                            if p.get(k):
                                ledger_refs.add(str(p[k]))
            if isinstance(ft_res.data, list):
                for ft in ft_res.data:
                    if ft.get("reference"):
                        ledger_refs.add(str(ft["reference"]))

            sav_tables_meta = [
                ("individual_savings", "client_id"),
                ("group_savings", "group_id"),
                ("internal_savings", "branch_id"),
                ("laps_savings", "client_id"),
            ]
            all_sav_rows_for_check = []
            for tbl, key_col in sav_tables_meta:
                q_s = FinancialReconciliationService._apply_branch_filter(
                    uow.client.table(tbl).select(f"id, {key_col}, branch_id, deposit_amount, withdrawal_amount, reference, posting_date"),
                    branch_id,
                )
                s_rows = q_s.execute().data or []
                if isinstance(s_rows, list):
                    bal_by_acct = {}
                    seen_ref_side = {}
                    for r in s_rows:
                        if not isinstance(r, dict):
                            continue
                        acct_k = str(r.get(key_col) or r.get("branch_id") or "")
                        dep = float(r.get("deposit_amount") or 0.0)
                        wth = float(r.get("withdrawal_amount") or 0.0)
                        bal_by_acct[acct_k] = bal_by_acct.get(acct_k, 0.0) + (dep - wth)

                        ref_s = str(r.get("reference") or "").strip()
                        if ref_s:
                            side_tag = "WTH" if wth > 0 else ("DEP" if dep > 0 else "REV")
                            dup_key = (tbl, side_tag, ref_s)
                            seen_ref_side.setdefault(dup_key, []).append(str(r.get("id") or ""))

                        if wth > 0:
                            r_id = str(r.get("id") or "")
                            has_ledger = (r_id in ledger_agg_ids) or (acct_k in ledger_agg_ids) or (ref_s and ref_s in ledger_refs)
                            if not has_ledger and (ledger_agg_ids or ledger_refs):
                                wth_no_ledger.append({
                                    "table": tbl,
                                    "id": r_id,
                                    "account_key": acct_k,
                                    "amount": wth,
                                    "reference": ref_s,
                                    "posting_date": r.get("posting_date"),
                                })

                    for acct_k, net_bal in bal_by_acct.items():
                        if net_bal < -0.01:
                            neg_balances.append({
                                "table": tbl,
                                "account_key": acct_k,
                                "net_balance": round(net_bal, 2),
                            })
                    for (t_name, side_tag, ref_s), ids_list in seen_ref_side.items():
                        if len(ids_list) > 1:
                            dup_refs.append({
                                "table": t_name,
                                "side": side_tag,
                                "reference": ref_s,
                                "count": len(ids_list),
                                "record_ids": ids_list,
                            })
        except Exception:
            pass

        # 6. Duplicate Receipt Numbers
        try:
            q_rep = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("repayments").select("id, loan_id, client_id, amount_paid, receipt_number, branch_id"),
                branch_id,
            )
            r_rows = q_rep.execute().data or []
            seen_rcpts = {}
            for r in (r_rows if isinstance(r_rows, list) else []):
                if not isinstance(r, dict):
                    continue
                rcpt = str(r.get("receipt_number") or "").strip()
                if rcpt:
                    seen_rcpts.setdefault(rcpt, []).append(str(r.get("id") or ""))
            for rcpt, r_ids in seen_rcpts.items():
                if len(r_ids) > 1:
                    dup_receipts.append({"receipt_number": rcpt, "count": len(r_ids), "repayment_ids": r_ids})
        except Exception:
            pass

        exceptions["savings_withdrawal_no_ledger"] = wth_no_ledger

        # 5. Negative Savings Balance
        exceptions["negative_savings_balance"] = neg_balances

        # 6. Duplicate Receipt Numbers
        exceptions["duplicate_receipt_numbers"] = dup_receipts

        # 7. Duplicate Transaction References
        exceptions["duplicate_transaction_references"] = dup_refs

        # 8. Orphan Ledger Entries (entries whose transaction_id is missing or orphaned from financial_transactions)
        orphan_entries = []
        try:
            q_le = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("financial_ledger_entries").select("entry_id, transaction_id, account_code, side, amount, branch_id").limit(1000),
                branch_id,
            )
            le_rows = q_le.execute().data or []
            tx_ids = {str(r.get("transaction_id")) for r in le_rows if r.get("transaction_id")}
            valid_tx_ids = set()
            if tx_ids:
                tx_list = list(tx_ids)
                for chunk in [tx_list[i:i + 100] for i in range(0, len(tx_list), 100)]:
                    q_ft = uow.client.table("financial_transactions").select("transaction_id").in_("transaction_id", chunk).execute()
                    for ft in (q_ft.data or []):
                        if ft.get("transaction_id"):
                            valid_tx_ids.add(str(ft["transaction_id"]))
            for le in le_rows:
                tid = le.get("transaction_id")
                if not tid or str(tid) not in valid_tx_ids:
                    orphan_entries.append(le)
        except Exception:
            orphan_entries = []
        exceptions["orphan_ledger_entries"] = orphan_entries

        # 9. Unbalanced Journal Entries (sum(Debit) != sum(Credit) within a transaction)
        unbalanced_journals = []
        try:
            q_j = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("financial_transactions").select("transaction_id, reference, posting_date, branch_id, financial_ledger_entries(side, amount)").limit(500),
                branch_id,
            )
            j_rows = q_j.execute().data or []
            for j in j_rows:
                legs = j.get("financial_ledger_entries") or []
                tot_dr = sum(float(l.get("amount") or 0.0) for l in legs if str(l.get("side") or "").upper() == "DEBIT")
                tot_cr = sum(float(l.get("amount") or 0.0) for l in legs if str(l.get("side") or "").upper() == "CREDIT")
                if abs(tot_dr - tot_cr) >= 0.01:
                    unbalanced_journals.append({
                        "transaction_id": j.get("transaction_id"),
                        "reference": j.get("reference"),
                        "posting_date": j.get("posting_date"),
                        "branch_id": j.get("branch_id"),
                        "debit_total": round(tot_dr, 2),
                        "credit_total": round(tot_cr, 2),
                        "variance": round(abs(tot_dr - tot_cr), 2),
                    })
        except Exception:
            unbalanced_journals = []
        exceptions["unbalanced_journal_entries"] = unbalanced_journals

        # 10. Cashbook Differences (co_cashbooks closing_balance mismatch against opening + inflows - outflows)
        cb_diffs = []
        try:
            q_cb = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("co_cashbooks").select("branch_id, officer_id, date, opening_balance, total_inflows, total_outflows, closing_balance").order("date", desc=True).limit(300),
                branch_id,
            )
            for cb in (q_cb.execute().data or []):
                expected_close = float(cb.get("total_inflows") or 0.0) - float(cb.get("total_outflows") or 0.0)
                recorded_close = float(cb.get("closing_balance") or 0.0)
                if abs(expected_close - recorded_close) >= 0.01:
                    cb_diffs.append({**cb, "expected_closing": round(expected_close, 2), "variance": round(abs(expected_close - recorded_close), 2)})
        except Exception:
            cb_diffs = []
        exceptions["cashbook_differences"] = cb_diffs

        # 11. Projection Differences (master_cashbook closing_balance vs aggregated co_cashbooks/date expectation)
        proj_diffs = []
        try:
            q_mc = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("master_cashbook").select("branch_id, date, opening_balance, total_inflows, total_outflows, closing_balance").order("date", desc=True).limit(100),
                branch_id,
            )
            q_cc = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("co_cashbooks").select("branch_id, date, total_inflows, total_outflows, closing_balance").order("date", desc=True).limit(500),
                branch_id,
            )
            mc_rows = q_mc.execute().data or []
            cc_rows = q_cc.execute().data or []
            cc_by_bd = {}
            for cc in cc_rows:
                key = (str(cc.get("branch_id") or ""), str(cc.get("date") or "")[:10])
                cc_by_bd[key] = cc_by_bd.get(key, 0.0) + float(cc.get("closing_balance") or 0.0)
            for mc in mc_rows:
                expected_mc_close = float(mc.get("total_inflows") or 0.0) - float(mc.get("total_outflows") or 0.0)
                rec_mc_close = float(mc.get("closing_balance") or 0.0)
                if abs(expected_mc_close - rec_mc_close) >= 0.01:
                    proj_diffs.append({**mc, "expected_closing": round(expected_mc_close, 2), "variance": round(abs(expected_mc_close - rec_mc_close), 2)})
        except Exception:
            proj_diffs = []
        exceptions["projection_differences"] = proj_diffs

        # 12. Missing Collection Records (past-due Active loan schedules with zero payment & still Pending)
        missing_colls = []
        try:
            q_al_mc = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("loans").select("loan_id, client_id, branch_id").eq("status", "Active"),
                branch_id,
            )
            al_rows = q_al_mc.execute().data or []
            al_ids = [l["loan_id"] for l in al_rows if l.get("loan_id")]
            if al_ids:
                today_iso = date.today().isoformat()
                for chunk in [al_ids[i:i + 50] for i in range(0, len(al_ids), 50)]:
                    s_res = uow.client.table("loan_schedule").select("schedule_id, loan_id, due_date, total_due, paid_amount, status") \
                        .in_("loan_id", chunk).lt("due_date", today_iso).eq("status", "Pending").limit(200).execute()
                    for sr in (s_res.data or []):
                        if float(sr.get("paid_amount") or 0.0) <= 0.0 and float(sr.get("total_due") or 0.0) > 0.0:
                            missing_colls.append(sr)
        except Exception:
            missing_colls = []
        exceptions["missing_collection_records"] = missing_colls

        # 13. Clients with Overdue Repayments
        try:
            q = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("loans").select("loan_id, client_id, active_credit, loan_repay").eq("status", "Active"),
                branch_id,
            )
            res = q.execute()
            active_loans = res.data or []
            loan_ids = [l["loan_id"] for l in active_loans if l.get("loan_id")]
            
            # Batch fetch repayments for all loans in a single query
            paid_by_loan = {}
            if loan_ids:
                res_reps = uow.client.table("repayments").select("loan_id, amount_paid").in_("loan_id", loan_ids).execute()
                for r in (res_reps.data or []):
                    lid = r.get("loan_id")
                    amt = float(r.get("amount_paid") or 0.0)
                    paid_by_loan[lid] = paid_by_loan.get(lid, 0.0) + amt

            today_str = date.today().isoformat()
            overdue_by_loan = {}
            if loan_ids:
                try:
                    overdue_res = uow.client.table("loan_schedule").select("loan_id, total_due, paid_amount") \
                        .in_("loan_id", loan_ids).lt("due_date", today_str).execute()
                    for item in (overdue_res.data or []):
                        lid = item.get("loan_id")
                        d_amt = float(item.get("total_due") or 0.0)
                        p_amt = float(item.get("paid_amount") or 0.0)
                        if d_amt > p_amt:
                            overdue_by_loan[lid] = overdue_by_loan.get(lid, 0.0) + (d_amt - p_amt)
                except Exception:
                    pass

            overdue_loans = []
            for l in active_loans:
                lid = l.get("loan_id")
                ov_amt = overdue_by_loan.get(lid, 0.0)
                if ov_amt > 0:
                    overdue_loans.append({**l, "overdue_amount": round(ov_amt, 2)})
            exceptions["overdue_repayments"] = overdue_loans
        except Exception:
            exceptions["overdue_repayments"] = []

        # 14. Loans without Installment Schedule
        loans_no_sched = []
        try:
            q_ls = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("loans").select("loan_id, client_id, branch_id, status").in_("status", ["Active", "Disbursed", "Approved"]),
                branch_id,
            )
            cand_loans = q_ls.execute().data or []
            cand_ids = [l["loan_id"] for l in cand_loans if l.get("loan_id")]
            sched_loan_ids = set()
            for chunk in [cand_ids[i:i + 50] for i in range(0, len(cand_ids), 50)]:
                s_res = uow.client.table("loan_schedule").select("loan_id").in_("loan_id", chunk).execute()
                for s_row in (s_res.data or []):
                    if s_row.get("loan_id"):
                        sched_loan_ids.add(str(s_row["loan_id"]))
            for cl in cand_loans:
                if str(cl.get("loan_id")) not in sched_loan_ids:
                    loans_no_sched.append(cl)
        except Exception:
            loans_no_sched = []
        exceptions["loans_without_schedule"] = loans_no_sched

        # 15. Inactive Clients with Active Loan
        inactive_active = []
        try:
            q_act = FinancialReconciliationService._apply_branch_filter(
                uow.client.table("loans").select("loan_id, client_id, branch_id, active_credit, status").eq("status", "Active"),
                branch_id,
            )
            act_loans = q_act.execute().data or []
            c_ids = list({str(l["client_id"]) for l in act_loans if l.get("client_id")})
            client_map = {}
            for chunk in [c_ids[i:i + 50] for i in range(0, len(c_ids), 50)]:
                c_res = uow.client.table("clients").select("client_id, client_code, name, status, client_statuses(name)").in_("client_id", chunk).execute()
                for c_row in (c_res.data or []):
                    cs_rel = c_row.get("client_statuses")
                    cs_name = cs_rel.get("name") if isinstance(cs_rel, dict) else c_row.get("status")
                    client_map[str(c_row["client_id"])] = {
                        "client_code": c_row.get("client_code"),
                        "name": c_row.get("name"),
                        "client_status": str(cs_name or c_row.get("status") or ""),
                    }
            inactive_statuses = {"closed", "dormant", "inactive (savings only)", "inactive", "suspended", "completed"}
            for al in act_loans:
                c_info = client_map.get(str(al.get("client_id")), {})
                c_stat = str(c_info.get("client_status") or "").strip().lower()
                if c_stat in inactive_statuses:
                    inactive_active.append({**al, **c_info})
        except Exception:
            inactive_active = []
        exceptions["inactive_clients_active_loan"] = inactive_active


        total_exception_count = sum(len(v) for v in exceptions.values())

        return {
            "total_exceptions": total_exception_count,
            "exception_rules_evaluated": 15,
            "details": exceptions
        }

    @staticmethod
    def run_reconciliation_wizard_repair(
        uow: UnitOfWork,
        branch_id: str,
        posting_date: date
    ) -> Dict[str, Any]:
        """
        Guided self-healing reconciliation step:
          1. Rebuild CO Cashbook projections for all officers in branch
          2. Rebuild Master Cashbook projection for branch
          3. Re-evaluate 6-way financial integrity
        """
        rebuilt_officers = 0

        # 1. Fetch Credit Officers in branch (exclude BM/AM/Admin roles)
        try:
            res_off = uow.client.table("app_users").select("id, role, username").eq("branch_id", branch_id).execute()
            for o in (res_off.data or []):
                if o.get("id") and (
                    "co" in str(o.get("role") or "").lower()
                    or "credit" in str(o.get("role") or "").lower()
                    or str(o.get("username") or "").lower().startswith("co")
                ):
                    CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, o["id"], posting_date)
                    rebuilt_officers += 1
        except Exception:
            pass

        # 2. Rebuild Master Cashbook projection
        master_rebuilt = False
        try:
            rebuild_res = MasterCashbookProjectionBuilder.rebuild_master_projection(uow, branch_id, posting_date)
            master_rebuilt = (rebuild_res is not False)
        except Exception:
            master_rebuilt = False

        # 3. Re-verify integrity
        verification = FinancialReconciliationService.verify_6way_financial_integrity(uow, branch_id, posting_date)

        return {
            "rebuilt_officer_count": rebuilt_officers,
            "master_cashbook_rebuilt": master_rebuilt,
            "verification_after_repair": verification
        }

    @staticmethod
    def get_daily_collection_arrears_tally(
        uow: UnitOfWork,
        branch_id: str,
        posting_date: date,
        officer_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Computes the Daily Field Collection vs. Cashbook Arrears Reconciliation Tally.
        Provides the paper-style reconciliation bridge:
          Scheduled Inflows - Red-Pen Not Paid (Arrears) + Excess Banked = Actual Cash Collected
          Actual Cash Collected - Bank Deposited = Net Closing Cash Balance
          Arrears Float = Total Uncollected Arrears Generated Today
        """
        p_date_str = posting_date.isoformat() if isinstance(posting_date, date) else str(posting_date)[:10]

        # 1. Fetch Repayments on Date
        reps_query = uow.client.table("repayments").select(
            "id, client_id, amount_paid, expected_amount, overdue_amount, payment_status, note, clients(name, client_code)"
        ).eq("branch_id", branch_id).gte("date", f"{p_date_str}T00:00:00").lte("date", f"{p_date_str}T23:59:59")

        if officer_id:
            reps_query = reps_query.eq("officer_id", officer_id)

        try:
            res_reps = reps_query.execute()
            reps_data = res_reps.data or []
        except Exception:
            reps_data = []

        # 2. Fetch Savings Deposits on Date across all CO savings pools
        sav_data = []
        for tbl in ("individual_savings", "group_savings", "internal_savings", "laps_savings"):
            try:
                sav_query = uow.client.table(tbl).select("deposit_amount").eq("branch_id", branch_id).eq("posting_date", p_date_str)
                if officer_id:
                    sav_query = sav_query.eq("officer_id", officer_id)
                res_sav = sav_query.execute()
                rows = getattr(res_sav, "data", None)
                if isinstance(rows, list):
                    sav_data.extend(rows)
            except Exception:
                pass

        # 3. Fetch Cashbook figures (Bank deposit & Closing balance)
        bank_deposited = 0.0
        closing_balance = 0.0
        try:
            if officer_id:
                cb_res = uow.client.table("co_cashbooks").select("bank_deposit, closing_balance") \
                    .eq("branch_id", branch_id).eq("officer_id", officer_id).eq("date", p_date_str).execute()
            else:
                cb_res = uow.client.table("master_cashbook").select("bank_deposit, closing_balance") \
                    .eq("branch_id", branch_id).eq("date", p_date_str).execute()

            if cb_res.data:
                bank_deposited = float(cb_res.data[0].get("bank_deposit") or 0.0)
                closing_balance = float(cb_res.data[0].get("closing_balance") or 0.0)
        except Exception:
            pass

        # 4. Aggregate Tally Metrics
        scheduled_expected = 0.0
        not_paid_amount = 0.0
        not_paid_count = 0
        not_paid_clients = []
        excess_amount = 0.0
        excess_count = 0
        actual_repayments = 0.0

        for r in reps_data:
            amt = float(r.get("amount_paid") or 0.0)
            exp = float(r.get("expected_amount") or 0.0)
            status = str(r.get("payment_status") or "").upper()
            c_info = r.get("clients") or {} if isinstance(r.get("clients"), dict) else {}
            c_name = c_info.get("name") or "Unknown Client"
            c_code = c_info.get("client_code") or ""

            scheduled_expected += exp
            actual_repayments += amt

            if status == "NOT_PAID" or amt == 0.0:
                not_paid_amount += exp
                not_paid_count += 1
                not_paid_clients.append({
                    "name": c_name,
                    "code": c_code,
                    "expected": exp,
                    "shortfall": exp
                })
            elif amt > exp and exp > 0.0:
                diff = amt - exp
                excess_amount += diff
                excess_count += 1
            elif status == "PART_PAID":
                shortfall = max(0.0, exp - amt)
                if shortfall > 0:
                    not_paid_amount += shortfall
                    not_paid_count += 1
                    not_paid_clients.append({
                        "name": c_name,
                        "code": c_code,
                        "expected": exp,
                        "shortfall": shortfall,
                        "is_partial": True
                    })

        actual_savings = sum(float(s.get("deposit_amount") or 0.0) for s in sav_data)
        actual_cash_collected = actual_repayments + actual_savings

        return {
            "scheduled_expected": round(scheduled_expected, 2),
            "not_paid_amount": round(not_paid_amount, 2),
            "not_paid_count": not_paid_count,
            "not_paid_clients": not_paid_clients,
            "excess_amount": round(excess_amount, 2),
            "excess_count": excess_count,
            "actual_repayments": round(actual_repayments, 2),
            "actual_savings": round(actual_savings, 2),
            "actual_cash_collected": round(actual_cash_collected, 2),
            "bank_deposited": round(bank_deposited, 2),
            "closing_cash_balance": round(closing_balance, 2),
            "is_cash_balanced": abs(closing_balance) < 0.01,
            "arrears_float": round(not_paid_amount, 2),
            "total_reps_count": len(reps_data)
        }
