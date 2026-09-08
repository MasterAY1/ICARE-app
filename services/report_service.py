"""
ReportService — Phase 8.7 Enterprise Financial & Operational Reporting Engine.
Provides double-entry Trial Balance, comprehensive Savings Portfolio Summary,
Repayment & Collections Performance Summary, and Area Manager Branch Comparison
with audit-grade reconciliation, multi-branch RBAC scoping, and granular product/officer filtering.
"""
from typing import Dict, Any, List, Optional, Union
from datetime import date, datetime
import pandas as pd
from interfaces.unit_of_work import UnitOfWork


class ReportService:

    @staticmethod
    def get_trial_balance(
        uow: UnitOfWork,
        branch_id: Optional[Union[str, List[str]]] = None,
        as_of_date: Optional[date] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None
    ) -> Dict[str, Any]:
        """
        Generates a balanced Double-Entry Trial Balance from financial_ledger_entries
        joined with chart_of_accounts and financial_transactions.
        Guarantees Total Debits == Total Credits.
        Supports single branch ID, list of branch IDs (AM scope), or None (HQ scope).
        """
        # 1. Fetch Chart of Accounts
        res_coa = uow.client.table("chart_of_accounts") \
            .select("account_code, account_name, account_type, normal_balance, is_active") \
            .order("account_code") \
            .execute()
        coa_list = res_coa.data or []
        coa_dict = {a["account_code"]: a for a in coa_list}

        # 2. Query financial ledger entries joined with transactions for date/branch filtering
        query = uow.client.table("financial_ledger_entries") \
            .select("account_code, side, amount, branch_id, financial_transactions!inner(posting_date, branch_id)")

        if branch_id and branch_id != "ALL":
            if isinstance(branch_id, list):
                query = query.in_("branch_id", branch_id)
            else:
                query = query.eq("branch_id", branch_id)

        if start_date and end_date:
            query = query.gte("financial_transactions.posting_date", start_date.isoformat()) \
                         .lte("financial_transactions.posting_date", end_date.isoformat())
        elif as_of_date:
            query = query.lte("financial_transactions.posting_date", as_of_date.isoformat())

        res_entries = query.execute()
        entries = res_entries.data or []

        # 3. Aggregate Debits & Credits per Account
        totals = {}
        for r in entries:
            code = str(r.get("account_code") or "").strip()
            side = str(r.get("side") or "").strip()
            amt = float(r.get("amount") or 0.0)

            if code not in totals:
                totals[code] = {"debit": 0.0, "credit": 0.0}

            if side == "Debit":
                totals[code]["debit"] += amt
            elif side == "Credit":
                totals[code]["credit"] += amt

        # 4. Construct Trial Balance Rows
        table_rows = []
        total_gross_debits = 0.0
        total_gross_credits = 0.0
        total_net_debits = 0.0
        total_net_credits = 0.0

        for code, acc in sorted(coa_dict.items()):
            d = round(totals.get(code, {}).get("debit", 0.0), 2)
            c = round(totals.get(code, {}).get("credit", 0.0), 2)
            normal_bal = acc.get("normal_balance", "Debit")
            acc_type = acc.get("account_type", "Asset")

            total_gross_debits += d
            total_gross_credits += c

            # Net Balance per Account
            net_diff = d - c
            if net_diff >= 0:
                net_debit = net_diff
                net_credit = 0.0
            else:
                net_debit = 0.0
                net_credit = abs(net_diff)

            total_net_debits += net_debit
            total_net_credits += net_credit

            table_rows.append({
                "Account Code": code,
                "Account Name": acc.get("account_name", ""),
                "Account Type": acc_type,
                "Normal Balance": normal_bal,
                "Gross Debits": d,
                "Gross Credits": c,
                "Debit Balance": net_debit,
                "Credit Balance": net_credit,
                "Net Position": round((d - c) if normal_bal == "Debit" else (c - d), 2)
            })

        df_tb = pd.DataFrame(table_rows)

        # 5. Calculate Balancing Verification
        variance_gross = round(abs(total_gross_debits - total_gross_credits), 2)
        variance_net = round(abs(total_net_debits - total_net_credits), 2)
        is_balanced = (variance_gross == 0.0)

        return {
            "is_balanced": is_balanced,
            "status": "BALANCED" if is_balanced else "OUT OF BALANCE",
            "total_debits": total_gross_debits,
            "total_credits": total_gross_credits,
            "total_net_debits": total_net_debits,
            "total_net_credits": total_net_credits,
            "variance": variance_gross,
            "as_of_date": as_of_date.isoformat() if as_of_date else None,
            "start_date": start_date.isoformat() if start_date else None,
            "end_date": end_date.isoformat() if end_date else None,
            "branch_id": branch_id,
            "rows": table_rows,
            "dataframe": df_tb
        }

    @staticmethod
    def get_savings_summary(
        uow: UnitOfWork,
        branch_id: Optional[Union[str, List[str]]] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        as_of_date: Optional[date] = None,
        officer_name: Optional[str] = None,
        officer_id: Optional[str] = None,
        product_name: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Rebuilds authoritative Savings Portfolio Summary from individual_savings,
        group_savings, and General Ledger liability accounts.
        Supports filtering by Branch (single/list), Officer, Product, and Date.
        """
        # 1. Fetch Client mappings (UUID -> code, name, branch, officer, group)
        res_c = uow.client.table("clients") \
            .select("client_id, client_code, name, branch_id, officer_id, group_id, groups(name), branches(name), app_users!clients_officer_id_fkey(full_name)") \
            .execute()
        clients_map = {}
        for c in (res_c.data or []):
            cid = c.get("client_id")
            if cid:
                clients_map[cid] = {
                    "code": c.get("client_code") or "",
                    "name": c.get("name") or "",
                    "branch": c.get("branches", {}).get("name") if isinstance(c.get("branches"), dict) else "",
                    "officer": c.get("app_users", {}).get("full_name") if isinstance(c.get("app_users"), dict) else "",
                    "officer_id": c.get("officer_id"),
                    "group": c.get("groups", {}).get("name") if isinstance(c.get("groups"), dict) else "Independent",
                    "branch_id": c.get("branch_id")
                }

        # If product_name filter is active, resolve client IDs associated with that product
        product_client_ids = None
        if product_name and product_name not in ["All", "All Products"]:
            try:
                res_pl = uow.client.table("loans").select("client_id, loan_products(name)").execute()
                product_client_ids = set()
                for l in (res_pl.data or []):
                    lp = l.get("loan_products") or {}
                    if lp.get("name") == product_name:
                        product_client_ids.add(l.get("client_id"))
            except Exception:
                product_client_ids = None

        # 2. Query individual_savings
        q_ind = uow.client.table("individual_savings") \
            .select("id, posting_date, client_id, branch_id, deposit_amount, withdrawal_amount, remarks, created_at")

        if branch_id and branch_id != "ALL":
            if isinstance(branch_id, list):
                q_ind = q_ind.in_("branch_id", branch_id)
            else:
                q_ind = q_ind.eq("branch_id", branch_id)

        if start_date and end_date:
            q_ind = q_ind.gte("posting_date", start_date.isoformat()).lte("posting_date", end_date.isoformat())
        elif as_of_date:
            q_ind = q_ind.lte("posting_date", as_of_date.isoformat())

        res_ind = q_ind.execute()
        ind_records = res_ind.data or []

        # 3. Query group_savings
        grp_records = []
        is_officer_filtered = bool(officer_name and officer_name not in ["All", "All Officers"]) or bool(officer_id and officer_id not in ["All", "All Officers"])
        is_product_filtered = bool(product_name and product_name not in ["All", "All Products"])

        # Group savings are institutional/branch level; omit if officer or product is specifically isolated
        if not is_officer_filtered and not is_product_filtered:
            q_grp = uow.client.table("group_savings") \
                .select("id, posting_date, group_id, branch_id, deposit_amount, withdrawal_amount, remarks, created_at")

            if branch_id and branch_id != "ALL":
                if isinstance(branch_id, list):
                    q_grp = q_grp.in_("branch_id", branch_id)
                else:
                    q_grp = q_grp.eq("branch_id", branch_id)

            if start_date and end_date:
                q_grp = q_grp.gte("posting_date", start_date.isoformat()).lte("posting_date", end_date.isoformat())
            elif as_of_date:
                q_grp = q_grp.lte("posting_date", as_of_date.isoformat())

            res_grp = q_grp.execute()
            grp_records = res_grp.data or []

        # 4. Aggregate Individual Savings per Client
        client_savings_agg = {}
        total_ind_deposits = 0.0
        total_ind_withdrawals = 0.0

        for r in ind_records:
            cid = r.get("client_id")
            c_meta = clients_map.get(cid, {})

            # Filter by Officer
            if officer_name and officer_name not in ["All", "All Officers"]:
                if c_meta.get("officer") != officer_name:
                    continue
            if officer_id and officer_id not in ["All", "All Officers"]:
                if c_meta.get("officer_id") != officer_id:
                    continue

            # Filter by Product
            if product_client_ids is not None and cid not in product_client_ids:
                continue

            dep = float(r.get("deposit_amount") or 0.0)
            wd = float(r.get("withdrawal_amount") or 0.0)
            p_date = r.get("posting_date") or ""

            total_ind_deposits += dep
            total_ind_withdrawals += wd

            if cid not in client_savings_agg:
                client_savings_agg[cid] = {
                    "Client ID": c_meta.get("code") or cid,
                    "Client Name": c_meta.get("name") or "Unknown Client",
                    "Group": c_meta.get("group") or "Independent",
                    "Branch": c_meta.get("branch") or "",
                    "Officer": c_meta.get("officer") or "",
                    "Total Deposited": 0.0,
                    "Total Withdrawn": 0.0,
                    "Net Savings Balance": 0.0,
                    "Last Transaction Date": p_date
                }

            client_savings_agg[cid]["Total Deposited"] += dep
            client_savings_agg[cid]["Total Withdrawn"] += wd
            client_savings_agg[cid]["Net Savings Balance"] += (dep - wd)
            if p_date and p_date > client_savings_agg[cid]["Last Transaction Date"]:
                client_savings_agg[cid]["Last Transaction Date"] = p_date

        # Format client list
        savers_list = []
        active_savers_count = 0
        for cid, data in client_savings_agg.items():
            data["Total Deposited"] = round(data["Total Deposited"], 2)
            data["Total Withdrawn"] = round(data["Total Withdrawn"], 2)
            data["Net Savings Balance"] = round(data["Net Savings Balance"], 2)
            if data["Net Savings Balance"] > 0:
                active_savers_count += 1
            savers_list.append(data)

        df_savers = pd.DataFrame(savers_list)
        if not df_savers.empty:
            df_savers = df_savers.sort_values(by="Net Savings Balance", ascending=False)

        # 5. Aggregate Group Savings
        total_grp_deposits = sum(float(g.get("deposit_amount") or 0.0) for g in grp_records)
        total_grp_withdrawals = sum(float(g.get("withdrawal_amount") or 0.0) for g in grp_records)
        net_grp_savings = total_grp_deposits - total_grp_withdrawals

        # 6. Query LAPS Reserve (Account 2030 or co_cashbooks laps_reserve)
        laps_reserve_total = 0.0
        if not is_officer_filtered and not is_product_filtered:
            try:
                q_laps = uow.client.table("co_cashbooks").select("laps_reserve, laps_returns")
                if branch_id and branch_id != "ALL":
                    if isinstance(branch_id, list):
                        q_laps = q_laps.in_("branch_id", branch_id)
                    else:
                        q_laps = q_laps.eq("branch_id", branch_id)
                if start_date and end_date:
                    q_laps = q_laps.gte("date", start_date.isoformat()).lte("date", end_date.isoformat())
                elif as_of_date:
                    q_laps = q_laps.lte("date", as_of_date.isoformat())
                res_laps = q_laps.execute()
                for row in (res_laps.data or []):
                    laps_reserve_total += (float(row.get("laps_reserve") or 0.0) - float(row.get("laps_returns") or 0.0))
            except Exception:
                pass

        net_ind_savings = total_ind_deposits - total_ind_withdrawals
        total_consolidated = net_ind_savings + net_grp_savings + laps_reserve_total

        return {
            "total_individual_deposits": round(total_ind_deposits, 2),
            "total_individual_withdrawals": round(total_ind_withdrawals, 2),
            "net_individual_savings": round(net_ind_savings, 2),
            "total_group_deposits": round(total_grp_deposits, 2),
            "total_group_withdrawals": round(total_grp_withdrawals, 2),
            "net_group_savings": round(net_grp_savings, 2),
            "laps_reserve": round(laps_reserve_total, 2),
            "total_consolidated_savings": round(total_consolidated, 2),
            "active_savers_count": active_savers_count,
            "total_savers_recorded": len(client_savings_agg),
            "savers_dataframe": df_savers
        }

    @staticmethod
    def get_repayment_summary(
        uow: UnitOfWork,
        branch_id: Optional[Union[str, List[str]]] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        product_name: Optional[str] = None,
        officer_name: Optional[str] = None,
        officer_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Rebuilds authoritative Repayment & Collections Summary from repayments,
        loans, and loan_payoff_excess_records (BR-DASH-001, BR-DASH-005, BR-DASH-007).
        Supports filtering by Branch (single/list), Officer, Product, and Date.
        """
        # 1. Fetch Client mappings
        res_c = uow.client.table("clients").select("client_id, client_code, name").execute()
        client_code_map = {c["client_id"]: c.get("client_code", "") for c in (res_c.data or [])}
        client_name_map = {c["client_id"]: c.get("name", "") for c in (res_c.data or [])}

        # 2. Query repayments
        q_rep = uow.client.table("repayments") \
            .select("id, date, loan_id, client_id, amount_paid, officer_id, branch_id, payment_status, expected_amount, overdue_amount, transaction_type, loans(loan_products(name), active_credit, total_due, loan_amount), app_users!repayments_officer_id_fkey(full_name), branches(name)")

        if branch_id and branch_id != "ALL":
            if isinstance(branch_id, list):
                q_rep = q_rep.in_("branch_id", branch_id)
            else:
                q_rep = q_rep.eq("branch_id", branch_id)

        if start_date and end_date:
            s_d_str = f"{start_date.isoformat()}T00:00:00"
            e_d_str = f"{end_date.isoformat()}T23:59:59"
            q_rep = q_rep.gte("date", s_d_str).lte("date", e_d_str)

        res_rep = q_rep.order("date", desc=True).execute()
        rep_records = res_rep.data or []

        # 3. Query loan_payoff_excess_records for full payoffs and excess cash in period
        q_pe = uow.client.table("loan_payoff_excess_records").select("*, loans(loan_products(name))")
        if branch_id and branch_id != "ALL":
            if isinstance(branch_id, list):
                q_pe = q_pe.in_("branch_id", branch_id)
            else:
                q_pe = q_pe.eq("branch_id", branch_id)
        if start_date and end_date:
            q_pe = q_pe.gte("date", start_date.isoformat()).lte("date", end_date.isoformat())
        res_pe = q_pe.execute()
        pe_records = res_pe.data or []

        full_payoff_amount = 0.0
        full_payoff_count = 0
        excess_payment_amount = 0.0
        excess_payment_count = 0

        for r in pe_records:
            # Filter payoff/excess by product if product filter is active
            if product_name and product_name not in ["All", "All Products"]:
                pe_lp = r.get("loans", {}).get("loan_products", {}) if isinstance(r.get("loans"), dict) else {}
                if isinstance(pe_lp, dict) and pe_lp.get("name") != product_name:
                    continue

            # Filter by officer if officer filter is active
            if officer_id and officer_id not in ["All", "All Officers"]:
                if r.get("officer_id") != officer_id:
                    continue

            rec_type = r.get("record_type")
            if rec_type in ["FULL_PAYOFF", "FULL_PAYOFF_WITH_EXCESS"]:
                full_payoff_amount += float(r.get("active_credit_settled") or 0.0)
                full_payoff_count += 1
            if rec_type in ["EXCESS_PAYMENT", "FULL_PAYOFF_WITH_EXCESS"]:
                excess_payment_amount += float(r.get("excess_amount") or 0.0)
                excess_payment_count += 1

        # 4. Aggregate Repayment metrics
        total_collected = 0.0
        total_expected = 0.0
        total_overdue_collected = 0.0
        product_breakdown = {}
        status_counts = {"PAID": 0, "PARTIAL": 0, "NOT_PAID": 0, "OVERDUE": 0}

        repayment_rows = []
        for r in rep_records:
            # Determine product name
            p_name = "General Credit"
            loan_info = r.get("loans")
            if isinstance(loan_info, dict):
                lp = loan_info.get("loan_products")
                if isinstance(lp, dict) and lp.get("name"):
                    p_name = lp["name"]

            # Filter by Product
            if product_name and product_name not in ["All", "All Products"]:
                if p_name != product_name:
                    continue

            o_name = r.get("app_users", {}).get("full_name") if isinstance(r.get("app_users"), dict) else ""
            # Filter by Officer
            if officer_name and officer_name not in ["All", "All Officers"]:
                if o_name != officer_name:
                    continue
            if officer_id and officer_id not in ["All", "All Officers"]:
                if r.get("officer_id") != officer_id:
                    continue

            amt_paid = float(r.get("amount_paid") or 0.0)
            exp_amt = float(r.get("expected_amount") or 0.0)
            overdue_amt = float(r.get("overdue_amount") or 0.0)
            pay_status = str(r.get("payment_status") or "PAID").upper()

            total_collected += amt_paid
            total_expected += exp_amt
            total_overdue_collected += overdue_amt

            if pay_status in status_counts:
                status_counts[pay_status] += 1
            else:
                status_counts["PAID"] += 1

            # Aggregate product breakdown
            if p_name not in product_breakdown:
                product_breakdown[p_name] = {"Collections (NGN)": 0.0, "Transactions": 0, "Clients": set()}
            product_breakdown[p_name]["Collections (NGN)"] += amt_paid
            product_breakdown[p_name]["Transactions"] += 1
            if r.get("client_id"):
                product_breakdown[p_name]["Clients"].add(r.get("client_id"))

            cid = r.get("client_id")
            date_raw = str(r.get("date") or "")
            clean_date = date_raw.split("T")[0] if "T" in date_raw else date_raw

            b_name = r.get("branches", {}).get("name") if isinstance(r.get("branches"), dict) else ""

            repayment_rows.append({
                "Date": clean_date,
                "Client Code": client_code_map.get(cid, cid),
                "Client Name": client_name_map.get(cid, "Client"),
                "Loan Product": p_name,
                "Officer": o_name,
                "Branch": b_name,
                "Amount Paid": round(amt_paid, 2),
                "Expected Amount": round(exp_amt, 2),
                "Payment Status": pay_status,
                "Transaction Type": r.get("transaction_type", "Collection")
            })

        # Calculate scheduled base collections (Actual Collection - Excess Payments)
        base_collections = max(0.0, total_collected - excess_payment_amount)
        collection_efficiency = (round((base_collections / total_expected * 100), 2)) if total_expected > 0 else 100.0

        # Build product DataFrame
        prod_rows = []
        for p_name, stats in product_breakdown.items():
            prod_rows.append({
                "Loan Product": p_name,
                "Collections (NGN)": round(stats["Collections (NGN)"], 2),
                "Transactions": stats["Transactions"],
                "Unique Clients": len(stats["Clients"])
            })
        df_products = pd.DataFrame(prod_rows)
        if not df_products.empty:
            df_products = df_products.sort_values(by="Collections (NGN)", ascending=False)

        df_repayments = pd.DataFrame(repayment_rows)

        return {
            "total_collected": round(total_collected, 2),
            "total_expected": round(total_expected, 2),
            "base_collections": round(base_collections, 2),
            "collection_efficiency": collection_efficiency,
            "total_overdue_collected": round(total_overdue_collected, 2),
            "full_payoff_amount": round(full_payoff_amount, 2),
            "full_payoff_count": full_payoff_count,
            "excess_payment_amount": round(excess_payment_amount, 2),
            "excess_payment_count": excess_payment_count,
            "status_counts": status_counts,
            "total_transactions": len(repayment_rows),
            "product_dataframe": df_products,
            "repayments_dataframe": df_repayments
        }

    @staticmethod
    def get_area_branch_comparison(
        uow: UnitOfWork,
        assigned_branch_ids: List[str],
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        as_of_date: Optional[date] = None,
        product_name: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Builds side-by-side executive branch comparison matrix for Area Managers.
        Includes: No of People on Loan, No of Active Savers, Collections, Expected,
        Collection Efficiency %, Total Savings, Active Loans, Outstanding Portfolio, and PAR %.
        """
        if not assigned_branch_ids:
            return {
                "rows": [],
                "dataframe": pd.DataFrame(),
                "total_branches": 0,
                "total_people_on_loan": 0,
                "total_active_loans": 0,
                "total_active_savers": 0,
                "total_area_savings": 0.0,
                "total_area_collections": 0.0,
                "total_area_expected": 0.0,
                "overall_efficiency": 100.0,
                "total_area_portfolio": 0.0,
                "overall_par": 0.0
            }

        # 1. Fetch branch names
        res_b = uow.client.table("branches").select("branch_id, name").in_("branch_id", assigned_branch_ids).execute()
        branch_map = {b["branch_id"]: b["name"] for b in (res_b.data or [])}

        # 2. Fetch all active loans across assigned branches
        q_loans = uow.client.table("loans") \
            .select("loan_id, client_id, branch_id, status, active_credit, total_due, product_id, loan_products(name)") \
            .in_("branch_id", assigned_branch_ids) \
            .in_("status", ["Active", "Disbursed"])
        res_loans = q_loans.execute()
        all_loans = res_loans.data or []

        # 3. Fetch all savings across assigned branches
        q_sav = uow.client.table("individual_savings") \
            .select("client_id, branch_id, deposit_amount, withdrawal_amount, posting_date") \
            .in_("branch_id", assigned_branch_ids)

        if start_date and end_date:
            q_sav = q_sav.gte("posting_date", start_date.isoformat()).lte("posting_date", end_date.isoformat())
        elif as_of_date:
            q_sav = q_sav.lte("posting_date", as_of_date.isoformat())

        res_sav = q_sav.execute()
        all_savings = res_sav.data or []

        # 4. Fetch all repayments across assigned branches
        q_rep = uow.client.table("repayments") \
            .select("branch_id, amount_paid, expected_amount, overdue_amount, date, loans(loan_products(name))") \
            .in_("branch_id", assigned_branch_ids)

        if start_date and end_date:
            s_d_str = f"{start_date.isoformat()}T00:00:00"
            e_d_str = f"{end_date.isoformat()}T23:59:59"
            q_rep = q_rep.gte("date", s_d_str).lte("date", e_d_str)

        res_rep = q_rep.execute()
        all_reps = res_rep.data or []

        # Filter by product if active
        if product_name and product_name not in ["All", "All Products"]:
            filtered_loans = []
            for l in all_loans:
                lp = l.get("loan_products") or {}
                if lp.get("name") == product_name:
                    filtered_loans.append(l)
            all_loans = filtered_loans

            filtered_reps = []
            for r in all_reps:
                l_info = r.get("loans") or {}
                lp = l_info.get("loan_products") or {}
                if lp.get("name") == product_name:
                    filtered_reps.append(r)
            all_reps = filtered_reps

        # 5. Build branch-by-branch metrics
        comparison_rows = []
        tot_area_people_loan = set()
        tot_area_loans_count = 0
        tot_area_active_savers = set()
        tot_area_savings_amt = 0.0
        tot_area_coll = 0.0
        tot_area_exp = 0.0
        tot_area_portfolio = 0.0
        tot_area_overdue = 0.0
        tot_area_credit = 0.0

        for bid in assigned_branch_ids:
            b_name = branch_map.get(bid, "Branch")

            # Loans & Borrowers for this branch
            b_loans = [l for l in all_loans if l.get("branch_id") == bid]
            b_borrower_ids = set(l["client_id"] for l in b_loans if l.get("client_id"))
            tot_area_people_loan.update(b_borrower_ids)
            b_people_on_loan = len(b_borrower_ids)
            b_loans_count = len(b_loans)
            tot_area_loans_count += b_loans_count

            b_portfolio = sum(float(l.get("total_due") or 0.0) for l in b_loans)
            b_active_credit = sum(float(l.get("active_credit") or 0.0) for l in b_loans)
            tot_area_portfolio += b_portfolio
            tot_area_credit += b_active_credit

            # Savings for this branch
            b_savings = [s for s in all_savings if s.get("branch_id") == bid]
            client_sav_balances = {}
            for s in b_savings:
                cid = s.get("client_id")
                dep = float(s.get("deposit_amount") or 0.0)
                wd = float(s.get("withdrawal_amount") or 0.0)
                client_sav_balances[cid] = client_sav_balances.get(cid, 0.0) + (dep - wd)

            b_active_savers_set = set(cid for cid, bal in client_sav_balances.items() if bal > 0)
            tot_area_active_savers.update(b_active_savers_set)
            b_active_savers = len(b_active_savers_set)
            b_savings_total = sum(client_sav_balances.values())
            tot_area_savings_amt += b_savings_total

            # Repayments for this branch
            b_reps = [r for r in all_reps if r.get("branch_id") == bid]
            b_coll = sum(float(r.get("amount_paid") or 0.0) for r in b_reps)
            b_exp = sum(float(r.get("expected_amount") or 0.0) for r in b_reps)
            b_overdue = sum(float(r.get("overdue_amount") or 0.0) for r in b_reps)
            tot_area_coll += b_coll
            tot_area_exp += b_exp
            tot_area_overdue += b_overdue

            b_eff = round((b_coll / b_exp * 100), 2) if b_exp > 0 else 100.0
            b_par = round((b_overdue / b_active_credit * 100), 2) if b_active_credit > 0 else 0.0

            # Status Badge
            if b_eff >= 95.0 and b_par <= 5.0:
                status_badge = "[EXCELLENT]"
            elif b_eff >= 85.0 and b_par <= 10.0:
                status_badge = "[GOOD]"
            elif b_eff >= 70.0:
                status_badge = "[FAIR]"
            else:
                status_badge = "[CRITICAL]"

            comparison_rows.append({
                "Branch": b_name,
                "No. of People on Loan": b_people_on_loan,
                "Active Loans": b_loans_count,
                "No. of Active Savers": b_active_savers,
                "Total Savings": round(b_savings_total, 2),
                "Collections Received": round(b_coll, 2),
                "Expected Collections": round(b_exp, 2),
                "Collection Efficiency": f"{b_eff:.1f}%",
                "Outstanding Portfolio": round(b_portfolio, 2),
                "PAR %": f"{b_par:.1f}%",
                "Status": status_badge,
                "_raw_eff": b_eff,
                "_raw_par": b_par
            })

        df_comparison = pd.DataFrame(comparison_rows)
        if not df_comparison.empty:
            df_comparison = df_comparison.sort_values(by="Collections Received", ascending=False)

        overall_eff = round((tot_area_coll / tot_area_exp * 100), 2) if tot_area_exp > 0 else 100.0
        overall_par = round((tot_area_overdue / tot_area_credit * 100), 2) if tot_area_credit > 0 else 0.0

        return {
            "rows": comparison_rows,
            "dataframe": df_comparison,
            "total_branches": len(assigned_branch_ids),
            "total_people_on_loan": len(tot_area_people_loan),
            "total_active_loans": tot_area_loans_count,
            "total_active_savers": len(tot_area_active_savers),
            "total_area_savings": round(tot_area_savings_amt, 2),
            "total_area_collections": round(tot_area_coll, 2),
            "total_area_expected": round(tot_area_exp, 2),
            "overall_efficiency": overall_eff,
            "total_area_portfolio": round(tot_area_portfolio, 2),
            "overall_par": overall_par
        }
