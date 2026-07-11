import os
import streamlit as st
from supabase import create_client, Client
from config.settings import SUPABASE_URL, SUPABASE_KEY

@st.cache_resource
def get_supabase_client() -> Client:
    url = st.secrets.get("SUPABASE_URL") or SUPABASE_URL or os.environ.get("SUPABASE_URL")
    key = st.secrets.get("SUPABASE_KEY") or SUPABASE_KEY or os.environ.get("SUPABASE_KEY")
    if not url or not key:
        st.error("Database configuration is missing. Set SUPABASE_URL and SUPABASE_KEY.")
        st.stop()
    return create_client(url, key)

supabase = get_supabase_client()
