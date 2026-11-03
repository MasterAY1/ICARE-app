"""
services/circuit_breaker.py
Production-grade, thread-safe Circuit Breaker for ICARE Core Banking Platform.
Prevents cascading failures, protects worker thread pools, and provides fast-fail
resilience for database and external service calls during network instability.
Complies with Strict Zero-Emoji Governance.
"""

import enum
import time
import threading
import logging
from typing import Callable, Any, Optional, Dict
from fastapi import status
from api.core.errors import ICAREException

logger = logging.getLogger("icare.circuit_breaker")


class CircuitState(str, enum.Enum):
    CLOSED = "CLOSED"         # Normal operation, requests pass through
    OPEN = "OPEN"             # Failing fast, requests blocked without hitting downstream service
    HALF_OPEN = "HALF_OPEN"   # Canary trial state, testing if service has recovered


class CircuitBreakerOpenException(ICAREException):
    """Raised when an operation is attempted while the circuit breaker is in OPEN state."""
    def __init__(self, service_name: str, remaining_cooldown: float):
        super().__init__(
            error_code="CIRCUIT_BREAKER_OPEN",
            title="Service Temporarily Unavailable",
            message=f"The external service '{service_name}' is currently experiencing instability and is temporarily isolated.",
            action=f"System is preventing cascading outages. Please wait {int(remaining_cooldown) + 1} seconds before retrying.",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            details={"service": service_name, "remaining_cooldown_seconds": remaining_cooldown}
        )


class CircuitBreaker:
    """
    Thread-safe 3-state Circuit Breaker implementing the standard resilience pattern.
    """
    def __init__(
        self,
        name: str,
        failure_threshold: int = 5,
        cooldown_seconds: float = 15.0,
        window_seconds: float = 30.0
    ):
        self.name = name
        self.failure_threshold = failure_threshold
        self.cooldown_seconds = cooldown_seconds
        self.window_seconds = window_seconds

        self._lock = threading.Lock()
        self._state = CircuitState.CLOSED
        self._failure_timestamps = []
        self._last_state_change = time.monotonic()
        self._consecutive_successes = 0

    @property
    def state(self) -> CircuitState:
        with self._lock:
            self._evaluate_state()
            return self._state

    def _evaluate_state(self) -> None:
        """Internal helper to evaluate timeout-based transition from OPEN to HALF_OPEN."""
        now = time.monotonic()
        if self._state == CircuitState.OPEN:
            elapsed = now - self._last_state_change
            if elapsed >= self.cooldown_seconds:
                logger.info(f"[CIRCUIT_BREAKER] {self.name}: Cooldown elapsed ({elapsed:.1f}s). Transitioning OPEN -> HALF_OPEN.")
                self._state = CircuitState.HALF_OPEN
                self._last_state_change = now
                self._consecutive_successes = 0

    def call(self, func: Callable, *args, **kwargs) -> Any:
        """
        Executes the provided callable protected by the circuit breaker.
        Fails fast with CircuitBreakerOpenException if the circuit is OPEN.
        """
        now = time.monotonic()

        with self._lock:
            self._evaluate_state()

            if self._state == CircuitState.OPEN:
                remaining = max(0.0, self.cooldown_seconds - (now - self._last_state_change))
                raise CircuitBreakerOpenException(self.name, remaining)

        # Execute callable outside the lock to prevent blocking concurrent callers
        try:
            result = func(*args, **kwargs)
            self.record_success()
            return result
        except Exception as exc:
            # Re-raise without recording if it's already a circuit breaker open exception
            if isinstance(exc, CircuitBreakerOpenException):
                raise
            self.record_failure()
            raise

    def record_success(self) -> None:
        """Records a successful operation, resetting or recovering the circuit."""
        with self._lock:
            now = time.monotonic()
            if self._state == CircuitState.HALF_OPEN:
                self._consecutive_successes += 1
                logger.info(f"[CIRCUIT_BREAKER] {self.name}: Canary call succeeded in HALF_OPEN. Transitioning -> CLOSED.")
                self._state = CircuitState.CLOSED
                self._failure_timestamps.clear()
                self._last_state_change = now
            elif self._state == CircuitState.CLOSED:
                # In closed state, prune failures outside sliding window
                cutoff = now - self.window_seconds
                self._failure_timestamps = [ts for ts in self._failure_timestamps if ts > cutoff]

    def record_failure(self) -> None:
        """Records a failed operation, potentially tripping the circuit to OPEN."""
        with self._lock:
            now = time.monotonic()
            if self._state == CircuitState.HALF_OPEN:
                logger.warning(f"[CIRCUIT_BREAKER] {self.name}: Canary call failed in HALF_OPEN. Tripping back -> OPEN.")
                self._state = CircuitState.OPEN
                self._last_state_change = now
            elif self._state == CircuitState.CLOSED:
                self._failure_timestamps.append(now)
                cutoff = now - self.window_seconds
                self._failure_timestamps = [ts for ts in self._failure_timestamps if ts > cutoff]

                if len(self._failure_timestamps) >= self.failure_threshold:
                    logger.warning(
                        f"[CIRCUIT_BREAKER] {self.name}: Failure threshold reached ({len(self._failure_timestamps)} in {self.window_seconds}s). "
                        f"Tripping CLOSED -> OPEN for {self.cooldown_seconds}s."
                    )
                    self._state = CircuitState.OPEN
                    self._last_state_change = now

    def reset(self) -> None:
        """Manually forces the circuit breaker back to CLOSED state."""
        with self._lock:
            self._state = CircuitState.CLOSED
            self._failure_timestamps.clear()
            self._last_state_change = time.monotonic()
            self._consecutive_successes = 0

    def get_status(self) -> Dict[str, Any]:
        """Returns diagnostic metrics for health check and telemetry endpoints."""
        with self._lock:
            self._evaluate_state()
            now = time.monotonic()
            time_in_state = now - self._last_state_change
            remaining_cooldown = max(0.0, self.cooldown_seconds - time_in_state) if self._state == CircuitState.OPEN else 0.0
            return {
                "name": self.name,
                "state": self._state.value,
                "failure_count_in_window": len(self._failure_timestamps),
                "failure_threshold": self.failure_threshold,
                "cooldown_seconds": self.cooldown_seconds,
                "remaining_cooldown_seconds": remaining_cooldown if self._state == CircuitState.OPEN else 0.0,
                "time_in_state_seconds": time_in_state
            }


# Thread-safe global registry
_registry: Dict[str, CircuitBreaker] = {}
_registry_lock = threading.Lock()


def get_circuit_breaker(
    name: str = "database",
    failure_threshold: int = 5,
    cooldown_seconds: float = 15.0,
    window_seconds: float = 30.0
) -> CircuitBreaker:
    """Retrieves or creates a named circuit breaker singleton."""
    with _registry_lock:
        if name not in _registry:
            _registry[name] = CircuitBreaker(
                name=name,
                failure_threshold=failure_threshold,
                cooldown_seconds=cooldown_seconds,
                window_seconds=window_seconds
            )
        return _registry[name]
