import streamlit as st
from services.auth_service import AuthService
from auth.login import render_login_page

def route_app():
    # Attempt to restore session from URL if missing
    AuthService.restore_session_from_url()
    
    if not AuthService.is_logged_in():
        render_login_page()
        st.stop()
    else:
        # User is authenticated. We just return, allowing app.py to continue rendering the dashboard.
        pass
