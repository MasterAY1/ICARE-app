"""
api/routes/observability.py
Authoritative Observability, Metrics, SLI/SLO, and Disaster Recovery Telemetry API.
Provides deep operational visibility into API response times, P95/P99 latency,
error rates, connection pool health, and proactive alerts for ICARE Core Banking.
Complies with Strict Zero-Emoji Governance.
"""

from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field

from api.dependencies import get_current_user_optional, CurrentUser
from services.metrics_service import get_metrics_service
from services.circuit_breaker import get_circuit_breaker
import time
import os

router = APIRouter(prefix="/api/v1/observability", tags=["Observability & System Health"])


@router.get("/metrics")
def get_metrics():
    """
    Returns real-time aggregated API request metrics, status code distribution,
    endpoint breakdowns, and exact latency percentiles (P50, P90, P95, P99).
    """
    service = get_metrics_service()
    return service.get_metrics_snapshot()


@router.get("/sli-slo")
def get_sli_slo_status():
    """
    Evaluates current system SLIs against approved institutional SLO targets:
    API Availability (>= 99.9%), Financial Mutation Latency (P95 < 1500ms),
    Read Latency (P95 < 500ms), and Zero Duplicate Postings.
    """
    service = get_metrics_service()
    return service.evaluate_sli_slo()


@router.get("/alerts")
def get_active_alerts():
    """
    Returns active real-time operational alerts evaluated against metrics thresholds:
    high error rates, elevated latency spikes, circuit breaker trips, or auth anomalies.
    """
    service = get_metrics_service()
    return {
        "active_alerts_count": len(service.get_active_alerts()),
        "alerts": service.get_active_alerts()
    }


@router.get("/health")
def get_system_health():
    """
    Comprehensive system health inspection including FastAPI process,
    Supabase database connectivity, roundtrip latency, and circuit breaker status.
    """
    from database.connection import get_supabase_client
    cb = get_circuit_breaker("database")
    cb_status = cb.get_status()

    t0 = time.monotonic()
    db_status = "disconnected"
    db_latency_ms = None
    try:
        client = get_supabase_client()
        client.table("clients").select("id").limit(1).execute()
        db_status = "connected"
        db_latency_ms = round((time.monotonic() - t0) * 1000, 2)
    except Exception as ex:
        db_status = f"error: {str(ex)}"

    return {
        "status": "healthy" if db_status == "connected" and cb_status["state"] == "CLOSED" else "degraded",
        "service": "ICARE Core Banking Platform",
        "version": "1.0.0",
        "environment": os.getenv("ENVIRONMENT", "production"),
        "database": {
            "status": db_status,
            "latency_ms": db_latency_ms,
            "connection_pooling": {
                "max_connections": 50,
                "max_keepalive": 20,
                "keepalive_expiry_seconds": 30.0
            }
        },
        "circuit_breaker": cb_status
    }


@router.get("/disaster-recovery")
def get_disaster_recovery_specification():
    """
    Returns authoritative Disaster Recovery (DR) operational objectives,
    backup retention capabilities, and restoration specifications.
    """
    return {
        "objectives": {
            "rpo": {
                "central_ledger_account_1000": "0 seconds (synchronous PostgreSQL Write-Ahead Log in AWS eu-west-1)",
                "field_offline_collections": "Up to 24 hours (local SQLite & SharedPreferences storage on officer tablets)"
            },
            "rto": {
                "database_failover_and_restore": "< 30 minutes",
                "backend_api_re_deployment": "< 10 minutes",
                "frontend_web_cdn_distribution": "< 5 minutes"
            }
        },
        "hosting_and_backups": {
            "database_provider": "Supabase PostgreSQL (AWS eu-west-1)",
            "backup_strategy": "Daily automated physical backups with continuous Write-Ahead Log (WAL) archiving",
            "point_in_time_recovery_available": True,
            "retention_window_days": 7
        },
        "restoration_protocol": {
            "step_1": "Declare incident and isolate production to prevent corrupted in-flight writes",
            "step_2": "Execute Point-in-Time Recovery to an isolated target instance (never restore directly over production)",
            "step_3": "Run automated 6-way financial reconciliation script against restored Account 1000 ledger",
            "step_4": "Update SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables in Render",
            "step_5": "Verify /api/health/ready and instruct field officers to synchronize local outboxes"
        }
    }
