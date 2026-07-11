import streamlit as st
from typing import Any, Callable, Optional

class CacheProvider:
    """Abstracts caching logic to keep it framework-agnostic."""
    
    @staticmethod
    def cache_data(ttl: int = 3600):
        """Decorator to cache function results."""
        def decorator(func: Callable) -> Callable:
            # We wrap Streamlit's cache_data for now.
            # In the future, this can be swapped for Redis/Memcached.
            return st.cache_data(ttl=ttl)(func)
        return decorator

    @staticmethod
    def clear():
        """Clears the entire cache."""
        st.cache_data.clear()
