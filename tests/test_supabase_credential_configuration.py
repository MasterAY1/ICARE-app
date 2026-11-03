"""
Unit and integration test suite for server-side Supabase credential configuration.

Validates:
1. Environment detection (production vs development/testing).
2. JWT role claim extraction without secret verification.
3. Strict fail-closed enforcement in production when SUPABASE_SERVICE_ROLE_KEY is missing.
4. Prevention of accidental anon-key fallback in production.
5. Prevention of misconfigured anon keys assigned to SUPABASE_SERVICE_ROLE_KEY.
6. Safe backward-compatibility fallback in local development/testing.
7. Zero credential leakage in error messages or logs.
8. FastAPI startup verification hook integration.
"""
import json
import base64
import pytest
from database.connection import (
    is_production,
    get_jwt_role,
    resolve_supabase_credentials,
    verify_supabase_credentials,
    reset_supabase_client,
    get_supabase_client,
    supabase
)
from api.main import verify_security_configuration


def make_dummy_jwt(role: str) -> str:
    """Creates a structurally valid test JWT carrying the specified role claim."""
    header = base64.urlsafe_b64encode(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()).decode().rstrip("=")
    payload = base64.urlsafe_b64encode(json.dumps({"role": role, "iss": "supabase", "exp": 2099999999}).encode()).decode().rstrip("=")
    signature = "dummy_signature_bytes_for_testing"
    return f"{header}.{payload}.{signature}"


@pytest.fixture
def clean_env(monkeypatch):
    """Provides a sterile environment with all Supabase and environment variables cleared."""
    for var in [
        "ENVIRONMENT", "APP_ENV", "RENDER", "RENDER_SERVICE_ID",
        "SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_KEY"
    ]:
        monkeypatch.delenv(var, raising=False)
    monkeypatch.setenv("ICARE_AUTH_SECRET", "test-auth-secret-key-32-bytes-minimum-length")
    import database.connection
    import config.settings
    database.connection.reset_supabase_client()
    for attr in ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_KEY"]:
        monkeypatch.setattr(database.connection, attr, "", raising=False)
        monkeypatch.setattr(config.settings, attr, "", raising=False)
    return monkeypatch


# ============================================================================
# 1. ENVIRONMENT DETECTION TESTS
# ============================================================================

def test_is_production_detection_via_environment(clean_env):
    """Verifies that is_production detects production flags from ENVIRONMENT and APP_ENV."""
    clean_env.setenv("ENVIRONMENT", "production")
    assert is_production() is True

    clean_env.setenv("ENVIRONMENT", "prod")
    assert is_production() is True

    clean_env.setenv("ENVIRONMENT", "PRODUCTION")
    assert is_production() is True

    clean_env.delenv("ENVIRONMENT")
    clean_env.setenv("APP_ENV", "production")
    assert is_production() is True

    clean_env.setenv("ENVIRONMENT", "development")
    assert is_production() is False

    clean_env.setenv("ENVIRONMENT", "testing")
    assert is_production() is False


def test_is_production_detection_via_render(clean_env):
    """Verifies that is_production detects deployment on Render regardless of ENVIRONMENT."""
    clean_env.setenv("RENDER", "true")
    assert is_production() is True

    clean_env.delenv("RENDER")
    clean_env.setenv("RENDER_SERVICE_ID", "srv-test-12345")
    assert is_production() is True


# ============================================================================
# 2. JWT ROLE EXTRACTION TESTS
# ============================================================================

def test_get_jwt_role_decoding():
    """Verifies safe inspection of JWT 'role' claim without secret leakage."""
    anon_token = make_dummy_jwt("anon")
    assert get_jwt_role(anon_token) == "anon"

    service_token = make_dummy_jwt("service_role")
    assert get_jwt_role(service_token) == "service_role"

    assert get_jwt_role("invalid-non-jwt-token") is None
    assert get_jwt_role("") is None
    assert get_jwt_role(None) is None


# ============================================================================
# 3. PRODUCTION FAIL-CLOSED & ANTI-FALLBACK TESTS
# ============================================================================

def test_production_fails_closed_when_service_role_key_is_missing(clean_env):
    """
    CRITICAL: In production, missing SUPABASE_SERVICE_ROLE_KEY must raise RuntimeError
    even if SUPABASE_KEY (anon key) is present. Fallback to anon is strictly prohibited.
    """
    clean_env.setenv("ENVIRONMENT", "production")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_KEY", make_dummy_jwt("anon"))
    clean_env.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)

    with pytest.raises(RuntimeError) as exc_info:
        resolve_supabase_credentials()

    err_msg = str(exc_info.value)
    assert "SUPABASE_SERVICE_ROLE_KEY is required in production" in err_msg
    assert "Falling back to the public anon key (SUPABASE_KEY) is strictly prohibited" in err_msg


