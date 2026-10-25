import streamlit as st
from datetime import datetime, timedelta
import uuid
import hmac
import hashlib
import base64
import os
from models.user import CurrentUser

SESSION_TIMEOUT_MINUTES = 7 * 24 * 60  # 7-day sliding session window


def get_auth_secret() -> str:
    """
    Retrieves the authoritative HMAC secret key from the environment.
    Fails closed with RuntimeError if missing, empty, or whitespace-only.
    Never exposes or logs the secret.
    """
    secret = os.environ.get("ICARE_AUTH_SECRET", "")
    if not secret or not secret.strip():
        raise RuntimeError(
            "CRITICAL SECURITY CONFIGURATION ERROR: 'ICARE_AUTH_SECRET' environment variable "
            "is missing, empty, or whitespace-only. Application cannot safely start or issue session tokens."
        )
    return secret.strip()


def __getattr__(name: str):
    """Dynamically resolves SECRET_KEY to prevent hardcoded fallbacks and ensure fail-closed execution."""
    if name == "SECRET_KEY":
        return get_auth_secret()
    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


def generate_session_token(user_id: str, username: str) -> str:
    """Generates a tamper-proof HMAC-SHA256 signed session token."""
    secret = get_auth_secret()
    timestamp = int(datetime.now().timestamp())
    payload_str = f"{user_id}:{username}:{timestamp}"
    signature = hmac.new(secret.encode('utf-8'), payload_str.encode('utf-8'), hashlib.sha256).hexdigest()
    raw_token = f"{payload_str}:{signature}"
    return base64.urlsafe_b64encode(raw_token.encode('utf-8')).decode('utf-8')


def validate_session_token(token_str: str):
    """Validates an HMAC-signed session token. Returns dict with user_id, username if valid, else None."""
    if not token_str:
        return None
    secret = get_auth_secret()
    try:
        raw_token = base64.urlsafe_b64decode(token_str.encode('utf-8')).decode('utf-8')
        parts = raw_token.split(":")
        if len(parts) != 4:
            return None
        user_id, username, ts_str, sig = parts
        payload_str = f"{user_id}:{username}:{ts_str}"
        expected_sig = hmac.new(secret.encode('utf-8'), payload_str.encode('utf-8'), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(sig, expected_sig):
            return None
        
        # Check token age
        ts = int(ts_str)
        token_age = datetime.now().timestamp() - ts
        if token_age > (SESSION_TIMEOUT_MINUTES * 60) or token_age < -300:
            return None
            
        return {"user_id": user_id, "username": username, "timestamp": ts}
    except Exception:
        return None


def create_session(user: CurrentUser):
    st.session_state['user'] = user.username
    st.session_state['role'] = user.role
    st.session_state['branch'] = user.branch
    st.session_state['current_user'] = user
    st.session_state['session_id'] = str(uuid.uuid4())
    st.session_state['last_activity'] = datetime.now()
    st.session_state['logged_in'] = True

    # Persist token in query params for browser refresh survival
    try:
        token = generate_session_token(user.id, user.username)
        st.session_state['auth_token'] = token
        st.query_params['auth_token'] = token
        st.query_params['auth'] = user.username
    except Exception:
        pass


def destroy_session():
    keys_to_remove = ['user', 'role', 'branch', 'current_user', 'session_id', 'last_activity', 'logged_in', 'auth_token']
    for key in keys_to_remove:
        if key in st.session_state:
            del st.session_state[key]
    try:
        if 'auth_token' in st.query_params:
            del st.query_params['auth_token']
        if 'auth' in st.query_params:
            del st.query_params['auth']
    except Exception:
        pass


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
            
    # Sliding keepalive
    st.session_state['last_activity'] = datetime.now()
    return True
