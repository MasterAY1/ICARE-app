"""
Institutional Metric Card Component for ICARE Core Banking.
Renders clean, styled KPI cards with subtle borders and SVG icons.
Replaces informal emojis with enterprise-grade typography.
"""

from typing import Optional
from components.icons import get_svg_icon

def render_metric_card(
    label: str,
    value: str,
    subtitle: Optional[str] = None,
    icon: Optional[str] = None,
    trend: Optional[str] = None,
    trend_positive: bool = True,
    border_left_color: Optional[str] = None
) -> str:
    """
    Renders an institutional KPI metric card in HTML with subtle vector accents.
    Safe for st.markdown(..., unsafe_allow_html=True).
    """
    icon_html = ""
    if icon:
        icon_html = (
            f'<div style="background: #F8FAFC; border: 1px solid #E2E8F0; padding: 6px; '
            f'border-radius: 8px; display: inline-flex; align-items: center; justify-content: center;">'
            f'{get_svg_icon(icon, size=18, color="#2E86C1")}'
            f'</div>'
        )

    trend_html = ""
    if trend:
        color = "#059669" if trend_positive else "#DC2626"
        trend_icon = "trending-up" if trend_positive else "trending-down"
        trend_svg = get_svg_icon(trend_icon, size=12, color=color)
        trend_html = (
            f'<span style="display: inline-flex; align-items: center; gap: 4px; '
            f'font-size: 0.75rem; font-weight: 600; color: {color}; margin-top: 4px;">'
            f'{trend_svg}{trend}</span>'
        )

    sub_html = ""
    if subtitle:
        sub_html = f'<div style="font-size: 0.78rem; color: #64748B; margin-top: 4px;">{subtitle}</div>'

    border_style = f"border-left: 4px solid {border_left_color};" if border_left_color else ""

    return (
        f'<div style="background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 10px; '
        f'padding: 14px 16px; box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04); {border_style}">'
        f'<div style="display: flex; justify-content: space-between; align-items: flex-start;">'
        f'<div>'
        f'<div style="font-size: 0.8rem; font-weight: 600; color: #64748B; text-transform: uppercase; letter-spacing: 0.04em;">{label}</div>'
        f'<div style="font-size: 1.45rem; font-weight: 700; color: #0F172A; margin-top: 6px; letter-spacing: -0.02em;">{value}</div>'
        f'</div>'
        f'{icon_html}'
        f'</div>'
        f'{trend_html}'
        f'{sub_html}'
        f'</div>'
    )
