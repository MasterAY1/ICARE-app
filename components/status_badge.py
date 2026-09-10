"""
Institutional Status Badge Component for ICARE Core Banking.
Renders clean, accessible pill badges with micro vector dots.
Replaces informal emojis (🟡, 🟢, 🔴, ✅, ❌, ⚠️) with enterprise styling.
"""

from typing import Dict, Any

STATUS_CONFIG: Dict[str, Dict[str, Any]] = {
    # Loan & Client Lifecycle
    "Pending": {"bg": "#FEF3C7", "text": "#92400E", "dot": "#D97706", "label": "Pending"},
    "Approved": {"bg": "#DEF7EC", "text": "#03543F", "dot": "#0E9F6E", "label": "Approved"},
    "Active": {"bg": "#E1EFFE", "text": "#1E429F", "dot": "#3F83F8", "label": "Active"},
    "On Loan": {"bg": "#E1EFFE", "text": "#1E429F", "dot": "#3F83F8", "label": "On Loan"},
    "Completed": {"bg": "#F3F4F6", "text": "#374151", "dot": "#9CA3AF", "label": "Completed"},
    "Closed": {"bg": "#FEE2E2", "text": "#991B1B", "dot": "#EF4444", "label": "Closed"},
    "Rejected": {"bg": "#FEE2E2", "text": "#991B1B", "dot": "#EF4444", "label": "Rejected"},
    "Suspended": {"bg": "#FEE2E2", "text": "#991B1B", "dot": "#DC2626", "label": "Suspended"},
    "Dormant": {"bg": "#F3F4F6", "text": "#4B5563", "dot": "#6B7280", "label": "Dormant"},
    "Defaulter": {"bg": "#FEE2E2", "text": "#7F1D1D", "dot": "#B91C1C", "label": "Defaulter"},
    "Registered": {"bg": "#F0FDF4", "text": "#166534", "dot": "#22C55E", "label": "Registered"},

    # Repayment & Collections
    "PAID": {"bg": "#DEF7EC", "text": "#03543F", "dot": "#0E9F6E", "label": "Paid"},
    "NOT_PAID": {"bg": "#FEE2E2", "text": "#991B1B", "dot": "#EF4444", "label": "Not Paid"},
    "PART_PAID": {"bg": "#FEF3C7", "text": "#92400E", "dot": "#D97706", "label": "Part Paid"},
    "EXCESS": {"bg": "#E1EFFE", "text": "#1E429F", "dot": "#2563EB", "label": "Excess"},

    # Reconciliation
    "BALANCED": {"bg": "#DEF7EC", "text": "#03543F", "dot": "#0E9F6E", "label": "Balanced"},
    "OUT_OF_BALANCE": {"bg": "#FEE2E2", "text": "#991B1B", "dot": "#EF4444", "label": "Out of Balance"},
}


def render_status_badge(status_val: str, label_override: str = None) -> str:
    """
    Renders an HTML/SVG pill badge for a given status.
    Safe for st.markdown(..., unsafe_allow_html=True).
    """
    clean_key = str(status_val or "").strip()
    cfg = STATUS_CONFIG.get(clean_key)
    if not cfg:
        # Fallback matching
        for k, v in STATUS_CONFIG.items():
            if k.lower() == clean_key.lower():
                cfg = v
                break
    if not cfg:
        cfg = {"bg": "#F1F5F9", "text": "#475569", "dot": "#94A3B8", "label": clean_key or "Unknown"}

    display_text = label_override or cfg.get("label", clean_key)
    dot_color = cfg["dot"]

    return (
        f'<span style="display: inline-flex; align-items: center; gap: 6px; '
        f'padding: 3px 10px; border-radius: 9999px; font-size: 0.76rem; font-weight: 600; '
        f'background-color: {cfg["bg"]}; color: {cfg["text"]}; letter-spacing: 0.02em; line-height: 1.2;">'
        f'<svg width="6" height="6" viewBox="0 0 6 6" fill="{dot_color}" style="flex-shrink: 0;">'
        f'<circle cx="3" cy="3" r="3"/></svg>'
        f'{display_text}'
        f'</span>'
    )


def format_status_text(status_val: str) -> str:
    """
    Returns clean, professional text without cartoon emojis.
    Used for st.dataframe or plain selectbox options.
    """
    s = str(status_val or "").strip()
    # Strip any residual emojis
    for emoji in ["🟡", "🟢", "🔴", "✅", "❌", "⚠️", "⏳", "🔵", "🚨"]:
        s = s.replace(emoji, "").strip()
    return s
