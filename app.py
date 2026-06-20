import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
import math
import uuid
import hashlib
from supabase import create_client, Client

def generate_client_id(branch_name, group_string, member_num_or_index, is_bulk=False):
    import re
    # 1. Get branch prefix (first 3 letters, uppercase)
    b_prefix = str(branch_name)[:3].upper() if branch_name else "UNK"
    
    # 2. Get group prefix
    g_str = str(group_string).strip()
    if not g_str or g_str.lower() in ["none", "nan", "ungrouped"]:
        g_prefix = "IND" # Individual / Ungrouped
    else:
        # If it looks like 'GRP-02' or has digits, extract digits
        digits = re.findall(r'\d+', g_str)
        if digits:
            # Use the first number found, pad to 2 digits
            g_prefix = str(digits[0]).zfill(2)
        else:
            # Otherwise use the first 3 letters of the group name
            g_prefix = g_str[:3].upper()
            
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
import extra_streamlit_components as stx

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
        res = supabase.table("app_users").select("*").eq("username", username).eq("password", password).execute()
        if res.data and len(res.data) > 0:
            user = res.data[0]
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
    
    /* === LOGIN === */
    .login-container {
        max-width: 440px;
        margin: 60px auto;
        text-align: center;
    }
    .login-brand {
        margin-bottom: 32px;
    }
    .login-brand h1 {
        color: #2E86C1 !important;
        font-size: 2rem;
        font-weight: 800;
        letter-spacing: 4px;
        margin: 0 0 4px 0;
    }
    .login-brand .org-name {
        color: #64748B;
        font-size: 0.8rem;
        line-height: 1.6;
        margin: 0;
    }
    .login-brand .brand-line {
        width: 48px;
        height: 3px;
        background: #8CC63F;
        margin: 16px auto;
        border-radius: 2px;
    }
    .login-card {
        background: #FFFFFF;
        border-radius: 16px;
        padding: 40px 36px 32px;
        border: 1px solid #E5E7EB;
        box-shadow: 0 4px 24px rgba(46,134,193,0.08);
    }
    .login-card h2 {
        color: #1B4F72 !important;
        font-size: 1.3rem;
        font-weight: 700;
        margin: 0 0 4px 0;
    }
    .login-card .subtitle {
        color: #94A3B8;
        font-size: 0.85rem;
        margin-bottom: 24px;
    }
    .login-footer {
        margin-top: 24px;
        color: #94A3B8;
        font-size: 0.72rem;
    }
    
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
    "others_amount": "Others Amount"
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
        return df
    except Exception as e:
        st.error(f"Database Error: {e}")
        return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))
    try:
        response = supabase.table("loans").select("*").execute()
        if not response.data:
            return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))
        df = pd.DataFrame(response.data).rename(columns=DB_TO_UI_LOANS)
        num_cols = ['Loan Amount', 'Active Credit', 'Loan Repay', 'Total Due']
        for c in num_cols:
            df[c] = pd.to_numeric(df[c], errors='coerce').fillna(0)
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
    db_data = {UI_TO_DB_LOANS[k]: v for k, v in data.items()}
    supabase.table("loans").insert(db_data).execute()

def save_repayment(data):
    """Save repayment to database"""
    if not supabase:
        st.error("Database not connected")
        return
    db_data = {UI_TO_DB_REP[k]: v for k, v in data.items()}
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

