"""
Centralized SVG Icon Library for ICARE Core Banking.
Provides clean, institutional vector icons (Lucide / Heroicons standard)
with zero external runtime dependencies.
"""

from typing import Optional

def get_svg_icon(
    name: str,
    size: int = 18,
    color: str = "currentColor",
    stroke_width: float = 2.0,
    class_name: str = ""
) -> str:
    """
    Returns an inline SVG string for the specified icon name.
    All icons use 24x24 viewBox, stroke-based vector styling.
    """
    cls_attr = f' class="{class_name}"' if class_name else ""
    svg_header = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="{stroke_width}" '
        f'stroke-linecap="round" stroke-linejoin="round"{cls_attr} style="vertical-align: middle; display: inline-block;">'
    )
    svg_footer = "</svg>"

    paths = {
        # Financial & Banking
        "bank": (
            '<path d="M3 21h18M3 10h18M5 6l7-3 7 3M4 10v11M20 10v11M8 14v4M12 14v4M16 14v4"/>'
        ),
        "building": (
            '<rect x="4" y="2" width="16" height="20" rx="2" ry="2"/>'
            '<path d="M9 22v-4h6v4M8 6h.01M16 6h.01M12 6h.01M12 10h.01M12 14h.01M16 10h.01M16 14h.01M8 10h.01M8 14h.01"/>'
        ),
        "wallet": (
            '<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1"/>'
            '<path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>'
        ),
        "credit-card": (
            '<rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/>'
        ),
        "coins": (
            '<circle cx="8" cy="8" r="6"/><path d="M18.09 10.37A6 6 0 1 1 10.34 18M7 6h1v4M16.7 13H18a2 2 0 0 1 2 2v1"/>'
        ),
        "piggy-bank": (
            '<path d="M19 5c-1.5 0-2.8 1.4-3 2-3.5-1.5-11-.3-11 5 0 1.8 0 3 2 4.5V20h4v-2h3v2h4v-4c1-.5 1.7-1 2-2h2v-4h-2c0-1-.5-1.5-1-2V5z"/>'
            '<path d="M2 9v1c0 1.1.9 2 2 2h1M16 11h.01"/>'
        ),
        "receipt": (
            '<path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1-2-1z"/>'
            '<line x1="8" y1="6" x2="16" y2="6"/><line x1="8" y1="10" x2="16" y2="10"/><line x1="8" y1="14" x2="12" y2="14"/>'
        ),
        "naira": (
            '<path d="M6 4v16M18 4v16M6 10h12M6 14h12M6 4l12 16"/>'
        ),

        # People & Roles
        "users": (
            '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>'
            '<path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>'
        ),
        "user": (
            '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>'
        ),
        "user-check": (
            '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>'
            '<polyline points="16 11 18 13 22 9"/>'
        ),

        # Documents & Records
        "file-text": (
            '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>'
            '<polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/>'
        ),
        "file-spreadsheet": (
            '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>'
            '<polyline points="14 2 14 8 20 8"/><path d="M8 13h8M8 17h8M12 10v10"/>'
        ),
        "clipboard-list": (
            '<rect x="8" y="2" width="8" height="4" rx="1" ry="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>'
            '<path d="M12 11h4M12 16h4M8 11h.01M8 16h.01"/>'
        ),

        # Status & Feedback
        "check-circle": (
            '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>'
        ),
        "check": (
            '<polyline points="20 6 9 17 4 12"/>'
        ),
        "x-circle": (
            '<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>'
        ),
        "x": (
            '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>'
        ),
        "alert-triangle": (
            '<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>'
            '<line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>'
        ),
        "alert-circle": (
            '<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>'
        ),
        "info": (
            '<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>'
        ),
        "clock": (
            '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>'
        ),

        # Navigation & System Controls
        "refresh-cw": (
            '<polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/>'
            '<path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>'
        ),
        "shield-check": (
            '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/>'
        ),
        "download": (
            '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>'
        ),
        "search": (
            '<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>'
        ),
        "calendar": (
            '<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>'
        ),
        "trending-up": (
            '<polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/>'
        ),
        "trending-down": (
            '<polyline points="23 18 13.5 8.5 8.5 13.5 1 6"/><polyline points="17 18 23 18 23 12"/>'
        ),
        "sliders": (
            '<line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/>'
        ),
        "tag": (
            '<path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/>'
        ),
        "arrow-left-right": (
            '<path d="M8 3 4 7l4 4M4 7h16M16 21l4-4-4-4M20 17H4"/>'
        )
    }

    inner = paths.get(name.lower(), paths["file-text"])
    return f"{svg_header}{inner}{svg_footer}"


def render_icon_badge(
    icon_name: str,
    label: str,
    bg_color: str = "#F1F5F9",
    text_color: str = "#1E293B",
    icon_color: Optional[str] = None,
    size: int = 14
) -> str:
    """
    Renders an accessible, institutional pill badge with an embedded vector icon.
    """
    actual_icon_color = icon_color or text_color
    svg = get_svg_icon(icon_name, size=size, color=actual_icon_color)
    return (
        f'<span style="display: inline-flex; align-items: center; gap: 6px; '
        f'padding: 3px 10px; border-radius: 9999px; font-size: 0.78rem; font-weight: 600; '
        f'background-color: {bg_color}; color: {text_color}; letter-spacing: 0.02em;">'
        f'{svg}{label}</span>'
    )


def render_section_header(
    title: str,
    subtitle: Optional[str] = None,
    icon: Optional[str] = None,
    badge: Optional[str] = None
) -> str:
    """
    Renders an institutional typography section header with optional vector icon and pill badge.
    """
    icon_html = f"{get_svg_icon(icon, size=20, color='#2E86C1')} " if icon else ""
    badge_html = f" &nbsp;{badge}" if badge else ""
    sub_html = f'<div style="font-size: 0.85rem; color: #64748B; margin-top: 2px;">{subtitle}</div>' if subtitle else ""
    return (
        f'<div style="margin-top: 14px; margin-bottom: 10px;">'
        f'<div style="display: flex; align-items: center; gap: 6px;">'
        f'{icon_html}<span style="font-size: 1.25rem; font-weight: 700; color: #0F172A; letter-spacing: -0.01em;">{title}</span>'
        f'{badge_html}</div>{sub_html}</div>'
    )
