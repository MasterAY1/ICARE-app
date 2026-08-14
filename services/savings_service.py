import uuid
from datetime import datetime
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.savings import IndividualSavings, GroupSavings, MiscSavings, LapsSavings
from domain.entities.repayment import Repayment
from domain.entities.event_store import DomainEvent
from domain.enums import TransactionClassification
from services.withdrawal_classification_engine import WithdrawalClassificationEngine
from services.posting_engine import FinancialPostingEngine

class SavingsService:
    @staticmethod
    def post_individual_savings(uow: SupabaseUnitOfWork, client_id: str, client_name: str, branch: str, officer: str, deposit_amount: float, withdrawal_amount: float = 0.0, reference: str = None, remarks: str = None):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return
            
        entity = IndividualSavings(
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=remarks,
            date=datetime.now()
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
    def post_group_savings(uow: SupabaseUnitOfWork, group_name: str, branch: str, officer: str, deposit_amount: float, withdrawal_amount: float = 0.0, reference: str = None, remarks: str = None):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return
            
        entity = GroupSavings(
            group_name=group_name,
            branch=branch,
            officer=officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=remarks,
            date=datetime.now()
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
                    "narration": remarks or f"Group savings transaction for group {group_name}"
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
    def post_misc_savings(uow: SupabaseUnitOfWork, client_id: str, client_name: str, branch: str, officer: str, deposit_amount: float, withdrawal_amount: float = 0.0, reference: str = None, remarks: str = None):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return
            
        managing_id, managing_name = SavingsService.get_branch_misc_savings_officer(uow, branch)
        collecting_officer = officer or "Unknown Officer"
        
        narr = remarks or (f"Misc savings collected by {collecting_officer} (Managed by {managing_name})" if deposit_amount > 0 else f"Misc savings withdrawal for {client_name}")
        
        entity = MiscSavings(
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=managing_name,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=narr,
            date=datetime.now()
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
                "narration": narr
            }
        )
        uow.event_store.append(event)
        FinancialPostingEngine.post_event(uow, event)

    @staticmethod
    def post_laps_savings(uow: SupabaseUnitOfWork, client_id: str, client_name: str, branch: str, officer: str, deposit_amount: float, withdrawal_amount: float = 0.0, reference: str = None, remarks: str = None):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return
            
        entity = LapsSavings(
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=remarks,
            date=datetime.now()
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
                "narration": remarks or f"LAPS savings transaction for client {client_name}"
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
        remarks: str = None
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
                date=datetime.now()
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
                date=datetime.now()
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
                date=datetime.now()
            )
            uow.individual_savings.create(source_entity)

        try:
            repayment_entity = Repayment(
                id=str(uuid.uuid4()),
                loan_id=loan_id,
                client_id=client_id,
                amount_paid=amount,
                savings_amount=0.0,
                loan_repayment_amount=amount,
                withdrawal_amount=0.0,
                others_amount=0.0,
                recovery_amount=0.0,
                initial_payment=0.0,
                payment_date=datetime.now().date(),
                transaction_type="LOAN_OFFSET",
                branch=branch,
                credit_officer=officer,
                payment_status="PAID",
                note=remarks or f"Loan offset of {amount} from {source_savings_type}"
            )
            uow.repayments.create(repayment_entity)

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
                    "client_id": client_id,
                    "loan_id": loan_id,
                    "source_savings_type": source_savings_type,
                    "branch": branch,
                    "officer": officer,
                    "amount": amount,
                    "reference": reference or source_entity.id,
                    "classification": TransactionClassification.LOAN_OFFSET.value,
                    "narration": remarks or f"Loan offset of {amount:,.2f} from {source_savings_type} for loan {loan_id}"
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
        remarks: str = None
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
                date=datetime.now()
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
                date=datetime.now()
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
                date=datetime.now()
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
                date=datetime.now()
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
                    "narration": remarks or f"LAPS transfer of {amount:,.2f} from {source_savings_type} for client {client_name}"
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
        remarks: str = None
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
            date=datetime.now()
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
                    "narration": remarks or f"LAPS payout of {amount:,.2f} ({'Cash' if cash_paid else 'Non-Cash'}) for client {client_name}"
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

