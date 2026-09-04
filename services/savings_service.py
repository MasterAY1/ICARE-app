import uuid
from datetime import datetime, date
from typing import Optional, Any
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.savings import IndividualSavings, GroupSavings, MiscSavings, LapsSavings
from domain.entities.repayment import Repayment
from domain.entities.event_store import DomainEvent
from domain.enums import TransactionClassification
from services.withdrawal_classification_engine import WithdrawalClassificationEngine
from services.posting_engine import FinancialPostingEngine

class SavingsService:
    @staticmethod
    def post_individual_savings(uow: SupabaseUnitOfWork, client_id: str, client_name: str, branch: str, officer: str, deposit_amount: float, withdrawal_amount: float = 0.0, reference: str = None, remarks: str = None, posting_date: Optional[Any] = None, savings_id: Optional[str] = None):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return
            
        p_dt = posting_date if posting_date else datetime.now()
        # Check Business Date Freeze & Working Day (BR-DATE-002)
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if hasattr(p_dt, 'date') and not isinstance(p_dt, date) else p_dt
        is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot post savings. {reason}.")

        entity = IndividualSavings(
            id=savings_id,
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=remarks,
            date=p_dt
        )
        # 1. Persist operational data
        uow.individual_savings.create(entity)
        
        try:
            # 2. Audit
            action = "Individual Savings Deposit" if deposit_amount > 0 else "Individual Savings Withdrawal"
            uow.audit.log_action(officer, "Credit Officer", action, "individual_savings", entity.id, None, {"deposit": deposit_amount, "withdrawal": withdrawal_amount})

            # 3. Create Event & Post
            event_type = "SavingsDeposited" if deposit_amount > 0 else "SavingsWithdrawn"
            amt = deposit_amount if deposit_amount > 0 else withdrawal_amount
            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=entity.id,
                aggregate_type="IndividualSavings",
                event_type=event_type,
                payload={
                    "branch": branch,
                    "officer": officer,
                    "amount": amt,
                    "reference": reference or entity.id,
                    "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt),
                    "narration": remarks or f"Individual savings transaction for client {client_name}"
                }
            )
            uow.event_store.append(event)
            FinancialPostingEngine.post_event(uow, event)
        except Exception as e:
            try:
                uow.client.table("individual_savings").delete().eq("id", entity.id).execute()
            except Exception:
                pass
            raise e

    @staticmethod
    def post_group_savings(uow: SupabaseUnitOfWork, group_name: str, branch: str, officer: str, deposit_amount: float, withdrawal_amount: float = 0.0, reference: str = None, remarks: str = None, posting_date: Optional[Any] = None, group_id: Optional[str] = None, group_savings_id: Optional[str] = None):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return
            
        p_dt = posting_date if posting_date else datetime.now()
        # Check Business Date Freeze & Working Day (BR-DATE-002)
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if hasattr(p_dt, 'date') and not isinstance(p_dt, date) else p_dt
        is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot post group savings. {reason}.")

        entity = GroupSavings(
            id=group_savings_id,
            group_name=group_name,
            branch=branch,
            officer=officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=remarks,
            date=p_dt,
            group_id=group_id
        )
        # 1. Persist operational data
        uow.group_savings.create(entity)
        
        try:
            # 2. Audit
            action = "Group Savings Deposit" if deposit_amount > 0 else "Group Savings Withdrawal"
            uow.audit.log_action(officer, "Credit Officer", action, "group_savings", entity.id, None, {"deposit": deposit_amount, "withdrawal": withdrawal_amount})

            # 3. Create Event & Post
            event_type = "SavingsDeposited" if deposit_amount > 0 else "SavingsWithdrawn"
            amt = deposit_amount if deposit_amount > 0 else withdrawal_amount
            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=entity.id,
                aggregate_type="GroupSavings",
                event_type=event_type,
                payload={
                    "branch": branch,
                    "officer": officer,
                    "amount": amt,
                    "reference": reference or entity.id,
                    "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt),
                    "narration": remarks or f"Group savings transaction for group {group_name}",
                    "group_id": group_id
                }
            )
            uow.event_store.append(event)
            FinancialPostingEngine.post_event(uow, event)
        except Exception as e:
            try:
                uow.client.table("group_savings").delete().eq("id", entity.id).execute()
            except Exception:
                pass
            raise e

    @staticmethod
    def get_branch_misc_savings_officer(uow: SupabaseUnitOfWork, branch: str) -> tuple[str, str]:
        """
        BR-SAV-006: Resolves the designated managing officer for Misc Savings per branch.
        Returns tuple: (officer_id, officer_name/username)
        """
        # Default map for known branches
        branch_lower = (branch or "").strip().lower()
        if "ogijo" in branch_lower or not branch:
            # Ogijo branch designated officer is CO3 (Miss. Olajumoke)
            return ("60fa48a4-16a2-4ab8-b9c5-d13d72a040cc", "CO3")
        
        # Look up from branch extra_fields or app_users
        try:
            b_res = uow.client.table("branches").select("*").ilike("name", f"%{branch}%").execute()
            if b_res.data:
                b_info = b_res.data[0]
                ext = b_info.get("extra_fields") or {}
                if isinstance(ext, dict) and ext.get("misc_savings_officer_id"):
                    return (ext["misc_savings_officer_id"], ext.get("misc_savings_officer_name", "CO3"))
                
                # Look up first active CO for this branch
                u_res = uow.client.table("app_users").select("id, username").eq("branch_id", b_info["branch_id"]).execute()
                for u in (u_res.data or []):
                    if "co" in str(u.get("username", "")).lower():
                        return (u["id"], u["username"])
        except Exception:
            pass
        return ("60fa48a4-16a2-4ab8-b9c5-d13d72a040cc", "CO3")

    @staticmethod
    @staticmethod
    def post_misc_savings(uow: SupabaseUnitOfWork, client_id: str, client_name: str, branch: str, officer: str, deposit_amount: float, withdrawal_amount: float = 0.0, reference: str = None, remarks: str = None, posting_date: Optional[Any] = None):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return
            
        managing_id, managing_name = SavingsService.get_branch_misc_savings_officer(uow, branch)
        collecting_officer = officer or "Unknown Officer"
        
        narr = remarks or (f"Misc savings collected by {collecting_officer} (Managed by {managing_name})" if deposit_amount > 0 else f"Misc savings withdrawal for {client_name}")
        
        p_dt = posting_date if posting_date else datetime.now()
        entity = MiscSavings(
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=managing_name,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=narr,
            date=p_dt
        )
        # 1. Persist operational data (Internal savings mapped to managing officer)
        uow.misc_savings.create(entity)
        
        # 2. Audit Trace: Capture both collecting officer and managing officer
        action = "Misc Savings Collected" if deposit_amount > 0 else "Misc Savings Withdrawal"
        amt = deposit_amount if deposit_amount > 0 else withdrawal_amount
        uow.audit.log_action(
            collecting_officer, 
            "Credit Officer", 
            action, 
            "internal_savings", 
            entity.id, 
            None, 
            {
                "deposit": deposit_amount,
                "withdrawal": withdrawal_amount,
                "collecting_officer": collecting_officer,
                "managing_officer": managing_name,
                "managing_officer_id": managing_id,
                "client_name": client_name
            }
        )

        # 3. Create Event & Post
        event_type = "SavingsDeposited" if deposit_amount > 0 else "SavingsWithdrawn"
        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=entity.id,
            aggregate_type="MiscSavings",
            event_type=event_type,
            payload={
                "branch": branch,
                "officer": managing_name,
                "collecting_officer": collecting_officer,
                "amount": amt,
                "reference": reference or entity.id,
                "narration": narr,
                "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt)
            }
        )
        uow.event_store.append(event)
        FinancialPostingEngine.post_event(uow, event)

    @staticmethod
    def post_laps_savings(uow: SupabaseUnitOfWork, client_id: str, client_name: str, branch: str, officer: str, deposit_amount: float, withdrawal_amount: float = 0.0, reference: str = None, remarks: str = None, posting_date: Optional[Any] = None):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return

        p_dt = posting_date if posting_date else datetime.now()
        entity = LapsSavings(
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=remarks,
            date=p_dt
        )
        # 1. Persist operational data
        uow.laps_savings.create(entity)
        
        # 2. Audit
        uow.audit.log_action(officer, "Credit Officer", "LAPS Transaction", "laps_savings", entity.id, None, {"deposit": deposit_amount, "withdrawal": withdrawal_amount})

        # 3. Create Event & Post
        event_type = "SavingsDeposited" if deposit_amount > 0 else "SavingsWithdrawn"
        amt = deposit_amount if deposit_amount > 0 else withdrawal_amount
        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=entity.id,
            aggregate_type="LapsSavings",
            event_type=event_type,
            payload={
                "branch": branch,
                "officer": officer,
                "amount": amt,
                "reference": reference or entity.id,
                "narration": remarks or f"LAPS savings transaction for client {client_name}",
                "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt)
            }
        )
        uow.event_store.append(event)
        FinancialPostingEngine.post_event(uow, event)

    @staticmethod
    def get_branch_totals(uow: SupabaseUnitOfWork, branch: str) -> dict:
        ind = uow.individual_savings.get_total_balance(branch)
        grp = uow.group_savings.get_total_balance(branch)
        msc = uow.misc_savings.get_total_balance(branch)
        laps = uow.laps_savings.get_total_balance(branch)
        
        return {
            "individual_savings": ind,
            "group_savings": grp,
            "misc_savings": msc,
            "laps_savings": laps,
            "total_active_savings": ind + grp + msc
        }

    @staticmethod
    def get_officer_totals(uow: SupabaseUnitOfWork, branch: str, officer: str) -> dict:
        ind = uow.individual_savings.get_total_balance(branch, officer)
        grp = uow.group_savings.get_total_balance(branch, officer)
        laps = uow.laps_savings.get_total_balance(branch, officer)
        
        managing_id, managing_name = SavingsService.get_branch_misc_savings_officer(uow, branch)
        officer_clean = str(officer or "").strip().lower()
        
        # BR-SAV-002: If officer is the designated Misc Savings manager, include all branch Misc Savings
        if officer_clean == managing_name.lower() or officer_clean == managing_id.lower() or "co3" in officer_clean:
            msc = uow.misc_savings.get_total_balance(branch)
        else:
            msc = 0.0
        
        return {
            "individual_savings": ind,
            "group_savings": grp,
            "misc_savings": msc,
            "laps_savings": laps,
            "total_active_savings": ind + grp + msc
        }

    @staticmethod
    def post_loan_offset_from_savings(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        loan_id: str,
        source_savings_type: str,
        branch: str,
        officer: str,
        amount: float,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None
    ) -> dict:
        """
        Executes atomic loan offset using client savings balance:
        - Reduces client savings (source_savings_type)
        - Creates loan repayment record against loan_id
        - Emits LoanOffsetFromSavings domain event (ZERO physical cash movement)
        - Logs audit record
        """
        if amount <= 0:
            raise ValueError("Offset amount must be greater than zero.")

        p_dt = posting_date if posting_date else datetime.now()

        cls_info = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LOAN_OFFSET, amount
        )

        source_entity = None
        repayment_entity = None

        if source_savings_type == "GroupSavings":
            source_entity = GroupSavings(
                group_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"Loan offset withdrawal from GroupSavings",
                date=p_dt
            )
            uow.group_savings.create(source_entity)
        elif source_savings_type == "MiscSavings":
            source_entity = MiscSavings(
                client_id=client_id,
                client_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"Loan offset withdrawal from MiscSavings",
                date=p_dt
            )
            uow.misc_savings.create(source_entity)
        else: # IndividualSavings
            source_entity = IndividualSavings(
                client_id=client_id,
                client_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"Loan offset withdrawal from IndividualSavings",
                date=p_dt
            )
            uow.individual_savings.create(source_entity)

            # Fetch target loan product details for projection routing
            prod_name = ""
            cycle = "Weekly"
            is_asset = False
            target_client_id = client_id
            try:
                res_l = uow.client.table("loans").select("loan_id, client_id, is_asset, product_category, loan_products(name, repayment_cycle)").eq("loan_id", loan_id).execute()
                if res_l.data:
                    l_row = res_l.data[0]
                    target_client_id = l_row.get("client_id") or client_id
                    is_asset = bool(l_row.get("is_asset") or ("asset" in str(l_row.get("product_category") or "").lower()))
                    lp = l_row.get("loan_products") or {}
                    prod_name = str(lp.get("name") or "").lower()
                    cycle = lp.get("repayment_cycle") or ("Daily" if "daily" in prod_name else ("Weekly" if "weekly" in prod_name else "Monthly"))
            except Exception:
                pass

            repayment_entity = Repayment(
                id=str(uuid.uuid4()),
                loan_id=loan_id,
                client_id=target_client_id,
                amount_paid=amount,
                savings_amount=0.0,
                loan_repayment_amount=amount,
                withdrawal_amount=0.0,
                others_amount=0.0,
                recovery_amount=0.0,
                initial_payment=0.0,
                payment_date=p_dt.date() if hasattr(p_dt, 'date') and callable(p_dt.date) else p_dt,
                transaction_type="LOAN_OFFSET",
                branch=branch,
                credit_officer=officer,
                payment_status="PAID",
                note=remarks or f"Loan offset of {amount} from {source_savings_type}"
            )
            uow.repayments.create(repayment_entity)

            # Advance loan schedule chronologically
            try:
                from services.schedule_service import ScheduleService
                p_date_only = p_dt.date() if hasattr(p_dt, 'date') and callable(p_dt.date) else p_dt
                ScheduleService.record_repayment(uow, loan_id, amount, p_date_only)
            except Exception as se:
                print(f"[LOAN OFFSET TRACE] Schedule advancement warning: {se}")

            # Check if loan is fully paid and transition status
            try:
                from services.client_status_service import ClientStatusService
                ClientStatusService.on_loan_repayment_check(uow, target_client_id, loan_id)
            except Exception as ce:
                print(f"[LOAN OFFSET TRACE] Client status update warning: {ce}")

            uow.audit.log_action(
                officer,
                "Credit Officer",
                "Loan Offset From Savings",
                "loans",
                loan_id,
                None,
                {"amount": amount, "source": source_savings_type, "savings_id": source_entity.id}
            )

            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=source_entity.id,
                aggregate_type="LoanOffset",
                event_type="LoanOffsetFromSavings",
                payload={
                    "client_id": target_client_id,
                    "source_client_id": client_id,
                    "loan_id": loan_id,
                    "source_savings_type": source_savings_type,
                    "branch": branch,
                    "officer": officer,
                    "amount": amount,
                    "loan_product": prod_name,
                    "cycle": cycle,
                    "is_asset": is_asset,
                    "reference": reference or source_entity.id,
                    "classification": TransactionClassification.LOAN_OFFSET.value,
                    "narration": remarks or f"Loan offset of {amount:,.2f} from {source_savings_type} for loan {loan_id}",
                    "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt)
                }
            )
            uow.event_store.append(event)
            try:
                FinancialPostingEngine.post_event(uow, event)
            except ValueError as ve:
                if "No active posting rule found" in str(ve):
                    pass
                else:
                    raise ve

            return {
                "status": "SUCCESS",
                "event_id": event.event_id,
                "amount": amount,
                "source_savings_id": source_entity.id,
                "repayment_id": repayment_entity.id,
                "affects_cash_vault": cls_info["affects_cash_vault"]
            }

    @staticmethod
    def post_fee_offset_from_savings(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        source_savings_type: str,
        branch: str,
        officer: str,
        fee_type: str,
        amount: float,
        target_client_id: Optional[str] = None,
        target_client_name: Optional[str] = None,
        reference: Optional[str] = None,
        remarks: Optional[str] = None,
        posting_date: Optional[Any] = None
    ) -> dict:
        """
        Executes atomic non-cash fee payment deducted from savings:
        - Reduces client savings (source_savings_type)
        - Emits FeeOffsetFromSavings domain event (DR 2000, CR 3000)
        - Symmetrically projects to product_withdrawal on Right and fee column on Left
        - Zero physical vault cash movement (Account 1000 untouched)
        """
        if amount <= 0:
            raise ValueError("Fee offset amount must be greater than zero.")

        p_dt = posting_date if posting_date else datetime.now()

        source_entity = None
        if source_savings_type == "GroupSavings":
            source_entity = GroupSavings(
                group_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"Fee offset ({fee_type}) from GroupSavings",
                date=p_dt
            )
            uow.group_savings.create(source_entity)
        elif source_savings_type == "MiscSavings":
            source_entity = MiscSavings(
                client_id=client_id,
                client_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"Fee offset ({fee_type}) from MiscSavings",
                date=p_dt
            )
            uow.misc_savings.create(source_entity)
        else:
            source_entity = IndividualSavings(
                client_id=client_id,
                client_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"Fee offset ({fee_type}) from IndividualSavings",
                date=p_dt
            )
            uow.individual_savings.create(source_entity)

        try:
            uow.audit.log_action(
                officer,
                "Credit Officer",
                "Fee Offset From Savings",
                "fees",
                source_entity.id,
                None,
                {"amount": amount, "fee_type": fee_type, "source": source_savings_type, "savings_id": source_entity.id}
            )

            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=source_entity.id,
                aggregate_type="FeeOffset",
                event_type="FeeOffsetFromSavings",
                payload={
                    "client_id": target_client_id or client_id,
                    "client_name": target_client_name or client_name,
                    "source_savings_type": source_savings_type,
                    "fee_type": fee_type,
                    "branch": branch,
                    "officer": officer,
                    "amount": amount,
                    "reference": reference or source_entity.id,
                    "classification": "FeeOffset",
                    "narration": remarks or f"Fee offset ({fee_type}) of {amount:,.2f} from {source_savings_type}",
                    "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt)
                }
            )
            uow.event_store.append(event)
            FinancialPostingEngine.post_event(uow, event)

            return {
                "status": "SUCCESS",
                "event_id": event.event_id,
                "amount": amount,
                "source_savings_id": source_entity.id,
                "fee_type": fee_type,
                "affects_cash_vault": False
            }
        except Exception as e:
            if source_entity and source_entity.id:
                tbl = "group_savings" if source_savings_type == "GroupSavings" else ("misc_savings" if source_savings_type == "MiscSavings" else "individual_savings")
                try:
                    uow.client.table(tbl).delete().eq("id", source_entity.id).execute()
                except Exception:
                    pass
            raise e

    @staticmethod
    def transfer_savings(
        uow: SupabaseUnitOfWork,
        source_id: str,
        source_name: str,
        source_type: str,
        destination_id: str,
        destination_name: str,
        destination_type: str,
        branch: str,
        officer: str,
        amount: float,
        reference: Optional[str] = None,
        remarks: Optional[str] = None,
        posting_date: Optional[Any] = None
    ) -> dict:
        """
        Executes atomic peer-to-peer or peer-to-group savings reallocation:
        - Decreases source savings (withdrawal_amount = amount)
        - Increases destination savings (deposit_amount = amount)
        - Emits SavingsTransferred domain event (DR 2000, CR 2000)
        - Projects product_withdrawal on Right, savings_deposit on Left
        - Zero physical vault cash movement (Account 1000 untouched)
        """
        if amount <= 0:
            raise ValueError("Transfer amount must be greater than zero.")

        p_dt = posting_date if posting_date else datetime.now()

        source_entity = None
        dest_entity = None

        # 1. Deduct from Source
        if source_type == "GroupSavings":
            source_entity = GroupSavings(
                group_name=source_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"Transfer to {destination_name} ({destination_type})",
                date=p_dt
            )
            uow.group_savings.create(source_entity)
        elif source_type == "MiscSavings":
            source_entity = MiscSavings(
                client_id=source_id,
                client_name=source_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"Transfer to {destination_name} ({destination_type})",
                date=p_dt
            )
            uow.misc_savings.create(source_entity)
        else:
            source_entity = IndividualSavings(
                client_id=source_id,
                client_name=source_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"Transfer to {destination_name} ({destination_type})",
                date=p_dt
            )
            uow.individual_savings.create(source_entity)

        # 2. Credit Destination
        try:
            if destination_type == "GroupSavings":
                dest_entity = GroupSavings(
                    group_name=destination_name,
                    branch=branch,
                    officer=officer,
                    deposit_amount=amount,
                    withdrawal_amount=0.0,
                    reference=reference,
                    remarks=remarks or f"Transfer from {source_name} ({source_type})",
                    date=p_dt
                )
                uow.group_savings.create(dest_entity)
            elif destination_type == "MiscSavings":
                dest_entity = MiscSavings(
                    client_id=destination_id,
                    client_name=destination_name,
                    branch=branch,
                    officer=officer,
                    deposit_amount=amount,
                    withdrawal_amount=0.0,
                    reference=reference,
                    remarks=remarks or f"Transfer from {source_name} ({source_type})",
                    date=p_dt
                )
                uow.misc_savings.create(dest_entity)
            else:
                dest_entity = IndividualSavings(
                    client_id=destination_id,
                    client_name=destination_name,
                    branch=branch,
                    officer=officer,
                    deposit_amount=amount,
                    withdrawal_amount=0.0,
                    reference=reference,
                    remarks=remarks or f"Transfer from {source_name} ({source_type})",
                    date=p_dt
                )
                uow.individual_savings.create(dest_entity)

            uow.audit.log_action(
                officer,
                "Credit Officer",
                "Savings Transfer",
                "savings",
                source_entity.id,
                None,
                {"amount": amount, "source_id": source_id, "dest_id": destination_id, "source_type": source_type, "dest_type": destination_type}
            )

            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=source_entity.id,
                aggregate_type="SavingsTransfer",
                event_type="SavingsTransferred",
                payload={
                    "source_id": source_id,
                    "source_name": source_name,
                    "source_type": source_type,
                    "destination_id": destination_id,
                    "destination_name": destination_name,
                    "destination_type": destination_type,
                    "branch": branch,
                    "officer": officer,
                    "amount": amount,
                    "reference": reference or source_entity.id,
                    "classification": "SavingsTransfer",
                    "narration": remarks or f"Savings transfer of {amount:,.2f} from {source_name} to {destination_name}",
                    "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt)
                }
            )
            uow.event_store.append(event)
            FinancialPostingEngine.post_event(uow, event)

            return {
                "status": "SUCCESS",
                "event_id": event.event_id,
                "amount": amount,
                "source_savings_id": source_entity.id,
                "destination_savings_id": dest_entity.id,
                "affects_cash_vault": False
            }
        except Exception as e:
            if source_entity and source_entity.id:
                tbl = "group_savings" if source_type == "GroupSavings" else ("misc_savings" if source_type == "MiscSavings" else "individual_savings")
                try:
                    uow.client.table(tbl).delete().eq("id", source_entity.id).execute()
                except Exception:
                    pass
            if dest_entity and dest_entity.id:
                tbl = "group_savings" if destination_type == "GroupSavings" else ("misc_savings" if destination_type == "MiscSavings" else "individual_savings")
                try:
                    uow.client.table(tbl).delete().eq("id", dest_entity.id).execute()
                except Exception:
                    pass
            raise e

        except Exception as e:
            if source_entity and source_entity.id:
                tbl = "group_savings" if source_savings_type == "GroupSavings" else ("misc_savings" if source_savings_type == "MiscSavings" else "individual_savings")
                try:
                    uow.client.table(tbl).delete().eq("id", source_entity.id).execute()
                except Exception:
                    pass
            if repayment_entity and repayment_entity.id:
                try:
                    uow.client.table("repayments").delete().eq("id", repayment_entity.id).execute()
                except Exception:
                    pass
            raise e

    @staticmethod
    def transfer_to_laps(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        source_savings_type: str,
        branch: str,
        officer: str,
        amount: float,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None
    ) -> dict:
        """
        Executes atomic internal savings transfer into LAPS:
        - Decreases source savings (IndividualSavings, GroupSavings, MiscSavings)
        - Increases LAPS balance in laps_savings
        - Emits ONE LapsTransferred domain event (ZERO physical cash movement)
        - Logs audit record
        """
        if amount <= 0:
            raise ValueError("Transfer amount must be greater than zero.")

        p_dt = posting_date if posting_date else datetime.now()

        cls_info = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_TRANSFER, amount
        )

        source_entity = None
        laps_entity = None

        if source_savings_type == "GroupSavings":
            source_entity = GroupSavings(
                group_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"LAPS transfer withdrawal from GroupSavings",
                date=p_dt
            )
            uow.group_savings.create(source_entity)
        elif source_savings_type == "MiscSavings":
            source_entity = MiscSavings(
                client_id=client_id,
                client_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"LAPS transfer withdrawal from MiscSavings",
                date=p_dt
            )
            uow.misc_savings.create(source_entity)
        else: # IndividualSavings
            source_entity = IndividualSavings(
                client_id=client_id,
                client_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=0.0,
                withdrawal_amount=amount,
                reference=reference,
                remarks=remarks or f"LAPS transfer withdrawal from IndividualSavings",
                date=p_dt
            )
            uow.individual_savings.create(source_entity)

        try:
            laps_entity = LapsSavings(
                client_id=client_id,
                client_name=client_name,
                branch=branch,
                officer=officer,
                deposit_amount=amount,
                withdrawal_amount=0.0,
                reference=reference,
                remarks=remarks or f"LAPS transfer deposit from {source_savings_type}",
                date=p_dt
            )
            uow.laps_savings.create(laps_entity)

            uow.audit.log_action(
                officer,
                "Credit Officer",
                "LAPS Transfer",
                "laps_savings",
                laps_entity.id,
                None,
                {"amount": amount, "source": source_savings_type, "source_id": source_entity.id}
            )

            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=laps_entity.id,
                aggregate_type="LapsSavings",
                event_type="LapsTransferred",
                payload={
                    "client_id": client_id,
                    "source_savings_type": source_savings_type,
                    "destination": "LAPS",
                    "branch": branch,
                    "officer": officer,
                    "amount": amount,
                    "reference": reference or laps_entity.id,
                    "classification": TransactionClassification.LAPS_TRANSFER.value,
                    "narration": remarks or f"LAPS transfer of {amount:,.2f} from {source_savings_type} for client {client_name}",
                    "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt)
                }
            )
            uow.event_store.append(event)
            try:
                FinancialPostingEngine.post_event(uow, event)
            except ValueError as ve:
                if "No active posting rule found" in str(ve):
                    pass
                else:
                    raise ve

            return {
                "status": "SUCCESS",
                "event_id": event.event_id,
                "amount": amount,
                "source_savings_id": source_entity.id,
                "laps_savings_id": laps_entity.id,
                "affects_cash_vault": cls_info["affects_cash_vault"]
            }

        except Exception as e:
            if source_entity and source_entity.id:
                tbl = "group_savings" if source_savings_type == "GroupSavings" else ("misc_savings" if source_savings_type == "MiscSavings" else "individual_savings")
                try:
                    uow.client.table(tbl).delete().eq("id", source_entity.id).execute()
                except Exception:
                    pass
            if laps_entity and laps_entity.id:
                try:
                    uow.client.table("laps_savings").delete().eq("id", laps_entity.id).execute()
                except Exception:
                    pass
            raise e

    @staticmethod
    def pay_laps(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        branch: str,
        officer: str,
        amount: float,
        cash_paid: bool = True,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None
    ) -> dict:
        """
        Executes LAPS payout to client:
        - Decreases LAPS balance in laps_savings (withdrawal_amount = amount)
        - Emits LapsPaidOut domain event
        - Physical cash movement occurs ONLY if cash_paid = True
        - Logs audit record with cash_paid flag
        """
        if amount <= 0:
            raise ValueError("Payout amount must be greater than zero.")

        p_dt = posting_date if posting_date else datetime.now()

        cls_info = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_PAYOUT, amount, is_cash_paid=cash_paid
        )

        laps_entity = LapsSavings(
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=officer,
            deposit_amount=0.0,
            withdrawal_amount=amount,
            reference=reference,
            remarks=remarks or f"LAPS payout ({'Cash' if cash_paid else 'Non-Cash'}) for client {client_name}",
            date=p_dt
        )
        uow.laps_savings.create(laps_entity)

        try:
            uow.audit.log_action(
                officer,
                "Credit Officer",
                "LAPS Payout",
                "laps_savings",
                laps_entity.id,
                None,
                {"amount": amount, "cash_paid": cash_paid}
            )

            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=laps_entity.id,
                aggregate_type="LapsSavings",
                event_type="LapsPaidOut",
                payload={
                    "client_id": client_id,
                    "amount": amount,
                    "branch": branch,
                    "officer": officer,
                    "cash_paid": cash_paid,
                    "reference": reference or laps_entity.id,
                    "classification": TransactionClassification.LAPS_PAYOUT.value,
                    "narration": remarks or f"LAPS payout of {amount:,.2f} ({'Cash' if cash_paid else 'Non-Cash'}) for client {client_name}",
                    "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt)
                }
            )
            uow.event_store.append(event)
            try:
                FinancialPostingEngine.post_event(uow, event)
            except ValueError as ve:
                if "No active posting rule found" in str(ve):
                    pass
                else:
                    raise ve

            return {
                "status": "SUCCESS",
                "event_id": event.event_id,
                "amount": amount,
                "laps_savings_id": laps_entity.id,
                "cash_paid": cash_paid,
                "affects_cash_vault": cls_info["affects_cash_vault"]
            }

        except Exception as e:
            if laps_entity and laps_entity.id:
                try:
                    uow.client.table("laps_savings").delete().eq("id", laps_entity.id).execute()
                except Exception:
                    pass
            raise e

    @staticmethod
    def reverse_savings(uow: SupabaseUnitOfWork, original_savings_id: str, reason: str, reversed_by: str, reversal_date: Optional[Any] = None):
        """
        Executes a compensating negative savings record to reverse an error (BR-ERR-002).
        Handles both individual_savings and group_savings atomically with Ledger reversal.
        """
        # 1. Look in individual_savings
        table_name = "individual_savings"
        res = uow.client.table("individual_savings").select("*").eq("id", original_savings_id).execute()
        if not res.data:
            # 2. Look in group_savings
            table_name = "group_savings"
            res = uow.client.table("group_savings").select("*").eq("id", original_savings_id).execute()
            if not res.data:
                raise ValueError(f"Savings record {original_savings_id} not found in individual or group savings.")

        orig = res.data[0]
        operations = []

        # 1. Operational data: Compensating negative record
        new_id = str(uuid.uuid4())
        comp_record = orig.copy()
        comp_record["id"] = new_id

        dep_amt = float(comp_record.get("deposit_amount") or 0.0)
        wd_amt = float(comp_record.get("withdrawal_amount") or 0.0)

        if dep_amt > 0:
            comp_record["deposit_amount"] = -abs(dep_amt)
            comp_record["withdrawal_amount"] = 0.0
            reversal_amount = abs(dep_amt)
            event_type = "SavingsReversed"
        else:
            comp_record["withdrawal_amount"] = -abs(wd_amt)
            comp_record["deposit_amount"] = 0.0
            reversal_amount = abs(wd_amt)
            event_type = "SavingsDeposited"

        comp_record["remarks"] = f"REVERSAL of {original_savings_id}. Reason: {reason} (by {reversed_by})"
        comp_record["created_at"] = datetime.now().isoformat()

        rev_dt = reversal_date if reversal_date else datetime.now()
        rev_dt_str = rev_dt.isoformat() if hasattr(rev_dt, 'isoformat') else str(rev_dt)
        if "posting_date" in comp_record:
            comp_record["posting_date"] = rev_dt_str[:10]
        if "date" in comp_record:
            comp_record["date"] = rev_dt_str

        operations.append({
            "type": "insert",
            "table": table_name,
            "record": comp_record
        })

        # 2. Reversal Domain Event
        event_payload = {
            "branch": orig.get("branch_id") or orig.get("branch"),
            "officer": orig.get("officer_id") or orig.get("officer"),
            "amount": reversal_amount,
            "reference": new_id,
            "narration": f"Reversal of savings {original_savings_id}. Reason: {reason}",
            "date": rev_dt_str
        }

        agg_type = "IndividualSavings" if table_name == "individual_savings" else "GroupSavings"
        ev = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=new_id,
            aggregate_type=agg_type,
            event_type=event_type,
            payload=event_payload
        )

        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": ev.event_id,
                "aggregate_id": ev.aggregate_id,
                "aggregate_type": ev.aggregate_type,
                "event_type": ev.event_type,
                "version": ev.version,
                "payload": ev.payload,
                "status": "Posted"
            }
        })

        tx_id, post_op = FinancialPostingEngine.post_event(uow, ev, defer_commit=True)
        operations.append(post_op)

        # 3. Execute all accumulated operations atomically
        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        # 4. Rebuild projection
        try:
            from datetime import date
            branch_val = orig.get("branch_id") or orig.get("branch")
            # Rebuild reversal date
            rebuild_date = rev_dt.date() if hasattr(rev_dt, 'date') and callable(rev_dt.date) else (date.fromisoformat(str(rev_dt)[:10]) if rev_dt else date.today())
            uow.cashbook.rebuild_projection(uow, branch_val, rebuild_date)

            # Also rebuild original date if different
            orig_raw_date = orig.get("posting_date") or orig.get("date")
            if orig_raw_date:
                orig_date = date.fromisoformat(str(orig_raw_date)[:10])
                if orig_date != rebuild_date:
                    uow.cashbook.rebuild_projection(uow, branch_val, orig_date)
        except Exception:
            pass

