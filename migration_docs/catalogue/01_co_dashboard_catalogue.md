# Parity Catalogue: 01 — Credit Officer Dashboard

**Source Implementation**: `app.py` L3140–3215  
**Navigation & Sidebar Source**: `app.py` L2340–2407, `services/rbac_scope_service.py` L30–33  
**Backend Service Authority**: `services/dashboard_service.py` L228–699 (`DashboardService.get_co_dashboard_data`)  
**Target Screen**: `frontend_flutter/lib/features/co/presentation/co_dashboard_screen.dart`  
**API Route**: `GET /api/v1/co/dashboard` (`api/routes/co/dashboard.py`, `api/schemas/dashboard.py`)  

---

## 1. Page Title & Identity
* **Exact Title**: `Credit Officer Dashboard — {USER} ({BRANCH})` (`app.py` L3140)
  - Rendered as Markdown H3 (`### Credit Officer Dashboard — ...`)
  - Subordinate to Sidebar Navigation label `Dashboard` (`app.py` L2366, `ROLE_NAVIGATION["CO"]`)
* **Welcome Banner (Global Header)**:
  - Top greeting: `{greeting}, {display_name}` (`Good morning` / `Good afternoon` / `Good evening`)
  - Sub-header: `{role_label} — {branch_display} · {Day, Month DD, YYYY}`

---

## 2. Section Titles
1. **Welcome Alert**: Contextual Info Banner (no section title, full-width `st.info`)
2. **Branch Closure Warning**: Conditional Alert (no section title, full-width `st.warning`)
3. **Section 1**: `Today's Repayment Summary` (`st.markdown("#### Today's Repayment Summary")`, L3150)
4. **Section 2**: `Today's Meeting Portfolio` (`st.markdown("#### Today's Meeting Portfolio")`, L3158)
   - Sub-heading inside: `Quick Action: Start Collection` (`st.markdown("##### Quick Action: Start Collection")`, L3163)
5. **Section 3**: `Today's Savings` (`st.markdown("#### Today's Savings")`, L3180)
6. **Section 4**: `Today's Repayment Status` (`st.markdown("#### Today's Repayment Status")`, L3188)
7. **Section 5**: `Cash Position (CO Cashbook)` (`st.markdown("#### Cash Position (CO Cashbook)")`, L3197)
8. **Section 6**: `Today's Attention List` (`st.markdown("#### Today's Attention List")`, L3209)

---

## 3. Labels & Metric Cards
### Section 1: Today's Repayment Summary (3 Columns)
| Card Label | Value Format | Delta Format | Accent / Styling |
|---|---|---|---|
| `60D / 12W / 3M` | `₦{amt:,.0f}` | `{count} Clients Paid` | Standard white container, 1px `#E2E8F0` border |
| `120D / 24W / 6M` | `₦{amt:,.0f}` | `{count} Clients Paid` | Standard white container, 1px `#E2E8F0` border |
| `Total Repayment Today` | `₦{amt:,.0f}` | *(none)* | Dark Emerald `#064E3B` card, white text |

### Section 3: Today's Savings (3 Columns)
| Card Label | Value Format | Delta Format | Accent / Styling |
|---|---|---|---|
| `Savings Deposited` | `₦{amt:,.0f}` | `{count} Clients` | Standard white container, green upward delta |
| `Savings Withdrawn` | `₦{amt:,.0f}` | `{count} Clients` | Standard white container, red downward delta (`inverse`) |
| `Net Savings` | `₦{amt:,.0f}` | *(none)* | Standard white container |

### Section 4: Today's Repayment Status (4 Columns)
| Card Label | Value Format | Delta Format | Accent / Styling |
|---|---|---|---|
| `Full Payment` | `₦{amt:,.0f}` | `{count} Loans Settled` | Emerald top border / tag (`#16A34A`) |
| `Excess Payment` | `₦{amt:,.0f}` | `{count} Surplus Payers` | Blue top border / tag (`#2563EB`) |
| `Part Payment` | `₦{amt:,.0f}` | `{count} Underpayers` | Amber top border / tag (`#D97706`) |
| `Not Paid` | `₦{amt:,.0f}` | `{count} Non-Payers` | Rose/Red top border / tag (`#DC2626`), inverse delta |

### Section 5: Cash Position (CO Cashbook) (Row 1: 4 Columns, Row 2: 2 Columns)
| Card Label | Value Format | Delta Format | Source |
|---|---|---|---|
| `Opening Balance` | `₦{amt:,.0f}` | *(none)* | `co_cashbooks` / Account 1000 projection |
| `Cash In` | `₦{amt:,.0f}` | *(none)* | `co_cashbooks` / Account 1000 projection |
| `Cash Out` | `₦{amt:,.0f}` | *(none)* | `co_cashbooks` / Account 1000 projection |
| `Closing Balance` | `₦{amt:,.0f}` | *(none)* | `co_cashbooks` / Account 1000 projection |
| `Cashbook Status` | `{status}` (e.g. `Balanced`) | *(none)* | Projection check (`diff == 0.0`) |
| `Difference` | `₦{amt:,.0f}` | *(none)* | `round(abs(opening + in - out - closing), 2)` |

