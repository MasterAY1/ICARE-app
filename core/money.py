"""
core/money.py
Fixed-precision banking monetary arithmetic using Python's Decimal with explicit
commercial rounding rules (2 decimal places, ROUND_HALF_UP) for ICARE Core Banking.
"""
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any, Iterable, Optional

MONEY_QUANT = Decimal("0.01")
MONEY_ROUNDING = ROUND_HALF_UP


def to_decimal(
    value: Any,
    *,
    allow_none: bool = False,
    quantize: bool = True,
) -> Optional[Decimal]:
    """
    Converts a numeric or string monetary input into a finite fixed-precision Decimal.
    Rejects booleans, NaN, Infinity, and malformed values cleanly with ValueError.
    """
    if value is None:
        if allow_none:
            return None
        raise ValueError("Monetary amount cannot be None.")

    if isinstance(value, bool):
        raise ValueError("Boolean value is not a valid monetary amount.")

    try:
        if isinstance(value, Decimal):
            dec = value
        elif isinstance(value, int):
            dec = Decimal(value)
        else:
            raw = str(value).strip()
            if not raw:
                raise ValueError("Monetary amount cannot be blank.")
            dec = Decimal(raw)
    except (InvalidOperation, ValueError) as exc:
        raise ValueError(f"Invalid monetary amount: {value!r}") from exc

    if not dec.is_finite():
        raise ValueError(f"Monetary amount must be finite: {value!r}")

    if quantize:
        return dec.quantize(MONEY_QUANT, rounding=MONEY_ROUNDING)
    return dec


def assert_positive_money(value: Any, label: str = "Amount") -> Decimal:
    """Validates and quantizes a strictly positive (> 0.00) monetary amount."""
    dec = to_decimal(value, quantize=True)
    if dec is None or dec <= Decimal("0.00"):
        raise ValueError(f"{label} must be greater than zero.")
    return dec


def sum_money(values: Iterable[Any]) -> Decimal:
    """Sums an iterable of monetary values using exact Decimal arithmetic quantized to 2dp."""
    total = Decimal("0.00")
    for val in values:
        dec = to_decimal(val, quantize=True)
        if dec is not None:
            total += dec
    return total.quantize(MONEY_QUANT, rounding=MONEY_ROUNDING)


def format_money_str(value: Any) -> str:
    """Formats a monetary value as an exact fixed-point string with 2 decimal places."""
    dec = to_decimal(value, quantize=True)
    return f"{dec:.2f}"
