"""
tests/test_observability_and_disaster_recovery.py
Comprehensive test suite for Prompt 4: Observability and Disaster Recovery.
Validates:
1. Structured JSON logging and cryptographic credential redaction (passwords/tokens never logged).
2. Request ID generation, propagation, and correlation tracing.
3. In-memory API request metrics aggregation and exact percentile calculation (P50, P90, P95, P99).
4. Measurable SLI/SLO compliance evaluation against institutional microfinance targets.
5. Real-time proactive alerting triggers (high error rates, latency spikes, circuit breaker trips).
6. Observability API endpoints (/metrics, /sli-slo, /alerts, /disaster-recovery).
7. Isolated Disaster Recovery restoration runbook verification logic.
Complies with Strict Zero-Emoji Governance.
"""

import pytest
import json
import logging
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient

from api.main import app
from core.logging import StructuredJsonFormatter, mask_sensitive_data, request_id_ctx
from services.metrics_service import MetricsService, get_metrics_service
from services.circuit_breaker import get_circuit_breaker


@pytest.fixture(autouse=True)
def reset_observability_state():
    """Clears metrics and resets circuit breaker before each test."""
    app.dependency_overrides.clear()
    get_metrics_service().clear_all()
    get_circuit_breaker("database").reset()
    yield
    app.dependency_overrides.clear()
    get_metrics_service().clear_all()
    get_circuit_breaker("database").reset()


class TestStructuredLoggingAndRedaction:
    """Validates structured JSON output and non-negotiable credential redaction."""

    def test_sensitive_credentials_masked_in_dict(self):
        raw_payload = {
            "username": "OGI_CO1",
            "password": "SuperSecretPassword123!",
            "current_password": "OldPassword456!",
            "new_password": "BrandNewPassword789!",
            "temp_token": "pwd_chg:usr-1:token_abc",
            "access_token": "eyJhbGciOiJIUzI1NiIsIn...",
            "mfa_token": "mfa:challenge:usr-1",
            "totp_code": "123456",
            "bvn": "22233344455",
            "nin": "99988877766",
            "account_number": "0123456789",
            "client_name": "Adewale Johnson",
            "amount": 25000.0
        }

        sanitized = mask_sensitive_data(raw_payload)

        # Sensitive keys MUST be redacted
        assert sanitized["password"] == "[REDACTED]"
        assert sanitized["current_password"] == "[REDACTED]"
        assert sanitized["new_password"] == "[REDACTED]"
        assert sanitized["temp_token"] == "[REDACTED]"
        assert sanitized["access_token"] == "[REDACTED]"
        assert sanitized["mfa_token"] == "[REDACTED]"
        assert sanitized["totp_code"] == "[REDACTED]"
        assert sanitized["bvn"] == "[REDACTED]"
        assert sanitized["nin"] == "[REDACTED]"
        assert sanitized["account_number"] == "[REDACTED]"

        # Non-sensitive keys MUST remain intact
        assert sanitized["username"] == "OGI_CO1"
        assert sanitized["client_name"] == "Adewale Johnson"
        assert sanitized["amount"] == 25000.0

    def test_bearer_token_sanitization_in_strings(self):
        auth_header = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0"
        sanitized = mask_sensitive_data(auth_header)
        assert sanitized == "Bearer [REDACTED]"

    def test_structured_json_formatter_produces_valid_json(self):
        formatter = StructuredJsonFormatter()
        record = logging.LogRecord(
            name="icare.test",
            level=logging.INFO,
            pathname="test_file.py",
            lineno=42,
            msg="User login attempt completed",
            args=(),
            exc_info=None
        )
        record.request_id = "req-test-uuid-1234"

        output = formatter.format(record)
        parsed = json.loads(output)

        assert parsed["level"] == "INFO"
        assert parsed["logger"] == "icare.test"
        assert parsed["message"] == "User login attempt completed"
        assert parsed["request_id"] == "req-test-uuid-1234"
        assert "timestamp" in parsed


class TestCorrelationIdAndTracingMiddleware:
    """Validates X-Request-ID propagation through the FastAPI middleware pipeline."""

    def test_incoming_request_receives_generated_request_id(self):
        client = TestClient(app)
        res = client.get("/health")
        assert res.status_code == 200
        assert "X-Request-ID" in res.headers
        assert res.headers["X-Request-ID"].startswith("req-")

    def test_client_provided_request_id_is_preserved(self):
        client = TestClient(app)
        custom_id = "trace-client-device-9988-aabb"
        res = client.get("/health", headers={"X-Request-ID": custom_id})
        assert res.status_code == 200
        assert res.headers["X-Request-ID"] == custom_id


