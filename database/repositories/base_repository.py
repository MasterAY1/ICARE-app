from typing import TypeVar, Generic, List, Optional
from core.exceptions import RepositoryError, NotFoundError

T = TypeVar('T')

class BaseRepository(Generic[T]):
    def __init__(self, client):
        self.client = client
        self.table_name = ""

    def _execute(self, query):
        for attempt in range(2):
            try:
                res = query.execute()
                # Postgrest exceptions might also raise inherently in execute()
                return res
            except Exception as e:
                err_msg = str(e).lower()
                if attempt == 0 and any(k in err_msg for k in ("disconnected", "connection", "protocol", "remoteprotocolerror")):
                    continue
                raise RepositoryError(f"Database operation failed: {str(e)}")

    def _single_or_none(self, data: List[dict]) -> Optional[dict]:
        if not data:
            return None
        return data[0]