def test_production_fails_closed_when_service_role_key_is_empty_or_whitespace(clean_env):
    """Verifies that whitespace-only or empty strings for SUPABASE_SERVICE_ROLE_KEY fail closed in production."""
    clean_env.setenv("ENVIRONMENT", "production")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_SERVICE_ROLE_KEY", "   ")
    clean_env.setenv("SUPABASE_KEY", make_dummy_jwt("anon"))

    with pytest.raises(RuntimeError) as exc_info:
        resolve_supabase_credentials()

    assert "SUPABASE_SERVICE_ROLE_KEY is required in production" in str(exc_info.value)


def test_production_fails_closed_when_service_role_key_is_anon(clean_env):
    """
    CRITICAL: In production, if an operator mistakenly pastes the anon key into
    SUPABASE_SERVICE_ROLE_KEY, the system must detect the 'anon' role and fail closed.
    """
    clean_env.setenv("ENVIRONMENT", "production")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_SERVICE_ROLE_KEY", make_dummy_jwt("anon"))

    with pytest.raises(RuntimeError) as exc_info:
        resolve_supabase_credentials()

    err_msg = str(exc_info.value)
    assert "configured with a public 'anon' key instead of a privileged service_role key" in err_msg


def test_production_succeeds_with_valid_service_role_key(clean_env):
    """Verifies that production connects cleanly when SUPABASE_SERVICE_ROLE_KEY is valid."""
    srv_token = make_dummy_jwt("service_role")
    clean_env.setenv("ENVIRONMENT", "production")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_SERVICE_ROLE_KEY", srv_token)
    clean_env.setenv("SUPABASE_KEY", make_dummy_jwt("anon"))

    url, key, source = resolve_supabase_credentials()
    assert url == "https://test.supabase.co"
    assert key == srv_token
    assert source == "SUPABASE_SERVICE_ROLE_KEY"


def test_production_render_environment_fails_without_service_role_key(clean_env):
    """Verifies that on Render (RENDER=true), startup fails closed without SUPABASE_SERVICE_ROLE_KEY."""
    clean_env.setenv("RENDER", "true")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_KEY", make_dummy_jwt("anon"))

    with pytest.raises(RuntimeError) as exc_info:
        verify_supabase_credentials()

    assert "SUPABASE_SERVICE_ROLE_KEY is required in production" in str(exc_info.value)


# ============================================================================
# 4. LOCAL DEVELOPMENT & TESTING BACKWARD COMPATIBILITY TESTS
# ============================================================================

def test_development_falls_back_to_supabase_key(clean_env):
    """
    Verifies backward compatibility in development/testing:
    When SUPABASE_SERVICE_ROLE_KEY is absent, SUPABASE_KEY is safely permitted.
    """
    clean_env.setenv("ENVIRONMENT", "development")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_KEY", "dev-anon-key-12345")
    clean_env.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)

    url, key, source = resolve_supabase_credentials()
    assert url == "https://test.supabase.co"
    assert key == "dev-anon-key-12345"
    assert "SUPABASE_KEY" in source


def test_development_prefers_service_role_key_if_present(clean_env):
    """Verifies that even in development, SUPABASE_SERVICE_ROLE_KEY takes precedence if configured."""
    srv_token = make_dummy_jwt("service_role")
    clean_env.setenv("ENVIRONMENT", "development")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_SERVICE_ROLE_KEY", srv_token)
    clean_env.setenv("SUPABASE_KEY", "dev-anon-key")

    url, key, source = resolve_supabase_credentials()
    assert key == srv_token
    assert source == "SUPABASE_SERVICE_ROLE_KEY"


def test_missing_both_keys_in_development_fails_cleanly(clean_env):
    """Verifies that missing all keys in development raises a descriptive ValueError."""
    clean_env.setenv("ENVIRONMENT", "development")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    clean_env.delenv("SUPABASE_KEY", raising=False)

    with pytest.raises(ValueError) as exc_info:
        resolve_supabase_credentials()

    assert "Database configuration is missing" in str(exc_info.value)


def test_missing_supabase_url_fails_closed(clean_env):
    """Verifies that missing SUPABASE_URL raises RuntimeError in production and ValueError in dev."""
    clean_env.setenv("ENVIRONMENT", "production")
    clean_env.setenv("SUPABASE_SERVICE_ROLE_KEY", make_dummy_jwt("service_role"))
    clean_env.delenv("SUPABASE_URL", raising=False)

    with pytest.raises(RuntimeError) as exc_info:
        resolve_supabase_credentials()
    assert "SUPABASE_URL is missing or empty" in str(exc_info.value)

    clean_env.setenv("ENVIRONMENT", "development")
    with pytest.raises(ValueError) as exc_info_dev:
        resolve_supabase_credentials()
    assert "SUPABASE_URL is not set" in str(exc_info_dev.value)