---

## 4. Buttons & Quick Actions
* **Start Collection Action Buttons**:
  - Location: Directly under `Today's Meeting Portfolio` table.
  - Label: `Start {g_name} ({status_badge})` (e.g., `Start Unity Group (Completed)`)
  - Status Badge text cleaned by `format_status_text`: NO EMOJIS (e.g., `Completed`, `In Progress`, `Pending`, `Scheduled`).
  - Button Action:
    1. Sets active navigation to `Collections` (`st.session_state["Navigation"] = "Collections"`).
    2. Preselects `Group Collection Sheet` mode (`st.session_state["collections_mode_radio"] = "Group Collection Sheet"`).
    3. Preselects the clicked group (`st.session_state["sel_group"] = g_name`).

---

## 5. Tables & Columns
### Table 1: Today's Meeting Portfolio
* Rendered via: `st.dataframe(m_port, use_container_width=True, hide_index=True)`
* Primary Columns:
  1. `Group Name` (string, left-aligned)
  2. `Expected (₦)` / `Expected Collection` (currency, right-aligned)
  3. `Collected (₦)` / `Collected` (currency, right-aligned, bold `#064E3B`)
  4. `Outstanding (₦)` / `Outstanding` (currency, right-aligned)
  5. `Compliance` / `Compliance %` (percentage, right-aligned)
  6. `Status` (string status badge, center-aligned)
* Additional underlying columns from backend: `Meeting Day`, `Clients Expected`, `Clients Paid`, `Clients Not Paid`.

### Table 2: Today's Attention List
* Rendered via: `st.dataframe(att_list, use_container_width=True, hide_index=True)`
* Primary Columns:
  1. `Client Name` (string, left-aligned)
  2. `Group` (string, left-aligned)
  3. `Expected (₦)` (currency, right-aligned)
  4. `Paid (₦)` (currency, right-aligned)
  5. `Shortfall (₦)` (currency, right-aligned, bold `#DC2626`)
  6. `Status` / `Issue Type` (string, e.g. `Part Payment`, `Overdue Arrears + Current`, `Pending`)
* Additional underlying columns: `Client Code`, `Risk Level`, `Action`.

---

