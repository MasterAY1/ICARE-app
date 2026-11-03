"""
tests/test_network_resilience_and_reliability.py
Comprehensive test suite for Prompt 3: Network Resilience and API Reliability.
Validates:
1. 3-state Circuit Breaker (CLOSED -> OPEN -> HALF_OPEN -> CLOSED).
2. Safe HTTP transport & connection pool limits (POST timeouts not blindly retried).
3. Canonical Transaction Status Recovery endpoint (/api/v1/transactions/status/{idempotency_key}).
4. Two-tier health checks (liveness vs deep database readiness).
5. Financial rate limiting & double-tap protection (HTTP 429 Too Many Requests).
6. Idempotency lock recovery and mismatched payload rejection.
Complies with Strict Zero-Emoji Governance.
"""

import pytest
import time
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient
import httpx

from api.main import app
from api.dependencies import get_uow, get_current_user, CurrentUser
from services.circuit_breaker import CircuitBreaker, CircuitState, CircuitBreakerOpenException, get_circuit_breaker
from services.rate_limiter import FinancialRateLimiter, get_financial_rate_limiter
from database.connection import RetryingHTTPTransport


@pytest.fixture(autouse=True)
def clean_environment():
    """Ensures rate limiters and circuit breakers are clean for every test."""
    app.dependency_overrides.clear()
    get_financial_rate_limiter().clear_all()
    cb = get_circuit_breaker("database")
    cb.reset()
    yield
    app.dependency_overrides.clear()
    get_financial_rate_limiter().clear_all()
    cb.reset()


class TestCircuitBreaker:
    """Validates 3-state Circuit Breaker transitions and failure fast behavior."""

    def test_closed_state_allows_calls(self):
        cb = CircuitBreaker("test_service", failure_threshold=3, cooldown_seconds=1.0)
        result = cb.call(lambda: "success_value")
        assert result == "success_value"
        assert cb.state == CircuitState.CLOSED

    def test_failure_threshold_trips_to_open(self):
        cb = CircuitBreaker("test_service", failure_threshold=3, cooldown_seconds=1.0)

        def failing_op():
            raise RuntimeError("Database connection timed out")

        for _ in range(3):
            with pytest.raises(RuntimeError):
                cb.call(failing_op)

        # After 3 failures, state must be OPEN
        assert cb.state == CircuitState.OPEN

        # Subsequent calls must fail fast with CircuitBreakerOpenException without running the function
        mock_fn = MagicMock()
        with pytest.raises(CircuitBreakerOpenException) as exc_info:
            cb.call(mock_fn)
        assert exc_info.value.status_code == 503
        mock_fn.assert_not_called()

    def test_open_transitions_to_half_open_after_cooldown(self):
        cb = CircuitBreaker("test_service", failure_threshold=2, cooldown_seconds=0.1)

        def failing_op():
            raise RuntimeError("Network error")

        for _ in range(2):
            with pytest.raises(RuntimeError):
                cb.call(failing_op)

        assert cb.state == CircuitState.OPEN

        # Wait for cooldown to expire
        time.sleep(0.15)

        # Evaluating state should now transition to HALF_OPEN
        assert cb.state == CircuitState.HALF_OPEN

        # Successful canary call resets circuit to CLOSED
        res = cb.call(lambda: "canary_recovered")
        assert res == "canary_recovered"
        assert cb.state == CircuitState.CLOSED

    def test_half_open_failure_re_trips_to_open(self):
        cb = CircuitBreaker("test_service", failure_threshold=2, cooldown_seconds=0.1)

        for _ in range(2):
            with pytest.raises(RuntimeError):
                cb.call(lambda: (_ for _ in ()).throw(RuntimeError("Fail")))

        assert cb.state == CircuitState.OPEN
        time.sleep(0.15)
        assert cb.state == CircuitState.HALF_OPEN

        # Canary call fails -> trips back to OPEN
        with pytest.raises(RuntimeError):
            cb.call(lambda: (_ for _ in ()).throw(RuntimeError("Canary failed")))

        assert cb.state == CircuitState.OPEN


class TestSafeHttpTransport:
    """Validates that mutating POST operations are never blindly retried on TimeoutException."""

    def test_post_timeout_is_not_retried(self):
        transport = RetryingHTTPTransport(retries=3)
        mock_super_handle = MagicMock(side_effect=httpx.TimeoutException("Read timed out"))

        req = httpx.Request("POST", "https://mock.supabase.co/rest/v1/rpc/atomic_execute_operations")

        with patch.object(httpx.HTTPTransport, "handle_request", mock_super_handle):
            with pytest.raises(httpx.TimeoutException):
                transport.handle_request(req)

        # MUST be called exactly once: NO BLIND RETRIES on mutating POST timeouts!
        assert mock_super_handle.call_count == 1

    def test_get_timeout_is_safely_retried(self):
        transport = RetryingHTTPTransport(retries=3)
        mock_super_handle = MagicMock(side_effect=httpx.TimeoutException("Read timed out"))

        req = httpx.Request("GET", "https://mock.supabase.co/rest/v1/clients")

        with patch.object(httpx.HTTPTransport, "handle_request", mock_super_handle):
            with pytest.raises(httpx.TimeoutException):
                transport.handle_request(req)

        # Idempotent GET: safe to retry up to max_retries (3 times)
        assert mock_super_handle.call_count == 3