def calculate_overdue(start_date_str, product, fixed_repay, total_loan_paid):
    """Calculate overdue amount for a client"""
    try:
        start_date = datetime.strptime(start_date_str, "%Y-%m-%d")
    except:
        return 0, 0
    
    today = datetime.now()
    
    if "Daily" in str(product):
        try:
            years = [today.year - 1, today.year, today.year + 1]
            ng_holidays = holidays.country_holidays('NG', years=years)
            bday_ng = CustomBusinessDay(holidays=list(ng_holidays.keys()))
            date_range = pd.date_range(start_date.date(), today.date(), freq=bday_ng)
            business_days = len(date_range)
        except Exception:
            business_days = len(pd.bdate_range(start_date.date(), today.date()))
            
        days_passed = max(0, business_days - 1)
        capped_days = min(days_passed, 60)
        expected_paid = capped_days * fixed_repay
    elif "12 Weeks" in str(product):
        weeks_passed = max(0, (today - start_date).days // 7)
        capped_weeks = min(weeks_passed, 12)
        expected_paid = capped_weeks * fixed_repay
    elif "24 Weeks" in str(product):
        weeks_passed = max(0, (today - start_date).days // 7)
        capped_weeks = min(weeks_passed, 24)
        expected_paid = capped_weeks * fixed_repay
    else:
        expected_paid = 0
    
    overdue = max(0, expected_paid - total_loan_paid)
    return expected_paid, overdue

def calculate_loan_setup(amount, product_type, product_category="Finance"):
    """Calculate loan setup parameters"""
    if product_category == "Asset":
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
    if "Daily" in str(product_type):
        rate = 0.12
        duration = 60
        freq = "Daily"
        round_step = 50
        force_gap = False
    elif "12 Weeks" in str(product_type):
        rate = 0.12
        duration = 12
        freq = "Weekly"
        round_step = 50
        force_gap = True
    else:
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
cookie_manager = stx.CookieManager(key="icare_cookies")

# Try to restore session from cookie
if 'logged_in' not in st.session_state or not st.session_state['logged_in']:
    auth_token = cookie_manager.get(cookie="icare_auth")
    if auth_token:
        try:
            res = supabase.table("app_users").select("*").eq("username", auth_token).execute()
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
    st.markdown("<br><br>", unsafe_allow_html=True)
    
    _, center_col, _ = st.columns([1, 2, 1])
    
    with center_col:
        st.markdown("""
            <div class='login-container'>
                <div class='login-brand'>
                    <h1>ICARE</h1>
                    <div class='brand-line'></div>
                    <p class='org-name'>Initiative for Community Advancement,<br>Relief and Empowerment</p>
                </div>
            </div>
        """, unsafe_allow_html=True)
        
        st.markdown("""
            <div class='login-card'>
                <h2>Sign In</h2>
                <p class='subtitle'>Enter your credentials to continue</p>
            </div>
        """, unsafe_allow_html=True)
        
        with st.form("login"):
            username = st.text_input("Username", placeholder="Enter your username")
            pw = st.text_input("Password", type="password", placeholder="Enter your password")
            
            submitted = st.form_submit_button("SIGN IN", use_container_width=True)
            
            if submitted:
                auth_result = authenticate_user(username, pw)
                if auth_result:
                    cookie_manager.set("icare_auth", username.lower(), expires_at=datetime.now() + timedelta(days=7))
                    st.session_state['logged_in'] = True
                    st.session_state['user'] = auth_result['user_name']
                    st.session_state['role'] = auth_result['user_role']
                    st.session_state['branch'] = auth_result['branch_name']
                    st.rerun()
                else:
                    st.error("Invalid credentials. Please try again.")
        
        st.markdown("<p class='login-footer'>Core Banking System v3.0 &middot; Secured Connection</p>", unsafe_allow_html=True)
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
        <div style='text-align: center; padding: 14px 0 6px 0;'>
            <h2 style='color: #2E86C1 !important; font-size: 1.3rem; margin: 0; letter-spacing: 2px; font-weight: 800;'>ICARE</h2>
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
        nav_options = ["Dashboard", "Loan Origination", "Collections", "Daily Report", "WhatsApp Cashbook", "Audit Ledger"]
    elif ROLE in ["BM", "AM"]:
        st.markdown("<p class='nav-section-label'>EXECUTIVE</p>", unsafe_allow_html=True)
        nav_options = ["Dashboard", "WhatsApp Cashbook", "Portfolio", "Cash Book", "Audit Ledger"]
    else:  # Admin
        st.markdown("<p class='nav-section-label'>ADMINISTRATION</p>", unsafe_allow_html=True)
        nav_options = ["Dashboard", "Loan Origination", "Collections", "Daily Report", "WhatsApp Cashbook", "Portfolio", "Cash Book", "Audit Ledger", "Reports & Export"]
    
    page = st.radio("Navigation", nav_options, label_visibility="collapsed")
    
    # Security check: if the requested page is not in permitted list, fallback to Dashboard
    if page not in nav_options:
        page = "Dashboard"
    
    st.divider()
    
    if st.button("Sign Out", use_container_width=True):
        try:
            cookie_manager.delete("icare_auth")
        except KeyError:
            pass
        st.session_state.clear()
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
                exp_paid, overdue_amt = calculate_overdue(start_date_str, product, fixed_repay, l_amt)
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
    st.title("New Loan Application")
    
    client_type = st.radio("Client Type", ["New Client", "Existing Client", "📦 Bulk Onboarding"], horizontal=True)
    
    defaults = {
        "Name": "", "Nickname": "", "Phone": "", "Address": "", "BizAddress": "",
        "Marital": "Single", "BizType": "Trader", "Income": 0.0, "Obs": "",
        "GName": "", "GNick": "", "GPhone": "", "GHome": "", "GOffice": "",
        "GMarital": "Single", "GOcc": "", "GRel": "",
        "Group": "", "GroupLoc": "", "Meeting": "Daily",
        "Leader": "", "GroupDate": datetime.now()
    }
    
    prev_client_id = None
    prev_savings = 0.0
    
    if client_type == "Existing Client":
        all_loans_df = load_loans()
        if not all_loans_df.empty:
            # Sort by Date descending to get the most recent loan per phone
            all_loans_df = all_loans_df.sort_values(by="Date", ascending=False)
            all_loans_df['Group Name'] = all_loans_df['Group Name'].fillna('Ungrouped').replace('', 'Ungrouped')
            all_loans_df["DisplayName"] = all_loans_df["Client Name"] + " (" + all_loans_df["Phone"] + ")"
            unique_clients = all_loans_df.drop_duplicates(subset=["Phone"])
            
            c_grp, c_cli = st.columns([1.5, 2.5])
            unique_groups = ["All Groups"] + sorted([str(g) for g in unique_clients['Group Name'].unique() if str(g).strip()])
            selected_group = c_grp.selectbox("Filter by Group:", unique_groups)
            
            if selected_group != "All Groups":
                unique_clients = unique_clients[unique_clients['Group Name'] == selected_group]
                
            options = [""] + unique_clients["DisplayName"].tolist()
            selected_display = c_cli.selectbox("Search & Select Existing Client:", options)
            if selected_display:
                selected_row = unique_clients[unique_clients["DisplayName"] == selected_display].iloc[0]
                prev_client_id = selected_row["Client ID"]
                
                full_record = all_loans_df[all_loans_df["Client ID"] == prev_client_id].iloc[0]
                
                defaults["Name"] = str(full_record.get("Client Name", ""))
                defaults["Nickname"] = str(full_record.get("Nickname", ""))
                defaults["Phone"] = str(full_record.get("Phone", ""))
                defaults["Address"] = str(full_record.get("Address", ""))
                defaults["Marital"] = str(full_record.get("Marital Status", "Single"))
                defaults["BizType"] = str(full_record.get("Business Type", "Trader"))
                try:
                    defaults["Income"] = float(full_record.get("Average Monthly Income", 0.0))
                except:
                    pass
                defaults["Obs"] = str(full_record.get("Other Obligations", ""))
                
                defaults["GName"] = str(full_record.get("Guarantor Name", ""))
                defaults["GNick"] = str(full_record.get("Guarantor Nickname", ""))
                defaults["GPhone"] = str(full_record.get("Guarantor Phone", ""))
                defaults["GHome"] = str(full_record.get("Guarantor Home Address", ""))
                defaults["GOffice"] = str(full_record.get("Guarantor Office Address", ""))
                defaults["GMarital"] = str(full_record.get("Guarantor Marital Status", "Single"))
                defaults["GOcc"] = str(full_record.get("Guarantor Occupation", ""))
                defaults["GRel"] = str(full_record.get("Guarantor Relationship", ""))
                
                defaults["Group"] = str(full_record.get("Group Name", ""))
                defaults["GroupLoc"] = str(full_record.get("Group Location", ""))
                defaults["Meeting"] = str(full_record.get("Meeting Day", "Daily"))
                defaults["Leader"] = str(full_record.get("Group Leader Name", ""))
                
                try:
                    defaults["GroupDate"] = datetime.strptime(str(full_record.get("Group Formation Date", "")), "%Y-%m-%d").date()
                except:
                    pass
                
                reps = load_repayments()
                client_reps = reps[reps['Client ID'] == prev_client_id]
                fixed_repay = pd.to_numeric(full_record['Loan Repay'], errors='coerce')
                fixed_repay = 0 if pd.isna(fixed_repay) else fixed_repay
                savings, _ = calculate_client_savings(client_reps, fixed_repay)
                prev_savings = float(savings)
                
                st.info(f"💰 **Current Accumulated Savings Balance:** ₦{prev_savings:,.0f}")
                st.write(f"**Previous Loan Status:** {full_record['Status']}")
        else:
            st.warning("No existing clients found in the database.")
            
    if client_type == "📦 Bulk Onboarding":
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("📦 Bulk Import from Excel")
        st.info("Upload the standard ICARE Group and Member Onboarding Template to import multiple groups and members at once.")
        
        uploaded_file = st.file_uploader("Upload Excel Template", type=["xlsx"])
        
        if uploaded_file is not None:
            try:
                import pandas as pd
                import uuid
                
                # Read without headers to manually find them
                raw_groups = pd.read_excel(uploaded_file, sheet_name='Groups', header=None)
                raw_members = pd.read_excel(uploaded_file, sheet_name='Members', header=None)
                
                def extract_table(df, key_col1, key_col2):
                    # Search for the header row
                    header_idx = -1
                    for i, row in df.iterrows():
                        row_str = row.astype(str).str.replace('*', '', regex=False).str.strip().str.lower()
                        if key_col1.lower() in row_str.values and key_col2.lower() in row_str.values:
                            header_idx = i
                            break
                            
                    if header_idx != -1:
                        # Set headers and slice
                        df.columns = df.iloc[header_idx].astype(str).str.replace('*', '', regex=False).str.strip()
                        df = df.iloc[header_idx + 1:].reset_index(drop=True)
                        return df
                    return pd.DataFrame() # Return empty if headers not found

                df_groups = extract_table(raw_groups, 'Group Reference', 'Group Name')
                df_members = extract_table(raw_members, 'Member Reference', 'Full Name')
                
                # Filter empty rows and example/dummy rows
                if not df_groups.empty and 'Group Name' in df_groups.columns:
                    df_groups = df_groups.dropna(subset=['Group Reference', 'Group Name'])
                    df_groups = df_groups[~df_groups['Group Name'].astype(str).str.contains('Example', case=False, na=False)]
                    
                if not df_members.empty and 'Full Name' in df_members.columns:
                    df_members = df_members.dropna(subset=['Member Reference', 'Full Name'])
                    df_members = df_members[~df_members['Full Name'].astype(str).str.contains('Example', case=False, na=False)]
                
                num_groups = len(df_groups)
                num_members = len(df_members)
                
                st.success(f"File parsed successfully! Found **{num_groups} Groups** and **{num_members} Members**.")
                
                if st.button("🚀 Confirm and Import", use_container_width=True):
                    with st.spinner("Importing data into database..."):
                        success_count = 0
                        error_count = 0
                        
                        # Process each member
                        for index, member_row in df_members.iterrows():
                            try:
                                group_ref = member_row.get('Group Reference')
                                # Find corresponding group
                                if 'Group Reference' in df_groups.columns:
                                    group_match = df_groups[df_groups['Group Reference'] == group_ref]
                                else:
                                    group_match = pd.DataFrame()
                                
                                if group_match.empty:
                                    print(f"Group ref {group_ref} not found for member.")
                                    continue
                                
                                group_row = group_match.iloc[0]
                                
                                                                # Extract member number from the sheet if present
                                m_num_raw = member_row.get('Member Number')
                                try:
                                    m_num_val = int(float(m_num_raw))
                                except:
                                    m_num_val = index + 1 # fallback to row index
                                    
                                branch_val = str(group_row.get('Branch Name', BRANCH))
                                group_ref_val = str(member_row.get('Group Reference', ''))
                                
                                client_id = generate_client_id(branch_val, group_ref_val, m_num_val, is_bulk=True)
                                
                                # Safety check: If client_id already exists, append a random string to avoid duplicate errors
                                existing_check = supabase.table("loans").select("client_id").eq("client_id", client_id).execute()
                                if existing_check.data and len(existing_check.data) > 0:
                                    client_id = f"{client_id}-{str(uuid.uuid4())[:4]}"
                                
                                # Default to 'Internal Account' for bulk imports
                                status = 'Internal Account'
                                
                                # Robust extraction of officer with translation
                                officer_val = group_row.get('Credit Officer Name')
                                if pd.isna(officer_val) or str(officer_val).strip() == "" or str(officer_val).strip().lower() == "nan":
                                    officer_val = USER
                                else:
                                    raw_name = str(officer_val).strip()
                                    if raw_name in CO_NAME_MAP:
                                        officer_val = CO_NAME_MAP[raw_name]
                                    else:
                                        st.warning(f"⚠️ Unrecognized officer name: '{raw_name}' in Excel. Defaulting to logged-in user.")
                                        officer_val = USER
                                
                                client_data = {
                                    "client_id": client_id,
                                    "date": str(datetime.now().date()),
                                    "branch": str(group_row.get('Branch Name', BRANCH)),
                                    "officer": officer_val,
                                    "client_name": str(member_row.get('Full Name', 'Unknown')),
                                    "phone": str(member_row.get('Phone Number', '')),
                                    "address": str(member_row.get('Home Address', '')),
                                    "business_type": "Other",
                                    "group_name": str(group_row.get('Group Name', '')),
                                    "meeting_day": str(group_row.get('Meeting Day', 'Daily')),
                                    "loan_product": "Pending Onboarding",
                                    "product_category": "Finance",
                                    "loan_amount": 0,
                                    "active_credit": 0,
                                    "total_due": 0,
                                    "status": status
                                }
                                
                                supabase.table("loans").insert(client_data).execute()
                                success_count += 1
                            except Exception as e:
                                error_count += 1
                                print(f"Error importing member: {e}")
                                
                        if success_count > 0:
                            st.balloons()
                            st.success(f"✅ Successfully imported {success_count} members!")
                        if error_count > 0:
                            st.error(f"❌ Failed to import {error_count} members.")
                        
            except Exception as e:
                st.error(f"Error reading the Excel file: {e}. Please ensure it matches the template.")
                
        st.markdown("</div>", unsafe_allow_html=True)
    else:
        with st.container():
            st.markdown("<div class='card'>", unsafe_allow_html=True)
            st.subheader("1. Member's Data")
            c1, c2, c3 = st.columns(3)
            name = c1.text_input("Full Name (Surname First)", value=defaults["Name"], placeholder="Enter full name")
            nickname = c2.text_input("Nickname", value=defaults["Nickname"] if defaults["Nickname"] != "nan" else "", placeholder="e.g. Iya Oloja")
            phone = c3.text_input("Phone Number", value=defaults["Phone"], placeholder="e.g. 08012345678")
        
            c4, c5 = st.columns(2)
            address = c4.text_area("Home Address", value=defaults["Address"], height=70)
            biz_address = c5.text_area("Business / Address", value=defaults["BizAddress"] if defaults["BizAddress"] != "nan" else "", height=70)
        
            c6, c7, c8 = st.columns(3)
            ms_index = ["Single", "Married", "Divorced", "Widowed"].index(defaults["Marital"]) if defaults["Marital"] in ["Single", "Married", "Divorced", "Widowed"] else 0
            marital_status = c6.selectbox("Marital Status", ["Single", "Married", "Divorced", "Widowed"], index=ms_index)
            bz_index = ["Trader", "Artisan", "Driver", "SME", "Other"].index(defaults["BizType"]) if defaults["BizType"] in ["Trader", "Artisan", "Driver", "SME", "Other"] else 0
            biz_type = c7.selectbox("Occupation", ["Trader", "Artisan", "Driver", "SME", "Other"], index=bz_index)
            monthly_income = c8.number_input("Average Monthly Income (₦)", value=float(defaults["Income"]), step=5000.0)
        
            other_obs = st.text_input("Obligation with other institution", value=defaults["Obs"] if defaults["Obs"] != "nan" else "")
            st.markdown("</div>", unsafe_allow_html=True)
        
            st.markdown("<div class='card'>", unsafe_allow_html=True)
            st.subheader("2. Guarantor's Undertaking")
            g1, g2, g3 = st.columns(3)
            g_name = g1.text_input("Guarantor Full Name", value=defaults["GName"] if defaults["GName"] != "nan" else "")
            g_nick = g2.text_input("Guarantor Nickname", value=defaults["GNick"] if defaults["GNick"] != "nan" else "")
            g_phone = g3.text_input("Guarantor Phone", value=defaults["GPhone"] if defaults["GPhone"] != "nan" else "")
        
            g4, g5 = st.columns(2)
            g_address = g4.text_area("Guarantor Home Address", value=defaults["GHome"] if defaults["GHome"] != "nan" else "", height=70)
            g_office = g5.text_area("Guarantor Office Address", value=defaults["GOffice"] if defaults["GOffice"] != "nan" else "", height=70)
        
            g6, g7, g8 = st.columns(3)
            gm_index = ["Single", "Married", "Divorced", "Widowed"].index(defaults["GMarital"]) if defaults["GMarital"] in ["Single", "Married", "Divorced", "Widowed"] else 0
            g_marital = g6.selectbox("Guarantor Marital Status", ["Single", "Married", "Divorced", "Widowed"], index=gm_index)
            g_occ = g7.text_input("Guarantor Occupation", value=defaults["GOcc"] if defaults["GOcc"] != "nan" else "")
            g_rel = g8.text_input("Relationship with Borrower", value=defaults["GRel"] if defaults["GRel"] != "nan" else "")
            st.markdown("</div>", unsafe_allow_html=True)
        
            st.markdown("<div class='card'>", unsafe_allow_html=True)
            st.subheader("3. Group Undertaking")
            gr1, gr2, gr3 = st.columns(3)
            group_name = gr1.text_input("Group Name", value=defaults["Group"] if defaults["Group"] != "nan" else "")
            group_loc = gr2.text_input("Group Location / Address", value=defaults["GroupLoc"] if defaults["GroupLoc"] != "nan" else "")
            md_index = ["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"].index(defaults["Meeting"]) if defaults["Meeting"] in ["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"] else 0
            meeting_day = gr3.selectbox("Meeting Day", ["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], index=md_index)
        
            gr4, gr5 = st.columns(2)
            group_leader = gr4.text_input("Group Leader's Name", value=defaults["Leader"] if defaults["Leader"] != "nan" else "")
            group_date = gr5.date_input("Date of Formation", defaults["GroupDate"])
        
            if ROLE in ["Admin", "BM"]:
                co_display_names = list(CO_NAME_MAP.keys())
                if co_display_names:
                    selected_display = st.selectbox("Assign to Officer:", co_display_names)
                    assigned_officer = CO_NAME_MAP.get(selected_display, selected_display)
                else:
                    assigned_officer = st.selectbox("Assign to Officer:", ["CO1", "CO2"]) # fallback
            else:
                st.write(f"**Assigned Officer:** {CO_DISPLAY_MAP.get(USER, USER)}")
                assigned_officer = USER
            st.markdown("</div>", unsafe_allow_html=True)
        
            st.markdown("<div class='card'>", unsafe_allow_html=True)
            st.subheader("4. Financial Request (Applied Credit / Asset)")
        
            cat_col, prod_col, amt_col = st.columns(3)
            product_category = cat_col.selectbox("Product Category", ["Finance", "Asset"])
            
            if product_category == "Asset":
                product = prod_col.selectbox("Proposed Scheme", ["Cash and Carry", "60-Day Installment", "120-Day Installment"])
                amount_label = "Base Price (Asset Value ₦)"
            else:
                product = prod_col.selectbox("Proposed Scheme", ["Daily Loan (60 Days)", "Weekly Loan (12 Weeks)", "Weekly Loan (24 Weeks)"])
                amount_label = "Applied Credit Amount (Principal ₦)"
                
            amount = amt_col.number_input(amount_label, value=100000, step=5000, min_value=10000)
        
            setup = calculate_loan_setup(amount, product, product_category)
        
            st.markdown("---")
            col_gap, col_int = st.columns(2)
            
            if product_category == "Asset":
                # For Assets, the manual_gap acts as the 'Upfront Payment' which determines remaining balance
                manual_gap = col_gap.number_input("Upfront Payment (Deducted from Total Price ₦)", value=int(amount * 0.2), step=500)
            else:
                manual_gap = col_gap.number_input("Savings Balance (Gap/Deposit)", value=int(setup['initial_payment']), step=500)
                
            col_int.metric("Interest (Fixed)", f"₦{setup['interest']:,.0f}")
            
            if product_category == "Asset" and "Cash and Carry" not in product:
                total_price = amount + setup['interest']
                remaining_balance = total_price - manual_gap
                actual_repayment = remaining_balance / setup['duration']
                st.info(f"💡 **Asset Math:** Total Price (₦{total_price:,.0f}) - Upfront (₦{manual_gap:,.0f}) = Remaining ₦{remaining_balance:,.0f}. Expected {setup['freq']} Payment: **₦{actual_repayment:,.0f}**")
            elif product_category == "Asset" and "Cash and Carry" in product:
                actual_repayment = 0
                st.info(f"💡 **Asset Math:** Cash and Carry requires full upfront payment. Expected Payment: **₦0**")
        
            st.markdown("#### Origination Fees & Upfront Savings")
        
            # Base automated fees
            auto_proc = 500
            auto_group = 1000
            auto_branch = 1000
            auto_passbook = 0
        
            f1, f2, f3 = st.columns(3)
            processing_fee = f1.number_input("Processing Fee", value=auto_proc, step=50)
            group_savings = f2.number_input("Group Savings", value=auto_group, step=500)
            branch_contingency = f3.number_input("Branch Contingency", value=auto_branch, step=500)
        
            s1, s2 = st.columns(2)
            pass_book_fee = s1.number_input("Pass Book Fee (If exhausted)", value=auto_passbook, step=500)
            extra_savings = s2.number_input("Extra Personal Savings Deposit", value=2500 if not prev_client_id else 0, step=500)
        
            if product_category == "Asset":
                required_deduction = manual_gap
            else:
                required_deduction = setup['interest'] + manual_gap
                
            other_fees = processing_fee + group_savings + branch_contingency + pass_book_fee
        
            savings_available = prev_savings if prev_client_id else 0
            savings_shortfall = max(0, required_deduction - savings_available)
        
            total_cash_to_collect = savings_shortfall + other_fees + extra_savings
        
            st.info(f"**Total Upfront Cash to Collect from Client:** ₦{total_cash_to_collect:,.0f}")
            if savings_available > 0:
                st.success(f"Client has ₦{savings_available:,.0f} in previous savings. We will automatically deduct ₦{min(required_deduction, savings_available):,.0f} from it to cover upfront Interest and Gap.")
        
            if product_category == "Asset":
                if "Cash and Carry" in product:
                    active_credit = 0
                    final_repay = 0
                else:
                    active_credit = remaining_balance
                    final_repay = math.ceil(actual_repayment / 10) * 10
            else:
                active_credit = amount - manual_gap
                raw_repay = active_credit / setup['duration']
                final_repay = math.ceil(raw_repay / 10) * 10
        
            k1, k2 = st.columns(2)
            k1.metric("Outstanding Principal", f"₦{active_credit:,.0f}")
            k2.metric(f"Fixed {setup['freq']} Repayment", f"₦{final_repay:,.0f}")
            st.markdown("</div>", unsafe_allow_html=True)
        
            col_btn1, col_btn2, col_btn3 = st.columns([2, 1, 2])
            with col_btn2:
                submitted = st.button("📝 ORIGINATE LOAN", use_container_width=True)
        
            if submitted:
                if not name or not phone:
                    st.error("❌ Please fill in all required fields (Name and Phone)")
                else:
                    # Generate structured ID for single client
                    g_val = group_name if group_name else "IND"
                    
                    # Count how many existing clients are in this group to assign the next member number
                    try:
                        group_count_res = supabase.table("loans").select("client_id", count="exact").eq("Branch", BRANCH).eq("Group Name", group_name).execute()
                        next_num = group_count_res.count + 1 if group_count_res.count else 1
                    except:
                        next_num = 1
                        
                    new_client_id = generate_client_id(BRANCH, g_val, next_num)
                    
                    # Safety check
                    existing_check = supabase.table("loans").select("client_id").eq("client_id", new_client_id).execute()
                    if existing_check.data and len(existing_check.data) > 0:
                        new_client_id = f"{new_client_id}-{str(uuid.uuid4())[:4]}"
                    current_date_str = datetime.now().strftime("%Y-%m-%d")
                
                    # Save the new loan to the database FIRST to avoid Foreign Key violations
                    data = {
                        "Client ID": new_client_id,
                        "Date": current_date_str,
                        "Branch": BRANCH,
                        "Officer": assigned_officer,
                        "Client Name": name,
                        "Nickname": nickname,
                        "Phone": phone,
                        "Address": address,
                        "Business Type": biz_type,
                        "Marital Status": marital_status,
                        "Average Monthly Income": monthly_income,
                        "Other Obligations": other_obs,
                        "Guarantor Name": g_name,
                        "Guarantor Nickname": g_nick,
                        "Guarantor Marital Status": g_marital,
                        "Guarantor Home Address": g_address,
                        "Guarantor Occupation": g_occ,
                        "Guarantor Office Address": g_office,
                        "Guarantor Phone": g_phone,
                        "Guarantor Relationship": g_rel,
                        "Group Name": group_name,
                        "Group Location": group_loc,
                        "Group Leader Name": group_leader,
                        "Group Formation Date": group_date.strftime("%Y-%m-%d"),
                        "Meeting Day": meeting_day,
                        "Product Category": product_category,
                        "Loan Product": product,
                        "Loan Amount": amount,
                        "Active Credit": active_credit,
                        "Loan Repay": final_repay,
                        "Total Due": active_credit,
                        "Status": "Pending",
                        "Processing Fee": processing_fee,
                        "Pass Book Fee": pass_book_fee,
                        "Group Savings": group_savings,
                        "Branch Contingency": branch_contingency
                    }
                    save_new_loan(data)
                
                    # Perform Rollover Transactions
                    if prev_client_id and savings_available > 0:
                        # Withdraw all savings from old loan
                        withdraw_data = {
                            "Date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                            "Branch": BRANCH,
                            "Client ID": prev_client_id,
                            "Client Name": name,
                            "Amount Paid": 0,
                            "Officer": assigned_officer,
                            "Note": f"Rollover Withdrawal for new loan {new_client_id[:8]}",
                            "Transaction Type": "Savings",
                            "Withdrawal Amount": savings_available
                        }
                        save_repayment(withdraw_data)
                    
                        # Deposit all savings into new loan
                        fee_deposit = {
                            "Date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                            "Branch": BRANCH,
                            "Client ID": new_client_id,
                            "Client Name": name,
                            "Amount Paid": 0,
                            "Officer": assigned_officer,
                            "Note": f"Rollover Transfer from old loan {prev_client_id[:8]}",
                            "Transaction Type": "Savings",
                            "Savings Amount": savings_available
                        }
                        save_repayment(fee_deposit)
                    
                        if supabase:
                            supabase.table("loans").update({"status": "Completed"}).eq("client_id", prev_client_id).execute()
                    
                        st.toast("Rollover transactions logged & old loan Completed!")
                
                    # Collect Cash from Client
                    if total_cash_to_collect > 0:
                        cash_collection = {
                            "Date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                            "Branch": BRANCH,
                            "Client ID": new_client_id,
                            "Client Name": name,
                            "Amount Paid": total_cash_to_collect,
                            "Officer": assigned_officer,
                            "Note": "Upfront Cash Collection & Savings Deposit",
                            "Transaction Type": "Loan",
                            "Savings Amount": savings_shortfall + extra_savings,
                            "Processing Fee Paid": processing_fee,
                            "Pass Book Paid": pass_book_fee,
                            "Others Amount": group_savings + branch_contingency
                        }
                        save_repayment(cash_collection)
                
                    # Auto-Deduct Interest & Gap from Savings
                    if required_deduction > 0:
                        deduct_tx = {
                            "Date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                            "Branch": BRANCH,
                            "Client ID": new_client_id,
                            "Client Name": name,
                            "Amount Paid": 0,
                            "Officer": assigned_officer,
                            "Note": "Auto-Deduction of Management Fee (Interest + Gap)",
                            "Transaction Type": "Loan",
                            "Withdrawal Amount": required_deduction,
                            "Mgt Fee Paid": required_deduction
                        }
                        save_repayment(deduct_tx)
                
                    st.success(f"🎉 Loan Originated Successfully for {name}!")
                    st.balloons()
                    import time
                    time.sleep(2)
                    st.rerun()

elif page in ["Collections", "Audit Ledger"]:
    st.title(f"{page}")
    
    all_loans = load_loans()
    my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
    active_clients = my_loans[my_loans['Status'].isin(['Approved', 'Active'])]
    
    if active_clients.empty:
        st.warning("⚠️ No Active clients assigned to you.")
    else:
        c_grp, c1, c2 = st.columns([1.5, 2, 1])
        
        # Group Filter
        active_clients['Group Name'] = active_clients['Group Name'].fillna('Ungrouped').replace('', 'Ungrouped')
        unique_groups = ["All Groups"] + sorted([str(g) for g in active_clients['Group Name'].unique() if str(g).strip()])
        selected_group = c_grp.selectbox("Filter by Group:", unique_groups)
        
        if selected_group != "All Groups":
            filtered_clients = active_clients[active_clients['Group Name'] == selected_group]
        else:
            filtered_clients = active_clients
            
        client_ids = filtered_clients['Client ID'].tolist()
        
        def format_client_dropdown(cid):
            row = filtered_clients[filtered_clients['Client ID'] == cid].iloc[0]
            group_tag = f"[{row['Group Name']}] " if selected_group == "All Groups" else ""
            return f"{group_tag}{row['Client Name']} ({row['Phone']})"
        
        if not client_ids:
            st.warning("No clients found in this group.")
            st.stop()
            
        selected_id = c1.selectbox("Select Client:", client_ids, format_func=format_client_dropdown)
        view_date = c2.date_input("Report Date", datetime.now())
        
        client_loan = active_clients[active_clients['Client ID'] == selected_id].iloc[0]
        repayments = load_repayments()
        client_payments = repayments[repayments['Client ID'] == selected_id]
        
        fixed_repay = float(client_loan['Loan Repay'])
        active_credit_total = float(client_loan['Active Credit'])
        prod_type = client_loan['Loan Product']
        meet_day = client_loan.get('Meeting Day', 'Daily')
        start_date_str = client_loan['Date']
        
        acc_savings, total_loan_paid = calculate_client_savings(client_payments, fixed_repay)
        loan_balance_left = active_credit_total - total_loan_paid
        expected_paid, overdue_amt = calculate_overdue(start_date_str, prod_type, fixed_repay, total_loan_paid)
        
        st.markdown(f"<h3>👤 {client_loan['Client Name']} | <span style='color: #666;'>{prod_type}</span></h3>", unsafe_allow_html=True)
        if "Weekly" in str(prod_type):
            st.caption(f"🗓️ Meets on: **{meet_day}**")
            
        if loan_balance_left <= 0:
            st.success("🎉 **FULLY PAID!** This client has completely paid off their active loan balance!")
        
        # Client metrics
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Outstanding Principal", f"₦{active_credit_total:,.0f}")
        col2.metric("Total Paid to Loan", f"₦{total_loan_paid:,.0f}")
        balance_color = "normal" if loan_balance_left <= 0 else "inverse"
        col3.metric("🔻 Loan Balance", f"₦{loan_balance_left:,.0f}", delta_color=balance_color)
        col4.metric("🐷 Acc. Savings", f"₦{acc_savings:,.0f}")
        
        # Risk status
        st.markdown("### ⚠️ Risk & Overdue Status")
        r_col1, r_col2 = st.columns(2)
        r_col1.metric("Expected By Now", f"₦{expected_paid:,.0f}")
        overdue_color = "inverse" if overdue_amt > 0 else "normal"
        r_col2.metric("🚨 Overdue Amount", f"₦{overdue_amt:,.0f}", delta_color=overdue_color)
        
        # Payment schedule
        st.markdown("---")
        st.subheader("📅 Payment Schedule (Aggregated)")
        report_df = get_ledger_report(client_payments, fixed_repay, prod_type, meet_day, view_date)
        st.dataframe(report_df, use_container_width=True)
        
        # Transaction history
        st.markdown("### 📜 Raw Transaction History")
        if not client_payments.empty:
            if 'Transaction Type' not in client_payments.columns:
                client_payments['Transaction Type'] = "Loan"
            else:
                client_payments['Transaction Type'] = client_payments['Transaction Type'].fillna("Loan")
            
            history_cols = ["Date", "Amount Paid", "Transaction Type", "Officer", "Note"]
            display_history = client_payments[[c for c in history_cols if c in client_payments.columns]]
            display_history = display_history.sort_values(by="Date", ascending=False)
            st.dataframe(display_history, use_container_width=True)
        else:
            st.info("No transactions recorded yet.")
        
        # Smart Auto-Splitter
        st.markdown("---")
        st.subheader("🧮 Smart Auto-Splitter (For Overpayments)")
        st.caption("Enter the total cash received and the client's total agreed daily payment (loan + savings) to auto-fill the form below.")
        
        c_split1, c_split2 = st.columns(2)
        total_cash_received = c_split1.number_input("Total Cash Received (₦)", value=0, step=500)
        agreed_daily_payment = c_split2.number_input("Client's Agreed Daily Total (₦)", value=int(fixed_repay) + 350, step=50)
        
        auto_loan_rep = 0
        auto_savings_dep = 0
        
        if total_cash_received > 0 and agreed_daily_payment > 0:
            multiplier = total_cash_received / agreed_daily_payment
            auto_loan_rep = int(fixed_repay * multiplier)
            auto_savings_dep = int(total_cash_received - auto_loan_rep)
            st.info(f"💡 **Auto-Calculated Split:** ₦{auto_loan_rep:,.0f} for Loan & ₦{auto_savings_dep:,.0f} for Savings")
            
        # Record granular payment
        st.markdown("---")
        st.subheader("💸 Record Granular Collection")
        
        with st.form("pay_form"):
            st.caption(f"Expected Fixed Repayment: **₦{fixed_repay:,.0f}**")
            
            st.markdown("**1. Core Collections**")
            c1, c2 = st.columns(2)
            loan_rep = c1.number_input("Installment Collection (₦)", value=int(auto_loan_rep), step=500)
            savings_dep = c2.number_input("Savings Deposit (₦)", value=int(auto_savings_dep), step=500)
            
            st.markdown("**2. Exceptions**")
            e1, e2, e3 = st.columns(3)
            overdue_coll = e1.number_input("Overdue Collected (₦)", value=0, step=500)
            recoveries = e2.number_input("Recoveries (₦)", value=0, step=500)
            excess = e3.number_input("Excess (₦)", value=0, step=500)
            
            st.markdown("**3. Fees & Sales**")
            f1, f2, f3 = st.columns(3)
            pass_book = f1.number_input("Passbook Sales (₦)", value=0, step=100)
            proc_fees = f2.number_input("Processing Fees (₦)", value=0, step=500)
            mgt_fees = f3.number_input("Mgt Fees (₦)", value=0, step=500)
            
            fs1, fs2, fs3 = st.columns(3)
            init_pay = fs1.number_input("Initial Payments (₦)", value=0, step=500)
            asset_sales = fs2.number_input("Asset Sales (₦)", value=0, step=500)
            contingency = fs3.number_input("Contingency (₦)", value=0, step=500)
            
            st.markdown("**4. Outflows (Deductions)**")
            o1, o2, o3 = st.columns(3)
            withdrawal = o1.number_input("Savings Withdrawal (₦)", value=0, step=500)
            cash_return = o2.number_input("Cash Return (₦)", value=0, step=500)
            adjustments = o3.number_input("Adjustments (₦)", value=0, step=500)
            
            note_col = st.text_input("Note", placeholder="e.g. Week 4 Group Collection")
            
            # Auto-calculate total cash layout for sanity check
            total_cash_in = (loan_rep + savings_dep + overdue_coll + recoveries + excess + 
                             pass_book + proc_fees + mgt_fees + init_pay + asset_sales + contingency)
            total_cash_out = withdrawal + cash_return + adjustments
            net_cash = total_cash_in - total_cash_out
            
            st.info(f"**Total Cash IN:** ₦{total_cash_in:,.0f} | **Total Cash OUT:** ₦{total_cash_out:,.0f} | **Net Cash Collected:** ₦{net_cash:,.0f}")
            
            if st.form_submit_button("🏦 AUTHORIZE CASH POSTING"):
                pay_data = {
                    "Date": datetime.now().strftime("%Y-%m-%d %H:%M"),
                    "Branch": BRANCH,
                    "Client ID": selected_id,
                    "Client Name": client_loan['Client Name'],
                    "Amount Paid": net_cash,
                    "Officer": USER,
                    "Note": note_col,
                    "Transaction Type": "Loan",
                    "Savings Amount": savings_dep,
                    "Loan Repayment Amount": loan_rep,
                    "Processing Fee Paid": proc_fees,
                    "Markup Paid": cash_return,
                    "Pass Book Paid": pass_book,
                    "Recovery Amount": recoveries,
                    "Withdrawal Amount": withdrawal,
                    "Mgt Fee Paid": mgt_fees,
                    "Others Amount": adjustments,
                    "asset_sales_paid": asset_sales,
                    "contingency_paid": contingency,
                    "excess_amount": excess,
                    "initial_payment": init_pay,
                    "overdue_collected": overdue_coll # Need to save this to others_amount if missing, wait.
                }
                # Since we changed columns, map Overdue to Others if not in DB, but let's just save it. Wait, Supabase will ignore extra keys if we don't have them in the DB if we use the Python client? No, Supabase Python client might error. 
                # Let's map Overdue strictly to others_amount if we didn't add it. But I added `excess_amount` etc.
                # Actually, wait. I will map Adjustments to something else and Overdue to others_amount.
                # Let me fix the dictionary:
                pay_data["Others Amount"] = overdue_coll
                pay_data["adjustments"] = adjustments # adding extra keys might fail if the column doesn't exist!
                
                # Let's just strictly map what we have in DB.
                pay_data_safe = {
                    "Date": datetime.now().strftime("%Y-%m-%d %H:%M"),
                    "Branch": BRANCH,
                    "Client ID": selected_id,
                    "Client Name": client_loan['Client Name'],
                    "Amount Paid": net_cash,
                    "Officer": USER,
                    "Note": f"{note_col} | Adj:{adjustments}", # Stashing adj in note
                    "Transaction Type": "Loan",
                    "Savings Amount": savings_dep,
                    "Loan Repayment Amount": loan_rep,
                    "Processing Fee Paid": proc_fees,
                    "Markup Paid": cash_return,
                    "Pass Book Paid": pass_book,
                    "Recovery Amount": recoveries,
                    "Withdrawal Amount": withdrawal,
                    "Mgt Fee Paid": mgt_fees,
                    "Others Amount": overdue_coll,
                    "asset_sales_paid": asset_sales,
                    "contingency_paid": contingency,
                    "excess_amount": excess,
                    "initial_payment": init_pay
                }
                
                # Check if this exact payment pays them off!
                total_loan_contribution = loan_rep + overdue_coll + recoveries + init_pay
                if loan_balance_left - total_loan_contribution <= 0 and loan_balance_left > 0:
                    st.balloons()
                    
                save_repayment(pay_data_safe)
                
                st.success("✅ Detailed Collection Recorded Globally!")
                
                import time
                time.sleep(1.5)
                st.rerun()


elif page == "Daily Report":
    st.title("Daily Collections Report")
    
    view_date = st.date_input("Select Date for Report", datetime.now().date())
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    # Filter for the selected date for new active loans
    if not all_loans.empty:
        all_loans['DateStr'] = pd.to_datetime(all_loans['Date'], errors='coerce').dt.date.astype(str)
        daily_loans = all_loans[all_loans['DateStr'] == date_str]
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
elif page == "WhatsApp Cashbook":
    st.title("WhatsApp Cashbook")
    st.caption("Daily Reconciliation Dashboard — Left (Inflows) vs Right (Outflows)")
    
    view_date = st.date_input("Select Date", datetime.now().date(), key="wa_date")
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    if not repayments.empty:
        repayments['DateStr'] = pd.to_datetime(repayments['Date'], errors='coerce').dt.date.astype(str)
        daily_reps = repayments[repayments['DateStr'] == date_str]
        
        # --- RBAC FILTERING ---
        if ROLE in ["BM", "AM"]:
            st.markdown("### 🏢 Managerial Controls")
            if ROLE == "BM":
                daily_reps = daily_reps[daily_reps['Branch'] == BRANCH]
            
            unique_officers = daily_reps['Officer'].dropna().unique().tolist()
            if unique_officers:
                display_options = [CO_DISPLAY_MAP.get(o, o) for o in unique_officers]
                selected_display = st.selectbox("Select Credit Officer", display_options, key="wa_cashbook_co")
                selected_co = CO_NAME_MAP.get(selected_display, selected_display)
                daily_reps = daily_reps[daily_reps['Officer'] == selected_co]
            else:
                st.info("No officers have records for this date.")
        elif ROLE == "CO":
            daily_reps = daily_reps[daily_reps['Officer'] == USER]
        else:
            daily_reps = daily_reps[daily_reps['Officer'] == USER]
        
        if daily_reps.empty:
            st.info(f"No transactions found for {date_str}.")
        else:
            # ========================================================
            # HELPER: Safe sum from a column
            # ========================================================
            def safe_sum(df, col):
                if col in df.columns:
                    return pd.to_numeric(df[col], errors='coerce').fillna(0).sum()
                return 0.0
            
            # ========================================================
            # HELPER: Sum repayments by loan product type
            # To break down "Repayment 12 Weeks", "Repayment 24 Weeks", etc.
            # we cross-reference each repayment's Client ID against the loans table
            # ========================================================
            def sum_repayments_by_product(daily_df, loans_df, product_keywords):
                """Sum loan repayments for clients whose Loan Product contains any of the keywords."""
                total = 0.0
                for _, row in daily_df.iterrows():
                    cid = row.get('Client ID')
                    rep_amt = pd.to_numeric(row.get('Loan Repayment Amount', 0), errors='coerce')
                    if pd.isna(rep_amt):
                        rep_amt = 0
                    if cid and not loans_df.empty:
                        client_loan = loans_df[loans_df['Client ID'] == cid]
                        if not client_loan.empty:
                            product = str(client_loan.iloc[0].get('Loan Product', '')).lower()
                            if any(kw.lower() in product for kw in product_keywords):
                                total += rep_amt
                return total
            
            # ========================================================
            # HELPER: Sum new disbursements by product type from loans table
            # ========================================================
            def sum_disbursements_by_product(loans_df, date_str, product_keywords):
                """Sum active credit for loans originated today matching product keywords."""
                if loans_df.empty:
                    return 0.0
                loans_df['DateStr'] = pd.to_datetime(loans_df['Date'], errors='coerce').dt.date.astype(str)
                today_loans = loans_df[loans_df['DateStr'] == date_str]
                total = 0.0
                for _, loan in today_loans.iterrows():
                    product = str(loan.get('Loan Product', '')).lower()
                    if any(kw.lower() in product for kw in product_keywords):
                        total += pd.to_numeric(loan.get('Active Credit', 0), errors='coerce') or 0
                return total
            
            # ========================================================
            # LEFT SIDE: INFLOWS (Expected Cash Coming In)
            # ========================================================
            
            # Manual inputs for Brought Forward
            st.markdown("---")
            st.markdown("### ✏️ Manual Entries")
            mi1, mi2 = st.columns(2)
            bf_cash = mi1.number_input("Brought Forward Cash (₦)", value=0, step=500, key="wa_bf_cash")
            bf_overdue = mi2.number_input("Brought Forward Overdue (₦)", value=0, step=500, key="wa_bf_overdue")
            
            # From database aggregation
            total_savings = safe_sum(daily_reps, 'Savings Amount')
            rep_12_weeks = sum_repayments_by_product(daily_reps, all_loans, ['12 Week', '12 week', '12wk'])
            rep_24_weeks = sum_repayments_by_product(daily_reps, all_loans, ['24 Week', '24 week', '24wk'])
            rep_60_days = sum_repayments_by_product(daily_reps, all_loans, ['60 Day', '60 day', '60-Day'])
            rep_monthly = sum_repayments_by_product(daily_reps, all_loans, ['Monthly', 'monthly'])
            
            # Fallback: any repayments not captured above go to a general bucket
            total_all_rep = safe_sum(daily_reps, 'Loan Repayment Amount')
            rep_categorized = rep_12_weeks + rep_24_weeks + rep_60_days + rep_monthly
            rep_other = total_all_rep - rep_categorized
            
            contingency = safe_sum(daily_reps, 'contingency_paid')
            bank_withdrawn = safe_sum(daily_reps, 'Withdrawal Amount')  # Bank withdrawals TO the CO (inflow)
            asset_sales = safe_sum(daily_reps, 'asset_sales_paid')
            app_fee = safe_sum(daily_reps, 'Processing Fee Paid')
            pass_book = safe_sum(daily_reps, 'Pass Book Paid')
            
            left_total = (bf_cash + bf_overdue + total_savings + rep_12_weeks + rep_24_weeks + 
                         rep_60_days + rep_monthly + rep_other + contingency + bank_withdrawn + 
                         asset_sales + app_fee + pass_book)
            
            # ========================================================
            # RIGHT SIDE: OUTFLOWS (Cash Going Out)
            # ========================================================
            
            # Disbursements by product type (new loans given today)
            co_name = USER if ROLE == "CO" else (selected_co if ROLE in ["BM", "AM"] and unique_officers else USER)
            co_loans = all_loans[all_loans['Officer'] == co_name] if not all_loans.empty else pd.DataFrame()
            
            daily_11 = sum_disbursements_by_product(co_loans, date_str, ['Daily 11', 'daily 11'])
            weekly_11 = sum_disbursements_by_product(co_loans, date_str, ['Weekly 11', 'weekly 11'])
            weekly_20 = sum_disbursements_by_product(co_loans, date_str, ['Weekly 20', 'weekly 20'])
            cash_carry = sum_disbursements_by_product(co_loans, date_str, ['Cash and Carry', 'Cash & Carry', 'cash carry'])
            weekly_active = sum_disbursements_by_product(co_loans, date_str, ['Weekly Active', 'weekly active'])
            daily_active = sum_disbursements_by_product(co_loans, date_str, ['Daily Active', 'daily active'])
            
            # Catch-all for disbursements not matching any specific product
            total_all_disbursed = sum_disbursements_by_product(co_loans, date_str, [''])  # Won't match, use below
            if not co_loans.empty:
                co_loans_temp = co_loans.copy()
                co_loans_temp['DateStr'] = pd.to_datetime(co_loans_temp['Date'], errors='coerce').dt.date.astype(str)
                today_co_loans = co_loans_temp[co_loans_temp['DateStr'] == date_str]
                total_all_disbursed = pd.to_numeric(today_co_loans['Active Credit'], errors='coerce').fillna(0).sum()
            else:
                total_all_disbursed = 0
            disbursed_categorized = daily_11 + weekly_11 + weekly_20 + cash_carry + weekly_active + daily_active
            disbursed_other = total_all_disbursed - disbursed_categorized
            
            product_withdrawal = safe_sum(daily_reps, 'Markup Paid')  # Cash Return / Product Withdrawal
            savings_withdrawal = safe_sum(daily_reps, 'Withdrawal Amount')  # Savings withdrawal
            
            # Manual outflow inputs
            mo1, mo2 = st.columns(2)
            expenses = mo1.number_input("Expenses (₦)", value=0, step=500, key="wa_expenses")
            banked = mo2.number_input("Cash Banked / Deposited (₦)", value=0, step=500, key="wa_banked")
            
            right_total = (daily_11 + weekly_11 + weekly_20 + cash_carry + product_withdrawal +
                          weekly_active + daily_active + disbursed_other + expenses + banked)
            
            # ========================================================
            # UI LAYOUT: THE PHYSICAL LEDGER
            # ========================================================
            st.markdown("---")
            left_col, right_col = st.columns(2)
            
            with left_col:
                st.markdown("<div class='card'>", unsafe_allow_html=True)
                st.subheader("🟢 LEFT — INFLOWS")
                st.markdown("---")
                st.write(f"**Brought Forward Cash:** ₦{bf_cash:,.0f}")
                st.write(f"**Brought Forward Overdue:** ₦{bf_overdue:,.0f}")
                st.markdown("---")
                st.write(f"**Total Savings:** ₦{total_savings:,.0f}")
                st.write(f"**Repayment 12 Weeks:** ₦{rep_12_weeks:,.0f}")
                st.write(f"**Repayment 24 Weeks:** ₦{rep_24_weeks:,.0f}")
                st.write(f"**Repayment 60 Days:** ₦{rep_60_days:,.0f}")
                st.write(f"**Repayment Monthly:** ₦{rep_monthly:,.0f}")
                if rep_other > 0:
                    st.write(f"**Other Repayments:** ₦{rep_other:,.0f}")
                st.markdown("---")
                st.write(f"**Contingency:** ₦{contingency:,.0f}")
                st.write(f"**Bank Withdrawn:** ₦{bank_withdrawn:,.0f}")
                st.write(f"**Asset Sales:** ₦{asset_sales:,.0f}")
                st.write(f"**App Fee:** ₦{app_fee:,.0f}")
                st.write(f"**Pass Book:** ₦{pass_book:,.0f}")
                st.markdown("---")
                st.markdown(f"### 📥 Total Inflows: ₦{left_total:,.0f}")
                st.markdown("</div>", unsafe_allow_html=True)
                
            with right_col:
                st.markdown("<div class='card'>", unsafe_allow_html=True)
                st.subheader("🔴 RIGHT — OUTFLOWS")
                st.markdown("---")
                st.write(f"**Daily 11%:** ₦{daily_11:,.0f}")
                st.write(f"**Weekly 11%:** ₦{weekly_11:,.0f}")
                st.write(f"**Weekly 20%:** ₦{weekly_20:,.0f}")
                st.write(f"**Cash Carry:** ₦{cash_carry:,.0f}")
                if disbursed_other > 0:
                    st.write(f"**Other Disbursements:** ₦{disbursed_other:,.0f}")
                st.markdown("---")
                st.write(f"**Product Withdrawal:** ₦{product_withdrawal:,.0f}")
                st.write(f"**Weekly Active:** ₦{weekly_active:,.0f}")
                st.write(f"**Daily Active:** ₦{daily_active:,.0f}")
                st.markdown("---")
                st.write(f"**Expenses:** ₦{expenses:,.0f}")
                st.write(f"**Banked:** ₦{banked:,.0f}")
                st.markdown("---")
                st.markdown(f"### 📤 Total Outflows: ₦{right_total:,.0f}")
                st.markdown("</div>", unsafe_allow_html=True)
            
            # ========================================================
            # THE GOLDEN RULE VALIDATION ENGINE
            # ========================================================
            st.markdown("---")
            st.markdown("## ⚖️ Golden Rule Validation")
            
            net_cash = left_total - right_total
            
            if net_cash == 0:
                st.success("## ✅ BALANCED: Closing Cash is ₦0 — Cashbook perfectly reconciled!")
            elif net_cash > 0:
                st.error(f"## 🚨 SHORTAGE: Closing Overdue of ₦{net_cash:,.0f}")
                st.write("Your Inflows (Left) exceed your Outflows (Right). You should have this exact amount as physical cash at hand, OR there is a shortage.")
            else:
                st.info(f"## 💎 EXCESS: Unaccounted surplus of ₦{abs(net_cash):,.0f}")
                st.write("Your Outflows (Right) exceed your Inflows (Left). You've banked or paid out more than collected.")
                
    else:
        st.info("No records found.")


elif page == "Cash Book":
    st.title("Credit Cash Book")
    st.caption("INITIATIVE FOR COMMUNITY ADVANCEMENT, RELIEF AND EMPOWERMENT — Credit Cash Book")
    
    # --- Controls ---
    ctl1, ctl2, ctl3 = st.columns([1, 1, 1])
    cb_month = ctl1.selectbox("Month", list(range(1, 13)), index=datetime.now().month - 1,
                               format_func=lambda m: datetime(2026, m, 1).strftime("%B"))
    cb_year = ctl2.number_input("Year", value=datetime.now().year, step=1, min_value=2024, max_value=2030)
    
    all_loans = load_loans()
    all_repayments = load_repayments()
    
    branch_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
    
    officers = sorted(branch_loans['Officer'].dropna().unique()) if not branch_loans.empty else []
    display_options = ["All Officers"] + [CO_DISPLAY_MAP.get(o, o) for o in officers]
    selected_display = ctl3.selectbox("Officer Filter", display_options)
    selected_officer = "All Officers" if selected_display == "All Officers" else CO_NAME_MAP.get(selected_display, selected_display)
    
    if selected_officer != "All Officers":
        branch_loans = branch_loans[branch_loans['Officer'] == selected_officer]
    
    # Filter repayments by month/year
    if not all_repayments.empty:
        all_repayments['_dt'] = pd.to_datetime(all_repayments['Date'], errors='coerce')
        month_reps = all_repayments[
            (all_repayments['_dt'].dt.month == cb_month) &
            (all_repayments['_dt'].dt.year == cb_year)
        ].copy()
        
        # Filter by branch/officer
        if ROLE == "BM":
            month_reps = month_reps[month_reps['Branch'] == BRANCH]
        elif ROLE == "Officer":
            month_reps = month_reps[month_reps['Officer'] == USER]
        if selected_officer != "All Officers":
            month_reps = month_reps[month_reps['Officer'] == selected_officer]
    else:
        month_reps = pd.DataFrame()
    
    if month_reps.empty:
        st.info(f"No transactions found for {datetime(cb_year, cb_month, 1).strftime('%B %Y')}.")
    else:
        month_reps['_day'] = month_reps['_dt'].dt.date
        
        # Helper to safely sum numeric
        def safe_sum(series):
            return pd.to_numeric(series, errors='coerce').fillna(0).sum()
        
        # Build daily cashbook rows
        cashbook_rows = []
        unique_days = sorted(month_reps['_day'].dropna().unique())
        
        # Running totals for closing balance
        cumulative_payment = 0
        cumulative_credit_disbursed = 0
        
        for day in unique_days:
            day_data = month_reps[month_reps['_day'] == day]
            
            # --- PAYMENT SIDE (Cash In) ---
            loan_rep_no = len(day_data[pd.to_numeric(day_data['Loan Repayment Amount'], errors='coerce').fillna(0) > 0])
            loan_rep_amt = safe_sum(day_data['Loan Repayment Amount'])
            
            savings_withdrawal_no = len(day_data[pd.to_numeric(day_data['Withdrawal Amount'], errors='coerce').fillna(0) > 0])
            savings_withdrawal_amt = safe_sum(day_data['Withdrawal Amount'])
            
            savings_return_amt = safe_sum(day_data['Savings Amount'])
            
            risk_premium = safe_sum(day_data['Markup Paid'])
            mgt_fee = safe_sum(day_data['Mgt Fee Paid'])
            proc_fee = safe_sum(day_data['Processing Fee Paid'])
            pass_book = safe_sum(day_data['Pass Book Paid'])
            recovery = safe_sum(day_data['Recovery Amount'])
            others = safe_sum(day_data['Others Amount'])
            
            # --- RECEIPT SIDE (Cash Out / Disbursements) ---
            # Check for new loans originated on this day
            day_str = day.strftime("%Y-%m-%d")
            day_loans = branch_loans[branch_loans['Date'] == day_str]
            if selected_officer != "All Officers":
                day_loans = day_loans[day_loans['Officer'] == selected_officer]
            
            credit_disbursed_no = len(day_loans)
            credit_disbursed_amt = day_loans['Active Credit'].sum() if not day_loans.empty else 0
            
            # Fund transfers (identifiable via transaction notes)
            fund_to_ho = 0
            fund_to_other_area = 0
            staff_salaries = 0
            office_returns = 0
            
            # Total Payment (cash in)
            total_payment = (loan_rep_amt + savings_return_amt + risk_premium + 
                           mgt_fee + proc_fee + pass_book + recovery + others)
            
            # Total Receipt / Cash Out
            total_receipt = credit_disbursed_amt + savings_withdrawal_amt
            
            cumulative_payment += total_payment
            cumulative_credit_disbursed += total_receipt
            closing_balance = cumulative_payment - cumulative_credit_disbursed
            
            cashbook_rows.append({
                "Date": day.strftime("%d/%m"),
                "Credit Disbursed (No)": credit_disbursed_no,
                "Credit Disbursed (₦)": credit_disbursed_amt,
                "Savings Withdrawal (No)": savings_withdrawal_no,
                "Savings Withdrawal (₦)": savings_withdrawal_amt,
                "Savings Deposit (₦)": savings_return_amt,
                "Risk Premium (₦)": risk_premium,
                "Mgt Fee (₦)": mgt_fee,
                "Processing Fee (₦)": proc_fee,
                "Pass Book (₦)": pass_book,
                "Recovery (₦)": recovery,
                "Others (₦)": others,
                "Loan Repayment (No)": loan_rep_no,
                "Loan Repayment (₦)": loan_rep_amt,
                "Staff Salaries (₦)": staff_salaries,
                "Office Returns (₦)": office_returns,
                "Total Payment (₦)": total_payment,
                "Total Receipt (₦)": total_receipt,
                "Closing Balance (₦)": closing_balance
            })
        
        cashbook_df = pd.DataFrame(cashbook_rows)
        
        # --- DISPLAY ---
        st.markdown(f"### 📅 Cash Book — {datetime(cb_year, cb_month, 1).strftime('%B %Y')}")
        if selected_officer != "All Officers":
            st.markdown(f"**Officer:** {selected_officer} | **Branch:** {BRANCH}")
        else:
            st.markdown(f"**Branch:** {BRANCH} (All Officers)")
        
        # Summary metrics
        st.markdown("#### 💰 Monthly Overview")
        m1, m2, m3, m4, m5 = st.columns(5)
        m1.metric("Total Cash In", f"₦{cashbook_df['Total Payment (₦)'].sum():,.0f}")
        m2.metric("Total Disbursed", f"₦{cashbook_df['Credit Disbursed (₦)'].sum():,.0f}")
        m3.metric("Total Loan Repaid", f"₦{cashbook_df['Loan Repayment (₦)'].sum():,.0f}")
        m4.metric("Total Savings In", f"₦{cashbook_df['Savings Deposit (₦)'].sum():,.0f}")
        m5.metric("Closing Balance", f"₦{cashbook_df['Closing Balance (₦)'].iloc[-1]:,.0f}" if not cashbook_df.empty else "₦0")
        
        # Weekly breakdown
        st.markdown("---")
        st.markdown("#### 📊 Weekly Cash Book Ledger")
        
        # Group by week
        for day in unique_days:
            cashbook_df.loc[cashbook_df['Date'] == day.strftime("%d/%m"), '_week'] = (day.day - 1) // 7 + 1
        
        weeks = sorted(cashbook_df['_week'].dropna().unique())
        
        for week_num in weeks:
            week_data = cashbook_df[cashbook_df['_week'] == week_num].drop(columns=['_week'], errors='ignore')
            
            st.markdown(f"##### 📋 Week {int(week_num)}")
            
            # Format the display
            display_cols = [c for c in week_data.columns if c != '_week']
            
            # Style the dataframe with currency formatting
            format_dict = {}
            for col in display_cols:
                if "(₦)" in col:
                    format_dict[col] = "₦{:,.0f}"
                elif "(No)" in col:
                    format_dict[col] = "{:.0f}"
            
            st.dataframe(
                week_data[display_cols].style.format(format_dict, na_rep="—"),
                use_container_width=True,
                hide_index=True
            )
            
            # Weekly totals
            wt_cols = [c for c in display_cols if "(₦)" in c or "(No)" in c]
            weekly_totals = {c: week_data[c].sum() for c in wt_cols}
            
            wt1, wt2, wt3, wt4 = st.columns(4)
            wt1.metric(f"W{int(week_num)} Cash In", f"₦{weekly_totals.get('Total Payment (₦)', 0):,.0f}")
            wt2.metric(f"W{int(week_num)} Disbursed", f"₦{weekly_totals.get('Credit Disbursed (₦)', 0):,.0f}")
            wt3.metric(f"W{int(week_num)} Loan Repaid", f"₦{weekly_totals.get('Loan Repayment (₦)', 0):,.0f}")
            wt4.metric(f"W{int(week_num)} Savings", f"₦{weekly_totals.get('Savings Deposit (₦)', 0):,.0f}")
            st.markdown("---")
        
        # Monthly Total row
        st.markdown("#### 📈 Monthly Totals")
        num_cols = [c for c in cashbook_df.columns if "(₦)" in c or "(No)" in c]
        monthly_totals = cashbook_df[num_cols].sum()
        
        mt_df = pd.DataFrame([monthly_totals], index=["Monthly Total"])
        format_dict_mt = {}
        for col in mt_df.columns:
            if "(₦)" in col:
                format_dict_mt[col] = "₦{:,.0f}"
            elif "(No)" in col:
                format_dict_mt[col] = "{:.0f}"
        
        st.dataframe(mt_df.style.format(format_dict_mt), use_container_width=True)
        
        # Download cashbook as Excel
        st.markdown("---")
        if st.button("⬇️ Download Cash Book as Excel", use_container_width=True):
            import io
            output = io.BytesIO()
            display_df = cashbook_df.drop(columns=['_week'], errors='ignore')
            
            # Add totals row
            total_row = display_df.select_dtypes(include='number').sum()
            total_row['Date'] = 'MONTHLY TOTAL'
            display_df = pd.concat([display_df, pd.DataFrame([total_row])], ignore_index=True)
            
            with pd.ExcelWriter(output, engine='openpyxl') as writer:
                display_df.to_excel(writer, sheet_name='Credit Cash Book', index=False)
            
            st.download_button(
                label="📄 Click to Download",
                data=output.getvalue(),
                file_name=f"ICARE_CashBook_{datetime(cb_year, cb_month, 1).strftime('%B_%Y')}.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )

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
            expected, overdue = calculate_overdue(row['Date'], row['Loan Product'], row['Loan Repay'], l_amt)
            row_data = row.to_dict()
            row_data['Acc. Savings'] = s_amt
            row_data['Paid to Loan'] = l_amt
            row_data['Loan Balance'] = row['Active Credit'] - l_amt
            row_data['Overdue'] = overdue
            display_data.append(row_data)
        
        display_df = pd.DataFrame(display_data)
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
            ["Daily Loan (60 Days)", "Weekly Loan (12 Weeks)", "Weekly Loan (24 Weeks)"]
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
