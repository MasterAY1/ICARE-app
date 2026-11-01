"""
Telemetry and APM Relay API Route.

Enables cross-platform Flutter clients (Mobile, Web, Desktop) to securely report
unhandled frontend exceptions and performance metrics directly into backend APM
(Sentry) and structured observability logs.
"""
import logging
from typing import Optional, Dict, Any
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field

from api.dependencies import get_current_user_optional, CurrentUser

logger = logging.getLogger("icare.telemetry")
router = APIRouter(prefix="/api/v1/telemetry", tags=["Telemetry"])


class ClientCrashReport(BaseModel):
    error: str = Field(..., description="Exception or error message string")
    stack_trace: Optional[str] = Field(None, description="Formatted client stack trace")
    platform: Optional[str] = Field("web", description="Client platform e.g. web, android, ios")
    route: Optional[str] = Field(None, description="Client route/screen where error occurred")
    context: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Additional client state metadata")


class TelemetryResponse(BaseModel):
    recorded: bool
    status: str


@router.post("/client-error", response_model=TelemetryResponse, status_code=status.HTTP_200_OK)
def report_client_error(
    report: ClientCrashReport,
    current_user: Optional[CurrentUser] = Depends(get_current_user_optional)
):
    """
    Ingests and forwards client-side error telemetry to Sentry APM and structured logs.
    """
    user_info = f"{current_user.username} ({current_user.role})" if current_user else "Unauthenticated"
    logger.error(
        f"[CLIENT ERROR] Platform: {report.platform} | User: {user_info} | Route: {report.route} | "
        f"Error: {report.error}\nStack Trace:\n{report.stack_trace or 'No stack trace provided'}"
    )

    try:
        import sentry_sdk
        if sentry_sdk.is_initialized():
            with sentry_sdk.push_scope() as scope:
                scope.set_tag("client.platform", report.platform)
                if report.route:
                    scope.set_tag("client.route", report.route)
                if current_user:
                    scope.set_user({"id": current_user.id, "username": current_user.username, "role": current_user.role})
                if report.context:
                    for k, v in report.context.items():
                        scope.set_extra(k, v)
                sentry_sdk.capture_message(f"ClientError: {report.error}", level="error")
    except Exception as ex_sentry:
        logger.debug(f"Sentry relay notice: {ex_sentry}")

    return TelemetryResponse(recorded=True, status="Logged")
