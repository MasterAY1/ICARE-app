"""
Legacy LAPS Bulk Migration Service (Phase 8)
Supports importing historical legacy LAPS (Loan Application Savings) balances
with full metadata tracking (migration_batch_id, migration_source, owner_known),
emitting LapsMigrated domain events, posting double-entry ledger rules (DR 3000 Opening Equity, CR 2030 LAPS Savings),
and zero-cash vault cashbook projection rebuilds.
"""

import uuid
from datetime import datetime, date
from typing import List, Dict, Any, Optional
from domain.entities.savings import LapsSavings
from domain.entities.event_store import DomainEvent
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.posting_engine import FinancialPostingEngine


class LAPSMigrationService:

    @staticmethod
    def migrate_legacy_laps(
        uow: SupabaseUnitOfWork,
        records: List[Dict[str, Any]],
        user_id: str = "Super Admin",
        batch_id: Optional[str] = None,
        source_name: str = "EXCEL_MIGRATION"
    ) -> Dict[str, Any]:
        """
        Processes a bulk migration batch of legacy LAPS records.

        Expected record keys:
          - client_id (Optional[str])
          - client_name (str)
          - branch (str)
          - officer (str)
          - amount / balance (float)
          - owner_known (Optional[bool] or Optional[str], e.g. "Yes"/"No", True/False)
          - remarks (Optional[str])
        """
        if not batch_id:
            date_prefix = datetime.now().strftime("%Y%m%d")
            random_suffix = str(uuid.uuid4())[:8].upper()
            batch_id = f"LAPS-MIG-{date_prefix}-{random_suffix}"

        success_count = 0
        failed_count = 0
        total_amount = 0.0
        errors = []
        affected_branches = set()

        for idx, rec in enumerate(records, start=1):
            try:
                amt = float(rec.get("amount") or rec.get("balance") or rec.get("laps_balance") or 0.0)
                if amt <= 0:
                    errors.append(f"Row {idx}: Amount must be greater than zero (got {amt})")
                    failed_count += 1
                    continue

                client_name = str(rec.get("client_name") or rec.get("name") or "Legacy Account").strip()
                c_id = rec.get("client_id") or rec.get("client_code")
                if c_id:
                    c_id = str(c_id).strip()

                branch = str(rec.get("branch") or rec.get("branch_name") or "Main Branch").strip()
                officer = str(rec.get("officer") or rec.get("officer_name") or user_id).strip()
                remarks = rec.get("remarks") or f"Legacy LAPS migration batch {batch_id}"

                # Determine owner_known flag
                raw_owner_known = rec.get("owner_known")
                if raw_owner_known is not None:
                    if isinstance(raw_owner_known, bool):
                        owner_known = raw_owner_known
                    elif isinstance(raw_owner_known, str):
                        owner_known = raw_owner_known.strip().lower() in ["yes", "true", "1", "y"]
                    else:
                        owner_known = bool(raw_owner_known)
                else:
                    owner_known = bool(c_id and c_id.strip())

                # If owner is not known, clear client_id to prevent false linkage
                if not owner_known:
                    c_id = None

                entity = LapsSavings(
                    client_id=c_id or "",
                    client_name=client_name,
                    branch=branch,
                    officer=officer,
                    deposit_amount=amt,
                    withdrawal_amount=0.0,
                    reference=batch_id,
                    remarks=remarks,
                    date=datetime.now(),
                    migration_batch_id=batch_id,
                    migration_source=source_name,
                    owner_known=owner_known
                )

                # 1. Persist operational LAPS record
                uow.laps_savings.create(entity)

                # 2. Audit log entry
                uow.audit.log_action(
                    officer,
                    "Super Admin",
                    "Legacy LAPS Migration",
                    "laps_savings",
                    entity.id,
                    None,
                    {
                        "deposit": amt,
                        "batch_id": batch_id,
                        "source": source_name,
                        "owner_known": owner_known,
                        "client_name": client_name
                    }
                )

                # 3. Create Domain Event & Post to Double-Entry Ledger
                event = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=entity.id,
                    aggregate_type="LapsSavings",
                    event_type="LapsMigrated",
                    payload={
                        "branch": branch,
                        "officer": officer,
                        "amount": amt,
                        "reference": batch_id,
                        "narration": f"Legacy LAPS migration balance for {client_name} (Batch: {batch_id})",
                        "migration_batch_id": batch_id,
                        "owner_known": owner_known
                    }
                )
                uow.event_store.append(event)
                FinancialPostingEngine.post_event(uow, event)

                affected_branches.add(branch)
                success_count += 1
                total_amount += amt

            except Exception as ex:
                failed_count += 1
                errors.append(f"Row {idx} ({rec.get('client_name', 'Unknown')}): {str(ex)}")

        # Rebuild projections for all affected branches
        for b_name in affected_branches:
            try:
                b_id = uow.laps_savings._resolve_branch_id(b_name)
                uow.cashbook.rebuild_projection(b_id, date.today().isoformat())
            except Exception as ex:
                print(f"[LAPS MIGRATION WARNING] Failed rebuilding projection for branch {b_name}: {ex}")

        return {
            "batch_id": batch_id,
            "total_records": len(records),
            "success_count": success_count,
            "failed_count": failed_count,
            "total_amount_migrated": total_amount,
            "affects_cash_vault": False,  # Opening equity ledger movement - zero cash vault impact!
            "errors": errors
        }