def test_development_fails_closed_when_env_vars_missing(clean_env):
    """Verifies that local development without any .env or environment variables fails closed immediately."""
    clean_env.setenv("ENVIRONMENT", "development")
    clean_env.delenv("SUPABASE_URL", raising=False)
    clean_env.delenv("SUPABASE_KEY", raising=False)
    clean_env.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)

    with pytest.raises(ValueError) as exc_info:
        resolve_supabase_credentials()
    assert "SUPABASE_URL is not set" in str(exc_info.value)


def test_streamlit_secrets_cannot_supply_credentials(clean_env, monkeypatch):
    """
    CRITICAL SECURITY TEST:
    Verifies that historical .streamlit/secrets.toml or streamlit.secrets cannot
    supply credentials to backend services when environment variables are cleared.
    """
    clean_env.setenv("ENVIRONMENT", "development")
    clean_env.delenv("SUPABASE_URL", raising=False)
    clean_env.delenv("SUPABASE_KEY", raising=False)

    # Even if a mock Streamlit with production secrets was somehow present in sys.modules
    class MockStreamlitSecrets:
        secrets = {
            "SUPABASE_URL": "https://leaked-production-project.supabase.co",
            "SUPABASE_SERVICE_ROLE_KEY": make_dummy_jwt("service_role"),
            "SUPABASE_KEY": "leaked-anon-key"
        }
    monkeypatch.setitem(pytest.importorskip("sys").modules, "streamlit", MockStreamlitSecrets())

    # Must still fail closed because connection.py strictly ignores Streamlit secrets
    with pytest.raises(ValueError) as exc_info:
        resolve_supabase_credentials()
    assert "SUPABASE_URL is not set" in str(exc_info.value)


# ============================================================================
# 5. FASTAPI STARTUP GATE INTEGRATION & ZERO-LEAK VERIFICATION
# ============================================================================

def test_fastapi_startup_hook_verifies_service_role_key_in_production(clean_env):
    """
    Verifies that the FastAPI startup gate (verify_security_configuration)
    fails closed immediately if SUPABASE_SERVICE_ROLE_KEY is unconfigured in production.
    """
    clean_env.setenv("ENVIRONMENT", "production")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_KEY", make_dummy_jwt("anon"))
    clean_env.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)

    with pytest.raises(RuntimeError) as exc_info:
        verify_security_configuration()

    assert "SUPABASE_SERVICE_ROLE_KEY is required in production" in str(exc_info.value)


def test_fastapi_startup_hook_passes_with_valid_production_configuration(clean_env):
    """Verifies that verify_security_configuration succeeds when all production secrets are valid."""
    clean_env.setenv("ENVIRONMENT", "production")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_SERVICE_ROLE_KEY", make_dummy_jwt("service_role"))

    # Should execute cleanly without raising any exception
    verify_security_configuration()


def test_no_credential_leak_in_error_messages(clean_env):
    """
    Verifies that secret values or tokens are NEVER printed, leaked, or exposed
    inside exception messages.
    """
    sensitive_token = make_dummy_jwt("anon")
    clean_env.setenv("ENVIRONMENT", "production")
    clean_env.setenv("SUPABASE_URL", "https://test.supabase.co")
    clean_env.setenv("SUPABASE_SERVICE_ROLE_KEY", sensitive_token)

    with pytest.raises(RuntimeError) as exc_info:
        resolve_supabase_credentials()

    err_text = str(exc_info.value)
    assert sensitive_token not in err_text
    assert "service_role" in err_text or "anon" in err_text  # Mentions role name, not raw token


def test_lazy_supabase_client_delegation_and_isolation(clean_env, monkeypatch):
    """
    Verifies that the module-level 'supabase' lazy client fails closed when credentials
    are missing, and delegates properly when credentials are configured.
    """
    clean_env.delenv("SUPABASE_URL", raising=False)
    reset_supabase_client()

    # Accessing attributes on unconfigured lazy client raises descriptive error
    with pytest.raises(ValueError) as exc_info:
        _ = supabase.table("loans")
    assert "SUPABASE_URL is not set" in str(exc_info.value)

    # When mock client is returned by get_supabase_client, lazy proxy delegates seamlessly
    class MockClient:
        def table(self, name):
            return f"table_{name}"

    monkeypatch.setattr("database.connection.get_supabase_client", lambda: MockClient())
    assert supabase.table("users") == "table_users"

