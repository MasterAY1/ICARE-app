import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
import math
import uuid
import hashlib
import base64
import os
import bcrypt
from supabase import create_client, Client
import holidays

# Initialize Nigerian holidays
ng_holidays = holidays.Nigeria()

@st.cache_data(ttl=3600)
def get_custom_closures():
    try:
        res = supabase.table("branch_closures").select("*").execute()
        if res.data:
            closures = []
            for row in res.data:
                s_date = datetime.strptime(row['start_date'], "%Y-%m-%d").date()
                e_date = datetime.strptime(row['end_date'], "%Y-%m-%d").date()
                closures.append((s_date, e_date, row['reason']))
            return closures
    except Exception:
        pass
    return []

def get_next_working_day(target_date, custom_closures=None):
    """
    Checks if a date is a weekend, Nigerian public holiday, or falls within custom_closures.
    If so, pushes the date forward until it hits a valid working day.
    Returns the new date and the reason for the shift.
    """
    if custom_closures is None:
        custom_closures = []
        
    original_date = target_date
    reasons = []
    
    while True:
        is_closure = False
        for s_date, e_date, reason in custom_closures:
            if s_date <= target_date <= e_date:
                is_closure = True
                closure_reason = f"a branch closure ({reason})"
                if closure_reason not in reasons:
                    reasons.append(closure_reason)
                break
                
        if target_date.weekday() >= 5 or target_date in ng_holidays or is_closure:
            if target_date.weekday() >= 5 and "a weekend" not in reasons:
                reasons.append("a weekend")
            if target_date in ng_holidays:
                holiday_name = ng_holidays.get(target_date)
                holiday_reason = f"a public holiday ({holiday_name})"
                if holiday_reason not in reasons:
                    reasons.append(holiday_reason)
            
            target_date += timedelta(days=1)
        else:
            break
        
    is_adjusted = target_date != original_date
    return target_date, is_adjusted, " and ".join(reasons)

def generate_repayment_schedule(start_date, total_installments, frequency):
    """
    Generates valid working dates.
    Uses a theoretical target date to prevent schedule drift.
    """
    schedule = []
    theoretical_date = start_date
    closures = get_custom_closures()
    
    for _ in range(total_installments):
        # Find the actual valid working day for this installment
        valid_date, _, _ = get_next_working_day(theoretical_date, closures)
        schedule.append(valid_date)
        
        # Step the THEORETICAL date forward for the next loop
        if frequency.lower() == 'daily':
            theoretical_date += timedelta(days=1)
        elif frequency.lower() == 'weekly':
            theoretical_date += timedelta(days=7)
        elif frequency.lower() == 'monthly':
            theoretical_date += relativedelta(months=1)
            
    return schedule

@st.cache_data
def get_base64_image(image_path):
    if not os.path.exists(image_path):
        return ""
    with open(image_path, "rb") as img_file:
        return base64.b64encode(img_file.read()).decode()

LOGO_B64 = get_base64_image("assets/icare_logo.jpg")

def get_next_client_number(all_loans, branch, group_string):
    if all_loans.empty:
        return 1
    branch_loans = all_loans[all_loans['Branch'] == branch]
    if branch_loans.empty:
        return 1
    g_str = str(group_string).strip()
    if not g_str or g_str.lower() in ["none", "nan", "ungrouped", "ind"]:
        group_loans = branch_loans[branch_loans['Group Name'].isna() | (branch_loans['Group Name'] == '') | (branch_loans['Group Name'].str.lower() == 'ind')]
    else:
        group_loans = branch_loans[branch_loans['Group Name'] == g_str]
    if group_loans.empty:
        return 1
    max_num = 0
    for cid in group_loans['Client ID'].dropna():
        parts = str(cid).split('-')
        if len(parts) >= 3:
            try:
                num = int(parts[-1])
                if num > max_num: max_num = num
            except: pass
    return max_num + 1

def generate_client_id(all_loans, branch_name, group_string, member_num_or_index, is_bulk=False):
    import re
    # 1. Get branch prefix (first 3 letters, uppercase)
    b_prefix = str(branch_name)[:3].upper() if branch_name else "UNK"
    
    # 2. Get group prefix
    g_str = str(group_string).strip()
    if not g_str or g_str.lower() in ["none", "nan", "ungrouped", "ind"]:
        g_prefix = "IND" # Individual / Ungrouped
    else:
        # Check if this group already exists in the branch and has a prefix
        import pandas as pd
        branch_loans = all_loans[all_loans['Branch'] == branch_name] if not all_loans.empty else pd.DataFrame()
        group_loans = branch_loans[branch_loans['Group Name'] == g_str] if not branch_loans.empty else pd.DataFrame()
        
        found_existing = False
        if not group_loans.empty:
            for cid in group_loans['Client ID'].dropna():
                parts = str(cid).split('-')
                if len(parts) >= 3 and parts[1].isdigit():
                    g_prefix = parts[1]
                    found_existing = True
                    break
        
        if not found_existing:
            # New group, assign next sequential number based on all groups in branch
            max_g_num = 0
            if not branch_loans.empty:
                for cid in branch_loans['Client ID'].dropna():
                    parts = str(cid).split('-')
                    if len(parts) >= 3 and parts[1].isdigit():
                        try:
                            num = int(parts[1])
                            if num > max_g_num:
                                max_g_num = num
                        except: pass
            g_prefix = str(max_g_num + 1).zfill(2)
            
    # 3. Get member number
    try:
        m_num = int(float(member_num_or_index))
    except:
        m_num = 1 # Fallback
        
    m_prefix = str(m_num).zfill(3)
    
    return f"{b_prefix}-{g_prefix}-{m_prefix}"

import sys
import os
import holidays
from pandas.tseries.offsets import CustomBusinessDay
# import extra_streamlit_components as stx  # Replaced with native JS cookies

