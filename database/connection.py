import os
try:
    import streamlit as st
except ImportError:
    st = None

from supabase import create_client, Client
from config.settings import SUPABASE_URL, SUPABASE_KEY

def get_supabase_client() -> Client:
    url = (st.secrets.get("SUPABASE_URL") if st and hasattr(st, "secrets") else None) or SUPABASE_URL or os.environ.get("SUPABASE_URL")
    key = (st.secrets.get("SUPABASE_KEY") if st and hasattr(st, "secrets") else None) or SUPABASE_KEY or os.environ.get("SUPABASE_KEY")
    if not url or not key:
        if st:
            st.error("Database configuration is missing. Set SUPABASE_URL and SUPABASE_KEY.")
            st.stop()
        else:
            raise ValueError("Database configuration is missing. Set SUPABASE_URL and SUPABASE_KEY.")
    return create_client(url, key)

if st and hasattr(st, "cache_resource"):
    get_supabase_client = st.cache_resource(get_supabase_client)

supabase = get_supabase_client()
