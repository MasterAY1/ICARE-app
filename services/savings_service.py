import uuid
from datetime import datetime
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.savings import IndividualSavings, GroupSavings, MiscSavings, LapsSavings
from domain.entities.event_store import DomainEvent
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

    @staticmethod
    def post_misc_savings(uow: SupabaseUnitOfWork, client_id: str, client_name: str, branch: str, officer: str, deposit_amount: float, reference: str = None, remarks: str = None):
        if deposit_amount == 0:
            return
            
        entity = MiscSavings(
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=officer,
            deposit_amount=deposit_amount,
            reference=reference,
            remarks=remarks,
            date=datetime.now()
        )
        # 1. Persist operational data
        uow.misc_savings.create(entity)
        
        # 2. Audit
        uow.audit.log_action(officer, "Credit Officer", "Misc Savings Collected", "misc_savings", entity.id, None, {"deposit": deposit_amount})

        # 3. Create Event & Post
        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=entity.id,
            aggregate_type="MiscSavings",
            event_type="SavingsDeposited",
            payload={
                "branch": branch,
                "officer": officer,
                "amount": deposit_amount,
                "reference": reference or entity.id,
                "narration": remarks or f"Internal savings deposit for client {client_name}"
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
