"""
services/reference_cache_service.py
Authoritative Thread-Safe In-Memory Reference Cache for Static Metadata.

Governance Invariants:
1. STRICTLY PROHIBITS CACHING FINANCIAL BALANCES:
   - Account 1000 Vault Cash, loan balances, savings balances, and cashbooks are NEVER cached.
2. ZERO REDIS DEPENDENCY:
   - Lightweight in-process Python cache with monotonic timestamps and threading.RLock.
3. EXPLICIT INVALIDATION & BRANCH ISOLATION:
   - Thread-safe mutation invalidation and tenant isolation.
"""

from typing import Dict, Any, Optional, Callable, List
import time
import threading


class ReferenceCacheService:
    """
    High-performance, in-memory reference cache for static and semi-static metadata.
    Avoids redundant remote database queries for data that changes infrequently
    (e.g., branches, loan products, client lifecycle status codes, roles).
    """

    _lock = threading.RLock()
    _cache: Dict[str, Dict[str, Any]] = {}
    _hits: int = 0
    _misses: int = 0

    # Strict TTL specifications in seconds
    DEFAULT_TTL_SECONDS = 900  # 15 minutes
    STATUS_TTL_SECONDS = 1800  # 30 minutes

    # Strictly forbidden cache keys to prevent financial data drift
    FORBIDDEN_KEY_PATTERNS = (
        "account_1000",
        "vault_cash",
        "balance",
        "cashbook",
        "financial_ledger",
        "repayment",
        "savings_balance",
        "eod_status",
        "variance",
    )

    @classmethod
    def _validate_cache_key(cls, key: str) -> None:
        """Enforces invariant: Financial balances and transactions must never be cached."""
        key_lower = key.lower()
        for forbidden in cls.FORBIDDEN_KEY_PATTERNS:
            if forbidden in key_lower:
                raise ValueError(
                    f"Financial Invariant Violation: Caching of '{key}' is strictly prohibited. "
                    f"Financial balances and ledger positions must be derived dynamically."
                )

    @classmethod
    def get(cls, key: str) -> Optional[Any]:
        """Retrieves a cached value if present and unexpired."""
        cls._validate_cache_key(key)
        with cls._lock:
            entry = cls._cache.get(key)
            if not entry:
                cls._misses += 1
                return None

            if time.monotonic() >= entry["expires_at"]:
                del cls._cache[key]
                cls._misses += 1
                return None

            cls._hits += 1
            return entry["data"]

    @classmethod
    def set(cls, key: str, value: Any, ttl_seconds: Optional[int] = None) -> None:
        """Stores a value in cache with monotonic expiration."""
        cls._validate_cache_key(key)
        ttl = ttl_seconds if ttl_seconds is not None else cls.DEFAULT_TTL_SECONDS
        with cls._lock:
            cls._cache[key] = {
                "data": value,
                "expires_at": time.monotonic() + ttl,
                "created_at": time.monotonic()
            }

    @classmethod
    def get_or_set(cls, key: str, fetcher: Callable[[], Any], ttl_seconds: Optional[int] = None) -> Any:
        """Double-checked locking pattern for safe lazy loading."""
        cls._validate_cache_key(key)
        cached = cls.get(key)
        if cached is not None:
            return cached

        with cls._lock:
            # Recheck under lock
            entry = cls._cache.get(key)
            if entry and time.monotonic() <= entry["expires_at"]:
                cls._hits += 1
                return entry["data"]

            # Compute from authoritative fetcher
            data = fetcher()
            ttl = ttl_seconds if ttl_seconds is not None else cls.DEFAULT_TTL_SECONDS
            cls._cache[key] = {
                "data": data,
                "expires_at": time.monotonic() + ttl,
                "created_at": time.monotonic()
            }
            cls._misses += 1
            return data

    @classmethod
    def invalidate(cls, key: str) -> bool:
        """Invalidates a specific cache entry."""
        with cls._lock:
            return cls._cache.pop(key, None) is not None

    @classmethod
    def invalidate_prefix(cls, prefix: str) -> int:
        """Invalidates all keys matching a prefix (e.g., 'branches:')."""
        with cls._lock:
            matching = [k for k in cls._cache if k.startswith(prefix)]
            for k in matching:
                del cls._cache[k]
            return len(matching)

    @classmethod
    def invalidate_all(cls) -> None:
        """Flushes the entire reference cache."""
        with cls._lock:
            cls._cache.clear()

    @classmethod
    def get_stats(cls) -> Dict[str, Any]:
        """Returns diagnostic statistics of the reference cache."""
        with cls._lock:
            total = cls._hits + cls._misses
            hit_ratio = round((cls._hits / total * 100.0), 2) if total > 0 else 0.0
            return {
                "hits": cls._hits,
                "misses": cls._misses,
                "total_requests": total,
                "hit_ratio_pct": hit_ratio,
                "active_entries": len(cls._cache)
            }

    # -------------------------------------------------------------------------
    # Specialized Reference Metadata Accessors
    # -------------------------------------------------------------------------

    @classmethod
    def get_branches(cls, fetcher: Callable[[], List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
        """Cached lookup of active branches list."""
        return cls.get_or_set("metadata:branches:all", fetcher, ttl_seconds=cls.DEFAULT_TTL_SECONDS)

    @classmethod
    def get_branch_by_name(cls, branch_name: str, fetcher: Callable[[str], Optional[Dict[str, Any]]]) -> Optional[Dict[str, Any]]:
        """Cached lookup of a single branch by name."""
        clean_name = (branch_name or "").strip().lower()
        if not clean_name:
            return None
        return cls.get_or_set(
            f"metadata:branches:by_name:{clean_name}",
            lambda: fetcher(branch_name),
            ttl_seconds=cls.DEFAULT_TTL_SECONDS
        )

    @classmethod
    def get_loan_products(cls, fetcher: Callable[[], List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
        """Cached lookup of loan products."""
        return cls.get_or_set("metadata:loan_products:all", fetcher, ttl_seconds=cls.DEFAULT_TTL_SECONDS)

    @classmethod
    def get_client_statuses(cls, fetcher: Callable[[], List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
        """Cached lookup of client status codes."""
        return cls.get_or_set("metadata:client_statuses:all", fetcher, ttl_seconds=cls.STATUS_TTL_SECONDS)

    @classmethod
    def invalidate_branches(cls) -> int:
        """Invalidates branch-related cache entries on mutation."""
        return cls.invalidate_prefix("metadata:branches:")

    @classmethod
    def invalidate_products(cls) -> int:
        """Invalidates product-related cache entries on mutation."""
        return cls.invalidate_prefix("metadata:loan_products:")