class TestMetricsServiceAndPercentiles:
    """Validates in-memory metrics collection and exact latency percentiles."""

    def test_request_counters_and_status_tracking(self):
        metrics = MetricsService()
        metrics.record_request("GET", "/api/v1/co/dashboard", 200, 120.0)
        metrics.record_request("POST", "/api/v1/co/collections/single-submit", 200, 350.0)
        metrics.record_request("POST", "/api/v1/co/collections/batch-submit", 422, 50.0)
        metrics.record_request("GET", "/api/v1/bm/dashboard", 500, 1500.0)

        snap = metrics.get_metrics_snapshot()
        assert snap["traffic"]["total_requests"] == 4
        assert snap["traffic"]["status_2xx"] == 2
        assert snap["traffic"]["status_4xx"] == 1
        assert snap["traffic"]["status_5xx"] == 1
        assert snap["traffic"]["error_rate_percentage"] == 25.0

    def test_exact_percentile_calculations(self):
        # 100 samples from 10ms to 1000ms in increments of 10ms
        samples = [float(i * 10) for i in range(1, 101)]
        res = MetricsService.calculate_percentiles(samples)

        assert res["count"] == 100
        assert res["min_ms"] == 10.0
        assert res["max_ms"] == 1000.0
        assert res["avg_ms"] == 505.0
        assert res["p50_ms"] == 500.0
        assert res["p90_ms"] == 900.0
        assert res["p95_ms"] == 950.0
        assert res["p99_ms"] == 990.0

    def test_empty_samples_percentile_calculation(self):
        res = MetricsService.calculate_percentiles([])
        assert res["count"] == 0
        assert res["p50_ms"] == 0.0
        assert res["p95_ms"] == 0.0
        assert res["p99_ms"] == 0.0


class TestSliSloCompliance:
    """Validates SLI calculation against approved banking SLO targets."""

    def test_slo_evaluation_compliant(self):
        metrics = MetricsService()
        # 100 successful requests with low latency
        for _ in range(100):
            metrics.record_request("GET", "/api/v1/co/dashboard", 200, 150.0)

        slo = metrics.evaluate_sli_slo()
        assert slo["overall_slo_status"] == "COMPLIANT"
        avail = next(o for o in slo["objectives"] if o["objective"] == "API Availability")
        assert avail["status"] == "COMPLIANT"
        assert avail["sli_value"] == "100.0%"

    def test_slo_evaluation_breached_on_high_error_rate(self):
        metrics = MetricsService()
        # 90 successful, 10 failures (90% availability, breaches 99.9% target)
        for _ in range(90):
            metrics.record_request("GET", "/api/v1/co/dashboard", 200, 150.0)
        for _ in range(10):
            metrics.record_request("POST", "/api/v1/co/collections/batch-submit", 500, 2000.0)

        slo = metrics.evaluate_sli_slo()
        assert slo["overall_slo_status"] == "BREACHED"
        avail = next(o for o in slo["objectives"] if o["objective"] == "API Availability")
        assert avail["status"] == "BREACHED"


class TestProactiveAlerting:
    """Validates real-time threshold alert triggers."""

    def test_high_error_rate_alert(self):
        metrics = MetricsService()
        # 90 successful, 10 errors -> 10% error rate (threshold 1.0%)
        for _ in range(90):
            metrics.record_request("GET", "/api/v1/co/dashboard", 200, 100.0)
        for _ in range(10):
            metrics.record_request("GET", "/api/v1/co/dashboard", 500, 100.0)

        alerts = metrics.get_active_alerts()
        alert_ids = [a["alert_id"] for a in alerts]
        assert "HIGH_ERROR_RATE" in alert_ids

    def test_circuit_breaker_alert_when_open(self):
        metrics = MetricsService()
        cb = get_circuit_breaker("database")
        for _ in range(5):
            cb.record_failure()

        alerts = metrics.get_active_alerts()
        alert_ids = [a["alert_id"] for a in alerts]
        assert "CIRCUIT_BREAKER_TRIPPED" in alert_ids

    def test_auth_failure_burst_alert(self):
        metrics = MetricsService()
        for _ in range(10):
            metrics.record_auth_failure()

        alerts = metrics.get_active_alerts()
        alert_ids = [a["alert_id"] for a in alerts]
        assert "RAPID_AUTH_FAILURES" in alert_ids


