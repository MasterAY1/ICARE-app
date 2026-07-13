from typing import Optional
from domain.entities.posting_rule import PostingRule
from interfaces.posting_rules_repository import PostingRulesRepository
from database.repositories.base_repository import BaseRepository

class SupabasePostingRulesRepository(BaseRepository[PostingRule], PostingRulesRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "posting_rules"
        # Optional local cache to prevent database lookups for high-frequency operations
        self._cache = {}

    def get_rule(self, event_type: str, version: int = 1) -> Optional[PostingRule]:
        cache_key = f"{event_type}_{version}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        res = self.client.table(self.table_name).select("*").eq("event_type", event_type).eq("version", version).eq("enabled", True).execute()
        if res.data:
            r = res.data[0]
            rule = PostingRule(
                id=str(r.get("id")),
                event_type=str(r.get("event_type")),
                debit_account=str(r.get("debit_account")),
                credit_account=str(r.get("credit_account")),
                version=int(r.get("version") or 1),
                enabled=bool(r.get("enabled", True))
            )
            self._cache[cache_key] = rule
            return rule
        return None

    def save_rule(self, rule: PostingRule) -> None:
        data = {
            "event_type": rule.event_type,
            "debit_account": rule.debit_account,
            "credit_account": rule.credit_account,
            "version": rule.version,
            "enabled": rule.enabled
        }
        if rule.id:
            data["id"] = rule.id
        self.client.table(self.table_name).upsert(data).execute()
        # Invalidate cache
        cache_key = f"{rule.event_type}_{rule.version}"
        self._cache.pop(cache_key, None)