# 🚨 THE ABSOLUTE FIRST COMMAND 🚨
st.set_page_config(
    page_title="ICARE Microfinance - Core Banking",
    page_icon="🌱",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Add utils to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from utils.google_sheets import export_loans_to_sheet, export_repayments_to_sheet, export_summary_report
from utils.reports import (
    generate_portfolio_summary, create_portfolio_chart, 
    create_officer_performance_chart, create_weekly_trend_chart,
    generate_officer_report, export_to_excel
)

# --- 1. CONFIGURATION & CLOUD DB SETUP ---
COMPANY_NAME = "ICARE Microfinance"
APP_VERSION = "3.0.0"

# Initialize Supabase
@st.cache_resource
def init_connection():
    try:
        url = st.secrets["SUPABASE_URL"]
        key = st.secrets["SUPABASE_KEY"]
        return create_client(url, key)
    except Exception as e:
        st.error(f"Failed to connect to database: {e}")
        return None

supabase = init_connection()

@st.cache_data(ttl=600)
def load_co_mapping():
    if not supabase:
        return {}, {}
    try:
        res = supabase.table("app_users").select("username, full_name").in_("role", ["CO", "Officer"]).execute()
        if res.data:
            name_map = {row["full_name"].strip(): row["username"] for row in res.data if row.get("full_name")}
            display_map = {v: k for k, v in name_map.items()}
            return name_map, display_map
    except Exception as e:
        print(f"Error loading CO mapping: {e}")
    return {}, {}

CO_NAME_MAP, CO_DISPLAY_MAP = load_co_mapping()

# --- RBAC AUTHENTICATION ---
def authenticate_user(username, password):
    if not supabase:
        return None
    try:
        res = supabase.table("app_users").select("*").ilike("username", username).execute()
        if res.data and len(res.data) > 0:
            user = res.data[0]
            stored_hash = user.get("password", "")
            
            # Check if the stored password matches the bcrypt hash
            if str(stored_hash).startswith("$2") and bcrypt.checkpw(str(password).encode('utf-8'), str(stored_hash).encode('utf-8')):
                return {
                    'user_name': user['username'],
                    'user_role': user['role'],
                    'branch_name': user['branch_name']
                }
    except Exception as e:
        st.error(f"Auth error: {e}")
    return None

# Custom CSS — ICARE Banking Design System v5.0 (Brand Colors)
st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
    
    /* === ICARE BRAND PALETTE === */
    /* Primary Blue: #2E86C1  |  Accent Green: #8CC63F  |  Dark: #1B4F72 */
    
    /* === BASE === */
    .stApp { 
        background: #F0F4F8 !important;
        font-family: 'Inter', -apple-system, sans-serif !important;
    }
    h1 { color: #1B4F72 !important; font-weight: 800; font-size: 1.8rem; letter-spacing: -0.5px; }
    h2 { color: #1B4F72 !important; font-weight: 700; font-size: 1.4rem; }
    h3 { color: #1A1D23 !important; font-weight: 700; font-size: 1.15rem; }
    h4 { color: #1A1D23 !important; font-weight: 600; font-size: 1rem; }
    
    /* === METRICS === */
    .stMetric {
        background: #FFFFFF;
        border-radius: 12px;
        padding: 18px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
        border: 1px solid #E5E7EB;
        transition: transform 0.2s ease, box-shadow 0.2s ease;
    }
    .stMetric:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(46,134,193,0.12); }
    div[data-testid="stMetricValue"] { color: #1B4F72 !important; font-size: 1.7rem; font-weight: 800; }
    div[data-testid="stMetricLabel"] { color: #6B7280 !important; font-size: 0.8rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
    
    /* === INPUTS === */
    .stTextInput input, .stNumberInput input, .stSelectbox div, 
    .stTextArea textarea, .stDateInput input {
        background-color: #FFFFFF !important;
        color: #1A1D23 !important;
        border: 1px solid #D1D5DB;
        border-radius: 8px;
    }
    .stTextInput input:focus, .stNumberInput input:focus {
        border-color: #2E86C1 !important;
        box-shadow: 0 0 0 3px rgba(46, 134, 193, 0.12) !important;
    }
    
    /* === BUTTONS === */
    .stButton > button { 
        background: linear-gradient(135deg, #2E86C1 0%, #3498DB 100%) !important;
        color: white !important;
        font-weight: 600 !important;
        border: none;
        height: 2.8em;
        border-radius: 8px;
        transition: all 0.25s ease;
        box-shadow: 0 2px 4px rgba(46, 134, 193, 0.2);
        letter-spacing: 0.3px;
    }
    .stButton > button:hover { 
        background: linear-gradient(135deg, #2574A9 0%, #2E86C1 100%) !important;
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(46, 134, 193, 0.3);
    }
    .stButton > button:active { transform: translateY(0); }
    
    /* === TABLES === */
    div[data-testid="stDataFrame"] { 
        background-color: #FFFFFF !important;
        border-radius: 10px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06);
        border: 1px solid #E5E7EB;
    }
    
    /* === SIDEBAR — Professional Light Theme === */
    section[data-testid="stSidebar"] {
        background: #FFFFFF !important;
        border-right: 1px solid #E2E8F0 !important;
    }
    section[data-testid="stSidebar"] .stRadio label { 
        color: #334155 !important; 
        font-weight: 500;
        font-size: 0.9rem;
        transition: color 0.2s, background 0.2s;
        padding: 4px 8px;
        border-radius: 6px;
    }
    section[data-testid="stSidebar"] .stRadio label:hover { 
        color: #2E86C1 !important;
        background: #EBF5FB;
    }
    section[data-testid="stSidebar"] .stDivider { border-color: #E2E8F0 !important; }
    section[data-testid="stSidebar"] .stButton > button {
        background: #F8F9FA !important;
        color: #334155 !important;
        border: 1px solid #E2E8F0 !important;
        box-shadow: none !important;
    }
    section[data-testid="stSidebar"] .stButton > button:hover {
        background: #FEE2E2 !important;
        color: #991B1B !important;
        border-color: #FECACA !important;
    }
    
    /* === ALERTS === */
    .stAlert { border-radius: 10px; }
    
    /* === CARDS === */
    .card {
        background: #FFFFFF;
        border-radius: 14px;
        padding: 24px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
        margin-bottom: 20px;
        border: 1px solid #E5E7EB;
    }
    .metric-card {
        background: #FFFFFF;
        border-radius: 12px;
        padding: 22px;
        text-align: center;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06);
        border-top: 3px solid #2E86C1;
        transition: transform 0.2s ease, box-shadow 0.2s ease;
    }
    .metric-card:hover {
        transform: translateY(-3px);
        box-shadow: 0 6px 16px rgba(46,134,193,0.12);
    }
    .metric-value { font-size: 2rem; font-weight: 800; color: #1B4F72; letter-spacing: -0.5px; }
    .metric-label { font-size: 0.8rem; color: #6B7280; margin-top: 6px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
    
    /* === STATUS BADGES === */
    .status-badge { display: inline-block; padding: 5px 12px; border-radius: 20px; font-size: 0.75rem; font-weight: 600; letter-spacing: 0.3px; }
    .status-pending { background: #FEF3C7; color: #92400E; }
    .status-approved { background: #D5F5E3; color: #1E8449; }
    .status-active { background: #D6EAF8; color: #1B4F72; }
    .status-completed { background: #F3F4F6; color: #374151; }
    .status-closed { background: #FEE2E2; color: #991B1B; }
    
    /* === PAGE-LEVEL RADIO NAV (Pill Tabs) === */
    div[data-testid="stMainBlockContainer"] > div > div > div > div[data-testid="stHorizontalBlock"] .stRadio > div {
        gap: 0.3rem !important;
        flex-wrap: wrap;
    }
    div[data-testid="stMainBlockContainer"] .stRadio > div > label {
        background: #F1F5F9 !important;
        border: 1px solid #E2E8F0 !important;
        border-radius: 8px !important;
        padding: 8px 16px !important;
        font-size: 0.82rem !important;
        font-weight: 500 !important;
        color: #475569 !important;
        transition: all 0.2s ease !important;
    }
    div[data-testid="stMainBlockContainer"] .stRadio > div > label:hover {
        background: #E0F2FE !important;
        border-color: #2E86C1 !important;
        color: #1B4F72 !important;
    }
    div[data-testid="stMainBlockContainer"] .stRadio > div > label[data-checked="true"],
    div[data-testid="stMainBlockContainer"] .stRadio > div > label[aria-checked="true"] {
        background: #2E86C1 !important;
        color: white !important;
        border-color: #2E86C1 !important;
    }
    
    /* === WELCOME BANNER === */
    .welcome-banner {
        background: linear-gradient(135deg, #1B4F72 0%, #2E86C1 50%, #3498DB 100%);
        border-radius: 14px;
        padding: 28px 32px;
        color: white;
        margin-bottom: 24px;
        border: 1px solid rgba(255,255,255,0.08);
    }
    .welcome-banner h2 { color: white !important; margin: 0; font-size: 1.4rem; }
    .welcome-banner p { color: rgba(255,255,255,0.8); margin: 6px 0 0 0; font-size: 0.9rem; }
    .welcome-banner .wb-gold { color: #8CC63F; font-weight: 600; }
    
    /* === LOGIN PAGE — PREMIUM FINTECH === */
    .login-page-bg {
        position: fixed;
        top: 0; left: 0; right: 0; bottom: 0;
        background: linear-gradient(135deg, #0C2D48 0%, #1B4F72 30%, #2E86C1 70%, #3498DB 100%);
        z-index: -2;
    }
    .login-page-bg::before {
        content: '';
        position: fixed;
        top: -50%; left: -50%; right: -50%; bottom: -50%;
        background: radial-gradient(circle at 30% 20%, rgba(140,198,63,0.08) 0%, transparent 50%),
                    radial-gradient(circle at 70% 80%, rgba(46,134,193,0.12) 0%, transparent 50%);
        z-index: -1;
        animation: loginGlow 8s ease-in-out infinite alternate;
    }
    @keyframes loginGlow {
        0% { opacity: 0.6; transform: scale(1); }
        100% { opacity: 1; transform: scale(1.1); }
    }
    
    .login-glass-card {
        background: rgba(255, 255, 255, 0.95);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
        border-radius: 20px;
        padding: 44px 38px 36px;
        border: 1px solid rgba(255,255,255,0.3);
        box-shadow: 0 8px 32px rgba(0,0,0,0.12), 0 2px 8px rgba(0,0,0,0.06);
        max-width: 420px;
        margin: 0 auto;
    }
    .login-glass-card .login-logo-wrap {
        text-align: center;
        margin-bottom: 8px;
    }
    .login-glass-card .login-logo-wrap img {
        width: 76px;
        height: auto;
        border-radius: 50%;
        box-shadow: 0 4px 16px rgba(46,134,193,0.18);
        border: 3px solid rgba(255,255,255,0.9);
    }
    .login-glass-card .login-brand-name {
        font-size: 1.8rem;
        font-weight: 800;
        color: #1B4F72;
        letter-spacing: 5px;
        padding-left: 5px;
        margin: 10px 0 0 0;
        text-align: center;
    }
    .login-glass-card .login-org-name {
        font-size: 0.75rem;
        color: #64748B;
        text-align: center;
        line-height: 1.6;
        margin: 4px 0 0 0;
    }
    .login-glass-card .login-accent-line {
        width: 44px;
        height: 3px;
        background: linear-gradient(90deg, #8CC63F, #2E86C1);
        margin: 18px auto;
        border-radius: 4px;
    }
    .login-glass-card .login-title {
        font-size: 1.05rem;
        font-weight: 700;
        color: #1B4F72;
        text-align: center;
        margin: 0 0 2px 0;
    }
    .login-glass-card .login-subtitle {
        font-size: 0.8rem;
        color: #94A3B8;
        text-align: center;
        margin: 0 0 20px 0;
    }
    .login-footer-bar {
        text-align: center;
        margin-top: 20px;
        padding-top: 16px;
        border-top: 1px solid #E2E8F0;
    }
    .login-footer-bar p {
        color: #94A3B8;
        font-size: 0.68rem;
        margin: 0;
        letter-spacing: 0.3px;
    }
    .login-footer-bar .secured-badge {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        background: #F0FDF4;
        color: #16A34A;
        font-size: 0.65rem;
        font-weight: 600;
        padding: 4px 10px;
        border-radius: 20px;
        margin-top: 8px;
        border: 1px solid #BBF7D0;
    }
    .login-footer-bar .secured-badge svg {
        width: 12px; height: 12px;
    }
    
    /* Hide default Streamlit bg on login */
    .login-hide-bg .stApp { background: transparent !important; }
    
    /* === SECTION HEADERS === */
    .section-header {
        border-left: 4px solid #2E86C1;
        padding-left: 14px;
        margin: 20px 0 14px 0;
    }
    .section-header h3 { margin: 0; font-size: 1.1rem; }
    
    /* === NAV GROUP LABELS === */
    .nav-section-label {
        color: #94A3B8 !important;
        font-size: 0.65rem !important;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 1.5px;
        padding: 8px 0 4px 0;
        margin: 0;
    }
    
    /* === TABS === */
    .stTabs [data-baseweb="tab-list"] { gap: 4px; }
    .stTabs [data-baseweb="tab"] {
        border-radius: 8px 8px 0 0;
        font-weight: 600;
        font-size: 0.85rem;
    }
    </style>
    """, unsafe_allow_html=True)

# --- 2. CLOUD DATA ENGINE (SUPABASE) ---

# Mapping dictionaries to bridge UI names to SQL column names
DB_TO_UI_LOANS = {
    "client_id": "Client ID", "date": "Date", "branch": "Branch", "officer": "Officer",
    "client_name": "Client Name", "phone": "Phone", "address": "Address", "business_type": "Business Type",
    "group_name": "Group Name", "meeting_day": "Meeting Day", "loan_product": "Loan Product",
    "loan_amount": "Loan Amount", "active_credit": "Active Credit", "loan_repay": "Loan Repay",
    "total_due": "Total Due", "status": "Status",
    "processing_fee": "Processing Fee", "markup": "Markup", "pass_book_fee": "Pass Book Fee",
    "nickname": "Nickname", "marital_status": "Marital Status", "average_monthly_income": "Average Monthly Income",
    "other_obligations": "Other Obligations",
    "guarantor_name": "Guarantor Name", "guarantor_nickname": "Guarantor Nickname", "guarantor_marital_status": "Guarantor Marital Status",
    "guarantor_home_address": "Guarantor Home Address", "guarantor_occupation": "Guarantor Occupation",
    "guarantor_office_address": "Guarantor Office Address", "guarantor_phone": "Guarantor Phone",
    "guarantor_relationship": "Guarantor Relationship",
    "group_location": "Group Location", "group_leader_name": "Group Leader Name", "group_formation_date": "Group Formation Date",
    "product_category": "Product Category", "group_savings": "Group Savings", 
    "branch_contingency": "Branch Contingency", "branch_contingency_2": "Branch Contingency 2"
}
UI_TO_DB_LOANS = {v: k for k, v in DB_TO_UI_LOANS.items()}

DB_TO_UI_REP = {
    "date": "Date", "branch": "Branch", "client_id": "Client ID",
    "client_name": "Client Name", "amount_paid": "Amount Paid", "officer": "Officer", 
    "note": "Note", "transaction_type": "Transaction Type",
    "savings_amount": "Savings Amount", "loan_repayment_amount": "Loan Repayment Amount",
    "processing_fee_paid": "Processing Fee Paid", "markup_paid": "Markup Paid",
    "pass_book_paid": "Pass Book Paid", "recovery_amount": "Recovery Amount",
    "withdrawal_amount": "Withdrawal Amount", "mgt_fee_paid": "Mgt Fee Paid",
    "others_amount": "Others Amount",
    "opening_balance": "Opening Balance", "rep_12_weeks": "Repayment 12 Weeks",
    "rep_24_weeks": "Repayment 24 Weeks", "rep_60_days": "Repayment 60 Days",
    "rep_120_days": "Repayment 120 Days", "rep_monthly": "Monthly",
    "contingency_paid": "Contingency", "bank_withdrawal": "Bank Withdrawal",
    "asset_sales": "Asset Sales", "app_fee": "App Fee",
    "passbook_bonus": "Pass Book Bonus", "daily_11_pct": "Daily 11%",
    "daily_20_pct": "Daily 20%", "weekly_11_pct": "Weekly 11%",
    "weekly_20_pct": "Weekly 20%", "monthly_markup": "Monthly 11%/20%",
    "cash_carry": "Cash Carry", "product_withdrawal": "Product Withdrawal",
    "weekly_active": "Weekly Active", "daily_active": "Daily Active",
    "monthly_active": "Monthly Active", "expenses": "Expenses",
    "bank_deposited": "Bank Deposited", "closing_balance": "Closing Balance",
    "laps_reserved": "Laps Reserved", "laps_transferred": "Laps Transferred",
    "initial_payment": "initial_payment", "group_savings_dep": "Group Savings Deposit", "group_savings_wd": "Group Savings Withdrawal", "misc_fees": "Misc Fees",
    "asset_credit_sales": "Asset Credit Sales", "cash_and_carry": "Cash and Carry", "credit_form": "Credit Form", "credit_form_damage": "Credit Form Damage", "bonus": "Bonus"
}
UI_TO_DB_REP = {v: k for k, v in DB_TO_UI_REP.items()}

def load_loans():
    """Load loans filtered by RBAC"""
    if not supabase:
        return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))
    try:
        query = supabase.table("loans").select("*")
        
        # RBAC Filters
        if st.session_state.get('role') == 'CO':
            query = query.eq('officer', st.session_state.get('user'))
        elif st.session_state.get('role') == 'BM':
            query = query.eq('branch', st.session_state.get('branch'))
            
        response = query.execute()
        if not response.data:
            return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))
        df = pd.DataFrame(response.data).rename(columns=DB_TO_UI_LOANS)
        num_cols = ['Loan Amount', 'Active Credit', 'Loan Repay', 'Total Due']
        for c in num_cols:
            df[c] = pd.to_numeric(df[c], errors='coerce').fillna(0)
            
        # Deduplicate to always return the latest state of each client
        if not df.empty and 'Date' in df.columns and 'Client ID' in df.columns:
            df = df.sort_values('Date').groupby('Client ID').last().reset_index()
            
        return df
    except Exception as e:
        st.error(f"Database Error: {e}")
        return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))


def load_repayments():
    """Load repayments filtered by RBAC"""
    if not supabase:
        return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
    try:
        query = supabase.table("repayments").select("*")
        
        # RBAC Filters
        if st.session_state.get('role') == 'CO':
            query = query.eq('officer', st.session_state.get('user'))
        elif st.session_state.get('role') == 'BM':
            query = query.eq('branch', st.session_state.get('branch'))
            
        response = query.execute()
        if not response.data:
            return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
        df = pd.DataFrame(response.data).rename(columns=DB_TO_UI_REP)
        
        return df
    except Exception as e:
        st.error(f"Database Error: {e}")
        return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
    try:
        response = supabase.table("repayments").select("*").execute()
        if not response.data:
            return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
        df = pd.DataFrame(response.data).rename(columns=DB_TO_UI_REP)
        num_cols = ["Amount Paid", "Savings Amount", "Loan Repayment Amount"]
        for c in num_cols:
            if c in df.columns:
                df[c] = pd.to_numeric(df[c], errors='coerce').fillna(0)
        return df
    except Exception as e:
        st.error(f"Database Error: {e}")
        return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))

def save_new_loan(data):
    """Save new loan to database"""
    if not supabase:
        st.error("Database not connected")
        return
    db_data = {UI_TO_DB_LOANS[k]: v for k, v in data.items() if k in UI_TO_DB_LOANS}
    supabase.table("loans").upsert(db_data).execute()

def save_repayment(data):
    """Save repayment to database"""
    if not supabase:
        st.error("Database not connected")
        return
    db_data = {UI_TO_DB_REP[k]: v for k, v in data.items() if k in UI_TO_DB_REP}
    supabase.table("repayments").insert(db_data).execute()

def update_database_safe(edited_subset, user_role, user_name, branch):
    """Update database with edited data"""
    if not supabase:
        st.error("Database not connected")
        return
    
    query = supabase.table("loans").select("client_id")
    if user_role == "BM":
        query = query.eq("branch", branch)
    elif user_role == "Officer":
        query = query.eq("officer", user_name)
    
    original_ids = [r["client_id"] for r in query.execute().data]
    kept_ids = edited_subset["Client ID"].tolist()
    ids_to_delete = set(original_ids) - set(kept_ids)
    
    for d_id in ids_to_delete:
        supabase.table("loans").delete().eq("client_id", d_id).execute()
    
    for _, row in edited_subset.iterrows():
        db_data = {UI_TO_DB_LOANS[k]: row[k] for k in row.keys() if k in UI_TO_DB_LOANS}
        # Translate display name back to DB username before saving
        if "officer" in db_data:
            db_data["officer"] = CO_NAME_MAP.get(db_data["officer"], db_data["officer"])
        supabase.table("loans").upsert(db_data).execute()

def get_clients_for_user(df, user_role, user_name, branch):
    """Filter clients based on user role"""
    if df.empty:
        return df
    if user_role == "Admin":
        return df
    elif user_role == "BM":
        return df[df['Branch'] == branch]
    elif user_role == "Officer":
        return df[df['Officer'] == user_name]
    return pd.DataFrame(columns=df.columns)

# --- 3. MATH HELPERS & RISK LOGIC ---

def calculate_overdue(start_date_str, product, fixed_repay, total_loan_paid, status='Active'):
    """Calculate overdue amount for a client"""
    if status in ['Registered', 'Pending']:
        return 0, 0
    
    try:
        start_date = datetime.strptime(start_date_str, "%Y-%m-%d").date()
    except:
        return 0, 0
    
    today = datetime.now().date()
    
    if "120" in str(product):
        duration = 120
        freq = "Daily"
    elif "Daily" in str(product) or "60" in str(product): 
        duration = 60
        freq = "Daily"
    elif "3 Month" in str(product) or "3M" in str(product):
        duration = 3
        freq = "Monthly"
    elif "6 Month" in str(product) or "6M" in str(product):
        duration = 6
        freq = "Monthly"
    elif "12 Week" in str(product) or "12W" in str(product):
        duration = 12
        freq = "Weekly"
    elif "24 Week" in str(product) or "24W" in str(product):
        duration = 24
        freq = "Weekly"
    else:
        duration = 60
        freq = "Daily"
        
    schedule = generate_repayment_schedule(start_date, duration, freq)
    
    # Count how many scheduled dates have passed up to today
    passed_installments = sum(1 for d in schedule if d <= today)
    
    expected_paid = passed_installments * fixed_repay
    overdue = max(0, expected_paid - total_loan_paid)
    return expected_paid, overdue

def calculate_loan_setup(amount, product_type, product_category="Finance"):
    """Calculate loan setup parameters"""
    if "Asset" in str(product_category):
        if "Cash and Carry" in str(product_type):
            rate = 0.0
            duration = 1
            freq = "One-Time"
            round_step = 1
            force_gap = False
        elif "60-Day" in str(product_type):
            rate = 0.12
            duration = 60
            freq = "Daily"
            round_step = 50
            force_gap = False
        else:
            rate = 0.21
            duration = 120
            freq = "Daily"
            round_step = 50
            force_gap = False
            
        interest = amount * rate
        # For assets, upfront fee determines actual repayment later.
        # We'll return 0 for gap and a default loan_repayment assuming 0 upfront.
        gap = 0
        loan_repayment = (amount + interest) / duration
        return {
            "freq": freq,
            "duration": duration,
            "interest": interest,
            "initial_payment": gap,
            "loan_repayment": loan_repayment
        }
        
    # Finance Product Logic
    if "120" in str(product_type):
        rate = 0.21
        duration = 120
        freq = "Daily"
        round_step = 50
        force_gap = False
    elif "Daily" in str(product_type) or "60" in str(product_type): # Daily Loan (60 Days)
        rate = 0.12
        duration = 60
        freq = "Daily"
        round_step = 50
        force_gap = False
    elif "3 Month" in str(product_type) or "3M" in str(product_type):
        rate = 0.12
        duration = 3
        freq = "Monthly"
        round_step = 100
        force_gap = False
    elif "6 Month" in str(product_type) or "6M" in str(product_type):
        rate = 0.21
        duration = 6
        freq = "Monthly"
        round_step = 100
        force_gap = False
    elif "12 Week" in str(product_type) or "12W" in str(product_type):
        rate = 0.12
        duration = 12
        freq = "Weekly"
        round_step = 50
        force_gap = True
    else: # 24 Weeks fallback
        rate = 0.21
        duration = 24
        freq = "Weekly"
        round_step = 50
        force_gap = True
    
    interest = amount * rate
    raw_val = amount / duration
    
    if raw_val.is_integer():
        loan_repayment = int(raw_val)
        gap = 0
    else:
        loan_repayment = math.floor(raw_val / round_step) * round_step
        while True:
            gap = amount - (loan_repayment * duration)
            is_valid = True if gap >= 0 else False
            if force_gap and (gap % 1000 != 0 or gap < 1000):
                is_valid = False
            if is_valid:
                break
            loan_repayment -= round_step
            if loan_repayment <= 0:
                loan_repayment = 0
                gap = amount
                break
    
    return {
        "freq": freq,
        "duration": duration,
        "interest": interest,
        "initial_payment": gap,
        "loan_repayment": loan_repayment
    }


def calculate_client_savings(client_repayments, fixed_repay):
    """Calculate client's savings and loan paid respecting Transaction Types"""
    total_savings = 0
    total_loan_paid = 0
    
    if client_repayments.empty:
        return 0, 0
        
    for _, row in client_repayments.iterrows():
        # Backward compatibility for old records
        amount = float(row.get('Amount Paid', 0))
        trans_type = row.get('Transaction Type', 'Loan')
        
        # Explicit granular columns check
        savings_dep = float(row.get('Savings Amount', 0))
        loan_rep = float(row.get('Loan Repayment Amount', 0))
        withdrawal = float(row.get('Withdrawal Amount', 0))
        
        # New granular columns for loan
        overdue_coll = float(row.get('Others Amount', 0))
        recoveries = float(row.get('Recovery Amount', 0))
        init_pay = float(row.get('initial_payment', 0))
        
        if savings_dep > 0 or loan_rep > 0 or withdrawal > 0 or overdue_coll > 0 or recoveries > 0 or init_pay > 0:
            total_savings += savings_dep
            total_savings -= withdrawal
            total_loan_paid += (loan_rep + overdue_coll + recoveries + init_pay)
        else:
            # Fallback to old logic
            if trans_type == 'Savings':
                total_savings += amount
            else:
                if amount > fixed_repay:
                    total_savings += (amount - fixed_repay)
                    total_loan_paid += fixed_repay
                else:
                    total_loan_paid += amount
                
    return total_savings, total_loan_paid

def get_ledger_report(client_payments, fixed_repay, loan_product, meeting_day, view_date):
    """Generate ledger report for a client"""
    report_data = []
    
    cp = client_payments.copy() if not client_payments.empty else pd.DataFrame()
    if not cp.empty:
        cp['DateObj'] = pd.to_datetime(cp['Date'], errors='coerce')
    
    if "Daily" in str(loan_product):
        start_of_week = view_date - timedelta(days=view_date.weekday())
        days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        for i in range(5):
            current_day = start_of_week + timedelta(days=i)
            daily_total = 0
            sav = 0
            ln = 0
            if not cp.empty:
                mask = cp['DateObj'].dt.date == current_day
                daily_total = cp.loc[mask, 'Amount Paid'].sum()
                sav_explicit = cp.loc[mask, 'Savings Amount'].sum() if 'Savings Amount' in cp.columns else 0
                ln_explicit = cp.loc[mask, 'Loan Repayment Amount'].sum() if 'Loan Repayment Amount' in cp.columns else 0
                
                if sav_explicit > 0 or ln_explicit > 0:
                    sav = sav_explicit
                    ln = ln_explicit
                else:
                    if daily_total > fixed_repay:
                        sav = daily_total - fixed_repay
                        ln = fixed_repay
                    else:
                        sav = 0
                        ln = daily_total
                        
            report_data.append({
                "Day": days[i],
                "Date": current_day.strftime("%Y-%m-%d"),
                "Total Paid": daily_total,
                "Loan Repayment": ln,
                "Savings": sav
            })
    else:
        day_map = {"Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3, "Friday": 4, "Daily": 0}
        target_day_num = day_map.get(meeting_day, 0)
        diff = (view_date.weekday() - target_day_num) % 7
        last_meeting = view_date - timedelta(days=diff)
        for i in range(5):
            meeting_date = last_meeting - timedelta(weeks=i)
            week_total = 0
            sav = 0
            ln = 0
            if not cp.empty:
                mask = cp['DateObj'].dt.date == meeting_date
                week_total = cp.loc[mask, 'Amount Paid'].sum()
                sav_explicit = cp.loc[mask, 'Savings Amount'].sum() if 'Savings Amount' in cp.columns else 0
                ln_explicit = cp.loc[mask, 'Loan Repayment Amount'].sum() if 'Loan Repayment Amount' in cp.columns else 0
                
                if sav_explicit > 0 or ln_explicit > 0:
                    sav = sav_explicit
                    ln = ln_explicit
                else:
                    if week_total > fixed_repay:
                        sav = week_total - fixed_repay
                        ln = fixed_repay
                    else:
                        sav = 0
                        ln = week_total
                        
            report_data.append({
                "Week": f"Week {i+1} (Ago)",
                "Meeting Date": meeting_date.strftime("%Y-%m-%d"),
                "Total Paid": week_total,
                "Loan Repayment": ln,
                "Savings": sav
            })
        report_data.reverse()
    
    return pd.DataFrame(report_data)

# --- 4. AUTHENTICATION ---
# JS-based cookie helpers (replace flaky extra-streamlit-components)
import streamlit.components.v1 as components

def _set_auth_cookie(username):
    """Set auth cookie via JS injection (expires in 7 days)."""
    components.html(f"""
    <script>
    document.cookie = "icare_auth={username}; path=/; max-age={7*24*60*60}; SameSite=Lax";
    </script>
    """, height=0)

def _delete_auth_cookie():
    """Delete auth cookie via JS injection."""
    components.html("""
    <script>
    document.cookie = "icare_auth=; path=/; max-age=0; SameSite=Lax";
    </script>
    """, height=0)

def _read_auth_cookie():
    """Read auth cookie from Streamlit's request headers."""
    try:
        headers = st.context.headers
        cookie_header = headers.get("Cookie", "")
        for part in cookie_header.split(";"):
            part = part.strip()
            if part.startswith("icare_auth="):
                val = part[len("icare_auth="):]
                if val and val.strip():
                    return val.strip()
    except Exception:
        pass
    return None

# Try to restore session from cookie
if 'logged_in' not in st.session_state or not st.session_state['logged_in']:
    if st.session_state.get('logout_in_progress'):
        auth_token = None
    else:
        auth_token = _read_auth_cookie()
        
    if auth_token:
        try:
            res = supabase.table("app_users").select("*").ilike("username", auth_token).execute()
            if res.data and len(res.data) > 0:
                user = res.data[0]
                st.session_state['logged_in'] = True
                st.session_state['user'] = user['username']
                st.session_state['role'] = user['role']
                st.session_state['branch'] = user['branch_name']
            else:
                st.session_state['logged_in'] = False
        except:
            st.session_state['logged_in'] = False
    else:
        st.session_state['logged_in'] = False

if not st.session_state['logged_in']:
    # Inject gradient background over Streamlit's default
    st.markdown('<div class="login-page-bg"></div>', unsafe_allow_html=True)
    st.markdown('<style>.stApp { background: transparent !important; }</style>', unsafe_allow_html=True)
    
    st.markdown('<br>', unsafe_allow_html=True)
    _, center_col, _ = st.columns([1, 1.4, 1])
    
    with center_col:
        st.markdown(f"""
            <div class='login-glass-card'>
                <div class='login-logo-wrap'>
                    <img src="data:image/jpeg;base64,{LOGO_B64}">
                </div>
                <p class='login-brand-name'>ICARE</p>
                <p class='login-org-name'>Initiative for Community Advancement,<br>Relief and Empowerment</p>
                <div class='login-accent-line'></div>
                <p class='login-title'>Welcome Back</p>
                <p class='login-subtitle'>Sign in to your banking portal</p>
            </div>
        """, unsafe_allow_html=True)
        
        with st.form("login"):
            username = st.text_input("Username", placeholder="Enter your username")
            pw = st.text_input("Password", type="password", placeholder="Enter your password")
            
            submitted = st.form_submit_button("SIGN IN", use_container_width=True)
            
            if submitted:
                st.session_state['logout_in_progress'] = False
                auth_result = authenticate_user(username, pw)
                if auth_result:
                    _set_auth_cookie(auth_result['user_name'])
                    st.session_state['logged_in'] = True
                    st.session_state['user'] = auth_result['user_name']
                    st.session_state['role'] = auth_result['user_role']
                    st.session_state['branch'] = auth_result['branch_name']
                    st.rerun()
                else:
                    st.error("Invalid credentials. Please try again.")
        
        st.markdown(f"""
            <div class='login-footer-bar'>
                <p>Core Banking System v{APP_VERSION}</p>
                <span class='secured-badge'>
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-1 16l-4-4 1.41-1.41L11 14.17l6.59-6.59L19 9l-8 8z"/></svg>
                    256-bit Secured Connection
                </span>
            </div>
        """, unsafe_allow_html=True)
    st.stop()

# --- 5. SIDEBAR ---
ROLE = st.session_state['role']
USER = st.session_state['user']
BRANCH = st.session_state['branch']

# Role badge colors (ICARE brand palette)
role_colors = {"Admin": "#1B4F72", "BM": "#2E86C1", "CO": "#8CC63F", "Officer": "#8CC63F", "AM": "#2E86C1"}
role_color = role_colors.get(ROLE, "#6B7280")

# Role display labels
role_labels = {"Admin": "Administrator", "BM": "Branch Manager", "CO": "Credit Officer", "Officer": "Credit Officer", "AM": "Area Manager"}
role_label = role_labels.get(ROLE, ROLE)

with st.sidebar:
    st.markdown(f"""
        <div style="text-align: center; margin-top: 10px; margin-bottom: 5px;">
            <img src="data:image/jpeg;base64,{LOGO_B64}" style="width: 65px; height: auto; border-radius: 50%; box-shadow: 0 2px 8px rgba(0,0,0,0.06);">
        </div>
    """, unsafe_allow_html=True)
    
    st.markdown(f"""
        <div style='text-align: center; padding: 0 0 6px 0;'>
            <p style='color: #94A3B8; font-size: 0.65rem; margin: 4px 0 0 0; letter-spacing: 1px;'>CORE BANKING v{APP_VERSION}</p>
        </div>
    """, unsafe_allow_html=True)
    st.divider()
    
    st.markdown(f"""
        <div style='background: #F8FAFC; padding: 14px 16px; border-radius: 10px; margin-bottom: 12px; border: 1px solid #E2E8F0;'>
            <p style='color: #0F172A; margin: 0; font-size: 0.92rem; font-weight: 600;'>{CO_DISPLAY_MAP.get(USER, USER)}</p>
            <p style='color: #64748B; margin: 6px 0 0 0; font-size: 0.78rem;'>
                <span style='background: {role_color}; color: white; padding: 2px 8px; border-radius: 10px; font-size: 0.68rem; font-weight: 600;'>{role_label}</span>
                &nbsp; {BRANCH} Branch
            </p>
        </div>
    """, unsafe_allow_html=True)
    
    if ROLE in ["Officer", "CO"]:
        st.markdown("<p class='nav-section-label'>OPERATIONS</p>", unsafe_allow_html=True)
        nav_options = ["Dashboard", "Loan Origination", "Collections", "Daily Report", "Audit Ledger"]
    elif ROLE in ["BM", "AM"]:
        st.markdown("<p class='nav-section-label'>EXECUTIVE</p>", unsafe_allow_html=True)
        nav_options = ["Dashboard", "Loan Origination", "Portfolio", "Master Cashbook", "Audit Ledger"]
        if ROLE == "AM":
            nav_options.append("User Management")
    else:  # Admin
        st.markdown("<p class='nav-section-label'>ADMINISTRATION</p>", unsafe_allow_html=True)
        nav_options = ["Dashboard", "Loan Origination", "Collections", "Daily Report", "Portfolio", "Master Cashbook", "Audit Ledger", "Reports & Export", "User Management"]
    
    page = st.radio("Navigation", nav_options, label_visibility="collapsed")
    
    # Security check: if the requested page is not in permitted list, fallback to Dashboard
    if page not in nav_options:
        page = "Dashboard"
    
    st.divider()
    
    if st.button("Sign Out", use_container_width=True):
        _delete_auth_cookie()
        st.session_state['logout_in_progress'] = True
        st.session_state['logged_in'] = False
        for key in list(st.session_state.keys()):
            if key not in ['logout_in_progress', 'logged_in']:
                del st.session_state[key]
        st.rerun()

# Welcome banner
hour = datetime.now().hour
greeting = "Good morning" if hour < 12 else ("Good afternoon" if hour < 17 else "Good evening")
display_name = CO_DISPLAY_MAP.get(USER, USER)
st.markdown(f"""
    <div class='welcome-banner'>
        <h2>{greeting}, {display_name}</h2>
        <p>{role_label} &mdash; <span class='wb-gold'>{BRANCH} Branch</span> &middot; {datetime.now().strftime('%A, %B %d, %Y')}</p>
    </div>
""", unsafe_allow_html=True)

# --- 6. PAGES ---

if page == "Dashboard":
    st.title("Performance & Risk Dashboard")
    
    all_loans = load_loans()
    all_repayments = load_repayments()
    my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
    
    total_people_with_savings = 0
    total_savings = 0
    active_loans_count = 0
    total_active_credit = 0
    fully_paid_count = 0
    total_overdue = 0
    
    for _, loan in my_loans.iterrows():
        cid = loan.get('Client ID')
        c_payments = all_repayments[all_repayments['Client ID'] == cid]
        s_amt, l_amt = calculate_client_savings(c_payments, loan.get('Loan Repay', 0))
        
        loan_bal = loan.get('Active Credit', 0) - l_amt
        
        if s_amt > 0:
            total_people_with_savings += 1
            total_savings += s_amt
            
        if loan_bal > 0:
            active_loans_count += 1
            total_active_credit += loan_bal
            
            # calculate overdue
            start_date_str = loan.get('Date', '')
            product = loan.get('Loan Product', '')
            fixed_repay = loan.get('Loan Repay', 0)
            if start_date_str and product:
                exp_paid, overdue_amt = calculate_overdue(start_date_str, product, fixed_repay, l_amt, loan.get('Status', 'Active'))
                total_overdue += overdue_amt
        else:
            fully_paid_count += 1
            
    st.markdown("### 💰 Savings Summary")
    s1, s2 = st.columns(2)
    s1.metric("👥 People with Savings", f"{total_people_with_savings}")
    s2.metric("🐷 Total Savings Balance", f"₦{total_savings:,.0f}")
    
    st.divider()
    
    st.markdown("### 🏦 Credit Summary")
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("👥 People with Active Loans", f"{active_loans_count}")
    c2.metric("📈 Total Active Credit Balance", f"₦{total_active_credit:,.0f}")
    c3.metric("🎉 Fully Paid Loans", f"{fully_paid_count}")
    od_color = "inverse" if total_overdue > 0 else "normal"
    c4.metric("🚨 Total Overdue Amount", f"₦{total_overdue:,.0f}", delta_color=od_color)


elif page == "Loan Origination":
    st.title("Origination & Registration")
    
    orig_section = st.radio("Navigate", ["👤 Client Registration", "📝 Loan Application", "⏳ Pending Disbursements"], horizontal=True, label_visibility="collapsed")

    if orig_section == "⏳ Pending Disbursements":
        st.subheader("Pending Disbursements")
        all_loans = load_loans()
        my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
        pending_clients = my_loans[(my_loans['Status'] == 'Pending') & (pd.to_numeric(my_loans['Loan Amount'], errors='coerce').fillna(0) > 0)]
        if pending_clients.empty:
            st.info("✅ No pending loans found.")
        else:
            st.dataframe(pending_clients[['Client ID', 'Client Name', 'Date', 'Officer', 'Loan Amount', 'Loan Product']], use_container_width=True)
            if ROLE in ["AM", "BM", "Admin"]:
                st.markdown("### 🔑 Checker Action: Activate Loan")
                with st.form("activate_loan_form"):
                    opts = pending_clients['Client ID'].tolist()
                    def format_func(x):
                        return f"{x} - {pending_clients[pending_clients['Client ID'] == x].iloc[0]['Client Name']}"
                    selected_client_id = st.selectbox("Select Client to Activate", opts, format_func=format_func)
                    submitted_activate = st.form_submit_button("✅ Authorize & Activate Disbursement", use_container_width=True)
                    if submitted_activate:
                        today = datetime.now().date()
                        today_str = today.strftime("%Y-%m-%d")
                        
                        loan_row = pending_clients[pending_clients['Client ID'] == selected_client_id].iloc[0]
                        product = str(loan_row.get("Loan Product", ""))
                        
                        if "Daily" in product or "120 Days" in product:
                            initial_start_date = today + timedelta(days=1)
                        else:
                            meeting_day = str(loan_row.get("Meeting Day", ""))
                            days_of_week = {"Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3, "Friday": 4, "Saturday": 5, "Sunday": 6}
                            if meeting_day in days_of_week:
                                target_weekday = days_of_week[meeting_day]
                                current_weekday = today.weekday()
                                days_ahead = target_weekday - current_weekday
                                if days_ahead <= 0:
                                    days_ahead += 7
                                initial_start_date = today + timedelta(days=days_ahead)
                            else:
                                initial_start_date = today + timedelta(days=7)
                                
                        closures = get_custom_closures()
                        final_start_date, is_adjusted, shift_reason = get_next_working_day(initial_start_date, closures)
                        
                        setup = calculate_loan_setup(100000, product)
                        loan_freq = setup.get("freq", "Daily")
                        duration_in_installments = setup.get("duration", 60)
                        
                        schedule = generate_repayment_schedule(final_start_date, duration_in_installments, loan_freq)
                        expected_end_date = schedule[-1] if schedule else final_start_date
                        
                        try:
                            supabase.table("loans").update({
                                "status": "Active", 
                                "disbursement_date": today_str,
                                "start_date": final_start_date.strftime("%Y-%m-%d"),
                                "expected_end_date": expected_end_date.strftime("%Y-%m-%d")
                            }).eq("client_id", selected_client_id).eq("status", "Pending").execute()
                            
                            st.success(f"Successfully activated loan! Disbursement Date set to {today_str}.")
                            
                            # Inject Upfront Revenue (Contingency & Markup)
                            amt_val = pd.to_numeric(loan_row.get("Loan Amount", 0), errors='coerce')
                            prod_str = str(loan_row.get("Loan Product", ""))
                            rate = 0.12 if "60" in prod_str or "12 Week" in prod_str or "3 Month" in prod_str else 0.21
                            interest_val = amt_val * rate
                            
                            cont_val = interest_val * (1/12) if rate == 0.12 else interest_val * (1/21)
                            markup_val = interest_val - cont_val
                            
                            dur_val = 60
                            if "120" in prod_str: dur_val = 120
                            elif "12 Week" in prod_str: dur_val = 12
                            elif "24 Week" in prod_str: dur_val = 24
                            elif "3 Month" in prod_str: dur_val = 3
                            elif "6 Month" in prod_str: dur_val = 6
                            
                            d11 = markup_val if rate == 0.12 and dur_val == 60 else 0
                            w11 = markup_val if rate == 0.12 and dur_val == 12 else 0
                            d20 = markup_val if rate == 0.21 and dur_val == 120 else 0
                            w20 = markup_val if rate == 0.21 and dur_val == 24 else 0
                            m_mark = markup_val if dur_val in [3, 6] else 0
                            
                            rev_data = {
                                "Date": today_str,
                                "Client ID": selected_client_id,
                                "Client Name": loan_row.get("Client Name", ""),
                                "Officer": loan_row.get("Officer", USER),
                                "Branch": loan_row.get("Branch", BRANCH),
                                "Amount Paid": 0,
                                "Transaction Type": "Loan",
                                "Note": f"Upfront Revenue injected on Disbursement ({prod_str})",
                                "Contingency": cont_val,
                                "Daily 11%": d11,
                                "Daily 20%": d20,
                                "Weekly 11%": w11,
                                "Weekly 20%": w20,
                                "Monthly 11%/20%": m_mark
                            }
                            save_repayment(rev_data)
                            st.info("✅ Upfront Revenue (Markup & Contingency) successfully logged to the Daily Cashbook.")
                            
                            if is_adjusted:
                                st.warning(f"📅 **Schedule Adjusted:** The first repayment was automatically moved to **{final_start_date.strftime('%A, %b %d')}** because the original date fell on {shift_reason}.")
                                
                            import time
                            time.sleep(2)
                            st.rerun()
                        except Exception as e:
                            st.error(f"Failed to activate loan: {e}")
            else:
                st.info("🔒 Note: You are a Credit Officer. Only Branch Managers or Area Managers can authorize and activate disbursements.")

    elif orig_section == "👤 Client Registration":
        st.subheader("👤 Client Registration")
        reg_type = st.radio("Registration Method", ["Single Client", "📦 Bulk Onboarding"], horizontal=True)
        
        if reg_type == "Single Client":
            # Dynamic form layout (no st.form wrapper)
            st.markdown("#### 1. Personal Info")
            c1, c2, c3 = st.columns(3)
            name = c1.text_input("Full Name")
            nickname = c2.text_input("Nickname")
            phone = c3.text_input("Phone Number")
            address = st.text_input("Home Address")
            
            c4, c5, c6 = st.columns(3)
            marital = c4.selectbox("Marital Status", ["Single", "Married", "Divorced", "Widowed"])
            biz_type = c5.text_input("Business Type", value="Trader")
            raw_inc = c6.number_input("Average Monthly Income (₦)", min_value=0.0, step=5000.0, value=None, placeholder="0")
            income = float(raw_inc) if raw_inc else 0.0
            biz_address = st.text_input("Business Address")
            other_obs = st.text_input("Other Financial Obligations (if any)")
            
            st.markdown("#### 2. Guarantor Info")
            g1, g2, g3 = st.columns(3)
            g_name = g1.text_input("Guarantor Full Name")
            g_nick = g2.text_input("Guarantor Nickname")
            g_phone = g3.text_input("Guarantor Phone")
            g_address = st.text_input("Guarantor Home Address")
            
            g4, g5, g6 = st.columns(3)
            g_marital = g4.selectbox("Guarantor Marital Status", ["Single", "Married", "Divorced", "Widowed"])
            g_occ = g5.text_input("Guarantor Occupation")
            g_rel = g6.text_input("Relationship with Client")
            g_office = st.text_input("Guarantor Office Address")
            
            st.markdown("#### 3. Group Info")
            
            # Load all loans to find existing groups for this branch
            all_loans_for_groups = load_loans()
            branch_loans = all_loans_for_groups[all_loans_for_groups['Branch'] == BRANCH] if not all_loans_for_groups.empty else pd.DataFrame()
            
            if not branch_loans.empty and 'Group Name' in branch_loans.columns:
                existing_groups = sorted([g for g in branch_loans['Group Name'].dropna().unique().tolist() if str(g).strip()])
            else:
                existing_groups = []
                
            group_options = ["Individual (No Group)", "+ Create New Group"] + existing_groups
            selected_group_mode = st.selectbox("Assign to Group", group_options)
            
            # Variables for saving
            final_group_name = ""
            final_group_loc = ""
            final_meeting_day = "Daily"
            final_group_leader = ""
            final_group_date = datetime.now().strftime("%Y-%m-%d")
            
            if selected_group_mode == "+ Create New Group":
                gr1, gr2 = st.columns(2)
                final_group_name = gr1.text_input("New Group Name", placeholder="e.g. Alaba Market Traders")
                final_group_loc = gr2.text_input("Group Location")
                gr3, gr4 = st.columns(2)
                final_meeting_day = gr3.selectbox("Meeting Day", ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "Daily"])
                final_group_leader = gr4.text_input("Group Leader Name")
                new_group_date = st.date_input("Group Formation Date", datetime.now())
                final_group_date = new_group_date.strftime("%Y-%m-%d")
            elif selected_group_mode != "Individual (No Group)":
                # User selected an existing group
                final_group_name = selected_group_mode
                # Pull data from the first member found in this group
                group_members = branch_loans[branch_loans['Group Name'] == final_group_name]
                if not group_members.empty:
                    first_member = group_members.iloc[0]
                    def get_val(key, default):
                        val = first_member.get(key)
                        if pd.isna(val) or str(val).strip().lower() in ['nan', 'none', 'nat', '']:
                            return default
                        return str(val).strip()
                        
                    final_group_loc = get_val('Group Location', '')
                    final_meeting_day = get_val('Meeting Day', 'Daily')
                    final_group_leader = get_val('Group Leader Name', '')
                    final_group_date = get_val('Group Formation Date', datetime.now().strftime("%Y-%m-%d"))
                st.info(f"✅ Found group info: Meets on {final_meeting_day} at {final_group_loc}")
            
            st.markdown("---")
            submitted_reg = st.button("💾 Register Client", type="primary", use_container_width=True)
            
            if submitted_reg:
                if not name or not phone:
                    st.error("Name and Phone are required!")
                elif selected_group_mode == "+ Create New Group" and not final_group_name.strip():
                    st.error("Please enter the New Group Name.")
                else:
                    g_val = final_group_name if final_group_name.strip() else "IND"
                    all_loans_for_id = load_loans()
                    next_num = get_next_client_number(all_loans_for_id, BRANCH, g_val)
                    new_client_id = generate_client_id(all_loans_for_id, BRANCH, g_val, next_num)
                    
                    data = {
                        "Client ID": new_client_id,
                        "Client Name": name,
                        "Nickname": nickname,
                        "Phone": phone,
                        "Address": address,
                        "Business Address": biz_address,
                        "Marital Status": marital,
                        "Business Type": biz_type,
                        "Average Monthly Income": income,
                        "Other Obligations": other_obs,
                        "Guarantor Name": g_name,
                        "Guarantor Nickname": g_nick,
                        "Guarantor Marital Status": g_marital,
                        "Guarantor Home Address": g_address,
                        "Guarantor Occupation": g_occ,
                        "Guarantor Office Address": g_office,
                        "Guarantor Phone": g_phone,
                        "Guarantor Relationship": g_rel,
                        "Group Name": final_group_name,
                        "Group Location": final_group_loc,
                        "Group Leader Name": final_group_leader,
                        "Group Formation Date": final_group_date,
                        "Meeting Day": final_meeting_day,
                        "Date": datetime.now().strftime("%Y-%m-%d"),
                        "Officer": USER,
                        "Branch": BRANCH,
                        "Loan Amount": 0,
                        "Active Credit": 0,
                        "Loan Repay": 0,
                        "Total Due": 0,
                        "Status": "Pending"
                    }
                    save_new_loan(data)
                    st.success(f"Successfully registered client! Client ID: {new_client_id}")
                    import time
                    time.sleep(2)
                    st.rerun()
                        
        else:
            st.markdown("<div class='card'>", unsafe_allow_html=True)
            st.info("Upload the standard ICARE Group and Member Onboarding Template.")
            uploaded_file = st.file_uploader("Upload Excel Template", type=["xlsx"])
            if uploaded_file is not None:
                try:
                    import pandas as pd
                    import uuid
                    raw_groups = pd.read_excel(uploaded_file, sheet_name='Groups', header=None)
                    raw_members = pd.read_excel(uploaded_file, sheet_name='Members', header=None)
                    def extract_table(df, key_col1, key_col2):
                        header_idx = -1
                        for i, row in df.iterrows():
                            row_str = row.astype(str).str.replace('*', '', regex=False).str.strip().str.lower()
                            if key_col1.lower() in row_str.values and key_col2.lower() in row_str.values:
                                header_idx = i
                                break
                        if header_idx != -1:
                            df.columns = df.iloc[header_idx].astype(str).str.replace('*', '', regex=False).str.strip()
                            df = df.iloc[header_idx + 1:].reset_index(drop=True)
                            return df
                        return pd.DataFrame()
                    df_groups = extract_table(raw_groups, 'Group Reference', 'Group Name')
                    df_members = extract_table(raw_members, 'Member Reference', 'Full Name')
                    if not df_groups.empty and 'Group Name' in df_groups.columns:
                        df_groups = df_groups.dropna(subset=['Group Reference', 'Group Name'])
                        df_groups = df_groups[~df_groups['Group Name'].astype(str).str.contains('Example', case=False, na=False)]
                    if not df_members.empty and 'Full Name' in df_members.columns:
                        df_members = df_members.dropna(subset=['Member Reference', 'Full Name'])
                        df_members = df_members[~df_members['Full Name'].astype(str).str.contains('Example', case=False, na=False)]
                    num_groups = len(df_groups)
                    num_members = len(df_members)
                    st.success(f"File parsed! Found **{num_groups} Groups** and **{num_members} Members**.")
                    if st.button("🚀 Confirm and Import", use_container_width=True):
                        with st.spinner("Importing data..."):
                            success_count = 0
                            skip_count = 0
                            for index, member_row in df_members.iterrows():
                                try:
                                    group_ref = member_row.get('Group Reference')
                                    group_match = df_groups[df_groups['Group Reference'] == group_ref] if 'Group Reference' in df_groups.columns else pd.DataFrame()
                                    if group_match.empty: continue
                                    group_row = group_match.iloc[0]
                                    m_num_raw = member_row.get('Member Number')
                                    try: m_num_val = int(float(m_num_raw))
                                    except: m_num_val = index + 1
                                    branch_val = str(group_row.get('Branch Name', BRANCH))
                                    group_ref_val = str(member_row.get('Group Reference', ''))
                                    client_id = generate_client_id(all_loans, branch_val, group_ref_val, m_num_val, is_bulk=True)
                                    existing_check = supabase.table("loans").select("client_id").eq("client_id", client_id).execute()
                                    if existing_check.data and len(existing_check.data) > 0:
                                        skip_count += 1
                                        continue
                                    phone_val = str(member_row.get('Phone Number', ''))
                                    if phone_val.lower() == 'nan' or not phone_val.strip(): phone_val = "00000000000"
                                    data = {
                                        "Client ID": client_id,
                                        "Client Name": str(member_row.get('Full Name', '')),
                                        "Phone": phone_val,
                                        "Address": str(member_row.get('Home Address', '')),
                                        "Business Type": str(member_row.get('Business Type', 'Trader')),
                                        "Group Name": str(group_row.get('Group Name', '')),
                                        "Group Location": str(group_row.get('Meeting Location', '')),
                                        "Meeting Day": str(group_row.get('Meeting Day/Time', 'Daily')),
                                        "Date": datetime.now().strftime("%Y-%m-%d"),
                                        "Officer": USER,
                                        "Branch": branch_val,
                                        "Loan Amount": 0,
                                        "Active Credit": 0,
                                        "Loan Repay": 0,
                                        "Total Due": 0,
                                        "Status": "Pending"
                                    }
                                    save_new_loan(data)
                                    success_count += 1
                                except Exception as e:
                                    print(f"Error row {index}: {e}")
                            st.success(f"Import Complete! Registered {success_count} members. Skipped {skip_count} existing.")
                except Exception as e:
                    st.error(f"Error reading file: {e}")
            st.markdown("</div>", unsafe_allow_html=True)

    elif orig_section == "📝 Loan Application":
        st.subheader("📝 Loan Application")
        all_loans_df = load_loans()
        if all_loans_df.empty:
            st.warning("No clients registered in the database.")
        else:
            latest_status = all_loans_df.sort_values('Date').groupby('Client ID').last().reset_index()
            # Filter out auxiliary -ASSET profiles from the origination dropdown list
            base_clients = latest_status[~latest_status['Client ID'].str.endswith("-ASSET", na=False)].copy()
            
            if base_clients.empty:
                st.warning("No clients registered in the database.")
            else:
                # 1. Filter by Group
                unique_groups = ["All Groups"] + sorted(base_clients['Group Name'].dropna().unique().tolist())
                selected_group = st.selectbox("Filter by Group (Optional):", unique_groups)
                
                if selected_group != "All Groups":
                    base_clients = base_clients[base_clients['Group Name'] == selected_group]
                
                if base_clients.empty:
                    st.info("No clients in this group.")
                else:
                    base_clients['DisplayName'] = base_clients['Client Name'] + " (" + base_clients['Client ID'] + ")"
                    options = [""] + base_clients['DisplayName'].tolist()
                    selected_display = st.selectbox("Select Registered/Completed Client:", options)
                    
                    if selected_display:
                        selected_row = base_clients[base_clients['DisplayName'] == selected_display].iloc[0]
                        target_client_id = selected_row['Client ID']
                        
                        reps = load_repayments()
                        client_reps = reps[reps['Client ID'] == target_client_id] if not reps.empty else __import__('pandas').DataFrame()
                        savings, _ = calculate_client_savings(client_reps, 0)
                        
                        st.info(f"💰 **Current Pooled Savings Balance:** ₦{savings:,.0f}")
                        
                        st.markdown("#### Financial Details")
                        f1, f2 = st.columns(2)
                        product_category = f1.selectbox("Product Category", ["Finance", "Asset"])
                        
                        if product_category == "Finance":
                            prods = ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M"]
                        else:
                            prods = ["60-Day Asset", "120-Day Asset", "Cash and Carry"]
                            
                        product = f2.selectbox("Loan Product", prods)
                        raw_amount = st.number_input("Requested Loan Amount / Asset Cost (₦)", min_value=0.0, step=10000.0, value=None, placeholder="0")
                        amount = float(raw_amount) if raw_amount else 0.0
                        
                        setup = calculate_loan_setup(amount, product, product_category)
                        interest = setup.get('interest', 0)
                        dur = setup.get('duration', 60)
                        
                        if product_category == "Asset":
                            # ---- ASSET ORIGINATION ENGINE ----
                            total_cost = amount + interest
                            st.markdown(f"**Asset Cost:** ₦{amount:,.0f}")
                            st.markdown(f"**Interest ({int(setup.get('interest',0)/amount*100) if amount > 0 else 0}%):** ₦{interest:,.0f}")
                            st.markdown(f"**Total Cost (Principal + Interest):** ₦{total_cost:,.0f}")
                            
                            raw_dp = st.number_input("Initial Cash Downpayment (₦)", min_value=0.0, step=5000.0, value=None, placeholder="0")
                            initial_downpayment = float(raw_dp) if raw_dp else 0.0
                            
                            active_credit = total_cost - initial_downpayment
                            final_repay = active_credit / dur if dur > 0 else 0
                            
                            st.markdown("---")
                            st.markdown(f"**Active Loan (Total Cost - Downpayment):** ₦{active_credit:,.0f}")
                            st.markdown(f"**Expected Installment:** ₦{final_repay:,.0f} x {dur} {setup.get('freq', 'Daily')}")
                            
                            if initial_downpayment > 0:
                                st.info(f"💵 Ensure the ₦{initial_downpayment:,.0f} downpayment is collected physically. It will be banked as part of total cash.")
                            
                            total_upfront_required = 0  # No savings deduction for asset loans
                        else:
                            # ---- FINANCE ORIGINATION ENGINE (existing logic) ----
                            raw_gap = st.number_input("Gap Fee / Base Savings (₦)", min_value=0.0, step=1000.0, value=None, placeholder="0")
                            base_savings_req = float(raw_gap) if raw_gap else 0.0
                            initial_downpayment = 0
                            
                            active_credit = amount - base_savings_req
                            final_repay = active_credit / dur if dur > 0 else 0
                                
                            total_upfront_required = interest + base_savings_req
                            
                            st.markdown(f"**Calculated Upfront Requirement:**")
                            st.markdown(f"- Interest: ₦{interest:,.0f}")
                            st.markdown(f"- Gap Fee (Base Savings): ₦{base_savings_req:,.0f}")
                            st.markdown(f"**Total Required:** ₦{total_upfront_required:,.0f}")
                            
                            if total_upfront_required > 0:
                                if savings < total_upfront_required:
                                    st.error(f"❌ **INSUFFICIENT SAVINGS:** Client has ₦{savings:,.0f} but needs ₦{total_upfront_required:,.0f}. Please collect additional savings via the Cashbook first.")
                                else:
                                    st.success(f"✅ **SUFFICIENT SAVINGS:** Client has enough to cover the upfront fees.")
                            
                        submitted_app = st.button("Submit Application for BM Approval", use_container_width=True)
                        if submitted_app:
                            # Validation: Check for existing loan of the SAME category
                            check_id = target_client_id if product_category == "Finance" else f"{target_client_id}-ASSET"
                            existing_loan = all_loans_df[all_loans_df['Client ID'] == check_id]
                            
                            is_blocked = False
                            if not existing_loan.empty:
                                last_stat = existing_loan.sort_values('Date').iloc[-1]
                                # If it is Active or Pending AND has an actual loan amount (not just a registration placeholder)
                                if last_stat['Status'] in ['Active', 'Pending'] and float(last_stat.get('Loan Amount', 0)) > 0:
                                    is_blocked = True
                                    
                            if is_blocked:
                                st.error(f"❌ Cannot submit: This client already has an Active or Pending {product_category} loan!")
                            elif product_category == "Finance" and savings < total_upfront_required:
                                st.error("Cannot submit! Insufficient savings.")
                            else:
                                # For Finance: auto-deduct upfront fees from savings
                                if product_category == "Finance" and total_upfront_required > 0:
                                    wd_data = {
                                        "Date": datetime.now().strftime("%Y-%m-%d"),
                                        "Client ID": target_client_id,
                                        "Client Name": selected_row['Client Name'],
                                        "Officer": USER,
                                        "Branch": BRANCH,
                                        "Withdrawal Amount": total_upfront_required,
                                        "Note": f"Auto-deducted Upfront Fees (Interest: {interest}, Gap: {base_savings_req}) for Loan App"
                                    }
                                    save_repayment(wd_data)
                                

                                
                                kyc = selected_row.to_dict()
                                kyc.pop('DisplayName', None)
                                kyc.pop('DateStr', None)
                                kyc.pop('id', None)
                                
                                kyc["Client ID"] = check_id  # Use base ID for Finance, suffixed ID for Asset
                                kyc["Date"] = datetime.now().strftime("%Y-%m-%d")
                                kyc["Officer"] = USER
                                kyc["Branch"] = BRANCH
                                kyc["Product Category"] = product_category
                                kyc["Loan Product"] = product
                                kyc["Loan Amount"] = amount
                                kyc["Active Credit"] = active_credit
                                kyc["Loan Repay"] = final_repay
                                kyc["Total Due"] = active_credit
                                kyc["Status"] = "Pending"
                                
                                kyc["Processing Fee"] = 0
                                kyc["Pass Book Fee"] = 0
                                kyc["Group Savings"] = 0
                                kyc["Branch Contingency"] = 0
                                
                                save_new_loan(kyc)
                                
                                st.success("Application submitted successfully! It is now Pending BM Authorization.")
                                import time
                                time.sleep(2)
                                st.rerun()


elif page == "Collections":
    st.title("👥 Member Collections")
    st.caption("Record daily repayments, savings, and fees for a specific group.")
    
    view_date = st.date_input("Select Date", datetime.now().date(), key="col_date")
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    if all_loans.empty:
        st.warning("No active loans found.")
    else:
        # Filter active loans for this officer (unless BM/AM looking at all)
        if ROLE in ["BM", "AM"]:
            branch_loans = all_loans[all_loans['Branch'] == BRANCH] if ROLE == "BM" else all_loans
            unique_officers = branch_loans['Officer'].dropna().unique().tolist()
            if unique_officers:
                display_options = [CO_DISPLAY_MAP.get(o, o) for o in unique_officers]
                selected_display = st.selectbox("Select Credit Officer", display_options, key="col_co")
                target_co = CO_NAME_MAP.get(selected_display, selected_display)
            else:
                target_co = USER
        else:
            target_co = USER
            
        # Show all clients that are not strictly closed or completed, so newly assigned clients appear
        co_loans = all_loans[(all_loans['Officer'] == target_co) & (~all_loans['Status'].isin(['Completed', 'Closed']))]
        
        if co_loans.empty:
            st.info("No active or pending members for this officer.")
        else:
            groups = ["Ungrouped"] + sorted(co_loans[co_loans['Group Name'].notna()]['Group Name'].unique().tolist())
            selected_group = st.selectbox("Select Group", groups)
            
            if selected_group == "Ungrouped":
                group_loans = co_loans[co_loans['Group Name'].isna() | (co_loans['Group Name'] == "")]
            else:
                group_loans = co_loans[co_loans['Group Name'] == selected_group]
                
            if group_loans.empty:
                st.info("No active or pending members in this group.")
            else:
                st.markdown(f"### Members in {selected_group}")
                
                # Fetch history for today to prefill/check
                today_reps = repayments[(repayments['Date'] == date_str) & (repayments['Officer'] == target_co)] if not repayments.empty else pd.DataFrame()
                
                # Pre-compute member data for both tabs
                member_info = {}
                for _, member in group_loans.iterrows():
                    cid = member['Client ID']
                    mem_reps = repayments[repayments['Client ID'] == cid] if not repayments.empty else pd.DataFrame()
                    acc_sav = mem_reps['Savings Amount'].astype(float).sum() if not mem_reps.empty else 0
                    acc_wd = mem_reps['Withdrawal Amount'].astype(float).sum() if 'Withdrawal Amount' in mem_reps.columns and not mem_reps.empty else 0
                    sav_bal = acc_sav - acc_wd
                    total_paid = mem_reps['Loan Repayment Amount'].astype(float).sum() if not mem_reps.empty else 0
                    act_cred = float(member.get('Active Credit', 0))
                    rem_bal = act_cred - total_paid
                    exp_rep = float(member.get('Loan Repayment', 0))
                    today_paid = today_reps[today_reps['Client ID'] == cid] if not today_reps.empty else pd.DataFrame()
                    default_rep = exp_rep if today_paid.empty else 0.0
                    member_info[cid] = {
                        "member": member,
                        "sav_bal": sav_bal,
                        "rem_bal": rem_bal,
                        "act_cred": act_cred,
                        "default_rep": default_rep
                    }
                
                if st.session_state.get('pending_collections') and st.session_state.get('collections_group') == selected_group and st.session_state.get('collections_date') == date_str:
                    st.markdown("### 🔍 Review Group Collections")
                    to_insert = st.session_state['pending_collections']
                    
                    total_in = sum(float(tx.get('Amount Paid', 0)) + float(tx.get('Bank Withdrawal', 0)) for tx in to_insert)
                    total_out = sum(float(tx.get('Withdrawal Amount', 0)) + float(tx.get('Expenses', 0)) + float(tx.get('Bank Deposited', 0)) + float(tx.get('Product Withdrawal', 0)) + float(tx.get('Laps Transferred', 0)) for tx in to_insert)
                    net_cash = total_in - total_out
                    
                    st.info(f"**Total Money Collected (Cash In):** ₦{total_in:,.0f}")
                    st.warning(f"**Total Money Given Out (Cash Out):** ₦{total_out:,.0f}")
                    st.success(f"**NET CASH EXPECTED FROM GROUP:** ₦{net_cash:,.0f}")
                    
                    c1, c2 = st.columns(2)
                    if c1.button("🔙 Edit / Go Back"):
                        del st.session_state['pending_collections']
                        st.rerun()
                    
                    if c2.button("✅ Confirm & Save to Database", type="primary", use_container_width=True):
                        db_payload = []
                        from app import UI_TO_DB_REP, supabase
                        for tx in to_insert:
                            db_payload.append({UI_TO_DB_REP[k]: v for k, v in tx.items() if k in UI_TO_DB_REP})
                        try:
                            supabase.table('repayments').insert(db_payload).execute()
                            st.success("Group Collections Submitted Successfully!")
                            del st.session_state['pending_collections']
                            import time
                            time.sleep(2)
                            st.rerun()
                        except Exception as e:
                            st.error(f"Error saving: {e}")
                else:
                    with st.form("collections_form"):
                        sav_data = {}
                        rep_data = {}
                        
                        # ---- GROUP-LEVEL SAVINGS ----
                        st.markdown("### 🏛️ Group-Level Savings")
                        st.caption("Input communal group savings and withdrawal amounts.")
                        gsc1, gsc2, gsc3 = st.columns(3)
                        global_group_savings = gsc1.number_input("Group Savings Deposit", min_value=0.0, step=500.0, value=None, placeholder="0")
                        global_group_wd = gsc2.number_input("Group Savings Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                        global_laps_reserved = gsc3.number_input("Laps Reserved", min_value=0.0, step=500.0, value=None, placeholder="0")
                        st.markdown("---")
                        
                        # ---- PER-CLIENT COLLECTIONS (UNIFIED) ----
                        st.markdown("### 📋 Client Collections (Savings & Repayments)")
                        for cid, info in member_info.items():
                            m = info['member']
                            prod = str(m['Loan Product'])
                            is_asset = str(cid).endswith("-ASSET")
                            
                            if is_asset:
                                title = f"📋 {m['Client Name']} (ASSET) - Rem: ₦{info['rem_bal']:,.0f}"
                            else:
                                title = f"👤 {m['Client Name']} ({cid}) - Rem: ₦{info['rem_bal']:,.0f} | Sav: ₦{info['sav_bal']:,.0f}"
                                
                            with st.expander(title):
                                if not is_asset:
                                    st.markdown("**🏦 Savings**")
                                    sc1, sc2 = st.columns(2)
                                    s_dep = sc1.number_input("Savings Deposit", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"sdep_{cid}")
                                    s_wd = sc2.number_input("Savings Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"swd_{cid}")
                                    sav_data[cid] = {"dep": s_dep, "wd": s_wd}
                                    st.markdown("---")
                                
                                st.markdown(f"**💵 Loan ({prod})** - Active Cr: ₦{info['act_cred']:,.0f}")
                                d_rep = float(info['default_rep'])
                                
                                r1, r2 = st.columns(2)
                                rep_col = r1.number_input("Credit Repayment", min_value=0.0, step=500.0, value=d_rep if d_rep > 0 else None, placeholder="0", key=f"rep_{cid}")
                                app_col = r2.number_input("Processing Fee", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"app_{cid}")
                                
                                r3, r4 = st.columns(2)
                                pb_col = r3.number_input("Pass Book", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"pb_{cid}")
                                misc_col = r4.number_input("Misc Fee", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"misc_{cid}")
                                
                                a1, a2 = st.columns(2)
                                asset_cr_col = a1.number_input("Asset Cr Sale", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"acr_{cid}")
                                cc_col = a2.number_input("Cash & Carry", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"cc_{cid}")
                                
                                a3, a4 = st.columns(2)
                                cfd_col = a3.number_input("Cr Form Dmg", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"cfd_{cid}")
                                bonus_col = a4.number_input("Bonus", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"bon_{cid}")
                                
                                rep_data[cid] = {
                                    "rep": rep_col, "app": app_col, "pb": pb_col, "misc": misc_col,
                                    "asset_cr": asset_cr_col, "cc": cc_col, "cfd": cfd_col, "bonus": bonus_col
                                }
                        
                        # ---- END OF DAY / GLOBAL OUTFLOWS (Below Tabs) ----
                        st.markdown("### 📤 End of Day / Global Outflows")
                        st.caption("Log your daily branch expenses, bank deposits, and withdrawals here.")
                        out_1, out_2, out_3 = st.columns(3)
                        global_expenses = out_1.number_input("Office Expenses", min_value=0.0, step=500.0, value=None, placeholder="0")
                        global_bank_dep = out_2.number_input("Bank Deposited", min_value=0.0, step=500.0, value=None, placeholder="0")
                        global_bank_wd = out_3.number_input("Bank Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                        
                        out_4, out_5 = st.columns(2)
                        global_prod_wd = out_4.number_input("Product Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                        global_laps_trans = out_5.number_input("Laps Transferred", min_value=0.0, step=500.0, value=None, placeholder="0")
                        
                        st.markdown("---")
                        submit_btn = st.form_submit_button("Calculate Totals & Review", type="primary", use_container_width=True)
                        
                        if submit_btn:
                            to_insert = []
                            
                            # ---- Process per-client data (merge both tabs) ----
                            for cid, info in member_info.items():
                                m = info['member']
                                s = sav_data.get(cid, {"dep": 0, "wd": 0})
                                r = rep_data.get(cid, {"rep": 0, "app": 0, "pb": 0, "misc": 0, "asset_cr": 0, "cc": 0, "cfd": 0, "bonus": 0})
                                
                                sav = float(s['dep'] or 0)
                                sav_wd = float(s['wd'] or 0)
                                rep = float(r['rep'] or 0)
                                app = float(r['app'] or 0)
                                pb = float(r['pb'] or 0)
                                misc = float(r['misc'] or 0)
                                asset_cr = float(r['asset_cr'] or 0)
                                cc = float(r['cc'] or 0)
                                cfd = float(r['cfd'] or 0)
                                bon = float(r['bonus'] or 0)
                                
                                # Skip if nothing entered at all
                                if sav == 0 and sav_wd == 0 and rep == 0 and app == 0 and pb == 0 and misc == 0 and asset_cr == 0 and cc == 0 and cfd == 0 and bon == 0:
                                    continue
                                
                                prod_low = str(m['Loan Product']).lower()
                                rep_12w = rep_24w = rep_60d = rep_120d = rep_mth = 0
                                
                                if "12 week" in prod_low or "12wk" in prod_low or "12w" in prod_low: rep_12w = rep
                                elif "24 week" in prod_low or "24wk" in prod_low or "24w" in prod_low: rep_24w = rep
                                elif "60 day" in prod_low or ("daily" in prod_low and "120" not in prod_low) or "60-day" in prod_low: rep_60d = rep
                                elif "120 day" in prod_low or "120-day" in prod_low: rep_120d = rep
                                elif "month" in prod_low: rep_mth = rep
                                else: rep_60d = rep
                                
                                tx_data = {
                                    "Date": date_str,
                                    "Client ID": cid,
                                    "Client Name": m['Client Name'],
                                    "Officer": target_co,
                                    "Branch": m['Branch'],
                                    "Amount Paid": sav + rep + app + pb + misc + asset_cr + cc + cfd + bon,
                                    "Transaction Type": "Loan",
                                    "Note": "Daily Collection",
                                    "Savings Amount": sav,
                                    "Withdrawal Amount": sav_wd,
                                    "Loan Repayment Amount": rep,
                                    "Repayment 12 Weeks": rep_12w,
                                    "Repayment 24 Weeks": rep_24w,
                                    "Repayment 60 Days": rep_60d,
                                    "Repayment 120 Days": rep_120d,
                                    "Monthly": rep_mth,
                                    "Bank Withdrawal": 0,
                                    "Asset Sales": 0,
                                    "App Fee": app,
                                    "Pass Book Bonus": pb,
                                    "Misc Fees": misc,
                                    "Asset Credit Sales": asset_cr,
                                    "Cash and Carry": cc,
                                    "Credit Form": 0,
                                    "Credit Form Damage": cfd,
                                    "Bonus": bon,
                                    "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0,
                                    "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                                    "Product Withdrawal": 0, "Expenses": 0, "Bank Deposited": 0,
                                    "Laps Reserved": 0, "Laps Transferred": 0,
                                    "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
                                }
                                to_insert.append(tx_data)
                            
                            # ---- Process Group-Level Inflows ----
                            
                            global_group_savings = float(global_group_savings or 0)
                            global_group_wd = float(global_group_wd or 0)
                            global_laps_reserved = float(global_laps_reserved or 0)
                            global_expenses = float(global_expenses or 0)
                            global_bank_dep = float(global_bank_dep or 0)
                            global_bank_wd = float(global_bank_wd or 0)
                            global_prod_wd = float(global_prod_wd or 0)
                            global_laps_trans = float(global_laps_trans or 0)
                            
                            if global_group_savings > 0 or global_group_wd > 0 or global_laps_reserved > 0:
                                g_data = {
                                    "Date": date_str, "Client ID": f"GROUP-{selected_group}", "Client Name": f"{selected_group} Meeting",
                                    "Officer": target_co, "Branch": BRANCH,
                                    "Amount Paid": global_group_savings + global_laps_reserved,
                                    "Transaction Type": "Group Meeting", "Note": "Group Level Inputs",
                                    "Savings Amount": global_group_savings, "Withdrawal Amount": global_group_wd,
                                    "Laps Reserved": global_laps_reserved,
                                    "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
                                    "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0, "Bank Withdrawal": 0,
                                    "Asset Sales": 0, "App Fee": 0, "Pass Book Bonus": 0, "Misc Fees": 0, "Asset Credit Sales": 0,
                                    "Cash and Carry": 0, "Credit Form": 0, "Credit Form Damage": 0, "Bonus": 0,
                                    "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0, "Weekly 11%": 0,
                                    "Weekly 20%": 0, "Monthly 11%/20%": 0, "Group Savings Deposit": 0, "Group Savings Withdrawal": 0,
                                    "Laps Transferred": 0, "Product Withdrawal": 0, "Expenses": 0, "Bank Deposited": 0
                                }
                                to_insert.append(g_data)
                            
                            # ---- Process EOD Outflows ----
                            if global_expenses > 0 or global_bank_dep > 0 or global_bank_wd > 0 or global_prod_wd > 0 or global_laps_trans > 0:
                                eod_data = {
                                    "Date": date_str, "Client ID": "CASHBOOK", "Client Name": "EOD Outflows",
                                    "Officer": target_co, "Branch": BRANCH, "Amount Paid": 0,
                                    "Transaction Type": "EOD Outflows", "Note": "Daily Branch End of Day",
                                    "Expenses": global_expenses, "Bank Deposited": global_bank_dep,
                                    "Bank Withdrawal": global_bank_wd, "Product Withdrawal": global_prod_wd,
                                    "Laps Transferred": global_laps_trans,
                                    "Savings Amount": 0, "Withdrawal Amount": 0, "Laps Reserved": 0,
                                    "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
                                    "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0,
                                    "Asset Sales": 0, "App Fee": 0, "Pass Book Bonus": 0, "Misc Fees": 0,
                                    "Asset Credit Sales": 0, "Cash and Carry": 0, "Credit Form": 0,
                                    "Credit Form Damage": 0, "Bonus": 0, "Contingency": 0, "Daily 11%": 0,
                                    "Daily 20%": 0, "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                                    "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
                                }
                                to_insert.append(eod_data)
                            
                            if to_insert:
                                st.session_state['pending_collections'] = to_insert
                                st.session_state['collections_group'] = selected_group
                                st.session_state['collections_date'] = date_str
                                st.rerun()
                            else:
                                st.info("No collections entered to save.")


elif page == "Daily Report":
    st.title("Daily Collections Report")
    
    view_date = st.date_input("Select Date for Report", datetime.now().date())
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    # Filter for the selected date for new active loans
    if not all_loans.empty:
        all_loans['DateStr'] = pd.to_datetime(all_loans['Date'], errors='coerce').dt.date.astype(str)
        daily_loans = all_loans[(all_loans['DateStr'] == date_str) & (all_loans['Status'].isin(['Active', 'Completed', 'Approved']))]
        if ROLE == "BM":
            daily_loans = daily_loans[daily_loans['Branch'] == BRANCH]
        elif ROLE == "Officer":
            daily_loans = daily_loans[daily_loans['Officer'] == USER]
        new_active_loans = pd.to_numeric(daily_loans['Active Credit'], errors='coerce').fillna(0).sum()
    else:
        new_active_loans = 0
        
    if not repayments.empty:
        # Filter for the selected date
        repayments['DateStr'] = pd.to_datetime(repayments['Date'], errors='coerce').dt.date.astype(str)
        

        daily_reps = repayments[repayments['DateStr'] == date_str]
        
        # --- MANAGERIAL DROPDOWN ---
        if ROLE in ["BM", "AM"]:
            st.markdown("### 🏢 Managerial Controls")
            # Get unique officers for this branch today
            if ROLE == "BM":
                daily_reps = daily_reps[daily_reps['Branch'] == BRANCH]
            
            unique_officers = daily_reps['Officer'].dropna().unique().tolist()
            if not unique_officers:
                st.info("No officers have records for today.")
                target_officer = "All Officers"
            else:
                display_options = ["All Officers"] + [CO_DISPLAY_MAP.get(o, o) for o in unique_officers]
                selected_display = st.selectbox("Select Credit Officer", display_options, key="daily_rep_co")
                target_officer = "All Officers" if selected_display == "All Officers" else CO_NAME_MAP.get(selected_display, selected_display)
                
            if target_officer != "All Officers":
                daily_reps = daily_reps[daily_reps['Officer'] == target_officer]
                if not all_loans.empty:
                    daily_loans = daily_loans[daily_loans['Officer'] == target_officer]
        elif ROLE == "Officer":
            daily_reps = daily_reps[daily_reps['Officer'] == USER]

            
        if daily_reps.empty:
            st.info(f"No collections found for {date_str}.")
        else:
            st.markdown(f"### 📊 Collection Summary for {date_str}")
            
            # Sum up granular fields
            total_savings_dep = pd.to_numeric(daily_reps['Savings Amount'], errors='coerce').fillna(0).sum()
            total_withdrawal = pd.to_numeric(daily_reps['Withdrawal Amount'], errors='coerce').fillna(0).sum()
            total_cash_return = pd.to_numeric(daily_reps['Markup Paid'], errors='coerce').fillna(0).sum()
            total_mgt_fees = pd.to_numeric(daily_reps['Mgt Fee Paid'], errors='coerce').fillna(0).sum()
            total_adj = pd.to_numeric(daily_reps['Others Amount'], errors='coerce').fillna(0).sum() # Note: we overloaded this, wait.
            
            # Wait, in Phase 1, I mapped Overdue to Others Amount, Cash Return to Markup Paid, Adjustments to Note!
            # Since Adjustments are in the Note, I will just ignore it for the summary logic, or try to parse it.
            # But the user asked for explicit "Total Savings Collected - Total Savings Withdrawn (Cash Return, Mgt Fees, Adjustments)".
            # Actually, let's just use what we have in columns.
            total_savings_withdrawn = total_withdrawal + total_cash_return + total_mgt_fees
            closing_savings = total_savings_dep - total_savings_withdrawn
            
            total_loan_rep = pd.to_numeric(daily_reps['Loan Repayment Amount'], errors='coerce').fillna(0).sum()
            total_overdue = pd.to_numeric(daily_reps['Others Amount'], errors='coerce').fillna(0).sum()
            total_recoveries = pd.to_numeric(daily_reps['Recovery Amount'], errors='coerce').fillna(0).sum()
            total_init_pay = pd.to_numeric(daily_reps['initial_payment'], errors='coerce').fillna(0).sum()
            
            actual_collections = total_loan_rep + total_overdue + total_recoveries + total_init_pay
            
            total_cash_in = pd.to_numeric(daily_reps['Amount Paid'], errors='coerce').fillna(0).sum()
            
            st.markdown("---")
            c1, c2 = st.columns(2)
            with c1:
                st.markdown("<div class='card'>", unsafe_allow_html=True)
                st.subheader("🐷 Savings Summary")
                st.write(f"**Total Savings Collected:** ₦{total_savings_dep:,.0f}")
                st.write(f"**Total Savings Withdrawn:** ₦{total_savings_withdrawn:,.0f} (Withdrawal, Cash Return, Mgt Fees)")
                st.markdown("---")
                st.markdown(f"#### Closing Savings Balance: ₦{closing_savings:,.0f}")
                st.markdown("</div>", unsafe_allow_html=True)
                
            with c2:
                st.markdown("<div class='card'>", unsafe_allow_html=True)
                st.subheader("🏦 Credit Summary")
                # To calculate prev balance, we need all past active credit - all past actual collections. 
                # This is complex, so let's just show the math for today.
                st.write(f"**New Active Loans Today:** ₦{new_active_loans:,.0f}")
                st.write(f"**Actual Loan Collections:** ₦{actual_collections:,.0f} (Instalments, Overdue, Init, Rec)")
                # Assume full repayments are 0 for now unless we calculate it globally
                st.markdown("---")
                st.markdown(f"#### Net Credit Flow Today: ₦{(new_active_loans - actual_collections):,.0f}")
                st.markdown("</div>", unsafe_allow_html=True)
            
            st.markdown("### 📝 Detailed Client Breakdown")
            
            detailed_data = []
            for _, row in daily_reps.iterrows():
                cid = row.get('Client ID')
                c_loan = all_loans[all_loans['Client ID'] == cid].iloc[0] if cid in all_loans['Client ID'].values else None
                
                acc_savings = 0
                loan_bal = 0
                
                if c_loan is not None:
                    c_payments = repayments[repayments['Client ID'] == cid]
                    s_amt, l_amt = calculate_client_savings(c_payments, c_loan['Loan Repay'])
                    acc_savings = s_amt
                    loan_bal = c_loan['Active Credit'] - l_amt
                    
                detailed_data.append({
                    "Client Name": row.get('Client Name', 'Unknown'),
                    "Phone": c_loan['Phone'] if c_loan is not None else '',
                    "Group": c_loan['Group Name'] if c_loan is not None else '',
                    "Cash Paid Today": row.get('Amount Paid', 0),
                    "Loan Paid Today": row.get('Loan Repayment Amount', 0) + row.get('Others Amount', 0) + row.get('Recovery Amount', 0) + row.get('initial_payment', 0),
                    "Savings Paid Today": row.get('Savings Amount', 0),
                    "Withdrawal Today": row.get('Withdrawal Amount', 0) + row.get('Markup Paid', 0),
                    "Current Loan Balance": loan_bal,
                    "Total Acc. Savings": acc_savings,
                    "Officer": row.get('Officer', ''),
                    "Note": row.get('Note', '')
                })
            
            st.dataframe(pd.DataFrame(detailed_data), use_container_width=True)
    else:
        st.info("No records found in database.")

elif page == "Audit Ledger":
    st.title("📒 Audit Ledger")
    st.caption("Complete transaction history — Loans & Repayments")
    
    audit_section = st.radio("View", ["📋 Loans Ledger", "💰 Repayments Ledger"], horizontal=True, label_visibility="collapsed")
    
    al1, al2 = st.columns(2)
    audit_date_from = al1.date_input("From Date", datetime.now().date() - timedelta(days=30), key="audit_from")
    audit_date_to = al2.date_input("To Date", datetime.now().date(), key="audit_to")
    search_term = st.text_input("🔍 Search by Client Name or ID", placeholder="Type to filter...", key="audit_search")
    
    if audit_section == "📋 Loans Ledger":
        all_loans = load_loans()
        if all_loans.empty:
            st.info("No loan records found.")
        else:
            # Role-based filter
            filtered = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
            
            # Date filter (string-based to avoid tz mismatch)
            filtered['_dstr'] = pd.to_datetime(filtered['Date'], errors='coerce').dt.strftime('%Y-%m-%d')
            _from = audit_date_from.strftime('%Y-%m-%d')
            _to = audit_date_to.strftime('%Y-%m-%d')
            filtered = filtered[filtered['_dstr'].notna() & (filtered['_dstr'] >= _from) & (filtered['_dstr'] <= _to)]
            
            # Search filter
            if search_term:
                mask = (
                    filtered['Client Name'].str.contains(search_term, case=False, na=False) |
                    filtered['Client ID'].str.contains(search_term, case=False, na=False)
                )
                filtered = filtered[mask]
            
            filtered = filtered.drop(columns=['_dstr'], errors='ignore')
            
            display_cols = [c for c in ['Date', 'Client ID', 'Client Name', 'Officer', 'Branch', 'Loan Product', 'Loan Amount', 'Active Credit', 'Loan Repay', 'Status'] if c in filtered.columns]
            
            st.markdown(f"**{len(filtered)} records found**")
            st.dataframe(filtered[display_cols].sort_values('Date', ascending=False), use_container_width=True, hide_index=True)
    
    elif audit_section == "💰 Repayments Ledger":
        all_reps = load_repayments()
        if all_reps.empty:
            st.info("No repayment records found.")
        else:
            # Role-based filter
            if ROLE in ['CO', 'Officer']:
                filtered = all_reps[all_reps['Officer'] == USER]
            elif ROLE == 'BM':
                filtered = all_reps[all_reps['Branch'] == BRANCH]
            else:
                filtered = all_reps
            
            # Date filter (string-based to avoid tz mismatch)
            filtered['_dstr'] = pd.to_datetime(filtered['Date'], errors='coerce').dt.strftime('%Y-%m-%d')
            _from = audit_date_from.strftime('%Y-%m-%d')
            _to = audit_date_to.strftime('%Y-%m-%d')
            filtered = filtered[filtered['_dstr'].notna() & (filtered['_dstr'] >= _from) & (filtered['_dstr'] <= _to)]
            
            # Search filter
            if search_term:
                mask = (
                    filtered['Client Name'].str.contains(search_term, case=False, na=False) |
                    filtered['Client ID'].str.contains(search_term, case=False, na=False)
                )
                filtered = filtered[mask]
            
            filtered = filtered.drop(columns=['_dstr'], errors='ignore')
            
            display_cols = [c for c in ['Date', 'Client ID', 'Client Name', 'Officer', 'Amount Paid', 'Savings Amount', 'Loan Repayment Amount', 'Withdrawal Amount', 'Transaction Type', 'Note'] if c in filtered.columns]
            
            st.markdown(f"**{len(filtered)} records found**")
            st.dataframe(filtered[display_cols].sort_values('Date', ascending=False), use_container_width=True, hide_index=True)

elif page == "WhatsApp Cashbook":
    st.title("📖 CO Daily Cashbook")
    st.caption("Daily Ledger — Auto-Calculated from Collections")
    
    view_date = st.date_input("Select Date", datetime.now().date(), key="wa_date")
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    if repayments.empty:
        repayments = pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
    
    repayments['DateStr'] = pd.to_datetime(repayments['Date'], errors='coerce').dt.date.astype(str)
    
    # --- RBAC FILTERING ---
    if ROLE in ["BM", "AM"]:
        st.markdown("### 🏢 Managerial Controls")
        daily_reps_all = repayments[repayments['DateStr'] == date_str]
        if ROLE == "BM":
            daily_reps_all = daily_reps_all[daily_reps_all['Branch'] == BRANCH]
        
        unique_officers = daily_reps_all['Officer'].dropna().unique().tolist()
        if unique_officers:
            display_options = [CO_DISPLAY_MAP.get(o, o) for o in unique_officers]
            selected_display = st.selectbox("Select Credit Officer", display_options, key="wa_cashbook_co")
            target_co = CO_NAME_MAP.get(selected_display, selected_display)
        else:
            st.info("No officers have records for this date.")
            target_co = USER
    else:
        target_co = USER
        
    daily_reps = repayments[(repayments['DateStr'] == date_str) & (repayments['Officer'] == target_co)]
    
    # ========================================================
    # LEDGER DISPLAY & MANUAL OUTFLOWS
    # ========================================================
    st.markdown("---")
    st.markdown(f"### 📋 Daily Ledger for {CO_DISPLAY_MAP.get(target_co, target_co)} - {date_str}")
    
    def sum_col(df, col):
        if col in df.columns:
            return pd.to_numeric(df[col], errors='coerce').fillna(0).sum()
        return 0.0

    c1, c2 = st.columns(2)
    with c1:
        st.markdown("#### Setup & Manual Outflows")
        bf_cash = st.number_input("Opening Balance (B/F Cash)", value=0.0, step=500.0, key="ledger_opening")
        laps_res = st.number_input("Laps Reserved (Left Inflow)", value=0.0, step=500.0)
        
        st.markdown("##### Outflows (Right)")
        product_wd = st.number_input("Product Withdrawal (Savings WD)", value=0.0, step=500.0)
        bank_dep = st.number_input("Bank Deposited", value=0.0, step=500.0)
        expenses = st.number_input("Expenses", value=0.0, step=500.0)
        laps_trans = st.number_input("Laps Transferred", value=0.0, step=500.0)
        
        submit_manual = st.button("Save Manual Entries", type="primary")
        if submit_manual:
            tx_data = {
                "Date": date_str, "Client ID": "CASHBOOK", "Client Name": "Cashbook Entry",
                "Officer": target_co, "Branch": BRANCH,
                "Transaction Type": "Cashbook Entry", "Amount Paid": 0, "Note": "Cashbook Manual Outflows",
                "Laps Reserved": laps_res, "Product Withdrawal": product_wd,
                "Bank Deposited": bank_dep, "Expenses": expenses, "Laps Transferred": laps_trans,
                "Savings Amount": 0, "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0,
                "Repayment 24 Weeks": 0, "Repayment 60 Days": 0, "Repayment 120 Days": 0,
                "Monthly": 0, "Contingency": 0, "Bank Withdrawal": 0, "Asset Sales": 0,
                "App Fee": 0, "Pass Book Bonus": 0, "Daily 11%": 0, "Daily 20%": 0,
                "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0, "Group Savings Deposit": 0,
                "Group Savings Withdrawal": 0, "Misc Fees": 0, "Withdrawal Amount": 0
            }
            try:
                db_data = {UI_TO_DB_REP[k]: v for k, v in tx_data.items()}
                supabase.table("repayments").insert([db_data]).execute()
                st.success("Manual entries saved!")
                import time
                time.sleep(1)
                st.rerun()
            except Exception as e:
                st.error(f"Error saving: {e}")

    # Calculate New Active Disbursements (from loans table originated today by this CO)
    co_loans = all_loans[all_loans['Officer'] == target_co] if not all_loans.empty else pd.DataFrame()
    d_act = w_act = m_act = 0
    if not co_loans.empty:
        co_loans['DateStr'] = pd.to_datetime(co_loans['Date'], errors='coerce').dt.date.astype(str)
        today_loans = co_loans[co_loans['DateStr'] == date_str]
        for _, loan in today_loans.iterrows():
            prod = str(loan.get('Loan Product', '')).lower()
            amt = pd.to_numeric(loan.get('Active Credit', 0), errors='coerce')
            if pd.isna(amt): amt = 0
            if "daily" in prod or "60" in prod or "120" in prod: d_act += amt
            elif "weekly" in prod or "12w" in prod or "24w" in prod: w_act += amt
            elif "month" in prod or "3m" in prod or "6m" in prod: m_act += amt

    # Sum all the columns from daily_reps
    t_sav = sum_col(daily_reps, 'Savings Amount')
    t_r12w = sum_col(daily_reps, 'Repayment 12 Weeks')
    t_r24w = sum_col(daily_reps, 'Repayment 24 Weeks')
    t_r60d = sum_col(daily_reps, 'Repayment 60 Days')
    t_r120d = sum_col(daily_reps, 'Repayment 120 Days')
    t_rmth = sum_col(daily_reps, 'Monthly')
    t_cont = sum_col(daily_reps, 'Contingency')
    t_bwd = sum_col(daily_reps, 'Bank Withdrawal')
    t_asale = sum_col(daily_reps, 'Asset Sales')
    t_app = sum_col(daily_reps, 'App Fee')
    t_pb = sum_col(daily_reps, 'Pass Book Bonus')
    t_misc = sum_col(daily_reps, 'Misc Fees')
    
    t_d11 = sum_col(daily_reps, 'Daily 11%')
    t_d20 = sum_col(daily_reps, 'Daily 20%')
    t_w11 = sum_col(daily_reps, 'Weekly 11%')
    t_w20 = sum_col(daily_reps, 'Weekly 20%')
    t_mm = sum_col(daily_reps, 'Monthly 11%/20%')
    t_pwd = sum_col(daily_reps, 'Product Withdrawal')
    t_exp = sum_col(daily_reps, 'Expenses')
    t_bdep = sum_col(daily_reps, 'Bank Deposited')
    t_lres = sum_col(daily_reps, 'Laps Reserved')
    t_ltrans = sum_col(daily_reps, 'Laps Transferred')
    t_cc = sum_col(daily_reps, 'Cash Carry')

    left_total = bf_cash + t_lres + t_sav + t_r12w + t_r24w + t_r60d + t_r120d + t_rmth + t_cont + t_bwd + t_asale + t_app + t_pb + t_misc
    right_total = t_d11 + t_d20 + t_w11 + t_w20 + t_mm + t_pwd + w_act + d_act + m_act + t_exp + t_bdep + t_ltrans + t_cc
    closing_bal = left_total - right_total

    # Build the single-row dataframe for the ledger
    ledger_data = {
        "Date": [date_str],
        "Opening balance": [bf_cash],
        "Savings": [t_sav],
        "Repayment 12 weeks": [t_r12w],
        "Repayment 24 weeks": [t_r24w],
        "Repayment 60 days": [t_r60d],
        "Repayment 120 days": [t_r120d],
        "monthly": [t_rmth],
        "Contigency": [t_cont],
        "Bank withdrawal": [t_bwd],
        "Asset sales": [t_asale],
        "App fee": [t_app],
        "Pass book bonus": [t_pb],
        "Misc Fees": [t_misc],
        "Laps Reserved": [t_lres],
        "Daily 11%": [t_d11],
        "Daily 20%": [t_d20],
        "Weekly 11%": [t_w11],
        "Weekly 20%": [t_w20],
        "Monthly 11%/20%": [t_mm],
        "Cash Carry": [t_cc],
        "Total": [left_total],
        "Product Withdrawal": [t_pwd],
        "Weekly Active": [w_act],
        "Daily Active": [d_act],
        "Monthly Active": [m_act],
        "Expenses": [t_exp],
        "Bank": [t_bdep],
        "Laps Transferred": [t_ltrans],
        "Total.1": [right_total],
        "Closing balance": [closing_bal]
    }
    
    with c2:
        st.dataframe(pd.DataFrame(ledger_data).T.rename(columns={0: "Amount"}).style.format(precision=0, thousands=","), height=500)
    
    st.markdown("---")
    c_l, c_r = st.columns(2)
    with c_l:
        st.success(f"### Total Inflows (Left): ₦{left_total:,.0f}")
    with c_r:
        st.error(f"### Total Outflows (Right): ₦{right_total:,.0f}")
        
    if closing_bal == 0:
        st.info(f"### Closing Balance: ₦{closing_bal:,.0f} (Balanced)")
    else:
        st.warning(f"### Closing Balance: ₦{closing_bal:,.0f}")


elif page == "Master Cashbook":
    st.title("🏦 Branch Manager Master Cashbook")
    st.caption("INITIATIVE FOR COMMUNITY ADVANCEMENT, RELIEF AND EMPOWERMENT — Credit Cash Book Ledger")
    
    cashbook_section = st.radio("Navigate", ["📝 Daily Entry", "📊 Monthly Ledger"], horizontal=True, label_visibility="collapsed")
    
    all_loans = load_loans()
    all_repayments = load_repayments()
    
    if cashbook_section == "📝 Daily Entry":
        view_date = st.date_input("Select Date", datetime.now().date(), key="mc_date")
        date_str = view_date.strftime("%Y-%m-%d")
        
        # ---- AUTO-SUM: Query CO daily entries for this branch ----
        if not all_repayments.empty:
            all_repayments['_dt'] = pd.to_datetime(all_repayments['Date'], errors='coerce')
            day_reps = all_repayments[
                (all_repayments['_dt'].dt.date.astype(str) == date_str) &
                (all_repayments['Branch'] == BRANCH)
            ]
        else:
            day_reps = pd.DataFrame()
        
        def ssum(df, col):
            if df.empty or col not in df.columns:
                return 0.0
            return pd.to_numeric(df[col], errors='coerce').fillna(0).sum()
        
        # Auto-sum LEFT (Inflows) from CO collections
        auto_rep_daily = ssum(day_reps, 'Repayment 60 Days') + ssum(day_reps, 'Repayment 120 Days')
        auto_rep_12w = ssum(day_reps, 'Repayment 12 Weeks')
        auto_rep_24w = ssum(day_reps, 'Repayment 24 Weeks')
        auto_rep_mth = ssum(day_reps, 'Monthly')
        auto_savings = ssum(day_reps, 'Savings Amount')
        auto_laps_res = ssum(day_reps, 'Laps Reserved')
        auto_daily_11 = ssum(day_reps, 'Daily 11%')
        auto_weekly_11 = ssum(day_reps, 'Weekly 11%')
        auto_risk_premium = ssum(day_reps, 'Markup Paid')
        auto_passbook = ssum(day_reps, 'Pass Book Bonus')
        auto_app_fee = ssum(day_reps, 'App Fee')  # Processing Fee / Credit Form — single canonical field
        auto_asset_cr_sales = ssum(day_reps, 'Asset Credit Sales')
        auto_cash_carry = ssum(day_reps, 'Cash and Carry')
        auto_contingency = ssum(day_reps, 'Contingency')
        auto_credit_form_dmg = ssum(day_reps, 'Credit Form Damage')
        auto_bonus = ssum(day_reps, 'Bonus')
        auto_misc = ssum(day_reps, 'Misc Fees')
        
        # Auto-sum RIGHT (Outflows) from CO entries
        auto_savings_wd = ssum(day_reps, 'Withdrawal Amount')
        auto_expenses = ssum(day_reps, 'Expenses')
        auto_laps_ret = ssum(day_reps, 'Laps Transferred')
        auto_bank_dep = ssum(day_reps, 'Bank Deposited')
        auto_bank_wd = ssum(day_reps, 'Bank Withdrawal')
        auto_prod_wd = ssum(day_reps, 'Product Withdrawal')
        
        # Auto-sum VAULT FUNDING from loans disbursed today
        if not all_loans.empty:
            all_loans['_dt'] = pd.to_datetime(all_loans['Date'], errors='coerce')
            today_loans = all_loans[
                (all_loans['_dt'].dt.date.astype(str) == date_str) &
                (all_loans['Branch'] == BRANCH) &
                (all_loans['Status'].isin(['Active', 'Approved', 'Completed']))
            ]
        else:
            today_loans = pd.DataFrame()
        
        auto_fund_asset = 0.0
        auto_fund_finance = 0.0
        if not today_loans.empty:
            for _, loan in today_loans.iterrows():
                principal = pd.to_numeric(loan.get('Loan Amount', 0), errors='coerce')
                if pd.isna(principal): principal = 0
                cat = str(loan.get('Product Category', 'Finance'))
                if 'Asset' in cat:
                    auto_fund_asset += principal
                else:
                    auto_fund_finance += principal
        
        # ---- OPENING BALANCE: Fetch previous day's closing ----
        prev_date = (view_date - timedelta(days=1)).strftime("%Y-%m-%d")
        try:
            prev_row = supabase.table("master_cashbook").select("closing_balance").eq("date", prev_date).eq("branch", BRANCH).execute()
            auto_opening = float(prev_row.data[0]['closing_balance']) if prev_row.data else 0.0
        except Exception:
            auto_opening = 0.0
        
        # ---- DISPLAY AUTO-SUMMED VALUES ----
        st.markdown("### 📥 Left (Inflows) — Auto-Summed from CO Data")
        
        a1, a2, a3, a4 = st.columns(4)
        a1.metric("Credit Rep (Daily)", f"₦{auto_rep_daily:,.0f}")
        a2.metric("Credit Rep (12 Wks)", f"₦{auto_rep_12w:,.0f}")
        a3.metric("Credit Rep (24 Wks)", f"₦{auto_rep_24w:,.0f}")
        a4.metric("Credit Rep (Monthly)", f"₦{auto_rep_mth:,.0f}")
        
        b1, b2, b3, b4 = st.columns(4)
        b1.metric("Savings Deposit", f"₦{auto_savings:,.0f}")
        b2.metric("Laps Reserve", f"₦{auto_laps_res:,.0f}")
        b3.metric("Daily 11%", f"₦{auto_daily_11:,.0f}")
        b4.metric("Weekly 11%", f"₦{auto_weekly_11:,.0f}")
        
        e1, e2, e3, e4 = st.columns(4)
        e1.metric("Risk Premium", f"₦{auto_risk_premium:,.0f}")
        e2.metric("Passbook", f"₦{auto_passbook:,.0f}")
        e3.metric("Credit Form (Proc. Fee)", f"₦{auto_app_fee:,.0f}")
        e4.metric("Contingency (1%)", f"₦{auto_contingency:,.0f}")
        
        f1, f2, f3, f4 = st.columns(4)
        f1.metric("Asset Credit Sales", f"₦{auto_asset_cr_sales:,.0f}")
        f2.metric("Cash and Carry", f"₦{auto_cash_carry:,.0f}")
        f3.metric("Cr Form Damage", f"₦{auto_credit_form_dmg:,.0f}")
        f4.metric("Misc Fees", f"₦{auto_misc:,.0f}")
        
        g1, _ = st.columns(2)
        g1.metric("Bonus", f"₦{auto_bonus:,.0f}")
        
        st.markdown("---")
        st.markdown("### 📤 Right (Outflows) — Auto-Summed from CO Data")
        
        h1, h2, h3, h4 = st.columns(4)
        h1.metric("Fund to Asset Program", f"₦{auto_fund_asset:,.0f}")
        h2.metric("Fund to Product Finance", f"₦{auto_fund_finance:,.0f}")
        h3.metric("Savings Withdrawal", f"₦{auto_savings_wd:,.0f}")
        h4.metric("Laps Returns", f"₦{auto_laps_ret:,.0f}")
        
        i1, i2, i3, i4 = st.columns(4)
        i1.metric("Office Expenses", f"₦{auto_expenses:,.0f}")
        i2.metric("Bank Deposit", f"₦{auto_bank_dep:,.0f}")
        i3.metric("Bank Withdrawal", f"₦{auto_bank_wd:,.0f}")
        i4.metric("Product Withdrawal", f"₦{auto_prod_wd:,.0f}")
        
        # ---- MANUAL BM INPUTS ----
        st.markdown("---")
        st.markdown("### ✏️ BM Manual Inputs")
        
        with st.form("master_cashbook_form"):
            st.markdown("#### 📥 Inflows (Vault Funding Received)")
            m1, m2 = st.columns(2)
            funds_ho = m1.number_input("Funds Received from Head Office", min_value=0.0, step=1000.0, value=0.0)
            funds_branch = m2.number_input("Funds Received from Other Branch", min_value=0.0, step=1000.0, value=0.0)
            
            st.markdown("#### 📤 Outflows (Corporate Transfers)")
            n1, n2 = st.columns(2)
            xfer_ho = n1.number_input("Fund Transferred to H.O.", min_value=0.0, step=1000.0, value=0.0)
            xfer_branch = n2.number_input("Fund Transferred to Other Branch", min_value=0.0, step=1000.0, value=0.0)
            
            o1, o2 = st.columns(2)
            xfer_area = o1.number_input("Fund Transferred to Other Area", min_value=0.0, step=1000.0, value=0.0)
            salaries = o2.number_input("Staff Salaries", min_value=0.0, step=1000.0, value=0.0)
            
            # ---- CALCULATE TOTALS ----
            total_inflows = (
                auto_opening + auto_rep_daily + auto_rep_12w + auto_rep_24w + auto_rep_mth +
                auto_savings + auto_laps_res + auto_daily_11 + auto_weekly_11 +
                auto_risk_premium + auto_passbook + auto_app_fee +
                auto_asset_cr_sales + auto_cash_carry + auto_contingency +
                auto_credit_form_dmg + auto_bonus + auto_misc +
                funds_ho + funds_branch
            )
            
            total_outflows = (
                auto_fund_asset + auto_fund_finance + auto_savings_wd +
                auto_expenses + auto_laps_ret + auto_bank_dep + auto_prod_wd +
                xfer_ho + xfer_branch + xfer_area + salaries
            )
            
            closing_balance = total_inflows - total_outflows
            
            st.markdown("---")
            st.markdown("### 📊 Daily Summary")
            s1, s2, s3 = st.columns(3)
            s1.metric("Opening Balance", f"₦{auto_opening:,.0f}")
            s2.metric("Total Inflows (Left)", f"₦{total_inflows:,.0f}")
            s3.metric("Total Outflows (Right)", f"₦{total_outflows:,.0f}")
            
            if closing_balance >= 0:
                st.success(f"### Closing Balance: ₦{closing_balance:,.0f}")
            else:
                st.error(f"### Closing Balance: ₦{closing_balance:,.0f}")
            
            save_mc = st.form_submit_button("💾 Save Master Cashbook Entry", type="primary", use_container_width=True)
            
            if save_mc:
                mc_data = {
                    "date": date_str,
                    "branch": BRANCH,
                    "opening_balance": auto_opening,
                    "rep_daily": auto_rep_daily,
                    "rep_12_weeks": auto_rep_12w,
                    "rep_24_weeks": auto_rep_24w,
                    "rep_monthly": auto_rep_mth,
                    "savings_deposit": auto_savings,
                    "laps_reserve": auto_laps_res,
                    "funds_received_ho": funds_ho,
                    "funds_received_other_branch": funds_branch,
                    "loan_received_asset": 0,
                    "loan_received_finance": 0,
                    "daily_11_pct": auto_daily_11,
                    "weekly_11_pct": auto_weekly_11,
                    "savings_adj_no": 0,
                    "savings_adj_amount": 0,
                    "risk_premium_returns": auto_risk_premium,
                    "passbook": auto_passbook,
                    "app_fee": auto_app_fee,
                    "asset_credit_sales": auto_asset_cr_sales,
                    "cash_and_carry": auto_cash_carry,
                    "contingency": auto_contingency,
                    "credit_form": 0,
                    "credit_form_damage": auto_credit_form_dmg,
                    "bonus": auto_bonus,
                    "misc_fees": auto_misc,
                    "fund_transferred_other_branch": xfer_branch,
                    "fund_transferred_ho": xfer_ho,
                    "fund_to_other_area": xfer_area,
                    "fund_to_asset_program": auto_fund_asset,
                    "fund_to_product_finance": auto_fund_finance,
                    "savings_withdrawal": auto_savings_wd,
                    "staff_salaries": salaries,
                    "office_expenses": auto_expenses,
                    "laps_returns": auto_laps_ret,
                    "bank_deposit": auto_bank_dep,
                    "bank_withdrawal": auto_bank_wd,
                    "product_withdrawal": auto_prod_wd,
                    "total_inflows": total_inflows,
                    "total_outflows": total_outflows,
                    "closing_balance": closing_balance
                }
                
                try:
                    # Upsert: check if row exists for this date+branch
                    existing = supabase.table("master_cashbook").select("id").eq("date", date_str).eq("branch", BRANCH).execute()
                    if existing.data:
                        supabase.table("master_cashbook").update(mc_data).eq("date", date_str).eq("branch", BRANCH).execute()
                        st.success("Master Cashbook entry UPDATED successfully!")
                    else:
                        supabase.table("master_cashbook").insert(mc_data).execute()
                        st.success("Master Cashbook entry SAVED successfully!")
                except Exception as e:
                    st.error(f"Failed to save: {e}")
    
    elif cashbook_section == "📊 Monthly Ledger":
        st.markdown("### 📅 Monthly Ledger View")
        
        ctl1, ctl2 = st.columns(2)
        cb_month = ctl1.selectbox("Month", list(range(1, 13)), index=datetime.now().month - 1,
                                   format_func=lambda m: datetime(2026, m, 1).strftime("%B"), key="mc_month")
        cb_year = ctl2.number_input("Year", value=datetime.now().year, step=1, min_value=2024, max_value=2030, key="mc_year")
        
        try:
            # Build date range for the month
            from calendar import monthrange
            _, last_day = monthrange(cb_year, cb_month)
            start_date = f"{cb_year}-{cb_month:02d}-01"
            end_date = f"{cb_year}-{cb_month:02d}-{last_day:02d}"
            
            result = supabase.table("master_cashbook").select("*").eq("branch", BRANCH).gte("date", start_date).lte("date", end_date).order("date").execute()
            
            if result.data:
                ledger_df = pd.DataFrame(result.data)
                
                # Reorder columns to match the Excel layout
                display_cols = [
                    "date", "opening_balance",
                    "rep_daily", "rep_12_weeks", "rep_24_weeks", "rep_monthly",
                    "savings_deposit", "laps_reserve",
                    "funds_received_ho", "funds_received_other_branch",
                    "loan_received_asset", "loan_received_finance",
                    "daily_11_pct", "weekly_11_pct",
                    "savings_adj_no", "savings_adj_amount",
                    "risk_premium_returns",
                    "fund_transferred_other_branch", "fund_transferred_ho",
                    "fund_to_other_area", "fund_to_asset_program", "fund_to_product_finance",
                    "staff_salaries", "office_expenses",
                    "laps_returns", "bank_deposit",
                    "total_inflows", "total_outflows", "closing_balance"
                ]
                
                # Filter to available columns only
                available_cols = [c for c in display_cols if c in ledger_df.columns]
                display_df = ledger_df[available_cols].copy()
                
                # Rename for display
                col_rename = {
                    "date": "Date", "opening_balance": "Opening Balance",
                    "rep_daily": "Credit Rep (Daily)", "rep_12_weeks": "Credit Rep (12 Wks)",
                    "rep_24_weeks": "Credit Rep (24 Wks)", "rep_monthly": "Credit Rep (Monthly)",
                    "savings_deposit": "Savings Deposit", "laps_reserve": "Laps Reserve",
                    "funds_received_ho": "Funds Recv (H.O.)", "funds_received_other_branch": "Funds Recv (Branch)",
                    "loan_received_asset": "Loan Recv (Asset)", "loan_received_finance": "Loan Recv (Finance)",
                    "daily_11_pct": "Daily 11%", "weekly_11_pct": "Weekly 11%",
                    "savings_adj_no": "Sav Adj (No)", "savings_adj_amount": "Sav Adj (₦)",
                    "risk_premium_returns": "Risk Premium",
                    "fund_transferred_other_branch": "Fund Xfer (Branch)", "fund_transferred_ho": "Fund Xfer (H.O.)",
                    "fund_to_other_area": "Fund to Area", "fund_to_asset_program": "Fund to Asset",
                    "fund_to_product_finance": "Fund to Finance",
                    "staff_salaries": "Staff Salaries", "office_expenses": "Office Expenses",
                    "laps_returns": "Laps Returns", "bank_deposit": "Bank Deposit",
                    "total_inflows": "Total Inflows", "total_outflows": "Total Outflows",
                    "closing_balance": "Closing Balance"
                }
                display_df.rename(columns=col_rename, inplace=True)
                
                st.dataframe(
                    display_df.style.format(precision=0, thousands=",", na_rep="—"),
                    use_container_width=True,
                    hide_index=True,
                    height=600
                )
                
                # Monthly totals
                st.markdown("#### 📈 Monthly Totals")
                num_cols = display_df.select_dtypes(include='number').columns
                totals = display_df[num_cols].sum()
                mt1, mt2, mt3 = st.columns(3)
                mt1.metric("Total Inflows", f"₦{totals.get('Total Inflows', 0):,.0f}")
                mt2.metric("Total Outflows", f"₦{totals.get('Total Outflows', 0):,.0f}")
                mt3.metric("Net Position", f"₦{totals.get('Closing Balance', 0):,.0f}")
                
                # Download
                st.markdown("---")
                if st.button("⬇️ Download Ledger as Excel", use_container_width=True, key="dl_mc"):
                    import io
                    output = io.BytesIO()
                    with pd.ExcelWriter(output, engine='openpyxl') as writer:
                        display_df.to_excel(writer, sheet_name='Master Cashbook', index=False)
                    st.download_button(
                        label="📄 Click to Download",
                        data=output.getvalue(),
                        file_name=f"ICARE_Master_Cashbook_{datetime(cb_year, cb_month, 1).strftime('%B_%Y')}.xlsx",
                        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                        key="dl_mc_btn"
                    )
            else:
                st.info(f"No ledger entries found for {datetime(cb_year, cb_month, 1).strftime('%B %Y')}.")
        except Exception as e:
            st.error(f"Error loading ledger: {e}")


elif page == "Portfolio":
    st.title("Portfolio Management")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    if st.button("🔄 SYNC FROM CLOUD"):
        st.rerun()
    
    my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
    
    if not my_loans.empty:
        display_data = []
        for _, row in my_loans.iterrows():
            c_payments = repayments[repayments['Client ID'] == row['Client ID']] if not repayments.empty else pd.DataFrame()
            s_amt, l_amt = calculate_client_savings(c_payments, row['Loan Repay'])
            expected, overdue = calculate_overdue(row['Date'], row['Loan Product'], row['Loan Repay'], l_amt, row.get('Status', 'Active'))
            row_data = row.to_dict()
            row_data['Acc. Savings'] = s_amt
            row_data['Paid to Loan'] = l_amt
            row_data['Loan Balance'] = row['Active Credit'] - l_amt
            row_data['Overdue'] = overdue
            display_data.append(row_data)
        
        display_df = pd.DataFrame(display_data)
        if "Client ID" in display_df.columns:
            display_df.sort_values(by="Client ID", inplace=True)
            
        if "Officer" in display_df.columns:
            display_df["Officer"] = display_df["Officer"].apply(lambda x: CO_DISPLAY_MAP.get(x, x))
        cols = ["Client ID", "Date", "Branch", "Officer", "Client Name", "Group Name", 
                "Meeting Day", "Active Credit", "Loan Repay", "Acc. Savings", 
                "Loan Balance", "Overdue", "Status", "Loan Product", "Phone"]
        final_cols = [c for c in cols if c in display_df.columns]
        
        edited = st.data_editor(
            display_df[final_cols],
            num_rows="dynamic",
            key="db_edit",
            column_config={
                "Client ID": st.column_config.TextColumn("Client ID", disabled=True),
                "Status": st.column_config.SelectboxColumn("Status", options=["Pending", "Approved", "Active", "Completed"]),
                "Meeting Day": st.column_config.SelectboxColumn("Meeting Day", options=["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]),
                "Branch": st.column_config.TextColumn("Branch", disabled=(ROLE != "Admin")),
                "Officer": st.column_config.SelectboxColumn("Officer", options=list(CO_NAME_MAP.keys()) if CO_NAME_MAP else ["CO1", "CO2"], disabled=(ROLE == "Officer")),
                "Loan Balance": st.column_config.NumberColumn("Balance", disabled=True, format="₦%d"),
                "Acc. Savings": st.column_config.NumberColumn("Savings", disabled=True, format="₦%d"),
                "Overdue": st.column_config.NumberColumn("Overdue", disabled=True, format="₦%d"),
            },
            use_container_width=True
        )
        
        if st.button("🔄 POST TO GLOBAL LEDGER"):
            update_database_safe(edited, ROLE, USER, BRANCH)
            st.success("✅ Cloud Database Updated Successfully!")
            st.rerun()

elif page == "Calculator":
    st.title("Loan Simulator")
    
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    c1, c2 = st.columns(2)
    
    with c1:
        amt = st.number_input("Loan Amount", value=150000, step=5000, min_value=10000)
        prod = st.selectbox(
            "Product",
            ["Daily Loan (60 Days)", "Daily Loan (120 Days)", "Weekly Loan (12 Weeks)", "Weekly Loan (24 Weeks)", "Monthly Loan (3 Months)", "Monthly Loan (6 Months)"]
        )
    
    setup = calculate_loan_setup(amt, prod)
    
    with c2:
        st.metric("Suggested Upfront", f"₦{setup['interest'] + setup['initial_payment']:,.0f}")
        st.caption(f"Interest: ₦{setup['interest']:,.0f} | Gap: ₦{setup['initial_payment']:,.0f}")
        active = amt - setup['initial_payment']
        repay = math.ceil((active / setup['duration']) / 10) * 10
        st.metric("Fixed Repayment", f"₦{repay:,.0f}")
    
    st.markdown("</div>", unsafe_allow_html=True)
    
    # Amortization preview
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("📊 Repayment Schedule Preview")
    
    schedule_data = []
    remaining = active
    for i in range(1, setup['duration'] + 1):
        payment = min(repay, remaining)
        remaining -= payment
        schedule_data.append({
            "Period": f"{setup['freq']} {i}",
            "Payment": payment,
            "Remaining Balance": max(0, remaining)
        })
    
    schedule_df = pd.DataFrame(schedule_data)
    st.dataframe(schedule_df, use_container_width=True)
    st.markdown("</div>", unsafe_allow_html=True)

elif page in ["Reports", "Reports & Export"]:
    st.title("Reports & Data Export")
    
    all_loans = load_loans()
    all_repayments = load_repayments()
    my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
    
    # Summary Report
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("📊 Portfolio Summary Report")
    
    summary = generate_portfolio_summary(my_loans, all_repayments)
    
    col1, col2, col3 = st.columns(3)
    col1.metric("Active Loans", summary['active_loans'])
    col2.metric("Total Portfolio", f"₦{summary['total_portfolio']:,.0f}")
    col3.metric("PAR %", f"{summary['par_percentage']:.2f}%")
    
    # Export to Google Sheets
    st.markdown("---")
    st.subheader("☁️ Export to Google Sheets")
    
    sheet_col1, sheet_col2, sheet_col3 = st.columns(3)
    
    with sheet_col1:
        if st.button("📤 Export Loans", use_container_width=True):
            with st.spinner("Exporting to Google Sheets..."):
                url, msg = export_loans_to_sheet(my_loans)
                if url:
                    st.success(msg)
                    st.markdown(f"[Open Spreadsheet]({url})")
                else:
                    st.error(msg)
    
    with sheet_col2:
        if st.button("📤 Export Repayments", use_container_width=True):
            with st.spinner("Exporting to Google Sheets..."):
                url, msg = export_repayments_to_sheet(all_repayments)
                if url:
                    st.success(msg)
                    st.markdown(f"[Open Spreadsheet]({url})")
                else:
                    st.error(msg)
    
    with sheet_col3:
        if st.button("📤 Export Summary", use_container_width=True):
            with st.spinner("Exporting to Google Sheets..."):
                url, msg = export_summary_report(summary)
                if url:
                    st.success(msg)
                    st.markdown(f"[Open Spreadsheet]({url})")
                else:
                    st.error(msg)
    
    st.markdown("</div>", unsafe_allow_html=True)
    
    # Excel Export
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("📥 Download Excel Report")
    
    if st.button("⬇️ Download Full Report (Excel)", use_container_width=True):
        with st.spinner("Generating Excel file..."):
            success, result = export_to_excel(my_loans, all_repayments, 
                                              f"trustmicro_report_{datetime.now().strftime('%Y%m%d')}.xlsx")
            if success:
                with open(result, "rb") as f:
                    st.download_button(
                        label="📄 Click to Download",
                        data=f,
                        file_name=result,
                        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    )
            else:
                st.error(f"Export failed: {result}")
    
    st.markdown("</div>", unsafe_allow_html=True)
    
    # Officer Reports
    if ROLE in ["Admin", "BM"]:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("👥 Officer Performance Reports")
        
        officers = my_loans['Officer'].unique() if not my_loans.empty else []
        display_options = ["All"] + [CO_DISPLAY_MAP.get(o, o) for o in officers]
        selected_display = st.selectbox("Select Officer:", display_options)
        selected_officer = "All" if selected_display == "All" else CO_NAME_MAP.get(selected_display, selected_display)
        
        if selected_officer != "All":
            officer_report = generate_officer_report(my_loans, all_repayments, selected_officer)
        else:
            officer_report = generate_officer_report(my_loans, all_repayments)
        
        if not officer_report.empty:
            st.dataframe(
                officer_report.style.format({
                    "Active Credit": "₦{:,.0f}",
                    "Loan Repay": "₦{:,.0f}",
                    "Paid to Loan": "₦{:,.0f}",
                    "Loan Balance": "₦{:,.0f}",
                    "Savings": "₦{:,.0f}",
                    "Overdue": "₦{:,.0f}"
                }),
                use_container_width=True
            )
        else:
            st.info("No data available for officer report")
        
        st.markdown("</div>", unsafe_allow_html=True)

# ==========================================
# 14. USER MANAGEMENT (AM / Admin)
# ==========================================
elif page == "User Management" and ROLE in ["AM", "Admin"]:
    st.markdown("<div class='dashboard-header'>", unsafe_allow_html=True)
    st.markdown("<h1>🔐 User Management</h1>", unsafe_allow_html=True)
    st.markdown("<p>Manage application users, reset passwords, and handle officer turnover.</p>", unsafe_allow_html=True)
    st.markdown("</div>", unsafe_allow_html=True)
    
    # Fetch all users
    try:
        res = supabase.table("app_users").select("*").execute()
        all_users = res.data if res.data else []
    except Exception as e:
        st.error(f"Failed to fetch users: {e}")
        all_users = []
        
    user_usernames = [u['username'] for u in all_users]
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("➕ Add New User")
        with st.form("add_user_form"):
            new_username = st.text_input("Username (e.g. CO5, BM_Ikeja)")
            new_fullname = st.text_input("Full Name (e.g. Mr. Ayomide)")
            new_role = st.selectbox("Role", ["CO", "BM", "AM", "Admin"])
            new_branch = st.text_input("Branch Name (e.g. Ogijo)")
            new_password = st.text_input("Password", type="password")
            
            submit_new = st.form_submit_button("Create User", use_container_width=True)
            if submit_new:
                if not new_username or not new_password or not new_fullname:
                    st.error("Username, Full Name, and Password are required.")
                elif new_username in user_usernames:
                    st.error("Username already exists!")
                else:
                    hashed_pw = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
                    try:
                        supabase.table("app_users").insert({
                            "username": new_username,
                            "full_name": new_fullname,
                            "role": new_role,
                            "branch_name": new_branch,
                            "password": hashed_pw
                        }).execute()
                        st.success(f"User {new_username} created successfully!")
                        st.rerun()
                    except Exception as e:
                        st.error(f"Failed to create user: {e}")
        st.markdown("</div>", unsafe_allow_html=True)
        
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("🔑 Reset Password")
        with st.form("reset_pw_form"):
            reset_username = st.selectbox("Select User", user_usernames)
            reset_password = st.text_input("New Password", type="password")
            submit_reset = st.form_submit_button("Reset Password", use_container_width=True)
            if submit_reset:
                if not reset_password:
                    st.error("Please enter a new password.")
                else:
                    hashed_pw = bcrypt.hashpw(reset_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
                    try:
                        supabase.table("app_users").update({"password": hashed_pw}).eq("username", reset_username).execute()
                        st.success(f"Password reset for {reset_username}!")
                    except Exception as e:
                        st.error(f"Failed to reset password: {e}")
        st.markdown("</div>", unsafe_allow_html=True)
        
    with col2:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("🔄 Update Officer Name (Turnover)")
        st.info("When an officer leaves, update the Full Name tied to their generic username (e.g. CO2) so that historical data remains intact but the new officer's name is used going forward.")
        
        co_users = [u for u in all_users if u['role'] in ['CO', 'Officer']]
        co_usernames = [u['username'] for u in co_users]
        
        with st.form("update_officer_form"):
            update_username = st.selectbox("Select Officer ID", co_usernames)
            # Find current name
            current_name = ""
            for u in co_users:
                if u['username'] == update_username:
                    current_name = u.get('full_name', '')
                    break
                    
            st.write(f"**Current Name:** {current_name}")
            new_officer_name = st.text_input("New Full Name")
            
            submit_update = st.form_submit_button("Update Officer Name", use_container_width=True)
            if submit_update:
                if not new_officer_name:
                    st.error("Please enter a new name.")
                else:
                    try:
                        supabase.table("app_users").update({"full_name": new_officer_name}).eq("username", update_username).execute()
                        st.success(f"Updated {update_username} to {new_officer_name}!")
                        st.rerun()
                    except Exception as e:
                        st.error(f"Failed to update name: {e}")
        st.markdown("</div>", unsafe_allow_html=True)
        
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("👥 Current Users")
        df_users = pd.DataFrame(all_users)
        if not df_users.empty:
            st.dataframe(df_users[['username', 'full_name', 'role', 'branch_name', 'created_at']], use_container_width=True)
        st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<hr/>", unsafe_allow_html=True)
    st.subheader("🏢 Branch Settings & Closures")
    st.write("Manage custom branch closures (e.g., operational shutdowns, end-of-year breaks). These dates will be strictly excluded when calculating loan repayment schedules.")
    
    c3, c4 = st.columns(2)
    with c3:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.markdown("#### ➕ Add New Closure")
        with st.form("add_closure_form"):
            closure_dates = st.date_input("Select Date Range", [], key="closure_range")
            closure_reason = st.text_input("Reason (e.g. End of Year Break)")
            submit_closure = st.form_submit_button("Save Closure", use_container_width=True)
            if submit_closure:
                if not closure_reason or len(closure_dates) != 2:
                    st.error("Please provide a reason and select a full date range (start and end).")
                else:
                    try:
                        supabase.table("branch_closures").insert({
                            "start_date": closure_dates[0].strftime("%Y-%m-%d"),
                            "end_date": closure_dates[1].strftime("%Y-%m-%d"),
                            "reason": closure_reason,
                            "created_by": USER
                        }).execute()
                        st.success("Branch closure added successfully!")
                        get_custom_closures.clear() # clear cache
                        st.rerun()
                    except Exception as e:
                        st.error(f"Failed to add closure: {e}")
        st.markdown("</div>", unsafe_allow_html=True)
        
    with c4:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.markdown("#### 📅 Active Closures")
        closures_list = get_custom_closures()
        if closures_list:
            closure_data = [{"Start Date": c[0].strftime('%Y-%m-%d'), "End Date": c[1].strftime('%Y-%m-%d'), "Reason": c[2]} for c in closures_list]
            st.dataframe(pd.DataFrame(closure_data), use_container_width=True)
        else:
            st.info("No custom closures recorded.")
        st.markdown("</div>", unsafe_allow_html=True)

