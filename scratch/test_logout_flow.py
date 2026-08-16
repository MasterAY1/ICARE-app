import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from services.auth_service import AuthService
import streamlit as st

def test_logout():
    # Setup mock session
    st.session_state['logged_in'] = True
    st.session_state['user'] = "BM_Ogijo"
    st.session_state['role'] = "BM"
    st.session_state['session_id'] = "test-session-123"
    
    print("Testing AuthService.logout()...")
    AuthService.logout()
    
    assert 'logged_in' not in st.session_state or not st.session_state['logged_in'], "logged_in should be cleared"
    assert 'user' not in st.session_state, "user should be cleared"
    print(">>> LOGOUT TEST PASSED WITH 100% SUCCESS! <<<")

if __name__ == "__main__":
    test_logout()