## 6. Filters, Tabs & Forms
* **Filters**: None for CO Dashboard (always scoped to the authenticated officer and today's business date).
* **Tabs**: None on the CO Dashboard main canvas (CO operations tabs are routed via Sidebar Navigation: `Dashboard`, `Loan Origination`, `Collections`, `Withdrawal Operations`, `Portfolio`, `CO Cashbook`).
* **Forms**: None (read-only analytical overview; mutations occur in Collections, Withdrawals, Origination, Cashbook).

---

## 7. Status Indicators & Badges
* **Institutional Status Dots** (`components/status_badge.py`):
  - `Completed`: `#064E3B` dark emerald bg, `#ECFDF5` text, green dot.
  - `In Progress`: `#1E40AF` blue bg, `#EFF6FF` text, blue dot.
  - `Pending`: `#92400E` amber bg, `#FFFBEB` text, amber dot.
  - `Balanced`: `#064E3B` emerald text.
  - `Unbalanced`: `#991B1B` red text.
* **Strict Rule**: Zero emojis in badges.

---

## 8. Colours & Styling Tokens
* **Background**: `#F8FAFC` (Page body canvas), `#FFFFFF` (Card container).
* **Borders**: 1px solid `#E2E8F0`, `border-radius: 8px`.
* **Shadows**: None / Flat (`elevation: 0`).
* **Accent Emerald**: `#064E3B` (Primary brand dark emerald), `#16A34A` (Positive delta).
* **Warning Amber**: `#92400E` text, `#FFFBEB` bg, `#FDE68A` border.
* **Error Rose/Red**: `#DC2626` / `#991B1B` text, `#FEF2F2` bg, `#FCA5A5` border.
* **Info Blue**: `#1E3A8A` text, `#EFF6FF` bg, `#BFDBFE` border.
* **Neutral Slate**: `#0F172A` (Headings), `#334155` (Body), `#64748B` (Muted labels).

---

## 9. Typography
* **Headings**: `Plus Jakarta Sans`, 600/700 weight.
* **Body / Labels**: `Source Sans 3` / System sans-serif, 400/500 weight.
* **Currency Figures**: `JetBrains Mono` / Tabular monospace numbers, 600/700 weight.

---

## 10. Icons
* **Zero Emojis**: Strictly prohibited (GEMINI Rule 10).
* **Icon System**: Institutional SVGs or clean Material icons matching corporate theme:
  - Info: Info circle SVG / `Icons.info_outline`
  - Warning: Alert triangle SVG / `Icons.warning_amber_rounded`
  - Success: Check circle SVG / `Icons.check_circle_outline`
  - Delta Up: Up arrow SVG / `Icons.arrow_upward`
  - Delta Down: Down arrow SVG / `Icons.arrow_downward`

---

## 11. Layout & Spacing
* Maximum content width: Full container width with 24px padding.
* Grid row spacing: 16px to 24px between sections.
* Metric card spacing: 12px to 14px horizontal gap.
* Section header spacing: 8px bottom margin before card rows/tables.

---

## 12. Empty States
1. **Meeting Portfolio Empty State** (`app.py` L3177):
   - Text: `No active groups scheduled for today.`
   - Container: Full-width info box (`#EFF6FF`, 1px border `#BFDBFE`).
2. **Attention List Empty State** (`app.py` L3214):
   - Text: `All scheduled clients have completed full repayments for today.`
   - Container: Full-width success box (`#F0FDF4`, 1px border `#BBF7D0`, text `#166534`).

---

## 13. Error States
* API Load Failure:
  - Container: `#FEF2F2` error banner, border `#FCA5A5`.
  - Content: Error message + `Retry` action button.

---

## 14. Success States
* Attention List 100% Repaid:
  - Success banner: `"All scheduled clients have completed full repayments for today."` (exact punctuation: period, no exclamation mark, no party popper emoji).

---

## 15. Conditional States (Branch Closure / Holiday)
* Trigger: `co_data["branch_closure"]["is_closed"] == True` (`app.py` L3146–3148)
* Notice: `**Branch Closed / Holiday ({reason})**: All field collections, group meetings, and daily/weekly/monthly repayments are suspended for {branch_name} Branch today.`
* Background: `#FFFBEB`, Border: `#FDE68A`, Text: `#92400E`.

---

## 16. Calculations (Server-Side Authority)
* Flutter does NOT compute:
  - `rep_12_weeks_amt`, `rep_24_weeks_amt`, `total_collected_today`
  - `deposited_amt`, `withdrawn_amt`, `net_savings`
  - `full_payment`, `excess_payment`, `part_payment`, `not_paid` counts and totals
  - `opening_balance`, `cash_in`, `cash_out`, `closing_balance`, `difference`, `status`
  - Meeting compliance % and status
* All calculations are computed by `DashboardService.get_co_dashboard_data` via `ScheduleService`, `RepaymentStatusEngine`, and `CoCashbookProjectionBuilder` from Account 1000.

---

## 17. Navigation & RBAC Visibility
* **Role**: `Credit Officer` (`CO`)
* **Permitted Menu Items**:
  1. `Dashboard`
  2. `Loan Origination`
  3. `Collections`
  4. `Withdrawal Operations`
  5. `Portfolio`
  6. `CO Cashbook`
* **Route Guard**: Only users with role `CO`, `BM`, `AM`, `Admin` can view the CO dashboard route.

---

## 18. Required API Contract
* **Endpoint**: `GET /api/v1/co/dashboard?date={YYYY-MM-DD}`
* **Response Model**: `CoDashboardResponse`
* **Keys**:
  - `welcome`: `{"officer_name": str, "branch_name": str, "date_str": str, "meeting_day": str, "time_str": str}`
  - `branch_closure`: `{"is_closed": bool, "reason": str}`
  - `repayment_summary`: `{"rep_12_weeks_amt": float, "rep_12_weeks_clients": int, "rep_24_weeks_amt": float, "rep_24_weeks_clients": int, "total_collected_today": float}`
  - `meeting_portfolio`: `[{"Group Name": str, "Expected": float, "Collected": float, "Outstanding": float, "Compliance %": float, "Status": str, ...}]`
  - `savings`: `{"deposited_amt": float, "deposited_clients": int, "withdrawn_amt": float, "withdrawn_clients": int, "net_savings": float}`
  - `repayment_status`: `{"full_payment": {"count": int, "amount": float}, "excess_payment": {"count": int, "amount": float}, "part_payment": {"count": int, "amount": float}, "not_paid": {"count": int, "amount": float}}`
  - `cash_position`: `{"opening_balance": float, "cash_in": float, "cash_out": float, "closing_balance": float, "status": str, "difference": float}`
  - `attention_list`: `[{"Client Name": str, "Group": str, "Expected (₦)": float, "Paid (₦)": float, "Shortfall (₦)": float, "Issue Type": str, ...}]`
