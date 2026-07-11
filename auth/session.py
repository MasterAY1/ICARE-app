import streamlit as st
from datetime import datetime, timedelta
import uuid
from models.user import CurrentUser

SESSION_TIMEOUT_MINUTES = 30

def create_session(user: CurrentUser):
    st.session_state['user'] = user.username
    st.session_state['role'] = user.role
    st.session_state['branch'] = user.branch
    st.session_state['current_user'] = user
    st.session_state['session_id'] = str(uuid.uuid4())
    st.session_state['last_activity'] = datetime.now()
    st.session_state['logged_in'] = True

def destroy_session():
    keys_to_remove = ['user', 'role', 'branch', 'current_user', 'session_id', 'last_activity', 'logged_in']
    for key in keys_to_remove:
        if key in st.session_state:
            del st.session_state[key]
    # Optionally st.session_state.clear() but that might destroy theme info

def refresh_session():
    if is_authenticated():
        st.session_state['last_activity'] = datetime.now()

def get_current_user() -> CurrentUser:
    return st.session_state.get('current_user')

def is_authenticated() -> bool:
    if not st.session_state.get('logged_in'):
        return False
        
    last_activity = st.session_state.get('last_activity')
    if last_activity:
        if datetime.now() - last_activity > timedelta(minutes=SESSION_TIMEOUT_MINUTES):
            destroy_session()
            return False
            
    return True
