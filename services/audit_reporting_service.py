"""
AuditReportingService — Phase 8.1
Generates audit summary statistics, multi-level drill-down breakdowns,
and financial audit reports across Fee, Treasury, Savings, Loan, and Cashbook sub-systems.
"""
from typing import Dict, Any, List, Optional
from datetime import date, datetime
from interfaces.unit_of_work import UnitOfWork


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
        """
        if not records:
            return {
                "total_amount": 0.0,
                "total_count": 0,
                "average_amount": 0.0,
                "last_transaction_date": "N/A",
                "highest_amount": 0.0
            }

        amounts = [float(r.get(amount_key) or 0.0) for r in records]
        dates = [str(r.get("posting_date") or r.get("date") or r.get("meeting_date") or r.get("created_at") or "")[:10] for r in records]

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
            "highest_amount": max_amt
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
        if ledger_category == "FEE":
            records = uow.audit_views.get_fee_ledger(fee_or_txn_type, branch_id=branch_id, limit=500)
        else:
            records = uow.audit_views.get_treasury_ledger(fee_or_txn_type, branch_id=branch_id, limit=500)

        # 1. By Branch
        by_branch = {}
        for r in records:
            b_id = r.get("branch_id") or "Unknown"
            by_branch[b_id] = by_branch.get(b_id, 0.0) + float(r.get("amount") or 0.0)

        # 2. By Officer
        by_officer = {}
        for r in records:
            o_id = r.get("officer_id") or "Unknown"
            by_officer[o_id] = by_officer.get(o_id, 0.0) + float(r.get("amount") or 0.0)

        # 3. By Client
        by_client = {}
        for r in records:
            c_id = r.get("client_id") or "N/A (Treasury)"
            by_client[c_id] = by_client.get(c_id, 0.0) + float(r.get("amount") or 0.0)

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
