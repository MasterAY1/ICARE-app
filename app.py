import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
import math
import uuid
from supabase import create_client, Client
import sys
import os
import holidays
from pandas.tseries.offsets import CustomBusinessDay

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
APP_VERSION = "2.5.0"

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

USERS = {
    "admin": {"pass": "1234", "role": "Admin", "branch": "Global", "name": "System Admin"},
    "bm": {"pass": "1234", "role": "BM", "branch": "Lagos", "name": "Lagos Manager"},
    "john": {"pass": "1234", "role": "Officer", "branch": "Lagos", "name": "John"},
    "jane": {"pass": "1234", "role": "Officer", "branch": "Lagos", "name": "Jane"}
}

# Custom CSS for professional styling
st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap');
    
    .stApp { 
        background: linear-gradient(135deg, #f4f6f5 0%, #e8edea 100%);
        font-family: 'Inter', sans-serif !important;
    }
    h1, h2, h3, h4 { 
        color: #0F4C3A !important; 
        font-family: 'Inter', sans-serif;
        font-weight: 800;
        letter-spacing: -0.5px;
    }
    .stMetric {
        background: rgba(255, 255, 255, 0.9);
        backdrop-filter: blur(10px);
        border-radius: 12px;
        padding: 18px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.04), 0 1px 3px rgba(0,0,0,0.02);
        border: 1px solid rgba(15, 76, 58, 0.1);
        transition: transform 0.2s ease;
    }
    .stMetric:hover {
        transform: translateY(-2px);
    }
    div[data-testid="stMetricValue"] { 
        color: #0F4C3A !important;
        font-size: 1.8rem;
        font-weight: 800;
    }
    div[data-testid="stMetricLabel"] { 
        color: #556B60 !important;
        font-size: 0.95rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    .stTextInput input, .stNumberInput input, .stSelectbox div, 
    .stTextArea textarea, .stDateInput input {
        background-color: #ffffff !important;
        color: #1a1a1a !important;
        border: 1px solid #dcdfe3;
        border-radius: 8px;
        box-shadow: inset 0 1px 2px rgba(0,0,0,0.02);
    }
    .stButton > button { 
        background: linear-gradient(135deg, #0F4C3A 0%, #156B51 100%) !important;
        color: white !important;
        font-weight: 600 !important;
        border: none;
        height: 2.8em;
        border-radius: 8px;
        transition: all 0.3s ease;
        box-shadow: 0 2px 4px rgba(15, 76, 58, 0.2);
    }
    .stButton > button:hover { 
        background: linear-gradient(135deg, #156B51 0%, #1A8A68 100%) !important;
        transform: translateY(-2px);
        box-shadow: 0 6px 12px rgba(15, 76, 58, 0.3);
    }
    .stButton > button[kind="secondary"] {
        background: white !important;
        color: #0F4C3A !important;
        border: 2px solid #0F4C3A !important;
        box-shadow: none;
    }
    .stButton > button[kind="secondary"]:hover {
        background: #f0fdf4 !important;
    }
    div[data-testid="stDataFrame"] { 
        background-color: white !important;
        border-radius: 12px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.04);
        border: 1px solid rgba(15, 76, 58, 0.05);
    }
    .sidebar .sidebar-content {
        background: linear-gradient(180deg, #0F4C3A 0%, #08291F 100%);
    }
    .stAlert {
        border-radius: 12px;
        border-left: 4px solid #D4AF37;
    }
    .card {
        background: white;
        border-radius: 16px;
        padding: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.03);
        margin-bottom: 24px;
        border: 1px solid rgba(0,0,0,0.03);
    }
    .metric-card {
        background: white;
        border-radius: 12px;
        padding: 24px;
        text-align: center;
        box-shadow: 0 4px 6px rgba(0,0,0,0.04);
        border-top: 4px solid #D4AF37;
        transition: transform 0.2s ease;
    }
    .metric-card:hover {
        transform: translateY(-4px);
        box-shadow: 0 8px 15px rgba(0,0,0,0.06);
    }
    .metric-value {
        font-size: 2.2rem;
        font-weight: 800;
        color: #0F4C3A;
        letter-spacing: -1px;
    }
    .metric-label {
        font-size: 0.9rem;
        color: #556B60;
        margin-top: 8px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    .status-badge {
        display: inline-block;
        padding: 6px 14px;
        border-radius: 20px;
        font-size: 0.8rem;
        font-weight: 600;
        letter-spacing: 0.3px;
    }
    .status-pending { background: #fef3c7; color: #92400e; }
    .status-approved { background: #d1fae5; color: #065f46; }
    .status-active { background: #dbeafe; color: #1e40af; }
    .status-completed { background: #f3f4f6; color: #374151; }
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
    "group_location": "Group Location", "group_leader_name": "Group Leader Name", "group_formation_date": "Group Formation Date"
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
    """Load all loans from Supabase"""
    if not supabase:
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
    """Load all repayments from Supabase"""
    if not supabase:
        return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
    try:
        response = supabase.table("repayments").select("*").execute()
        if not response.data:
            return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
        return pd.DataFrame(response.data).rename(columns=DB_TO_UI_REP)
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

def calculate_loan_setup(amount, product_type):
    """Calculate loan setup parameters"""
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
        
        if savings_dep > 0 or loan_rep > 0 or withdrawal > 0:
            total_savings += savings_dep
            total_savings -= withdrawal
            total_loan_paid += loan_rep
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
    if not client_payments.empty:
        client_payments['DateObj'] = pd.to_datetime(client_payments['Date'], errors='coerce')
    
    if "Daily" in str(loan_product):
        start_of_week = view_date - timedelta(days=view_date.weekday())
        days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        for i in range(5):
            current_day = start_of_week + timedelta(days=i)
            daily_total = 0
            if not client_payments.empty:
                mask = client_payments['DateObj'].dt.date == current_day
                daily_total = client_payments.loc[mask, 'Amount Paid'].sum()
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
            if not client_payments.empty:
                mask = client_payments['DateObj'].dt.date == meeting_date
                week_total = client_payments.loc[mask, 'Amount Paid'].sum()
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
if 'logged_in' not in st.session_state:
    st.session_state['logged_in'] = False

if not st.session_state['logged_in']:
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.markdown("<h1 style='text-align: center;'>🏦 TrustMicro Credit</h1>", unsafe_allow_html=True)
        st.markdown("<h3 style='text-align: center; color: #666;'>Loan Management System</h3>", unsafe_allow_html=True)
        st.markdown("<hr>", unsafe_allow_html=True)
        
        with st.form("login"):
            st.markdown("<h4>🔐 System Login</h4>", unsafe_allow_html=True)
            username = st.text_input("Username", placeholder="Enter username")
            pw = st.text_input("Password", type="password", placeholder="Enter password")
            
            col_btn1, col_btn2, col_btn3 = st.columns([1, 2, 1])
            with col_btn2:
                submitted = st.form_submit_button("LOGIN", use_container_width=True)
            
            if submitted:
                user_data = USERS.get(username.lower())
                if user_data and user_data['pass'] == pw:
                    st.session_state['logged_in'] = True
                    st.session_state['user'] = user_data['name']
                    st.session_state['role'] = user_data['role']
                    st.session_state['branch'] = user_data['branch']
                    st.rerun()
                else:
                    st.error("❌ Invalid Username or Password")
        
        st.markdown("<p style='text-align: center; color: #999; font-size: 0.8rem;'>Demo: admin/bm/john/jane (Password: 1234)</p>", unsafe_allow_html=True)
        st.markdown("</div>", unsafe_allow_html=True)
    st.stop()

# --- 5. SIDEBAR ---
ROLE = st.session_state['role']
USER = st.session_state['user']
BRANCH = st.session_state['branch']

with st.sidebar:
    st.markdown(f"<h2 style='color: white;'>🏦 {COMPANY_NAME}</h2>", unsafe_allow_html=True)
    st.markdown(f"<p style='color: #ccc; font-size: 0.8rem;'>v{APP_VERSION}</p>", unsafe_allow_html=True)
    st.divider()
    
    st.markdown(f"""
        <div style='background: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px; margin-bottom: 15px;'>
            <p style='color: white; margin: 0; font-size: 1rem;'>👤 <strong>{USER}</strong></p>
            <p style='color: #ccc; margin: 5px 0 0 0; font-size: 0.85rem;'>🛡️ {ROLE} | 📍 {BRANCH}</p>
        </div>
    """, unsafe_allow_html=True)
    
    st.divider()
    
    if ROLE == "Officer":
        nav_options = ["Dashboard", "Loan Origination", "Collections & Arrears", "Portfolio Management", "Loan Calculator", "Reports"]
    else:
        nav_options = ["Branch Dashboard", "Loan Origination", "Branch Audit Ledger", "Global Portfolio Management", "Loan Calculator", "Compliance & Export"]
    
    page = st.radio("Navigation", nav_options, label_visibility="collapsed")
    
    st.divider()
    
    if st.button("🚪 LOGOUT", use_container_width=True):
        st.session_state.clear()
        st.rerun()

# Status indicator
if ROLE == "Admin":
    st.info("🌍 **Global View Mode:** Connected to Cloud Database")
elif ROLE == "BM":
    st.info(f"🏢 **Branch View Mode:** Connected to Cloud Database")
else:
    st.info(f"👤 **Officer View Mode:** Connected to Cloud Database")

# --- 6. PAGES ---

if page in ["Dashboard", "Branch Dashboard"]:
    st.title("📊 Performance & Risk Dashboard")
    
    all_loans = load_loans()
    all_repayments = load_repayments()
    my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
    
    # Calculate metrics
    summary = generate_portfolio_summary(my_loans, all_repayments)
    
    # Top metrics row
    st.markdown("### 💰 Liquidity Overview")
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.markdown(f"""
            <div class='metric-card'>
                <div class='metric-value'>{summary['active_loans']}</div>
                <div class='metric-label'>Active Loans</div>
            </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown(f"""
            <div class='metric-card'>
                <div class='metric-value'>₦{summary['total_cash_in']:,.0f}</div>
                <div class='metric-label'>Cumulative Collections</div>
            </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown(f"""
            <div class='metric-card'>
                <div class='metric-value'>₦{summary['total_savings']:,.0f}</div>
                <div class='metric-label'>Deposits (Liabilities)</div>
            </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown(f"""
            <div class='metric-card'>
                <div class='metric-value'>{summary['pending_count']}</div>
                <div class='metric-label'>Pending Approvals</div>
            </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # Risk metrics
    st.markdown("### ⚠️ Portfolio Health")
    r1, r2, r3 = st.columns(3)
    
    r1.metric("Total Active Portfolio", f"₦{summary['total_portfolio']:,.0f}")
    
    od_color = "inverse" if summary['total_overdue'] > 0 else "normal"
    r2.metric("🚨 Total Overdue Cash", f"₦{summary['total_overdue']:,.0f}", delta_color=od_color)
    
    par_color = "inverse" if summary['par_percentage'] > 5 else "normal"
    r3.metric("📈 Portfolio At Risk (PAR)", f"{summary['par_percentage']:.1f}%", delta_color=par_color)
    
    # Charts
    st.divider()
    st.markdown("### 📈 Visual Analytics")
    
    chart_col1, chart_col2 = st.columns(2)
    
    with chart_col1:
        portfolio_chart = create_portfolio_chart(my_loans)
        if portfolio_chart:
            st.plotly_chart(portfolio_chart, use_container_width=True)
        else:
            st.info("No data for portfolio chart")
    
    with chart_col2:
        trend_chart = create_weekly_trend_chart(all_repayments)
        if trend_chart:
            st.plotly_chart(trend_chart, use_container_width=True)
        else:
            st.info("No data for trend chart")
    
    # Officer breakdown for Admin/BM
    if ROLE in ["Admin", "BM"] and not my_loans.empty:
        st.divider()
        st.markdown("### 👥 Officer Risk Breakdown")
        
        officer_data = []
        for _, row in my_loans[my_loans['Status'].isin(['Approved', 'Active'])].iterrows():
            c_payments = all_repayments[all_repayments['Client ID'] == row['Client ID']] if not all_repayments.empty else pd.DataFrame()
            _, l_amt = calculate_client_savings(c_payments, row['Loan Repay'])
            expected, overdue = calculate_overdue(row['Date'], row['Loan Product'], row['Loan Repay'], l_amt)
            loan_balance = max(0, float(row['Active Credit']) - l_amt)
            
            officer_data.append({
                "Officer": row['Officer'],
                "Active Portfolio": loan_balance,
                "Overdue Cash": overdue,
                "PAR Balance": loan_balance if overdue > 0 else 0
            })
        
        if officer_data:
            summary_df = pd.DataFrame(officer_data).groupby("Officer").sum().reset_index()
            summary_df["PAR %"] = (summary_df["PAR Balance"] / summary_df["Active Portfolio"] * 100).fillna(0).round(1).astype(str) + "%"
            
            st.dataframe(
                summary_df.style.format({
                    "Active Portfolio": "₦{:,.0f}",
                    "Overdue Cash": "₦{:,.0f}",
                    "PAR Balance": "₦{:,.0f}"
                }),
                use_container_width=True
            )
            
            # Officer performance chart
            perf_chart = create_officer_performance_chart(officer_data)
            if perf_chart:
                st.plotly_chart(perf_chart, use_container_width=True)

elif page == "Loan Origination":
    st.title("📝 New Loan Application")
    
    with st.form("app_form"):
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("1. Member's Data")
        c1, c2, c3 = st.columns(3)
        name = c1.text_input("Full Name (Surname First)", placeholder="Enter full name")
        nickname = c2.text_input("Nickname", placeholder="e.g. Iya Oloja")
        phone = c3.text_input("Phone Number", placeholder="e.g. 08012345678")
        
        c4, c5 = st.columns(2)
        address = c4.text_area("Home Address", height=70, placeholder="Client's home address")
        biz_address = c5.text_area("Business / Address", height=70, placeholder="Client's business address")
        
        c6, c7, c8 = st.columns(3)
        marital_status = c6.selectbox("Marital Status", ["Single", "Married", "Divorced", "Widowed"])
        biz_type = c7.selectbox("Occupation", ["Trader", "Artisan", "Driver", "SME", "Other"])
        monthly_income = c8.number_input("Average Monthly Income (₦)", value=0, step=5000)
        
        other_obs = st.text_input("Obligation with other institution", placeholder="If none, type 'None'")
        st.markdown("</div>", unsafe_allow_html=True)
        
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("2. Guarantor's Undertaking")
        g1, g2, g3 = st.columns(3)
        g_name = g1.text_input("Guarantor Full Name", placeholder="Surname first")
        g_nick = g2.text_input("Guarantor Nickname")
        g_phone = g3.text_input("Guarantor Phone")
        
        g4, g5 = st.columns(2)
        g_address = g4.text_area("Guarantor Home Address", height=70)
        g_office = g5.text_area("Guarantor Office Address", height=70)
        
        g6, g7, g8 = st.columns(3)
        g_marital = g6.selectbox("Guarantor Marital Status", ["Single", "Married", "Divorced", "Widowed"])
        g_occ = g7.text_input("Guarantor Occupation")
        g_rel = g8.text_input("Relationship with Borrower")
        st.markdown("</div>", unsafe_allow_html=True)
        
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("3. Group Undertaking")
        gr1, gr2, gr3 = st.columns(3)
        group_name = gr1.text_input("Group Name", placeholder="e.g. Market Women A")
        group_loc = gr2.text_input("Group Location / Address")
        meeting_day = gr3.selectbox("Meeting Day", ["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"])
        
        gr4, gr5 = st.columns(2)
        group_leader = gr4.text_input("Group Leader's Name")
        group_date = gr5.date_input("Date of Formation", datetime.now())
        
        if ROLE in ["Admin", "BM"]:
            assigned_officer = st.selectbox("Assign to Officer:", ["John", "Jane"])
        else:
            st.write(f"**Assigned Officer:** {USER}")
            assigned_officer = USER
        st.markdown("</div>", unsafe_allow_html=True)
        
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("4. Financial Request (Applied Credit)")
        prod_col, amt_col = st.columns(2)
        product = prod_col.selectbox(
            "Proposed Scheme",
            ["Daily Loan (60 Days)", "Weekly Loan (12 Weeks)", "Weekly Loan (24 Weeks)"]
        )
        amount = amt_col.number_input("Applied Credit Amount (Principal ₦)", value=100000, step=5000, min_value=10000)
        
        setup = calculate_loan_setup(amount, product)
        
        st.markdown("---")
        col_gap, col_int = st.columns(2)
        manual_gap = col_gap.number_input("Savings Balance (Gap/Deposit)", value=int(setup['initial_payment']), step=500)
        col_int.metric("Interest (Fixed)", f"₦{setup['interest']:,.0f}")
        
        total_upfront = manual_gap + setup['interest']
        st.info(f"**Total Upfront to Collect:** ₦{total_upfront:,.0f}")
        
        st.markdown("#### Setup Fees (One-time)")
        f1, f2, f3 = st.columns(3)
        processing_fee = f1.number_input("Processing Fee", value=0, step=50)
        markup = f2.number_input("Markup", value=0, step=50)
        pass_book_fee = f3.number_input("Pass Book Fee", value=0, step=50)
        
        active_credit = amount - manual_gap
        raw_repay = active_credit / setup['duration']
        final_repay = math.ceil(raw_repay / 10) * 10
        
        k1, k2 = st.columns(2)
        k1.metric("Outstanding Principal", f"₦{active_credit:,.0f}")
        k2.metric(f"Fixed {setup['freq']} Repayment", f"₦{final_repay:,.0f}")
        st.markdown("</div>", unsafe_allow_html=True)
        
        col_btn1, col_btn2, col_btn3 = st.columns([2, 1, 2])
        with col_btn2:
            submitted = st.form_submit_button("📝 ORIGINATE LOAN", use_container_width=True)
        
        if submitted:
            if not name or not phone:
                st.error("❌ Please fill in all required fields (Name and Phone)")
            else:
                data = {
                    "Client ID": str(uuid.uuid4()),
                    "Date": datetime.now().strftime("%Y-%m-%d"),
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
                    "Loan Product": product,
                    "Loan Amount": amount,
                    "Active Credit": active_credit,
                    "Loan Repay": final_repay,
                    "Total Due": active_credit,
                    "Status": "Pending",
                    "Processing Fee": processing_fee,
                    "Markup": markup,
                    "Pass Book Fee": pass_book_fee
                }
                save_new_loan(data)
                st.success("✅ Application Saved to Database!")
                st.balloons()

elif page in ["Collections & Arrears", "Branch Audit Ledger"]:
    st.title(f"📂 {page}")
    
    all_loans = load_loans()
    my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
    active_clients = my_loans[my_loans['Status'].isin(['Approved', 'Active'])]
    
    if active_clients.empty:
        st.warning("⚠️ No Active clients assigned to you.")
    else:
        c1, c2 = st.columns([2, 1])
        client_ids = active_clients['Client ID'].tolist()
        
        def format_client_dropdown(cid):
            row = active_clients[active_clients['Client ID'] == cid].iloc[0]
            return f"{row['Client Name']} ({row['Phone']})"
        
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
        
        # Record granular payment
        st.markdown("---")
        st.subheader("💸 Record Granular Collection")
        
        with st.form("pay_form"):
            st.caption(f"Expected Fixed Repayment: **₦{fixed_repay:,.0f}**")
            
            # Group into logical rows for UI clarity
            col1, col2, col3 = st.columns(3)
            loan_rep = col1.number_input("Loan Instalment (₦)", value=0, step=500)
            savings_dep = col2.number_input("Savings Deposit (₦)", value=0, step=500)
            withdrawal = col3.number_input("Savings Withdrawal (₦)", value=0, step=500)
            
            f1, f2, f3 = st.columns(3)
            proc_fee = f1.number_input("Processing Fee (₦)", value=0, step=100)
            pass_book = f2.number_input("Pass Book (₦)", value=0, step=100)
            markup_pd = f3.number_input("Markup (₦)", value=0, step=100)
            
            o1, o2, o3 = st.columns(3)
            recovery = o1.number_input("Recovery (₦)", value=0, step=100)
            mgt_fee = o2.number_input("Mgt Fee (₦)", value=0, step=100)
            others = o3.number_input("Others (₦)", value=0, step=100)
            
            note_col = st.text_input("Note", placeholder="e.g. Week 4 Group Collection")
            
            # Auto-calculate total cache layout for sanity check
            total_cache_in = loan_rep + savings_dep + proc_fee + pass_book + markup_pd + recovery + mgt_fee + others
            st.info(f"**Total Cash From Client Today:** ₦{total_cache_in:,.0f} (Excluding withdrawals)")
            
            if st.form_submit_button("🏦 AUTHORIZE CASH POSTING"):
                pay_data = {
                    "Date": datetime.now().strftime("%Y-%m-%d %H:%M"),
                    "Branch": BRANCH,
                    "Client ID": selected_id,
                    "Client Name": client_loan['Client Name'],
                    "Amount Paid": total_cache_in, # Kept for backward compatibility
                    "Officer": USER,
                    "Note": note_col,
                    "Transaction Type": "Granular",
                    "Savings Amount": savings_dep,
                    "Loan Repayment Amount": loan_rep,
                    "Processing Fee Paid": proc_fee,
                    "Markup Paid": markup_pd,
                    "Pass Book Paid": pass_book,
                    "Recovery Amount": recovery,
                    "Withdrawal Amount": withdrawal,
                    "Mgt Fee Paid": mgt_fee,
                    "Others Amount": others
                }
                save_repayment(pay_data)
                st.success("✅ Detailed Collection Recorded Globally!")
                st.rerun()

elif page in ["Portfolio Management", "Global Portfolio Management"]:
    st.title(f"🗂️ {page}")
    
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
                "Officer": st.column_config.SelectboxColumn("Officer", options=["John", "Jane", "System Admin"], disabled=(ROLE == "Officer")),
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

elif page == "Loan Calculator":
    st.title("🧮 Loan Simulator")
    
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

elif page in ["Reports", "Compliance & Export"]:
    st.title("📑 Reports & Data Export")
    
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
        selected_officer = st.selectbox("Select Officer:", ["All"] + list(officers))
        
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
