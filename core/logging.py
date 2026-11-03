"""
core/logging.py
Production-grade structured JSON logging with cryptographic credential redaction
and correlation ID tracing for the ICARE Core Banking Platform.
Complies with Strict Zero-Emoji Governance.
"""

import sys
import json
import logging
import re
from typing import Any, Dict, Set
from datetime import datetime, timezone
from contextvars import ContextVar

# Thread-local/async context variable for request correlation ID
request_id_ctx: ContextVar[str] = ContextVar("request_id_ctx", default="")

# Sensitive keys that must NEVER appear in logs or error traces
SENSITIVE_KEYS: Set[str] = {
    "password",
    "current_password",
    "new_password",
    "confirm_password",
    "temp_token",
    "access_token",
    "mfa_token",
    "totp_code",
    "secret",
    "auth_secret",
    "icare_auth_secret",
    "service_role_key",
    "supabase_service_role_key",
    "supabase_key",
    "recovery_code",
    "recovery_hashes",
    "bvn",
    "nin",
    "pin",
    "card_number",
    "account_number"
}

# Regex to sanitize bearer tokens in header strings
BEARER_REGEX = re.compile(r"Bearer\s+([A-Za-z0-9_\-\.]+)", re.IGNORECASE)


def mask_sensitive_data(data: Any) -> Any:
    """
    Recursively inspects and masks sensitive credentials in dictionaries,
    lists, and strings to prevent private customer/auth leaks.
    """
    if isinstance(data, dict):
        sanitized = {}
        for k, v in data.items():
            k_lower = str(k).lower().strip()
            if any(sensitive in k_lower for sensitive in SENSITIVE_KEYS):
                sanitized[k] = "[REDACTED]"
            elif isinstance(v, (dict, list)):
                sanitized[k] = mask_sensitive_data(v)
            elif isinstance(v, str):
                sanitized[k] = BEARER_REGEX.sub("Bearer [REDACTED]", v)
            else:
                sanitized[k] = v
        return sanitized

    elif isinstance(data, list):
        return [mask_sensitive_data(item) for item in data]

    elif isinstance(data, str):
        return BEARER_REGEX.sub("Bearer [REDACTED]", data)

    return data


class StructuredJsonFormatter(logging.Formatter):
    """
    Formats log records into machine-readable JSON with ISO timestamps,
    request correlation IDs, and credential redaction.
    """
    def format(self, record: logging.LogRecord) -> str:
        log_entry: Dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": mask_sensitive_data(record.getMessage()),
        }

        # Inject correlation ID if available in request context
        req_id = request_id_ctx.get() or getattr(record, "request_id", "")
        if req_id:
            log_entry["request_id"] = req_id

        # Attach custom extra fields passed to logger.info(..., extra={...})
        for key, val in record.__dict__.items():
            if key not in (
                "args", "asctime", "created", "exc_info", "exc_text", "filename",
                "funcName", "id", "levelname", "levelno", "lineno", "module",
                "msecs", "message", "msg", "name", "pathname", "process",
                "processName", "relativeCreated", "stack_info", "thread",
                "threadName", "request_id"
            ):
                log_entry[key] = mask_sensitive_data(val)

        # Include exception trace if present
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_entry, default=str)


def configure_logging(level: int = logging.INFO) -> None:
    """Configures the root and ICARE loggers with StructuredJsonFormatter."""
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(StructuredJsonFormatter())

    root_logger = logging.getLogger()
    # Remove existing handlers to avoid duplicate log entries
    for h in list(root_logger.handlers):
        root_logger.removeHandler(h)

    root_logger.addHandler(handler)
    root_logger.setLevel(level)

    # Ensure uvicorn and app loggers route through structured formatter
    for logger_name in ("icare", "icare.api", "icare.telemetry", "icare.circuit_breaker", "uvicorn.access"):
        log = logging.getLogger(logger_name)
        log.handlers.clear()
        log.addHandler(handler)
        log.propagate = False
        log.setLevel(level)


def get_logger(name: str) -> logging.Logger:
    """Retrieves a logger instance configured for structured output."""
    return logging.getLogger(name)
