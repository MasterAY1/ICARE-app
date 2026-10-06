"""
Database Query Utilities.
Provides authoritative pagination and batch query execution to prevent
silent PostgREST 1,000-row query truncation across services.
"""
from typing import Any, List


import time


def fetch_all_paginated(query_builder: Any, step: int = 1000, max_retries: int = 3) -> List[dict]:
    """
    Authoritative paginated fetch utility for Supabase / PostgREST queries.
    Prevents silent 1,000-row result truncation by fetching in chunks of `step`
    using `.range(start, end)` until all records are retrieved.
    Includes automatic retry for transient network/Cloudflare hiccups.
    """
    all_data: List[dict] = []
    page = 0
    while True:
        data = None
        for attempt in range(max_retries):
            try:
                res = query_builder.range(page * step, (page + 1) * step - 1).execute()
                data = res.data or []
                break
            except Exception as e:
                err_str = str(e).lower()
                if attempt < max_retries - 1 and any(k in err_str for k in ("worker", "cloudflare", "timeout", "disconnected", "remoteprotocolerror", "500", "502", "503")):
                    time.sleep(1.0 * (attempt + 1))
                    continue
                raise
        if data is None:
            data = []
        all_data.extend(data)
        if len(data) < step:
            break
        page += 1
    return all_data
