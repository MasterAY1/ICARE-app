"""
AuditReportingService — Phase 8.2
Generates executive audit summary statistics, multi-level drill-down breakdowns,
and financial audit metrics across Fee, Treasury, Savings, Loan, and Cashbook sub-systems.
"""

from typing import Dict, Any, List, Optional
from interfaces.unit_of_work import UnitOfWork
from services.audit_enricher_service import AuditEnricher


class AuditReportingService:

    @staticmethod
    def calculate_summary_metrics(records: List[Dict[str, Any]], amount_key: str = "amount") -> Dict[str, Any]:
        """
        Calculate standard audit page top metrics:
          - Total Amount
          - Transaction Count
          - Average Transaction
          - Last Transaction Date
          - Highest Transaction
          - Unique Customers
        """
        if not records:
            return {
                "total_amount": 0.0,
                "total_count": 0,
                "average_amount": 0.0,
                "last_transaction_date": "N/A",
                "highest_amount": 0.0,
                "unique_customers": 0
            }

        amounts = []
        for r in records:
            val = r.get("Amount_Raw") if "Amount_Raw" in r else (
                r.get("Principal_Raw") if "Principal_Raw" in r else (
                    r.get("Deposit_Raw") if "Deposit_Raw" in r else (
                        r.get("Amount Paid_Raw") if "Amount Paid_Raw" in r else r.get(amount_key, 0.0)
                    )
                )
            )
            try:
                amounts.append(float(val or 0.0))
            except (ValueError, TypeError):
                amounts.append(0.0)

        dates = [str(r.get("Date") or r.get("Posting Date") or r.get("posting_date") or r.get("date") or r.get("created_at") or "")[:10] for r in records]
        clients = set([str(r.get("Client Code") or r.get("client_id") or "") for r in records if r.get("Client Code") or r.get("client_id")])

        total_amt = sum(amounts)
        count = len(records)
        avg_amt = total_amt / count if count > 0 else 0.0
        max_amt = max(amounts) if amounts else 0.0
        last_date = sorted(dates, reverse=True)[0] if dates and any(dates) else "N/A"

        return {
            "total_amount": total_amt,
            "total_count": count,
            "average_amount": round(avg_amt, 2),
            "last_transaction_date": last_date,
            "highest_amount": max_amt,
            "unique_customers": len(clients)
        }

    @staticmethod
    def get_multi_level_drilldown(
        uow: UnitOfWork,
        ledger_category: str,
        fee_or_txn_type: str,
        branch_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Multi-level drill-down helper:
        Total → By Branch → By Officer → By Client → Original Loan → Ledger Entries → Event Store.
        """
        enricher = AuditEnricher(uow=uow)
        enricher.load_lookups()

        if ledger_category == "FEE":
            records = uow.audit_views.get_fee_ledger(fee_or_txn_type, branch_id=branch_id, limit=500)
        else:
            records = uow.audit_views.get_treasury_ledger(fee_or_txn_type, branch_id=branch_id, limit=500)

        # 1. By Branch
        by_branch = {}
        for r in records:
            b_name = enricher.resolve_branch(r.get("branch_id"))
            by_branch[b_name] = by_branch.get(b_name, 0.0) + float(r.get("amount") or 0.0)

        # 2. By Officer
        by_officer = {}
        for r in records:
            o_name = enricher.resolve_officer(r.get("officer_id"))
            by_officer[o_name] = by_officer.get(o_name, 0.0) + float(r.get("amount") or 0.0)

        # 3. By Client
        by_client = {}
        for r in records:
            c_info = enricher.resolve_client(r.get("client_id"))
            c_label = c_info["full_label"] if c_info["code"] != "N/A" else "N/A (Treasury)"
            by_client[c_label] = by_client.get(c_label, 0.0) + float(r.get("amount") or 0.0)

        total = sum(float(r.get("amount") or 0.0) for r in records)

        return {
            "category": ledger_category,
            "type": fee_or_txn_type,
            "total": total,
            "count": len(records),
            "by_branch": by_branch,
            "by_officer": by_officer,
            "by_client": by_client,
            "raw_records": records[:100]
        }
