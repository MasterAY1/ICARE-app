import os
try:
    import streamlit as st
except ImportError:
    st = None

from supabase import create_client, Client
from config.settings import SUPABASE_URL, SUPABASE_KEY

import httpx
import time
from supabase.lib.client_options import SyncClientOptions

class RetryingHTTPTransport(httpx.HTTPTransport):
    def handle_request(self, request: httpx.Request) -> httpx.Response:
        max_retries = 3
        for attempt in range(max_retries):
            try:
                return super().handle_request(request)
            except (httpx.ConnectError, httpx.TimeoutException, httpx.RemoteProtocolError):
                if attempt == max_retries - 1:
                    raise
                time.sleep(0.5 * (attempt + 1))

def get_supabase_client() -> Client:
    url = (st.secrets.get("SUPABASE_URL") if st and hasattr(st, "secrets") else None) or SUPABASE_URL or os.environ.get("SUPABASE_URL")
    key = (st.secrets.get("SUPABASE_KEY") if st and hasattr(st, "secrets") else None) or SUPABASE_KEY or os.environ.get("SUPABASE_KEY")
    if not url or not key:
        if st:
            st.error("Database configuration is missing. Set SUPABASE_URL and SUPABASE_KEY.")
            st.stop()
        else:
            raise ValueError("Database configuration is missing. Set SUPABASE_URL and SUPABASE_KEY.")
    transport = RetryingHTTPTransport(retries=3)
    http_client = httpx.Client(http2=False, timeout=60.0, transport=transport)
    opts = SyncClientOptions(httpx_client=http_client)
    return create_client(url, key, options=opts)

if st and hasattr(st, "cache_resource"):
    get_supabase_client = st.cache_resource(get_supabase_client)

supabase = get_supabase_client()
