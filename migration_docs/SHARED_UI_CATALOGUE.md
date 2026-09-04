# ICARE SHARED UI COMPONENT CATALOGUE

> Authority: shared widgets may be extracted in Flutter only after the identical Streamlit pattern is evidenced across routes. See `FLUTTER_STRUCTURE_CONTRACT.md`.

> **MANDATORY REFERENCE**: Sourced from `app.py`, `config/themes.py`, and `auth/login.py`.

---

## 1. Global Components

### 1.1. Sidebar Shell (`app.py` L1925–1990)
* **Top Status Bar**: `#FF4B4B` 4px solid running indicator.
* **Circular Logo**: Centered 65px circular image with `#0F2744` background and `#8CC63F` border.
* **Version Label**: `CORE BANKING v{APP_VERSION} (st v{st.__version__})` in `#94A3B8`, letter spacing 1px, font-size 0.65rem.
* **Divider**: `st.divider()`.
* **User Profile Card**: `#F8FAFC` rounded container, border `#E2E8F0`, full name in bold `#0F172A`, role badge with dynamic role color, branch label in `#64748B`.
* **Section Label**: `OPERATIONS` / `EXECUTIVE` / `ADMINISTRATION` in `#94A3B8`, 0.7rem uppercase font.
* **Radio Menu**: `st.radio` with custom CSS removing label, radio dot `#2563EB` for active item.
* **Sign Out Button**: Full-width card button `#FFFFFF`, border `#CBD5E1`, text `#334155`.

### 1.2. Top Welcome Banner (`app.py` L1991–2000)
* **Container**: Forest Green `#064E3B` rounded box, padding 1.25rem 1.5rem, border `1px solid rgba(255,255,255,0.08)`.
* **Heading**: `<h2>{greeting}, {display_name}</h2>` in white `#FFFFFF`.
* **Sub-Heading**: `<p>{role_label} &mdash; <span class='wb-gold'>{branch_display}</span> &middot; {Date}</p>` with gold/green accent `#8CC63F`.

### 1.3. KPI Metric Card (`st.metric`)
* **Standard Card**: White `#FFFFFF`, border `#E2E8F0`, rounded 8px, padding 1rem.
* **Label**: Font size 0.8rem, font-weight 600, color `#64748B`.
* **Primary Value**: Font size 1.75rem, font-weight 700, color `#0F172A`, formatted in Naira (`₦X,XXX`).
* **Delta Subtitle**: Font size 0.75rem, font-weight 600. Green `#16A34A` for positive, Red `#DC2626` for inverse/warning, Slate `#64748B` for neutral.

### 1.4. Operational Alert Boxes
* **Info Alert (`st.info`)**: Blue `#EFF6FF`, border `#BFDBFE`, text `#1E3A8A`, icon `ℹ️`.
* **Warning / Closure Alert (`st.warning`)**: Amber `#FFFBEB`, border `#FDE68A`, text `#92400E`, icon `🏖️` / `⚠️`.
* **Success Alert (`st.success`)**: Green `#F0FDF4`, border `#BBF7D0`, text `#166534`, icon `✅` / `🎉`.
* **Error Alert (`st.error`)**: Red `#FEF2F2`, border `#FCA5A5`, text `#991B1B`, icon `🚨`.

### 1.5. Data Tables (`st.dataframe`)
* **Styling**: `use_container_width=True, hide_index=True`.
* **Headers**: `#F8FAFC`, uppercase tracking, font size 12px, font-weight 700.
* **Cells**: 12px regular text, numeric columns right-aligned, status badges centered.

### 1.6. Tab Navigation (`st.tabs`)
* **Styling**: Horizontal tabs with bottom indicator line, active tab in `#064E3B` bold text.
