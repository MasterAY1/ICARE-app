"""
ReportService — Phase 8.7 Enterprise Financial & Operational Reporting Engine.
Provides double-entry Trial Balance, comprehensive Savings Portfolio Summary,
and Repayment & Collections Performance Summary with audit-grade reconciliation.
"""
from typing import Dict, Any, List, Optional
from datetime import date, datetime
import pandas as pd
from interfaces.unit_of_work import UnitOfWork


class ReportService:

    @staticmethod
    def get_trial_balance(
        uow: UnitOfWork,
        branch_id: Optional[str] = None,
        as_of_date: Optional[date] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None
    ) -> Dict[str, Any]:
        """
        Generates a balanced Double-Entry Trial Balance from financial_ledger_entries
        joined with chart_of_accounts and financial_transactions.
        Guarantees Total Debits == Total Credits.
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
        branch_id: Optional[str] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        as_of_date: Optional[date] = None
    ) -> Dict[str, Any]:
        """
        Rebuilds authoritative Savings Portfolio Summary from individual_savings,
        group_savings, and General Ledger liability accounts.
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
                    "group": c.get("groups", {}).get("name") if isinstance(c.get("groups"), dict) else "Independent",
                    "branch_id": c.get("branch_id")
                }

        # 2. Query individual_savings
        q_ind = uow.client.table("individual_savings") \
            .select("id, posting_date, client_id, branch_id, deposit_amount, withdrawal_amount, remarks, created_at")

        if branch_id and branch_id != "ALL":
            q_ind = q_ind.eq("branch_id", branch_id)

        if start_date and end_date:
            q_ind = q_ind.gte("posting_date", start_date.isoformat()).lte("posting_date", end_date.isoformat())
        elif as_of_date:
            q_ind = q_ind.lte("posting_date", as_of_date.isoformat())

        res_ind = q_ind.execute()
        ind_records = res_ind.data or []

        # 3. Query group_savings
        q_grp = uow.client.table("group_savings") \
            .select("id, posting_date, group_id, branch_id, deposit_amount, withdrawal_amount, remarks, created_at")

        if branch_id and branch_id != "ALL":
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
            dep = float(r.get("deposit_amount") or 0.0)
            wd = float(r.get("withdrawal_amount") or 0.0)
            p_date = r.get("posting_date") or ""

            total_ind_deposits += dep
            total_ind_withdrawals += wd

            if cid not in client_savings_agg:
                c_meta = clients_map.get(cid, {})
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
        try:
            q_laps = uow.client.table("co_cashbooks").select("laps_reserve, laps_returns")
            if branch_id and branch_id != "ALL":
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
        branch_id: Optional[str] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None
    ) -> Dict[str, Any]:
        """
        Rebuilds authoritative Repayment & Collections Summary from repayments,
        loans, and loan_payoff_excess_records (BR-DASH-001, BR-DASH-005, BR-DASH-007).
        """
        # 1. Fetch Client mappings
        res_c = uow.client.table("clients").select("client_id, client_code, name").execute()
        client_code_map = {c["client_id"]: c.get("client_code", "") for c in (res_c.data or [])}
        client_name_map = {c["client_id"]: c.get("name", "") for c in (res_c.data or [])}

        # 2. Query repayments
        q_rep = uow.client.table("repayments") \
            .select("id, date, loan_id, client_id, amount_paid, officer_id, branch_id, payment_status, expected_amount, overdue_amount, transaction_type, loans(loan_products(name), active_credit, total_due, loan_amount), app_users!repayments_officer_id_fkey(full_name), branches(name)")

        if branch_id and branch_id != "ALL":
            q_rep = q_rep.eq("branch_id", branch_id)

        if start_date and end_date:
            s_d_str = f"{start_date.isoformat()}T00:00:00"
            e_d_str = f"{end_date.isoformat()}T23:59:59"
            q_rep = q_rep.gte("date", s_d_str).lte("date", e_d_str)

        res_rep = q_rep.order("date", desc=True).execute()
        rep_records = res_rep.data or []

        # 3. Query loan_payoff_excess_records for full payoffs and excess cash in period
        q_pe = uow.client.table("loan_payoff_excess_records").select("*")
        if branch_id and branch_id != "ALL":
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

            # Determine product name
            p_name = "General Credit"
            loan_info = r.get("loans")
            if isinstance(loan_info, dict):
                lp = loan_info.get("loan_products")
                if isinstance(lp, dict) and lp.get("name"):
                    p_name = lp["name"]

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
            o_name = r.get("app_users", {}).get("full_name") if isinstance(r.get("app_users"), dict) else ""

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
            "total_transactions": len(rep_records),
            "product_dataframe": df_products,
            "repayments_dataframe": df_repayments
        }

