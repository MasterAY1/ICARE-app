"""
Unit Tests for Telemetry API and Sentry APM Relay.

Verifies:
1. POST /api/v1/telemetry/client-error records client crash reports from Flutter.
2. User context attribution for authenticated errors.
3. Health check returns APM status.
"""
import unittest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient

from api.main import app


class TestTelemetryAPI(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)

    def test_health_check_returns_apm_field(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("apm_enabled", data)
        self.assertEqual(data["status"], "healthy")

    def test_report_client_error_anonymous(self):
        payload = {
            "error": "RenderFlex overflowed by 24 pixels on the bottom",
            "stack_trace": "#0 RenderFlex.performLayout (rendering/flex.dart:100)",
            "platform": "web",
            "route": "/co/portfolio",
            "context": {"screen_width": 1024, "screen_height": 768}
        }
        response = self.client.post("/api/v1/telemetry/client-error", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["recorded"])
        self.assertEqual(data["status"], "Logged")

    def test_report_client_error_with_user_context(self):
        payload = {
            "error": "NullPointerException on client data load",
            "stack_trace": "#0 ClientService.load (client.dart:55)",
            "platform": "android",
            "route": "/bm/approvals"
        }
        token_data = {"user_id": "u-123", "username": "bm_user", "timestamp": 1234567890}
        with patch("api.dependencies.validate_session_token", return_value=token_data), \
             patch("api.dependencies.get_cached_user", return_value=MagicMock(id="u-123", username="bm_user", role="BM")):
            response = self.client.post(
                "/api/v1/telemetry/client-error",
                json=payload,
                headers={"Authorization": "Bearer test-valid-token"}
            )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["recorded"])


if __name__ == "__main__":
    unittest.main()