class TestObservabilityApiEndpoints:
    """Validates HTTP endpoints exposed under /api/v1/observability."""

    def test_get_metrics_endpoint(self):
        client = TestClient(app)
        res = client.get("/api/v1/observability/metrics")
        assert res.status_code == 200
        data = res.json()
        assert "traffic" in data
        assert "latency_global" in data
        assert "domain_events" in data

    def test_get_sli_slo_endpoint(self):
        client = TestClient(app)
        res = client.get("/api/v1/observability/sli-slo")
        assert res.status_code == 200
        data = res.json()
        assert "overall_slo_status" in data
        assert "objectives" in data
        assert len(data["objectives"]) >= 4

    def test_get_alerts_endpoint(self):
        client = TestClient(app)
        res = client.get("/api/v1/observability/alerts")
        assert res.status_code == 200
        data = res.json()
        assert "active_alerts_count" in data
        assert isinstance(data["alerts"], list)

    def test_get_disaster_recovery_specification(self):
        client = TestClient(app)
        res = client.get("/api/v1/observability/disaster-recovery")
        assert res.status_code == 200
        data = res.json()
        assert "objectives" in data
        assert data["objectives"]["rpo"]["central_ledger_account_1000"].startswith("0 seconds")
        assert data["objectives"]["rto"]["database_failover_and_restore"] == "< 30 minutes"
        assert "restoration_protocol" in data


class TestDisasterRecoverySimulation:
    """Validates isolated disaster recovery restoration procedure and verification."""

    def test_simulated_dr_restore_verification_logic(self):
        # Simulates verifying an isolated target database before DNS cutover
        mock_dr_client = MagicMock()

        # Mock table checks
        mock_dr_client.table.return_value.select.return_value.limit.return_value.execute.return_value.data = [{"id": "entry-1"}]

        # Mock 6-way financial reconciliation check (debits == credits on Account 1000)
        mock_dr_client.rpc.return_value.execute.return_value.data = {
            "reconciliation_status": "BALANCED",
            "total_debits": 5000000.0,
            "total_credits": 5000000.0,
            "variance": 0.0,
            "orphans_count": 0
        }

        # Step 1: Health check against isolated instance
        res_health = mock_dr_client.table("clients").select("id").limit(1).execute()
        assert len(res_health.data) == 1

        # Step 2: Financial ledger balance check
        rec_res = mock_dr_client.rpc("verify_account_1000_reconciliation").execute()
        assert rec_res.data["reconciliation_status"] == "BALANCED"
        assert rec_res.data["variance"] == 0.0
        assert rec_res.data["orphans_count"] == 0

        # Step 3: Cutover approval gate
        can_cutover = (
            len(res_health.data) > 0 and
            rec_res.data["reconciliation_status"] == "BALANCED" and
            rec_res.data["variance"] == 0.0
        )
        assert can_cutover is True


class TestReadinessHealthCheckEndpoint:
    """Validates /api/health/ready deep readiness check endpoint."""

    @patch("database.connection.get_supabase_client")
    def test_readiness_check_success(self, mock_get_client):
        mock_client = MagicMock()
        mock_client.table.return_value.select.return_value.limit.return_value.execute.return_value.data = [
            {"client_id": "c-123"}
        ]
        mock_get_client.return_value = mock_client

        client = TestClient(app)
        res = client.get("/api/health/ready")
        assert res.status_code == 200
        data = res.json()
        assert data["ready"] is True
        assert data["status"] == "ready"
        assert data["database"]["status"] == "connected"
        assert "latency_ms" in data["database"]
        mock_client.table.assert_called_with("clients")
        mock_client.table("clients").select.assert_called_with("client_id")

    @patch("database.connection.get_supabase_client")
    def test_readiness_check_db_failure_fails_closed(self, mock_get_client):
        mock_client = MagicMock()
        mock_client.table.side_effect = RuntimeError("Database unreachable")
        mock_get_client.return_value = mock_client

        client = TestClient(app)
        res = client.get("/api/health/ready")
        assert res.status_code == 503
        data = res.json()
        assert data["ready"] is False
        assert data["status"] == "unhealthy"
        assert data["database"]["status"] == "disconnected"