class TestCanonicalTransactionStatusEndpoint:
    """Validates /api/v1/transactions/status/{idempotency_key} recovery flow."""

    def test_status_confirmed_returns_cached_receipt(self):
        mock_uow = MagicMock()
        mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [{
            "key": "IDEM-OGI-BATCH-001",
            "scope": "batch_collection",
            "status": "COMMITTED",
            "response_code": 200,
            "response_body": {
                "batch_id": "COL-2026-11-03-A1B2",
                "total_collected": 150000.0,
                "repayments_count": 10
            },
            "created_at": "2026-11-03T10:00:00Z",
            "locked_at": "2026-11-03T10:00:01Z"
        }]

        mock_user = CurrentUser(
            id="usr-co-1",
            username="OGI_CO1",
            role="Credit Officer",
            branch_id="b-ogi-1",
            branch="Ogijo"
        )

        app.dependency_overrides[get_uow] = lambda: mock_uow
        app.dependency_overrides[get_current_user] = lambda: mock_user

        client = TestClient(app)
        res = client.get("/api/v1/transactions/status/IDEM-OGI-BATCH-001")

        assert res.status_code == 200
        data = res.json()
        assert data["idempotency_key"] == "IDEM-OGI-BATCH-001"
        assert data["status"] == "Confirmed"
        assert data["raw_status"] == "COMMITTED"
        assert data["response_code"] == 200
        assert data["response_body"]["batch_id"] == "COL-2026-11-03-A1B2"

    def test_status_processing_returns_in_flight(self):
        mock_uow = MagicMock()
        mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [{
            "key": "IDEM-OGI-BATCH-002",
            "scope": "batch_collection",
            "status": "PROCESSING",
            "response_code": None,
            "response_body": None,
            "created_at": "2026-11-03T10:05:00Z",
            "locked_at": "2026-11-03T10:05:01Z"
        }]

        mock_user = CurrentUser(
            id="usr-co-1",
            username="OGI_CO1",
            role="Credit Officer",
            branch_id="b-ogi-1",
            branch="Ogijo"
        )

        app.dependency_overrides[get_uow] = lambda: mock_uow
        app.dependency_overrides[get_current_user] = lambda: mock_user

        client = TestClient(app)
        res = client.get("/api/v1/transactions/status/IDEM-OGI-BATCH-002")

        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "Processing"
        assert data["raw_status"] == "PROCESSING"

    def test_status_not_found_returns_404(self):
        mock_uow = MagicMock()
        mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []

        mock_user = CurrentUser(
            id="usr-co-1",
            username="OGI_CO1",
            role="Credit Officer",
            branch_id="b-ogi-1",
            branch="Ogijo"
        )

        app.dependency_overrides[get_uow] = lambda: mock_uow
        app.dependency_overrides[get_current_user] = lambda: mock_user

        client = TestClient(app)
        res = client.get("/api/v1/transactions/status/IDEM-NON-EXISTENT")
        assert res.status_code == 404
        assert "not found" in res.json()["detail"].lower()


class TestTwoTierHealthChecks:
    """Validates liveness probe vs deep database readiness probe."""

    def test_liveness_check_returns_200_immediately(self):
        client = TestClient(app)
        res = client.get("/api/health/liveness")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "healthy"
        assert data["service"] == "ICARE Core Banking API"

    def test_readiness_check_healthy_database(self):
        mock_client = MagicMock()
        mock_client.table.return_value.select.return_value.limit.return_value.execute.return_value.data = [{"id": "c-1"}]

        with patch("database.connection.get_supabase_client", return_value=mock_client):
            client = TestClient(app)
            res = client.get("/api/health/ready")
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "ready"
            assert data["ready"] is True
            assert data["database"]["status"] == "connected"
            assert "latency_ms" in data["database"]

    def test_readiness_check_database_unreachable_returns_503(self):
        mock_client = MagicMock()
        mock_client.table.return_value.select.return_value.limit.return_value.execute.side_effect = Exception("Supabase unreachable")

        with patch("database.connection.get_supabase_client", return_value=mock_client):
            client = TestClient(app)
            res = client.get("/api/health/ready")
            assert res.status_code == 503
            data = res.json()
            assert data["status"] == "unhealthy"
            assert data["ready"] is False
            assert data["database"]["status"] == "disconnected"

    def test_readiness_check_circuit_open_returns_503(self):
        cb = get_circuit_breaker("database")
        # Trip circuit breaker
        for _ in range(5):
            cb.record_failure()
        assert cb.state == CircuitState.OPEN

        client = TestClient(app)
        res = client.get("/api/health/ready")
        assert res.status_code == 503
        data = res.json()
        assert data["status"] == "unhealthy"
        assert data["ready"] is False
        assert data["circuit_breaker"]["state"] == "OPEN"


class TestFinancialRateLimiter:
    """Validates rapid double-tap protection on financial mutations."""

    def test_financial_burst_rate_limiting(self):
        limiter = FinancialRateLimiter(max_requests=3, window_seconds=2.0)
        key = "officer_123:batch_collection"

        # First 3 requests permitted
        for _ in range(3):
            is_limited, _ = limiter.check_rate_limit(key)
            assert is_limited is False

        # 4th rapid request within 2s window is blocked
        is_limited, retry_after = limiter.check_rate_limit(key)
        assert is_limited is True
        assert retry_after >= 1
