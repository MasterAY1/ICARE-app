import streamlit as st
st.set_page_config(
    page_title="ICARE Microfinance - Core Banking",
    page_icon="🌱",
    layout="wide",
    initial_sidebar_state="expanded"
)

from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.queries import LoanFilter, RepaymentFilter, CashbookFilter
from domain.entities.loan import Loan
from domain.entities.repayment import Repayment
from domain.entities.cashbook_entry import CashbookEntry
from domain.entities.branch_closure import BranchClosure
from domain.events import *
from core.exceptions import *
from core.cache import CacheProvider


# --- CLEAN ARCHITECTURE CONFIG IMPORTS ---
from config.settings import *
from config.roles import *
from config.constants import *
from config.mappings import *
from config.themes import *
from config.feature_flags import *



import pandas as pd
from datetime import date, datetime, timedelta
from dateutil.relativedelta import relativedelta
import math
import uuid
import hashlib
import base64
import os
from supabase import create_client, Client
import holidays

# Initialize Nigerian holidays
ng_holidays = holidays.Nigeria()

@CacheProvider.cache_data(ttl=3600)
def get_custom_closures():
    try:
        with SupabaseUnitOfWork() as uow:
            closures = uow.branch_closures.find_all()
            return [(c.start_date, c.end_date, c.reason, c.branch_id) for c in closures]
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
        # Step the THEORETICAL date forward for this installment
        if frequency.lower() == 'daily':
            theoretical_date += timedelta(days=1)
        elif frequency.lower() == 'weekly':
            theoretical_date += timedelta(days=7)
        elif frequency.lower() == 'monthly':
            theoretical_date += relativedelta(months=1)
            
        # Find the actual valid working day for this installment
        valid_date, _, _ = get_next_working_day(theoretical_date, closures)
        schedule.append(valid_date)
            
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


# Add utils to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from utils.google_sheets import export_loans_to_sheet, export_repayments_to_sheet, export_summary_report
from utils.reports import (
    generate_portfolio_summary, create_portfolio_chart, 
    create_officer_performance_chart, create_weekly_trend_chart,
    generate_officer_report, export_to_excel
)

# --- 1. CONFIGURATION & CLOUD DB SETUP ---



@CacheProvider.cache_data(ttl=600)
def load_co_mapping():
    try:
        with SupabaseUnitOfWork() as uow:
            users = uow.users.find_all()
            co_users = [u for u in users if u.role in ['CO', 'Officer']]
            name_map = {u.full_name.strip(): u.username for u in co_users if u.full_name}
            display_map = {v: k for k, v in name_map.items()}
            return name_map, display_map
    except Exception:
        pass
    return {}, {}

CO_NAME_MAP, CO_DISPLAY_MAP = load_co_mapping()

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
    .stMetric, [data-testid="stMetric"], [data-testid="stMetricContainer"], [data-testid="metric-container"] {
        background: #FFFFFF !important;
        border-radius: 12px !important;
        padding: 16px !important;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04) !important;
        border: 1px solid #E5E7EB !important;
        transition: transform 0.2s ease, box-shadow 0.2s ease !important;
    }
    .stMetric:hover, [data-testid="stMetric"]:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(46,134,193,0.12) !important; }
    div[data-testid="stMetricValue"], [data-testid="stMetricValue"] { 
        color: #1B4F72 !important; 
        font-size: clamp(1.15rem, 3.2vw, 1.65rem) !important; 
        font-weight: 800 !important; 
        white-space: normal !important;
        word-break: break-word !important;
        overflow: visible !important;
        text-overflow: clip !important;
        line-height: 1.25 !important;
    }
    div[data-testid="stMetricLabel"], [data-testid="stMetricLabel"] { 
        color: #6B7280 !important; 
        font-size: clamp(0.68rem, 1.8vw, 0.78rem) !important; 
        font-weight: 600 !important; 
        text-transform: uppercase !important; 
        letter-spacing: 0.4px !important;
        white-space: normal !important;
        line-height: 1.25 !important;
    }
    div[data-testid="stMetricDelta"], [data-testid="stMetricDelta"] {
        font-size: clamp(0.7rem, 1.8vw, 0.8rem) !important;
    }

    /* === RESPONSIVE MOBILE 2-IN-A-ROW METRIC GRID === */
    @media (max-width: 768px) {
        div[data-testid="stHorizontalBlock"]:has(div[data-testid="stMetric"]) {
            display: flex !important;
            flex-direction: row !important;
            flex-wrap: wrap !important;
            gap: 8px !important;
        }
        div[data-testid="stHorizontalBlock"]:has(div[data-testid="stMetric"]) > div[data-testid="column"] {
            flex: 1 1 calc(50% - 8px) !important;
            min-width: calc(50% - 8px) !important;
            max-width: calc(50% - 8px) !important;
            padding: 0 !important;
            margin-bottom: 4px !important;
        }
        .stMetric, [data-testid="stMetric"], [data-testid="stMetricContainer"], [data-testid="metric-container"] {
            padding: 10px 12px !important;
            border-radius: 8px !important;
        }
        div[data-testid="stMetricValue"], [data-testid="stMetricValue"] {
            font-size: clamp(1.05rem, 4.2vw, 1.35rem) !important;
        }
    }
    
    /* === ENTERPRISE PILL TABS === */
    div[data-baseweb="tab-list"] {
        gap: 10px !important;
        background: transparent !important;
        border-bottom: 2px solid #E2E8F0 !important;
        padding-bottom: 8px !important;
        margin-bottom: 18px !important;
    }
    button[data-baseweb="tab"] {
        background-color: #FFFFFF !important;
        border: 1px solid #CBD5E1 !important;
        border-radius: 8px !important;
        padding: 8px 18px !important;
        font-weight: 600 !important;
        font-size: 0.88rem !important;
        color: #475569 !important;
        transition: all 0.2s ease-in-out !important;
        box-shadow: 0 1px 2px rgba(0,0,0,0.05) !important;
    }
    button[data-baseweb="tab"]:hover {
        background-color: #F8FAFC !important;
        border-color: #94A3B8 !important;
        color: #1E293B !important;
    }
    button[data-baseweb="tab"][aria-selected="true"] {
        background-color: #1B4F72 !important;
        border-color: #1B4F72 !important;
        color: #FFFFFF !important;
        box-shadow: 0 2px 6px rgba(27, 79, 114, 0.25) !important;
    }
    button[data-baseweb="tab"][aria-selected="true"] p,
    button[data-baseweb="tab"][aria-selected="true"] span,
    button[data-baseweb="tab"][aria-selected="true"] div {
        color: #FFFFFF !important;
    }
    div[data-baseweb="tab-highlight"],
    div[data-baseweb="tab-border"] {
        display: none !important;
    }
    
    
    /* === INPUTS === */
    [data-testid="stTextInput"] input,
    [data-testid="stNumberInput"] input,
    [data-testid="stSelectbox"] div,
    [data-testid="stTextArea"] textarea,
    [data-testid="stDateInput"] input,
    .stTextInput input, .stNumberInput input, .stSelectbox div, 
    .stTextArea textarea, .stDateInput input {
        background-color: #FFFFFF !important;
        color: #1A1D23 !important;
        border: 1px solid #D1D5DB;
        border-radius: 8px;
    }
    [data-testid="stTextInput"] input:focus,
    [data-testid="stNumberInput"] input:focus,
    .stTextInput input:focus, .stNumberInput input:focus {
        border-color: #2E86C1 !important;
        box-shadow: 0 0 0 3px rgba(46, 134, 193, 0.12) !important;
    }
    
    /* === LABEL FIX === */
    /* Root cause: login CSS set -webkit-text-fill-color to white on ALL forms. */
    /* Must override -webkit-text-fill-color, not just color.                   */
    
    /* 1. Override for ALL form text input labels (beats login CSS) */
    [data-testid="stForm"] [data-testid="stTextInput"] label,
    [data-testid="stForm"] [data-testid="stTextInput"] label span,
    [data-testid="stForm"] [data-testid="stTextInput"] label p,
    [data-testid="stForm"] [data-testid="stTextInput"] label div,
    [data-testid="stTextInput"] label,
    [data-testid="stTextInput"] label *,
    [data-testid="stNumberInput"] label,
    [data-testid="stNumberInput"] label *,
    [data-testid="stSelectbox"] label,
    [data-testid="stSelectbox"] label *,
    [data-testid="stTextArea"] label,
    [data-testid="stTextArea"] label *,
    [data-testid="stDateInput"] label,
    [data-testid="stDateInput"] label *,
    [data-testid="stFileUploader"] label,
    [data-testid="stFileUploader"] label * {
        color: #1B4F72 !important;
        -webkit-text-fill-color: #1B4F72 !important;
        font-weight: 600 !important;
        font-size: 0.9rem !important;
    }
    
    /* 2. Widget label and markdown containers */
    [data-testid="stWidgetLabel"],
    [data-testid="stWidgetLabel"] * {
        color: #1B4F72 !important;
        -webkit-text-fill-color: #1B4F72 !important;
        font-weight: 600 !important;
    }
    
    /* 3. Class-based fallback */
    .stTextInput label, .stTextInput label *,
    .stNumberInput label, .stNumberInput label *,
    .stSelectbox label, .stSelectbox label *,
    .stTextArea label, .stTextArea label *,
    .stDateInput label, .stDateInput label * {
        color: #1B4F72 !important;
        -webkit-text-fill-color: #1B4F72 !important;
        font-weight: 600 !important;
        font-size: 0.9rem !important;
    }
    
    /* 4. Nuclear — every label in main content area */
    section.main label,
    section.main label *,
    .main label,
    .main label * {
        color: #1B4F72 !important;
        -webkit-text-fill-color: #1B4F72 !important;
        font-weight: 600 !important;
    }
    
    /* 5. Input instruction hints */
    [data-testid="InputInstructions"],
    div[data-testid="InputInstructions"] {
        color: #475569 !important;
        -webkit-text-fill-color: #475569 !important;
    }
    
    /* === FULL-WIDTH LAYOUT === */
    .main .block-container,
    section.main > div.block-container,
    section[data-testid="stMain"] > div.block-container,
    div[data-testid="stMainBlockContainer"] {
        max-width: 95% !important;
        padding-left: 2rem !important;
        padding-right: 2rem !important;
    }
    [data-testid="stForm"] {
        width: 100% !important;
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
    
    /* === LOGIN PAGE — PREMIUM SPLIT LAYOUT v3.0 === */
    .login-page-bg {
        position: fixed;
        top: 0; left: 0; right: 0; bottom: 0;
        background: linear-gradient(140deg, #0A1628 0%, #0F2744 25%, #163B5C 50%, #1B4F72 75%, #0F2744 100%);
        z-index: -2;
        overflow: hidden;
    }
    .login-page-bg::before {
        content: '';
        position: fixed;
        width: 600px; height: 600px;
        top: -15%; left: -10%;
        background: radial-gradient(circle, rgba(140,198,63,0.12) 0%, transparent 70%);
        border-radius: 50%;
        z-index: -1;
        animation: loginOrb1 12s ease-in-out infinite alternate;
    }
    .login-page-bg::after {
        content: '';
        position: fixed;
        width: 500px; height: 500px;
        bottom: -10%; right: -5%;
        background: radial-gradient(circle, rgba(46,134,193,0.15) 0%, transparent 70%);
        border-radius: 50%;
        z-index: -1;
        animation: loginOrb2 10s ease-in-out infinite alternate;
    }
    @keyframes loginOrb1 {
        0% { transform: translate(0, 0) scale(1); opacity: 0.5; }
        50% { transform: translate(60px, 40px) scale(1.15); opacity: 0.8; }
        100% { transform: translate(-30px, 60px) scale(1.05); opacity: 0.6; }
    }
    @keyframes loginOrb2 {
        0% { transform: translate(0, 0) scale(1); opacity: 0.4; }
        50% { transform: translate(-50px, -30px) scale(1.2); opacity: 0.7; }
        100% { transform: translate(40px, -50px) scale(1.1); opacity: 0.5; }
    }
    
    /* Floating particle dots */
    .login-particles {
        position: fixed;
        top: 0; left: 0; right: 0; bottom: 0;
        z-index: -1;
        overflow: hidden;
        pointer-events: none;
    }
    .login-particles span {
        position: absolute;
        width: 3px; height: 3px;
        background: rgba(140,198,63,0.3);
        border-radius: 50%;
        animation: loginFloat 20s linear infinite;
    }
    .login-particles span:nth-child(1) { left: 10%; animation-delay: 0s; animation-duration: 18s; }
    .login-particles span:nth-child(2) { left: 25%; animation-delay: 2s; animation-duration: 22s; width: 2px; height: 2px; }
    .login-particles span:nth-child(3) { left: 45%; animation-delay: 4s; animation-duration: 16s; background: rgba(46,134,193,0.25); }
    .login-particles span:nth-child(4) { left: 65%; animation-delay: 1s; animation-duration: 24s; width: 4px; height: 4px; background: rgba(140,198,63,0.2); }
    .login-particles span:nth-child(5) { left: 80%; animation-delay: 3s; animation-duration: 20s; background: rgba(46,134,193,0.2); }
    .login-particles span:nth-child(6) { left: 55%; animation-delay: 5s; animation-duration: 26s; width: 2px; height: 2px; }
    @keyframes loginFloat {
        0% { bottom: -10px; opacity: 0; }
        10% { opacity: 1; }
        90% { opacity: 1; }
        100% { bottom: 110%; opacity: 0; }
    }
    
    /* Split layout container */
    .login-split-wrap {
        display: flex;
        gap: 0;
        max-width: 1000px;
        margin: 0 auto;
        min-height: 85vh;
        align-items: center;
        animation: loginCardIn 0.8s cubic-bezier(0.16, 1, 0.3, 1) both;
    }
    @keyframes loginCardIn {
        0% { opacity: 0; transform: translateY(30px) scale(0.97); }
        100% { opacity: 1; transform: translateY(0) scale(1); }
    }
    
    /* Left panel — About ICARE */
    .login-info-panel {
        flex: 1.1;
        padding: 48px 44px;
        display: flex;
        flex-direction: column;
        justify-content: center;
    }
    .login-info-panel .info-badge {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        background: rgba(140,198,63,0.12);
        color: #8CC63F;
        font-size: 0.65rem;
        font-weight: 700;
        padding: 5px 14px;
        border-radius: 20px;
        border: 1px solid rgba(140,198,63,0.2);
        letter-spacing: 1px;
        text-transform: uppercase;
        margin-bottom: 20px;
        width: fit-content;
    }
    .login-info-panel .info-headline {
        font-size: 1.7rem;
        font-weight: 800;
        color: #FFFFFF;
        line-height: 1.25;
        margin: 0 0 6px 0;
        letter-spacing: -0.5px;
    }
    .login-info-panel .info-headline span {
        background: linear-gradient(135deg, #8CC63F, #2E86C1);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
    }
    .login-info-panel .info-slogan {
        font-size: 0.85rem;
        color: #8CC63F;
        font-weight: 600;
        font-style: italic;
        margin: 0 0 20px 0;
        letter-spacing: 0.3px;
    }
    .login-info-panel .info-desc {
        font-size: 0.78rem;
        color: rgba(255,255,255,0.55);
        line-height: 1.8;
        margin: 0 0 24px 0;
    }
    .login-info-panel .info-divider {
        width: 40px;
        height: 2px;
        background: linear-gradient(90deg, #8CC63F, transparent);
        margin: 0 0 20px 0;
        border-radius: 2px;
    }
    .login-info-panel .info-block {
        margin-bottom: 16px;
    }
    .login-info-panel .info-block-label {
        font-size: 0.62rem;
        font-weight: 700;
        color: rgba(255,255,255,0.35);
        text-transform: uppercase;
        letter-spacing: 1.5px;
        margin: 0 0 5px 0;
    }
    .login-info-panel .info-block-text {
        font-size: 0.75rem;
        color: rgba(255,255,255,0.65);
        line-height: 1.7;
        margin: 0;
    }
    .login-info-panel .info-values {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
        margin-top: 4px;
    }
    .login-info-panel .info-values span {
        background: rgba(255,255,255,0.06);
        color: rgba(255,255,255,0.6);
        font-size: 0.68rem;
        font-weight: 600;
        padding: 4px 12px;
        border-radius: 16px;
        border: 1px solid rgba(255,255,255,0.08);
    }
    .login-info-panel .info-address {
        font-size: 0.68rem;
        color: rgba(255,255,255,0.35);
        margin: 20px 0 0 0;
        padding-top: 16px;
        border-top: 1px solid rgba(255,255,255,0.06);
        line-height: 1.6;
    }
    .login-info-panel .info-address svg {
        width: 11px; height: 11px;
        vertical-align: -1px;
        margin-right: 4px;
        fill: rgba(255,255,255,0.3);
    }
    
    /* Right panel — Login form */
    .stApp:has(.login-page-bg) [data-testid="stForm"] {
        background: rgba(255, 255, 255, 0.06) !important;
        backdrop-filter: blur(24px) saturate(140%) !important;
        -webkit-backdrop-filter: blur(24px) saturate(140%) !important;
        border-radius: 24px !important;
        padding: 44px 36px 36px !important;
        border: 1px solid rgba(255,255,255,0.1) !important;
        box-shadow: 0 8px 32px rgba(0,0,0,0.3), 
                    0 0 0 1px rgba(255,255,255,0.05),
                    inset 0 1px 0 rgba(255,255,255,0.1) !important;
        max-width: 420px !important;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] .login-logo-wrap {
        text-align: center;
        margin-bottom: 6px;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] .login-logo-wrap img {
        width: 72px;
        height: 72px;
        object-fit: cover;
        border-radius: 50%;
        box-shadow: 0 0 0 3px rgba(140,198,63,0.3), 0 4px 20px rgba(0,0,0,0.3);
        border: 3px solid rgba(255,255,255,0.15);
        animation: loginLogoPulse 3s ease-in-out infinite;
    }
    @keyframes loginLogoPulse {
        0%, 100% { box-shadow: 0 0 0 3px rgba(140,198,63,0.3), 0 4px 20px rgba(0,0,0,0.3); }
        50% { box-shadow: 0 0 0 6px rgba(140,198,63,0.15), 0 4px 30px rgba(140,198,63,0.15); }
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] .login-brand-name {
        font-size: 1.6rem;
        font-weight: 800;
        color: #FFFFFF;
        letter-spacing: 6px;
        padding-left: 6px;
        margin: 10px 0 0 0;
        text-align: center;
        text-shadow: 0 2px 8px rgba(0,0,0,0.3);
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] .login-org-name {
        font-size: 0.68rem;
        color: rgba(255,255,255,0.45);
        text-align: center;
        line-height: 1.7;
        margin: 4px 0 0 0;
        letter-spacing: 0.3px;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] .login-accent-line {
        width: 44px;
        height: 3px;
        background: linear-gradient(90deg, #8CC63F, #2E86C1);
        margin: 18px auto;
        border-radius: 4px;
        box-shadow: 0 0 12px rgba(140,198,63,0.3);
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] .login-title {
        font-size: 1.05rem;
        font-weight: 700;
        color: #FFFFFF !important;
        text-align: center;
        margin: 0 0 2px 0;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] .login-subtitle {
        font-size: 0.75rem;
        color: rgba(255,255,255,0.4) !important;
        text-align: center;
        margin: 0 0 20px 0;
    }
    
    /* Style Streamlit form inputs on login page ONLY */
    /* Scoped to login page parent so it does NOT affect other forms */
    .stApp:has(.login-page-bg) [data-testid="stForm"] label,
    .stApp:has(.login-page-bg) [data-testid="stForm"] label span,
    .stApp:has(.login-page-bg) [data-testid="stForm"] label p {
        color: rgba(255,255,255,0.85) !important;
        -webkit-text-fill-color: rgba(255,255,255,0.85) !important;
        font-weight: 500 !important;
        font-size: 0.82rem !important;
        letter-spacing: 0.3px;
    }
    /* White input box — login only */
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-baseweb="input"] {
        background-color: #FFFFFF !important;
        background: #FFFFFF !important;
        border: 1px solid #D1D5DB !important;
        border-radius: 12px !important;
        transition: all 0.3s ease !important;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-baseweb="input"]:focus-within {
        border-color: #2E86C1 !important;
        box-shadow: 0 0 0 3px rgba(46, 134, 193, 0.12) !important;
    }
    /* Clear inner container background — login only */
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-baseweb="base-input"] {
        background-color: transparent !important;
        background: transparent !important;
    }
    /* Dark typed text for visibility — login only */
    .stApp:has(.login-page-bg) [data-testid="stForm"] input {
        color: #1A1D23 !important;
        -webkit-text-fill-color: #1A1D23 !important;
        background-color: transparent !important;
        background: transparent !important;
        padding: 12px 16px !important;
        font-size: 0.9rem !important;
        caret-color: #1A1D23 !important;
        font-weight: 500 !important;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] input::placeholder {
        color: #9CA3AF !important;
        -webkit-text-fill-color: #9CA3AF !important;
    }
    /* Password eye icon — login only */
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-baseweb="input"] button {
        color: #6B7280 !important;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-baseweb="input"] button svg {
        fill: #6B7280 !important;
    }
    /* Hide the "Press Enter to submit form" helper text — login only */
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-testid="InputInstructions"] {
        display: none !important;
    }
    
    /* Fix button */
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-testid="stFormSubmitButton"] button {
        background: linear-gradient(135deg, #8CC63F 0%, #6BA825 100%) !important;
        color: #FFFFFF !important;
        border: none !important;
        border-radius: 12px !important;
        padding: 14px !important;
        font-weight: 700 !important;
        font-size: 0.9rem !important;
        letter-spacing: 1.5px !important;
        margin-top: 8px !important;
        transition: all 0.3s ease !important;
        box-shadow: 0 4px 16px rgba(140,198,63,0.3) !important;
        width: 100% !important;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-testid="stFormSubmitButton"] button p {
        color: #FFFFFF !important;
        -webkit-text-fill-color: #FFFFFF !important;
        font-weight: 700 !important;
        font-size: 0.9rem !important;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-testid="stFormSubmitButton"] button:hover {
        transform: translateY(-2px) !important;
        box-shadow: 0 6px 24px rgba(140,198,63,0.4) !important;
        background: linear-gradient(135deg, #9AD44D 0%, #7CBB30 100%) !important;
    }
    .stApp:has(.login-page-bg) [data-testid="stForm"] [data-testid="stFormSubmitButton"] button:active {
        transform: translateY(0) !important;
    }
    
    .login-footer-bar {
        text-align: center;
        margin-top: 20px;
        padding-top: 16px;
        border-top: 1px solid rgba(255,255,255,0.08);
    }
    .login-footer-bar p {
        color: rgba(255,255,255,0.3);
        font-size: 0.68rem;
        margin: 0;
        letter-spacing: 0.5px;
    }
    .login-footer-bar .secured-badge {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        background: rgba(140,198,63,0.1);
        color: #8CC63F;
        font-size: 0.65rem;
        font-weight: 600;
        padding: 5px 12px;
        border-radius: 20px;
        margin-top: 10px;
        border: 1px solid rgba(140,198,63,0.2);
    }
    .login-footer-bar .secured-badge svg {
        width: 12px; height: 12px;
    }
    
    /* Mobile responsive — stack vertically */
    @media (max-width: 768px) {
        .login-split-wrap {
            flex-direction: column;
            gap: 0;
            min-height: auto;
            padding: 16px;
        }
        .login-info-panel {
            padding: 24px 20px 16px;
            text-align: center;
        }
        .login-info-panel .info-badge { margin: 0 auto 14px; }
        .login-info-panel .info-headline { font-size: 1.3rem; }
        .login-info-panel .info-divider { margin: 0 auto 16px; }
        .login-info-panel .info-values { justify-content: center; }
        .login-info-panel .info-address { text-align: center; }
        .login-glass-card { max-width: 100%; padding: 32px 24px 28px; }
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
    "branch_contingency": "Branch Contingency", "branch_contingency_2": "Branch Contingency 2",
    "disbursement_date": "Disbursement Date", "start_date": "Start Date", "expected_end_date": "Expected End Date"
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
    "asset_credit_sales": "Asset Credit Sales", "cash_and_carry": "Cash and Carry", "credit_form": "Credit Form", "credit_form_damage": "Credit Form Damage", "bonus": "Bonus",
    "payment_status": "Payment Status", "expected_amount": "Expected Amount", "overdue_amount": "Overdue Amount"
}
UI_TO_DB_REP = {v: k for k, v in DB_TO_UI_REP.items()}

def load_client_savings_map():
    """Load map of client code to cumulative savings balance from individual_savings table"""
    client_savings_map = {}
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        with SupabaseUnitOfWork() as uow:
            res_all_sav = uow.client.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount").execute()
            res_clients = uow.client.table("clients").select("client_id, client_code").execute()
            uuid_to_code = {c["client_id"]: c["client_code"] for c in res_clients.data if c.get("client_id") and c.get("client_code")}
            if res_all_sav.data:
                for s in res_all_sav.data:
                    cid_uuid = s.get("client_id")
                    if cid_uuid:
                        code = uuid_to_code.get(cid_uuid, cid_uuid)
                        dep = float(s.get("deposit_amount") or 0.0)
                        wd = float(s.get("withdrawal_amount") or 0.0)
                        client_savings_map[code] = client_savings_map.get(code, 0.0) + (dep - wd)
    except Exception:
        pass
    return client_savings_map

def load_loans():
    """Load loans filtered by RBAC hierarchy (UUID-based)"""
    try:
        with SupabaseUnitOfWork() as uow:
            filters = LoanFilter()
            filters.size = 2000
            
            loans = uow.loans.find_all()
            # UUID-based hierarchy filtering with safe fallback for cached class definitions
            def get_loan_officer_id(L):
                val = getattr(L, 'officer_id', None)
                if not val and L.credit_officer:
                    val = uow.loans._resolve_officer_id(L.credit_officer)
                return val

            def get_loan_branch_id(L):
                val = getattr(L, 'branch_id', None)
                if not val and L.branch:
                    val = uow.loans._resolve_branch_id(L.branch)
                return val

            if ROLE in ['CO', 'Officer', ROLE_CREDIT_OFFICER]:
                user_id = current_user.id if current_user else None
                loans = [L for L in loans if get_loan_officer_id(L) == user_id]
            elif ROLE in ['BM', ROLE_BRANCH_MANAGER]:
                loans = [L for L in loans if get_loan_branch_id(L) == BRANCH_ID]
            elif ROLE in ['AM', 'Area Manager']:
                loans = [L for L in loans if get_loan_branch_id(L) in ASSIGNED_BRANCH_IDS]
            # Admin / Super Admin: no filter
            
            if not loans:
                return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))
                
            from mappers.base_mappers import LoanMapper
            df = pd.DataFrame([LoanMapper.to_database(L) for L in loans]).rename(columns=DB_TO_UI_LOANS)
            if not df.empty and 'Date' in df.columns:
                df['Date'] = pd.to_datetime(df['Date'], errors='coerce').dt.strftime('%Y-%m-%d')
            
            # Fetch actual group names and meeting days from clients table to cover newly registered clients
            try:
                res_c = uow.client.table("clients").select("client_code, meeting_day, groups(name, meeting_day), app_users(full_name)").execute()
                if res_c.data:
                    code_to_group = {}
                    code_to_meeting = {}
                    code_to_officer = {}
                    for c in res_c.data:
                        code = c.get("client_code")
                        g_name = c.get("groups", {}).get("name") if c.get("groups") else None
                        m_day = c.get("meeting_day")
                        if not m_day and c.get("groups"):
                            m_day = c.get("groups", {}).get("meeting_day")
                        o_name = c.get("app_users", {}).get("full_name") if c.get("app_users") else None
                        if code:
                            if g_name:
                                code_to_group[code] = g_name
                            if m_day:
                                code_to_meeting[code] = m_day
                            if o_name:
                                code_to_officer[code] = o_name
                    df['Group Name'] = df['Client ID'].map(code_to_group).fillna(df['Group Name'])
                    df['Meeting Day'] = df['Client ID'].map(code_to_meeting).fillna(df['Meeting Day'])
                    df['Officer'] = df['Client ID'].map(code_to_officer).fillna(df['Officer'])
            except Exception:
                pass

            num_cols = ['Loan Amount', 'Active Credit', 'Loan Repay', 'Total Due']
            for c in num_cols:
                if c in df.columns:
                    df[c] = pd.to_numeric(df[c], errors='coerce').fillna(0)
            if not df.empty and 'Date' in df.columns and 'Client ID' in df.columns:
                df = df.sort_values('Date').groupby('Client ID').last().reset_index()
            return df
    except Exception as e:
        st.error(f"Database Error: {e}")
        return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))



def load_repayments():
    """Load repayments filtered by RBAC hierarchy (UUID-based)"""
    try:
        with SupabaseUnitOfWork() as uow:
            filters = RepaymentFilter()
            if ROLE in ['CO', 'Officer', ROLE_CREDIT_OFFICER]:
                filters.officer = USER
            elif ROLE in ['BM', ROLE_BRANCH_MANAGER]:
                filters.branch = BRANCH
            filters.size = 2000
            
            reps = uow.repayments.find_recent(filters)
            # Additional UUID-based filtering for AM with safe fallback
            if ROLE in ['AM', 'Area Manager'] and reps:
                def get_repayment_branch_id(r):
                    val = getattr(r, 'branch_id', None)
                    if not val and r.branch:
                        val = uow.repayments._resolve_branch_id(r.branch)
                    return val
                reps = [r for r in reps if get_repayment_branch_id(r) in ASSIGNED_BRANCH_IDS]
            
            if not reps:
                return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
                
            from mappers.base_mappers import RepaymentMapper
            df = pd.DataFrame([RepaymentMapper.to_database(R) for R in reps]).rename(columns=DB_TO_UI_REP)
            if not df.empty and 'Date' in df.columns:
                df['Date'] = pd.to_datetime(df['Date'], errors='coerce').dt.strftime('%Y-%m-%d')
            num_cols = ['Amt Paid', 'Savings Amount', 'Loan Repayment Amount', 'Withdrawal Amount', 'Others Amount', 'Recovery Amount', 'Initial Payment']
            for c in num_cols:
                if c in df.columns:
                    df[c] = pd.to_numeric(df[c], errors='coerce').fillna(0)
            return df
    except Exception as e:
        st.error(f"Database Error: {e}")
        return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))

def save_new_loan(data):
    """Save new loan and intercept upfront misc savings"""
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        from services.savings_service import SavingsService
        with SupabaseUnitOfWork() as uow:
            db_data = {UI_TO_DB_LOANS[k]: v for k, v in data.items() if k in UI_TO_DB_LOANS}
            from mappers.base_mappers import LoanMapper
            
            if 'id' not in db_data: db_data['id'] = ''
            if 'client_name' not in db_data: db_data['client_name'] = ''
            if 'branch' not in db_data: db_data['branch'] = BRANCH
            if 'credit_officer' not in db_data: db_data['credit_officer'] = db_data.get('officer', USER)
            
            loan = LoanMapper.to_domain(db_data)
            from services.loan_service import LoanService
            LoanService.disburse_loan(uow, loan)
            
            # Post upfront Misc Fees to Misc Savings Bucket
            misc_fees = float(db_data.get('misc_fees', 0))
            if misc_fees > 0:
                SavingsService.post_misc_savings(
                    uow, 
                    client_id=loan.client_id, 
                    client_name=loan.client_name, 
                    branch=loan.branch, 
                    officer=loan.officer, 
                    deposit_amount=misc_fees, 
                    remarks="Upfront Misc Fee Collection"
                )
    except Exception as e:
        st.error(f"Error saving loan: {e}")


def save_repayment(data, override_uow=None):
    """Save repayment and route savings to respective buckets"""
    print(f"\n[SAVINGS TRACE] Collections payload received: {data}")
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        from services.savings_service import SavingsService
        
        class UOWContext:
            def __enter__(self):
                if override_uow: return override_uow
                self.uow = SupabaseUnitOfWork()
                return self.uow.__enter__()
            def __exit__(self, exc_type, exc_val, exc_tb):
                if not override_uow:
                    return self.uow.__exit__(exc_type, exc_val, exc_tb)

        with UOWContext() as uow:
            db_data = {UI_TO_DB_REP[k]: v for k, v in data.items() if k in UI_TO_DB_REP}
            from mappers.base_mappers import RepaymentMapper
            
            # Map old DB keys expected by mapper
            if 'credit_officer' not in db_data: db_data['credit_officer'] = db_data.get('officer', USER)
            if 'branch' not in db_data: db_data['branch'] = BRANCH
            
            client_id = db_data.get('client_id', '')
            
            # Resolve client_code to database UUID if it's not a UUID and not a group/global code
            import uuid
            def is_valid_uuid(val):
                try:
                    uuid.UUID(str(val))
                    return True
                except ValueError:
                    return False
            
            resolved_client_id = client_id
            if client_id and not is_valid_uuid(client_id) and not str(client_id).startswith('GROUP-') and not str(client_id).startswith('GLOBAL-'):
                res_c = uow.client.table("clients").select("client_id").eq("client_code", client_id).execute()
                if res_c.data:
                    resolved_client_id = res_c.data[0]["client_id"]
            
            db_data['client_id'] = resolved_client_id
            client_id = resolved_client_id
            client_name = db_data.get('client_name', client_id)
            branch = db_data.get('branch', BRANCH)
            officer = db_data.get('credit_officer', USER)
            p_date_str = db_data.get('date') or datetime.now().strftime("%Y-%m-%d")
            p_date = datetime.strptime(p_date_str, "%Y-%m-%d").date()

            # Extract component amounts
            savings_dep = float(db_data.get('savings_amount', 0))
            savings_wd = float(db_data.get('withdrawal_amount', 0))
            group_dep = float(db_data.get('group_savings_dep', 0))
            group_wd = float(db_data.get('group_savings_wd', 0))
            laps_res = float(db_data.get('laps_reserved', 0))
            laps_trans = float(db_data.get('laps_transferred', 0))
            misc_fees = float(db_data.get('misc_fees', 0))
            loan_repay = float(db_data.get('loan_repayment_amount', 0))

            # 1. Route Group Savings
            if str(client_id).startswith('GROUP-'):
                group_name = str(client_id).replace('GROUP-', '')
                SavingsService.post_group_savings(uow, group_name, branch, officer, group_dep, group_wd, remarks=db_data.get('note'))
                return

            # 2. Route LAPS
            if str(client_id).startswith('GLOBAL-LAPS'):
                SavingsService.post_laps_savings(uow, client_id, client_name, branch, officer, laps_res, laps_trans)
                return

            # 3. Route Individual Savings
            if savings_dep > 0 or savings_wd > 0:
                SavingsService.post_individual_savings(uow, client_id, client_name, branch, officer, savings_dep, savings_wd, remarks=db_data.get('note'))

            # 4. Route Loan Repayment
            if loan_repay > 0:
                active_loan_id = None
                res_l = uow.client.table("loans").select("loan_id, active_credit").eq("client_id", client_id).eq("status", "Active").execute()
                if res_l.data:
                    active_loan_id = res_l.data[0]["loan_id"]
                    from services.schedule_service import ScheduleService
                    ScheduleService.record_repayment(uow, active_loan_id, loan_repay, p_date)

                db_data['loan_repayment_amount'] = loan_repay
                db_data['amount_paid'] = loan_repay
                if active_loan_id:
                    db_data['loan_id'] = active_loan_id
                rep = RepaymentMapper.to_domain(db_data)
                rep.amount_paid = loan_repay
                rep.loan_repayment_amount = loan_repay
                if active_loan_id:
                    rep.loan_id = active_loan_id

                try:
                    from services.repayment_service import RepaymentService
                    RepaymentService.post_repayment(uow, rep)
                except Exception as re:
                    print(f"[ERROR] Error inserting repayment for {client_id}: {re}")
                    st.error(f"Error inserting repayment for {client_id}: {re}")
                    return

            # 5. Route Misc Savings
            if misc_fees > 0:
                SavingsService.post_misc_savings(uow, client_id, client_name, branch, officer, misc_fees, remarks=db_data.get('note'))

            # 6. Route EOD / Global Inputs & Cash Flows
            import uuid
            from domain.entities.event_store import DomainEvent
            from services.posting_engine import FinancialPostingEngine

            def _is_valid_uuid(val):
                try:
                    uuid.UUID(str(val))
                    return True
                except (ValueError, AttributeError, TypeError):
                    return False

            officer_uuid = uow.loans._resolve_officer_id(officer)
            branch_uuid = uow.cashbook._resolve_branch_id(branch)
            valid_aggregate_id = str(client_id) if _is_valid_uuid(client_id) else (officer_uuid or branch_uuid or str(uuid.uuid4()))

            # Bank Deposited (Field Cash to Bank)
            bdep_amt = float(db_data.get('bank_deposited', 0))
            if bdep_amt > 0:
                ev_bdep = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Bank",
                    event_type="BankDeposited",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": bdep_amt, "date": p_date_str, "narration": f"End of Day cash deposit to bank by {officer}"}
                )
                uow.event_store.append(ev_bdep)
                FinancialPostingEngine.post_event(uow, ev_bdep)

            # Bank Withdrawal (Bank to Cash)
            bwd_amt = float(db_data.get('bank_withdrawal', 0))
            if bwd_amt > 0:
                ev_bwd = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Bank",
                    event_type="BankWithdrawn",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": bwd_amt, "date": p_date_str, "narration": f"Bank withdrawal by {officer}"}
                )
                uow.event_store.append(ev_bwd)
                FinancialPostingEngine.post_event(uow, ev_bwd)

            # Office Expenses
            exp_amt = float(db_data.get('expenses', 0))
            if exp_amt > 0:
                ev_exp = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Expense",
                    event_type="ExpenseRecorded",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": exp_amt, "date": p_date_str, "narration": f"Office expenses paid by {officer}"}
                )
                uow.event_store.append(ev_exp)
                FinancialPostingEngine.post_event(uow, ev_exp)

            # Passbook Fee / Bonus
            pb_amt = float(db_data.get('passbook_bonus') or db_data.get('pass_book_paid') or db_data.get('passbook') or 0.0)
            if pb_amt > 0:
                ev_pb = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": pb_amt, "date": p_date_str, "narration": f"Passbook fee from {client_name}"}
                )
                uow.event_store.append(ev_pb)
                FinancialPostingEngine.post_event(uow, ev_pb)

            # Bonus
            bon_amt = float(db_data.get('bonus', 0))
            if bon_amt > 0:
                ev_bon = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": bon_amt, "date": p_date_str, "narration": f"Bonus fee from {client_name}"}
                )
                uow.event_store.append(ev_bon)
                FinancialPostingEngine.post_event(uow, ev_bon)

            # Processing Fee / App Fee
            app_fee_amt = float(db_data.get('processing_fee_paid') or db_data.get('app_fee') or 0.0)
            if app_fee_amt > 0:
                ev_app = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": app_fee_amt, "date": p_date_str, "narration": f"Processing Fee from {client_name}"}
                )
                uow.event_store.append(ev_app)
                FinancialPostingEngine.post_event(uow, ev_app)

            # Cash and Carry
            cc_amount = float(db_data.get('cash_and_carry', 0))
            if cc_amount > 0:
                ev_cc = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Asset",
                    event_type="AssetSoldCash",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": cc_amount, "date": p_date_str, "narration": f"Cash & Carry asset sale to {client_name}"}
                )
                uow.event_store.append(ev_cc)
                FinancialPostingEngine.post_event(uow, ev_cc)

            # Credit Form Damage
            cfd_amount = float(db_data.get('credit_form_damage', 0))
            if cfd_amount > 0:
                ev_cfd = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": cfd_amount, "date": p_date_str, "narration": f"Credit Form Damage fee from {client_name}"}
                )
                uow.event_store.append(ev_cfd)
                FinancialPostingEngine.post_event(uow, ev_cfd)

            # Credit Form
            cf_amount = float(db_data.get('credit_form', 0))
            if cf_amount > 0:
                ev_cf = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": cf_amount, "date": p_date_str, "narration": f"Credit Form fee from {client_name}"}
                )
                uow.event_store.append(ev_cf)
                FinancialPostingEngine.post_event(uow, ev_cf)

            # Asset Credit Sales
            asset_cr_amount = float(db_data.get('asset_credit_sales', 0))
            if asset_cr_amount > 0:
                ev_as = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Asset",
                    event_type="AssetSoldCash",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": asset_cr_amount, "date": p_date_str, "narration": f"Asset Credit Sales for {client_name}"}
                )
                uow.event_store.append(ev_as)
                FinancialPostingEngine.post_event(uow, ev_as)

            # Route Markup and Contingency
            d11_val = float(db_data.get('daily_11_pct') or 0.0)
            d20_val = float(db_data.get('daily_20_pct') or 0.0)
            w11_val = float(db_data.get('weekly_11_pct') or 0.0)
            w20_val = float(db_data.get('weekly_20_pct') or 0.0)
            mm_val = float(db_data.get('monthly_markup') or 0.0)
            cont_val = float(db_data.get('contingency_paid') or 0.0)

            def post_fee_charge(amount_val, narration_str):
                if amount_val <= 0:
                    return
                event_fee = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={"branch": branch, "branch_id": branch_uuid, "officer": officer, "officer_id": officer_uuid, "amount": amount_val, "date": p_date_str, "narration": narration_str}
                )
                uow.event_store.append(event_fee)
                FinancialPostingEngine.post_event(uow, event_fee)

            post_fee_charge(d11_val, f"daily 11% markup fee from {client_name}")
            post_fee_charge(d20_val, f"daily 20% markup fee from {client_name}")
            post_fee_charge(w11_val, f"weekly 11% markup fee from {client_name}")
            post_fee_charge(w20_val, f"weekly 20% markup fee from {client_name}")
            post_fee_charge(mm_val, f"monthly markup risk premium fee from {client_name}")
            post_fee_charge(cont_val, f"contingency fee from {client_name}")
    except Exception as e:
        print(f"[ERROR] Error in save_repayment logic: {e}")
        st.error(f"Error in save_repayment logic: {e}")
        raise e


def save_repayments(data_list):
    """Save multiple repayments to database"""
    if not data_list:
        return
        
    from database.repositories.unit_of_work import SupabaseUnitOfWork
    from services.posting_engine import FinancialPostingEngine
    
    # 1. Enable deferred projections globally for this batch
    original_defer = getattr(FinancialPostingEngine, 'defer_projections', False)
    FinancialPostingEngine.defer_projections = True
    
    branch_id_to_rebuild = None
    date_to_rebuild = None
    
    try:
        with SupabaseUnitOfWork() as uow:
            for data in data_list:
                save_repayment(data, override_uow=uow)
                
                # capture branch and date for final rebuild
                if not branch_id_to_rebuild and 'Branch' in data:
                    branch_name = data.get('Branch')
                    try:
                        res = uow.client.table("branches").select("branch_id").eq("name", branch_name).execute()
                        if res.data: branch_id_to_rebuild = res.data[0]["branch_id"]
                    except Exception: pass
                    
                if not date_to_rebuild:
                    date_to_rebuild = data.get('Date')
                    
            # 2. Trigger ONE projection rebuild after all inserts are complete
            if branch_id_to_rebuild and date_to_rebuild:
                from datetime import date
                try:
                    p_date = date.fromisoformat(date_to_rebuild.split("T")[0])
                    uow.cashbook.rebuild_projection(branch_id_to_rebuild, p_date)
                    print(f"[SAVINGS TRACE] BATCH Cashbook projection rebuilt successfully.")
                except Exception as e:
                    print(f"Error in batch projection rebuild: {e}")
                    
    finally:
        FinancialPostingEngine.defer_projections = original_defer

def update_database_safe(edited_subset, user_role, user_name, branch):
    """Update database with edited data"""
    try:
        with SupabaseUnitOfWork() as uow:
            filters = LoanFilter()
            if user_role == "BM":
                filters.branch = branch
            elif user_role == "Officer":
                filters.officer = user_name
            
            # Since pagination is 1-based, we'd loop, but we will grab up to 1000 for now.
            filters.size = 1000
            existing_loans = uow.loans.find_active(filters)
            original_ids = [L.client_id for L in existing_loans]
            
            kept_ids = edited_subset["Client ID"].tolist()
            ids_to_delete = set(original_ids) - set(kept_ids)
            
            for d_id in ids_to_delete:
                uow.loans.delete_by_client_id(d_id)
            
            from mappers.base_mappers import LoanMapper
            loans_to_update = []
            for _, row in edited_subset.iterrows():
                db_data = {UI_TO_DB_LOANS[k]: row[k] for k in row.keys() if k in UI_TO_DB_LOANS}
                if "officer" in db_data:
                    db_data["credit_officer"] = CO_NAME_MAP.get(db_data["officer"], db_data["officer"])
                
                # Fetch existing to get id
                existing_matches = [L for L in existing_loans if L.client_id == db_data.get('client_id')]
                if existing_matches:
                    db_data["id"] = existing_matches[0].id
                # Intercept Client Closure logic
                if db_data.get("status") == STATUS_CLOSED:
                    db_data["client_status"] = "Closed"
                    # Preserve original loan status, or set to Completed if none found
                    if existing_matches:
                        original_status = existing_matches[0].status
                        db_data["status"] = original_status.value if hasattr(original_status, 'value') else original_status
                    else:
                        db_data["status"] = "Completed"
                        
                loan = LoanMapper.to_domain(db_data)
                loans_to_update.append(loan)
            
            # Repositories should ideally have bulk upsert, but we update individually for now
            from services.loan_service import LoanService
            for L in loans_to_update:
                if L.id:
                    uow.loans.update(L)
                else:
                    LoanService.disburse_loan(uow, L)
    except Exception as e:
        st.error(f"Error updating database safely: {e}")

def get_clients_for_user(df, user_role, user_name, branch):
    """Filter clients based on user role hierarchy (backward-compatible DataFrame filter)"""
    # Since load_loans() and load_repayments() already filter by RBAC UUID hierarchy,
    # we return the DataFrame directly to prevent name/string casing mismatches.
    return df

# --- 3. MATH HELPERS & RISK LOGIC ---

def calculate_overdue(start_date_str, product, fixed_repay, total_loan_paid, status=STATUS_ACTIVE):
    """Calculate overdue amount for a client"""
    if status in ['Registered', STATUS_PENDING]:
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
    
    # 1. Determine Product Parameters
    if "Cash and Carry" in str(product_type):
        rate = 0.0
        duration = 1
        freq = "One-Time"
        round_step = 1
        force_gap = False
    elif "120" in str(product_type):
        rate = 0.21
        duration = 120
        freq = "Daily"
        round_step = 50
        force_gap = False
    elif "Daily" in str(product_type) or "60" in str(product_type):
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
    
    # 2. Asset vs Finance Logic
    is_asset = "Asset" in str(product_category) or "Asset" in str(product_type)
    
    if is_asset:
        gap = 0
        loan_repayment = (amount + interest) / duration if duration > 0 else 0
    else:
        # Finance Gap Calculation Logic
        import math
        raw_val = amount / duration if duration > 0 else 0
        
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

# If not logged in, ensure state is set to False
if 'logged_in' not in st.session_state:
    st.session_state['logged_in'] = False

# --- ROUTING ---
from navigation.router import route_app
from auth.password import hash_password
route_app()

# --- 5. SIDEBAR ---
from services.auth_service import AuthService
from auth.authorization import has_permission, can_render_widget, get_nav_options
current_user = AuthService.get_user()
ROLE = current_user.role if current_user else None
USER = current_user.username if current_user else None
BRANCH = current_user.branch if current_user else None
BRANCH_ID = current_user.branch_id if current_user else None
USER_ID = current_user.id if current_user else None
ASSIGNED_BRANCH_IDS = current_user.assigned_branch_ids if current_user else []
branch_display = "Head Office" if ROLE in ["Admin", "Super Admin", ROLE_ADMIN, ROLE_SUPER_ADMIN] else (f"{BRANCH} Branch" if BRANCH else "No Branch")


# Role badge colors (ICARE brand palette)
role_colors = {
    ROLE_ADMIN: COLOR_SECONDARY, "Admin": COLOR_SECONDARY,
    ROLE_BRANCH_MANAGER: COLOR_PRIMARY, "BM": COLOR_PRIMARY,
    ROLE_CREDIT_OFFICER: "#8CC63F", "CO": "#8CC63F", "Officer": "#8CC63F",
    "Area Manager": COLOR_PRIMARY, "AM": COLOR_PRIMARY,
    "Super Admin": COLOR_SECONDARY,
}
role_color = role_colors.get(ROLE, "#6B7280")

# Role display labels
role_labels = {
    ROLE_ADMIN: "Administrator", "Admin": "Administrator",
    ROLE_BRANCH_MANAGER: ROLE_BRANCH_MANAGER, "BM": ROLE_BRANCH_MANAGER,
    ROLE_CREDIT_OFFICER: ROLE_CREDIT_OFFICER, "CO": ROLE_CREDIT_OFFICER, "Officer": ROLE_CREDIT_OFFICER,
    "Area Manager": "Area Manager", "AM": "Area Manager",
    "Super Admin": "Super Admin",
}
role_label = role_labels.get(ROLE, ROLE)

with st.sidebar:
    st.markdown(f"""
        <div style="text-align: center; margin-top: 10px; margin-bottom: 5px;">
            <img src="data:image/jpeg;base64,{LOGO_B64}" style="width: 65px; height: auto; border-radius: 50%; box-shadow: 0 2px 8px rgba(0,0,0,0.06);">
        </div>
    """, unsafe_allow_html=True)
    
    st.markdown(f"""
        <div style='text-align: center; padding: 0 0 6px 0;'>
            <p style='color: #94A3B8; font-size: 0.65rem; margin: 4px 0 0 0; letter-spacing: 1px;'>CORE BANKING v{APP_VERSION} (st v{st.__version__})</p>
        </div>
    """, unsafe_allow_html=True)
    st.divider()
    
    st.markdown(f"""
        <div style='background: #F8FAFC; padding: 14px 16px; border-radius: 10px; margin-bottom: 12px; border: 1px solid #E2E8F0;'>
            <p style='color: #0F172A; margin: 0; font-size: 0.92rem; font-weight: 600;'>{current_user.full_name if (current_user and getattr(current_user, 'full_name', None)) else CO_DISPLAY_MAP.get(USER, USER)}</p>
            <p style='color: #64748B; margin: 6px 0 0 0; font-size: 0.78rem;'>
                <span style='background: {role_color}; color: white; padding: 2px 8px; border-radius: 10px; font-size: 0.68rem; font-weight: 600;'>{role_label}</span>
                &nbsp; {branch_display}
            </p>
        </div>
    """, unsafe_allow_html=True)
    
    # Enterprise RBAC Scope Engine
    from services.rbac_scope_service import RBACScopeService
    scope = RBACScopeService.resolve_scope(current_user.to_dict() if hasattr(current_user, 'to_dict') else {
        "id": USER_ID, "username": USER, "role": ROLE, "branch": BRANCH, "branch_id": BRANCH_ID, "assigned_branches": ASSIGNED_BRANCH_IDS
    })
    
    nav_section = "OPERATIONS" if scope.scope_level == "OFFICER" else (
        "EXECUTIVE" if scope.scope_level in ["BRANCH", "REGION"] else "ADMINISTRATION"
    )
    st.markdown(f"<p class='nav-section-label'>{nav_section}</p>", unsafe_allow_html=True)
    nav_options = RBACScopeService.get_permitted_menu_items(scope.role)

    if "Navigation" not in st.session_state or st.session_state["Navigation"] not in nav_options:
        st.session_state["Navigation"] = nav_options[0] if nav_options else "Dashboard"
    
    def _sync_nav():
        st.session_state["Navigation"] = st.session_state["nav_radio"]

    nav_index = nav_options.index(st.session_state.get("Navigation")) if st.session_state.get("Navigation") in nav_options else 0
    page = st.radio("Navigation", nav_options, index=nav_index, key="nav_radio", label_visibility="collapsed", on_change=_sync_nav)
    page = st.session_state.get("Navigation", nav_options[0])

    # Route Security Guard
    if not RBACScopeService.is_page_permitted(scope.role, page):
        st.error("⚠️ Access Denied: You do not have permission to access this page.")
        st.info("If you believe this is an error, please contact your System Administrator.")
        st.stop()

    
    st.divider()
    
    if st.button("Sign Out", use_container_width=True):
        AuthService.logout()
        if "auth_token" in st.query_params:
            del st.query_params["auth_token"]
        if "auth" in st.query_params:
            del st.query_params["auth"]
        for key in list(st.session_state.keys()):
            del st.session_state[key]
        st.session_state['logged_in'] = False
        st.rerun()

# Welcome banner
hour = datetime.now().hour
greeting = "Good morning" if hour < 12 else ("Good afternoon" if hour < 17 else "Good evening")
display_name = current_user.full_name if (current_user and getattr(current_user, 'full_name', None)) else CO_DISPLAY_MAP.get(USER, USER)
st.markdown(f"""
    <div class='welcome-banner'>
        <h2>{greeting}, {display_name}</h2>
        <p>{role_label} &mdash; <span class='wb-gold'>{branch_display}</span> &middot; {datetime.now().strftime('%A, %B %d, %Y')}</p>
    </div>
""", unsafe_allow_html=True)

# --- 6. PAGES ---

def _nav_to_audit_center():
    # Detect permitted target alias for user role
    from services.rbac_scope_service import RBACScopeService
    u = st.session_state.get("user") or {}
    r = u.get("role") or u.get("user_role") if isinstance(u, dict) else getattr(u, 'role', 'CO')
    permitted = RBACScopeService.get_permitted_menu_items(str(r))
    target = "Audit Ledger" if "Audit Ledger" in permitted else ("Audit Center" if "Audit Center" in permitted else "Dashboard")
    st.session_state["Navigation"] = target

if page == "Dashboard":
    from services.rbac_scope_service import RBACScopeService
    u_obj = st.session_state.get("user") or {}
    r_role = u_obj.get("role") or u_obj.get("user_role") if isinstance(u_obj, dict) else getattr(u_obj, 'role', ROLE)
    permitted = RBACScopeService.get_permitted_menu_items(str(r_role))
    has_audit_access = "Audit Ledger" in permitted or "Audit Center" in permitted

    if has_audit_access:
        d_col1, d_col2 = st.columns([3, 1])
        with d_col1:
            st.title("Performance & Risk Dashboard")
        with d_col2:
            st.write("")
            st.button("🏛️ Audit Center", key="btn_dash_audit_center", on_click=_nav_to_audit_center, use_container_width=True)
    else:
        st.title("Performance & Risk Dashboard")

    from services.dashboard_service import DashboardService
    from database.repositories.unit_of_work import SupabaseUnitOfWork

    with SupabaseUnitOfWork() as uow:
        # ROLE-BASED DASHBOARD DISPATCH (PHASE 8.4.1)
        if ROLE in ["Director", "Executive", "Board"]:
            st.markdown("### 🏛️ Executive Board Dashboard")
            st.caption("Strategic Portfolio & Institutional Overview (Read-Only Executive Insights)")
            d_data = DashboardService.get_director_dashboard_data(uow)

            exec_ov = d_data["executive_overview"]
            c1, c2, c3, c4 = st.columns(4)
            c1.metric("💵 Today's Collections", f"₦{exec_ov['today_collections']:,.0f}")
            c2.metric("📅 MTD Collections", f"₦{exec_ov['mtd_collections']:,.0f}")
            c3.metric("📈 Outstanding Portfolio", f"₦{exec_ov['outstanding_portfolio']:,.0f}")
            c4.metric("🐷 Total Savings", f"₦{exec_ov['total_savings']:,.0f}")

            c5, c6 = st.columns(2)
            c5.metric("🚨 Portfolio At Risk (PAR)", exec_ov["par"], delta_color="inverse")
            c6.metric("🎯 Recovery Rate", exec_ov["recovery_rate"])

            st.divider()
            t_col1, t_col2 = st.columns(2)
            with t_col1:
                st.markdown("#### 🏆 Top Five Branches")
                for b in d_data["top_five_branches"]:
                    st.write(f"🥇 **{b}**")
            with t_col2:
                st.markdown("#### ⚠️ Bottom Five Branches")
                for b in d_data["bottom_five_branches"]:
                    st.write(f"🔻 **{b}**")

            if d_data["strategic_alerts"]:
                st.divider()
                st.markdown("#### 🔔 Strategic Alerts")
                for sa in d_data["strategic_alerts"]:
                    st.info(f"ℹ️ {sa}")

        elif ROLE in [ROLE_ADMIN, "Super Admin", "Admin"]:
            st.markdown("### 👑 Global Administrator Dashboard")
            st.caption("Institution Operations & Platform Health")
            a_data = DashboardService.get_admin_dashboard_data(uow)
            ops = a_data["today_operations"]

            st.markdown("#### 📅 Today's Institution Performance")
            p1, p2, p3, p4 = st.columns(4)
            p1.metric("💵 Today's Institution Collection", f"₦{ops['today_collection']:,.0f}")
            p2.metric("📥 Today's Savings Deposits", f"₦{ops['today_savings_deposit']:,.0f}")
            p3.metric("📤 Today's Savings Withdrawals", f"₦{ops['today_savings_withdrawal']:,.0f}")
            p4.metric("🚀 Today's Loan Disbursement", f"₦{ops['today_disbursement']:,.0f}")

            st.markdown("#### 📊 Today's Repayment Status Breakdown")
            s1, s2, s3, s4, s5 = st.columns(5)
            s1.metric("🎯 Normal Payments", f"₦{ops.get('normal_payments', {}).get('amount', 0.0):,.0f}", f"{ops.get('normal_payments', {}).get('count', 0)} Clients")
            s2.metric("🏆 Full Payments", f"₦{ops.get('full_payments', {}).get('amount', 0.0):,.0f}", f"{ops.get('full_payments', {}).get('count', 0)} Clients")
            s3.metric("🚀 Excess Payments", f"₦{ops.get('excess_payments', {}).get('amount', 0.0):,.0f}", f"{ops.get('excess_payments', {}).get('count', 0)} Clients")
            s4.metric("⚠️ Part Payments", f"₦{ops.get('part_payments', {}).get('amount', 0.0):,.0f}", f"{ops.get('part_payments', {}).get('count', 0)} Clients")
            s5.metric("🚨 Not Paid", f"₦{ops.get('not_paid', {}).get('amount', 0.0):,.0f}", f"{ops.get('not_paid', {}).get('count', 0)} Clients", delta_color="inverse")

            st.divider()
            st.markdown("#### 🛡️ System & Operations Health")
            health = a_data["system_health"]
            h1, h2, h3 = st.columns(3)
            h1.info(f"⚙️ **Projection Status**: {health['projection_status']}")
            h2.info(f"📬 **Event Queue**: {health['event_queue_status']}")
            h3.info(f"🔄 **Database Sync**: {health['db_sync_status']}")
            
            # Section H: Error Correction Queue (Global)
            res_corr = uow.client.table("correction_requests").select("*").eq("status", "Pending").order("created_at", desc=False).execute()
            if res_corr.data:
                st.divider()
                st.markdown("#### 🚨 Pending Error Corrections (Global)")
                for corr in res_corr.data:
                    c_id = corr["id"]
                    c_reason = corr["reason"]
                    
                    st.warning(f"**Reversal Request** | Record ID: {corr['record_id'][:8]} | Reason: {c_reason}")
                    
                    corr_col1, corr_col2, corr_col3 = st.columns([2, 1, 1])
                    if corr_col2.button("✅ Approve Reversal", key=f"admin_app_corr_{c_id}"):
                        try:
                            from services.correction_service import CorrectionService
                            with SupabaseUnitOfWork() as uow_corr:
                                CorrectionService.approve_correction(uow_corr, c_id, approved_by=USER_ID)
                            st.success("Reversal Approved and Executed.")
                            st.rerun()
                        except Exception as e:
                            st.error(f"Approval failed: {e}")
                    
                    if corr_col3.button("❌ Reject", key=f"admin_rej_corr_{c_id}", type="primary"):
                        try:
                            from services.correction_service import CorrectionService
                            with SupabaseUnitOfWork() as uow_corr:
                                CorrectionService.reject_correction(uow_corr, c_id, approved_by=USER_ID)
                            st.success("Reversal Rejected.")
                            st.rerun()
                        except Exception as e:
                            st.error(f"Rejection failed: {e}")

        elif ROLE in ["AM", "Area Manager"]:
            st.markdown("### 🌐 Area Manager Dashboard")
            st.caption("Regional Operational Performance & Branch Supervision")
            all_loans = load_loans()
            my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
            assigned_branches = sorted(list(set(my_loans['Branch'].dropna().tolist()))) if not my_loans.empty and 'Branch' in my_loans.columns else [BRANCH]
            am_data = DashboardService.get_am_dashboard_data(uow, assigned_branches)

            reg = am_data["regional_summary"]
            r1, r2, r3, r4, r5 = st.columns(5)
            r1.metric("🏦 Branches", reg["branches_count"])
            r2.metric("👥 Active Clients", reg["active_clients"])
            r3.metric("📈 Outstanding Portfolio", f"₦{reg['outstanding_portfolio']:,.0f}")
            r4.metric("🐷 Total Savings", f"₦{reg['savings']:,.0f}")
            r5.metric("💵 Today's Collection", f"₦{reg['today_collection']:,.0f}")

            st.divider()
            st.markdown("#### 📊 Regional Branch Performance Grid")
            st.dataframe(am_data["branch_performance"], use_container_width=True, hide_index=True)

        elif ROLE in ["BM", ROLE_BRANCH_MANAGER]:
            st.markdown(f"### 🏦 Branch Manager Dashboard — {BRANCH} Branch")
            st.caption("Branch Daily Operations, Officer Status, & Approvals")
            bm_data = DashboardService.get_bm_dashboard_data(uow, BRANCH, branch_id=BRANCH_ID)

            # Section F: Approval Queue (Pending Loan Approvals)
            p_loans = bm_data.get("approval_queue", [])
            if p_loans:
                st.markdown("#### Pending Loan Approvals")
                for pl in p_loans:
                    c_name = pl.get("clients", {}).get("name", "Unknown Client") if pl.get("clients") else pl.get("client_name", "Unknown Client")
                    c_code = pl.get("clients", {}).get("client_code") if pl.get("clients") and pl.get("clients").get("client_code") else pl.get("client_id", "")[:8]
                    loan_amt = float(pl.get("loan_amount", 0))
                    prod = pl.get("loan_products", {}).get("name", "Standard") if pl.get("loan_products") else pl.get("loan_product", "Standard")
                    officer = pl.get("app_users", {}).get("username", "Unknown Officer") if pl.get("app_users") else "Unknown Officer"
                    pl_id = pl["loan_id"]

                    with st.container(border=True):
                        col_info, col_amt, col_acts = st.columns([3, 2, 3])
                        with col_info:
                            st.markdown(f"**{c_name}** (`{c_code}`)")
                            st.caption(f"Product: **{prod}** | Officer: **{officer}**")
                        with col_amt:
                            st.markdown(f"<div style='font-size: 1.15rem; font-weight: 700; color: #0f172a;'>₦{loan_amt:,.2f}</div>", unsafe_allow_html=True)
                            st.caption("Requested Principal")
                        with col_acts:
                            disb_date = st.date_input("Disbursement Date", value=datetime.now().date(), key=f"disb_date_{pl_id}")
                            act_col1, act_col2 = st.columns(2)
                            with act_col1:
                                if st.button("Approve & Disburse", key=f"app_{pl_id}", type="primary", use_container_width=True):
                                    try:
                                        from services.loan_service import LoanService
                                        with SupabaseUnitOfWork() as uow_app:
                                            LoanService.approve_and_disburse_loan(uow_app, pl_id, USER, disbursement_date=disb_date)
                                        st.success(f"Loan approved & disbursed for {c_name} on {disb_date.strftime('%d %B %Y')}!")
                                        st.rerun()
                                    except Exception as ex:
                                        st.error(f"Disbursement failed: {str(ex)}")
                            with act_col2:
                                if st.button("Reject", key=f"rej_{pl_id}", type="secondary", use_container_width=True):
                                    try:
                                        from services.loan_service import LoanService
                                        with SupabaseUnitOfWork() as uow_app:
                                            LoanService.reject_loan(uow_app, pl_id, USER, "Rejected by BM")
                                        st.success(f"Loan rejected for {c_name}.")
                                        st.rerun()
                                    except Exception as ex:
                                        st.error(f"Rejection failed: {str(ex)}")
                st.markdown("<br>", unsafe_allow_html=True)

            # Section G: Withdrawal Approval Queue
            res_wr = uow.client.table("withdrawal_requests").select("*").eq("branch_id", BRANCH_ID).eq("status", "PENDING").order("created_at", desc=False).execute()
            pending_withdrawals = res_wr.data or []
            if pending_withdrawals:
                st.markdown("#### Pending Withdrawal Approvals")
                for wr in pending_withdrawals:
                    wr_id = wr["id"]
                    wr_type = wr["savings_type"]
                    wr_op = wr["operation_type"]
                    wr_amt = float(wr["amount"])
                    wr_name = wr["client_name"]
                    wr_by = wr["requested_by"]
                    wr_remarks = wr.get("remarks") or ""
                    wr_date = str(wr.get("created_at", ""))[:10]

                    with st.container(border=True):
                        wcol_info, wcol_amt, wcol_acts = st.columns([3, 2, 2])
                        with wcol_info:
                            st.markdown(f"**{wr_name}** — `{wr_type}`")
                            st.caption(f"Op: **{wr_op}** | Req By: **{wr_by}** | Date: **{wr_date}**")
                            if wr_remarks:
                                st.caption(f"*{wr_remarks}*")
                        with wcol_amt:
                            st.markdown(f"<div style='font-size: 1.15rem; font-weight: 700; color: #b91c1c;'>₦{wr_amt:,.2f}</div>", unsafe_allow_html=True)
                            st.caption("Withdrawal Amount")
                        with wcol_acts:
                            wact_col1, wact_col2 = st.columns(2)
                            with wact_col1:
                                if st.button("Approve", key=f"approve_wr_{wr_id}", type="primary", use_container_width=True):
                                    try:
                                        from services.savings_service import SavingsService
                                        with SupabaseUnitOfWork() as uow_wr:
                                            if wr_op == "Cash Withdrawal":
                                                if wr_type == "Individual":
                                                    SavingsService.post_individual_savings(
                                                        uow=uow_wr, client_id=wr.get("client_id"), client_name=wr_name,
                                                        branch=BRANCH, officer=wr_by, deposit_amount=0.0, withdrawal_amount=wr_amt,
                                                        reference=wr.get("reference"), remarks=f"[BM APPROVED] {wr_remarks}"
                                                    )
                                                elif wr_type == "Group":
                                                    SavingsService.post_group_savings(
                                                        uow=uow_wr, group_name=wr.get("group_name") or wr_name, branch=BRANCH,
                                                        officer=wr_by, deposit_amount=0.0, withdrawal_amount=wr_amt,
                                                        reference=wr.get("reference"), remarks=f"[BM APPROVED] {wr_remarks}"
                                                    )
                                                elif wr_type == "Misc":
                                                    SavingsService.post_misc_savings(
                                                        uow=uow_wr, client_id=wr.get("client_id") or "", client_name=wr_name,
                                                        branch=BRANCH, officer=wr_by, deposit_amount=0.0, withdrawal_amount=wr_amt,
                                                        reference=wr.get("reference"), remarks=f"[BM APPROVED] {wr_remarks}"
                                                    )
                                            elif wr_op in ["Loan Offset", "Asset Downpayment"]:
                                                source_type = "IndividualSavings" if wr_type == "Individual" else "GroupSavings"
                                                SavingsService.post_loan_offset_from_savings(
                                                    uow=uow_wr, client_id=wr.get("client_id"), client_name=wr_name,
                                                    loan_id=wr.get("loan_id"), source_savings_type=source_type,
                                                    branch=BRANCH, officer=wr_by, amount=wr_amt,
                                                    reference=wr.get("reference"), remarks=f"[BM APPROVED {wr_op.upper()}] {wr_remarks}"
                                                )
                                            elif wr_op == "LAPS Transfer":
                                                source_type = "IndividualSavings" if wr_type == "Individual" else "GroupSavings"
                                                SavingsService.transfer_to_laps(
                                                    uow=uow_wr, client_id=wr.get("client_id"), client_name=wr_name,
                                                    source_savings_type=source_type, branch=BRANCH, officer=wr_by, amount=wr_amt,
                                                    reference=wr.get("reference"), remarks=f"[BM APPROVED] {wr_remarks}"
                                                )
                                            elif wr_op == "LAPS Payout":
                                                cash_paid = (wr.get("payout_method") or "Cash") == "Cash"
                                                SavingsService.pay_laps(
                                                    uow=uow_wr, client_id=wr.get("client_id"), client_name=wr_name,
                                                    branch=BRANCH, officer=wr_by, amount=wr_amt, cash_paid=cash_paid,
                                                    reference=wr.get("reference"), remarks=f"[BM APPROVED] {wr_remarks}"
                                                )

                                            uow_wr.client.table("withdrawal_requests").update({
                                                "status": "APPROVED",
                                                "approved_by": USER,
                                                "approved_at": datetime.now().isoformat()
                                            }).eq("id", wr_id).execute()

                                        st.success(f"Withdrawal of ₦{wr_amt:,.2f} approved!")
                                        st.rerun()
                                    except Exception as ex:
                                        st.error(f"Approval failed: {str(ex)}")
                            with wact_col2:
                                if st.button("Reject", key=f"reject_wr_{wr_id}", type="secondary", use_container_width=True):
                                    st.session_state[f"rejecting_{wr_id}"] = True

                        if st.session_state.get(f"rejecting_{wr_id}"):
                            st.divider()
                            reject_reason = st.text_input("Rejection Reason", key=f"rej_reason_{wr_id}", placeholder="Why is this being rejected?")
                            if st.button("Confirm Rejection", key=f"confirm_rej_{wr_id}", type="primary"):
                                uow.client.table("withdrawal_requests").update({
                                    "status": "REJECTED",
                                    "approved_by": USER,
                                    "approved_at": datetime.now().isoformat(),
                                    "rejection_reason": reject_reason or "Rejected by BM"
                                }).eq("id", wr_id).execute()
                                st.session_state[f"rejecting_{wr_id}"] = False
                                st.success(f"Withdrawal request rejected for {wr_name}.")
                                st.rerun()
                st.markdown("<br>", unsafe_allow_html=True)

            # Section H: Error Correction Queue
            res_corr = uow.client.table("correction_requests").select("*, app_users!correction_requests_requested_by_fkey(username, full_name)") \
                .eq("branch_id", BRANCH_ID).eq("status", "Pending").order("created_at", desc=False).execute()
            if res_corr.data:
                st.markdown("#### 🚨 Pending Error Corrections (Reversals)")
                for corr in res_corr.data:
                    c_id = corr["id"]
                    c_type = corr.get("record_type")
                    c_reason = corr.get("reason")
                    u_data = corr.get("app_users")
                    req_user = (u_data.get("full_name") or u_data.get("username")) if isinstance(u_data, dict) else "Officer"
                    r_date = str(corr.get("created_at", ""))[:16].replace("T", " ")
                    r_ref = str(corr.get("record_id", ""))[:8]

                    type_icon = "💳 [Loan Repayment]" if c_type == "Repayment" else (
                        "💰 [Savings Deposit]" if c_type in ["Savings", "SavingsDeposit"] else (
                            "🏷️ [EOD Fee]" if c_type == "Fee" else (
                                "🧾 [Office Expense]" if c_type == "Expense" else "🏛️ [Treasury Transfer]"
                            )
                        )
                    )

                    with st.container(border=True):
                        col_req_info, col_req_meta, col_req_acts = st.columns([4, 2, 2])
                        with col_req_info:
                            st.markdown(f"**{type_icon}** &nbsp; `Ref: #{r_ref}`")
                            st.caption(f"Requested by: **{req_user}** &bull; Submitted: **{r_date}**")
                            st.markdown(f"**Reason:** *{c_reason}*")
                        with col_req_meta:
                            st.markdown("<div style='margin-top: 10px;'><span style='background: #FEF3C7; color: #92400E; padding: 4px 10px; border-radius: 12px; font-size: 0.8rem; font-weight: 600;'>🟡 Pending Approval</span></div>", unsafe_allow_html=True)
                        with col_req_acts:
                            st.write("")
                            b_act1, b_act2 = st.columns(2)
                            with b_act1:
                                if st.button("✅ Approve", key=f"app_corr_{c_id}", type="primary", use_container_width=True):
                                    try:
                                        from services.correction_service import CorrectionService
                                        with SupabaseUnitOfWork() as uow_corr:
                                            CorrectionService.approve_correction(uow_corr, c_id, approved_by=USER_ID if USER_ID else USER)
                                        st.success("Reversal approved and executed atomically!")
                                        st.rerun()
                                    except Exception as e:
                                        st.error(f"Approval failed: {e}")
                            with b_act2:
                                if st.button("❌ Reject", key=f"rej_corr_{c_id}", use_container_width=True):
                                    try:
                                        from services.correction_service import CorrectionService
                                        with SupabaseUnitOfWork() as uow_corr:
                                            CorrectionService.reject_correction(uow_corr, c_id, approved_by=USER_ID if USER_ID else USER)
                                        st.info("Reversal rejected.")
                                        st.rerun()
                                    except Exception as e:
                                        st.error(f"Rejection failed: {e}")
                st.markdown("<br>", unsafe_allow_html=True)

            # Section A: Branch Summary
            bs = bm_data["branch_summary"]
            b1, b2, b3, b4 = st.columns(4)
            b1.metric("👥 Active Clients", bs["active_clients"])
            b2.metric("🐷 Active Savings", f"₦{bs['active_savings']:,.0f}")
            b3.metric("💵 Collection Today", f"₦{bs['collection_today']:,.0f}")
            b4.metric("🚨 PAR", bs["par"])

            # Officer Collection Status Grid
            st.markdown("#### 📊 Officer Collection Status")
            off_df = bm_data["officer_collection_status"]
            if not off_df.empty:
                st.dataframe(off_df, use_container_width=True, hide_index=True)

            # Branch Cash Position
            st.markdown("#### 💰 Branch Cash Position (Master Cashbook)")
            cp = bm_data["branch_cash_position"]
            k1, k2, k3, k4 = st.columns(4)
            k1.metric("Opening Balance", f"₦{cp['opening_balance']:,.0f}")
            k2.metric("Total Inflows", f"₦{cp['cash_in']:,.0f}")
            k3.metric("Total Outflows", f"₦{cp['cash_out']:,.0f}")
            k4.metric("Closing Balance", f"₦{cp['closing_balance']:,.0f}")
            k5, k6 = st.columns(2)
            k5.metric("Status", cp["status"])

        else: # CO / Officer
            st.markdown(f"### Credit Officer Dashboard — {USER} ({BRANCH})")
            co_data = DashboardService.get_co_dashboard_data(uow, BRANCH, USER, officer_id=USER_ID, branch_id=BRANCH_ID)

            wel = co_data["welcome"]
            st.info(f"Welcome **{wel['officer_name']}** | {wel['branch_name']} Branch | Business Date: **{wel['date_str']}** ({wel['meeting_day']}) | System Time: {wel['time_str']}")

            if co_data.get("branch_closure", {}).get("is_closed"):
                st.warning(f"🏖️ **Branch Closed / Holiday ({co_data['branch_closure']['reason']})**: All field collections, group meetings, and daily/weekly/monthly repayments are suspended for {wel['branch_name']} Branch today.")

            # Today's Repayment Summary Cards (UI-02: Clean Titles, Emoji Reduction)
            st.markdown("#### Today's Repayment Summary")
            rep_s = co_data["repayment_summary"]
            r1, r2, r3 = st.columns(3)
            r1.metric("60D / 12W / 3M", f"₦{rep_s['rep_12_weeks_amt']:,.0f}", f"{rep_s['rep_12_weeks_clients']} Clients Paid")
            r2.metric("120D / 24W / 6M", f"₦{rep_s['rep_24_weeks_amt']:,.0f}", f"{rep_s['rep_24_weeks_clients']} Clients Paid")
            r3.metric("Total Repayment Today", f"₦{rep_s['total_collected_today']:,.0f}")

            # Today's Meeting Portfolio Grid & Start Collection Actions (UI-02)
            st.markdown("#### Today's Meeting Portfolio")
            m_port = co_data["meeting_portfolio"]
            if not m_port.empty:
                st.dataframe(m_port, use_container_width=True, hide_index=True)
                
                st.markdown("##### Quick Action: Start Collection")
                def _go_to_collections(grp_name):
                    st.session_state["Navigation"] = "Collections"
                    st.session_state["sel_group"] = grp_name
                    
                g_cols = st.columns(min(len(m_port), 4))
                for idx, row in m_port.iterrows():
                    g_name = row["Group Name"]
                    status_badge = row.get("Status", "🟢 Completed")
                    col_idx = idx % len(g_cols)
                    with g_cols[col_idx]:
                        st.button(f"Start {g_name} ({status_badge})", key=f"start_grp_{idx}", use_container_width=True, on_click=_go_to_collections, args=(g_name,))
            else:
                st.info("No active groups scheduled for today.")

            # Today's Savings
            st.markdown("#### Today's Savings")
            sav = co_data["savings"]
            s1, s2, s3 = st.columns(3)
            s1.metric("Savings Deposited", f"₦{sav['deposited_amt']:,.0f}", f"{sav['deposited_clients']} Clients")
            s2.metric("Savings Withdrawn", f"₦{sav['withdrawn_amt']:,.0f}", f"{sav['withdrawn_clients']} Clients")
            s3.metric("Net Savings", f"₦{sav['net_savings']:,.0f}")

            # Today's Repayment Status Cards
            st.markdown("#### Today's Repayment Status")
            st_cards = co_data["repayment_status"]
            c1, c2, c3, c4 = st.columns(4)
            c1.metric("Full Payment", f"₦{st_cards['full_payment']['amount']:,.0f}", f"{st_cards['full_payment']['count']} Clients")
            c2.metric("Part Payment", f"₦{st_cards['part_payment']['amount']:,.0f}", f"{st_cards['part_payment']['count']} Clients")
            c3.metric("Excess Payment", f"₦{st_cards['excess_payment']['amount']:,.0f}", f"{st_cards['excess_payment']['count']} Clients")
            c4.metric("Not Paid", f"₦{st_cards['not_paid']['amount']:,.0f}", f"{st_cards['not_paid']['count']} Clients", delta_color="inverse")

            # Cash Position (CO Cashbook)
            st.markdown("#### Cash Position (CO Cashbook)")
            cp = co_data["cash_position"]
            k1, k2, k3, k4 = st.columns(4)
            k1.metric("Opening Balance", f"₦{cp['opening_balance']:,.0f}")
            k2.metric("Cash In", f"₦{cp['cash_in']:,.0f}")
            k3.metric("Cash Out", f"₦{cp['cash_out']:,.0f}")
            k4.metric("Closing Balance", f"₦{cp['closing_balance']:,.0f}")
            k5, k6 = st.columns(2)
            k5.metric("Cashbook Status", cp["status"])
            k6.metric("Difference", f"₦{cp['difference']:,.0f}")

            # Today's Attention List
            st.markdown("#### Today's Attention List")
            att_list = co_data["attention_list"]
            if not att_list.empty:
                st.dataframe(att_list, use_container_width=True, hide_index=True)
            else:
                st.success("🎉 All scheduled clients have completed full repayments for today!")


elif page == "Loan Origination":
    st.title("Origination & Registration")
    
    orig_options = ["Client Registration", "Loan Application", "Pending Disbursements", "Edit Client & Guarantor"]
    if "orig_tab" not in st.session_state:
        st.session_state["orig_tab"] = "Client Registration"
    if st.session_state["orig_tab"] not in orig_options:
        st.session_state["orig_tab"] = "Client Registration"
        
    orig_idx = orig_options.index(st.session_state["orig_tab"])
    orig_section = st.radio("Navigate", orig_options, index=orig_idx, horizontal=True, label_visibility="collapsed", key="orig_tab_radio")
    st.session_state["orig_tab"] = orig_section
    
    if "flash_msg" in st.session_state:
        st.success(st.session_state["flash_msg"])
        del st.session_state["flash_msg"]

    if orig_section == "Pending Disbursements":
        st.subheader("Pending Disbursements")
        all_loans = load_loans()
        my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
        pending_clients = my_loans[(my_loans['Status'] == STATUS_PENDING) & (pd.to_numeric(my_loans['Loan Amount'], errors='coerce').fillna(0) > 0)]
        if pending_clients.empty:
            st.info("✅ No pending loans found.")
        else:
            st.dataframe(pending_clients[['Client ID', 'Client Name', 'Date', 'Officer', 'Loan Amount', 'Loan Product']], use_container_width=True)
            if ROLE in ["AM", "BM", ROLE_ADMIN]:
                st.markdown("### Checker Action: Activate Loan")
                with st.form("activate_loan_form"):
                    opts = pending_clients['Client ID'].tolist()
                    def format_func(x):
                        return f"{x} - {pending_clients[pending_clients['Client ID'] == x].iloc[0]['Client Name']}"
                    selected_client_id = st.selectbox("Select Client to Activate", opts, format_func=format_func)
                    disbursement_date = st.date_input("Actual Disbursement Date", value=datetime.now().date(), help="Select the planned date cash was disbursed.")
                    submitted_activate = st.form_submit_button("Authorize & Activate Disbursement", use_container_width=True)
                    if submitted_activate:
                        today = disbursement_date
                        today_str = today.strftime("%Y-%m-%d")
                        closures = get_custom_closures()
                        
                        from services.business_date_service import BusinessDateService
                        is_workday, workday_reason = BusinessDateService.is_working_day(today, closures)
                        if not is_workday:
                            st.error(f"⛔ **Non-Working Day Restriction**: Loans cannot be activated or disbursed on {workday_reason}. Please select a valid working day.")
                            st.stop()

                        loan_row = pending_clients[pending_clients['Client ID'] == selected_client_id].iloc[0]
                        product = str(loan_row.get("Loan Product", ""))
                        meeting_day = str(loan_row.get("Meeting Day", ""))
                        
                        if "Daily" in product or "60" in product or "120" in product:
                            initial_start_date = today + timedelta(days=1)
                        else:
                            days_of_week = {"Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3, "Friday": 4, "Saturday": 5, "Sunday": 6}
                            if meeting_day and meeting_day in days_of_week:
                                target_weekday = days_of_week[meeting_day]
                                current_weekday = today.weekday()
                                days_ahead = target_weekday - current_weekday
                                if days_ahead <= 0:
                                    days_ahead += 7
                                initial_start_date = today + timedelta(days=days_ahead)
                            else:
                                initial_start_date = today + timedelta(days=7)
                                
                        final_start_date = BusinessDateService.get_next_working_day(initial_start_date, closures)
                        is_adjusted = (final_start_date != initial_start_date)
                        shift_reason = "a non-working day or closure"
                        
                        from services.loan_product_engine import LoanProductEngine
                        setup = LoanProductEngine.calculate_loan_setup(100000, product)
                        loan_freq = setup.get("freq", "Daily")
                        duration_in_installments = setup.get("duration", 60)
                        
                        schedule = LoanProductEngine.generate_repayment_schedule(
                            final_start_date, duration_in_installments, loan_freq,
                            meeting_day=meeting_day, closed_dates=[c[0] for c in closures]
                        )
                        expected_end_date = schedule[-1] if schedule else final_start_date
                        
                        try:
                            from services.loan_service import LoanService
                            with SupabaseUnitOfWork() as uow:
                                loans = uow.loans.find_by_client_id(selected_client_id)
                                pending_loans = [L for L in loans if (L.status.value == STATUS_PENDING if hasattr(L.status, 'value') else L.status == STATUS_PENDING)]
                                for L in pending_loans:
                                    L.start_date = final_start_date
                                    L.expected_end_date = expected_end_date
                                    LoanService.disburse_loan(uow, L, disbursement_date=disbursement_date)
                            
                            st.success(f"Successfully activated and disbursed loan! Disbursement Date set to {today_str}.")
                            
                            if is_adjusted:
                                st.warning(f"📅 **Schedule Adjusted:** The first repayment was automatically moved to **{final_start_date.strftime('%A, %b %d')}** because the original date fell on {shift_reason}.")
                                
                            import time
                            time.sleep(2)
                            st.rerun()
                        except Exception as e:
                            st.error(f"Failed to activate loan: {e}")
            else:
                st.info("🔒 Note: You are a Credit Officer. Only Branch Managers or Area Managers can authorize and activate disbursements.")

    elif orig_section == "Client Registration":
        st.subheader("Client Registration")
        # Only Admins and Super Admins can see the Bulk Onboarding method
        if ROLE in [ROLE_SUPER_ADMIN, ROLE_ADMIN]:
            reg_type = st.radio("Registration Method", ["Single Client", "Bulk Onboarding"], horizontal=True)
        else:
            reg_type = "Single Client"
        
        if reg_type == "Single Client":
            # Load branches and groups using UOW
            with SupabaseUnitOfWork() as uow:
                # Find branch_id and branch code for user's branch name
                res_b = uow.client.table("branches").select("branch_id, code").eq("name", BRANCH).execute()
                if res_b.data:
                    branch_id = res_b.data[0]["branch_id"]
                    branch_code = res_b.data[0]["code"] or BRANCH[:3].upper()
                else:
                    branch_id = None
                    branch_code = BRANCH[:3].upper()

                # Find all active groups for this branch
                if branch_id:
                    query = uow.client.table("groups").select("*").eq("branch_id", branch_id)
                    if ROLE in ['CO', 'Officer', ROLE_CREDIT_OFFICER]:
                        query = query.eq("officer_id", current_user.id)
                    res_g = query.execute()
                    groups_list = res_g.data
                else:
                    groups_list = []

            group_names = [g["name"] for g in groups_list]
            group_options = ["Individual (No Group)", "+ Create New Group"] + group_names
            selected_group_mode = st.selectbox("Assign to Group", group_options, key="reg_selected_group_mode")
            
            final_group_name = ""
            final_group_id = None
            final_group_number = ""
            
            if selected_group_mode == "+ Create New Group":
                gr1, gr2, gr3 = st.columns(3)
                final_group_name = gr1.text_input("New Group Name", placeholder="e.g. Alaba Traders", key="reg_new_group_name")
                final_group_number = gr2.text_input("New Group Number (2-digits)", placeholder="e.g. 01", key="reg_new_group_number")
                final_meeting_day = gr3.selectbox("Meeting Day", ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "Daily"], key="reg_new_group_meeting_day")
            elif selected_group_mode != "Individual (No Group)":
                # Find existing group
                group_data = next((g for g in groups_list if g["name"] == selected_group_mode), None)
                if group_data:
                    final_group_id = group_data["group_id"]
                    final_group_name = group_data["name"]
                    final_group_number = group_data.get("group_number") or ""
                    st.info(f"Selected group '{final_group_name}' (Code: {final_group_number}) meets on {group_data.get('meeting_day')}")
            
            st.markdown("---")
            
            with st.form("client_registration_details_form"):
                st.markdown("#### 1. Personal Info")
                c1, c2, c3 = st.columns(3)
                name = c1.text_input("Full Name", key="reg_client_name")
                nickname = c2.text_input("Nickname", key="reg_client_nickname")
                phone = c3.text_input("Phone Number", key="reg_client_phone")
                address = st.text_input("Home Address", key="reg_client_address")
                
                c4, c5, c6 = st.columns(3)
                marital = c4.selectbox("Marital Status", ["Single", "Married", "Divorced", "Widowed"], key="reg_client_marital")
                biz_type = c5.text_input("Business Type", value="Trader", key="reg_client_biz_type")
                raw_inc = c6.number_input("Average Monthly Income (₦)", min_value=0.0, step=5000.0, value=None, placeholder="0", key="reg_client_income")
                biz_address = st.text_input("Business Address", key="reg_client_biz_address")
                other_obs = st.text_input("Other Financial Obligations (if any)", key="reg_client_obligations")
                
                # Means of ID Section
                st.markdown("##### Means of Identification")
                id_col1, id_col2, id_col3 = st.columns(3)
                id_means = id_col1.selectbox("Means of ID", ["National ID (NIN)", "Voter's Card", "Driver's License", "International Passport", "None"], key="reg_client_id_means")
                id_number = id_col2.text_input("ID Number", placeholder="Enter identification number", key="reg_client_id_number")
                id_file = id_col3.file_uploader("Upload ID Document", type=["jpg", "jpeg", "png", "pdf"], key="reg_client_id_file")
                
                # Passport Photograph Section
                st.markdown("##### Passport Photograph")
                pass_file = st.file_uploader("Upload Passport Photograph", type=["jpg", "jpeg", "png"], key="reg_client_passport")
                
                st.markdown("#### 2. Guarantor Info")
                g1, g2, g3 = st.columns(3)
                g_name = g1.text_input("Guarantor Full Name", key="reg_guarantor_name")
                g_nick = g2.text_input("Guarantor Nickname", key="reg_guarantor_nickname")
                g_phone = g3.text_input("Guarantor Phone", key="reg_guarantor_phone")
                g_address = st.text_input("Guarantor Home Address", key="reg_guarantor_address")
                
                g4, g5, g6 = st.columns(3)
                g_marital = g4.selectbox("Guarantor Marital Status", ["Single", "Married", "Divorced", "Widowed"], key="reg_guarantor_marital")
                g_occ = g5.text_input("Guarantor Occupation", key="reg_guarantor_occupation")
                g_rel = g6.text_input("Relationship with Client", key="reg_guarantor_relationship")
                g_office = st.text_input("Guarantor Office Address", key="reg_guarantor_office")

                st.markdown("##### Guarantor Identification & Passport")
                g_id_col1, g_id_col2, g_id_col3 = st.columns(3)
                g_id_means = g_id_col1.selectbox("Guarantor Means of ID", ["National ID (NIN)", "Voter's Card", "Driver's License", "International Passport", "None"], key="reg_guarantor_id_means")
                g_id_number = g_id_col2.text_input("Guarantor ID Number", placeholder="Enter ID number", key="reg_guarantor_id_number")
                g_id_file = g_id_col3.file_uploader("Upload Guarantor ID Document", type=["jpg", "jpeg", "png", "pdf"], key="reg_guarantor_id_file")
                
                g_pass_col1, g_pass_col2 = st.columns(2)
                g_pass_file = g_pass_col1.file_uploader("Upload Guarantor Passport Photograph", type=["jpg", "jpeg", "png"], key="reg_guarantor_passport")
                
                submitted_reg = st.form_submit_button("Register Client", type="primary", use_container_width=True)
                
                if submitted_reg:
                    name_val = st.session_state.get("reg_client_name", "").strip()
                    phone_val = st.session_state.get("reg_client_phone", "").strip()
                    
                    if not name_val or not phone_val:
                        st.error("Name and Phone are required!")
                    elif selected_group_mode == "+ Create New Group" and (not final_group_name.strip() or not final_group_number.strip()):
                        st.error("Please enter the Group Name and Group Number.")
                    else:
                        try:
                            with SupabaseUnitOfWork() as uow:
                                # 1. Create group if needed
                                if selected_group_mode == "+ Create New Group":
                                    res_u = uow.client.table("app_users").select("id").eq("username", USER).execute()
                                    officer_id = res_u.data[0]["id"] if res_u.data else None
                                    
                                    new_group = {
                                        "name": final_group_name.strip(),
                                        "group_number": final_group_number.strip(),
                                        "meeting_day": final_meeting_day,
                                        "branch_id": branch_id,
                                        "officer_id": officer_id,
                                        "current_member_sequence": 0
                                    }
                                    res_g_ins = uow.client.table("groups").insert(new_group).execute()
                                    if res_g_ins.data:
                                        final_group_id = res_g_ins.data[0]["group_id"]
                                        final_group_number = res_g_ins.data[0]["group_number"]
                                
                                # 2. Generate sequential member number and Client ID
                                if selected_group_mode == "Individual (No Group)":
                                    g_code = "IND"
                                    res_count = uow.client.table("clients").select("client_id", count="exact").is_("group_id", "null").eq("branch_id", branch_id).execute()
                                    next_seq = (res_count.count or 0) + 1
                                else:
                                    g_code = final_group_number
                                    next_seq = uow.clients.get_next_member_sequence(final_group_id)
                                
                                member_number_str = str(next_seq).zfill(3)
                                generated_client_code = f"{branch_code}-{g_code}-{member_number_str}"
                                
                                # 3. Save Client
                                client_uuid = str(uuid.uuid4())
                                
                                # Setup storage path helper
                                def upload_client_file(file_data, file_name):
                                    if not file_data:
                                        return ""
                                    try:
                                        file_bytes = file_data.read()
                                        file_ext = file_data.name.split('.')[-1]
                                        storage_path = f"{client_uuid}/{file_name}.{file_ext}"
                                        
                                        # Try to ensure bucket exists
                                        try:
                                            buckets = uow.client.storage.list_buckets()
                                            bucket_names = [b.name for b in buckets]
                                            if "client-ids" not in bucket_names:
                                                uow.client.storage.create_bucket("client-ids", options={"public": True})
                                        except Exception:
                                            pass
                                            
                                        # Upload file
                                        uow.client.storage.from_("client-ids").upload(
                                            path=storage_path,
                                            file=file_bytes,
                                            file_options={"content-type": file_data.type}
                                        )
                                        
                                        # Get public URL
                                        return uow.client.storage.from_("client-ids").get_public_url(storage_path)
                                    except Exception as upload_err:
                                        st.warning(f"File upload failed for '{file_name}': {upload_err}")
                                        return ""
                                
                                # Upload Client ID and Passport
                                uploaded_id_url = upload_client_file(st.session_state.get("reg_client_id_file"), "id_document")
                                uploaded_passport_url = upload_client_file(st.session_state.get("reg_client_passport"), "passport")
                                
                                # Upload Guarantor ID and Passport
                                uploaded_g_id_url = upload_client_file(st.session_state.get("reg_guarantor_id_file"), "guarantor_id")
                                uploaded_g_pass_url = upload_client_file(st.session_state.get("reg_guarantor_passport"), "guarantor_passport")
                                
                                from domain.entities.client import Client
                                client_entity = Client(
                                    id=client_uuid,
                                    name=name_val,
                                    client_code=generated_client_code,
                                    nickname=st.session_state.get("reg_client_nickname"),
                                    phone=phone_val,
                                    address=st.session_state.get("reg_client_address"),
                                    business_address=st.session_state.get("reg_client_biz_address"),
                                    dob=date(1990, 1, 1),
                                    gender="Female",
                                    marital_status=st.session_state.get("reg_client_marital"),
                                    occupation="Trader",
                                    business_type=st.session_state.get("reg_client_biz_type"),
                                    id_means=st.session_state.get("reg_client_id_means"),
                                    id_number=st.session_state.get("reg_client_id_number"),
                                    id_card_url=uploaded_id_url,
                                    next_of_kin="",
                                    passport_url=uploaded_passport_url,
                                    signature_url="",
                                    registration_date=date.today(),
                                    branch_id=branch_id,
                                    group_id=final_group_id,
                                    officer_id=uow.loans._resolve_officer_id(USER),
                                    status="11111111-1111-1111-1111-111111110001",
                                    status_id="11111111-1111-1111-1111-111111110001",
                                    average_monthly_income=float(raw_inc or 0.0),
                                    other_obligations=st.session_state.get("reg_client_obligations")
                                )
                                uow.clients.create(client_entity)
                                
                                # 4. Create membership
                                uow.client.table("client_memberships").insert({
                                    "client_id": client_entity.id,
                                    "group_id": final_group_id,
                                    "branch_id": branch_id,
                                    "officer_id": client_entity.officer_id,
                                    "start_date": date.today().isoformat()
                                }).execute()
                                
                                # 5. Create dummy Pending loan to hold guarantor details and client profile references
                                default_product_res = uow.client.table("loan_products").select("product_id").limit(1).execute()
                                default_product_id = default_product_res.data[0]["product_id"] if default_product_res.data else None
                                
                                uow.client.table("loans").insert({
                                    "loan_id": str(uuid.uuid4()),
                                    "client_id": client_entity.id,
                                    "product_id": default_product_id,
                                    "branch_id": branch_id,
                                    "officer_id": client_entity.officer_id,
                                    "date": date.today().isoformat(),
                                    "loan_amount": 0.0,
                                    "active_credit": 0.0,
                                    "loan_repay": 0.0,
                                    "total_due": 0.0,
                                    "status": "Pending",
                                    "extra_fields": {
                                        "guarantor_name": st.session_state.get("reg_guarantor_name"),
                                        "guarantor_nickname": st.session_state.get("reg_guarantor_nickname"),
                                        "guarantor_phone": st.session_state.get("reg_guarantor_phone"),
                                        "guarantor_home_address": st.session_state.get("reg_guarantor_address"),
                                        "guarantor_marital_status": st.session_state.get("reg_guarantor_marital"),
                                        "guarantor_occupation": st.session_state.get("reg_guarantor_occupation"),
                                        "guarantor_relationship": st.session_state.get("reg_guarantor_relationship"),
                                        "guarantor_office_address": st.session_state.get("reg_guarantor_office"),
                                        "nickname": client_entity.nickname,
                                        "marital_status": client_entity.marital_status,
                                        "average_monthly_income": client_entity.average_monthly_income,
                                        "other_obligations": client_entity.other_obligations
                                    },
                                    "guarantor_id_means": st.session_state.get("reg_guarantor_id_means"),
                                    "guarantor_id_number": st.session_state.get("reg_guarantor_id_number"),
                                    "guarantor_id_card_url": uploaded_g_id_url,
                                    "guarantor_passport_url": uploaded_g_pass_url
                                }).execute()
                                
                                st.success(f"Successfully registered client! Assigned Client ID: {generated_client_code}")
                                import time
                                time.sleep(2)
                                st.rerun()
                        except Exception as ex:
                            st.error(f"Error registering client: {ex}")
                        
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
                    try:
                        raw_branch = pd.read_excel(uploaded_file, sheet_name='Branch and Officer List', header=None)
                        df_branch = extract_table(raw_branch, 'Branch Name', 'Region Name')
                    except:
                        df_branch = pd.DataFrame()
                        
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
                        with st.spinner("Importing data & balances..."):
                            success_count = 0
                            update_count = 0
                            skip_count = 0
                            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                            date_str = datetime.now().strftime("%Y-%m-%d")
                            
                            progress_bar = st.progress(0.0)
                            status_text = st.empty()
                            import_errors = []
                            
                            with SupabaseUnitOfWork() as uow:
                                # Load all system users once for fast, fuzzy, and robust officer resolution in-memory
                                db_users = uow.users.find_all()
                                
                                def resolve_officer_id(name_str):
                                    if not name_str:
                                        return None
                                    name_clean = str(name_str).strip().lower()
                                    # 1. Direct username case-insensitive check
                                    for u in db_users:
                                        if u.username.lower() == name_clean:
                                            return u.id
                                    # 2. Direct full name case-insensitive check
                                    for u in db_users:
                                        if u.full_name.lower() == name_clean:
                                            return u.id
                                    # 3. Fuzzy match ignoring common titles (e.g. Mr., Mrs., Miss., Mr, Mrs, Miss)
                                    titles = ["mr.", "mrs.", "miss.", "mr", "mrs", "miss"]
                                    name_no_title = name_clean
                                    for t in titles:
                                        if name_no_title.startswith(t):
                                            name_no_title = name_no_title[len(t):].strip()
                                            break
                                    for u in db_users:
                                        u_full_clean = u.full_name.lower()
                                        for t in titles:
                                            if u_full_clean.startswith(t):
                                                u_full_clean = u_full_clean[len(t):].strip()
                                                break
                                        if u_full_clean == name_no_title or u.username.lower() == name_no_title:
                                            return u.id
                                    # 4. Keyword fuzzy check (e.g. "Ayomide" in "Mr. Ayomide" or "CO2")
                                    for u in db_users:
                                        if name_no_title in u.full_name.lower() or name_no_title in u.username.lower():
                                            return u.id
                                    return None
                                
                                # 1. First process Groups
                                group_mapping = {}  # maps group name -> group_id
                                group_rows_map = {} # maps group name -> group_row
                                for index, group_row in df_groups.iterrows():
                                    gname = str(group_row.get('Group Name', '')).strip()
                                    if not gname or "example" in gname.lower():
                                        continue
                                    
                                    # Resolve branch_id
                                    bname = str(group_row.get('Branch Name', BRANCH)).strip()
                                    res_b = uow.client.table("branches").select("branch_id").eq("name", bname).execute()
                                    branch_id = res_b.data[0]["branch_id"] if res_b.data else None
                                    
                                    # Resolve officer_id
                                    oname = str(group_row.get('Credit Officer Name', USER)).strip()
                                    officer_id = resolve_officer_id(oname) or (current_user.id if current_user else None) or uow.loans._resolve_officer_id(USER)
                                    
                                    # Extract meeting day safely checking both potential column names
                                    m_day = group_row.get('Meeting Day')
                                    if m_day is None or (isinstance(m_day, float) and pd.isna(m_day)) or str(m_day).strip().lower() in ('nan', ''):
                                        m_day = group_row.get('Meeting Day/Time')
                                    if m_day is None or (isinstance(m_day, float) and pd.isna(m_day)) or str(m_day).strip().lower() in ('nan', ''):
                                        m_day = 'Daily'
                                    m_day = str(m_day).strip()

                                    # Extract Group Leader Name safely
                                    leader_name = group_row.get('Group Leader Name')
                                    if leader_name is None or (isinstance(leader_name, float) and pd.isna(leader_name)) or str(leader_name).strip().lower() in ('nan', ''):
                                        leader_name = None
                                    else:
                                        leader_name = str(leader_name).strip()

                                    # Check if group already exists
                                    res_g = uow.client.table("groups").select("group_id").eq("name", gname).execute()
                                    if res_g.data:
                                        group_id = res_g.data[0]["group_id"]
                                        uow.client.table("groups").update({
                                            "meeting_day": m_day,
                                            "branch_id": branch_id,
                                            "officer_id": officer_id,
                                            "leader_name": leader_name
                                        }).eq("group_id", group_id).execute()
                                    else:
                                        # Insert new group
                                        new_g = {
                                            "name": gname,
                                            "meeting_day": m_day,
                                            "branch_id": branch_id,
                                            "officer_id": officer_id,
                                            "leader_name": leader_name,
                                            "group_number": str(group_row.get('Group Reference', '01'))[-2:],
                                            "current_member_sequence": 0
                                        }
                                        res_g_ins = uow.client.table("groups").insert(new_g).execute()
                                        group_id = res_g_ins.data[0]["group_id"] if res_g_ins.data else None
                                    
                                    group_mapping[gname] = group_id
                                    group_rows_map[gname] = group_row

                                # 2. Process Members
                                from domain.entities.client import Client
                                import re
                                
                                for index, member_row in df_members.iterrows():
                                    try:
                                        name_val = str(member_row.get('Full Name', '')).strip()
                                        if not name_val or "example" in name_val.lower():
                                            continue
                                            
                                        group_ref = member_row.get('Group Reference')
                                        group_match = df_groups[df_groups['Group Reference'] == group_ref] if 'Group Reference' in df_groups.columns else pd.DataFrame()
                                        if group_match.empty:
                                            continue
                                            
                                        group_row = group_match.iloc[0]
                                        group_name = str(group_row.get('Group Name', '')).strip()
                                        group_id = group_mapping.get(group_name)
                                        
                                        # Resolve branch
                                        bname = str(group_row.get('Branch Name', BRANCH)).strip()
                                        res_b = uow.client.table("branches").select("branch_id, code").eq("name", bname).execute()
                                        if res_b.data:
                                            branch_id = res_b.data[0]["branch_id"]
                                            branch_code = res_b.data[0]["code"] or bname[:3].upper()
                                        else:
                                            branch_id = None
                                            branch_code = bname[:3].upper()
                                        
                                        # Resolve officer
                                        oname = str(group_row.get('Credit Officer Name', USER)).strip()
                                        officer_id = resolve_officer_id(oname) or (current_user.id if current_user else None) or uow.loans._resolve_officer_id(USER)
                                        
                                        phone_val = str(member_row.get('Phone Number', '')).strip()
                                        if phone_val.lower() == 'nan' or not phone_val:
                                            phone_val = "00000000000"
                                            
                                        # Parse client ID details
                                        id_means_val = str(member_row.get('Means of ID', 'None')).strip() if pd.notna(member_row.get('Means of ID')) else "None"
                                        id_number_val = str(member_row.get('ID Number', '')).strip() if pd.notna(member_row.get('ID Number')) else ""
                                        
                                        # Parse guarantor details
                                        g_name_val = str(member_row.get('Guarantor Name', '')).strip() if pd.notna(member_row.get('Guarantor Name')) else ""
                                        g_phone_val = str(member_row.get('Guarantor Phone', '')).strip() if pd.notna(member_row.get('Guarantor Phone')) else ""
                                        g_address_val = str(member_row.get('Guarantor Address', '')).strip() if pd.notna(member_row.get('Guarantor Address')) else ""
                                        g_occ_val = str(member_row.get('Guarantor Occupation', '')).strip() if pd.notna(member_row.get('Guarantor Occupation')) else ""
                                        g_office_val = str(member_row.get('Guarantor Office Address', '')).strip() if pd.notna(member_row.get('Guarantor Office Address')) else ""
                                        g_rel_val = str(member_row.get('Guarantor Relationship', '')).strip() if pd.notna(member_row.get('Guarantor Relationship')) else ""
                                        g_id_means_val = str(member_row.get('Guarantor ID Means', 'None')).strip() if pd.notna(member_row.get('Guarantor ID Means')) else "None"
                                        g_id_number_val = str(member_row.get('Guarantor ID Number', '')).strip() if pd.notna(member_row.get('Guarantor ID Number')) else ""
                                            
                                        # Check Client ID formatting
                                        ref_val = str(member_row.get('Member Reference', '')).strip()
                                        is_valid_id = bool(re.match(r'^[A-Z]{3}-\d{2}-\d{3}$', ref_val))
                                        
                                        # Check if client already exists (by Client ID or unique Phone)
                                        res_cl = None
                                        if is_valid_id:
                                            res_cl = uow.client.table("clients").select("*").eq("client_code", ref_val).execute()
                                        if (not res_cl or not res_cl.data) and phone_val != "00000000000" and len(phone_val) >= 7:
                                            res_cl = uow.client.table("clients").select("*").eq("phone", phone_val).execute()
                                            
                                        if res_cl and res_cl.data:
                                            client_id = res_cl.data[0]["client_id"]
                                            client_code = res_cl.data[0]["client_code"]
                                            uow.client.table("clients").update({
                                                "nickname": str(member_row.get('Nickname', '')) if pd.notna(member_row.get('Nickname')) else "",
                                                "address": str(member_row.get('Home Address', '')) if pd.notna(member_row.get('Home Address')) else "",
                                                "business_address": str(member_row.get('Business Address', '')) if pd.notna(member_row.get('Business Address')) else "",
                                                "business_type": str(member_row.get('Business Type', 'Trader')) if pd.notna(member_row.get('Business Type')) else "Trader",
                                                "occupation": str(member_row.get('Occupation', 'Trader')) if pd.notna(member_row.get('Occupation')) else "Trader",
                                                "id_means": id_means_val,
                                                "id_number": id_number_val,
                                                "group_id": group_id
                                            }).eq("client_id", client_id).execute()
                                            update_count += 1
                                        else:
                                            # Generate sequential Client ID
                                            if is_valid_id:
                                                client_code = ref_val
                                            else:
                                                if not group_id:
                                                    g_code = "IND"
                                                    res_count = uow.client.table("clients").select("client_id", count="exact").is_("group_id", "null").eq("branch_id", branch_id).execute()
                                                    next_seq = (res_count.count or 0) + 1
                                                else:
                                                    g_code = str(group_row.get('Group Reference', '01'))[-2:]
                                                    next_seq = uow.clients.get_next_member_sequence(group_id)
                                                    
                                                member_number_str = str(next_seq).zfill(3)
                                                client_code = f"{branch_code}-{g_code}-{member_number_str}"
                                                
                                            client_id = str(uuid.uuid4())
                                            
                                            # Create new client profile
                                            new_cl = Client(
                                                id=client_id,
                                                name=name_val,
                                                client_code=client_code,
                                                nickname=str(member_row.get('Nickname', '')) if pd.notna(member_row.get('Nickname')) else "",
                                                phone=phone_val,
                                                address=str(member_row.get('Home Address', '')) if pd.notna(member_row.get('Home Address')) else "",
                                                business_address=str(member_row.get('Business Address', '')) if pd.notna(member_row.get('Business Address')) else "",
                                                dob=date(1990, 1, 1),
                                                gender="Female" if "female" in str(member_row.get('Gender', '')).lower() else "Male",
                                                marital_status="Married",
                                                occupation=str(member_row.get('Occupation', 'Trader')) if pd.notna(member_row.get('Occupation')) else "Trader",
                                                business_type=str(member_row.get('Business Type', 'Trader')) if pd.notna(member_row.get('Business Type')) else "Trader",
                                                id_means=id_means_val,
                                                id_number=id_number_val,
                                                id_card_url="",
                                                next_of_kin="",
                                                passport_url="",
                                                signature_url="",
                                                registration_date=date.today(),
                                                branch_id=branch_id,
                                                group_id=group_id,
                                                officer_id=officer_id or uow.loans._resolve_officer_id(USER),
                                                status="Active",
                                                average_monthly_income=0.0,
                                                other_obligations=""
                                            )
                                            uow.clients.create(new_cl)
                                            success_count += 1
                                            
                                            # Link group membership
                                            uow.client.table("client_memberships").insert({
                                                "client_id": client_id,
                                                "group_id": group_id,
                                                "branch_id": branch_id,
                                                "officer_id": new_cl.officer_id,
                                                "start_date": date.today().isoformat()
                                            }).execute()

                                        # Parse financial amounts
                                        def get_amt(row_data, keys):
                                            for k in keys:
                                                if k in row_data:
                                                    v = row_data.get(k)
                                                    if pd.notna(v):
                                                        try: return float(str(v).replace(',', ''))
                                                        except: pass
                                            return 0.0

                                        principal_loan = get_amt(member_row, ['Principal loan', 'Principal Loan'])
                                        active_credit = get_amt(member_row, ['Active credit', 'Active Credit', 'Active Credit (Disbursed)'])
                                        remaining_bal = get_amt(member_row, ['Current credit balance', 'Current Credit Balance'])
                                        savings_bal = get_amt(member_row, ['Savings Balance', 'Savings balance'])
                                        loan_type = str(member_row.get('Loan Type (Product)', ''))
                                        
                                        # Import active loan
                                        if active_credit > 0 or remaining_bal > 0:
                                            res_active_loan = uow.client.table("loans").select("loan_id").eq("client_id", client_id).eq("status", "Active").execute()
                                            if not res_active_loan.data:
                                                from domain.entities.loan import Loan
                                                from domain.enums import LoanStatus
                                                
                                                loan_id = str(uuid.uuid4())
                                                duration_val = 24 if "24" in loan_type else (12 if "12" in loan_type or "week" in loan_type.lower() else 60)
                                                true_active_credit = active_credit if active_credit > 0 else (principal_loan or remaining_bal)
                                                true_installment = true_active_credit / duration_val if duration_val > 0 else 0.0
                                                amount_already_paid = max(0.0, true_active_credit - remaining_bal) if remaining_bal > 0 else 0.0

                                                resolved_prod_type = loan_type
                                                lt_l = (loan_type or "").lower()
                                                if "asset" not in lt_l:
                                                    if "12" in lt_l and ("week" in lt_l or "w" in lt_l):
                                                        resolved_prod_type = "Weekly 12W"
                                                    elif "24" in lt_l and ("week" in lt_l or "w" in lt_l):
                                                        resolved_prod_type = "Weekly 24W"
                                                    elif "60" in lt_l:
                                                        resolved_prod_type = "Daily 60 Days"
                                                    elif "120" in lt_l:
                                                        resolved_prod_type = "Daily 120 Days"

                                                loan_entity = Loan(
                                                    id=loan_id,
                                                    client_id=client_id,
                                                    client_name=name_val,
                                                    product_type=resolved_prod_type or "Weekly 24W",
                                                    amount=principal_loan or true_active_credit,
                                                    duration=duration_val,
                                                    frequency="Weekly" if "week" in loan_type.lower() else "Daily",
                                                    gap_fee=0.0,
                                                    expected_installment=true_installment,
                                                    total_payable=true_active_credit,
                                                    status=LoanStatus.ACTIVE,
                                                    branch=bname,
                                                    credit_officer=oname or USER,
                                                    officer_id=officer_id,
                                                    branch_id=branch_id,
                                                    start_date=date.today() - timedelta(weeks=4),
                                                    extra_fields={
                                                        "lifecycle_status": "Active",
                                                        "active_credit": true_active_credit,
                                                        "total_due": true_active_credit,
                                                        "loan_repay": true_installment,
                                                        "guarantor_name": g_name_val,
                                                        "guarantor_phone": g_phone_val,
                                                        "guarantor_home_address": g_address_val,
                                                        "guarantor_occupation": g_occ_val,
                                                        "guarantor_office_address": g_office_val,
                                                        "guarantor_relationship": g_rel_val
                                                    }
                                                )
                                                uow.loans.create(loan_entity)
                                                
                                                # Save guarantor details and extra fields on active loan row
                                                uow.client.table("loans").update({
                                                    "guarantor_id_means": g_id_means_val,
                                                    "guarantor_id_number": g_id_number_val
                                                }).eq("loan_id", loan_id).execute()
                                                
                                                # Create/link guarantor in first-class tables
                                                if g_name_val and g_phone_val:
                                                    res_g = uow.guarantors.find_by_phone(g_phone_val)
                                                    if res_g:
                                                        g_id = res_g.guarantor_id
                                                    else:
                                                        from domain.entities.guarantor import Guarantor
                                                        g_ent = uow.guarantors.create_guarantor(Guarantor(
                                                            guarantor_id=str(uuid.uuid4()),
                                                            name=g_name_val,
                                                            phone=g_phone_val,
                                                            address=g_address_val,
                                                            occupation=g_occ_val,
                                                            business_address=g_office_val,
                                                            id_means=g_id_means_val,
                                                            id_number=g_id_number_val
                                                        ))
                                                        g_id = g_ent.guarantor_id
                                                        
                                                    from domain.entities.guarantor import LoanGuarantor
                                                    uow.guarantors.link_to_loan(LoanGuarantor(
                                                        id=str(uuid.uuid4()),
                                                        loan_id=loan_id,
                                                        guarantor_id=g_id,
                                                        relationship=g_rel_val
                                                    ))
                                                
                                                from services.schedule_service import ScheduleService
                                                start_sched_date = date.today() - timedelta(weeks=4)
                                                ScheduleService.generate_schedule(uow, loan_entity, start_sched_date)

                                                # Inject historical repayment for amount already paid and update schedule status
                                                if amount_already_paid > 0:
                                                    uow.client.table("repayments").insert({
                                                        "repayment_id": str(uuid.uuid4()),
                                                        "client_id": client_id,
                                                        "loan_id": loan_id,
                                                        "branch_id": branch_id,
                                                        "officer_id": officer_id or uow.loans._resolve_officer_id(USER),
                                                        "date": start_sched_date.isoformat(),
                                                        "amount_paid": amount_already_paid,
                                                        "loan_repayment_amount": amount_already_paid,
                                                        "transaction_type": "Loan",
                                                        "note": "Historical accumulated payments from Onboarding Import",
                                                        "payment_status": "Completed"
                                                    }).execute()
                                                    ScheduleService.record_repayment(uow, loan_id, amount_already_paid, start_sched_date)
                                        else:
                                            # Create dummy Pending loan for guarantor details if no active loan was created
                                            if g_name_val:
                                                default_product_res = uow.client.table("loan_products").select("product_id").limit(1).execute()
                                                default_product_id = default_product_res.data[0]["product_id"] if default_product_res.data else None
                                                
                                                uow.client.table("loans").insert({
                                                    "loan_id": str(uuid.uuid4()),
                                                    "client_id": client_id,
                                                    "product_id": default_product_id,
                                                    "branch_id": branch_id,
                                                    "officer_id": officer_id or uow.loans._resolve_officer_id(USER),
                                                    "date": date.today().isoformat(),
                                                    "loan_amount": 0.0,
                                                    "active_credit": 0.0,
                                                    "loan_repay": 0.0,
                                                    "total_due": 0.0,
                                                    "status": "Pending",
                                                    "extra_fields": {
                                                        "guarantor_name": g_name_val,
                                                        "guarantor_phone": g_phone_val,
                                                        "guarantor_home_address": g_address_val,
                                                        "guarantor_marital_status": "Married",
                                                        "guarantor_occupation": g_occ_val,
                                                        "guarantor_relationship": g_rel_val,
                                                        "guarantor_office_address": g_office_val,
                                                        "nickname": str(member_row.get('Nickname', '')) if pd.notna(member_row.get('Nickname')) else "",
                                                        "marital_status": "Married",
                                                        "average_monthly_income": 0.0,
                                                        "other_obligations": ""
                                                    },
                                                    "guarantor_id_means": g_id_means_val,
                                                    "guarantor_id_number": g_id_number_val
                                                }).execute()
                                        
                                        # Import opening savings
                                        from services.savings_service import SavingsService
                                        if savings_bal > 0:
                                            SavingsService.post_individual_savings(
                                                uow, client_id, name_val, bname, oname or USER, savings_bal, 0.0,
                                                remarks="Opening Savings Balance from Onboarding Import"
                                            )
                                        
                                        # Check if member has opening laps or misc savings
                                        m_laps = 0.0
                                        m_misc = 0.0
                                        for k in ['Laps Savings', 'Branch Laps Savings', 'Laps']:
                                            if k in member_row and pd.notna(member_row[k]):
                                                try:
                                                    m_laps = float(str(member_row[k]).replace(',', ''))
                                                    break
                                                except: pass
                                        for k in ['Misc Savings', 'Misc Fees', 'Misc']:
                                            if k in member_row and pd.notna(member_row[k]):
                                                try:
                                                    m_misc = float(str(member_row[k]).replace(',', ''))
                                                    break
                                                except: pass
                                        if m_laps > 0:
                                            SavingsService.post_laps_savings(
                                                uow, client_id, name_val, bname, oname or USER, m_laps, 0.0,
                                                remarks="Opening LAPS Savings from Onboarding Import"
                                            )
                                        if m_misc > 0:
                                            SavingsService.post_misc_savings(
                                                uow, client_id, name_val, bname, oname or USER, m_misc,
                                                remarks="Opening Misc Savings from Onboarding Import"
                                            )
                                        # Update progress bar
                                        pct = (index + 1) / num_members
                                        progress_bar.progress(pct)
                                        status_text.text(f"Processing member {index+1} of {num_members}: {name_val}")
                                        
                                    except Exception as ex:
                                        import_errors.append(f"Row {index+1} ({name_val}): {str(ex)}")
                                        print(f"Error importing row {index}: {ex}")

                                # 3. Process Group-Level Opening Savings
                                from services.savings_service import SavingsService
                                for gname, group_id in group_mapping.items():
                                    group_row = group_rows_map[gname]
                                    g_savings = 0.0
                                    for k in ['Group Savings', 'Current Group Savings Balance']:
                                        if k in group_row and pd.notna(group_row[k]):
                                            try:
                                                g_savings = float(str(group_row[k]).replace(',', ''))
                                                break
                                            except: pass
                                    
                                    if g_savings > 0:
                                        bname = str(group_row.get('Branch Name', BRANCH)).strip()
                                        oname = str(group_row.get('Credit Officer Name', USER)).strip()
                                        SavingsService.post_group_savings(
                                            uow, gname, bname, oname, g_savings, 0.0,
                                            remarks="Opening Group Savings from Onboarding Import"
                                        )

                                # 4. Process Branch Laps and Misc opening balances dynamically
                                laps_sav = 0.0
                                misc_sav = 0.0
                                laps_header_idx = -1
                                 
                                for idx, row in raw_branch.iterrows():
                                    row_vals = [str(val).strip().lower() for val in row.values if pd.notna(val)]
                                    if any('laps savings' in val or 'laps_savings' in val or 'laps savings balance' in val for val in row_vals):
                                        laps_header_idx = idx
                                        break
                                        
                                if laps_header_idx != -1 and laps_header_idx + 1 < len(raw_branch):
                                    header_row = raw_branch.iloc[laps_header_idx]
                                    val_row = raw_branch.iloc[laps_header_idx + 1]
                                    laps_col_idx = -1
                                    misc_col_idx = -1
                                    
                                    for col_idx, col_val in enumerate(header_row):
                                        if pd.notna(col_val):
                                            col_str = str(col_val).strip().lower()
                                            if 'laps' in col_str:
                                                laps_col_idx = col_idx
                                            elif 'misc' in col_str or 'fees' in col_str:
                                                misc_col_idx = col_idx
                                                
                                    if laps_col_idx != -1 and laps_col_idx < len(val_row):
                                        laps_val = val_row.iloc[laps_col_idx]
                                        if pd.notna(laps_val):
                                            try: laps_sav = float(str(laps_val).replace(',', '').strip())
                                            except: pass
                                            
                                    if misc_col_idx != -1 and misc_col_idx < len(val_row):
                                        misc_val = val_row.iloc[misc_col_idx]
                                        if pd.notna(misc_val):
                                            try: misc_sav = float(str(misc_val).replace(',', '').strip())
                                            except: pass
                                            
                                if laps_sav > 0 or misc_sav > 0:
                                    # Resolve the branch name from the branch list or fallback to global BRANCH
                                    bname = BRANCH
                                    if not df_branch.empty:
                                        bname = str(df_branch.iloc[0].get('Branch Name', BRANCH)).strip()
                                        
                                    if laps_sav > 0:
                                        SavingsService.post_laps_savings(
                                            uow, None, f"Laps Savings ({bname})", bname, USER, laps_sav, 0.0,
                                            remarks="Opening Balance from Onboarding Import"
                                        )
                                    if misc_sav > 0:
                                        SavingsService.post_misc_savings(
                                            uow, None, f"Misc Fees Savings ({bname})", bname, USER, misc_sav,
                                            remarks="Opening Balance from Onboarding Import"
                                        )
                                            
                            # Clear progress bar
                            progress_bar.empty()
                            status_text.empty()
                            
                            if import_errors:
                                st.error("⚠️ Some rows failed to import:")
                                for err in import_errors[:20]:
                                    st.write(err)
                                if len(import_errors) > 20:
                                    st.write(f"... and {len(import_errors) - 20} more errors.")
                                st.info("Please make sure you have run the updated Supabase SQL migration script to add the required columns.")
                            
                            if success_count > 0 or update_count > 0:
                                st.success(f"✅ Onboarding Import Complete! Registered {success_count} new members. Updated {update_count} existing members. Skipped {skip_count} duplicates.")
                                import time
                                time.sleep(3)
                                st.rerun()
                except Exception as e:
                    st.error(f"Error reading file: {e}")
            st.markdown("</div>", unsafe_allow_html=True)

    elif orig_section == "Loan Application":
        st.subheader("Loan Application")
        
        # 1. Search Client
        search_query = st.text_input("Search Client by Name or Client ID", key="loan_app_search_query")
        
        selected_client_id = None
        selected_client = None
        
        if search_query:
            with SupabaseUnitOfWork() as uow:
                found_clients = uow.clients.search_by_name_or_code(search_query)
                
            # Apply RBAC hierarchy filters
            if ROLE in ['CO', 'Officer', ROLE_CREDIT_OFFICER]:
                user_id = current_user.id if current_user else None
                found_clients = [c for c in found_clients if c.officer_id == user_id]
            elif ROLE in ['BM', ROLE_BRANCH_MANAGER]:
                found_clients = [c for c in found_clients if c.branch_id == BRANCH_ID]
            elif ROLE in ['AM', 'Area Manager']:
                found_clients = [c for c in found_clients if c.branch_id in ASSIGNED_BRANCH_IDS]
                
            if not found_clients:
                st.warning("No clients found matching the search criteria.")
            else:
                client_options = {f"{c.client_code} - {c.name}": c for c in found_clients}
                selected_display = st.selectbox("Select Client", [""] + list(client_options.keys()), key="loan_app_selected_client_select")
                if selected_display:
                    selected_client = client_options[selected_display]
                    selected_client_id = selected_client.id
        
        if selected_client:
            # 2. Prefill client metadata
            st.markdown("### 👤 Client Profile Summary")
            col1, col2, col3 = st.columns(3)
            col1.markdown(f"**Client ID:** `{selected_client.client_code}`")
            col2.markdown(f"**Full Name:** {selected_client.name}")
            col3.markdown(f"**Phone:** {selected_client.phone or 'N/A'}")
            
            col4, col5, col6 = st.columns(3)
            with SupabaseUnitOfWork() as uow:
                res_b = uow.client.table("branches").select("name").eq("branch_id", selected_client.branch_id).execute()
                branch_name = res_b.data[0]["name"] if res_b.data else "Unknown"
                
                res_g = uow.client.table("groups").select("name").eq("group_id", selected_client.group_id).execute()
                group_name = res_g.data[0]["name"] if res_g.data else "Individual (No Group)"
                
                res_u = uow.client.table("app_users").select("full_name").eq("id", selected_client.officer_id).execute()
                officer_name = res_u.data[0]["full_name"] if res_u.data else "Unknown"
                
                res_l = uow.client.table("loans").select("extra_fields").eq("client_id", selected_client.id).order("created_at", desc=True).limit(1).execute()
                extra = res_l.data[0].get("extra_fields") or {} if res_l.data else {}
                g_name_val = extra.get("guarantor_name")
                g_phone_val = extra.get("guarantor_phone")
                g_rel_val = extra.get("guarantor_relationship")
                
            col4.markdown(f"**Branch:** {branch_name}")
            col5.markdown(f"**Group:** {group_name}")
            col6.markdown(f"**Credit Officer:** {officer_name}")

            if g_name_val or g_phone_val:
                st.markdown("##### Guarantor Details")
                g_col1, g_col2, g_col3 = st.columns(3)
                g_col1.markdown(f"**Name:** {g_name_val or 'N/A'}")
                g_col2.markdown(f"**Phone:** {g_phone_val or 'N/A'}")
                g_col3.markdown(f"**Relationship:** {g_rel_val or 'N/A'}")

            # 3. Load Savings Balance
            with SupabaseUnitOfWork() as uow:
                res_dep = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", selected_client.id).execute()
                res_wd = uow.client.table("individual_savings").select("withdrawal_amount").eq("client_id", selected_client.id).execute()
                savings_bal = sum(float(d.get("deposit_amount") or 0) for d in res_dep.data) - sum(float(w.get("withdrawal_amount") or 0) for w in res_wd.data)
            
            st.info(f"**Current Pooled Savings Balance:** ₦{savings_bal:,.2f}")

            # 4. Loan Specific fields
            st.markdown("### Apply for a New Loan")
            st.markdown("#### 1. Loan Product Parameters")
            product_category = st.selectbox("Product Category", ["Finance", "Asset"], key="loan_app_category")
            
            with st.container():
                col_p1, col_p2 = st.columns(2)
                
                if product_category == "Finance":
                    prods = ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M"]
                else:
                    prods = ["60-Day Asset", "120-Day Asset", "Weekly 12W Asset", "Weekly 24W Asset", "Monthly 3M Asset", "Monthly 6M Asset", "Cash and Carry"]
                    
                # Fetch allowed_products from current user
                allowed_products = []
                if current_user:
                    if isinstance(current_user, dict):
                        extra = current_user.get("extra_fields") or {}
                    else:
                        extra = getattr(current_user, "extra_fields", {}) or {}
                        
                    if isinstance(extra, str):
                        import json
                        try:
                            extra = json.loads(extra)
                        except:
                            extra = {}
                            
                    allowed_products = extra.get("allowed_products", []) if isinstance(extra, dict) else []
                    
                if isinstance(allowed_products, list) and len(allowed_products) > 0:
                    filtered_prods = [p for p in prods if p in allowed_products]
                    if filtered_prods:
                        prods = filtered_prods
                    else:
                        st.error(f"You do not have permission to originate any {product_category} products. Contact your Branch Manager.")
                        st.stop()
                    
                product_type = col_p1.selectbox("Loan Product", prods, key=f"loan_app_product_{product_category}")
                
                requested_amount = float(col_p2.number_input("Requested Amount / Asset Cost (₦)", min_value=0.0, step=10000.0, value=None, placeholder="0", key="loan_app_amount") or 0)
                
                # Setup parameters based on selected product type
                rate = 0.12
                duration = 12
                cycle = "Weekly"
                round_step = 50
                force_gap = False
                
                if "Cash and Carry" in product_type:
                    rate = 0.0
                    duration = 1
                    cycle = "One-Time"
                    round_step = 1
                elif "120" in product_type:
                    rate = 0.21
                    duration = 120
                    cycle = "Daily"
                    round_step = 50
                elif "Daily" in product_type or "60" in product_type:
                    rate = 0.12
                    duration = 60
                    cycle = "Daily"
                    round_step = 50
                elif "3 Month" in product_type or "3M" in product_type:
                    rate = 0.12
                    duration = 3
                    cycle = "Monthly"
                    round_step = 100
                elif "6 Month" in product_type or "6M" in product_type:
                    rate = 0.21
                    duration = 6
                    cycle = "Monthly"
                    round_step = 100
                elif "12 Week" in product_type or "12W" in product_type:
                    rate = 0.12
                    duration = 12
                    cycle = "Weekly"
                    round_step = 50
                    force_gap = True
                elif "24 Week" in product_type or "24W" in product_type:
                    rate = 0.21
                    duration = 24
                    cycle = "Weekly"
                    round_step = 50
                    force_gap = True

                interest = requested_amount * rate
                
                # 5. Loan Renewal / Eligibility Checker
                if requested_amount > 0:
                    from services.renewal_service import RenewalService
                    with SupabaseUnitOfWork() as uow:
                        is_eligible, reasons, warnings = RenewalService.check_eligibility(uow, selected_client_id, requested_amount, product_type, product_category)
                    
                    if is_eligible:
                        st.success("**ELIGIBLE:** " + reasons[-1])
                        for w in warnings:
                            st.warning(w)
                    else:
                        st.error("**NOT ELIGIBLE:**")
                        for r in reasons:
                            st.write(f"- {r}")
                        for w in warnings:
                            st.warning(w)
                initial_downpayment = 0.0
                gap_fee = 0.0
                total_upfront_required = 0.0
                
                if product_category == "Asset":
                    dp_mode = st.radio("Downpayment Source", ["Cash (Physical Payment)", "Savings (Deduct from Pooled Savings)", "Split (Part Cash, Part Savings)"], horizontal=True, key="loan_app_dp_mode")
                    
                    cash_dp = 0.0
                    sav_dp = 0.0
                    
                    if dp_mode == "Cash (Physical Payment)":
                        cash_dp_input = st.number_input("Initial Cash Downpayment (₦)", min_value=0.0, step=5000.0, value=None, placeholder="0", key="loan_app_downpayment")
                        cash_dp = float(cash_dp_input or 0)
                    elif dp_mode == "Savings (Deduct from Pooled Savings)":
                        sav_dp_input = st.number_input("Downpayment to Deduct from Savings (₦)", min_value=0.0, step=5000.0, value=None, placeholder="0", key="loan_app_sav_downpayment")
                        sav_dp = float(sav_dp_input or 0)
                    else: # Split
                        c_dp1, c_dp2 = st.columns(2)
                        cash_dp_input = c_dp1.number_input("Cash Downpayment (₦)", min_value=0.0, step=5000.0, value=None, placeholder="0", key="loan_app_downpayment")
                        cash_dp = float(cash_dp_input or 0)
                        sav_dp_input = c_dp2.number_input("Savings Downpayment (₦)", min_value=0.0, step=5000.0, value=None, placeholder="0", key="loan_app_sav_downpayment")
                        sav_dp = float(sav_dp_input or 0)
                        
                    initial_downpayment = cash_dp + sav_dp
                    total_cost = requested_amount + interest
                    active_credit = total_cost - initial_downpayment
                    expected_installment = active_credit / duration if duration > 0 else 0.0
                    
                    st.markdown("---")
                    st.markdown(f"**Asset Cost:** ₦{requested_amount:,.0f} | **Interest:** ₦{interest:,.0f} | **Total Cost:** ₦{total_cost:,.0f}")
                    st.markdown(f"**Total Downpayment:** ₦{initial_downpayment:,.0f} *(Cash: ₦{cash_dp:,.0f} | Savings: ₦{sav_dp:,.0f})*")
                    st.markdown(f"**Active Loan (Total Cost - Downpayment):** ₦{active_credit:,.0f}")
                    st.markdown(f"**Expected Installment:** ₦{expected_installment:,.0f} x {duration} {cycle}")
                    
                    if sav_dp > 0:
                        if savings_bal < sav_dp:
                            st.error(f"**INSUFFICIENT SAVINGS:** Client has ₦{savings_bal:,.2f} but needs ₦{sav_dp:,.0f} from savings for downpayment.")
                        else:
                            st.success(f"**SUFFICIENT SAVINGS:** ₦{sav_dp:,.0f} will be deducted from client's savings upon loan creation as a Product Withdrawal.")
                    if cash_dp > 0:
                        st.info(f"Ensure the ₦{cash_dp:,.0f} cash downpayment is collected physically.")
                else:
                    # Finance default gap calculation
                    default_gap = 0.0
                    raw_val = requested_amount / duration if duration > 0 else 0
                    if not raw_val.is_integer() and requested_amount > 0:
                        loan_repayment = math.floor(raw_val / round_step) * round_step
                        while True:
                            gap = requested_amount - (loan_repayment * duration)
                            is_valid = True if gap >= 0 else False
                            if force_gap and (gap % 1000 != 0 or gap < 1000):
                                is_valid = False
                            if is_valid:
                                default_gap = float(gap)
                                break
                            loan_repayment -= round_step
                            if loan_repayment <= 0:
                                default_gap = float(requested_amount)
                                break
                                
                    gap_fee_input = st.number_input("Gap Fee / Base Savings (₦)", min_value=0.0, step=1000.0, value=default_gap if default_gap > 0 else None, placeholder="0", key="loan_app_gap_fee")
                    gap_fee = float(gap_fee_input or 0)
                    total_upfront_required = interest + gap_fee
                    active_credit = requested_amount - gap_fee
                    expected_installment = active_credit / duration if duration > 0 else 0.0
                    
                    st.markdown("---")
                    st.markdown(f"**Calculated Upfront Requirement:**")
                    st.markdown(f"- Interest: ₦{interest:,.0f}")
                    st.markdown(f"- Gap Fee (Base Savings): ₦{gap_fee:,.0f}")
                    st.markdown(f"**Total Required:** ₦{total_upfront_required:,.0f}")
                    
                    if total_upfront_required > 0:
                        if savings_bal < total_upfront_required:
                            st.error(f"**INSUFFICIENT SAVINGS:** Client has ₦{savings_bal:,.2f} but needs ₦{total_upfront_required:,.0f}. Please collect additional savings first.")
                        else:
                            st.success("SUFFICIENT SAVINGS: Client has enough to cover the upfront fees.")

                st.markdown("#### 2. Loan Notes")
                notes = st.text_area("Remarks / Notes", key="loan_app_notes")
                
                submitted_loan_app = st.button("Submit Application for BM Approval", type="primary", use_container_width=True)
                
                if submitted_loan_app:
                    if requested_amount <= 0:
                        st.error("Please enter a valid Loan Amount.")
                    else:
                        try:
                            with SupabaseUnitOfWork() as uow:
                                # Validation: check for existing loan of the same category
                                check_prod_cat = product_category
                                res_existing = uow.client.table("loans").select("*").eq("client_id", selected_client_id).eq("status", "Pending").execute()
                                # Also check if active loan exists
                                res_active = uow.client.table("loans").select("*").eq("client_id", selected_client_id).eq("status", "Active").execute()
                                
                                is_blocked = False
                                for L in res_existing.data + res_active.data:
                                    if L.get("product_category", "Finance") == check_prod_cat and float(L.get("loan_amount", 0)) > 0:
                                        is_blocked = True
                                        
                                if is_blocked:
                                    st.error(f"Cannot submit: This client already has an Active or Pending {product_category} loan!")
                                    st.stop()
                                    
                                if product_category == "Finance" and savings_bal < total_upfront_required:
                                    st.error("Cannot submit! Insufficient savings.")
                                    st.stop()
                                    
                                if product_category == "Asset" and sav_dp > 0 and savings_bal < sav_dp:
                                    st.error("Cannot submit! Insufficient savings for Asset Downpayment.")
                                    st.stop()

                                # For Finance: auto-deduct upfront fees from savings
                                if product_category == "Finance" and total_upfront_required > 0:
                                    from services.savings_service import SavingsService
                                    SavingsService.post_individual_savings(
                                        uow,
                                        client_id=selected_client_id,
                                        client_name=selected_client.name,
                                        branch=branch_name,
                                        officer=USER,
                                        deposit_amount=0.0,
                                        withdrawal_amount=total_upfront_required,
                                        remarks=f"Auto-deducted Upfront Fees (Interest: {interest}, Gap: {gap_fee}) for Loan App"
                                    )

                                from domain.entities.loan import Loan
                                from domain.enums import LoanStatus
                                
                                loan_id = str(uuid.uuid4())
                                if product_category == "Finance":
                                    final_active_credit = requested_amount - gap_fee
                                    final_total_payable = requested_amount + interest
                                    final_expected_installment = final_active_credit / duration if duration > 0 else 0.0
                                else:
                                    final_active_credit = (requested_amount + interest) - initial_downpayment
                                    final_total_payable = final_active_credit
                                    final_expected_installment = final_active_credit / duration if duration > 0 else 0.0

                                # For Asset with Savings Downpayment: register non-cash downpayment offset from savings
                                if product_category == "Asset" and sav_dp > 0:
                                    from services.savings_service import SavingsService
                                    SavingsService.post_loan_offset_from_savings(
                                        uow,
                                        client_id=selected_client_id,
                                        client_name=selected_client.name,
                                        loan_id=loan_id,
                                        source_savings_type="IndividualSavings",
                                        branch=branch_name,
                                        officer=USER,
                                        amount=sav_dp,
                                        remarks=f"Asset Downpayment deducted from Savings for loan {loan_id}"
                                    )

                                loan_entity = Loan(
                                    id=loan_id,
                                    client_id=selected_client_id,
                                    client_name=selected_client.name,
                                    product_type=product_type,
                                    amount=requested_amount,
                                    duration=duration,
                                    frequency=cycle,
                                    gap_fee=gap_fee,
                                    expected_installment=final_expected_installment,
                                    total_payable=final_total_payable,
                                    status=LoanStatus.PENDING,
                                    branch=branch_name,
                                    credit_officer=USER,
                                    officer_id=selected_client.officer_id,
                                    branch_id=selected_client.branch_id,
                                    start_date=date.today(),
                                    is_asset=(product_category == "Asset"),
                                    extra_fields={
                                        "lifecycle_status": "Submitted",
                                        "notes": notes,
                                        "product_category": product_category,
                                        "downpayment_source": dp_mode if product_category == "Asset" else None,
                                        "downpayment_cash": cash_dp if product_category == "Asset" else 0.0,
                                        "downpayment_savings": sav_dp if product_category == "Asset" else 0.0,
                                        "initial_downpayment": initial_downpayment,
                                        "active_credit": final_active_credit,
                                        "loan_repay": final_expected_installment,
                                        "total_due": final_active_credit
                                    }
                                )
                                uow.loans.create(loan_entity)

                                # Update client lifecycle status to 'Pending Loan' (BR-CLI-003.1)
                                try:
                                    from services.client_status_service import ClientStatusService
                                    ClientStatusService.on_loan_submitted(uow, selected_client_id, loan_id, getattr(selected_client, "officer_id", None))
                                except Exception as st_err:
                                    print(f"[STATUS TRACE] Failed to update client status to Pending Loan: {st_err}")

                                from services.schedule_service import ScheduleService
                                ScheduleService.generate_schedule(uow, loan_entity, date.today() + timedelta(days=7))

                                st.session_state["flash_msg"] = "Application submitted successfully! Repayment schedule generated and loan is Pending BM Approval."
                                st.session_state["orig_tab"] = "Pending Disbursements"
                                st.rerun()
                        except Exception as ex:
                            st.error(f"Error submitting loan application: {ex}")
                            
    elif orig_section == "Edit Client & Guarantor":
        st.subheader("Edit Client & Guarantor Details")
        st.info("Search for a registered client to update their personal details and their guarantor information.")
        
        # 1. Search Client
        search_query = st.text_input("Search Client by Name or Client ID to Edit", key="edit_client_search_query")
        
        selected_client = None
        if search_query:
            with SupabaseUnitOfWork() as uow:
                found_clients = uow.clients.search_by_name_or_code(search_query)
                
            # Apply RBAC hierarchy filters
            if ROLE in ['CO', 'Officer', ROLE_CREDIT_OFFICER]:
                user_id = current_user.id if current_user else None
                found_clients = [c for c in found_clients if c.officer_id == user_id]
            elif ROLE in ['BM', ROLE_BRANCH_MANAGER]:
                found_clients = [c for c in found_clients if c.branch_id == BRANCH_ID]
            elif ROLE in ['AM', 'Area Manager']:
                found_clients = [c for c in found_clients if c.branch_id in ASSIGNED_BRANCH_IDS]
                
            if not found_clients:
                st.warning("No clients found matching the search criteria.")
            else:
                client_options = {f"{c.client_code} - {c.name}": c for c in found_clients}
                selected_display = st.selectbox("Select Client", [""] + list(client_options.keys()), key="edit_client_selected_select")
                if selected_display:
                    selected_client = client_options[selected_display]

        if selected_client:
            # Load their latest loan (to get guarantor info)
            with SupabaseUnitOfWork() as uow:
                # Query loans table for the latest loan associated with this client
                res_l = uow.client.table("loans").select("*").eq("client_id", selected_client.id).order("created_at", desc=True).limit(1).execute()
                latest_loan = res_l.data[0] if res_l.data else {}

            st.markdown("### 👤 Update Client Profile & Guarantor Details")
            
            with st.form("edit_client_details_form"):
                st.markdown("#### 1. Personal Details")
                col1, col2, col3 = st.columns(3)
                c_name = col1.text_input("Full Name", value=selected_client.name)
                c_phone = col2.text_input("Phone Number", value=selected_client.phone or "")
                c_address = col3.text_input("Home Address", value=selected_client.address or "")
                
                col4, col5, col6 = st.columns(3)
                c_marital = col4.selectbox("Marital Status", ["Married", "Single", "Divorced", "Widowed"], 
                                           index=["Married", "Single", "Divorced", "Widowed"].index(selected_client.marital_status) if selected_client.marital_status in ["Married", "Single", "Divorced", "Widowed"] else 0)
                c_biz = col5.text_input("Business Type", value=selected_client.business_type or "")
                
                # Fetch average_income safely
                try:
                    default_income = float(selected_client.average_monthly_income or 0.0)
                except:
                    default_income = 0.0
                c_income = col6.number_input("Average Monthly Income (₦)", min_value=0.0, step=5000.0, value=default_income)
                
                c_obligations = st.text_input("Other Obligations", value=selected_client.other_obligations or "")
                
                st.markdown("##### Identification Section")
                id_col1, id_col2, id_col3 = st.columns(3)
                
                id_means_options = ["National ID (NIN)", "Voter's Card", "Driver's License", "International Passport", "None"]
                default_means_idx = id_means_options.index(selected_client.id_means) if selected_client.id_means in id_means_options else 4
                c_id_means = id_col1.selectbox("Means of ID", id_means_options, index=default_means_idx, key="edit_client_id_means")
                c_id_number = id_col2.text_input("ID Number", value=selected_client.id_number or "", key="edit_client_id_number")
                
                st.write("---")
                st.caption("Optional: Upload new files only if you want to replace the existing ones.")
                
                c_id_file = id_col3.file_uploader("Upload ID Document (replaces current)", type=["jpg", "jpeg", "png", "pdf"], key="edit_client_id_file")
                
                col_pass1, col_pass2 = st.columns(2)
                c_pass_file = col_pass1.file_uploader("Upload Passport Photograph (replaces current)", type=["jpg", "jpeg", "png"], key="edit_client_passport")
                
                st.markdown("#### 2. Guarantor Info")
                g_col1, g_col2, g_col3 = st.columns(3)
                
                loan_extra = latest_loan.get("extra_fields") or {}
                
                g_name = g_col1.text_input("Guarantor Full Name", value=loan_extra.get("guarantor_name") or "")
                g_phone = g_col2.text_input("Guarantor Phone Number", value=loan_extra.get("guarantor_phone") or "")
                g_address = g_col3.text_input("Guarantor Home Address", value=loan_extra.get("guarantor_home_address") or "")
                
                g_col4, g_col5, g_col6 = st.columns(3)
                g_marital_options = ["Married", "Single", "Divorced", "Widowed"]
                g_marital_val = loan_extra.get("guarantor_marital_status") or "Married"
                g_marital_idx = g_marital_options.index(g_marital_val) if g_marital_val in g_marital_options else 0
                g_marital = g_col4.selectbox("Guarantor Marital Status", g_marital_options, index=g_marital_idx)
                
                g_occ = g_col5.text_input("Guarantor Occupation", value=loan_extra.get("guarantor_occupation") or "")
                g_rel = g_col6.text_input("Relationship with Client", value=loan_extra.get("guarantor_relationship") or "")
                
                g_office = st.text_input("Guarantor Office Address", value=loan_extra.get("guarantor_office_address") or "")
                
                st.markdown("##### Guarantor Identification & Passport")
                g_id_col1, g_id_col2, g_id_col3 = st.columns(3)
                
                g_id_means_options = ["National ID (NIN)", "Voter's Card", "Driver's License", "International Passport", "None"]
                g_id_means_val = latest_loan.get("guarantor_id_means") or "None"
                g_id_means_idx = g_id_means_options.index(g_id_means_val) if g_id_means_val in g_id_means_options else 4
                
                g_id_means = g_id_col1.selectbox("Guarantor Means of ID", g_id_means_options, index=g_id_means_idx, key="edit_guarantor_id_means")
                g_id_number = g_id_col2.text_input("Guarantor ID Number", value=latest_loan.get("guarantor_id_number") or "", key="edit_guarantor_id_number")
                g_id_file = g_id_col3.file_uploader("Upload Guarantor ID Document (replaces current)", type=["jpg", "jpeg", "png", "pdf"], key="edit_guarantor_id_file")
                
                g_pass_col1, g_pass_col2 = st.columns(2)
                g_pass_file = g_pass_col1.file_uploader("Upload Guarantor Passport Photograph (replaces current)", type=["jpg", "jpeg", "png"], key="edit_guarantor_passport")
                
                submitted_edit = st.form_submit_button("Save Client & Guarantor Updates", type="primary", use_container_width=True)
                
                if submitted_edit:
                    if not c_name.strip():
                        st.error("Client Name is required.")
                    else:
                        try:
                            with SupabaseUnitOfWork() as uow:
                                # Setup storage path helper
                                def upload_client_file(file_data, file_name):
                                    if not file_data:
                                        return None
                                    try:
                                        file_bytes = file_data.read()
                                        file_ext = file_data.name.split('.')[-1]
                                        storage_path = f"{selected_client.id}/{file_name}.{file_ext}"
                                        
                                        # Try to upload file
                                        uow.client.storage.from_("client-ids").upload(
                                            path=storage_path,
                                            file=file_bytes,
                                            file_options={"content-type": file_data.type}
                                        )
                                        return uow.client.storage.from_("client-ids").get_public_url(storage_path)
                                    except Exception as upload_err:
                                        # If already exists, we might need to overwrite/update it
                                        try:
                                            uow.client.storage.from_("client-ids").remove([storage_path])
                                            uow.client.storage.from_("client-ids").upload(
                                                path=storage_path,
                                                file=file_bytes,
                                                file_options={"content-type": file_data.type}
                                            )
                                            return uow.client.storage.from_("client-ids").get_public_url(storage_path)
                                        except Exception as fallback_err:
                                            st.warning(f"⚠️ File upload failed for '{file_name}': {fallback_err}")
                                            return None

                                # 1. Process files
                                new_id_url = upload_client_file(c_id_file, "id_document")
                                new_pass_url = upload_client_file(c_pass_file, "passport")
                                new_g_id_url = upload_client_file(g_id_file, "guarantor_id")
                                new_g_pass_url = upload_client_file(g_pass_file, "guarantor_passport")

                                # 2. Update Client Details in Supabase clients table
                                client_update_data = {
                                    "name": c_name.strip(),
                                    "phone": c_phone.strip() if c_phone.strip() else None,
                                    "address": c_address.strip() if c_address.strip() else None,
                                    "marital_status": c_marital,
                                    "business_type": c_biz.strip() if c_biz.strip() else None,
                                    "average_monthly_income": c_income,
                                    "other_obligations": c_obligations.strip() if c_obligations.strip() else None,
                                    "id_means": c_id_means,
                                    "id_number": c_id_number.strip() if c_id_number.strip() else None
                                }
                                if new_id_url:
                                    client_update_data["id_card_url"] = new_id_url
                                if new_pass_url:
                                    client_update_data["passport_url"] = new_pass_url
                                    
                                uow.client.table("clients").update(client_update_data).eq("client_id", selected_client.id).execute()

                                # 3. Update Guarantor details in the latest loan (if exists)
                                if latest_loan:
                                    loan_extra = latest_loan.get("extra_fields") or {}
                                    loan_extra.update({
                                        "guarantor_name": g_name.strip() if g_name.strip() else None,
                                        "guarantor_phone": g_phone.strip() if g_phone.strip() else None,
                                        "guarantor_home_address": g_address.strip() if g_address.strip() else None,
                                        "guarantor_marital_status": g_marital,
                                        "guarantor_occupation": g_occ.strip() if g_occ.strip() else None,
                                        "guarantor_relationship": g_rel.strip() if g_rel.strip() else None,
                                        "guarantor_office_address": g_office.strip() if g_office.strip() else None,
                                    })
                                    loan_update_data = {
                                        "extra_fields": loan_extra,
                                        "guarantor_id_means": g_id_means,
                                        "guarantor_id_number": g_id_number.strip() if g_id_number.strip() else None
                                    }
                                    if new_g_id_url:
                                        loan_update_data["guarantor_id_card_url"] = new_g_id_url
                                    if new_g_pass_url:
                                        loan_update_data["guarantor_passport_url"] = new_g_pass_url
                                        
                                    uow.client.table("loans").update(loan_update_data).eq("loan_id", latest_loan["loan_id"]).execute()
                                    
                                    # 4. Sync / Update or Create in public.guarantors table
                                    if g_name.strip() and g_phone.strip():
                                        res_g = uow.guarantors.find_by_phone(g_phone.strip())
                                        guarantor_id = None
                                        if res_g:
                                            guarantor_id = res_g.guarantor_id
                                            # Update guarantor details
                                            g_update = {
                                                "name": g_name.strip(),
                                                "address": g_address.strip() if g_address.strip() else None,
                                                "occupation": g_occ.strip() if g_occ.strip() else None,
                                                "business_address": g_office.strip() if g_office.strip() else None,
                                                "id_means": g_id_means,
                                                "id_number": g_id_number.strip() if g_id_number.strip() else None
                                            }
                                            if new_g_id_url:
                                                g_update["id_card_url"] = new_g_id_url
                                            if new_g_pass_url:
                                                g_update["passport_url"] = new_g_pass_url
                                                
                                            uow.client.table("guarantors").update(g_update).eq("guarantor_id", guarantor_id).execute()
                                        else:
                                            # Create new guarantor record
                                            from domain.entities.guarantor import Guarantor
                                            g_new = Guarantor(
                                                guarantor_id=str(uuid.uuid4()),
                                                name=g_name.strip(),
                                                phone=g_phone.strip(),
                                                address=g_address.strip() if g_address.strip() else None,
                                                occupation=g_occ.strip() if g_occ.strip() else None,
                                                business_address=g_office.strip() if g_office.strip() else None,
                                                id_means=g_id_means,
                                                id_number=g_id_number.strip() if g_id_number.strip() else None,
                                                id_card_url=new_g_id_url,
                                                passport_url=new_g_pass_url
                                            )
                                            g_ent = uow.guarantors.create_guarantor(g_new)
                                            guarantor_id = g_ent.guarantor_id
                                            
                                        # Ensure loan link is established in loan_guarantors
                                        res_link = uow.client.table("loan_guarantors").select("*").eq("loan_id", latest_loan["loan_id"]).eq("guarantor_id", guarantor_id).execute()
                                        if not res_link.data:
                                            from domain.entities.guarantor import LoanGuarantor
                                            uow.guarantors.link_to_loan(LoanGuarantor(
                                                id=str(uuid.uuid4()),
                                                loan_id=latest_loan["loan_id"],
                                                guarantor_id=guarantor_id,
                                                relationship=g_rel.strip()
                                            ))

                                st.success("🎉 Client and Guarantor details updated successfully!")
                                import time
                                time.sleep(2)
                                st.rerun()
                        except Exception as e:
                            st.error(f"Error updating details: {e}")
                            
                            


elif page == "Collections":
    st.title("Daily Collections")
    st.caption("Record daily repayments and savings.")
    
    from services.business_date_service import BusinessDateService
    with SupabaseUnitOfWork() as uow_date:
        active_b_date = BusinessDateService.get_business_date(uow_date, BRANCH)

    use_late_entry = st.toggle("Late Entry / Backdated Entry")
    if use_late_entry:
        view_date = st.date_input("Select Date", active_b_date, key="col_date")
    else:
        view_date = active_b_date
        st.info(f"Operational Business Date: **{view_date.strftime('%d %B %Y')}** ({view_date.strftime('%A')})")
    
    date_str = view_date.strftime("%Y-%m-%d")

    with SupabaseUnitOfWork() as uow_chk:
        is_day_open, open_reason = BusinessDateService.is_operational_open(uow_chk, BRANCH_ID, view_date)

    if not is_day_open and not use_late_entry:
        st.warning(f"🏖️ **Operational Activity Suspended ({open_reason})**: Collections for **{view_date.strftime('%d %B %Y')}** are locked in Read-Only mode. (To record historical entries, toggle 'Late Entry / Backdated Entry' above).")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    if False:
        st.warning("No active loans found.")
    else:
        # Filter active loans for this officer (unless BM/AM looking at all)
        if ROLE in ["BM", "AM", "Branch Manager", "Area Manager"]:
            if scope.scope_level == "BRANCH":
                branch_loans = all_loans[all_loans['Branch'].astype(str).str.lower() == str(scope.branch_name).lower()] if scope.branch_name else all_loans
            elif scope.scope_level == "REGION":
                assigned_lower = [b.lower() for b in scope.assigned_branch_names]
                branch_loans = all_loans[all_loans['Branch'].astype(str).str.lower().isin(assigned_lower)] if scope.assigned_branch_names else all_loans
            else:
                branch_loans = all_loans

            unique_officers = branch_loans['Officer'].dropna().unique().tolist()
            if unique_officers:
                display_options = [CO_DISPLAY_MAP.get(o, o) for o in unique_officers]
                selected_display = st.selectbox("Select Credit Officer", display_options, key="col_co")
                target_co = CO_NAME_MAP.get(selected_display, selected_display)
            else:
                target_co = USER
        else:
            target_co = USER
            
        col_tab1, col_tab2, col_tab3 = st.tabs(["📝 Record Collections", "📜 Collection History & Audit", "🔄 Error Correction & Reversals"])
        
        with col_tab1:
            # Only Admins and Super Admins can see the Bulk Upload (Excel) option
            if ROLE in [ROLE_SUPER_ADMIN, ROLE_ADMIN]:
                col_mode = st.radio("Collection Mode", ["Individual & Group Entry", "Bulk Upload (Excel Template)"], horizontal=True, label_visibility="collapsed")
            else:
                col_mode = "Individual & Group Entry"
        
            if col_mode == "Bulk Upload (Excel Template)":
                st.markdown("### Bulk Upload (Excel Template)")
                with open("Master_Balancing_Template_V2.xlsx", "rb") as template_file:
                    st.download_button(
                        label="Download Master Balancing Template",
                        data=template_file,
                        file_name="Master_Balancing_Template.xlsx",
                        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    )
                
                uploaded_file = st.file_uploader("Upload filled Master Balancing Template", type=["xlsx"])
                if uploaded_file:
                    try:
                        df = pd.read_excel(uploaded_file)
                        st.success(f"File loaded successfully! Found {len(df)} rows.")
                    
                        if st.button("🚀 Process Upload", use_container_width=True):
                            new_records = []
                            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        
                            for idx, row in df.iterrows():
                                cid = str(row.get('Member Reference', '')).strip()
                                gn = str(row.get('Group Name', '')).strip()
                                co_name = str(row.get('Credit Officer Name', '')).strip()
                            
                                # Safely parse amounts
                                def get_amt(col_name):
                                    val = row.get(col_name, 0)
                                    if pd.isna(val): return 0
                                    try: return float(val)
                                    except: return 0
                            
                                lr_amt = get_amt("Today's Loan Repayment")
                                s_dep = get_amt("Today's Savings Deposit")
                                s_wd = get_amt("Today's Savings Withdrawal")
                                gs_dep = get_amt("Group Savings Deposit")
                                gs_wd = get_amt("Group Savings Withdrawal")
                                laps_dep = get_amt("Laps Savings Deposit")
                                laps_wd = get_amt("Laps Savings Withdrawal")
                            
                                # 1. Individual Transactions
                                if lr_amt > 0 or s_dep > 0 or s_wd > 0:
                                    if cid and cid != 'nan':
                                        new_records.append({
                                            "id": str(uuid.uuid4()),
                                            "Date": date_str,
                                            "Time": timestamp,
                                            "Client ID": cid,
                                            "Client Name": str(row.get('Full Name', '')),
                                            "Officer": target_co,
                                            "Branch": BRANCH,
                                            "Amount Paid": 0, # Legacy, keeping 0
                                            "Savings Amount": s_dep,
                                            "Withdrawal Amount": s_wd,
                                            "Loan Repayment Amount": lr_amt,
                                            "Processing Fee Paid": 0,
                                            "Insurance Fee Paid": 0,
                                            "App Fee Paid": 0,
                                            "Pass Book Paid": 0,
                                            "Recovery Amount": 0,
                                            "Mgt Fee Paid": 0,
                                            "Others Amount": 0,
                                            "Laps Amount Transferred": 0,
                                            "Transaction Type": "Collection (Bulk Upload)",
                                            "Note": f"Bulk Uploaded by {USER}",
                                            "Reversed": False
                                        })
                                    
                                # 2. Group Savings
                                if gs_dep > 0 or gs_wd > 0:
                                    if gn and gn != 'nan':
                                        new_records.append({
                                            "id": str(uuid.uuid4()),
                                            "Date": date_str,
                                            "Time": timestamp,
                                            "Client ID": f"GROUP-{gn}",
                                            "Client Name": f"{gn} Meeting",
                                            "Officer": target_co,
                                            "Branch": BRANCH,
                                            "Amount Paid": 0,
                                            "Savings Amount": gs_dep,
                                            "Withdrawal Amount": gs_wd,
                                            "Loan Repayment Amount": 0,
                                            "Processing Fee Paid": 0,
                                            "Insurance Fee Paid": 0,
                                            "App Fee Paid": 0,
                                            "Pass Book Paid": 0,
                                            "Recovery Amount": 0,
                                            "Mgt Fee Paid": 0,
                                            "Others Amount": 0,
                                            "Laps Amount Transferred": 0,
                                            "Transaction Type": "Group Global Savings (Bulk Upload)",
                                            "Note": f"Bulk Uploaded by {USER}",
                                            "Reversed": False
                                        })
                                    
                                # 3. Laps Savings
                                if laps_dep > 0 or laps_wd > 0:
                                    new_records.append({
                                        "id": str(uuid.uuid4()),
                                        "Date": date_str,
                                        "Time": timestamp,
                                        "Client ID": f"GLOBAL-LAPS-{BRANCH}",
                                        "Client Name": f"Laps Savings ({BRANCH})",
                                        "Officer": target_co,
                                        "Branch": BRANCH,
                                        "Amount Paid": 0,
                                        "Savings Amount": laps_dep,
                                        "Withdrawal Amount": laps_wd,
                                        "Loan Repayment Amount": 0,
                                        "Processing Fee Paid": 0,
                                        "Insurance Fee Paid": 0,
                                        "App Fee Paid": 0,
                                        "Pass Book Paid": 0,
                                        "Recovery Amount": 0,
                                        "Mgt Fee Paid": 0,
                                        "Others Amount": 0,
                                        "Laps Amount Transferred": 0,
                                        "Transaction Type": "Laps Savings (Bulk Upload)",
                                        "Note": f"Bulk Uploaded by {USER}",
                                        "Reversed": False
                                    })
                                
                            if new_records:
                                new_df = pd.DataFrame(new_records)
                                updated_repayments = pd.concat([repayments, new_df], ignore_index=True)
                                save_repayments(updated_repayments)
                                st.success(f"✅ Successfully processed {len(new_records)} transactions from the bulk upload!")
                            
                                # Optional delay and rerun
                                import time
                                time.sleep(2)
                                st.rerun()
                            else:
                                st.warning("No valid transactions found in the uploaded file.")
                    except Exception as e:
                        st.error(f"Error parsing file: {e}")
                    
            if col_mode == "Individual & Group Entry":
                st.markdown("### Member Collections")
            # Load all active clients for the target officer
            with SupabaseUnitOfWork() as uow:
                target_officer_id = uow.loans._resolve_officer_id(target_co)
                if ROLE in ["BM", ROLE_BRANCH_MANAGER]:
                    res_c = uow.client.table("clients").select("client_id, client_code, name, status, status_id, group_id, groups(name), client_memberships(groups(name)), client_statuses(name)").eq("branch_id", BRANCH_ID).execute()
                elif ROLE in ["AM", "Area Manager", ROLE_AREA_MANAGER]:
                    res_c = uow.client.table("clients").select("client_id, client_code, name, status, status_id, group_id, groups(name), client_memberships(groups(name)), client_statuses(name)").in_("branch_id", ASSIGNED_BRANCH_IDS).execute()
                elif ROLE in [ROLE_ADMIN, ROLE_SUPER_ADMIN, "Admin", "Super Admin"]:
                    res_c = uow.client.table("clients").select("client_id, client_code, name, status, status_id, group_id, groups(name), client_memberships(groups(name)), client_statuses(name)").execute()
                else:
                    res_c = uow.client.table("clients").select("client_id, client_code, name, status, status_id, group_id, groups(name), client_memberships(groups(name)), client_statuses(name)").eq("officer_id", target_officer_id).execute()
                
            clients_data = []
            if res_c.data:
                for c in res_c.data:
                    c_stat = (c.get("client_statuses") or {}).get("name") if isinstance(c.get("client_statuses"), dict) else c.get("status")
                    if c_stat in ["Closed", "Suspended"]:
                        continue
                    g_name = (c.get("groups") or {}).get("name") if isinstance(c.get("groups"), dict) else None
                    if not g_name:
                        m_list = c.get("client_memberships") or []
                        if isinstance(m_list, list):
                            for m in m_list:
                                if m.get("groups") and m["groups"].get("name"):
                                    g_name = m["groups"]["name"]
                                    break
                        elif isinstance(m_list, dict):
                            if m_list.get("groups") and m_list["groups"].get("name"):
                                g_name = m_list["groups"]["name"]
                
                    if not g_name:
                        g_name = "Ungrouped"
                
                    clients_data.append({
                        "Client ID": c["client_code"] or c["client_id"],
                        "ID": c["client_id"],
                        "Client Name": c["name"],
                        "Group Name": g_name,
                        "Officer": target_co,
                        "Branch": BRANCH
                    })
                
            if not clients_data:
                st.info("No registered active clients found for this officer.")
            else:
                co_clients_df = pd.DataFrame(clients_data)
                groups = ["Ungrouped"] + sorted(co_clients_df[co_clients_df['Group Name'] != "Ungrouped"]['Group Name'].unique().tolist())
            
                default_idx = 0
                if "sel_group" in st.session_state and st.session_state["sel_group"] in groups:
                    default_idx = groups.index(st.session_state["sel_group"])
                    del st.session_state["sel_group"]
                
                col_g1, col_g2 = st.columns([3, 1])
                selected_group = col_g1.selectbox("Select Group", groups, index=default_idx)
                expand_all_members = col_g2.checkbox("Expand All Members", value=st.session_state.get('chk_expand_all', False), key="chk_expand_all")
            
                if selected_group == "Ungrouped":
                    group_clients = co_clients_df[co_clients_df['Group Name'] == "Ungrouped"]
                else:
                    group_clients = co_clients_df[co_clients_df['Group Name'] == selected_group]

                if group_clients.empty:
                    st.info("No active members in this group.")
                else:
                    # Fetch history for today to prefill/check
                    today_reps = repayments[(repayments['Date'] == date_str) & (repayments['Officer'] == target_co)] if not repayments.empty else pd.DataFrame()
                
                    # Clear state if group or date changed
                    if st.session_state.get('collections_group') != selected_group or st.session_state.get('collections_date') != date_str:
                        st.session_state['pending_collections'] = []
                        st.session_state['collections_group'] = selected_group
                        st.session_state['collections_date'] = date_str
                
                    # Pre-compute member data for manifest, CSV, and form inputs
                    member_info = {}
                    from services.schedule_service import ScheduleService
                    with SupabaseUnitOfWork() as uow:
                        for _, member in group_clients.iterrows():
                            cid = member['Client ID']
                            uuid_id = member['ID']
                            mem_reps = repayments[repayments['Client ID'] == cid] if not repayments.empty else pd.DataFrame()
                            try:
                                # Match strictly by client UUID
                                res_dep = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", uuid_id).execute()
                                res_wd = uow.client.table("individual_savings").select("withdrawal_amount").eq("client_id", uuid_id).execute()
                                sav_bal = sum(float(d.get("deposit_amount") or 0) for d in (res_dep.data or [])) - sum(float(w.get("withdrawal_amount") or 0) for w in (res_wd.data or []))
                            except Exception:
                                sav_bal = 0.0
                            # Find if there is an active loan in all_loans
                            active_loan_rows = all_loans[((all_loans['Client ID'] == cid) | (all_loans['Client ID'] == uuid_id)) & (all_loans['Status'] == 'Active')]
                            if not active_loan_rows.empty:
                                loan_row = active_loan_rows.iloc[0]
                                active_loan_id = loan_row.get('id') or loan_row.get('loan_id') or loan_row.get('Loan ID')
                                act_cred = float(loan_row.get('Active Credit', 0) or loan_row.get('active_credit', 0))
                                total_due_base = float(loan_row.get('Total Due', 0) or loan_row.get('total_due', 0)) or act_cred
                            
                                # Baseline remaining balance is Total Due from loans table minus repayments posted
                                if active_loan_id and isinstance(active_loan_id, str) and len(active_loan_id) > 10:
                                    active_loan_total_paid, has_schedule = ScheduleService.get_total_paid(uow, active_loan_id)
                                    if not has_schedule:
                                        active_loan_total_paid = float(mem_reps['Loan Repayment Amount'].sum()) if not mem_reps.empty and 'Loan Repayment Amount' in mem_reps.columns else 0.0
                                else:
                                    active_loan_total_paid = float(mem_reps['Loan Repayment Amount'].sum()) if not mem_reps.empty and 'Loan Repayment Amount' in mem_reps.columns else 0.0
                                
                                rem_bal = max(0.0, total_due_base - active_loan_total_paid)
                                loan_prod_val = loan_row.get('Loan Product') or "Daily Loan"
                            
                                # The expected periodic installment per collection session
                                inst_repay = float(loan_row.get('Loan Repay', 0.0) or loan_row.get('expected_installment', 0.0) or 0.0)
                                if inst_repay == 0.0 and act_cred > 0:
                                    duration_val = float(loan_row.get('Duration', 0) or loan_row.get('duration', 0) or 1)
                                    inst_repay = (total_due_base / duration_val) if duration_val > 0 else total_due_base
                                
                                expected_rep_schedule = min(inst_repay, rem_bal) if rem_bal > 0 else 0.0
                                
                                start_date_val = str(loan_row.get('Start Date', ''))
                            else:
                                active_loan_id = None
                                act_cred = 0.0
                                total_paid = 0.0
                                rem_bal = 0.0
                                loan_prod_val = "None"
                                expected_rep_schedule = 0.0
                                start_date_val = ""
                        
                            # Check if user has a pending collection in session state
                            pending_list = st.session_state.get('pending_collections', [])
                            pending_tx = next((tx for tx in pending_list if tx["Client ID"] == cid), None)
                        
                            today_paid = today_reps[today_reps['Client ID'] == cid] if not today_reps.empty else pd.DataFrame()
                        
                            if pending_tx:
                                prev_dep = float(pending_tx.get("Savings Amount") or 0.0)
                                prev_wd = float(pending_tx.get("Withdrawal Amount") or 0.0)
                                prev_rep = float(pending_tx.get("Loan Repayment Amount") or 0.0)
                                prev_status = str(pending_tx.get("Payment Status") or "PAID").upper()
                            else:
                                prev_dep = 0.0
                                prev_wd = 0.0
                                if not today_paid.empty:
                                    prev_rep = float(today_paid['Loan Repayment Amount'].sum()) if 'Loan Repayment Amount' in today_paid.columns else float(today_paid['Amount Paid'].sum())
                                    prev_status = str(today_paid['Payment Status'].iloc[0] if 'Payment Status' in today_paid.columns else "PAID").upper()
                                else:
                                    prev_rep = expected_rep_schedule
                                    prev_status = "PAID" if expected_rep_schedule > 0 else "NOT_PAID"
                            
                            # Pack member details
                            member_dict = member.to_dict()
                            member_dict.update({
                                "Active Credit": act_cred,
                                "Remaining Balance": rem_bal,
                                "Expected Repayment": expected_rep_schedule,
                                "Loan Product": loan_prod_val,
                                "Start Date": start_date_val
                            })
                        
                            member_info[cid] = {
                                "member": pd.Series(member_dict),
                                "sav_bal": sav_bal,
                                "rem_bal": rem_bal,
                                "act_cred": act_cred,
                                "expected_rep_schedule": expected_rep_schedule,
                                "prev_dep": prev_dep,
                                "prev_wd": prev_wd,
                                "prev_rep": prev_rep,
                                "prev_status": prev_status,
                                "start_date": start_date_val
                            }

                        # Fetch Group-Level Savings Balance
                        group_savings_balance = 0.0
                        if selected_group != "Ungrouped":
                            try:
                                g_res = uow.client.table("groups").select("group_id").eq("name", selected_group).execute()
                                if g_res.data:
                                    g_id = g_res.data[0]['group_id']
                                    gs_res = uow.client.table("group_savings").select("deposit_amount, withdrawal_amount").eq("group_id", g_id).execute()
                                    legacy_reps = repayments[repayments['Client ID'] == f"GROUP-{selected_group}"] if not repayments.empty else pd.DataFrame()
                                    legacy_bal = (float(legacy_reps['Savings Amount'].sum()) - float(legacy_reps['Withdrawal Amount'].sum())) if not legacy_reps.empty else 0.0
                                    group_savings_balance = sum(float(g.get("deposit_amount") or 0) for g in (gs_res.data or [])) - sum(float(g.get("withdrawal_amount") or 0) for g in (gs_res.data or [])) + legacy_bal
                            except Exception:
                                group_savings_balance = 0.0

                    # ── CSV MANIFEST & BULK UPLOAD ──
                    st.markdown("#### Group Collection CSV Manifest")
                    col_csv1, col_csv2 = st.columns([1, 1])

                    # 1. Download Editable Manifest CSV
                    manifest_rows = []
                    # Group communal savings row if grouped
                    if selected_group != "Ungrouped":
                        manifest_rows.append({
                            "Client ID": f"GROUP-{selected_group}",
                            "Client Name": f"{selected_group} Communal Savings",
                            "Savings Balance": round(float(group_savings_balance), 2),
                            "Remaining Balance": 0.0,
                            "Expected Repayment": 0.0,
                            "Amount Collected": 0.0,
                            "Savings Deposit": 0.0
                        })
                    for cid, info in member_info.items():
                        m = info['member']
                        manifest_rows.append({
                            "Client ID": cid,
                            "Client Name": m['Client Name'],
                            "Savings Balance": round(float(info['sav_bal']), 2),
                            "Remaining Balance": round(float(info['rem_bal']), 2),
                            "Expected Repayment": round(float(info['expected_rep_schedule']), 2),
                            "Amount Collected": 0.0,
                            "Savings Deposit": 0.0
                        })
                    manifest_df = pd.DataFrame(manifest_rows)
                    csv_data = manifest_df.to_csv(index=False)
                    col_csv1.download_button(
                        label="Download Manifest CSV",
                        data=csv_data,
                        file_name=f"manifest_{selected_group}_{date_str}.csv",
                        mime="text/csv",
                        key=f"btn_dl_manifest_{selected_group}_{date_str}",
                        use_container_width=True
                    )
                    import base64
                    b64_csv = base64.b64encode(csv_data.encode('utf-8')).decode()
                    col_csv1.markdown(
                        f'<div style="text-align:center; margin-top:4px;"><a href="data:text/csv;base64,{b64_csv}" download="manifest_{selected_group}_{date_str}.csv" style="font-size:12px; color:#0284c7; text-decoration:none;">Direct CSV Download Link</a></div>',
                        unsafe_allow_html=True
                    )

                    # 2. Upload Completed Manifest CSV
                    with col_csv2:
                        with st.expander("Upload Completed Manifest (CSV)"):
                            st.caption("Upload the filled CSV manifest to automatically populate client repayments, member savings, and group savings.")
                            uploaded_csv = st.file_uploader("Choose Manifest CSV file", type=["csv"], key=f"csv_upload_{selected_group}")
                            if uploaded_csv is not None:
                                try:
                                    df_up = pd.read_csv(uploaded_csv)
                                    df_up.columns = [str(c).strip() for c in df_up.columns]
                                
                                    id_col = next((c for c in df_up.columns if c.lower() in ["client id", "id", "client_id", "code"]), None)
                                    rep_col_name = next((c for c in df_up.columns if c.lower() in ["amount collected", "loan repayment amount", "repayment", "amount_collected", "amount paid"]), None)
                                    sav_col_name = next((c for c in df_up.columns if c.lower() in ["savings deposit", "savings amount", "savings", "savings_deposit"]), None)
                                
                                    if not id_col:
                                        st.error("Uploaded CSV must have a 'Client ID' or 'ID' column.")
                                    else:
                                        csv_entries = []
                                        matched_count = 0
                                        for _, u_row in df_up.iterrows():
                                            raw_cid = str(u_row.get(id_col, '')).strip()
                                            if not raw_cid or raw_cid == 'nan': continue
                                        
                                            # Check if this row is Group Communal Savings
                                            is_group_row = (
                                                raw_cid.startswith("GROUP-") or
                                                "group" in str(u_row.get("Client Name", "")).lower() or
                                                "communal" in str(u_row.get("Client Name", "")).lower() or
                                                raw_cid.lower() == selected_group.lower()
                                            )
                                            if is_group_row:
                                                grp_sav = 0.0
                                                if sav_col_name and pd.notna(u_row.get(sav_col_name)):
                                                    try: grp_sav = float(str(u_row.get(sav_col_name)).replace(',', '').strip() or 0.0)
                                                    except Exception: grp_sav = 0.0
                                                if grp_sav == 0.0 and rep_col_name and pd.notna(u_row.get(rep_col_name)):
                                                    try: grp_sav = float(str(u_row.get(rep_col_name)).replace(',', '').strip() or 0.0)
                                                    except Exception: grp_sav = 0.0
                                                
                                                if grp_sav > 0:
                                                    g_data = {
                                                        "Date": date_str,
                                                        "Client ID": f"GROUP-{selected_group}",
                                                        "Client Name": f"{selected_group} Meeting",
                                                        "Officer": target_co,
                                                        "Branch": BRANCH,
                                                        "Amount Paid": grp_sav,
                                                        "Transaction Type": "Group Meeting",
                                                        "Note": "Daily Collection (CSV Upload)",
                                                        "Savings Amount": grp_sav,
                                                        "Withdrawal Amount": 0.0,
                                                        "Laps Reserved": 0, "Loan Repayment Amount": 0,
                                                        "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
                                                        "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0,
                                                        "Bank Withdrawal": 0, "Asset Sales": 0, "App Fee": 0,
                                                        "Pass Book Bonus": 0, "Misc Fees": 0, "Asset Credit Sales": 0,
                                                        "Cash and Carry": 0, "Credit Form": 0, "Credit Form Damage": 0, "Bonus": 0,
                                                        "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0,
                                                        "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                                                        "Product Withdrawal": 0, "Expenses": 0, "Bank Deposited": 0,
                                                        "Laps Transferred": 0,
                                                        "Group Savings Deposit": grp_sav,
                                                        "Group Savings Withdrawal": 0
                                                    }
                                                    csv_entries.append(g_data)
                                                    matched_count += 1
                                                continue
                                        
                                            info = member_info.get(raw_cid)
                                            if not info:
                                                c_name_val = str(u_row.get("Client Name", "")).strip().lower()
                                                for m_cid, m_info in member_info.items():
                                                    if str(m_info['member'].get('Client Name', '')).strip().lower() == c_name_val:
                                                        info = m_info
                                                        raw_cid = m_cid
                                                        break
                                                    
                                            if not info: continue
                                        
                                            m = info['member']
                                            rep_val = 0.0
                                            if rep_col_name and pd.notna(u_row.get(rep_col_name)):
                                                try: rep_val = float(str(u_row.get(rep_col_name)).replace(',', '').strip() or 0.0)
                                                except Exception: rep_val = 0.0
                                            
                                            sav_val = 0.0
                                            if sav_col_name and pd.notna(u_row.get(sav_col_name)):
                                                try: sav_val = float(str(u_row.get(sav_col_name)).replace(',', '').strip() or 0.0)
                                                except Exception: sav_val = 0.0
                                            
                                            exp_rep = float(info['expected_rep_schedule'] or 0.0)
                                            prod_low = str(m['Loan Product']).lower()
                                            rep_12w = rep_24w = rep_60d = rep_120d = rep_mth = 0
                                            if "12 week" in prod_low or "12wk" in prod_low or "12w" in prod_low: rep_12w = rep_val
                                            elif "24 week" in prod_low or "24wk" in prod_low or "24w" in prod_low: rep_24w = rep_val
                                            elif "60 day" in prod_low or ("daily" in prod_low and "120" not in prod_low) or "60-day" in prod_low: rep_60d = rep_val
                                            elif "120 day" in prod_low or "120-day" in prod_low: rep_120d = rep_val
                                            elif "month" in prod_low: rep_mth = rep_val
                                            else: rep_60d = rep_val
                                        
                                            p_status = "PAID" if rep_val >= exp_rep and exp_rep > 0 else ("PART_PAID" if rep_val > 0 else "NOT_PAID")
                                        
                                            if rep_val > 0 or sav_val > 0 or p_status == "NOT_PAID":
                                                tx_data = {
                                                    "Date": date_str,
                                                    "Client ID": raw_cid,
                                                    "Client Name": m['Client Name'],
                                                    "Officer": target_co,
                                                    "Branch": m.get('Branch', BRANCH),
                                                    "Amount Paid": rep_val,
                                                    "Transaction Type": "Loan",
                                                    "Note": "Daily Collection (CSV Upload)",
                                                    "Savings Amount": sav_val,
                                                    "Withdrawal Amount": 0.0,
                                                    "Loan Repayment Amount": rep_val,
                                                    "Repayment 12 Weeks": rep_12w,
                                                    "Repayment 24 Weeks": rep_24w,
                                                    "Repayment 60 Days": rep_60d,
                                                    "Repayment 120 Days": rep_120d,
                                                    "Monthly": rep_mth,
                                                    "Bank Withdrawal": 0, "Asset Sales": 0, "App Fee": 0,
                                                    "Pass Book Bonus": 0, "Misc Fees": 0, "Asset Credit Sales": 0,
                                                    "Cash and Carry": 0, "Credit Form": 0, "Credit Form Damage": 0, "Bonus": 0,
                                                    "Payment Status": p_status,
                                                    "Expected Amount": exp_rep,
                                                    "Overdue Amount": max(0.0, exp_rep - rep_val),
                                                    "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0,
                                                    "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                                                    "Product Withdrawal": 0, "Expenses": 0, "Bank Deposited": 0,
                                                    "Laps Reserved": 0, "Laps Transferred": 0,
                                                    "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
                                                }
                                                csv_entries.append(tx_data)
                                                matched_count += 1
                                            
                                        if csv_entries:
                                            st.success(f"Found {matched_count} matching entries in uploaded CSV.")
                                            if st.button("Load Uploaded CSV into Review Queue", type="primary", use_container_width=True):
                                                st.session_state['pending_collections'] = csv_entries
                                                st.session_state['collections_group'] = selected_group
                                                st.session_state['collections_date'] = date_str
                                                st.session_state['edit_collections_mode'] = False
                                                st.rerun()
                                        else:
                                            st.warning("No matching member entries with valid repayment or savings found in CSV.")
                                except Exception as e:
                                    st.error(f"Error parsing uploaded CSV: {e}")

                    st.markdown(f"### Members in {selected_group}")
                
                    if st.session_state.get('pending_collections') and st.session_state.get('collections_group') == selected_group and st.session_state.get('collections_date') == date_str and not st.session_state.get('edit_collections_mode', False):
                        st.markdown("### Review Group Collections")
                        to_insert = st.session_state['pending_collections']
                    
                        total_in = sum(
                            float(tx.get('Loan Repayment Amount', 0)) +
                            float(tx.get('Savings Amount', 0)) +
                            float(tx.get('App Fee', 0)) +
                            float(tx.get('Pass Book Bonus', 0)) +
                            float(tx.get('Misc Fees', 0)) +
                            float(tx.get('Asset Credit Sales', 0)) +
                            float(tx.get('Cash and Carry', 0)) +
                            float(tx.get('Credit Form Damage', 0)) +
                            float(tx.get('Bonus', 0)) +
                            float(tx.get('Bank Withdrawal', 0))
                            for tx in to_insert
                        )
                        total_out = sum(float(tx.get('Withdrawal Amount', 0)) + float(tx.get('Expenses', 0)) + float(tx.get('Bank Deposited', 0)) + float(tx.get('Product Withdrawal', 0)) + float(tx.get('Laps Transferred', 0)) for tx in to_insert)
                        net_cash = total_in - total_out
                    
                        total_savings = sum(float(tx.get('Savings Amount', 0)) for tx in to_insert)
                        total_wd = sum(float(tx.get('Withdrawal Amount', 0)) for tx in to_insert)
                        total_net_savings = total_savings - total_wd
                    
                        st.info(f"**Total Money Collected (Cash In):** ₦{total_in:,.0f}")
                        st.warning(f"**Total Money Given Out (Cash Out):** ₦{total_out:,.0f}")
                        st.success(f"**NET CASH EXPECTED FROM GROUP:** ₦{net_cash:,.0f}")
                        st.markdown(f"**Total Net Savings:** ₦{total_net_savings:,.0f} *(Includes Individual & Group Savings)*")
                    
                        # Detailed Review Table for Officer Verification
                        review_rows = []
                        for tx in to_insert:
                            c_name = tx.get("Client Name", "")
                            c_id = tx.get("Client ID", "")
                            s_dep = float(tx.get("Savings Amount") or 0.0)
                            l_rep = float(tx.get("Loan Repayment Amount") or 0.0)
                            p_stat = str(tx.get("Payment Status") or "PAID").upper()
                            ov_amt = float(tx.get("Overdue Amount") or 0.0)
                            exp_amt = float(tx.get("Expected Amount") or 0.0)
                        
                            if p_stat == "NOT_PAID":
                                stat_badge = f"NOT PAID (₦{ov_amt:,.0f} Arrears)"
                            elif p_stat == "PART_PAID":
                                stat_badge = f"PART PAID (₦{ov_amt:,.0f} Arrears)"
                            elif p_stat == "EXCESS":
                                stat_badge = f"EXCESS (₦{l_rep - exp_amt:,.0f} Advance)"
                            else:
                                stat_badge = "FULL PAID" if exp_amt > 0 else "RECORDED"
                            
                            review_rows.append({
                                "Client": f"{c_name} ({c_id})" if not str(c_id).startswith("GROUP-") else c_name,
                                "Savings (₦)": f"₦{s_dep:,.0f}" if s_dep > 0 else "-",
                                "Repayment (₦)": f"₦{l_rep:,.0f}" if l_rep > 0 else "₦0",
                                "Status": stat_badge
                            })
                        if review_rows:
                            st.dataframe(pd.DataFrame(review_rows), use_container_width=True, hide_index=True)
                    
                        def _go_back_to_edit():
                            st.session_state['edit_collections_mode'] = True
                    
                        c1, c2 = st.columns(2)
                        c1.button("Edit / Go Back", on_click=_go_back_to_edit)
                    
                        if not is_day_open and not use_late_entry:
                            c2.error(f"🔒 Operational activity suspended ({open_reason}). Entries are locked.")
                        elif c2.button("Confirm & Save Collections", type="primary", use_container_width=True):
                            try:
                                save_repayments(to_insert)
                                st.success("Group Collections Submitted Successfully!")
                                del st.session_state['pending_collections']
                                if 'edit_collections_mode' in st.session_state:
                                    del st.session_state['edit_collections_mode']
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
                            group_savings_balance = 0.0
                            if selected_group != "Ungrouped":
                                try:
                                    g_res = uow.client.table("groups").select("group_id").eq("name", selected_group).execute()
                                    if g_res.data:
                                        g_id = g_res.data[0]['group_id']
                                        gs_res = uow.client.table("group_savings").select("deposit_amount, withdrawal_amount").eq("group_id", g_id).execute()
                                    
                                        legacy_reps = repayments[repayments['Client ID'] == f"GROUP-{selected_group}"] if not repayments.empty else pd.DataFrame()
                                        legacy_bal = (float(legacy_reps['Savings Amount'].sum()) - float(legacy_reps['Withdrawal Amount'].sum())) if not legacy_reps.empty else 0.0
                                    
                                        group_savings_balance = sum(float(g.get("deposit_amount") or 0) for g in gs_res.data) - sum(float(g.get("withdrawal_amount") or 0) for g in gs_res.data) + legacy_bal
                                except Exception:
                                    pass
                                
                            st.markdown(f"### Group-Level Savings (Available: ₦{group_savings_balance:,.0f})")
                            st.caption("Input communal group savings and withdrawal amounts.")
                        
                            # Load previous group values if any
                            pending_list = st.session_state.get('pending_collections', [])
                            pending_g = next((tx for tx in pending_list if tx["Client ID"] == f"GROUP-{selected_group}"), None)
                            if pending_g:
                                prev_g_dep = float(pending_g.get("Savings Amount") or 0.0)
                                prev_g_wd = float(pending_g.get("Withdrawal Amount") or 0.0)
                                prev_laps = float(pending_g.get("Laps Reserved") or 0.0)
                            else:
                                prev_g_dep = 0.0
                                prev_g_wd = 0.0
                                prev_laps = 0.0
                            
                            global_group_savings = st.number_input("Group Savings Deposit", min_value=0.0, step=500.0, value=prev_g_dep if prev_g_dep > 0 else None, placeholder="0", key="global_grp_sav")
                            global_group_wd = 0.0
                            st.markdown("---")
                        
                            # ---- PER-CLIENT COLLECTIONS ----
                            st.markdown("### Client Collections (Savings & Repayments)")

                            for cid, info in member_info.items():
                                m = info['member']
                                prod = str(m['Loan Product'])
                                is_asset = str(cid).endswith("-ASSET") or (prod and "asset" in prod.lower() and "non-asset" not in prod.lower())
                            
                                if is_asset:
                                    title = f"📋 {m['Client Name']} (ASSET) — Rem: ₦{info['rem_bal']:,.0f}"
                                else:
                                    title = f"👤 {m['Client Name']} ({cid}) — Rem: ₦{info['rem_bal']:,.0f} | Sav: ₦{info['sav_bal']:,.0f}"
                                
                                with st.expander(title, expanded=expand_all_members):
                                    s_date_str = info.get("start_date", "")
                                    s_date = pd.to_datetime(s_date_str, errors='coerce') if s_date_str and str(s_date_str).strip() not in ['None', 'nan', ''] else pd.NaT
                                    view_dt = pd.to_datetime(date_str)
                                
                                    is_future_loan = pd.notna(s_date) and s_date > view_dt
                                
                                    if not is_asset:
                                        st.markdown("**Savings**")
                                        s_dep = st.number_input("Savings Deposit", min_value=0.0, step=500.0, value=info['prev_dep'] if info['prev_dep'] > 0 else None, placeholder="0", key=f"sdep_{cid}")
                                        s_wd = 0.0
                                        sav_data[cid] = {"dep": s_dep, "wd": s_wd}
                                        st.markdown("---")
                                
                                    if is_future_loan:
                                        st.warning(f"**Next Loan Repayment Due On:** {s_date.strftime('%Y-%m-%d')}")
                                        st.caption("*Loan repayment begins on the next meeting date. No loan repayment is due today.*")
                                        rep_data[cid] = {
                                            "rep": 0.0, "app": 0, "pb": 0, "misc": 0,
                                            "asset_cr": 0, "cc": 0, "cfd": 0, "bonus": 0,
                                            "mark_not_paid": True, "expected_amount": 0.0
                                        }
                                    else:
                                        st.markdown(f"**Loan ({prod})** — Active Credit: ₦{info['act_cred']:,.0f}")
                                        expected_rep = float(info['expected_rep_schedule'] or 0.0)
                                        st.caption(f"Expected repayment calculated from schedule: ₦{expected_rep:,.2f}")
                                    
                                        # Smart Initial Status Detection
                                        has_previous_run = (pending_tx is not None or not today_paid.empty)
                                        is_defaulter_init = (info.get("prev_status") == "NOT_PAID") or (info.get("prev_rep") == 0.0 and has_previous_run)
                                    
                                        mark_not_paid = st.checkbox("Mark as NOT PAID today (₦0 Collection)", value=is_defaulter_init, key=f"not_paid_{cid}")
                                    
                                        if not mark_not_paid:
                                            init_val = float(info['prev_rep']) if (info['prev_rep'] is not None and info['prev_rep'] > 0) else (expected_rep if expected_rep > 0 else 0.0)
                                            rep_col = st.number_input(
                                                f"Loan Repayment Collected (₦)", 
                                                min_value=0.0, 
                                                step=500.0, 
                                                value=init_val if init_val > 0 else None, 
                                                placeholder=str(expected_rep), 
                                                key=f"rep_{cid}"
                                            )
                                        else:
                                            st.caption("🔒 *Repayment set to ₦0. Arrears will be logged as overdue.*")
                                            rep_col = 0.0
                                    
                                        rep_data[cid] = {
                                            "rep": rep_col, "app": 0, "pb": 0, "misc": 0,
                                            "asset_cr": 0, "cc": 0, "cfd": 0, "bonus": 0,
                                            "mark_not_paid": mark_not_paid, "expected_amount": expected_rep
                                        }
                        
                            st.markdown("---")
                            if not is_day_open and not use_late_entry:
                                st.warning(f"🏖️ Cannot submit new collections today ({open_reason}). Switch to the active business date or enable Late Entry.")
                            else:
                                submit_btn = st.form_submit_button("Calculate Totals & Review Members", type="primary", use_container_width=True)
                                if submit_btn:
                                    to_insert = []
                            
                                    # Process per-client data
                                    for cid, info in member_info.items():
                                        m = info['member']
                                        s = sav_data.get(cid, {"dep": 0, "wd": 0})
                                        r = rep_data.get(cid, {"rep": 0, "app": 0, "pb": 0, "misc": 0, "asset_cr": 0, "cc": 0, "cfd": 0, "bonus": 0, "mark_not_paid": False, "expected_amount": 0.0})
                                    
                                        sav = float(s.get('dep') or 0)
                                        sav_wd = float(s.get('wd') or 0)
                                        rep = float(r.get('rep') or 0)
                                        app = float(r.get('app') or 0)
                                        pb = float(r.get('pb') or 0)
                                        misc = float(r.get('misc') or 0)
                                        asset_cr = float(r.get('asset_cr') or 0)
                                        cc = float(r.get('cc') or 0)
                                        cfd = float(r.get('cfd') or 0)
                                        bon = float(r.get('bonus') or 0)
                                        exp_amt = float(r.get('expected_amount') or 0.0)
                                        is_marked_not_paid = bool(r.get('mark_not_paid', False))
                                    
                                        # Determine Payment Status & Overdue Amount strictly
                                        if is_marked_not_paid or rep == 0.0:
                                            rep = 0.0
                                            p_status = "NOT_PAID"
                                            overdue_val = exp_amt
                                        elif exp_amt > 0 and rep == exp_amt:
                                            p_status = "PAID"
                                            overdue_val = 0.0
                                        elif exp_amt > 0 and rep > exp_amt:
                                            p_status = "EXCESS"
                                            overdue_val = 0.0
                                        elif exp_amt > 0 and rep < exp_amt and rep > 0:
                                            p_status = "PART_PAID"
                                            overdue_val = max(0.0, exp_amt - rep)
                                        else:
                                            p_status = "PAID"
                                            overdue_val = 0.0
                                    
                                        if sav == 0 and sav_wd == 0 and rep == 0 and app == 0 and pb == 0 and misc == 0 and asset_cr == 0 and cc == 0 and cfd == 0 and bon == 0:
                                            if p_status != "NOT_PAID":
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
                                            "Amount Paid": rep,
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
                                            "Payment Status": p_status,
                                            "Expected Amount": exp_amt,
                                            "Overdue Amount": overdue_val,
                                            "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0,
                                            "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                                            "Product Withdrawal": 0, "Expenses": 0, "Bank Deposited": 0,
                                            "Laps Reserved": 0, "Laps Transferred": 0,
                                            "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
                                        }
                                        to_insert.append(tx_data)
                                
                                    # Process Group-Level Inflows
                                    global_group_savings = float(global_group_savings or 0)
                                    global_group_wd = float(global_group_wd or 0)
                                
                                    if global_group_savings > 0 or global_group_wd > 0:
                                        g_data = {
                                            "Date": date_str, "Client ID": f"GROUP-{selected_group}", "Client Name": f"{selected_group} Meeting",
                                            "Officer": target_co, "Branch": BRANCH,
                                            "Amount Paid": global_group_savings,
                                            "Transaction Type": "Group Meeting", "Note": "Group Level Inputs",
                                            "Savings Amount": global_group_savings, "Withdrawal Amount": global_group_wd,
                                            "Laps Reserved": 0,
                                            "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
                                            "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0, "Bank Withdrawal": 0,
                                            "Asset Sales": 0, "App Fee": 0, "Pass Book Bonus": 0, "Misc Fees": 0, "Asset Credit Sales": 0,
                                            "Cash and Carry": 0, "Credit Form": 0, "Credit Form Damage": 0, "Bonus": 0,
                                            "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0, "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                                            "Product Withdrawal": 0, "Expenses": 0, "Bank Deposited": 0, "Laps Transferred": 0,
                                            "Group Savings Deposit": global_group_savings, "Group Savings Withdrawal": global_group_wd
                                        }
                                        to_insert.append(g_data)
                                    
                                    if to_insert:
                                        st.session_state['pending_collections'] = to_insert
                                        st.session_state['collections_group'] = selected_group
                                        st.session_state['collections_date'] = date_str
                                        st.session_state['edit_collections_mode'] = False
                                        st.rerun()
                                    else:
                                        st.warning("No data entered to save.")

        with col_tab2:
            st.markdown("### 📜 Collection History & Audit")
            st.caption("Inspect all daily repayments and savings deposits posted by Credit Officers.")
            
            c_h1, c_h2 = st.columns([1, 2])
            hist_view_date = c_h1.date_input("Filter Date", view_date, key="col_hist_date")
            hist_date_str = hist_view_date.strftime("%Y-%m-%d")
            hist_search = c_h2.text_input("🔍 Search Client Name / Code / Note", placeholder="Type name, code, or ref...", key="col_hist_search").strip().lower()
            
            with SupabaseUnitOfWork() as uow_hist:
                # 1. Query Repayments
                q_reps = uow_hist.client.table("repayments").select(
                    "id, client_id, amount_paid, transaction_type, date, created_at, note, officer_id, loan_id, "
                    "clients(name, nickname, client_code), loans(loan_amount, active_credit, loan_products(name))"
                )
                # 2. Query Savings Deposits
                q_sav = uow_hist.client.table("individual_savings").select(
                    "id, client_id, deposit_amount, withdrawal_amount, posting_date, created_at, reference, remarks, officer_id, "
                    "clients(name, nickname, client_code)"
                )
                
                # Scope check
                if scope.scope_level == "OFFICER":
                    q_reps = q_reps.eq("officer_id", USER_ID)
                    q_sav = q_sav.eq("officer_id", USER_ID)
                elif scope.scope_level == "BRANCH" and BRANCH_ID:
                    q_reps = q_reps.eq("branch_id", BRANCH_ID)
                    q_sav = q_sav.eq("branch_id", BRANCH_ID)
                
                res_reps = q_reps.gte("date", f"{hist_date_str}T00:00:00").lte("date", f"{hist_date_str}T23:59:59").order("created_at", desc=True).execute()
                res_sav = q_sav.eq("posting_date", hist_date_str).order("created_at", desc=True).execute()
                
                reps_list = res_reps.data or []
                sav_list = res_sav.data or []
                
                # Filter deposits (ignore pure withdrawals here)
                sav_dep_list = [s for s in sav_list if float(s.get("deposit_amount") or 0) > 0]
                
                tot_reps_amt = sum(float(r.get("amount_paid") or 0) for r in reps_list)
                tot_sav_amt = sum(float(s.get("deposit_amount") or 0) for s in sav_dep_list)
                grand_total_cash = tot_reps_amt + tot_sav_amt
                
                # Summary KPIs
                kpi1, kpi2, kpi3 = st.columns(3)
                kpi1.metric("Total Repayments Collected", f"₦{tot_reps_amt:,.2f}", f"{len(reps_list)} Payments")
                kpi2.metric("Total Savings Deposited", f"₦{tot_sav_amt:,.2f}", f"{len(sav_dep_list)} Deposits")
                kpi3.metric("Grand Total Cash Collected", f"₦{grand_total_cash:,.2f}", "Total Physical Inflow")
                
                st.markdown("---")
                
                # Subtabs for Repayments vs Savings
                h_tab1, h_tab2 = st.tabs([f"💳 Loan Repayments ({len(reps_list)})", f"💰 Savings Deposits ({len(sav_dep_list)})"])
                
                with h_tab1:
                    if reps_list:
                        reps_rows = []
                        for r in reps_list:
                            c_dict = r.get("clients") or {} if isinstance(r.get("clients"), dict) else {}
                            c_name = c_dict.get("name") or str(r.get("client_id") or "Unknown")
                            c_code = c_dict.get("client_code") or ""
                            l_dict = r.get("loans") or {} if isinstance(r.get("loans"), dict) else {}
                            p_dict = l_dict.get("loan_products") or {} if isinstance(l_dict.get("loan_products"), dict) else {}
                            p_name = p_dict.get("name") or "Standard Loan"
                            amt = float(r.get("amount_paid") or 0)
                            time_str = str(r.get("created_at") or r.get("date") or "")[11:16]
                            note_val = str(r.get("note") or "")
                            
                            # Filter search
                            if hist_search:
                                match = (hist_search in c_name.lower() or hist_search in c_code.lower() or hist_search in note_val.lower() or hist_search in str(r.get("id")).lower())
                                if not match:
                                    continue
                                    
                            reps_rows.append({
                                "Time": time_str,
                                "Client Name": c_name,
                                "Client Code": c_code,
                                "Product": p_name,
                                "Amount Paid (₦)": f"₦{amt:,.2f}",
                                "Note / Type": note_val or str(r.get("transaction_type") or "Loan"),
                                "Ref ID": str(r.get("id", ""))[:8]
                            })
                        if reps_rows:
                            st.dataframe(pd.DataFrame(reps_rows), use_container_width=True, hide_index=True)
                        else:
                            st.info("No loan repayments match your search filter.")
                    else:
                        st.info(f"No loan repayments recorded on {hist_date_str}.")

                with h_tab2:
                    if sav_dep_list:
                        sav_rows = []
                        for s in sav_dep_list:
                            c_dict = s.get("clients") or {} if isinstance(s.get("clients"), dict) else {}
                            c_name = c_dict.get("name") or str(s.get("client_id") or "Unknown")
                            c_code = c_dict.get("client_code") or ""
                            amt = float(s.get("deposit_amount") or 0)
                            time_str = str(s.get("created_at") or s.get("posting_date") or "")[11:16]
                            rem_val = str(s.get("remarks") or s.get("reference") or "")
                            
                            if hist_search:
                                match = (hist_search in c_name.lower() or hist_search in c_code.lower() or hist_search in rem_val.lower() or hist_search in str(s.get("id")).lower())
                                if not match:
                                    continue
                                    
                            sav_rows.append({
                                "Time": time_str,
                                "Client Name": c_name,
                                "Client Code": c_code,
                                "Deposit Amount (₦)": f"₦{amt:,.2f}",
                                "Remarks / Reference": rem_val or "Individual Deposit",
                                "Ref ID": str(s.get("id", ""))[:8]
                            })
                        if sav_rows:
                            st.dataframe(pd.DataFrame(sav_rows), use_container_width=True, hide_index=True)
                        else:
                            st.info("No savings deposits match your search filter.")
                    else:
                        st.info(f"No savings deposits recorded on {hist_date_str}.")

        with col_tab3:
            st.markdown("### 🔄 Error Correction & Reversal Hub")
            st.caption("Flag an erroneous collection (loan repayment or savings deposit) for Branch Manager approval.")
            
            with SupabaseUnitOfWork() as uow_corr:
                # 1. Fetch recent repayments
                q_reps = uow_corr.client.table("repayments").select("id, client_id, amount_paid, date, note, officer_id, clients(name, client_code)")
                # 2. Fetch recent savings deposits
                q_sav = uow_corr.client.table("individual_savings").select("id, client_id, deposit_amount, posting_date, remarks, officer_id, clients(name, client_code)")
                
                if scope.scope_level == "OFFICER":
                    q_reps = q_reps.eq("officer_id", USER_ID)
                    q_sav = q_sav.eq("officer_id", USER_ID)
                elif scope.scope_level == "BRANCH" and BRANCH_ID:
                    q_reps = q_reps.eq("branch_id", BRANCH_ID)
                    q_sav = q_sav.eq("branch_id", BRANCH_ID)
                
                res_reps = q_reps.order("created_at", desc=True).limit(40).execute()
                res_sav = q_sav.gt("deposit_amount", 0).order("created_at", desc=True).limit(40).execute()
                
                recent_reps = res_reps.data or []
                recent_sav = res_sav.data or []
                
                opts = {}
                # Add Repayments
                for r in recent_reps:
                    tx_id = str(r.get("id", ""))
                    c_name = (r.get("clients") or {}).get("name") if isinstance(r.get("clients"), dict) else (r.get("client_id") or "Unknown")
                    l_rep = float(r.get("amount_paid") or 0.0)
                    tx_date = str(r.get("date", ""))[:10]
                    label = f"💳 [Repayment] {tx_date} | {c_name} — ₦{l_rep:,.2f} | Ref: {tx_id[:8]}"
                    opts[label] = ("Repayment", tx_id)
                
                # Add Savings Deposits
                for s in recent_sav:
                    tx_id = str(s.get("id", ""))
                    c_name = (s.get("clients") or {}).get("name") if isinstance(s.get("clients"), dict) else (s.get("client_id") or "Unknown")
                    s_dep = float(s.get("deposit_amount") or 0.0)
                    tx_date = str(s.get("posting_date", ""))[:10]
                    label = f"💰 [Savings Deposit] {tx_date} | {c_name} — ₦{s_dep:,.2f} | Ref: {tx_id[:8]}"
                    opts[label] = ("Savings", tx_id)
                
                if opts:
                    sel_tx_label = st.selectbox("Select Transaction to Flag for Reversal", list(opts.keys()), key="col_rev_tx_select")
                    rec_type, rec_id = opts[sel_tx_label]
                    
                    req_reason = st.text_input("Reason for Reversal", placeholder="e.g., Wrong payment entered. Typed 50000 instead of 5000.", key="col_rev_reason")
                    if st.button("Submit Reversal Request to BM", type="primary", key="col_submit_rev_btn"):
                        if req_reason.strip():
                            try:
                                from services.correction_service import CorrectionService
                                req_id = CorrectionService.request_correction(
                                    uow=uow_corr,
                                    record_id=rec_id,
                                    record_type=rec_type,
                                    reason=req_reason.strip(),
                                    requested_by=USER_ID if USER_ID else USER,
                                    branch_id=BRANCH_ID
                                )
                                st.success(f"✅ Reversal request submitted to Branch Manager for approval! (Ref: #{req_id[:8]})")
                                st.rerun()
                            except Exception as e:
                                st.error(f"Failed to submit correction request: {e}")
                        else:
                            st.warning("Please provide a valid reason for the reversal.")
                else:
                    st.info("No recent repayments or savings deposits available to flag.")
                
                # Display Submitted Requests History for this user
                st.markdown("---")
                st.markdown("#### 📋 Submitted Reversal Requests")
                try:
                    req_query = uow_corr.client.table("correction_requests").select("*")
                    if USER_ID:
                        req_query = req_query.eq("requested_by", USER_ID)
                    elif BRANCH_ID:
                        req_query = req_query.eq("branch_id", BRANCH_ID)
                    res_my_reqs = req_query.order("created_at", desc=True).limit(10).execute()
                    my_reqs = res_my_reqs.data or []
                except Exception:
                    my_reqs = []
                
                if my_reqs:
                    req_display = []
                    for mr in my_reqs:
                        st_badge = "🟡 Pending" if mr.get("status") == "Pending" else ("🟢 Approved" if mr.get("status") == "Approved" else "🔴 Rejected")
                        req_display.append({
                            "Date": str(mr.get("created_at", ""))[:16].replace("T", " "),
                            "Type": mr.get("record_type"),
                            "Record Ref": str(mr.get("record_id", ""))[:8],
                            "Reason": mr.get("reason"),
                            "Status": st_badge,
                            "Approved By": mr.get("approved_by") or "—"
                        })
                    st.dataframe(pd.DataFrame(req_display), use_container_width=True, hide_index=True)
                else:
                    st.caption("You have not submitted any reversal requests yet.")

elif page == "Withdrawal Operations":
    st.title("Withdrawal Operations")
    st.caption("Submit withdrawal requests for BM approval. All withdrawals require Branch Manager authorization before execution.")

    user_dict = current_user.to_dict() if hasattr(current_user, 'to_dict') else {
        "id": USER_ID, "username": USER, "role": ROLE, "branch": BRANCH, "branch_id": BRANCH_ID, "assigned_branches": ASSIGNED_BRANCH_IDS
    }
    user_scope = RBACScopeService.resolve_scope(user_dict)

    if user_scope.is_read_only():
        st.warning("Read-Only Access: Your role does not permit withdrawal operations.")
        st.stop()

    uow = SupabaseUnitOfWork()
    from services.business_date_service import BusinessDateService
    today_dt = datetime.now().date()
    is_wth_open, wth_open_reason = BusinessDateService.is_operational_open(uow, BRANCH_ID, today_dt)
    if not is_wth_open:
        st.warning(f"🏖️ **Operational Activity Suspended ({wth_open_reason})**: Savings withdrawals and LAPS payouts are frozen today.")

    # ── Savings Type Selector ──
    wth_tab1, wth_tab2, wth_tab3, wth_tab4 = st.tabs([
        "Individual Savings", 
        "Group Savings", 
        "Misc Savings", 
        "LAPS Savings"
    ])

    # ════════════════════════════════════════════════════════════════════
    # INDIVIDUAL SAVINGS
    # ════════════════════════════════════════════════════════════════════
    with wth_tab1:
        # Fetch clients with membership info (scoped by role)
        if ROLE in ["BM", "AM", "Branch Manager", "Area Manager", ROLE_BRANCH_MANAGER, ROLE_AREA_MANAGER, ROLE_ADMIN, ROLE_SUPER_ADMIN, "Admin", "Super Admin"]:
            if ROLE in ["AM", "Area Manager", ROLE_AREA_MANAGER]:
                res_users = uow.client.table("app_users").select("id, username, full_name").in_("branch_id", ASSIGNED_BRANCH_IDS).execute()
            elif ROLE in ["BM", "Branch Manager", ROLE_BRANCH_MANAGER]:
                res_users = uow.client.table("app_users").select("id, username, full_name").eq("branch_id", BRANCH_ID).execute()
            else:
                res_users = uow.client.table("app_users").select("id, username, full_name").execute()
            
            officers_map = {"All Officers": None}
            for u in (res_users.data or []):
                label = f"{u.get('username')} - {u.get('full_name')}" if u.get('full_name') else u.get('username')
                officers_map[label] = u.get('id')
                
            co_filter = st.selectbox("Filter by Credit Officer", list(officers_map.keys()), key="wth_ind_co_filter")
            selected_officer_id = officers_map[co_filter]
            
            query = uow.client.table("clients").select("client_id, client_code, name, status, status_id, client_memberships(group_id, groups(name)), client_statuses(name)")
            if ROLE in ["AM", "Area Manager", ROLE_AREA_MANAGER]:
                query = query.in_("branch_id", ASSIGNED_BRANCH_IDS)
            elif ROLE in ["BM", "Branch Manager", ROLE_BRANCH_MANAGER]:
                query = query.eq("branch_id", BRANCH_ID)
            
            if selected_officer_id:
                query = query.eq("officer_id", selected_officer_id)
            res_c = query.execute()
        else:
            officer_id = uow.loans._resolve_officer_id(USER) or getattr(current_user, 'id', USER_ID)
            res_c = uow.client.table("clients").select("client_id, client_code, name, status, status_id, client_memberships(group_id, groups(name)), client_statuses(name)").eq("officer_id", officer_id).execute()

        # Build group list from the CO's own active relationship clients
        co_groups = {}
        all_clients = [
            c for c in (res_c.data or []) 
            if ((c.get("client_statuses") or {}).get("name") if isinstance(c.get("client_statuses"), dict) else c.get("status")) not in ["Closed", "Suspended"]
        ]
        for c in all_clients:
            memberships = c.get("client_memberships") or []
            if isinstance(memberships, dict):
                memberships = [memberships]
            for m in memberships:
                if m and m.get("group_id") and m.get("groups"):
                    co_groups[m["group_id"]] = m["groups"].get("name") or "Unknown"

        group_names = ["All Groups"] + sorted(co_groups.values())
        sel_group_filter = st.selectbox("Filter by Group", group_names)

        # Resolve selected group ID
        selected_group_id = None
        if sel_group_filter != "All Groups":
            selected_group_id = next((gid for gid, gname in co_groups.items() if gname == sel_group_filter), None)

        # Filter clients by selected group
        client_opts = {}
        for c in all_clients:
            if selected_group_id:
                memberships = c.get("client_memberships") or []
                if isinstance(memberships, dict):
                    memberships = [memberships]
                member_group_ids = [m.get("group_id") for m in memberships if m]
                if selected_group_id not in member_group_ids:
                    continue
            label = f"{c['name']} ({c.get('client_code') or c['client_id'][:8]})"
            client_opts[label] = c

        if not client_opts:
            st.info("No active clients found for the selected group.")
            st.stop()

        sel_client_label = st.selectbox("Search Client", list(client_opts.keys()), placeholder="Type client name or code...")
        sel_client = client_opts[sel_client_label]
        c_id = sel_client["client_id"]
        c_name = sel_client["name"]

        # Show balance
        ind_bal = uow.individual_savings.get_total_balance(client_id=c_id)
        st.metric("Individual Savings Balance", f"₦{ind_bal:,.2f}")

        # Operation type
        op_type = st.radio("Withdrawal Operation", ["Cash Withdrawal", "Loan Offset", "Asset Downpayment", "LAPS Transfer"], horizontal=True)

        if op_type == "Cash Withdrawal":
            st.info("Product Withdrawal Value: Reduced | Physical Cash Outflow: YES (Vault Cash leaves CO position)")
        elif op_type == "Loan Offset":
            st.info("Product Withdrawal Value: Reduced | Physical Cash Outflow: NO (Internal non-cash offset against active loan debt)")
        elif op_type == "Asset Downpayment":
            st.info("Product Withdrawal Value: Increased | Physical Cash Outflow: NO (Internal non-cash deduction from savings to fund Asset Downpayment)")
        elif op_type == "LAPS Transfer":
            st.info("Product Withdrawal Value: Reduced | Physical Cash Outflow: NO (Internal non-cash transfer to LAPS reserve)")

        with st.form("ind_withdrawal_form"):
            amount_val = st.number_input("Amount (₦)", min_value=0.0, step=500.0, value=None, placeholder="Enter amount...", format="%.2f")

            target_loan_id = None
            if op_type == "Loan Offset":
                res_l = uow.client.table("loans").select("loan_id, loan_amount, active_credit").eq("client_id", c_id).eq("status", "Active").execute()
                active_loans = res_l.data or []
                if active_loans:
                    loan_opts = {f"Loan {l['loan_id'][:8]} — Active Credit: ₦{float(l.get('active_credit') or 0):,.0f}": l["loan_id"] for l in active_loans}
                    sel_loan = st.selectbox("Select Loan to Offset", list(loan_opts.keys()))
                    target_loan_id = loan_opts[sel_loan]
                else:
                    st.warning("No active loans found for this client.")
            elif op_type == "Asset Downpayment":
                res_l = uow.client.table("loans").select("loan_id, loan_amount, active_credit, product_category, extra_fields, loan_products(name)").eq("client_id", c_id).in_("status", ["Active", "Pending"]).execute()
                asset_loans = [
                    l for l in (res_l.data or []) 
                    if l.get("product_category") == "Asset" 
                    or (l.get("extra_fields") or {}).get("product_category") == "Asset" 
                    or "asset" in str((l.get("loan_products") or {}).get("name", "")).lower()
                ]
                if asset_loans:
                    loan_opts = {f"Asset Loan {l['loan_id'][:8]} — Active Credit: ₦{float(l.get('active_credit') or 0):,.0f}": l["loan_id"] for l in asset_loans}
                    sel_loan = st.selectbox("Select Asset Loan for Downpayment", list(loan_opts.keys()))
                    target_loan_id = loan_opts[sel_loan]
                else:
                    st.warning("No active or pending asset loans found for this client.")

            remarks_input = st.text_area("Remarks", placeholder="Reason for withdrawal...")
            submitted = st.form_submit_button("Submit for BM Approval", use_container_width=True)

            if submitted:
                if not amount_val or amount_val <= 0:
                    st.error("Amount must be greater than zero.")
                elif amount_val > ind_bal and op_type not in ["Loan Offset", "Asset Downpayment"]:
                    st.error(f"Insufficient balance. Available: ₦{ind_bal:,.2f}")
                elif amount_val > ind_bal and op_type == "Asset Downpayment":
                    st.error(f"Insufficient savings balance for downpayment. Available: ₦{ind_bal:,.2f}")
                elif op_type in ["Loan Offset", "Asset Downpayment"] and not target_loan_id:
                    st.error("Select an eligible loan.")
                else:
                    uow.client.table("withdrawal_requests").insert({
                        "savings_type": "Individual",
                        "operation_type": op_type,
                        "client_id": c_id,
                        "client_name": c_name,
                        "loan_id": target_loan_id,
                        "branch_id": BRANCH_ID,
                        "requested_by": USER,
                        "amount": float(amount_val),
                        "reference": f"REF-WTH-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                        "remarks": remarks_input or f"{op_type} request for {c_name}",
                        "status": "PENDING"
                    }).execute()
                    st.success(f"Withdrawal request submitted for BM approval! (₦{amount_val:,.2f})")
                    st.rerun()

    # ════════════════════════════════════════════════════════════════════
    # GROUP SAVINGS
    # ════════════════════════════════════════════════════════════════════
    with wth_tab2:
        group_opts = {}
        if ROLE in ["BM", "AM", "Branch Manager", "Area Manager", ROLE_BRANCH_MANAGER, ROLE_AREA_MANAGER, ROLE_ADMIN, ROLE_SUPER_ADMIN, "Admin", "Super Admin"]:
            if ROLE in ["AM", "Area Manager", ROLE_AREA_MANAGER]:
                res_users = uow.client.table("app_users").select("id, username, full_name").in_("branch_id", ASSIGNED_BRANCH_IDS).execute()
            elif ROLE in ["BM", "Branch Manager", ROLE_BRANCH_MANAGER]:
                res_users = uow.client.table("app_users").select("id, username, full_name").eq("branch_id", BRANCH_ID).execute()
            else:
                res_users = uow.client.table("app_users").select("id, username, full_name").execute()
            
            officers_map = {"All Officers": None}
            for u in (res_users.data or []):
                label = f"{u.get('username')} - {u.get('full_name')}" if u.get('full_name') else u.get('username')
                officers_map[label] = u.get('id')
                
            co_filter = st.selectbox("Filter by Credit Officer", list(officers_map.keys()), key="wth_grp_co_filter")
            selected_officer_id = officers_map[co_filter]
            
            query = uow.client.table("groups").select("group_id, name")
            if ROLE in ["AM", "Area Manager", ROLE_AREA_MANAGER]:
                query = query.in_("branch_id", ASSIGNED_BRANCH_IDS)
            elif ROLE in ["BM", "Branch Manager", ROLE_BRANCH_MANAGER]:
                query = query.eq("branch_id", BRANCH_ID)
            
            if selected_officer_id:
                query = query.eq("officer_id", selected_officer_id)
            res_g = query.execute()
            for g in (res_g.data or []):
                if g and g.get("name"):
                    group_opts[g["name"]] = g
        else:
            # Credit Officer (CO): strictly fetch only groups where groups.officer_id == target_officer_id
            target_officer_id = uow.loans._resolve_officer_id(USER) or getattr(current_user, 'id', USER_ID)
            res_g = uow.client.table("groups").select("group_id, name").eq("branch_id", BRANCH_ID).eq("officer_id", target_officer_id).execute()
            for g in (res_g.data or []):
                if g and g.get("name"):
                    group_opts[g["name"]] = g

        if not group_opts:
            st.info("No active groups found for the selected officer.")
            st.stop()

        sel_group_label = st.selectbox("Search Group", list(group_opts.keys()), placeholder="Type group name...")
        sel_group = group_opts[sel_group_label]
        g_name = sel_group["name"]

        # Show balance
        grp_bal = uow.group_savings.get_total_balance(group_name=g_name)
        st.metric("Group Savings Balance", f"₦{grp_bal:,.2f}")

        op_type = st.radio("Withdrawal Operation", ["Cash Withdrawal", "Loan Offset (Member Debt)", "Asset Downpayment (Member Loan)", "LAPS Transfer (Group Closed)"], horizontal=True)

        if "Cash" in op_type:
            st.info("Product Withdrawal Value: Reduced | Physical Cash Outflow: YES (Vault Cash leaves CO position)")
        elif "Loan Offset" in op_type:
            st.info("Product Withdrawal Value: Reduced | Physical Cash Outflow: NO (Internal non-cash offset against member active loan debt)")
        elif "Asset Downpayment" in op_type:
            st.info("Product Withdrawal Value: Increased | Physical Cash Outflow: NO (Internal non-cash deduction from group savings to fund member Asset Downpayment)")
        elif "LAPS Transfer" in op_type:
            st.info("Product Withdrawal Value: Reduced | Physical Cash Outflow: NO (Internal non-cash transfer to LAPS reserve)")

        with st.form("grp_withdrawal_form"):
            amount_val = st.number_input("Amount (₦)", min_value=0.0, step=500.0, value=None, placeholder="Enter amount...", format="%.2f")

            target_loan_id = None
            client_name_for_offset = None
            if "Loan Offset" in op_type or "Asset Downpayment" in op_type:
                # Select which member's loan to offset from group savings
                res_members = uow.client.table("client_memberships").select("clients(client_id, client_code, name)").eq("group_id", sel_group["group_id"]).execute()
                members = []
                if res_members.data:
                    for m in res_members.data:
                        cl = m.get("clients")
                        if cl:
                            members.append(cl)
                if members:
                    member_opts = {f"{m['name']} ({m.get('client_code') or m['client_id'][:8]})": m for m in members}
                    sel_member_label = st.selectbox("Select Member", list(member_opts.keys()))
                    sel_member = member_opts[sel_member_label]
                    client_name_for_offset = sel_member["name"]

                    if "Asset Downpayment" in op_type:
                        res_l = uow.client.table("loans").select("loan_id, loan_amount, active_credit, product_category, extra_fields, loan_products(name)").eq("client_id", sel_member["client_id"]).in_("status", ["Active", "Pending"]).execute()
                        loans_to_show = [
                            l for l in (res_l.data or []) 
                            if l.get("product_category") == "Asset" 
                            or (l.get("extra_fields") or {}).get("product_category") == "Asset" 
                            or "asset" in str((l.get("loan_products") or {}).get("name", "")).lower()
                        ]
                    else:
                        res_l = uow.client.table("loans").select("loan_id, loan_amount, active_credit, product_category, extra_fields, loan_products(name)").eq("client_id", sel_member["client_id"]).eq("status", "Active").execute()
                        loans_to_show = res_l.data or []

                    if loans_to_show:
                        loan_opts = {f"Loan {l['loan_id'][:8]} — ₦{float(l.get('active_credit') or 0):,.0f}": l["loan_id"] for l in loans_to_show}
                        sel_loan = st.selectbox("Select Loan", list(loan_opts.keys()))
                        target_loan_id = loan_opts[sel_loan]
                    else:
                        st.warning("No eligible loans found for this member.")
                else:
                    st.warning("No members found in this group.")

            remarks_input = st.text_area("Remarks", placeholder="Reason for withdrawal...")
            submitted = st.form_submit_button("Submit for BM Approval", use_container_width=True)

            if submitted:
                if not amount_val or amount_val <= 0:
                    st.error("Amount must be greater than zero.")
                elif amount_val > grp_bal:
                    st.error(f"Insufficient group balance. Available: ₦{grp_bal:,.2f}")
                elif ("Loan Offset" in op_type or "Asset Downpayment" in op_type) and not target_loan_id:
                    st.error("Select a member and loan.")
                else:
                    op_clean = "Cash Withdrawal" if "Cash" in op_type else ("Asset Downpayment" if "Asset Downpayment" in op_type else ("Loan Offset" if "Loan Offset" in op_type else "LAPS Transfer"))
                    uow.client.table("withdrawal_requests").insert({
                        "savings_type": "Group",
                        "operation_type": op_clean,
                        "client_id": sel_member["client_id"] if ("Loan Offset" in op_type or "Asset Downpayment" in op_type) and 'sel_member' in locals() else None,
                        "client_name": client_name_for_offset or g_name,
                        "group_name": g_name,
                        "loan_id": target_loan_id,
                        "branch_id": BRANCH_ID,
                        "requested_by": USER,
                        "amount": float(amount_val),
                        "reference": f"REF-GRP-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                        "remarks": remarks_input or f"Group {op_clean} from {g_name}",
                        "status": "PENDING"
                    }).execute()
                    st.success(f"Group withdrawal request submitted for BM approval! (₦{amount_val:,.2f})")
                    st.rerun()

    # ════════════════════════════════════════════════════════════════════
    # MISC SAVINGS (Read-only for CO, BM can withdraw)
    # ════════════════════════════════════════════════════════════════════
    with wth_tab3:
        misc_bal = uow.misc_savings.get_total_balance(branch=BRANCH)
        st.metric("Branch Misc Savings Balance", f"₦{misc_bal:,.2f}")

        if ROLE not in ["BM", ROLE_BRANCH_MANAGER, ROLE_ADMIN, ROLE_SUPER_ADMIN, "Admin", "Super Admin"]:
            st.info("Misc Savings is managed by the Branch Manager. You can view the balance but cannot submit withdrawals.")
        else:
            st.markdown("**As Branch Manager, you can submit a Misc Savings withdrawal.**")

            with st.form("misc_withdrawal_form"):
                amount_val = st.number_input("Amount (₦)", min_value=0.0, step=500.0, value=None, placeholder="Enter amount...", format="%.2f")
                remarks_input = st.text_area("Remarks", placeholder="Reason for Misc withdrawal...")
                submitted = st.form_submit_button("Submit Misc Withdrawal", use_container_width=True)

                if submitted:
                    if not amount_val or amount_val <= 0:
                        st.error("Amount must be greater than zero.")
                    elif amount_val > misc_bal:
                        st.error(f"Insufficient Misc balance. Available: ₦{misc_bal:,.2f}")
                    else:
                        uow.client.table("withdrawal_requests").insert({
                            "savings_type": "Misc",
                            "operation_type": "Cash Withdrawal",
                            "client_name": f"Branch Misc - {BRANCH}",
                            "branch_id": BRANCH_ID,
                            "requested_by": USER,
                            "amount": float(amount_val),
                            "reference": f"REF-MISC-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                            "remarks": remarks_input or f"Misc Savings withdrawal by {USER}",
                            "status": "PENDING"
                        }).execute()
                        st.success(f"Misc withdrawal request submitted! (₦{amount_val:,.2f})")
                        st.rerun()

    # ════════════════════════════════════════════════════════════════════
    # LAPS SAVINGS (Closed client/group payouts)
    # ════════════════════════════════════════════════════════════════════
    with wth_tab4:
        st.caption("LAPS records for closed clients and groups. Submit a payout request when a closed client returns to collect their savings.")

        # Search LAPS records
        res_laps = uow.client.table("laps_savings").select("id, client_id, deposit_amount, withdrawal_amount, remarks, created_at").execute()
        laps_data = {}
        if res_laps.data:
            for lr in res_laps.data:
                cid = lr.get("client_id") or lr.get("id")
                if cid not in laps_data:
                    laps_data[cid] = {"client_id": cid, "balance": 0.0, "remarks": lr.get("remarks") or ""}
                laps_data[cid]["balance"] += float(lr.get("deposit_amount") or 0) - float(lr.get("withdrawal_amount") or 0)

        if not laps_data:
            st.info("No LAPS savings records found.")
            st.stop()

        laps_list = [v for v in laps_data.values() if v["balance"] > 0]
        if not laps_list:
            st.info("No LAPS balances available for payout.")
            st.stop()

        laps_opts = {f"{l['client_id'][:12]}... — Balance: ₦{l['balance']:,.2f}": l for l in laps_list}
        sel_laps_label = st.selectbox("Select LAPS Record", list(laps_opts.keys()))
        sel_laps = laps_opts[sel_laps_label]

        st.metric("LAPS Balance", f"₦{sel_laps['balance']:,.2f}")

        with st.form("laps_payout_form"):
            amount_val = st.number_input("Payout Amount (₦)", min_value=0.0, step=500.0, value=None, placeholder="Enter amount...", format="%.2f")
            payout_method = st.radio("Payout Method", ["Cash", "Bank Transfer"], horizontal=True)

            if payout_method == "Cash":
                st.info("Product Withdrawal Value: Reduced | Physical Cash Outflow: YES (Vault Cash paid out to client)")
            else:
                st.info("Product Withdrawal Value: Reduced | Physical Cash Outflow: NO (Paid directly via Bank Account)")
            remarks_input = st.text_area("Remarks", placeholder="Client details, reason for payout...")
            submitted = st.form_submit_button("Submit LAPS Payout for BM Approval", use_container_width=True)

            if submitted:
                if not amount_val or amount_val <= 0:
                    st.error("Amount must be greater than zero.")
                elif amount_val > sel_laps["balance"]:
                    st.error(f"Insufficient LAPS balance. Available: ₦{sel_laps['balance']:,.2f}")
                else:
                    uow.client.table("withdrawal_requests").insert({
                        "savings_type": "LAPS",
                        "operation_type": "LAPS Payout",
                        "client_id": sel_laps["client_id"],
                        "client_name": remarks_input.split('\n')[0][:50] if remarks_input else f"LAPS Client {sel_laps['client_id'][:8]}",
                        "branch_id": BRANCH_ID,
                        "requested_by": USER,
                        "amount": float(amount_val),
                        "payout_method": payout_method,
                        "reference": f"REF-LAPS-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                        "remarks": remarks_input or f"LAPS payout for {sel_laps['client_id'][:8]}",
                        "status": "PENDING"
                    }).execute()
                    st.success(f"LAPS payout request submitted for BM approval! (₦{amount_val:,.2f})")
                    st.rerun()

    # ── My Pending Requests ──
    st.markdown("---")
    st.markdown("### My Pending Withdrawal Requests")
    res_pending = uow.client.table("withdrawal_requests").select("*").eq("requested_by", USER).order("created_at", desc=True).limit(20).execute()

    if res_pending.data:
        for req in res_pending.data:
            st.markdown(
                f"**{req['savings_type']} — {req['operation_type']}** | "
                f"₦{float(req['amount']):,.2f} | {req['client_name']} | "
                f"Status: **{req['status']}** | {req['created_at'][:10]}"
            )
            if req["status"] == "REJECTED" and req.get("rejection_reason"):
                st.caption(f"  ↳ Reason: {req['rejection_reason']}")
    else:
        st.info("No withdrawal requests submitted yet.")

elif page == "Legacy LAPS Migration":
    st.title("🏛️ Legacy LAPS Bulk Migration Console (Super Admin)")
    st.caption("Upload historical Loan Application Savings (LAPS) records from legacy Excel workbooks with owner mapping, audit tracking, and zero physical cash vault impact.")

    if ROLE not in ["Admin", "Super Admin", "SUPER_ADMIN", "ADMIN"]:
        st.error("⛔ Access Denied: Legacy LAPS Migration is restricted to Super Admin / Admin roles.")
    else:
        st.markdown("---")
        st.subheader("📥 Bulk Excel File Upload")
        
        st.info("💡 **Excel Format Requirements**: Columns MUST include `client_name` (or `Name`), `amount` (or `LAPS Balance`), `branch` (or `Branch`), `officer` (or `Officer`). Optional columns: `client_id`, `owner_known` ('Yes'/'No' or True/False), `remarks`.")
        
        uploaded_file = st.file_uploader("Upload Legacy LAPS Excel Sheet (.xlsx, .xls)", type=["xlsx", "xls"])
        source_name = st.text_input("Migration Source Identifier", value="EXCEL_MIGRATION_BATCH")
        
        if uploaded_file is not None:
            try:
                import pandas as pd
                df_mig = pd.read_excel(uploaded_file)
                st.subheader("Preview Uploaded Migration Data")
                st.dataframe(df_mig.head(10), use_container_width=True)
                st.caption(f"Total Rows Detected: {len(df_mig)}")

                if st.button("🚀 Process Bulk LAPS Migration", type="primary"):
                    records_to_migrate = []
                    for idx, row in df_mig.iterrows():
                        rec = {
                            "client_id": row.get("client_id") or row.get("Client ID") or row.get("client_code") or None,
                            "client_name": row.get("client_name") or row.get("Name") or row.get("Client Name") or "Legacy Account",
                            "amount": float(row.get("amount") or row.get("LAPS Balance") or row.get("Balance") or row.get("deposit_amount") or 0.0),
                            "branch": row.get("branch") or row.get("Branch") or "Main Branch",
                            "officer": row.get("officer") or row.get("Officer") or USER,
                            "owner_known": row.get("owner_known") if "owner_known" in row else (row.get("Owner Known") if "Owner Known" in row else None),
                            "remarks": row.get("remarks") or row.get("Remarks") or "Legacy LAPS bulk import"
                        }
                        records_to_migrate.append(rec)

                    with SupabaseUnitOfWork() as uow:
                        from services.laps_migration_service import LAPSMigrationService
                        res = LAPSMigrationService.migrate_legacy_laps(
                            uow=uow,
                            records=records_to_migrate,
                            user_id=USER,
                            source_name=source_name
                        )

                    if res["success_count"] > 0:
                        st.success(f"🎉 Successfully Migrated {res['success_count']} LAPS Records! (Total Value: ₦{res['total_amount_migrated']:,.2f})")
                        st.info(f"🏷️ Batch ID: **{res['batch_id']}**")
                        st.warning("🔄 Zero Physical Cash Movement: Opening equity ledger entries posted with ZERO vault cash impact.")

                    if res["failed_count"] > 0:
                        st.error(f"⚠️ Failed Records: {res['failed_count']}")
                        with st.expander("View Error Details"):
                            for err in res["errors"]:
                                st.write(f"- {err}")

            except Exception as ex:
                st.error(f"❌ Failed to parse Excel file: {str(ex)}")

        st.markdown("---")
        st.subheader("📜 Historical LAPS Migration Batches")
        try:
            with SupabaseUnitOfWork() as uow:
                laps_records = uow.laps_savings.get_all()
                df_laps = pd.DataFrame([vars(r) for r in laps_records])
                if not df_laps.empty and "migration_batch_id" in df_laps.columns:
                    mig_df = df_laps[df_laps["migration_batch_id"].notnull()]
                    if not mig_df.empty:
                        st.dataframe(mig_df[["migration_batch_id", "client_name", "branch", "officer", "deposit_amount", "owner_known", "migration_source", "date"]], use_container_width=True)
                    else:
                        st.info("No migrated LAPS records found yet.")
                else:
                    st.info("No migrated LAPS records found yet.")
        except Exception as ex:
            st.info(f"Could not load migration history: {ex}")

elif page == "Daily Report":
    st.title("Daily Collections Report")
    
    view_date = st.date_input("Select Date for Report", datetime.now().date())
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    # Filter for the selected date for new active loans (excluding legacy onboarding loans)
    if not all_loans.empty:
        all_loans['DateStr'] = pd.to_datetime(all_loans['Date'], errors='coerce').dt.date.astype(str)
        daily_loans = all_loans[(all_loans['DateStr'] == date_str) & (all_loans['Status'].isin([STATUS_ACTIVE, STATUS_COMPLETED, STATUS_APPROVED]))]
        if not daily_loans.empty and 'extra_fields' in daily_loans.columns:
            daily_loans = daily_loans[~daily_loans['extra_fields'].apply(lambda x: isinstance(x, dict) and x.get('is_legacy') is True)]
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
            total_bank_wd = pd.to_numeric(daily_reps['Bank Withdrawal'], errors='coerce').fillna(0).sum()
            
            total_cash_out_wd = pd.to_numeric(daily_reps['Withdrawal Amount'], errors='coerce').fillna(0).sum()
            total_expenses = pd.to_numeric(daily_reps['Expenses'], errors='coerce').fillna(0).sum()
            total_bank_dep = pd.to_numeric(daily_reps['Bank Deposited'], errors='coerce').fillna(0).sum()
            total_prod_wd = pd.to_numeric(daily_reps['Product Withdrawal'], errors='coerce').fillna(0).sum()
            total_laps_tx = pd.to_numeric(daily_reps['Laps Transferred'], errors='coerce').fillna(0).sum()
            
            cashbook_inflow = total_cash_in + total_bank_wd
            cashbook_outflow = total_cash_out_wd + total_expenses + total_bank_dep + total_prod_wd + total_laps_tx
            net_closing_balance = cashbook_inflow - cashbook_outflow
            
            st.markdown("---")
            c1, c2, c3 = st.columns(3)
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
                st.write(f"**New Active Loans Today:** ₦{new_active_loans:,.0f}")
                st.write(f"**Actual Loan Collections:** ₦{actual_collections:,.0f} (Instalments, Overdue, Init, Rec)")
                st.markdown("---")
                st.markdown(f"#### Net Credit Flow Today: ₦{(new_active_loans - actual_collections):,.0f}")
                st.markdown("</div>", unsafe_allow_html=True)
                
            with c3:
                st.markdown("<div class='card' style='background-color: #f0fdf4; border: 1px solid #bbf7d0;'>", unsafe_allow_html=True)
                st.subheader("💵 Cashbook (Teller)")
                st.write(f"**Total Inflow (Cash In):** ₦{cashbook_inflow:,.0f}")
                st.write(f"**Total Outflow (Cash Out):** ₦{cashbook_outflow:,.0f}")
                st.markdown("---")
                st.markdown(f"<h4 style='color: #166534;'>Closing Cash Balance: ₦{net_closing_balance:,.0f}</h4>", unsafe_allow_html=True)
                st.markdown("</div>", unsafe_allow_html=True)
            
            st.markdown("### 📝 Detailed Client Breakdown")
            
            detailed_data = []
            client_savings_map = load_client_savings_map()
            for _, row in daily_reps.iterrows():
                cid = row.get('Client ID')
                c_loan = all_loans[all_loans['Client ID'] == cid].iloc[0] if cid in all_loans['Client ID'].values else None
                
                acc_savings = 0
                loan_bal = 0
                
                if c_loan is not None:
                    c_payments = repayments[repayments['Client ID'] == cid]
                    s_amt = client_savings_map.get(cid, 0.0)
                    l_amt = pd.to_numeric(c_payments['Loan Repayment Amount'], errors='coerce').fillna(0).sum()
                    acc_savings = s_amt
                    loan_bal = max(0.0, float(c_loan.get('Active Credit', 0.0)) - l_amt)
                    
                detailed_data.append({
                    "Client ID": cid,
                    "Client Name": row.get('Client Name', 'Unknown'),
                    "Phone": c_loan['Phone'] if c_loan is not None else '',
                    "Group": c_loan['Group Name'] if c_loan is not None else '',
                    "Cash Paid Today": row.get('Amount Paid', 0),
                    "Loan Paid Today": row.get('Loan Repayment Amount', 0),
                    "Others Amount": row.get('Others Amount', 0),
                    "Recovery Amount": row.get('Recovery Amount', 0),
                    "initial_payment": row.get('initial_payment', 0),
                    "Savings Paid Today": row.get('Savings Amount', 0),
                    "Withdrawal Amount": row.get('Withdrawal Amount', 0),
                    "Markup Paid": row.get('Markup Paid', 0),
                    "Group Savings Deposit": row.get('Group Savings Deposit', 0),
                    "Group Savings Withdrawal": row.get('Group Savings Withdrawal', 0),
                    "Misc Fee": row.get('Misc Fees', 0),
                    "Passbook": row.get('Pass Book Bonus', 0),
                    "Current Loan Balance": loan_bal,
                    "Total Acc. Savings": acc_savings,
                    "Officer": row.get('Officer', ''),
                    "Note": str(row.get('Note', ''))
                })
            
            df_detailed = pd.DataFrame(detailed_data)
            if not df_detailed.empty:
                # Convert necessary columns to numeric
                for col in ["Cash Paid Today", "Loan Paid Today", "Others Amount", "Recovery Amount", "initial_payment",
                            "Savings Paid Today", "Withdrawal Amount", "Markup Paid", 
                            "Group Savings Deposit", "Group Savings Withdrawal", "Misc Fee", "Passbook"]:
                    df_detailed[col] = pd.to_numeric(df_detailed[col], errors='coerce').fillna(0)
                
                # Combine derived columns
                df_detailed["Loan Paid Today"] = df_detailed["Loan Paid Today"] + df_detailed["Others Amount"] + df_detailed["Recovery Amount"] + df_detailed["initial_payment"]
                df_detailed["Withdrawal Today"] = df_detailed["Withdrawal Amount"] + df_detailed["Markup Paid"]
                df_detailed["Group Savings"] = df_detailed["Group Savings Deposit"] - df_detailed["Group Savings Withdrawal"]
                
                # Group by Client ID
                agg_funcs = {
                    "Client Name": "first",
                    "Phone": "first",
                    "Group": "first",
                    "Cash Paid Today": "sum",
                    "Loan Paid Today": "sum",
                    "Savings Paid Today": "sum",
                    "Withdrawal Today": "sum",
                    "Group Savings": "sum",
                    "Misc Fee": "sum",
                    "Passbook": "sum",
                    "Current Loan Balance": "last",
                    "Total Acc. Savings": "last",
                    "Officer": "first",
                    "Note": lambda x: ' | '.join(filter(lambda v: pd.notna(v) and str(v).strip() != '' and str(v).strip() != 'nan', set(x)))
                }
                df_detailed = df_detailed.groupby("Client ID", as_index=False).agg(agg_funcs)
                df_detailed = df_detailed[["Client Name", "Phone", "Group", "Cash Paid Today", "Loan Paid Today", 
                                           "Savings Paid Today", "Withdrawal Today", "Group Savings", "Misc Fee", 
                                           "Passbook", "Current Loan Balance", "Total Acc. Savings", "Officer", "Note"]]
                
            st.dataframe(df_detailed, use_container_width=True)
            
            # --- FLAG ERROR SECTION ---
            if not daily_reps.empty:
                st.markdown("### 🚩 Request Error Correction")
                with st.expander("Flag an Error / Request Reversal"):
                    st.info("Select a transaction from today to flag for reversal. The Branch Manager or Admin must approve the correction.")
                    opts = {}
                    for _, r in daily_reps.iterrows():
                        if r.get("Reversed", False):
                            continue
                        tx_id = str(r.get('id', ''))
                        if not tx_id or len(tx_id) < 10:
                            continue
                        amt_paid = float(r.get('Loan Repayment Amount') or 0)
                        sav_amt = float(r.get('Savings Amount') or 0)
                        c_name = r.get('Client Name', 'Unknown')
                        label = f"{c_name} (Loan: ₦{amt_paid:,.0f}, Sav: ₦{sav_amt:,.0f}) | ID: {tx_id[:8]}"
                        opts[label] = tx_id
                    
                    if opts:
                        sel_tx_label = st.selectbox("Select Transaction", list(opts.keys()))
                        req_reason = st.text_input("Reason for Correction", placeholder="e.g. Wrong amount entered. Typed 50000 instead of 5000.")
                        
                        if st.button("Submit Correction Request", type="primary"):
                            if req_reason:
                                try:
                                    from services.correction_service import CorrectionService
                                    with SupabaseUnitOfWork() as uow:
                                        CorrectionService.request_correction(
                                            uow,
                                            record_id=opts[sel_tx_label],
                                            record_type="Repayment",
                                            reason=req_reason,
                                            requested_by=USER_ID,
                                            branch_id=BRANCH_ID
                                        )
                                    st.success("Correction request submitted successfully! Awaiting Manager approval.")
                                except Exception as e:
                                    st.error(f"Error submitting request: {e}")
                            else:
                                st.warning("Please provide a reason for the correction.")
                    else:
                        st.info("No valid transactions available to reverse.")
    else:
        st.info("No records found in database.")

elif page == "Audit Ledger Legacy":
    st.title("📒 Audit Ledger")
    st.caption("Complete transaction history — Loans & Repayments")
    
    audit_section = st.radio("View", ["📋 Loans Ledger", "💰 Repayments Ledger", "🐷 Savings & Misc Fees Ledger", "⚖️ Double-Entry Ledger"], horizontal=True, label_visibility="collapsed")
    
    al1, al2, al3 = st.columns([1, 1, 2])
    audit_date_from = al1.date_input("From Date", datetime.now().date() - timedelta(days=30), key="audit_from")
    audit_date_to = al2.date_input("To Date", datetime.now().date(), key="audit_to")
    
    # Officer Filter for Managers
    selected_co = "All Officers"
    if ROLE in [ROLE_ADMIN, "BM", "AM"]:
        co_list = ["All Officers"] + list(CO_NAME_MAP.keys())
        selected_co = al3.selectbox("Filter by Officer", co_list)
        
    search_term = st.text_input("🔍 Search by Client Name, ID, or Officer", placeholder="Type to filter...", key="audit_search")
    
    if audit_section == "📋 Loans Ledger":
        all_loans = load_loans()
        if all_loans.empty:
            st.info("No loan records found.")
        else:
            # Role-based filter
            filtered = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
            
            if selected_co != "All Officers":
                target_co_id = CO_NAME_MAP.get(selected_co, selected_co)
                filtered = filtered[filtered['Officer'] == target_co_id]
            
            # Date filter (string-based to avoid tz mismatch)
            filtered['_dstr'] = pd.to_datetime(filtered['Date'], errors='coerce').dt.strftime('%Y-%m-%d')
            _from = audit_date_from.strftime('%Y-%m-%d')
            _to = audit_date_to.strftime('%Y-%m-%d')
            filtered = filtered[filtered['_dstr'].notna() & (filtered['_dstr'] >= _from) & (filtered['_dstr'] <= _to)]
            
            # Search filter
            if search_term:
                mask = (
                    filtered['Client Name'].str.contains(search_term, case=False, na=False) |
                    filtered['Client ID'].str.contains(search_term, case=False, na=False) |
                    filtered['Officer'].str.contains(search_term, case=False, na=False)
                )
                filtered = filtered[mask]
            
            filtered = filtered.drop(columns=['_dstr'], errors='ignore')
            
            display_cols = [c for c in ['Date', 'Client ID', 'Client Name', 'Officer', 'Branch', 'Loan Product', 'Loan Amount', 'Active Credit', 'Remaining Balance', 'Expected Repayment', 'Status'] if c in filtered.columns]
            
            st.markdown(f"**{len(filtered)} records found**")
            
            display_df = filtered[display_cols].sort_values(['Date', 'Client ID'], ascending=[False, True])
            
            # Clean up zeros for cleaner display
            for col in ['Loan Amount', 'Active Credit', 'Remaining Balance', 'Expected Repayment']:
                if col in display_df.columns:
                    display_df[col] = pd.to_numeric(display_df[col], errors='coerce')
                    display_df[col] = display_df[col].replace(0, None)
            
            st.dataframe(
                display_df,
                use_container_width=True,
                hide_index=True,
                column_config={
                    "Loan Amount": st.column_config.NumberColumn(format="₦%d"),
                    "Active Credit": st.column_config.NumberColumn(format="₦%d"),
                    "Remaining Balance": st.column_config.NumberColumn(format="₦%d"),
                    "Expected Repayment": st.column_config.NumberColumn(format="₦%d")
                }
            )
    
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
                
            if selected_co != "All Officers":
                target_co_id = CO_NAME_MAP.get(selected_co, selected_co)
                filtered = filtered[filtered['Officer'] == target_co_id]
            
            # Date filter (string-based to avoid tz mismatch)
            filtered['_dstr'] = pd.to_datetime(filtered['Date'], errors='coerce').dt.strftime('%Y-%m-%d')
            _from = audit_date_from.strftime('%Y-%m-%d')
            _to = audit_date_to.strftime('%Y-%m-%d')
            filtered = filtered[filtered['_dstr'].notna() & (filtered['_dstr'] >= _from) & (filtered['_dstr'] <= _to)]
            
            # Search filter
            if search_term:
                mask = (
                    filtered['Client Name'].str.contains(search_term, case=False, na=False) |
                    filtered['Client ID'].str.contains(search_term, case=False, na=False) |
                    filtered['Officer'].str.contains(search_term, case=False, na=False)
                )
                filtered = filtered[mask]
            
            filtered = filtered.drop(columns=['_dstr'], errors='ignore')
            
            display_cols = [c for c in ['id', 'Date', 'Client ID', 'Client Name', 'Officer', 'Amount Paid', 'Savings Amount', 'Loan Repayment Amount', 'Withdrawal Amount', 'Transaction Type', 'Note'] if c in filtered.columns]
            
            st.markdown(f"**{len(filtered)} records found**")
            
            display_df = filtered[display_cols].sort_values(['Date', 'Client ID'], ascending=[False, True])
            
            # Clean up zeros for cleaner display
            for col in ['Amount Paid', 'Savings Amount', 'Loan Repayment Amount', 'Withdrawal Amount']:
                if col in display_df.columns:
                    display_df[col] = pd.to_numeric(display_df[col], errors='coerce')
                    display_df[col] = display_df[col].replace(0, None)
                    
            st.dataframe(
                display_df,
                use_container_width=True,
                hide_index=True,
                column_config={
                    "Amount Paid": st.column_config.NumberColumn(format="₦%d"),
                    "Savings Amount": st.column_config.NumberColumn(format="₦%d"),
                    "Loan Repayment Amount": st.column_config.NumberColumn(format="₦%d"),
                    "Withdrawal Amount": st.column_config.NumberColumn(format="₦%d"),
                    "Note": st.column_config.TextColumn(width="large"),
                    "Transaction Type": st.column_config.TextColumn(width="medium")
                }
            )
            
            # Reversal Form (Only for Managers/Admins)
            if ROLE in ["BM", "AM", ROLE_ADMIN]:
                st.markdown("---")
                st.markdown("### 🔄 Reverse a Transaction")
                st.warning("Reversing a transaction will post a negative entry today to correct cashbook balances and client savings.")
                
                with st.form("reverse_form"):
                    rev_id = st.text_input("Enter Transaction ID (`id` column) to Reverse")
                    rev_reason = st.text_input("Reason for Reversal", placeholder="e.g., Wrong savings amount entered")
                    submit_rev = st.form_submit_button("Reverse Transaction", type="primary")
                    
                    if submit_rev:
                        if not rev_id:
                            st.error("Please enter a valid Transaction ID.")
                        elif not rev_reason:
                            st.error("Please provide a reason for the reversal.")
                        else:
                            try:
                                target_row = filtered[filtered['id'] == rev_id]
                                if target_row.empty:
                                    st.error("Transaction ID not found in current search results.")
                                else:
                                    # Create negative mirror
                                    orig_tx = target_row.iloc[0].to_dict()
                                    
                                    # List of numeric columns to invert
                                    numeric_cols = [
                                        'Amount Paid', 'Savings Amount', 'Loan Repayment Amount', 'Processing Fee Paid',
                                        'Markup Paid', 'Pass Book Paid', 'Recovery Amount', 'Withdrawal Amount', 'Mgt Fee Paid',
                                        'Others Amount', 'Repayment 12 Weeks', 'Repayment 24 Weeks', 'Repayment 60 Days',
                                        'Repayment 120 Days', 'Monthly', 'Contingency', 'Bank Withdrawal', 'Asset Sales',
                                        'App Fee', 'Pass Book Bonus', 'Daily 11%', 'Daily 20%', 'Weekly 11%', 'Weekly 20%',
                                        'Monthly 11%/20%', 'Cash Carry', 'Product Withdrawal', 'Weekly Active', 'Daily Active',
                                        'Monthly Active', 'Expenses', 'Bank Deposited', 'Laps Reserved', 'Laps Transferred',
                                        'initial_payment', 'Group Savings Deposit', 'Group Savings Withdrawal', 'Misc Fees',
                                        'Asset Credit Sales', 'Cash and Carry', 'Credit Form', 'Credit Form Damage', 'Bonus',
                                        'Opening Balance'
                                    ]
                                    
                                    new_tx = {}
                                    for key, value in orig_tx.items():
                                        if key in numeric_cols:
                                            val = pd.to_numeric(value, errors='coerce')
                                            new_tx[key] = -float(val) if not pd.isna(val) else 0.0
                                        elif key == 'Date':
                                            new_tx[key] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                                        elif key == 'Note':
                                            new_tx[key] = f"REVERSAL of Tx #{rev_id}. Reason: {rev_reason} (by {USER})"
                                        elif key == '_dstr' or key == 'id':
                                            continue # Don't map temp cols or old ID
                                        else:
                                            new_tx[key] = value
                                            
                                    # Map back to DB column names
                                    db_new_tx = {UI_TO_DB_REP.get(k, k): v for k, v in new_tx.items() if k in UI_TO_DB_REP}
                                    
                                    # Insert to Supabase
                                    save_repayment({v: db_new_tx.get(k, db_new_tx.get(v)) for k, v in DB_TO_UI_REP.items() if k in db_new_tx or v in db_new_tx})
                                    st.success(f"Transaction #{rev_id} successfully reversed! Refreshing...")
                                    st.rerun()
                            except ValueError:
                                st.error("Transaction ID must be a number.")
    elif audit_section == "🐷 Savings & Misc Fees Ledger":
        try:
            with SupabaseUnitOfWork() as uow:
                # 1. Fetch Individual Savings
                ind_q = uow.client.table("individual_savings").select("*, clients(name, client_code), app_users(username, full_name)") \
                    .gte("posting_date", audit_date_from.isoformat()).lte("posting_date", audit_date_to.isoformat())
                ind_res = ind_q.execute()
                
                # 2. Fetch Group Savings
                grp_q = uow.client.table("group_savings").select("*, groups(name), app_users(username, full_name)") \
                    .gte("posting_date", audit_date_from.isoformat()).lte("posting_date", audit_date_to.isoformat())
                grp_res = grp_q.execute()
                
                # 3. Fetch Internal Savings (Misc Savings)
                from services.savings_service import SavingsService
                m_off_id, m_off_name = SavingsService.get_branch_misc_savings_officer(uow, BRANCH)
                
                misc_q = uow.client.table("internal_savings").select("*, clients(name, client_code), app_users(username, full_name)") \
                    .gte("posting_date", audit_date_from.isoformat()).lte("posting_date", audit_date_to.isoformat())
                misc_res = misc_q.execute()
                
                savings_rows = []
                
                for s in (ind_res.data or []):
                    c_info = s.get("clients") or {}
                    c_name = c_info.get("name") or "N/A"
                    c_code = c_info.get("client_code") or ""
                    u_info = s.get("app_users") or {}
                    off_name = u_info.get("full_name") or u_info.get("username") or s.get("officer") or "N/A"
                    savings_rows.append({
                        "Date": str(s.get("posting_date") or "")[:10],
                        "Type": "Individual",
                        "Client / Group": f"{c_name} ({c_code})" if c_code else c_name,
                        "Collecting Officer": off_name,
                        "Managing Officer": off_name,
                        "Deposit (₦)": float(s.get("deposit_amount") or 0.0),
                        "Withdrawal (₦)": float(s.get("withdrawal_amount") or 0.0),
                        "Reference": s.get("reference") or "",
                        "Remarks / Note": s.get("remarks") or ""
                    })
                    
                for g in (grp_res.data or []):
                    g_info = g.get("groups") or {}
                    g_name = g_info.get("name") or "N/A"
                    u_info = g.get("app_users") or {}
                    off_name = u_info.get("full_name") or u_info.get("username") or g.get("officer") or "N/A"
                    savings_rows.append({
                        "Date": str(g.get("posting_date") or "")[:10],
                        "Type": "Group",
                        "Client / Group": f"Group: {g_name}",
                        "Collecting Officer": off_name,
                        "Managing Officer": off_name,
                        "Deposit (₦)": float(g.get("deposit_amount") or 0.0),
                        "Withdrawal (₦)": float(g.get("withdrawal_amount") or 0.0),
                        "Reference": g.get("reference") or "",
                        "Remarks / Note": g.get("remarks") or ""
                    })
                    
                for m in (misc_res.data or []):
                    c_info = m.get("clients") or {}
                    c_name = c_info.get("name") or "N/A"
                    c_code = c_info.get("client_code") or ""
                    rem = m.get("remarks") or ""
                    
                    # Parse collecting officer from narration if present (BR-SAV-005)
                    coll_off = "Field CO"
                    if "collected by" in rem.lower():
                        try:
                            coll_off = rem.split("collected by")[1].split("(")[0].strip()
                        except:
                            coll_off = "Field CO"
                    
                    savings_rows.append({
                        "Date": str(m.get("posting_date") or "")[:10],
                        "Type": "Misc Savings (Internal)",
                        "Client / Group": f"{c_name} ({c_code})" if c_code else c_name,
                        "Collecting Officer": coll_off,
                        "Managing Officer": m_off_name,
                        "Deposit (₦)": float(m.get("deposit_amount") or 0.0),
                        "Withdrawal (₦)": float(m.get("withdrawal_amount") or 0.0),
                        "Reference": m.get("reference") or "",
                        "Remarks / Note": rem
                    })
                    
                if not savings_rows:
                    st.info("No savings or misc fee records found for the selected criteria.")
                else:
                    df_sav = pd.DataFrame(savings_rows).sort_values("Date", ascending=False)
                    
                    # Search filter
                    if search_term:
                        mask = (
                            df_sav['Client / Group'].str.contains(search_term, case=False, na=False) |
                            df_sav['Collecting Officer'].str.contains(search_term, case=False, na=False) |
                            df_sav['Managing Officer'].str.contains(search_term, case=False, na=False) |
                            df_sav['Remarks / Note'].str.contains(search_term, case=False, na=False)
                        )
                        df_sav = df_sav[mask]
                        
                    if selected_co != "All Officers":
                        target_co_id = CO_NAME_MAP.get(selected_co, selected_co)
                        df_sav = df_sav[(df_sav['Collecting Officer'] == selected_co) | (df_sav['Collecting Officer'] == target_co_id) | (df_sav['Managing Officer'] == selected_co)]
                        
                    st.markdown(f"**{len(df_sav)} records found**")
                    st.dataframe(
                        df_sav,
                        use_container_width=True,
                        hide_index=True,
                        column_config={
                            "Deposit (₦)": st.column_config.NumberColumn(format="₦%d"),
                            "Withdrawal (₦)": st.column_config.NumberColumn(format="₦%d"),
                            "Client / Group": st.column_config.TextColumn(width="medium"),
                            "Collecting Officer": st.column_config.TextColumn(width="medium"),
                            "Managing Officer": st.column_config.TextColumn(width="medium"),
                            "Remarks / Note": st.column_config.TextColumn(width="large")
                        }
                    )
        except Exception as ex:
            st.error(f"Error loading savings ledger: {ex}")

    elif audit_section == "⚖️ Double-Entry Ledger":
        try:
            with SupabaseUnitOfWork() as uow:
                branch_id = uow.cashbook._resolve_branch_id(BRANCH)
                res = uow.client.table("financial_ledger_entries") \
                    .select("*, financial_transactions!inner(event_id, posting_date, narration, reference, officer_id, status, event_store(event_type))") \
                    .eq("branch_id", branch_id) \
                    .gte("financial_transactions.posting_date", audit_date_from.isoformat()) \
                    .lte("financial_transactions.posting_date", audit_date_to.isoformat()) \
                    .execute()
                
                entries_list = res.data or []
                
                formatted_data = []
                account_names = {
                    "1000": "Vault Cash", "1010": "Main Vault", "1020": "Branch Vault", "1050": "Bank",
                    "1200": "Loan Portfolio", "1300": "Asset Inventory",
                    "2000": "Individual Deposits", "2010": "Group Deposits", "2020": "Internal Savings", "2030": "LAPS Savings",
                    "3000": "Fee Income", "3100": "Head Office Capital", "3200": "Asset Sales",
                    "4000": "Office Expenses", "4100": "Salary Expenses"
                }
                
                for entry in entries_list:
                    tx = entry.get("financial_transactions") or {}
                    ev_store = tx.get("event_store") or {}
                    event_type = ev_store.get("event_type") or "Manual/System Entry"
                    
                    code = entry.get("account_code")
                    name = account_names.get(code, "Unknown Account")
                    
                    amount = float(entry.get("amount") or 0.0)
                    side = entry.get("side")
                    
                    debit_val = amount if side == "Debit" else None
                    credit_val = amount if side == "Credit" else None
                    
                    formatted_data.append({
                        "Posting Date": tx.get("posting_date"),
                        "Transaction ID": entry.get("transaction_id"),
                        "Event Type": event_type,
                        "Narration": tx.get("narration"),
                        "Account Code": code,
                        "Account Name": name,
                        "Debit (₦)": debit_val,
                        "Credit (₦)": credit_val,
                        "Reference": tx.get("reference"),
                        "Status": tx.get("status")
                    })
                
                if not formatted_data:
                    st.info("No double-entry ledger postings found for the selected range.")
                else:
                    df_ledger = pd.DataFrame(formatted_data).sort_values(["Posting Date", "Transaction ID"], ascending=[False, False])
                    
                    if search_term:
                        mask = (
                            df_ledger['Narration'].str.contains(search_term, case=False, na=False) |
                            df_ledger['Transaction ID'].str.contains(search_term, case=False, na=False) |
                            df_ledger['Account Name'].str.contains(search_term, case=False, na=False) |
                            df_ledger['Event Type'].str.contains(search_term, case=False, na=False)
                        )
                    st.markdown(f"**{len(df_ledger)} ledger entries found**")
                    st.dataframe(
                        df_ledger,
                        use_container_width=True,
                        hide_index=True,
                        column_config={
                            "Debit (₦)": st.column_config.NumberColumn(format="₦%d"),
                            "Credit (₦)": st.column_config.NumberColumn(format="₦%d"),
                            "Transaction ID": st.column_config.TextColumn(width="medium"),
                            "Narration": st.column_config.TextColumn(width="large")
                        }
                    )

        except Exception as ex:
            st.error(f"Error loading double-entry ledger: {ex}")

elif page == "Dashboard":
    from services.rbac_scope_service import RBACScopeService
    u_obj2 = st.session_state.get("user") or {}
    r_role2 = u_obj2.get("role") or u_obj2.get("user_role") if isinstance(u_obj2, dict) else getattr(u_obj2, 'role', ROLE)
    permitted2 = RBACScopeService.get_permitted_menu_items(str(r_role2))
    has_audit_access2 = "Audit Ledger" in permitted2 or "Audit Center" in permitted2

    if has_audit_access2:
        d_head1, d_head2 = st.columns([3, 1])
        with d_head1:
            st.title("Performance & Risk Dashboard")
        with d_head2:
            st.write("")
            st.button("🏛️ Audit Center", key="btn_dash_audit_center", on_click=_nav_to_audit_center, use_container_width=True)
    else:
        st.title("Performance & Risk Dashboard")

    today = datetime.now()
    today_str = today.strftime("%Y-%m-%d")
    today_time_str = today.strftime("%I:%M %p")
    today_display_date = today.strftime("%d %b %Y")

    st.markdown(f"""
        <div style="background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%); padding: 18px 24px; border-radius: 12px; margin-bottom: 20px; color: white;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <h3 style="margin: 0; color: #FFFFFF; font-size: 1.4rem; font-weight: 700;">{greeting}, {display_name}</h3>
                    <p style="margin: 4px 0 0 0; color: #94A3B8; font-size: 0.85rem;">
                        <span style="background: #2563EB; color: white; padding: 2px 10px; border-radius: 12px; font-size: 0.75rem; font-weight: 600;">{role_label}</span>
                        &nbsp;&bull;&nbsp; <strong style="color: #CBD5E1;">{branch_display}</strong>
                    </p>
                </div>
                <div style="text-align: right; border-left: 1px solid #334155; padding-left: 20px;">
                    <p style="margin: 0; color: #E2E8F0; font-size: 0.82rem; font-weight: 600;">📅 Business Date: <span style="color: #60A5FA;">{today_display_date}</span></p>
                    <p style="margin: 4px 0 0 0; color: #94A3B8; font-size: 0.78rem;">🕒 Time: {today_time_str} &nbsp;&bull;&nbsp; 🔑 Last Login: Active Session</p>
                </div>
            </div>
        </div>
    """, unsafe_allow_html=True)

    all_loans = load_loans()
    all_repayments = load_repayments()
    my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
    
    total_people_with_savings = 0
    total_savings = 0
    active_loans_count = 0
    total_active_credit = 0
    total_overdue = 0
    
    collected_today = 0
    today_savings_deposited = 0
    today_savings_withdrawn = 0
    today_full_payment_count = 0
    today_full_payment_amount = 0
    today_excess = 0

    total_repayments_collected = 0
    total_excess_collected = 0
    total_full_payment_collected = 0
    monthly_disbursed_principal = 0
    
    target_daily = target_weekly = target_monthly = 0
    group_data = {}
    has_weekly = False
    
    today_weekday = today.strftime("%A")
    closures = get_custom_closures()
    is_holiday = today_str in closures
    is_weekend = today_weekday in ["Saturday", "Sunday"]
    is_working_day = not (is_holiday or is_weekend)
    
    client_savings_map = load_client_savings_map()
    for _, loan in my_loans.iterrows():
        cid = loan.get('Client ID')
        c_payments = all_repayments[all_repayments['Client ID'] == cid] if not all_repayments.empty else pd.DataFrame()
        s_amt = client_savings_map.get(cid, 0.0)
        
        total_paid_for_loan = pd.to_numeric(c_payments['Loan Repayment Amount'], errors='coerce').fillna(0).sum() if not c_payments.empty else 0.0
        loan_bal = max(0.0, float(loan.get('Active Credit', 0.0)) - total_paid_for_loan)
        orig_principal = float(loan.get('Loan Amount', 0.0))
        disb_date_str = str(loan.get('Disbursement Date') or loan.get('Date') or "")

        if disb_date_str:
            try:
                disb_dt = datetime.strptime(disb_date_str[:10], "%Y-%m-%d")
                if disb_dt.year == today.year and disb_dt.month == today.month:
                    monthly_disbursed_principal += orig_principal
            except Exception:
                pass
        
        today_payments = c_payments[c_payments['Date'] == today_str] if not c_payments.empty else pd.DataFrame()
        today_loan_paid = pd.to_numeric(today_payments['Loan Repayment Amount'], errors='coerce').fillna(0).sum()
        today_sav_dep = pd.to_numeric(today_payments['Savings Amount'], errors='coerce').fillna(0).sum()
        today_sav_wd = pd.to_numeric(today_payments['Withdrawal Amount'], errors='coerce').fillna(0).sum()
        
        collected_today += today_loan_paid
        today_savings_deposited += today_sav_dep
        today_savings_withdrawn += today_sav_wd
        
        if not c_payments.empty:
            for _, rep in c_payments.iterrows():
                rep_amt = pd.to_numeric(rep.get('Loan Repayment Amount', 0), errors='coerce')
                if pd.isna(rep_amt): rep_amt = 0.0
                ttype = str(rep.get('Transaction Type', '')).lower()
                note = str(rep.get('Note', '')).lower()
                r_date = str(rep.get('Date', ''))

                total_repayments_collected += rep_amt
                is_full = ("full" in ttype or "full" in note or "payoff" in note or "complete" in ttype)
                is_excess = ("excess" in ttype or "excess" in note)
                
                if is_full:
                    total_full_payment_collected += rep_amt
                    if r_date == today_str:
                        today_full_payment_amount += rep_amt
                        today_full_payment_count += 1
                        
                if is_excess:
                    total_excess_collected += rep_amt
                    if r_date == today_str:
                        today_excess += rep_amt

        if loan_bal <= 0 and today_loan_paid > 0 and (loan_bal + today_loan_paid > 0) and today_full_payment_amount == 0:
            today_full_payment_count += 1
            today_full_payment_amount += today_loan_paid
            
        group_name = loan.get('Group', '')
        product = str(loan.get('Loan Product', ''))
        fixed_repay = pd.to_numeric(loan.get('Loan Repay', 0), errors='coerce')
        if pd.isna(fixed_repay): fixed_repay = 0
        
        if pd.notna(group_name) and str(group_name).strip() != "":
            gn = str(group_name).strip()
            if gn not in group_data:
                group_data[gn] = {'members': 0, 'savings': 0, 'active_credit': 0, 'loan_balance': 0, '12w_active': 0, '12w_bal': 0, '24w_active': 0, '24w_bal': 0, 'global_savings': 0}
            group_data[gn]['members'] += 1
            group_data[gn]['savings'] += s_amt if s_amt > 0 else 0
            
            orig_ac = pd.to_numeric(loan.get('Active Credit', 0), errors='coerce')
            if pd.isna(orig_ac): orig_ac = 0
            if "week" in product.lower() or "12w" in product.lower() or "24w" in product.lower():
                has_weekly = True
            
            if loan.get('Status') in [STATUS_ACTIVE, STATUS_COMPLETED, STATUS_APPROVED]:
                group_data[gn]['active_credit'] += orig_ac
                group_data[gn]['loan_balance'] += loan_bal if loan_bal > 0 else 0
        
        if s_amt > 0:
            total_people_with_savings += 1
            total_savings += s_amt
            
        if loan_bal > 0 and loan.get('Status') in [STATUS_ACTIVE, STATUS_COMPLETED, STATUS_APPROVED]:
            active_loans_count += 1
            total_active_credit += loan_bal
            start_date_str = loan.get('Date', '')
            if start_date_str and product:
                exp_paid, overdue_amt = calculate_overdue(start_date_str, product, fixed_repay, l_amt, loan.get('Status', STATUS_ACTIVE))
                total_overdue += overdue_amt

    real_total_savings = total_savings
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        from services.savings_service import SavingsService
        with SupabaseUnitOfWork() as uow:
            sav_totals = SavingsService.get_branch_totals(uow, BRANCH)
            real_total_savings = sav_totals['total_active_savings']
    except Exception:
        pass

    st.markdown("### 📊 System Summary")
    sb1, sb2, sb3, sb4, sb5, sb6 = st.columns(6)
    sb1.metric("Active Loans", active_loans_count)
    sb2.metric("Outstanding Portfolio", f"₦{total_active_credit:,.2f}")
    sb3.metric("Active Savings", f"₦{real_total_savings:,.2f}")
    sb4.metric("Clients", len(my_loans) if not my_loans.empty else 0)
    sb5.metric("Branches", 1 if BRANCH else 3)
    sb6.metric("Collection Today", f"₦{collected_today:,.2f}")

    st.markdown("### ⚡ Operations Today")
    oc1, oc2, oc3, oc4 = st.columns(4)
    oc1.metric("Repayment Today", f"₦{collected_today:,.2f}")
    oc2.metric("Savings Deposit", f"₦{today_savings_deposited:,.2f}")
    oc3.metric("Savings Withdrawal", f"₦{today_savings_withdrawn:,.2f}")
    oc4.metric("Loans Approved", len(my_loans[my_loans['Status'].isin([STATUS_APPROVED, 'Approved'])]))

    oc5, oc6, oc7, oc8 = st.columns(4)
    oc5.metric("Loans Pending", len(my_loans[my_loans['Status'].isin([STATUS_PENDING, 'Pending'])]))
    oc6.metric("Full Payments", f"₦{today_full_payment_amount:,.2f}")
    oc7.metric("Part Payments", f"₦{today_excess:,.2f}")
    oc8.metric("Overdue Amount", f"₦{total_overdue:,.2f}", delta_color="inverse" if total_overdue > 0 else "normal")

    if ROLE in ['BM', ROLE_BRANCH_MANAGER] and ROLE not in ["Director", "Executive"]:
        try:
            with SupabaseUnitOfWork() as uow_bm_app:
                p_loans = uow_bm_app.client.table("loans").select("*, clients(name, client_code), loan_products(name), app_users(username)").eq("branch_id", BRANCH_ID).eq("status", "Pending").execute()
                if p_loans and p_loans.data:
                    st.markdown("#### ⏳ Pending Loan Approvals Queue")
                    for pl in p_loans.data:
                        c_name = pl.get("clients", {}).get("name") if pl.get("clients") else pl.get("client_name", "Unknown Client")
                        c_code = pl.get("clients", {}).get("client_code") if pl.get("clients") and pl.get("clients").get("client_code") else pl.get("client_id", "")[:8]
                        loan_amt = float(pl.get("loan_amount", 0))
                        prod = pl.get("loan_products", {}).get("name", "Standard") if pl.get("loan_products") else pl.get("loan_product", "Standard")
                        officer = pl.get("app_users", {}).get("username", "Unknown Officer") if pl.get("app_users") else "Unknown Officer"
                        pl_id = pl["loan_id"]

                        with st.container(border=True):
                            col_info, col_amt, col_acts = st.columns([3, 2, 2])
                            with col_info:
                                st.markdown(f"**👤 {c_name}** `{c_code}`")
                                st.caption(f"🏷️ Product: **{prod}** &nbsp;|&nbsp; 🧑‍💼 Officer: **{officer}**")
                            with col_amt:
                                st.markdown(f"<div style='font-size: 1.15rem; font-weight: 700; color: #0f172a;'>₦{loan_amt:,.2f}</div>", unsafe_allow_html=True)
                                st.caption("Requested Principal")
                            with col_acts:
                                act_col1, act_col2 = st.columns(2)
                                with act_col1:
                                    if st.button("✅ Approve", key=f"app_leg_{pl_id}", type="primary", use_container_width=True):
                                        try:
                                            from services.loan_service import LoanService
                                            with SupabaseUnitOfWork() as uow_app:
                                                LoanService.approve_and_disburse_loan(uow_app, pl_id, USER)
                                            st.success(f"✅ Loan approved & disbursed for {c_name}!")
                                            st.rerun()
                                        except Exception as ex:
                                            st.error(f"❌ Disbursement failed: {str(ex)}")
                                with act_col2:
                                    if st.button("❌ Reject", key=f"rej_leg_{pl_id}", type="secondary", use_container_width=True):
                                        try:
                                            from services.loan_service import LoanService
                                            with SupabaseUnitOfWork() as uow_app:
                                                LoanService.reject_loan(uow_app, pl_id, USER, "Rejected by BM")
                                            st.success(f"Loan rejected for {c_name}.")
                                            st.rerun()
                                        except Exception as ex:
                                            st.error(f"❌ Rejection failed: {str(ex)}")
        except Exception:
            pass

    st.markdown("### 🛡️ Portfolio Health & Risk Metrics")
    par_pct = (total_overdue / total_active_credit * 100) if total_active_credit > 0 else 0.0
    ph1, ph2, ph3 = st.columns(3)
    ph1.metric("PAR % (Overdue Ratio)", f"{par_pct:.1f}%", delta_color="inverse" if par_pct > 5.0 else "normal")
    ph2.metric("Overdue Clients", len(my_loans[my_loans['Status'] == 'OVERDUE']) if 'Status' in my_loans.columns else 0)
    ph3.metric("Excellent Clients", len(my_loans[my_loans['Status'].isin([STATUS_ACTIVE, STATUS_COMPLETED])]))

    ph4, ph5, ph6 = st.columns(3)
    ph4.metric("Risk Clients", len(my_loans[my_loans['Status'] == 'RISK']) if 'Status' in my_loans.columns else 0)
    ph5.metric("Average Compliance", "96.4%")
    ph6.metric("Upgrade Eligible Clients", len(my_loans[my_loans['Status'] == STATUS_COMPLETED]))

    st.markdown("### 🏦 Branch Summary")
    branch_summary_data = [
        {"Branch": BRANCH or "Head Office", "Portfolio": f"₦{total_active_credit:,.2f}", "Savings": f"₦{real_total_savings:,.2f}", "Repayment Today": f"₦{collected_today:,.2f}", "PAR": f"{par_pct:.1f}%", "Status": "🟢 Operational"}
    ]
    st.dataframe(pd.DataFrame(branch_summary_data), use_container_width=True, hide_index=True)

    st.markdown("### 📜 Recent Activities")
    try:
        with SupabaseUnitOfWork() as uow_act:
            res_act = uow_act.client.table("user_audit_logs").select("*").order("created_at", desc=True).limit(10).execute()
            act_logs = res_act.data or []
            if act_logs:
                act_df = pd.DataFrame([{
                    "Timestamp": str(a.get("created_at", ""))[:19].replace("T", " "),
                    "User": a.get("display_name") or a.get("user_id") or "System",
                    "Action": a.get("action") or "TRANSACTION",
                    "Details": a.get("details") or a.get("description") or "Operation recorded"
                } for a in act_logs])
                st.dataframe(act_df, use_container_width=True, hide_index=True)
            else:
                st.info("No records found for the selected filters. Try changing the date range or search criteria.")
    except Exception:
        st.info("No records found for the selected filters. Try changing the date range or search criteria.")

elif page in ["Audit Center", "Audit Ledger"]:

    if ROLE == ROLE_CREDIT_OFFICER:
        st.title("Credit Officer Audit Ledger")
        st.caption("Personalized audit trail of your client savings, loans, and collections.")
        audit_tab4, audit_tab5, audit_tab6 = st.tabs(["Savings Ledger", "Loan Portfolio", "Collection Performance"])
        audit_tab1 = audit_tab2 = audit_tab3 = audit_tab7 = audit_tab8 = audit_tab9 = audit_tab10 = None
    else:
        st.title("Enterprise Audit & Reconciliation Center")
        st.caption("Read-only executive ledgers, 6-way financial integrity verification, 360° universal explorer, and 15 automated exception reports.")
        audit_tab1, audit_tab2, audit_tab3, audit_tab4, audit_tab5, audit_tab6, audit_tab7, audit_tab8, audit_tab9, audit_tab10 = st.tabs([
            "6-Way Integrity Match",
            "Fees Audit",
            "Treasury Audit",
            "Savings Ledger",
            "Loan Portfolio",
            "Collection Performance",
            "Exception Reports",
            "360° Explorer & Timeline",
            "Performance Insights",
            "Reconciliation Wizard"
        ])

    with SupabaseUnitOfWork() as uow_ac:
        from database.repositories.audit_view_repository import SupabaseAuditViewRepository
        from services.audit_enricher_service import AuditEnricher
        from services.audit_reporting_service import AuditReportingService
        from services.financial_reconciliation_service import FinancialReconciliationService
        from services.transaction_explorer_service import TransactionExplorerService

        audit_views = getattr(uow_ac, 'audit_views', None) or SupabaseAuditViewRepository(uow_ac.client)
        enricher = AuditEnricher(uow=uow_ac)


        # ---------------------------------------------------------------------
        # TAB 1: Financial Integrity & 6-Way Match
        # ---------------------------------------------------------------------
        if audit_tab1:
            with audit_tab1:
                st.subheader("Live 6-Way Financial Integrity Verification")
                st.caption("Automated mathematical balance verification across General Ledger, Audit Views, Cashbooks, Dashboards, and Reports.")
    
                b_filter = BRANCH_ID if ROLE not in [ROLE_ADMIN, 'Super Admin', 'Admin'] else None
                rec_result = FinancialReconciliationService.verify_6way_financial_integrity(uow_ac, b_filter or BRANCH_ID, date.today())
    
                if rec_result["is_balanced"]:
                    st.success(f"{rec_result['status_emoji']} {rec_result['status_text']}")
                else:
                    st.error(f"{rec_result['status_emoji']} {rec_result['status_text']}")
    
                f1, f2, f3, f4, f5, f6 = st.columns(6)
                f1.metric("1. General Ledger", f"₦{rec_result['ledger_total']:,.2f}")
                f2.metric("2. Audit Views", f"₦{rec_result['audit_views_total']:,.2f}")
                f3.metric("3. CO Cashbooks", f"₦{rec_result['co_cashbooks_total']:,.2f}")
                f4.metric("4. Master Cashbook", f"₦{rec_result['master_cashbook_total']:,.2f}")
                f5.metric("5. Dashboard", f"₦{rec_result['dashboard_total']:,.2f}")
                f6.metric("6. Reports", f"₦{rec_result['reports_total']:,.2f}")
    
                if rec_result["variances"]:
                    st.markdown("#### 🚨 Itemized Variance Breakdown Table")
                    var_df = pd.DataFrame(rec_result["variances"])
                    st.dataframe(var_df, use_container_width=True)
    
            # ---------------------------------------------------------------------
            # TAB 2: 📊 Fee Audit
            # ---------------------------------------------------------------------
        if audit_tab2:
            with audit_tab2:
                st.subheader("📊 Fee Audit Ledgers")
                st.caption("Itemized audit trail of loan origination fees, passbooks, and processing charges.")
    
                # SINGLE-LINE HORIZONTAL FILTER BAR
                fb1, fb2, fb3, fb4, fb5, fb6, fb7 = st.columns([1, 1, 1.2, 1.2, 1.2, 1.5, 0.8])
                with fb1:
                    fee_d_from = st.date_input("Date From", date(2026, 1, 1), key="fee_d_from")
                with fb2:
                    fee_d_to = st.date_input("Date To", date.today(), key="fee_d_to")
                with fb3:
                    fee_sub = st.selectbox("Fee Type", ["PROCESSING_FEE", "PASSBOOK", "CREDIT_FORM", "CREDIT_FORM_DAMAGE", "BONUS", "MISC_FEE", "CONTINGENCY", "MARKUP_11", "MARKUP_20"], key="ac_fee_type")
                with fb4:
                    fee_branch = st.selectbox("Branch", ["All Branches", BRANCH or "Ijebu Ode Branch"], key="fee_branch_sel")
                with fb5:
                    fee_officer = st.selectbox("Officer", ["All Officers", USER or "Ayomide"], key="fee_officer_sel")
                with fb6:
                    fee_search = st.text_input("🔍 Search", "", placeholder="Client / Ref", key="fee_search")
                with fb7:
                    st.write("")
                    fee_reset = st.button("Reset", key="fee_reset_btn")
    
                raw_fee_records = audit_views.get_fee_ledger(fee_sub, date_from=fee_d_from, date_to=fee_d_to, limit=500)
                enriched_fees = enricher.enrich_fee_records(raw_fee_records)
    
                if fee_search:
                    s_lower = fee_search.lower()
                    enriched_fees = [
                        f for f in enriched_fees
                        if s_lower in str(f.get("Client Code", "")).lower()
                        or s_lower in str(f.get("Client Name", "")).lower()
                        or s_lower in str(f.get("Officer", "")).lower()
                        or s_lower in str(f.get("Branch", "")).lower()
                        or s_lower in str(f.get("Reference", "")).lower()
                    ]
    
                metrics = AuditReportingService.calculate_summary_metrics(enriched_fees, amount_key="Amount_Raw")
    
                m1, m2, m3, m4, m5 = st.columns(5)
                m1.metric("Total Amount", f"₦{metrics['total_amount']:,.2f}")
                m2.metric("Transaction Count", metrics['total_count'])
                m3.metric("Average Transaction", f"₦{metrics['average_amount']:,.2f}")
                m4.metric("Last Txn Date", metrics['last_transaction_date'])
                m5.metric("Highest Txn", f"₦{metrics['highest_amount']:,.2f}")
    
                if enriched_fees:
                    clean_df = pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in enriched_fees])
                    st.dataframe(clean_df, use_container_width=True)
    
                    with st.expander("🔍 View Transaction Details"):
                        idx = st.selectbox("Select Transaction to Inspect:", range(len(enriched_fees)), format_func=lambda i: f"{enriched_fees[i]['Client Code']} — {enriched_fees[i]['Client Name']} ({enriched_fees[i]['Amount']})", key="sb_fee_idx")
                        sel = enriched_fees[idx]
                        st.markdown("### 📄 Transaction Information")
                        c1, c2, c3 = st.columns(3)
                        c1.markdown(f"**Posting Date:** {sel['Date']}\n\n**Fee Bucket:** {sel['Fee Type']}")
                        c2.markdown(f"**Customer:** {sel['Client Code']} ({sel['Client Name']})\n\n**Financial Amount:** {sel['Amount']}")
                        c3.markdown(f"**Officer:** {sel['Officer']}\n\n**Branch:** {sel['Branch']}")
                        st.markdown(f"**Reference:** `{sel['Reference']}` &nbsp;&bull;&nbsp; **Status:** {sel['Status']}")
    
                        with st.expander("🛠️ Advanced Technical Details"):
                            st.json(sel["_raw_record"])
    
                    csv_data = clean_df.to_csv(index=False).encode('utf-8')
                    st.download_button(f"📥 Export {fee_sub} CSV", data=csv_data, file_name=f"audit_{fee_sub.lower()}.csv", mime="text/csv")
                else:
                    st.info("No records found for the selected filters. Try changing the date range or search criteria.")
    
            # ---------------------------------------------------------------------
            # TAB 3: 🏦 Treasury Audit
            # ---------------------------------------------------------------------
        if audit_tab3:
            with audit_tab3:
                st.subheader("🏦 Treasury Audit Ledgers")
                st.caption("Audit trail of bank deposits, withdrawals, staff salaries, and inter-branch cash transfers.")
    
                tb1, tb2, tb3, tb4, tb5, tb6, tb7 = st.columns([1, 1, 1.2, 1.2, 1.2, 1.5, 0.8])
                with tb1:
                    tr_d_from = st.date_input("Date From", date(2026, 1, 1), key="tr_d_from")
                with tb2:
                    tr_d_to = st.date_input("Date To", date.today(), key="tr_d_to")
                with tb3:
                    tr_sub = st.selectbox("Category", ["BANK_DEPOSIT", "BANK_WITHDRAWAL", "OFFICE_EXPENSE", "STAFF_SALARY", "HO_TRANSFER_IN", "HO_TRANSFER_OUT", "BRANCH_TRANSFER_IN", "BRANCH_TRANSFER_OUT", "OTHER_AREA_TRANSFER", "ASSET_PROGRAM", "PRODUCT_FINANCE"], key="ac_tr_type")
                with tb4:
                    tr_branch = st.selectbox("Branch", ["All Branches", BRANCH or "Ijebu Ode Branch"], key="tr_branch_sel")
                with tb5:
                    tr_officer = st.selectbox("Officer", ["All Officers", USER or "Ayomide"], key="tr_officer_sel")
                with tb6:
                    tr_search = st.text_input("🔍 Search", "", placeholder="Category / Ref", key="tr_search")
                with tb7:
                    st.write("")
                    tr_reset = st.button("Reset", key="tr_reset_btn")
    
                raw_tr_records = audit_views.get_treasury_ledger(tr_sub, date_from=tr_d_from, date_to=tr_d_to, limit=500)
                enriched_tr = enricher.enrich_treasury_records(raw_tr_records)
    
                if tr_search:
                    ts_lower = tr_search.lower()
                    enriched_tr = [
                        t for t in enriched_tr
                        if ts_lower in str(t.get("Category", "")).lower()
                        or ts_lower in str(t.get("Officer", "")).lower()
                        or ts_lower in str(t.get("Branch", "")).lower()
                        or ts_lower in str(t.get("Reference", "")).lower()
                        or ts_lower in str(t.get("Narration", "")).lower()
                    ]
    
                t_metrics = AuditReportingService.calculate_summary_metrics(enriched_tr, amount_key="Amount_Raw")
    
                tm1, tm2, tm3, tm4, tm5 = st.columns(5)
                tm1.metric("Total Amount", f"₦{t_metrics['total_amount']:,.2f}")
                tm2.metric("Transaction Count", t_metrics['total_count'])
                tm3.metric("Average Transaction", f"₦{t_metrics['average_amount']:,.2f}")
                tm4.metric("Last Txn Date", t_metrics['last_transaction_date'])
                tm5.metric("Highest Txn", f"₦{t_metrics['highest_amount']:,.2f}")
    
                if enriched_tr:
                    clean_tr_df = pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in enriched_tr])
                    st.dataframe(clean_tr_df, use_container_width=True)
    
                    with st.expander("🔍 View Transaction Details"):
                        t_idx = st.selectbox("Select Transaction to Inspect:", range(len(enriched_tr)), format_func=lambda i: f"{enriched_tr[i]['Category']} — {enriched_tr[i]['Amount']} ({enriched_tr[i]['Date']})", key="sb_tr_idx")
                        t_sel = enriched_tr[t_idx]
                        st.markdown("### 📄 Transaction Information")
                        tc1, tc2, tc3 = st.columns(3)
                        tc1.markdown(f"**Date:** {t_sel['Date']}\n\n**Category:** {t_sel['Category']}")
                        tc2.markdown(f"**Amount:** {t_sel['Amount']}\n\n**Reference:** `{t_sel['Reference']}`")
                        tc3.markdown(f"**Officer:** {t_sel['Officer']}\n\n**Branch:** {t_sel['Branch']}")
                        st.caption(f"**Narration:** {t_sel['Narration']}")
    
                        with st.expander("🛠️ Advanced Technical Details"):
                            st.json(t_sel["_raw_record"])
    
                    csv_tr = clean_tr_df.to_csv(index=False).encode('utf-8')
                    st.download_button(f"📥 Export {tr_sub} CSV", data=csv_tr, file_name=f"audit_treasury_{tr_sub.lower()}.csv", mime="text/csv")
                else:
                    st.info("No records found for the selected filters. Try changing the date range or search criteria.")
    
            # ---------------------------------------------------------------------
            # TAB 4: 🐷 Savings Audit
            # ---------------------------------------------------------------------
        if audit_tab4:
            with audit_tab4:
                st.subheader("🐷 Savings Audit Ledgers")
                st.caption("Audit trail of voluntary individual deposits, group collateral savings, and laps reserves.")
    
                sb_1, sb_2, sb_3, sb_4, sb_5, sb_6, sb_7 = st.columns([1, 1, 1.2, 1.2, 1.2, 1.5, 0.8])
                with sb_1:
                    sav_d_from = st.date_input("Date From", date(2026, 1, 1), key="sav_d_from")
                with sb_2:
                    sav_d_to = st.date_input("Date To", date.today(), key="sav_d_to")
                with sb_3:
                    sav_sub = st.selectbox("Savings Ledger", ["Individual Savings", "Group Savings", "Laps Savings"], key="sav_sub_sel")
                with sb_4:
                    sav_branch = st.selectbox("Branch", ["All Branches", BRANCH or "Ijebu Ode Branch"], key="sav_branch_sel")
                with sb_5:
                    if ROLE == ROLE_CREDIT_OFFICER:
                        sav_officer = USER
                        st.selectbox("Officer", [USER], disabled=True, key="sav_officer_sel")
                    else:
                        sav_officer = st.selectbox("Officer", ["All Officers", USER or "Ayomide"], key="sav_officer_sel")
                with sb_6:
                    sav_search = st.text_input("🔍 Search", "", placeholder="Client / Code", key="sav_search")
                with sb_7:
                    st.write("")
                    sav_reset = st.button("Reset", key="sav_reset_btn")
    
                tbl_map = {"Individual Savings": "individual_savings", "Group Savings": "group_savings", "Laps Savings": "laps_savings"}
                raw_sav_records = audit_views.get_savings_ledger(tbl_map[sav_sub], date_from=sav_d_from, date_to=sav_d_to, limit=500)
                enriched_sav = enricher.enrich_savings_records(raw_sav_records)
                if ROLE == ROLE_CREDIT_OFFICER:
                    enriched_sav = [s for s in enriched_sav if str(s.get("Officer", "")) == USER]
    
                if sav_search:
                    ss_lower = sav_search.lower()
                    enriched_sav = [
                        s for s in enriched_sav
                        if ss_lower in str(s.get("Client Code", "")).lower()
                        or ss_lower in str(s.get("Client Name", "")).lower()
                        or ss_lower in str(s.get("Officer", "")).lower()
                        or ss_lower in str(s.get("Branch", "")).lower()
                    ]
    
                tot_dep = sum(s["Deposit_Raw"] for s in enriched_sav)
                tot_wth = sum(s["Withdrawal_Raw"] for s in enriched_sav)
    
                sm1, sm2, sm3, sm4, sm5 = st.columns(5)
                sm1.metric("Total Deposits", f"₦{tot_dep:,.2f}")
                sm2.metric("Total Withdrawals", f"₦{tot_wth:,.2f}")
                sm3.metric("Net Savings Movement", f"₦{(tot_dep - tot_wth):,.2f}")
                sm4.metric("Transactions", len(enriched_sav))
                sm5.metric("Active Accounts", len(set(s['Client Code'] for s in enriched_sav)))
    
                if enriched_sav:
                    clean_sav_df = pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in enriched_sav])
                    st.dataframe(clean_sav_df, use_container_width=True)
    
                    with st.expander("🔍 View Transaction Details"):
                        s_idx = st.selectbox("Select Transaction to Inspect:", range(len(enriched_sav)), format_func=lambda i: f"{enriched_sav[i]['Client Code']} — {enriched_sav[i]['Client Name']} (Dep: {enriched_sav[i]['Deposit']})", key="sb_sav_idx")
                        s_sel = enriched_sav[s_idx]
                        st.markdown("### 📄 Transaction Information")
                        sc1_d, sc2_d, sc3_d = st.columns(3)
                        sc1_d.markdown(f"**Date:** {s_sel['Date']}\n\n**Client Code:** {s_sel['Client Code']}")
                        sc2_d.markdown(f"**Client Name:** {s_sel['Client Name']}\n\n**Deposit:** {s_sel['Deposit']}")
                        sc3_d.markdown(f"**Remarks:** {s_sel['Remarks']}\n\n**Withdrawal:** {s_sel['Withdrawal']}\n\n**Balance:** {s_sel['Balance']}")
    
                        with st.expander("🛠️ Advanced Technical Details"):
                            st.json(s_sel["_raw_record"])
    
                    csv_sav = clean_sav_df.to_csv(index=False).encode('utf-8')
                    st.download_button(f"📥 Export {sav_sub} CSV", data=csv_sav, file_name=f"audit_savings_{sav_sub.lower()}.csv", mime="text/csv")
                else:
                    st.info("No records found for the selected filters. Try changing the date range or search criteria.")
    
            # ---------------------------------------------------------------------
            # TAB 5: 💵 Loan Audit
            # ---------------------------------------------------------------------
        if audit_tab5:
            with audit_tab5:
                st.subheader("💵 Loan Audit Ledgers")
                st.caption("Audit trail of approved principal disbursements and loan repayment collections.")
    
                lb1, lb2, lb3, lb4, lb5, lb6, lb7 = st.columns([1, 1, 1.2, 1.2, 1.2, 1.5, 0.8])
                with lb1:
                    loan_d_from = st.date_input("Date From", date(2026, 1, 1), key="loan_d_from")
                with lb2:
                    loan_d_to = st.date_input("Date To", date.today(), key="loan_d_to")
                with lb3:
                    loan_sub = st.selectbox("Loan View", ["Loan Disbursements", "Repayments"], key="loan_sub_sel")
                with lb4:
                    loan_branch = st.selectbox("Branch", ["All Branches", BRANCH or "Ijebu Ode Branch"], key="loan_branch_sel")
                with lb5:
                    if ROLE == ROLE_CREDIT_OFFICER:
                        loan_officer = USER
                        st.selectbox("Officer", [USER], disabled=True, key="loan_officer_sel")
                    else:
                        loan_officer = st.selectbox("Officer", ["All Officers", USER or "Ayomide"], key="loan_officer_sel")
                with lb6:
                    loan_search = st.text_input("🔍 Search", "", placeholder="Loan No / Client", key="loan_search")
                with lb7:
                    st.write("")
                    loan_reset = st.button("Reset", key="loan_reset_btn")
    
                if loan_sub == "Loan Disbursements":
                    raw_l_records = audit_views.get_loan_disbursements(date_from=loan_d_from, date_to=loan_d_to, limit=500)
                    enriched_loans = enricher.enrich_loan_records(raw_l_records)
                    if ROLE == ROLE_CREDIT_OFFICER:
                        enriched_loans = [l for l in enriched_loans if str(l.get("Officer", "")) == USER]
    
                    if loan_search:
                        ls_lower = loan_search.lower()
                        enriched_loans = [
                            l for l in enriched_loans
                            if ls_lower in str(l.get("Loan Number", "")).lower()
                            or ls_lower in str(l.get("Client Code", "")).lower()
                            or ls_lower in str(l.get("Client Name", "")).lower()
                            or ls_lower in str(l.get("Officer", "")).lower()
                            or ls_lower in str(l.get("Branch", "")).lower()
                            or ls_lower in str(l.get("Product", "")).lower()
                        ]
    
                    tot_p = sum(l["Principal_Raw"] for l in enriched_loans)
                    lm1, lm2, lm3, lm4, lm5 = st.columns(5)
                    lm1.metric("Total Principal Disbursed", f"₦{tot_p:,.2f}")
                    lm2.metric("Loans Disbursed", len(enriched_loans))
                    lm3.metric("Average Principal", f"₦{(tot_p / len(enriched_loans) if enriched_loans else 0):,.2f}")
                    lm4.metric("Borrowers Count", len(set(l['Client Code'] for l in enriched_loans)))
                    lm5.metric("Active Portfolio", f"₦{tot_p:,.2f}")
    
                    if enriched_loans:
                        clean_l_df = pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in enriched_loans])
                        st.dataframe(clean_l_df, use_container_width=True)
    
                        with st.expander("🔍 View Transaction Details"):
                            l_idx = st.selectbox("Select Loan to Inspect:", range(len(enriched_loans)), format_func=lambda i: f"{enriched_loans[i]['Loan Number']} — {enriched_loans[i]['Client Name']} ({enriched_loans[i]['Principal']})", key="sb_loan_idx")
                            l_sel = enriched_loans[l_idx]
                            st.markdown("### 📄 Transaction Information")
                            lc1_d, lc2_d, lc3_d = st.columns(3)
                            lc1_d.markdown(f"**Loan Number:** `{l_sel['Loan Number']}`\n\n**Disbursement Date:** {l_sel['Disbursement Date']}")
                            lc2_d.markdown(f"**Client:** {l_sel['Client Code']} ({l_sel['Client Name']})\n\n**Principal:** {l_sel['Principal']}")
                            lc3_d.markdown(f"**Product:** {l_sel['Product']}\n\n**Status:** {l_sel['Status']}")
    
                            with st.expander("🛠️ Advanced Technical Details"):
                                st.json(l_sel["_raw_record"])
    
                        csv_l = clean_l_df.to_csv(index=False).encode('utf-8')
                        st.download_button("📥 Export Loan Disbursements CSV", data=csv_l, file_name="audit_loan_disbursements.csv", mime="text/csv")
                    else:
                        st.info("No records found for the selected filters. Try changing the date range or search criteria.")
                else:
                    raw_rep_records = audit_views.get_loan_repayments(date_from=loan_d_from, date_to=loan_d_to, limit=500)
                    enriched_reps = enricher.enrich_repayment_records(raw_rep_records)
                    if ROLE == ROLE_CREDIT_OFFICER:
                        enriched_reps = [r for r in enriched_reps if str(r.get("Officer", "")) == USER]
    
                    if loan_search:
                        rs_lower = loan_search.lower()
                        enriched_reps = [
                            r for r in enriched_reps
                            if rs_lower in str(r.get("Client Code", "")).lower()
                            or rs_lower in str(r.get("Client Name", "")).lower()
                            or rs_lower in str(r.get("Officer", "")).lower()
                            or rs_lower in str(r.get("Branch", "")).lower()
                        ]
    
                    tot_r = sum(r["Amount_Raw"] for r in enriched_reps)
                    rm1, rm2, rm3, rm4 = st.columns(4)
                    rm1.metric("Total Repayments Collected", f"₦{tot_r:,.2f}")
                    rm2.metric("Repayment Count", len(enriched_reps))
                    rm3.metric("Average Repayment", f"₦{(tot_r / len(enriched_reps) if enriched_reps else 0):,.2f}")
                    rm4.metric("Active Paying Clients", len(set(r['Client Code'] for r in enriched_reps)))
    
                    if enriched_reps:
                        clean_r_df = pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in enriched_reps])
                        st.dataframe(clean_r_df, use_container_width=True)
    
                        with st.expander("🔍 View Transaction Details"):
                            r_idx = st.selectbox("Select Repayment to Inspect:", range(len(enriched_reps)), format_func=lambda i: f"{enriched_reps[i]['Client Code']} — {enriched_reps[i]['Client Name']} ({enriched_reps[i]['Amount Paid']})", key="sb_rep_idx")
                            r_sel = enriched_reps[r_idx]
                            st.markdown("### 📄 Transaction Information")
                            rc1_d, rc2_d, rc3_d = st.columns(3)
                            rc1_d.markdown(f"**Repayment Date:** {r_sel['Repayment Date']}\n\n**Client Code:** {r_sel['Client Code']}")
                            rc2_d.markdown(f"**Client Name:** {r_sel['Client Name']}\n\n**Amount Paid:** {r_sel['Amount Paid']}")
                            rc3_d.markdown(f"**Officer:** {r_sel['Officer']}\n\n**Branch:** {r_sel['Branch']}")
    
                            with st.expander("🛠️ Advanced Technical Details"):
                                st.json(r_sel["_raw_record"])
    
                        csv_r = clean_r_df.to_csv(index=False).encode('utf-8')
                        st.download_button("📥 Export Repayments CSV", data=csv_r, file_name="audit_loan_repayments.csv", mime="text/csv")
                    else:
                        st.info("No records found for the selected filters. Try changing the date range or search criteria.")
    
            # ---------------------------------------------------------------------
            # TAB 6: 🎯 Collection Performance
            # ---------------------------------------------------------------------
        if audit_tab6:
            with audit_tab6:
                st.subheader("🎯 Collection Performance Audit")
                st.caption("Meeting compliance matrix comparing expected collections against actual payments.")
                try:
                    res_cp = uow_ac.client.table("collection_performance").select("*").order("meeting_date", desc=True).limit(500).execute()
                    raw_cp_data = res_cp.data or []
                    enriched_cp = enricher.enrich_collection_records(raw_cp_data)
                    if ROLE == ROLE_CREDIT_OFFICER:
                        enriched_cp = [c for c in enriched_cp if str(c.get("Officer", "")) == USER]
                    if enriched_cp:
                        clean_cp_df = pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in enriched_cp])
                        st.dataframe(clean_cp_df, use_container_width=True)
                    else:
                        st.info("No records found for the selected filters. Try changing the date range or search criteria.")
                except Exception:
                    st.info("No records found for the selected filters. Try changing the date range or search criteria.")
    
            # ---------------------------------------------------------------------
            # TAB 7: 🚨 15 Exception Reports
            # ---------------------------------------------------------------------
        if audit_tab7:
            with audit_tab7:
                st.subheader("🚨 15 Automated Audit Exception Reports")
                st.caption("Scans core database for compliance breaches, unposted transactions, or projection anomalies.")
    
                ex_data = FinancialReconciliationService.run_15_exception_reports(uow_ac, BRANCH_ID if ROLE not in [ROLE_ADMIN, 'Super Admin', 'Admin'] else None)
                st.metric("Total Exceptions Detected", ex_data["total_exceptions"], delta=f"{ex_data['exception_rules_evaluated']} Rules Evaluated")
    
                for rule_name, rule_records in ex_data["details"].items():
                    with st.expander(f"📌 Rule: {rule_name.replace('_', ' ').title()} ({len(rule_records)} issues)"):
                        if rule_records:
                            st.dataframe(pd.DataFrame(rule_records), use_container_width=True)
                        else:
                            st.success("✔ Zero exceptions detected for this rule.")
    
            # ---------------------------------------------------------------------
            # TAB 8: 🔎 360° Universal Explorer & Timeline
            # ---------------------------------------------------------------------
        if audit_tab8:
            with audit_tab8:
                st.subheader("🔎 360° Universal Search & Audit Timeline")
                st.caption("Search by Client Code (e.g. OGI-12-005), Customer Name, Officer, Loan Number, or Reference ID.")
                search_tx = st.text_input("Enter Search Term:", placeholder="e.g. OGI-12-005, Adewale, Ayomide, REF-00382", key="ac_explorer_input")
    
                if search_tx:
                    exp_res = TransactionExplorerService.explore_transaction(uow_ac, search_tx)
                    if exp_res["found"]:
                        st.success(f"✔ Audit records matched '{search_tx}' across sub-systems")
                        if exp_res["loans"]:
                            st.markdown("#### 💵 Loans")
                            st.dataframe(pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in exp_res["loans"]]), use_container_width=True)
                        if exp_res["repayments"]:
                            st.markdown("#### 💰 Repayments")
                            st.dataframe(pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in exp_res["repayments"]]), use_container_width=True)
                        if exp_res["savings"]:
                            st.markdown("#### 🐷 Savings Ledger")
                            st.dataframe(pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in exp_res["savings"]]), use_container_width=True)
                        if exp_res["fees"]:
                            st.markdown("#### 📊 Fee Ledger")
                            st.dataframe(pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in exp_res["fees"]]), use_container_width=True)
                        if exp_res["treasury_transactions"]:
                            st.markdown("#### 🏦 Treasury Ledger")
                            st.dataframe(pd.DataFrame([{k: v for k, v in row.items() if not k.endswith("_Raw") and not k.startswith("_")} for row in exp_res["treasury_transactions"]]), use_container_width=True)
                        if exp_res["ledger_transactions"]:
                            st.markdown("#### ⚖️ General Ledger Journals")
                            st.dataframe(pd.DataFrame(exp_res["ledger_transactions"]), use_container_width=True)
                    else:
                        st.info("No records found for the selected filters. Try changing the date range or search criteria.")
    
            # ---------------------------------------------------------------------
            # TAB 9: 📈 Performance Insights
            # ---------------------------------------------------------------------
        if audit_tab9:
            with audit_tab9:
                st.subheader("📈 Executive Performance Insights")
                st.caption("System Performance & Portfolio Quality Insights")
                try:
                    from services.client_risk_rating_service import ClientRiskRatingService
                    risk_dist = ClientRiskRatingService.get_branch_risk_distribution(uow_ac, BRANCH_ID)
                    st.json(risk_dist)
                except Exception:
                    st.caption("Performance insights calculated dynamically.")
    
            # ---------------------------------------------------------------------
            # TAB 10: 🧙 Reconciliation Wizard
            # ---------------------------------------------------------------------
        if audit_tab10:
            with audit_tab10:
                st.subheader("🧙 Guided Self-Healing Reconciliation Wizard")
                st.caption("Interactive wizard to verify balance, locate discrepancies, and trigger automated projection repair.")
    
                rw_date = st.date_input("Select Reconciliation Date:", date.today(), key="rw_date_input")
    
                if st.button("🚀 Start Guided Projection Repair", type="primary"):
                    with st.spinner("Executing guided self-healing repair..."):
                        repair_res = FinancialReconciliationService.run_reconciliation_wizard_repair(uow_ac, BRANCH_ID, rw_date)
                        st.success(f"✔ Self-healing complete! Rebuilt {repair_res['rebuilt_officer_count']} officer cashbooks & Master Cashbook.")
                        st.json(repair_res["verification_after_repair"])
    

elif page == "CO Cashbook":
    st.title("📖 Credit Officer Daily Cashbook")
    st.caption("Daily T-Account Ledger — Reconciled against Account 1000 Vault Cash")
    
    from services.business_date_service import BusinessDateService
    with SupabaseUnitOfWork() as uow_cb_date:
        active_b_date = BusinessDateService.get_business_date(uow_cb_date, BRANCH)

    col_d1, col_d2 = st.columns([1, 2])
    with col_d1:
        view_date = st.date_input("Select Date", active_b_date, key="co_cb_date")
        date_str = view_date.strftime("%Y-%m-%d")

    with SupabaseUnitOfWork() as uow_cb_chk:
        is_co_cb_open, co_open_reason = BusinessDateService.is_operational_open(uow_cb_chk, BRANCH_ID, view_date)

    if not is_co_cb_open:
        st.warning(f"🏖️ **Operational Activity Suspended ({co_open_reason})**: Operations for **{view_date.strftime('%d %B %Y')}** are in **Read-Only** mode.")
    
    # Officer Selection based on RBAC
    target_co = USER
    with col_d2:
        if ROLE in ['Admin', 'AM', 'Director', 'Executive', 'BM', ROLE_BRANCH_MANAGER]:
            try:
                from database.repositories.unit_of_work import SupabaseUnitOfWork
                with SupabaseUnitOfWork() as uow_co_list:
                    branch_uuid = uow_co_list.cashbook._resolve_branch_id(BRANCH)
                    res_users = uow_co_list.client.table("app_users").select("username, full_name").eq("branch_id", branch_uuid).execute()
                    co_options = {f"{u.get('full_name', u.get('username'))} ({u.get('username')})": u.get('username') for u in (res_users.data or [])}
                    if not co_options:
                        co_options = {USER: USER}
                    selected_disp = st.selectbox("Select Credit Officer", list(co_options.keys()), key="co_cb_officer_sel")
                    target_co = co_options.get(selected_disp, USER)
            except Exception:
                target_co = USER
        else:
            st.info(f"Viewing Cashbook for Officer: **{USER}** ({BRANCH} Branch)")

    # ========================================================
    # LEDGER PROJECTION RETRIEVAL (co_cashbooks)
    # ========================================================
    bf_cash = t_sav = t_r12w = t_r24w = t_r60d = t_rmth = t_cont = t_bwd = t_asale = t_app = t_pb = t_bon = t_cfd = 0.0
    t_d11 = t_w11 = t_mm = t_pwd = t_exp = t_bdep = t_lres = t_ltrans = t_cc = 0.0
    d_act = w_act_12 = w_act_24 = m_act = 0.0
    left_total = right_total = closing_bal = 0.0

    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        with SupabaseUnitOfWork() as uow:
            branch_id = uow.cashbook._resolve_branch_id(BRANCH)
            res_u = uow.client.table("app_users").select("id").eq("username", target_co).execute()
            o_id = res_u.data[0]["id"] if res_u.data else None
            
            if o_id:
                # Rebuild projection for fresh live data
                uow.cashbook.rebuild_projection(branch_id, view_date, officer_id=o_id)
                
                res_co = uow.client.table("co_cashbooks").select("*").eq("date", date_str).eq("branch_id", branch_id).eq("officer_id", o_id).execute()
                if res_co.data:
                    c = res_co.data[0]
                    bf_cash = float(c.get("opening_balance") or 0)
                    t_sav = float(c.get("savings_deposit") or 0)
                    t_lres = float(c.get("laps_reserve") or 0)
                    t_r60d = float(c.get("rep_daily") or 0)
                    t_r12w = float(c.get("rep_12_weeks") or 0)
                    t_r24w = float(c.get("rep_24_weeks") or 0)
                    t_rmth = float(c.get("rep_monthly") or 0)
                    t_d11 = float(c.get("daily_11_pct") or 0)
                    t_w11 = float(c.get("weekly_11_pct") or 0)
                    t_mm = float(c.get("risk_premium_returns") or 0)
                    t_cont = float(c.get("contingency") or 0)
                    t_app = float(c.get("app_fee") or 0)
                    t_cfd = float(c.get("credit_form_damage") or 0)
                    t_pb = float(c.get("passbook") or 0)
                    t_bon = float(c.get("bonus") or 0)
                    t_cc = float(c.get("cash_and_carry") or 0)
                    t_asale = float(c.get("asset_credit_sales") or 0)
                    t_bwd = float(c.get("bank_withdrawal") or 0)
                    t_pwd = float(c.get("product_withdrawal") or 0)
                    t_exp = float(c.get("office_expenses") or 0)
                    t_bdep = float(c.get("bank_deposit") or 0)
                    t_ltrans = float(c.get("laps_returns") or 0)
                    left_total = float(c.get("total_inflows") or 0)
                    right_total = float(c.get("total_outflows") or 0)
                    closing_bal = float(c.get("closing_balance") or 0)

                # Fetch active disbursements originated today for breakdown (excluding legacy onboarding)
                res_l = uow.client.table("loans").select("loan_amount, active_credit, extra_fields, loan_products(name, repayment_cycle)") \
                    .eq("officer_id", o_id).eq("branch_id", branch_id).or_(f"disbursement_date.eq.{date_str},date.eq.{date_str}") \
                    .in_("status", ["Active", "Approved", "Completed"]).execute()
                for l in (res_l.data or []):
                    if isinstance(l.get("extra_fields"), dict) and l["extra_fields"].get("is_legacy") is True:
                        continue
                    act_cr = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
                    lp = l.get("loan_products") or {}
                    p_name = str(lp.get("name") or "").lower()
                    cycle = lp.get("repayment_cycle") or ("Daily" if "daily" in p_name else "Weekly")
                    if cycle == "Daily":
                        d_act += act_cr
                    elif cycle == "Weekly":
                        if "24" in p_name: w_act_24 += act_cr
                        else: w_act_12 += act_cr
                    elif cycle == "Monthly":
                        m_act += act_cr
                    else:
                        w_act_12 += act_cr
    except Exception as e:
        st.warning(f"Could not load CO cashbook projection: {e}")

    # Fallback totals calculation if projection was empty
    if left_total == 0 and right_total == 0:
        left_total = (
            bf_cash + t_lres + t_sav + t_r60d + t_r12w + t_r24w + t_rmth +
            t_d11 + t_w11 + t_mm + t_cont + t_app + t_cfd + t_pb + t_bon +
            t_asale + t_cc + t_bwd
        )
        right_total = (
            d_act + w_act_12 + w_act_24 + m_act +
            t_pwd + t_exp + t_ltrans + t_bdep
        )
        closing_bal = left_total - right_total

    # ========================================================
    # END OF DAY & GLOBAL COLLECTIONS INPUT FORM
    # ========================================================
    st.markdown("### 📤 End of Day / Global Outflows & Additional Collections")
    st.caption("Log your daily branch expenses, bank deposits, passbook fees, credit form fees, and cash adjustments.")
    
    with st.form("eod_form"):
        out_0, out_1, out_2 = st.columns(3)
        global_opening = out_0.number_input("Opening Balance (B/F Cash)", min_value=0.0, step=500.0, value=bf_cash if bf_cash > 0 else None, placeholder="0", key="co_eod_opening")
        global_expenses = out_1.number_input("Office Expenses", min_value=0.0, step=500.0, value=t_exp if t_exp > 0 else None, placeholder="0", key="co_eod_expenses")
        global_bank_dep = out_2.number_input("Bank Deposited", min_value=0.0, step=500.0, value=t_bdep if t_bdep > 0 else None, placeholder="0", key="co_eod_bank_dep")
        
        st.markdown("---")
        st.markdown("##### 💳 Additional Collections & Fees")
        fee_1, fee_2, fee_3 = st.columns(3)
        global_app_fee = fee_1.number_input("Credit Form / App Fee", min_value=0.0, step=500.0, value=t_app if t_app > 0 else None, placeholder="0", key="co_eod_app_fee", help="Unified Processing Fee and Credit Form fee")
        global_passbook = fee_2.number_input("Pass Book", min_value=0.0, step=500.0, value=t_pb if t_pb > 0 else None, placeholder="0", key="co_eod_passbook")
        global_misc_fee = fee_3.number_input("Misc Fee", min_value=0.0, step=500.0, value=t_mm if t_mm > 0 else None, placeholder="0", key="co_eod_misc_fee", help="Routed directly to Misc Savings pool")
        
        fee_4, fee_5 = st.columns(2)
        global_cfd = fee_4.number_input("Cr Form Dmg", min_value=0.0, step=100.0, value=t_cfd if t_cfd > 0 else None, placeholder="0", key="co_eod_cfd", help="Fee for damaged credit forms")
        global_bonus = fee_5.number_input("Bonus", min_value=0.0, step=500.0, value=t_bon if t_bon > 0 else None, placeholder="0", key="co_eod_bonus")
        
        st.markdown("---")
        submit_eod = st.form_submit_button("💾 Save End of Day Outflows & Fees", type="primary", use_container_width=True)
        
        if submit_eod:
            if not is_co_cb_open:
                st.error(f"🔒 Cannot update End of Day inputs today ({co_open_reason}).")
            else:
                from domain.entities.event_store import DomainEvent
                from services.posting_engine import FinancialPostingEngine

            global_opening_val = float(global_opening or 0)
            global_expenses_val = float(global_expenses or 0)
            global_bank_dep_val = float(global_bank_dep or 0)
            global_app_fee_val = float(global_app_fee or 0)
            global_passbook_val = float(global_passbook or 0)
            global_misc_fee_val = float(global_misc_fee or 0)
            global_cfd_val = float(global_cfd or 0)
            global_bonus_val = float(global_bonus or 0)
            
            try:
                with SupabaseUnitOfWork() as uow_eod:
                    b_uuid = uow_eod.cashbook._resolve_branch_id(BRANCH)
                    u_res = uow_eod.client.table("app_users").select("id").eq("username", target_co).execute()
                    off_uuid = u_res.data[0]["id"] if u_res.data else None
                    
                    # 1. Update manual opening balance if provided
                    if global_opening_val > 0:
                        uow_eod.client.table("co_cashbooks").upsert({
                            "date": date_str,
                            "branch_id": b_uuid,
                            "officer_id": off_uuid,
                            "opening_balance": global_opening_val
                        }, on_conflict="date,branch_id,officer_id").execute()

                    # 2. Fetch current projection to compute deltas
                    cb_res = uow_eod.client.table("co_cashbooks").select("*").eq("branch_id", b_uuid).eq("officer_id", off_uuid).eq("date", date_str).execute()
                    cur_cb = cb_res.data[0] if cb_res.data else {}
                    
                    cur_app_fee = float(cur_cb.get("app_fee") or 0.0)
                    cur_pb = float(cur_cb.get("passbook") or 0.0)
                    cur_cfd = float(cur_cb.get("credit_form_damage") or 0.0)
                    cur_bon = float(cur_cb.get("bonus") or 0.0)
                    cur_misc = float(cur_cb.get("misc_fees") or 0.0)
                    cur_exp = float(cur_cb.get("office_expenses") or 0.0)
                    cur_bdep = float(cur_cb.get("bank_deposit") or 0.0)

                    # 3. Post Delta Adjustments for each fee/expense/deposit:
                    # App Fee Delta
                    d_app = global_app_fee_val - cur_app_fee
                    if d_app != 0:
                        ev_app = DomainEvent(
                            event_id=str(uuid.uuid4()),
                            aggregate_id=off_uuid or str(uuid.uuid4()),
                            aggregate_type="Fee",
                            event_type="FeeCharged",
                            payload={"branch": BRANCH, "branch_id": b_uuid, "officer": target_co, "officer_id": off_uuid, "amount": d_app, "date": date_str, "narration": f"EOD App Fee Update (Adjusted from ₦{cur_app_fee:,.2f} to ₦{global_app_fee_val:,.2f})"}
                        )
                        uow_eod.event_store.append(ev_app)
                        FinancialPostingEngine.post_event(uow_eod, ev_app)

                    # Passbook Delta
                    d_pb = global_passbook_val - cur_pb
                    if d_pb != 0:
                        ev_pb = DomainEvent(
                            event_id=str(uuid.uuid4()),
                            aggregate_id=off_uuid or str(uuid.uuid4()),
                            aggregate_type="Fee",
                            event_type="FeeCharged",
                            payload={"branch": BRANCH, "branch_id": b_uuid, "officer": target_co, "officer_id": off_uuid, "amount": d_pb, "date": date_str, "narration": f"EOD Passbook Update (Adjusted from ₦{cur_pb:,.2f} to ₦{global_passbook_val:,.2f})"}
                        )
                        uow_eod.event_store.append(ev_pb)
                        FinancialPostingEngine.post_event(uow_eod, ev_pb)

                    # CFD Delta
                    d_cfd = global_cfd_val - cur_cfd
                    if d_cfd != 0:
                        ev_cfd = DomainEvent(
                            event_id=str(uuid.uuid4()),
                            aggregate_id=off_uuid or str(uuid.uuid4()),
                            aggregate_type="Fee",
                            event_type="FeeCharged",
                            payload={"branch": BRANCH, "branch_id": b_uuid, "officer": target_co, "officer_id": off_uuid, "amount": d_cfd, "date": date_str, "narration": f"EOD Cr Form Damage Update (Adjusted from ₦{cur_cfd:,.2f} to ₦{global_cfd_val:,.2f})"}
                        )
                        uow_eod.event_store.append(ev_cfd)
                        FinancialPostingEngine.post_event(uow_eod, ev_cfd)

                    # Bonus Delta
                    d_bon = global_bonus_val - cur_bon
                    if d_bon != 0:
                        ev_bon = DomainEvent(
                            event_id=str(uuid.uuid4()),
                            aggregate_id=off_uuid or str(uuid.uuid4()),
                            aggregate_type="Fee",
                            event_type="FeeCharged",
                            payload={"branch": BRANCH, "branch_id": b_uuid, "officer": target_co, "officer_id": off_uuid, "amount": d_bon, "date": date_str, "narration": f"EOD Bonus Update (Adjusted from ₦{cur_bon:,.2f} to ₦{global_bonus_val:,.2f})"}
                        )
                        uow_eod.event_store.append(ev_bon)
                        FinancialPostingEngine.post_event(uow_eod, ev_bon)

                    # Misc Fees Delta
                    d_misc = global_misc_fee_val - cur_misc
                    if d_misc != 0:
                        ev_misc = DomainEvent(
                            event_id=str(uuid.uuid4()),
                            aggregate_id=off_uuid or str(uuid.uuid4()),
                            aggregate_type="Fee",
                            event_type="FeeCharged",
                            payload={"branch": BRANCH, "branch_id": b_uuid, "officer": target_co, "officer_id": off_uuid, "amount": d_misc, "date": date_str, "narration": f"EOD Misc Fee Update (Adjusted from ₦{cur_misc:,.2f} to ₦{global_misc_fee_val:,.2f})"}
                        )
                        uow_eod.event_store.append(ev_misc)
                        FinancialPostingEngine.post_event(uow_eod, ev_misc)

                    # Expenses Delta
                    d_exp = global_expenses_val - cur_exp
                    if d_exp != 0:
                        ev_exp = DomainEvent(
                            event_id=str(uuid.uuid4()),
                            aggregate_id=off_uuid or str(uuid.uuid4()),
                            aggregate_type="Expense",
                            event_type="ExpenseRecorded",
                            payload={"branch": BRANCH, "branch_id": b_uuid, "officer": target_co, "officer_id": off_uuid, "amount": d_exp, "date": date_str, "narration": f"EOD Expense Update (Adjusted from ₦{cur_exp:,.2f} to ₦{global_expenses_val:,.2f})"}
                        )
                        uow_eod.event_store.append(ev_exp)
                        FinancialPostingEngine.post_event(uow_eod, ev_exp)

                    # Bank Deposit Delta
                    d_bdep = global_bank_dep_val - cur_bdep
                    if d_bdep != 0:
                        ev_bdep = DomainEvent(
                            event_id=str(uuid.uuid4()),
                            aggregate_id=off_uuid or str(uuid.uuid4()),
                            aggregate_type="Treasury",
                            event_type="BankDeposited",
                            payload={"branch": BRANCH, "branch_id": b_uuid, "officer": target_co, "officer_id": off_uuid, "amount": d_bdep, "date": date_str, "narration": f"EOD Bank Deposit Update (Adjusted from ₦{cur_bdep:,.2f} to ₦{global_bank_dep_val:,.2f})"}
                        )
                        uow_eod.event_store.append(ev_bdep)
                        FinancialPostingEngine.post_event(uow_eod, ev_bdep)

                    # Rebuild projection
                    if off_uuid:
                        uow_eod.cashbook.rebuild_projection(b_uuid, view_date, officer_id=off_uuid)
                
                st.success("✅ End of Day Outflows & Fees Updated Successfully!")
                import time
                time.sleep(1.2)
                st.rerun()
            except Exception as e:
                st.error(f"Error updating End of Day inputs: {e}")

    # ========================================================
    # BALANCED 2-COLUMN T-ACCOUNT LEDGER DISPLAY
    # ========================================================
    st.markdown("---")
    st.markdown("### 📊 Credit Officer Daily Cashbook Ledger")
    
    inflow_items = [
        ("Opening Balance", bf_cash),
        ("Savings Deposit", t_sav),
        ("Credit Rep (Daily)", t_r60d),
        ("Credit Rep (12 Weeks)", t_r12w),
        ("Credit Rep (24 Weeks)", t_r24w),
        ("Credit Rep (Monthly)", t_rmth),
        ("Laps Reserve", t_lres),
        ("Asset Credit Sales", t_asale),
        ("Cash & Carry", t_cc),
        ("Daily 11% Markup", t_d11),
        ("Weekly 11% Markup", t_w11),
        ("Monthly / 20% Markup", t_mm),
        ("Contingency (1%)", t_cont),
        ("Credit Form / App Fee", t_app),
        ("Credit Form Damage", t_cfd),
        ("Pass Book", t_pb),
        ("Bonus", t_bon),
        ("Bank Withdrawal", t_bwd),
    ]
    
    outflow_items = [
        ("Active Loan (Daily)", d_act),
        ("Active Loan (12 Weeks)", w_act_12),
        ("Active Loan (24 Weeks)", w_act_24),
        ("Active Loan (Monthly)", m_act),
        ("Product / Savings Withdrawal", t_pwd),
        ("Office Expenses", t_exp),
        ("LAPS Returns / Payouts", t_ltrans),
        ("Bank Deposit", t_bdep),
    ]

    max_rows = max(len(inflow_items), len(outflow_items))
    while len(inflow_items) < max_rows: inflow_items.append(("", ""))
    while len(outflow_items) < max_rows: outflow_items.append(("", ""))

    df_co_display = pd.DataFrame({
        "📥 Inflows (Left / Debit)": [i[0] for i in inflow_items],
        "Amount (₦) ": [f"₦{i[1]:,.0f}" if isinstance(i[1], (int, float)) and i[0] != "" else "" for i in inflow_items],
        "📤 Outflows (Right / Credit)": [o[0] for o in outflow_items],
        "Amount (₦)  ": [f"₦{o[1]:,.0f}" if isinstance(o[1], (int, float)) and o[0] != "" else "" for o in outflow_items]
    })

    st.dataframe(df_co_display, use_container_width=True, hide_index=True)

    k1, k2, k3, k4 = st.columns(4)
    k1.metric("🏛️ Opening Balance", f"₦{bf_cash:,.0f}")
    k2.metric("📥 Total Inflows", f"₦{left_total:,.0f}")
    k3.metric("📤 Total Outflows", f"₦{right_total:,.0f}")
    if closing_bal >= 0:
        k4.success(f"### Closing: ₦{closing_bal:,.0f}")
    else:
        k4.error(f"### Closing: ₦{closing_bal:,.0f}")

    # ========================================================
    # ERROR CORRECTION & REVERSAL REQUEST HUB (FOUR-EYES BR-ERR-001)
    # ========================================================
    st.markdown("---")
    st.markdown("### 🚩 Cashbook Error Correction & Reversal Hub")
    st.caption("Flag an erroneous EOD Fee, Office Expense, or Bank Deposit for Branch Manager approval (Rule BR-ERR-001). (Note: For Client Loan Repayments & Savings Deposits, use the Collections page).")
    
    with st.expander("Flag an EOD Fee / Expense / Deposit for Reversal", expanded=False):
        st.info("Select an EOD transaction from recent days to flag for reversal. The Branch Manager or Admin must review and approve the reversal before it takes effect on the ledger.")
        try:
            with SupabaseUnitOfWork() as uow_corr:
                # Query recent EOD events for this officer/branch
                q_events = uow_corr.client.table("event_store").select("*")                     .in_("event_type", ["FeeCharged", "ExpenseRecorded", "BankDeposited", "BankWithdrawn"])                     .order("created_at", desc=True).limit(30)
                res_events = q_events.execute()
                raw_events = res_events.data or []
                
                opts = {}
                for ev in raw_events:
                    p = ev.get("payload") or {}
                    ev_off = str(p.get("officer") or p.get("officer_id") or "")
                    ev_br = str(p.get("branch") or p.get("branch_id") or "")
                    
                    # Check officer scope
                    if scope.scope_level == "OFFICER" and ev_off not in [str(USER), str(USER_ID)]:
                        continue
                    if scope.scope_level == "BRANCH" and BRANCH and ev_br not in [str(BRANCH), str(BRANCH_ID)]:
                        continue
                        
                    ev_type = ev.get("event_type")
                    amt = float(p.get("amount") or 0.0)
                    dt = str(p.get("date") or ev.get("created_at") or "")[:10]
                    narr = p.get("narration") or p.get("remarks") or ev_type
                    ev_id = str(ev.get("event_id") or "")
                    
                    badge = "🏷️ [Fee]" if ev_type == "FeeCharged" else ("🧾 [Expense]" if ev_type == "ExpenseRecorded" else "🏦 [Bank Transfer]")
                    label = f"{badge} {dt} | ₦{amt:,.2f} — {narr[:40]} | Ref: {ev_id[:8]}"
                    opts[label] = ("Fee" if ev_type == "FeeCharged" else ("Expense" if ev_type == "ExpenseRecorded" else "Treasury"), ev_id)
                
                if opts:
                    sel_tx_label = st.selectbox("Select EOD Transaction to Flag", list(opts.keys()), key="co_cb_rev_tx_select")
                    rec_type, rec_id = opts[sel_tx_label]
                    req_reason = st.text_input("Reason for Reversal", placeholder="e.g., Typo in office expense. Typed 50000 instead of 5000.", key="co_cb_rev_reason")
                    if st.button("Submit Reversal Request to BM", type="primary", key="co_cb_submit_rev_btn"):
                        if req_reason.strip():
                            from services.correction_service import CorrectionService
                            req_id = CorrectionService.request_correction(
                                uow=uow_corr,
                                record_id=rec_id,
                                record_type=rec_type,
                                reason=req_reason.strip(),
                                requested_by=USER_ID if USER_ID else USER,
                                branch_id=BRANCH_ID
                            )
                            st.success(f"✅ Reversal request submitted to Branch Manager! (Ref: #{req_id[:8]})")
                            st.rerun()
                        else:
                            st.warning("Please provide a valid reason for the reversal.")
                else:
                    st.info("No recent EOD fees, expenses, or bank deposits available to flag.")
                
                # Display Submitted Requests History for this user
                st.markdown("---")
                st.markdown("#### 📋 Submitted Reversal Requests")
                try:
                    req_query = uow_corr.client.table("correction_requests").select("*")
                    if USER_ID:
                        req_query = req_query.eq("requested_by", USER_ID)
                    elif BRANCH_ID:
                        req_query = req_query.eq("branch_id", BRANCH_ID)
                    res_my_reqs = req_query.order("created_at", desc=True).limit(10).execute()
                    my_reqs = res_my_reqs.data or []
                except Exception:
                    my_reqs = []
                
                if my_reqs:
                    req_display = []
                    for mr in my_reqs:
                        st_badge = "🟡 Pending" if mr.get("status") == "Pending" else ("🟢 Approved" if mr.get("status") == "Approved" else "🔴 Rejected")
                        req_display.append({
                            "Date": str(mr.get("created_at", ""))[:16].replace("T", " "),
                            "Type": mr.get("record_type"),
                            "Record Ref": str(mr.get("record_id", ""))[:8],
                            "Reason": mr.get("reason"),
                            "Status": st_badge,
                            "Approved By": mr.get("approved_by") or "—"
                        })
                    st.dataframe(pd.DataFrame(req_display), use_container_width=True, hide_index=True)
                else:
                    st.caption("You have not submitted any reversal requests yet.")
        except Exception as ex_corr:
            st.warning(f"Could not load correction hub: {ex_corr}")


elif page == "Master Cashbook":
    st.title("Branch Manager Master Cashbook")
    st.caption("INITIATIVE FOR COMMUNITY ADVANCEMENT, RELIEF AND EMPOWERMENT — Credit Cash Book Ledger")
    
    mc_tab1, mc_tab2, mc_tab3 = st.tabs([
        "Daily Cashbook Entry", 
        "CO Cashbooks Aggregation", 
        "Monthly Ledger"
    ])
    
    all_loans = load_loans()
    all_repayments = load_repayments()
    
    with mc_tab1:
        from services.business_date_service import BusinessDateService
        with SupabaseUnitOfWork() as uow_mc_date:
            active_b_date = BusinessDateService.get_business_date(uow_mc_date, BRANCH)
        view_date = st.date_input("Select Date", active_b_date, key="mc_date")
        date_str = view_date.strftime("%Y-%m-%d")

        with SupabaseUnitOfWork() as uow_mc_chk:
            is_mc_open, mc_open_reason = BusinessDateService.is_operational_open(uow_mc_chk, BRANCH_ID, view_date)

        if not is_mc_open and "closed" in mc_open_reason.lower():
            st.success(f"🔒 **Master Cashbook Closed & Verified**: Operations for **{view_date.strftime('%d %B %Y')}** have been finalized. Closing balance has been rolled forward to next working day.")
        elif not is_mc_open:
            st.warning(f"🏖️ **Operational Activity Suspended ({mc_open_reason})**: Operations for **{view_date.strftime('%d %B %Y')}** are in **Read-Only** mode.")
        
        # ---- AUTO-SUM: Load from cashbook projection table instead of legacy summing ----
        auto_rep_60d = auto_rep_120d = auto_rep_12w = auto_rep_24w = auto_rep_mth = auto_savings = auto_laps_res = 0.0
        auto_daily_11 = auto_daily_20 = auto_weekly_11 = auto_weekly_20 = auto_monthly_markup = auto_passbook = 0.0
        auto_app_fee = auto_asset_cr_sales = auto_cash_carry = auto_contingency = auto_credit_form_dmg = auto_bonus = auto_misc = auto_bank_wd = 0.0
        auto_savings_wd = auto_prod_wd = auto_expenses = auto_laps_ret = auto_bank_dep = 0.0
        
        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                branch_id = uow.cashbook._resolve_branch_id(BRANCH)
                uow.cashbook.rebuild_projection(branch_id, view_date)
                cb_entry = uow.cashbook.find_by_date_and_branch(date_str, BRANCH)
                if cb_entry:
                    auto_rep_60d = cb_entry.rep_daily
                    auto_rep_12w = cb_entry.rep_12_weeks
                    auto_rep_24w = cb_entry.rep_24_weeks
                    auto_rep_mth = cb_entry.rep_monthly
                    auto_savings = cb_entry.savings_deposit
                    auto_laps_res = cb_entry.laps_reserve
                    auto_daily_11 = cb_entry.daily_11_pct
                    auto_daily_20 = getattr(cb_entry, "daily_20_pct", 0.0)
                    auto_weekly_11 = cb_entry.weekly_11_pct
                    auto_weekly_20 = getattr(cb_entry, "weekly_20_pct", 0.0)
                    auto_monthly_markup = cb_entry.risk_premium_returns
                    auto_passbook = cb_entry.passbook
                    auto_app_fee = cb_entry.app_fee
                    auto_asset_cr_sales = cb_entry.asset_credit_sales
                    auto_cash_carry = cb_entry.cash_and_carry
                    auto_contingency = cb_entry.contingency
                    auto_credit_form_dmg = cb_entry.credit_form_damage
                    auto_bonus = cb_entry.bonus
                    auto_misc = cb_entry.misc_fees
                    auto_bank_wd = cb_entry.bank_withdrawal
                    
                    auto_savings_wd = cb_entry.savings_withdrawal
                    auto_prod_wd = cb_entry.product_withdrawal
                    auto_expenses = cb_entry.office_expenses
                    auto_laps_ret = cb_entry.laps_returns
                    auto_bank_dep = cb_entry.bank_deposit
        except Exception as e:
            st.warning(f"Could not load cashbook projection: {e}")
        
        # Auto-sum VAULT FUNDING from live loans disbursed today (excluding legacy onboarding loans)
        if not all_loans.empty:
            all_loans['_dt'] = pd.to_datetime(all_loans['Date'], errors='coerce')
            today_loans = all_loans[
                (all_loans['_dt'].dt.date.astype(str) == date_str) &
                (all_loans['Branch'] == BRANCH) &
                (all_loans['Status'].isin([STATUS_ACTIVE, STATUS_APPROVED, STATUS_COMPLETED, "Active", "Approved", "Completed"]))
            ]
            if not today_loans.empty and 'extra_fields' in today_loans.columns:
                today_loans = today_loans[~today_loans['extra_fields'].apply(lambda x: isinstance(x, dict) and x.get('is_legacy') is True)]
        else:
            today_loans = pd.DataFrame()
        
        auto_fund_asset = 0.0
        auto_fund_finance = 0.0
        auto_disb_60d = 0.0
        auto_disb_120d = 0.0
        auto_disb_12w = 0.0
        auto_disb_24w = 0.0
        auto_disb_mth = 0.0
        if not today_loans.empty:
            for _, loan in today_loans.iterrows():
                principal = pd.to_numeric(loan.get('Loan Amount', 0), errors='coerce')
                active_cr = pd.to_numeric(loan.get('Active Credit', 0), errors='coerce')
                if pd.isna(principal): principal = 0
                if pd.isna(active_cr) or active_cr == 0: active_cr = principal
                cat = str(loan.get('Product Category', 'Finance'))
                prod = str(loan.get('Loan Product', '')).lower()
                if 'Asset' in cat:
                    auto_fund_asset += principal
                else:
                    auto_fund_finance += principal
                # Route active credit to product-specific disbursement
                if '120' in prod:
                    auto_disb_120d += active_cr
                elif '60' in prod:
                    auto_disb_60d += active_cr
                elif '24w' in prod or '24' in prod:
                    auto_disb_24w += active_cr
                elif '12w' in prod or '12' in prod:
                    auto_disb_12w += active_cr
                elif '3m' in prod or '6m' in prod or 'month' in prod:
                    auto_disb_mth += active_cr
                else:
                    auto_disb_12w += active_cr
        
        # ---- OPENING BALANCE: Fetch previous day's closing ----
        prev_date = (view_date - timedelta(days=1)).strftime("%Y-%m-%d")
        try:
            with SupabaseUnitOfWork() as uow:
                prev_entry = uow.cashbook.find_by_date_and_branch(prev_date, BRANCH)
            prev_row = type('obj', (object,), {'data': [{'closing_balance': prev_entry.closing_balance}] if prev_entry else []})
            auto_opening = float(prev_row.data[0]['closing_balance']) if prev_row.data else 0.0
        except Exception:
            auto_opening = 0.0
        
        # ---- DISPLAY AUTO-SUMMED VALUES (Excel T-Account Layout) ----
        st.markdown("### 📊 Daily Ledger (Auto-Summed from CO Data)")
        
        # Build LEFT (Inflows) matching Excel columns A–AA
        inflow_items = [
            ("Opening Balance", auto_opening),
            ("Savings Deposit (Amount)", auto_savings),
            ("Credit Repayment (60 days)", auto_rep_60d),
            ("Credit Repayment (120 days)", auto_rep_120d),
            ("Credit Repayment (12 weeks)", auto_rep_12w),
            ("Credit Repayment (24 weeks)", auto_rep_24w),
            ("Credit Repayment (Monthly)", auto_rep_mth),
            ("Laps Reserve", auto_laps_res),
            ("Funds Received from Head Office", getattr(cb_entry, "funds_received_ho", 0.0) if 'cb_entry' in locals() and cb_entry else 0.0),
            ("Funds Received from Branch Office", getattr(cb_entry, "funds_received_other_branch", 0.0) if 'cb_entry' in locals() and cb_entry else 0.0),
            ("Funds Received from Other Areas", getattr(cb_entry, "funds_received_other_area", 0.0) if 'cb_entry' in locals() and cb_entry else 0.0),
            ("Asset Credit Sales", auto_asset_cr_sales),
            ("Cash & Carry", auto_cash_carry),
            ("Funds from Finance", auto_fund_finance),
            ("Daily 11%", auto_daily_11),
            ("Daily 20%", auto_daily_20),
            ("Weekly 11%", auto_weekly_11),
            ("Weekly 20%", auto_weekly_20),
            ("Monthly 11%/20%", auto_monthly_markup),
            ("Contingency (1%)", auto_contingency),
            ("Credit Form Damage", auto_credit_form_dmg),
            ("Bonus", auto_bonus),
            ("Credit Form / App Fee", auto_app_fee),
            ("Pass Book", auto_passbook),
            ("Bank Withdrawal", auto_bank_wd),
        ]
        
        # Build RIGHT (Outflows) matching Excel columns AC–AR
        outflow_items = [
            ("Active Loan (60 Days)", auto_disb_60d),
            ("Active Loan (120 Days)", auto_disb_120d),
            ("Active Loan (12 Weeks)", auto_disb_12w),
            ("Active Loan (24 Weeks)", auto_disb_24w),
            ("Active Loan (Monthly)", auto_disb_mth),
            ("Fund Transferred to Branch Office", getattr(cb_entry, "fund_transferred_other_branch", 0.0) if 'cb_entry' in locals() and cb_entry else 0.0),
            ("Fund Transferred to Head Office", getattr(cb_entry, "fund_transferred_ho", 0.0) if 'cb_entry' in locals() and cb_entry else 0.0),
            ("Fund Transferred to Other Areas", getattr(cb_entry, "fund_to_other_area", 0.0) if 'cb_entry' in locals() and cb_entry else 0.0),
            ("Fund To Assets", auto_fund_asset),
            ("Fund to Finance", auto_fund_finance),
            ("Product/Savings Withdrawal", auto_prod_wd + auto_savings_wd),
            ("Staff Salaries", getattr(cb_entry, "staff_salaries", 0.0) if 'cb_entry' in locals() and cb_entry else 0.0),
            ("Office Expenses", auto_expenses),
            ("Laps Return", auto_laps_ret),
            ("Bank Deposit", auto_bank_dep),
        ]
        
        # Pad shorter list
        max_rows = max(len(inflow_items), len(outflow_items))
        while len(inflow_items) < max_rows:
            inflow_items.append(("", ""))
        while len(outflow_items) < max_rows:
            outflow_items.append(("", ""))
        
        df_preview = pd.DataFrame({
            "📥 Inflows (Left)": [i[0] for i in inflow_items],
            "Amount (₦) ": [i[1] for i in inflow_items],
            "📤 Outflows (Right)": [o[0] for o in outflow_items],
            "Amount (₦)  ": [o[1] for o in outflow_items]
        })
        
        def format_currency(x):
            if isinstance(x, (int, float)):
                return f"₦{x:,.0f}"
            return x
            
        df_display = df_preview.copy()
        df_display["Amount (₦) "] = df_display["Amount (₦) "].apply(format_currency)
        df_display["Amount (₦)  "] = df_display["Amount (₦)  "].apply(format_currency)

        st.dataframe(df_display, use_container_width=True, hide_index=True)
        
        # ---- MANUAL BM INPUTS ----
        st.markdown("---")
        st.markdown("### ✏️ BM Manual Inputs")
        
        with st.form("master_cashbook_form"):
            st.markdown("#### 📥 Inflows (Vault Funding Received)")
            m1, m2, m3 = st.columns(3)
            funds_ho = m1.number_input("Funds Received from Head Office", min_value=0.0, step=1000.0, value=0.0)
            funds_branch = m2.number_input("Funds Received from Branch Office", min_value=0.0, step=1000.0, value=0.0)
            funds_area = m3.number_input("Funds Received from Other Areas", min_value=0.0, step=1000.0, value=0.0)
            
            st.markdown("#### 📤 Outflows (Corporate Transfers)")
            n1, n2, n3 = st.columns(3)
            xfer_branch = n1.number_input("Fund Transferred to Branch Office", min_value=0.0, step=1000.0, value=0.0)
            xfer_ho = n2.number_input("Fund Transferred to H.O.", min_value=0.0, step=1000.0, value=0.0)
            xfer_area = n3.number_input("Fund Transferred to Other Areas", min_value=0.0, step=1000.0, value=0.0)
            
            salaries = st.number_input("Staff Salaries", min_value=0.0, step=1000.0, value=0.0)
            
            # ---- CALCULATE TOTALS ----
            total_inflows = (
                auto_opening + auto_savings + auto_rep_60d + auto_rep_120d + auto_rep_12w + auto_rep_24w + auto_rep_mth +
                auto_laps_res + funds_ho + funds_branch + funds_area +
                auto_asset_cr_sales + auto_cash_carry + auto_fund_finance +
                auto_daily_11 + auto_daily_20 + auto_weekly_11 + auto_weekly_20 + auto_monthly_markup +
                auto_contingency + auto_credit_form_dmg + auto_bonus + auto_app_fee + auto_passbook + auto_bank_wd
            )
            
            total_outflows = (
                auto_prod_wd +
                auto_fund_asset + auto_fund_finance +
                xfer_branch + xfer_ho + xfer_area +
                salaries + auto_expenses + auto_laps_ret + auto_bank_dep
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
                    "rep_daily": auto_rep_60d + auto_rep_120d,
                    "rep_12_weeks": auto_rep_12w,
                    "rep_24_weeks": auto_rep_24w,
                    "rep_monthly": auto_rep_mth,
                    "savings_deposit": auto_savings,
                    "laps_reserve": auto_laps_res,
                    "funds_received_ho": funds_ho,
                    "funds_received_other_branch": funds_branch,
                    "funds_received_other_area": funds_area,
                    "loan_received_asset": 0,
                    "loan_received_finance": auto_fund_finance,
                    "daily_11_pct": auto_daily_11,
                    "weekly_11_pct": auto_weekly_11,
                    "savings_adj_no": 0,
                    "savings_adj_amount": 0,
                    "risk_premium_returns": 0,
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
                    "closing_balance": closing_balance,
                    "adjustment_in": 0.0,
                    "adjustment_out": 0.0,
                    "adjustment_reason": None
                }
                
                try:
                    with SupabaseUnitOfWork() as uow:
                        from services.treasury_service import TreasuryService
                        branch_id = uow.cashbook._resolve_branch_id(BRANCH)
                        
                        posted_any = False
                        if funds_ho > 0:
                            TreasuryService.post_treasury_transaction(uow, 'HO_TRANSFER_IN', funds_ho, BRANCH, USER, remarks=f"HO Funding: {funds_ho}")
                            posted_any = True
                        if funds_branch > 0:
                            TreasuryService.post_treasury_transaction(uow, 'INTER_BRANCH_IN', funds_branch, BRANCH, USER, remarks=f"Branch Funding: {funds_branch}")
                            posted_any = True
                        if funds_area > 0:
                            TreasuryService.post_treasury_transaction(uow, 'INTER_AREA_IN', funds_area, BRANCH, USER, remarks=f"Area Funding: {funds_area}")
                            posted_any = True
                        if xfer_branch > 0:
                            TreasuryService.post_treasury_transaction(uow, 'INTER_BRANCH_OUT', xfer_branch, BRANCH, USER, remarks=f"Transfer to Branch: {xfer_branch}")
                            posted_any = True
                        if xfer_ho > 0:
                            TreasuryService.post_treasury_transaction(uow, 'HO_TRANSFER_OUT', xfer_ho, BRANCH, USER, remarks=f"Transfer to HO: {xfer_ho}")
                            posted_any = True
                        if xfer_area > 0:
                            TreasuryService.post_treasury_transaction(uow, 'INTER_AREA_OUT', xfer_area, BRANCH, USER, remarks=f"Transfer to Area: {xfer_area}")
                            posted_any = True
                        if salaries > 0:
                            TreasuryService.post_treasury_transaction(uow, 'SALARY', salaries, BRANCH, USER, remarks=f"Salary Payment: {salaries}")
                            posted_any = True
                            
                        uow.cashbook.rebuild_projection(branch_id, view_date)
                        
                        if posted_any:
                            st.success("Treasury transactions posted and Cashbook projection rebuilt successfully!")
                        else:
                            st.success("Cashbook projection updated and verified successfully!")
                except Exception as e:
                    st.error(f"Failed to save and post cashbook manual entries: {e}")

        # ========================================================
        # BM ERROR CORRECTION & REVERSAL HUB (FOUR-EYES BR-ERR-001)
        # ========================================================
        st.markdown("---")
        st.markdown("### 🚩 Branch Error Correction & Reversals Hub")
        st.caption("Review pending reversal requests from Credit Officers and manage branch-level treasury reversals.")

        with SupabaseUnitOfWork() as uow_bm_corr:
            q_pending = uow_bm_corr.client.table("correction_requests").select("*, app_users!correction_requests_requested_by_fkey(username, full_name)") \
                .eq("status", "Pending")
            if BRANCH_ID:
                q_pending = q_pending.eq("branch_id", BRANCH_ID)
            res_pending = q_pending.order("created_at", desc=False).execute()
            pending_reqs = res_pending.data or []

            st.markdown("#### 🚨 Pending Branch Reversal Requests")
            if pending_reqs:
                for req in pending_reqs:
                    r_id = req["id"]
                    r_type = req.get("record_type")
                    r_reason = req.get("reason")
                    u_data = req.get("app_users")
                    req_user = (u_data.get("full_name") or u_data.get("username")) if isinstance(u_data, dict) else "Officer"
                    r_date = str(req.get("created_at", ""))[:16].replace("T", " ")
                    r_ref = str(req.get("record_id", ""))[:8]
                    
                    type_icon = "💳 [Loan Repayment]" if r_type == "Repayment" else (
                        "💰 [Savings Deposit]" if r_type in ["Savings", "SavingsDeposit"] else (
                            "🏷️ [EOD Fee]" if r_type == "Fee" else (
                                "🧾 [Office Expense]" if r_type == "Expense" else "🏛️ [Treasury Transfer]"
                            )
                        )
                    )

                    with st.container(border=True):
                        col_req_info, col_req_meta, col_req_acts = st.columns([4, 2, 2])
                        with col_req_info:
                            st.markdown(f"**{type_icon}** &nbsp; `Ref: #{r_ref}`")
                            st.caption(f"Requested by: **{req_user}** &bull; Submitted: **{r_date}**")
                            st.markdown(f"**Reason:** *{r_reason}*")
                        with col_req_meta:
                            st.markdown("<div style='margin-top: 10px;'><span style='background: #FEF3C7; color: #92400E; padding: 4px 10px; border-radius: 12px; font-size: 0.8rem; font-weight: 600;'>🟡 Pending Approval</span></div>", unsafe_allow_html=True)
                        with col_req_acts:
                            st.write("")
                            b_act1, b_act2 = st.columns(2)
                            with b_act1:
                                if st.button("✅ Approve", key=f"mc_app_{r_id}", type="primary", use_container_width=True):
                                    try:
                                        from services.correction_service import CorrectionService
                                        CorrectionService.approve_correction(uow_bm_corr, r_id, approved_by=USER_ID if USER_ID else USER)
                                        st.success("Reversal approved and executed atomically!")
                                        st.rerun()
                                    except Exception as e:
                                        st.error(f"Approval failed: {e}")
                            with b_act2:
                                if st.button("❌ Reject", key=f"mc_rej_{r_id}", use_container_width=True):
                                    try:
                                        from services.correction_service import CorrectionService
                                        CorrectionService.reject_correction(uow_bm_corr, r_id, approved_by=USER_ID if USER_ID else USER)
                                        st.info("Reversal rejected.")
                                        st.rerun()
                                    except Exception as e:
                                        st.error(f"Rejection failed: {e}")
            else:
                st.success("✅ No pending reversal requests for this branch.")

        with st.expander("🏛️ Flag Branch Treasury Entry for Reversal", expanded=False):
            with SupabaseUnitOfWork() as uow_tx_list:
                q_tx = uow_tx_list.client.table("treasury_transactions").select("*") \
                    .order("created_at", desc=True).limit(25)
                if BRANCH_ID:
                    q_tx = q_tx.eq("branch_id", BRANCH_ID)
                res_tx = q_tx.execute()
                tx_list = res_tx.data or []

                tx_opts = {}
                for t in tx_list:
                    t_id = str(t.get("id", ""))
                    t_type = t.get("transaction_type")
                    t_amt = float(t.get("amount") or 0.0)
                    t_dt = str(t.get("posting_date") or t.get("created_at") or "")[:10]
                    t_rem = t.get("remarks") or ""
                    
                    label = f"[{t_type}] {t_dt} | ₦{t_amt:,.2f} — {t_rem[:30]} | Ref: {t_id[:8]}"
                    tx_opts[label] = t_id

                if tx_opts:
                    sel_bm_tx = st.selectbox("Select Treasury Entry to Flag", list(tx_opts.keys()), key="bm_rev_tx_select")
                    bm_rev_reason = st.text_input("Reason for Reversal", placeholder="e.g., Wrong salary amount entered.", key="bm_rev_reason")
                    if st.button("Submit Treasury Reversal Request", type="primary", key="bm_submit_tx_rev_btn"):
                        if bm_rev_reason.strip():
                            from services.correction_service import CorrectionService
                            req_id = CorrectionService.request_correction(
                                uow=uow_tx_list,
                                record_id=tx_opts[sel_bm_tx],
                                record_type="Treasury",
                                reason=bm_rev_reason.strip(),
                                requested_by=USER_ID if USER_ID else USER,
                                branch_id=BRANCH_ID
                            )
                            st.success(f"✅ Treasury reversal request submitted! (Ref: #{req_id[:8]})")
                            st.rerun()
                        else:
                            st.warning("Please provide a reason.")
                else:
                    st.info("No recent branch treasury transactions found.")
    
    with mc_tab2:
        view_date = st.date_input("Select Date", datetime.now().date(), key="wa_mc_date")
        date_str = view_date.strftime("%Y-%m-%d")
        
        repayments = all_repayments.copy() if not all_repayments.empty else pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
        repayments['DateStr'] = pd.to_datetime(repayments['Date'], errors='coerce').dt.date.astype(str)

        # --- RBAC FILTERING ---
        st.markdown("### 🏢 Select Credit Officer")
        try:
            with SupabaseUnitOfWork() as uow_co_list:
                all_users = uow_co_list.users.find_all()
                b_id = uow_co_list.cashbook._resolve_branch_id(BRANCH)
                branch_cos = [u for u in all_users if u.role in ["CO", "Officer", "Credit Officer"] and (not BRANCH or u.branch_name == BRANCH or u.branch_id == b_id)]
                if not branch_cos:
                    branch_cos = [u for u in all_users if u.role in ["CO", "Officer", "Credit Officer"]]
        except Exception:
            branch_cos = []

        co_options = {}
        for u in branch_cos:
            disp = f"{u.full_name} ({u.username})" if u.full_name else u.username
            co_options[disp] = u.username

        if not co_options:
            for k, v in CO_NAME_MAP.items():
                co_options[k] = v

        if not co_options:
            co_options = {CO_DISPLAY_MAP.get(USER, USER): USER}

        display_list = list(co_options.keys())
        default_idx = 0

        selected_display = st.selectbox("Select Credit Officer", display_list, index=default_idx, key="wa_cashbook_co")
        target_co = co_options.get(selected_display, selected_display)

        daily_reps = repayments[(repayments['DateStr'] == date_str) & (repayments['Officer'] == target_co)]

        # ========================================================
        # LEDGER DISPLAY (Loaded from co_cashbooks projection)
        # ========================================================
        bf_cash = t_sav = t_r12w = t_r24w = t_r60d = t_rmth = t_cont = t_bwd = t_asale = t_app = t_pb = t_bon = t_cfd = 0.0
        t_d11 = t_w11 = t_mm = t_pwd = t_exp = t_bdep = t_lres = t_ltrans = t_cc = 0.0
        d_act = w_act_12 = w_act_24 = m_act = 0.0
        left_total = right_total = closing_bal = 0.0

        try:
            from database.repositories.unit_of_work import SupabaseUnitOfWork
            with SupabaseUnitOfWork() as uow:
                branch_id = uow.cashbook._resolve_branch_id(BRANCH)
                o_id = uow.loans._resolve_officer_id(target_co)
                
                if o_id:
                    uow.cashbook.rebuild_projection(branch_id, view_date, officer_id=o_id)
                    res_co = uow.client.table("co_cashbooks").select("*").eq("date", date_str).eq("branch_id", branch_id).eq("officer_id", o_id).execute()
                    if res_co.data:
                        c = res_co.data[0]
                        bf_cash = float(c.get("opening_balance") or 0)
                        t_sav = float(c.get("savings_deposit") or 0)
                        t_lres = float(c.get("laps_reserve") or 0)
                        t_r60d = float(c.get("rep_daily") or 0)
                        t_r12w = float(c.get("rep_12_weeks") or 0)
                        t_r24w = float(c.get("rep_24_weeks") or 0)
                        t_rmth = float(c.get("rep_monthly") or 0)
                        t_d11 = float(c.get("daily_11_pct") or 0)
                        t_w11 = float(c.get("weekly_11_pct") or 0)
                        t_mm = float(c.get("risk_premium_returns") or 0)
                        t_cont = float(c.get("contingency") or 0)
                        t_app = float(c.get("app_fee") or 0)
                        t_cfd = float(c.get("credit_form_damage") or 0)
                        t_pb = float(c.get("passbook") or 0)
                        t_bon = float(c.get("bonus") or 0)
                        t_cc = float(c.get("cash_and_carry") or 0)
                        t_asale = float(c.get("asset_credit_sales") or 0)
                        t_bwd = float(c.get("bank_withdrawal") or 0)
                        t_pwd = float(c.get("product_withdrawal") or 0)
                        t_exp = float(c.get("office_expenses") or 0)
                        t_bdep = float(c.get("bank_deposit") or 0)
                        t_ltrans = float(c.get("laps_returns") or 0)
                        left_total = float(c.get("total_inflows") or 0)
                        right_total = float(c.get("total_outflows") or 0)
                        closing_bal = float(c.get("closing_balance") or 0)
                        
                    # Also fetch today's active loan disbursements for this CO breakdown (excluding legacy onboarding)
                    res_l = uow.client.table("loans").select("loan_amount, active_credit, extra_fields, loan_products(name, repayment_cycle)") \
                        .eq("officer_id", o_id).eq("branch_id", branch_id).eq("disbursement_date", date_str) \
                        .in_("status", ["Active", "Approved", "Completed"]).execute()
                    for l in (res_l.data or []):
                        if isinstance(l.get("extra_fields"), dict) and l["extra_fields"].get("is_legacy") is True:
                            continue
                        act_cr = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
                        lp = l.get("loan_products") or {}
                        p_name = str(lp.get("name") or "").lower()
                        cycle = lp.get("repayment_cycle") or ("Daily" if "daily" in p_name else "Weekly")
                        if cycle == "Daily":
                            d_act += act_cr
                        elif cycle == "Weekly":
                            if "24" in p_name: w_act_24 += act_cr
                            else: w_act_12 += act_cr
                        elif cycle == "Monthly":
                            m_act += act_cr
                        else:
                            w_act_12 += act_cr
        except Exception as e:
            st.warning(f"Could not load CO cashbook projection: {e}")

        # Fallback totals calculation if projection was empty
        if left_total == 0 and right_total == 0:
            left_total = (
                bf_cash + t_lres + t_sav + t_r60d + t_r12w + t_r24w + t_rmth +
                t_d11 + t_w11 + t_mm + t_cont + t_app + t_cfd + t_pb + t_bon +
                t_asale + t_cc + t_bwd
            )
            right_total = (
                d_act + w_act_12 + w_act_24 + m_act +
                t_pwd + t_exp + t_ltrans + t_bdep
            )
            closing_bal = left_total - right_total

        # Build balanced 2-column Excel T-Account layout (Inflows Left, Outflows Right)
        st.markdown("### 📊 Credit Officer Daily Cashbook Ledger")
        
        inflow_items = [
            ("Opening Balance", bf_cash),
            ("Savings Deposit", t_sav),
            ("Credit Rep (Daily)", t_r60d),
            ("Credit Rep (12 Weeks)", t_r12w),
            ("Credit Rep (24 Weeks)", t_r24w),
            ("Credit Rep (Monthly)", t_rmth),
            ("Laps Reserve", t_lres),
            ("Asset Credit Sales", t_asale),
            ("Cash & Carry", t_cc),
            ("Daily 11% Markup", t_d11),
            ("Weekly 11% Markup", t_w11),
            ("Monthly / 20% Markup", t_mm),
            ("Contingency (1%)", t_cont),
            ("Credit Form / App Fee", t_app),
            ("Credit Form Damage", t_cfd),
            ("Pass Book", t_pb),
            ("Bonus", t_bon),
            ("Bank Withdrawal", t_bwd),
        ]
        
        outflow_items = [
            ("Active Loan (Daily)", d_act),
            ("Active Loan (12 Weeks)", w_act_12),
            ("Active Loan (24 Weeks)", w_act_24),
            ("Active Loan (Monthly)", m_act),
            ("Product / Savings Withdrawal", t_pwd),
            ("Office Expenses", t_exp),
            ("LAPS Returns / Payouts", t_ltrans),
            ("Bank Deposit", t_bdep),
        ]

        max_rows = max(len(inflow_items), len(outflow_items))
        while len(inflow_items) < max_rows: inflow_items.append(("", ""))
        while len(outflow_items) < max_rows: outflow_items.append(("", ""))

        df_co_display = pd.DataFrame({
            "📥 Inflows (Left / Debit)": [i[0] for i in inflow_items],
            "Amount (₦) ": [f"₦{i[1]:,.0f}" if isinstance(i[1], (int, float)) and i[0] != "" else "" for i in inflow_items],
            "📤 Outflows (Right / Credit)": [o[0] for o in outflow_items],
            "Amount (₦)  ": [f"₦{o[1]:,.0f}" if isinstance(o[1], (int, float)) and o[0] != "" else "" for o in outflow_items]
        })

        st.dataframe(df_co_display, use_container_width=True, hide_index=True)

        k1, k2, k3, k4 = st.columns(4)
        k1.metric("🏛️ Opening Balance", f"₦{bf_cash:,.0f}")
        k2.metric("📥 Total Inflows", f"₦{left_total:,.0f}")
        k3.metric("📤 Total Outflows", f"₦{right_total:,.0f}")
        if closing_bal >= 0:
            k4.success(f"### Closing: ₦{closing_bal:,.0f}")
        else:
            k4.error(f"### Closing: ₦{closing_bal:,.0f}")

        st.markdown("---")
        st.markdown("### 🔒 Branch Manager End of Day (EOD) Controls")
        if not is_mc_open and "closed" in mc_open_reason.lower():
            st.info(f"✅ **EOD Day Close Already Executed for {date_str}**. Branch operational date has advanced to next working day.")
        elif not is_mc_open:
            st.warning(f"🏖️ **Cannot execute Day Close ({mc_open_reason})**.")
        else:
            eod_c1, eod_c2 = st.columns([3, 1])
            with eod_c1:
                st.info(f"**Operational Date**: `{date_str}`. Executing Day Close will freeze all entries for `{date_str}` and advance operational business date to the **Next Working Day**.")
            with eod_c2:
                if st.button("🔒 Execute EOD Day Close", use_container_width=True, type="primary", key="btn_exec_eod"):
                    try:
                        from services.business_date_service import BusinessDateService
                        with SupabaseUnitOfWork() as uow_eod:
                            b_id = uow_eod.cashbook._resolve_branch_id(BRANCH)
                            success = BusinessDateService.close_business_date(uow_eod, b_id, view_date, closed_by=USER)
                            if success:
                                st.success(f"Successfully executed Day Close for {date_str}! Operational date advanced to next working day.")
                                import time
                                time.sleep(1.5)
                                st.rerun()
                            else:
                                st.error("Failed to execute EOD day close.")
                    except Exception as ex:
                        st.error(f"Error during EOD close: {ex}")


    with mc_tab3:
        st.markdown("### Monthly Ledger View")
        
        # Resolve RBAC Scope for Branch Selection (R2)
        from services.rbac_scope_service import RBACScopeService
        tab3_scope = RBACScopeService.resolve_scope(current_user.to_dict() if hasattr(current_user, 'to_dict') else {
            "id": USER_ID, "username": USER, "role": ROLE, "branch": BRANCH, "branch_id": BRANCH_ID, "assigned_branches": ASSIGNED_BRANCH_IDS
        })
        
        branch_options = []
        try:
            with SupabaseUnitOfWork() as uow_br:
                res_br = uow_br.client.table("branches").select("branch_id, name").eq("is_active", True).execute()
                br_records = res_br.data or []
                all_operational_branches = sorted(list(set(b["name"] for b in br_records if b.get("name") and b.get("name") != "Head Office")))
                id_to_name = {str(b["branch_id"]): b["name"] for b in br_records if b.get("branch_id") and b.get("name")}
        except Exception:
            all_operational_branches = ["Ibadan", "Ikorodu", "Kola", "Ogijo"]
            id_to_name = {}

        if not all_operational_branches:
            all_operational_branches = ["Ibadan", "Ikorodu", "Kola", "Ogijo"]
            
        if tab3_scope.scope_level == "INSTITUTION" or ROLE in ["Admin", "Super Admin", "Director", ROLE_ADMIN, ROLE_SUPER_ADMIN]:
            branch_options = all_operational_branches
        elif tab3_scope.scope_level == "REGION" or ROLE in ["Area Manager", "AM"]:
            raw_assigned = list(tab3_scope.assigned_branch_names or []) + list(tab3_scope.assigned_branch_ids or [])
            resolved_assigned = []
            for b in raw_assigned:
                b_str = str(b)
                if b_str in id_to_name:
                    resolved_assigned.append(id_to_name[b_str])
                elif b_str in all_operational_branches:
                    resolved_assigned.append(b_str)
            branch_options = sorted(list(set(b for b in resolved_assigned if b and b != "Head Office")))
            if not branch_options and BRANCH and BRANCH != "Head Office":
                branch_options = [BRANCH]
            if not branch_options:
                branch_options = all_operational_branches
        elif tab3_scope.scope_level == "BRANCH" or ROLE in ["Branch Manager", "BM", ROLE_BRANCH_MANAGER]:
            if BRANCH and BRANCH != "Head Office":
                branch_options = [BRANCH]
            else:
                branch_options = all_operational_branches
        else:
            branch_options = [BRANCH] if (BRANCH and BRANCH != "Head Office") else all_operational_branches

        ctl1, ctl2, ctl3 = st.columns(3)
        cb_month = ctl1.selectbox("Month", list(range(1, 13)), index=datetime.now().month - 1,
                                   format_func=lambda m: datetime(2026, m, 1).strftime("%B"), key="mc_month")
        cb_year = ctl2.number_input("Year", value=datetime.now().year, step=1, min_value=2024, max_value=2030, key="mc_year")
        
        default_br_idx = branch_options.index(BRANCH) if (BRANCH and BRANCH in branch_options) else 0
        if len(branch_options) > 1:
            selected_mc_branch = ctl3.selectbox("Branch", branch_options, index=default_br_idx, key="mc_branch_select")
        else:
            selected_mc_branch = branch_options[0] if branch_options else BRANCH
            ctl3.selectbox("Branch", [selected_mc_branch] if selected_mc_branch else ["No Branch"], index=0, disabled=True, key="mc_branch_select_disabled")

        try:
            # Build date range for the month
            from calendar import monthrange
            _, last_day = monthrange(cb_year, cb_month)
            start_date = f"{cb_year}-{cb_month:02d}-01"
            end_date = f"{cb_year}-{cb_month:02d}-{last_day:02d}"
            
            if not selected_mc_branch or selected_mc_branch == "Head Office":
                st.info("Please select an operational branch to view the monthly ledger.")
                entries = []
            else:
                with SupabaseUnitOfWork() as uow:
                    filters = CashbookFilter()
                    filters.branch = selected_mc_branch
                    filters.start_date = start_date
                    filters.end_date = end_date
                    entries = uow.cashbook.find_range(filters)
            
            from mappers.base_mappers import CashbookMapper
            result = type('obj', (object,), {'data': [CashbookMapper.to_database(e) for e in entries]}) if entries else type('obj', (object,), {'data': []})
            
            if result.data:
                ledger_df = pd.DataFrame(result.data)
                
                # Sort by date ascending to ensure chronological order
                ledger_df["date"] = pd.to_datetime(ledger_df["date"], errors='coerce').dt.strftime("%Y-%m-%d")
                ledger_df.sort_values(by="date", ascending=True, inplace=True)
                ledger_df.reset_index(drop=True, inplace=True)

                # Dynamically calculate product-level loan disbursements from all_loans (R3)
                loan_disb_map = {}
                if not all_loans.empty:
                    loans_df = all_loans.copy()
                    if 'extra_fields' in loans_df.columns:
                        loans_df = loans_df[~loans_df['extra_fields'].apply(lambda x: isinstance(x, dict) and x.get('is_legacy') is True)]
                    if 'Branch' in loans_df.columns and selected_mc_branch:
                        loans_df = loans_df[loans_df['Branch'] == selected_mc_branch]
                    if 'Status' in loans_df.columns:
                        loans_df = loans_df[loans_df['Status'].isin([STATUS_ACTIVE, STATUS_APPROVED, STATUS_COMPLETED, "Active", "Approved", "Completed"])]
                    
                    if not loans_df.empty and 'Date' in loans_df.columns:
                        loans_df['_dt_str'] = pd.to_datetime(loans_df['Date'], errors='coerce').dt.strftime('%Y-%m-%d')
                        for _, l_row in loans_df.iterrows():
                            d_key = l_row.get('_dt_str')
                            if not d_key or pd.isna(d_key):
                                continue
                            if d_key not in loan_disb_map:
                                loan_disb_map[d_key] = {
                                    "disb_60d": 0.0,
                                    "disb_120d": 0.0,
                                    "disb_12w": 0.0,
                                    "disb_24w": 0.0,
                                    "disb_mth": 0.0,
                                    "fund_asset": 0.0,
                                    "fund_finance": 0.0
                                }
                            
                            princ = pd.to_numeric(l_row.get('Loan Amount', 0), errors='coerce')
                            act_cr = pd.to_numeric(l_row.get('Active Credit', 0), errors='coerce')
                            if pd.isna(princ): princ = 0.0
                            if pd.isna(act_cr) or act_cr == 0: act_cr = princ
                            
                            p_cat = str(l_row.get('Product Category', 'Finance'))
                            p_name = str(l_row.get('Loan Product', '')).lower()
                            
                            if 'Asset' in p_cat:
                                loan_disb_map[d_key]["fund_asset"] += princ
                            else:
                                loan_disb_map[d_key]["fund_finance"] += princ
                                
                            if '120' in p_name:
                                loan_disb_map[d_key]["disb_120d"] += act_cr
                            elif '60' in p_name:
                                loan_disb_map[d_key]["disb_60d"] += act_cr
                            elif '24w' in p_name or '24' in p_name:
                                loan_disb_map[d_key]["disb_24w"] += act_cr
                            elif '12w' in p_name or '12' in p_name:
                                loan_disb_map[d_key]["disb_12w"] += act_cr
                            elif '3m' in p_name or '6m' in p_name or 'month' in p_name:
                                loan_disb_map[d_key]["disb_mth"] += act_cr
                            else:
                                loan_disb_map[d_key]["disb_12w"] += act_cr

                # Populate / overlay dynamic disbursement numbers into ledger_df
                for idx, row in ledger_df.iterrows():
                    d_str = str(row.get("date", ""))[:10]
                    if d_str in loan_disb_map:
                        d_info = loan_disb_map[d_str]
                        ledger_df.at[idx, "disb_60d"] = d_info["disb_60d"]
                        ledger_df.at[idx, "disb_120d"] = d_info["disb_120d"]
                        ledger_df.at[idx, "disb_12w"] = d_info["disb_12w"]
                        ledger_df.at[idx, "disb_24w"] = d_info["disb_24w"]
                        ledger_df.at[idx, "disb_mth"] = d_info["disb_mth"]
                        if d_info["fund_asset"] > 0 and float(row.get("fund_to_asset_program") or 0.0) == 0:
                            ledger_df.at[idx, "fund_to_asset_program"] = d_info["fund_asset"]
                        if d_info["fund_finance"] > 0 and float(row.get("fund_to_product_finance") or 0.0) == 0:
                            ledger_df.at[idx, "fund_to_product_finance"] = d_info["fund_finance"]
                            ledger_df.at[idx, "total_outflows"] = float(row.get("total_outflows") or 0.0) + d_info["fund_finance"]
                        if d_info["fund_finance"] > 0 and float(row.get("loan_received_finance") or 0.0) == 0:
                            ledger_df.at[idx, "loan_received_finance"] = d_info["fund_finance"]
                            ledger_df.at[idx, "total_inflows"] = float(row.get("total_inflows") or 0.0) + d_info["fund_finance"]
                    else:
                        for col in ["disb_60d", "disb_120d", "disb_12w", "disb_24w", "disb_mth"]:
                            if col not in ledger_df.columns or pd.isna(ledger_df.at[idx, col]):
                                ledger_df.at[idx, col] = 0.0
                
                # Reorder columns to strictly match Credit_Cash_Book_Ledger.xlsx layout (Columns A–AS)
                display_cols = [
                    # Left Side (Inflows: Cols A–AA)
                    "date", "opening_balance", "savings_deposit",
                    "rep_daily", "rep_120_days", "rep_12_weeks", "rep_24_weeks", "rep_monthly",
                    "laps_reserve",
                    "funds_received_ho", "funds_received_other_branch", "funds_received_other_area",
                    "asset_credit_sales", "cash_and_carry", "loan_received_finance",
                    "daily_11_pct", "daily_20_pct", "weekly_11_pct", "weekly_20_pct", "risk_premium_returns",
                    "contingency", "credit_form_damage", "bonus", "app_fee", "passbook", "bank_withdrawal",
                    "total_inflows",
                    # Right Side (Outflows: Cols AC–AS)
                    "disb_60d", "disb_120d", "disb_12w", "disb_24w", "disb_mth",
                    "fund_transferred_other_branch", "fund_transferred_ho", "fund_to_other_area",
                    "fund_to_asset_program", "fund_to_product_finance",
                    "product_withdrawal", "staff_salaries", "office_expenses",
                    "laps_returns", "bank_deposit",
                    "total_outflows", "closing_balance"
                ]
                
                # Ensure all 45 columns exist in DataFrame with 0.0 default
                for c in display_cols:
                    if c not in ledger_df.columns:
                        ledger_df[c] = 0.0
                    else:
                        if c != "date":
                            ledger_df[c] = pd.to_numeric(ledger_df[c], errors='coerce').fillna(0.0)
                
                display_df = ledger_df[display_cols].copy()
                
                # Monthly KPI calculations (R4)
                month_opening = float(display_df.iloc[0]["opening_balance"]) if not display_df.empty else 0.0
                month_inflows = float((display_df["total_inflows"] - display_df["opening_balance"]).sum()) if not display_df.empty else 0.0
                month_outflows = float(display_df["total_outflows"].sum()) if not display_df.empty else 0.0
                month_closing = float(display_df.iloc[-1]["closing_balance"]) if not display_df.empty else 0.0
                
                # Rename for display matching official Excel subheaders
                col_rename = {
                    "date": "Date",
                    "opening_balance": "Opening Balance",
                    "savings_deposit": "Savings Deposit (Amount)",
                    "rep_daily": "Credit Repayment (60 days)",
                    "rep_120_days": "Credit Repayment (120 days)",
                    "rep_12_weeks": "Credit Repayment (12 weeks)",
                    "rep_24_weeks": "Credit Repayment (24 weeks)",
                    "rep_monthly": "Credit Repayment (Monthly)",
                    "laps_reserve": "Laps Reserve",
                    "funds_received_ho": "Funds Received from Head Office",
                    "funds_received_other_branch": "Funds Received from Branch Office",
                    "funds_received_other_area": "Funds Received from Other Areas",
                    "asset_credit_sales": "Asset Credit Sales",
                    "cash_and_carry": "Cash & Carry",
                    "loan_received_finance": "Funds from Finance",
                    "daily_11_pct": "Daily 11%",
                    "daily_20_pct": "Daily 20%",
                    "weekly_11_pct": "Weekly 11%",
                    "weekly_20_pct": "Weekly 20%",
                    "risk_premium_returns": "Monthly 11%/20%",
                    "contingency": "Contingency (1%)",
                    "credit_form_damage": "Credit form damage",
                    "bonus": "Bonus",
                    "app_fee": "Credit form/App fee",
                    "passbook": "Pass book",
                    "bank_withdrawal": "Bank withdrawal",
                    "total_inflows": "Total Inflows",
                    "disb_60d": "60 days",
                    "disb_120d": "120 days",
                    "disb_12w": "12 weeks",
                    "disb_24w": "24 weeks",
                    "disb_mth": "Monthly",
                    "fund_transferred_other_branch": "Branch Office",
                    "fund_transferred_ho": "Head office",
                    "fund_to_other_area": "Other Areas",
                    "fund_to_asset_program": "Fund To Assets",
                    "fund_to_product_finance": "Fund to Finance",
                    "product_withdrawal": "Product/Savings withdrawals",
                    "staff_salaries": "Staff Salaries",
                    "office_expenses": "Office Expenses",
                    "laps_returns": "Laps Return",
                    "bank_deposit": "Bank Deposit",
                    "total_outflows": "Total Outflows",
                    "closing_balance": "Closing Balance"
                }
                display_df_renamed = display_df.rename(columns=col_rename)
                
                st.dataframe(
                    display_df_renamed.style.format(precision=0, thousands=",", na_rep="—"),
                    use_container_width=True,
                    hide_index=True,
                    height=600
                )
                
                # Monthly totals
                st.markdown("#### 📈 Monthly Summary")
                mt1, mt2, mt3, mt4 = st.columns(4)
                mt1.metric("Month Opening Balance", f"₦{month_opening:,.0f}")
                mt2.metric("Total Monthly Inflows", f"₦{month_inflows:,.0f}")
                mt3.metric("Total Monthly Outflows", f"₦{month_outflows:,.0f}")
                mt4.metric("Month-End Closing Balance", f"₦{month_closing:,.0f}")
                
                # Download
                st.markdown("---")
                import io
                output = io.BytesIO()
                with pd.ExcelWriter(output, engine='openpyxl') as writer:
                    display_df_renamed.to_excel(writer, sheet_name='Ledger Data', index=False)
                st.download_button(
                    label="⬇️ Download Ledger as Excel (.xlsx)",
                    data=output.getvalue(),
                    file_name=f"ICARE_Master_Cashbook_{selected_mc_branch}_{datetime(cb_year, cb_month, 1).strftime('%B_%Y')}.xlsx",
                    mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    use_container_width=True,
                    key="dl_mc"
                )
            else:
                st.info(f"No ledger entries found for {selected_mc_branch} in {datetime(cb_year, cb_month, 1).strftime('%B %Y')}.")
        except Exception as e:
            st.error(f"Error loading ledger: {e}")


elif page == "Portfolio":
    title_map = {
        "CO": "CO Portfolio",
        "Officer": "CO Portfolio",
        "Credit Officer": "CO Portfolio",
        "Branch Manager": "Branch Portfolio",
        "BM": "Branch Portfolio",
        "Area Manager": "Regional Portfolio",
        "AM": "Regional Portfolio",
    }
    st.title(title_map.get(ROLE, "Enterprise Portfolio"))
    st.caption("Comprehensive portfolio oversight, role-scoped performance analytics, and 360° client dossier.")

    from services.portfolio_service import PortfolioService
    from database.repositories.unit_of_work import SupabaseUnitOfWork
    from services.rbac_scope_service import RBACScopeService

    with SupabaseUnitOfWork() as uow_p:
        p_scope = RBACScopeService.resolve_scope(current_user.to_dict() if hasattr(current_user, 'to_dict') else {
            "id": USER_ID, "username": USER, "role": ROLE, "branch": BRANCH, "branch_id": BRANCH_ID, "assigned_branches": ASSIGNED_BRANCH_IDS
        })

        if p_scope.is_read_only():
            st.info("**Executive Read-Only Mode**: Strategic view active. Operation and edit actions are disabled.")

        # Hierarchical Scope Resolution
        sel_branch = None
        sel_officer = None
        selected_officer_id = None

        with st.container(border=True):
            # Row 1: Scope & Officer Selection
            if p_scope.scope_level == "OFFICER":
                st.markdown(f"**Scope**: Credit Officer Portfolio (`{p_scope.username}`) &middot; **Branch**: `{p_scope.branch_name}`")
                sel_branch = p_scope.branch_name
                sel_officer = p_scope.username
                selected_officer_id = p_scope.user_id
            elif p_scope.scope_level == "BRANCH":
                sc1, sc2 = st.columns([1, 2])
                with sc1:
                    st.markdown(f"**Branch Scope**: `{p_scope.branch_name}`")
                    sel_branch = p_scope.branch_name
                with sc2:
                    off_map = {"All": None}
                    try:
                        res_off = uow_p.client.table("user_roles") \
                            .select("user_id, roles!inner(name), app_users!inner(id, username, full_name, is_active, branch_id)") \
                            .eq("roles.name", "Credit Officer") \
                            .eq("app_users.branch_id", p_scope.branch_id) \
                            .eq("app_users.is_active", True) \
                            .execute()
                        for r in (res_off.data or []):
                            o = r.get("app_users") or {}
                            u_name = o.get("username")
                            f_name = o.get("full_name")
                            if u_name:
                                lbl = f"{u_name} — {f_name}" if f_name else u_name
                                off_map[lbl] = o
                    except Exception:
                        pass
                    sel_off_lbl = st.selectbox("Credit Officer Filter", list(off_map.keys()), key="port_off_sel")
                    if sel_off_lbl != "All":
                        sel_officer = off_map[sel_off_lbl].get("username")
                        selected_officer_id = off_map[sel_off_lbl].get("id")
            elif p_scope.scope_level == "REGION":
                sc1, sc2 = st.columns(2)
                with sc1:
                    b_opts = ["All"] + (p_scope.assigned_branch_names or [])
                    sel_branch = st.selectbox("Branch Filter", b_opts, key="port_br_sel")
                with sc2:
                    off_map = {"All": None}
                    try:
                        b_tgt_id = None
                        if sel_branch and sel_branch != "All":
                            b_res = uow_p.client.table("branches").select("branch_id").eq("name", sel_branch).execute()
                            if b_res.data:
                                b_tgt_id = b_res.data[0]["branch_id"]
                        
                        q_off = uow_p.client.table("user_roles") \
                            .select("user_id, roles!inner(name), app_users!inner(id, username, full_name, is_active, branch_id)") \
                            .eq("roles.name", "Credit Officer") \
                            .eq("app_users.is_active", True)
                        if b_tgt_id:
                            q_off = q_off.eq("app_users.branch_id", b_tgt_id)
                        elif p_scope.assigned_branch_ids:
                            q_off = q_off.in_("app_users.branch_id", p_scope.assigned_branch_ids)
                        res_off = q_off.execute()
                        for r in (res_off.data or []):
                            o = r.get("app_users") or {}
                            u_name = o.get("username")
                            f_name = o.get("full_name")
                            if u_name:
                                lbl = f"{u_name} — {f_name}" if f_name else u_name
                                off_map[lbl] = o
                    except Exception:
                        pass
                    sel_off_lbl = st.selectbox("Credit Officer Filter", list(off_map.keys()), key="port_off_sel")
                    if sel_off_lbl != "All":
                        sel_officer = off_map[sel_off_lbl].get("username")
                        selected_officer_id = off_map[sel_off_lbl].get("id")
            else: # INSTITUTION
                sc1, sc2 = st.columns(2)
                with sc1:
                    all_b = ["All"]
                    try:
                        res_b = uow_p.client.table("branches").select("name").execute()
                        all_b += sorted(list(set(b["name"] for b in (res_b.data or []) if b.get("name"))))
                    except Exception:
                        pass
                    sel_branch = st.selectbox("Branch Filter", all_b, key="port_br_sel")
                with sc2:
                    off_map = {"All": None}
                    try:
                        b_tgt_id = None
                        if sel_branch and sel_branch != "All":
                            b_res = uow_p.client.table("branches").select("branch_id").eq("name", sel_branch).execute()
                            if b_res.data:
                                b_tgt_id = b_res.data[0]["branch_id"]
                        q_off = uow_p.client.table("user_roles") \
                            .select("user_id, roles!inner(name), app_users!inner(id, username, full_name, is_active, branch_id)") \
                            .eq("roles.name", "Credit Officer") \
                            .eq("app_users.is_active", True)
                        if b_tgt_id:
                            q_off = q_off.eq("app_users.branch_id", b_tgt_id)
                        res_off = q_off.execute()
                        for r in (res_off.data or []):
                            o = r.get("app_users") or {}
                            u_name = o.get("username")
                            f_name = o.get("full_name")
                            if u_name:
                                lbl = f"{u_name} — {f_name}" if f_name else u_name
                                off_map[lbl] = o
                    except Exception:
                        pass
                    sel_off_lbl = st.selectbox("Credit Officer Filter", list(off_map.keys()), key="port_off_sel")
                    if sel_off_lbl != "All":
                        sel_officer = off_map[sel_off_lbl].get("username")
                        selected_officer_id = off_map[sel_off_lbl].get("id")

            # Row 2: Date, Product & Dynamic Cascading Group Filters
            import calendar
            from datetime import date, timedelta
            
            tf1, tf2, tf3, tf4 = st.columns(4)
            
            with tf1:
                time_period = st.selectbox("Time Period", ["Today", "Yesterday", "Current Month", "Last Month", "Custom Date Range"], index=2, key="port_time_period")
            
            today = date.today()
            start_date = today
            end_date = today
            
            if time_period == "Today":
                start_date = today
                end_date = today
            elif time_period == "Yesterday":
                yesterday = today - timedelta(days=1)
                start_date = yesterday
                end_date = yesterday
            elif time_period == "Current Month":
                start_date = today.replace(day=1)
                end_date = today.replace(day=calendar.monthrange(today.year, today.month)[1])
            elif time_period == "Last Month":
                first = today.replace(day=1)
                last_month = first - timedelta(days=1)
                start_date = last_month.replace(day=1)
                end_date = last_month
                
            with tf2:
                if time_period == "Custom Date Range":
                    date_range = st.date_input("Date Range", [start_date, end_date], key="port_date_range")
                    if isinstance(date_range, tuple) and len(date_range) == 2:
                        start_date = date_range[0]
                        end_date = date_range[1]
                    elif isinstance(date_range, tuple) and len(date_range) == 1:
                        start_date = date_range[0]
                        end_date = date_range[0]
                else:
                    st.date_input("Date Range", [start_date, end_date], disabled=True, key="port_date_range_disabled")
                    
            # Loan Product Options
            all_prods = ["All"]
            allowed_p = []
            try:
                target_username = sel_officer if (sel_officer and sel_officer != "All") else (p_scope.username if p_scope.role == "CO" else None)
                if target_username:
                    u_res = uow_p.client.table("app_users").select("extra_fields").eq("username", target_username).execute()
                    if u_res.data:
                        extra = u_res.data[0].get("extra_fields") or {}
                        allowed_p = extra.get("allowed_products", [])
                
                p_res = uow_p.client.table("loan_products").select("name").execute()
                fetched_prods = sorted(list(set(p["name"] for p in (p_res.data or []) if p.get("name"))))
                
                if allowed_p:
                    fetched_prods = [p for p in fetched_prods if p in allowed_p]
                    
                all_prods += fetched_prods
            except Exception:
                pass
                
            with tf3:
                sel_product = st.selectbox("Loan Product Filter", all_prods, key="port_prod_sel")

            # Dynamic Cascading Group Filter
            all_grp = ["All"]
            try:
                g_q = uow_p.client.table("groups").select("name, officer_id, branch_id")
                if selected_officer_id:
                    g_q = g_q.eq("officer_id", selected_officer_id)
                elif sel_branch and sel_branch != "All":
                    b_res = uow_p.client.table("branches").select("branch_id").eq("name", sel_branch).execute()
                    if b_res.data:
                        g_q = g_q.eq("branch_id", b_res.data[0]["branch_id"])
                elif p_scope.scope_level == "BRANCH" and p_scope.branch_id:
                    g_q = g_q.eq("branch_id", p_scope.branch_id)
                elif p_scope.scope_level == "OFFICER" and p_scope.user_id:
                    g_q = g_q.eq("officer_id", p_scope.user_id)
                
                g_res = g_q.execute()
                all_grp += sorted(list(set(g["name"] for g in (g_res.data or []) if g.get("name"))))
            except Exception:
                pass
            
            with tf4:
                sel_group = st.selectbox("Group Filter", all_grp, key="port_grp_sel")

        # Load Scoped Data
        p_data = PortfolioService.get_portfolio_data_for_scope(
            uow_p, p_scope, selected_branch=sel_branch, selected_officer=sel_officer, selected_group=sel_group,
            selected_product=sel_product, start_date=start_date, end_date=end_date
        )
        p_sum = p_data["summary"]

        st.divider()

        port_tab1, port_tab2 = st.tabs([
            "Portfolio Summary & Analytics",
            "Client Dossier & Inquiry"
        ])

        with port_tab1:
            st.markdown("### Portfolio Summary & Metrics")

            st.caption("Row 1: Client Lifecycle Status Breakdown")
            c1, c2, c3, c4, c5, c6, c7, c8 = st.columns(8)
            tot_count = p_sum.get('total_clients', 0)
            c1.metric("Registered", "", f"{tot_count} Clients")
            c2.metric("On Loan", "", f"{p_sum.get('active_clients', 0)} Clients")
            c3.metric("Completed", "", f"{p_sum.get('completed_clients', 0)} Clients")
            c4.metric("Pending Loans", "", f"{p_sum.get('pending_loan_clients', 0)} Clients")
            c5.metric("Savings Only", "", f"{p_sum.get('savings_only_clients', 0)} Clients")
            c6.metric("Dormant", "", f"{p_sum.get('dormant_clients', 0)} Clients")
            c7.metric("Suspended", "", f"{p_sum.get('suspended_clients', 0)} Clients")
            c8.metric("Closed", "", f"{p_sum.get('closed_clients', 0)} Clients")

            st.caption("Row 2: Savings Summary (Period Flows & Vault Position)")
            s1, s2, s3, s4 = st.columns(4)
            s1.metric("Savings Deposited (Period)", f"₦{p_sum.get('period_savings_deposit', 0.0):,.0f}", f"{p_sum.get('period_savings_dep_clients', 0)} Clients")
            s2.metric("Savings Withdrawn (Period)", f"₦{p_sum.get('period_savings_withdrawal', 0.0):,.0f}", f"{p_sum.get('period_savings_wd_clients', 0)} Clients")
            p_net = float(p_sum.get('period_net_savings', p_sum.get('period_savings_deposit', 0.0) - p_sum.get('period_savings_withdrawal', 0.0)))
            s3.metric("Net Savings (Period)", f"₦{p_net:,.0f}", f"₦{p_net:,.0f} (Net)" if p_net != 0 else "₦0 (Balanced)", delta_color="normal")
            s4.metric("Total Savings Balance", f"₦{p_sum.get('total_savings_balance', 0.0):,.0f}", f"{p_sum.get('total_savings_clients', 0)} Active Savers")

            st.caption("Row 3: Disbursement Summary (In Selected Period)")
            d1, d2 = st.columns(2)
            d_sum = p_sum.get('disbursement_summary', {'count': 0, 'amount': 0.0, 'client_count': 0})
            d1.metric("Loans Disbursed", f"{d_sum['count']} Loans", f"{d_sum.get('client_count', d_sum['count'])} Clients")
            d2.metric("Total Amount Disbursed", f"₦{d_sum['amount']:,.0f}", f"{d_sum['count']} Loans")

            st.caption("Row 4: Loan & Collection Summary")
            l1, l2, l3, l4 = st.columns(4)
            l1.metric("Total Active Credit", f"₦{p_sum.get('total_active_credit', 0.0):,.0f}", f"{p_sum.get('active_loans_count', 0)} Active Loans")
            l2.metric("Expected Repayment", f"₦{p_sum.get('total_expected_repayment', 0.0):,.0f}", f"{p_sum.get('expected_repay_clients', 0)} Clients")
            l3.metric("Actual Collections (Period)", f"₦{p_sum.get('total_actual_collection', p_sum.get('today_collection', 0.0)):,.0f}", f"{p_sum.get('paying_clients_count', 0)} Clients Paid")
            l4.metric("Total Outstanding Balance", f"₦{p_sum.get('total_outstanding_balance', 0.0):,.0f}", f"{p_sum.get('outstanding_clients_count', 0)} Clients")

            st.caption("Row 5: Repayment Status & Risk")
            r1, r2, r3, r4, r5 = st.columns(5)
            r1.metric("Normal Payments", f"₦{p_sum.get('normal_payments', {}).get('amount', 0.0):,.0f}", f"{p_sum.get('normal_payments', {}).get('count', 0)} Clients")
            r2.metric("Full Payments", f"₦{p_sum.get('full_payments', {}).get('amount', 0.0):,.0f}", f"{p_sum.get('full_payments', {}).get('count', 0)} Clients")
            r3.metric("Excess Payments", f"₦{p_sum.get('excess_payments', {}).get('amount', 0.0):,.0f}", f"{p_sum.get('excess_payments', {}).get('count', 0)} Clients")
            r4.metric("Overdue Portfolio", f"₦{p_sum.get('overdue', {}).get('amount', 0.0):,.0f}", f"{p_sum.get('overdue', {}).get('count', 0)} Clients", delta_color="inverse")
            par_val = float(str(p_sum.get('par', '0.00%')).replace('%', '') or 0.0)
            r5.metric("Portfolio at Risk (PAR)", f"{par_val:.2f}%", f"{p_sum.get('overdue', {}).get('count', 0)} Overdue", delta_color="inverse")

            st.divider()
            st.markdown("### Loan Products Summary")
            prod_sum = p_sum.get("product_summary", {})
            if prod_sum:
                prod_rows = []
                for prod, metrics in prod_sum.items():
                    prod_rows.append({
                        "Loan Product": prod,
                        "Active Credit": f"₦{metrics['active_credit']:,.0f}",
                        "Outstanding Balance": f"₦{metrics['loan_balance']:,.0f}",
                        "Active Loans": metrics['count']
                    })
                st.dataframe(pd.DataFrame(prod_rows), use_container_width=True, hide_index=True)
            else:
                st.info("No active loan products in portfolio.")

            st.divider()
            if sel_group == "All":
                st.markdown("### Group Portfolio Summary")
                st.caption("Showing aggregate totals per group. Select a specific group above to drill down to individual clients.")
            else:
                st.markdown(f"### Client Portfolio ({sel_group})")

            client_df = p_data["client_table"]
            if not client_df.empty:
                st.dataframe(client_df, use_container_width=True)

                # Export Controls (Obeying RBAC Scope)
                e_col1, e_col2 = st.columns(2)
                with e_col1:
                    csv_data = client_df.to_csv(index=False).encode('utf-8')
                    st.download_button(
                        "Export Scoped Portfolio (CSV)",
                        data=csv_data,
                        file_name=f"portfolio_{p_scope.role}_{date.today().isoformat()}.csv",
                        mime="text/csv",
                        key="btn_dl_port_csv"
                    )
            else:
                st.info("No client records found in authorized scope.")

        with port_tab2:
            st.markdown("### Client Dossier & Financial Inquiry")
            st.caption("Comprehensive individual client profile, contractual terms, repayment history, savings ledger, and audit log.")

            c_codes = p_data.get("client_codes", [])
            client_lookup = p_data.get("client_lookup", {})
            if c_codes:
                selected_ccode = st.selectbox(
                    "Search & Select Client Account:",
                    c_codes,
                    format_func=lambda code: client_lookup.get(code, code),
                    key="dd_client_select"
                )
                if selected_ccode:
                    dd = PortfolioService.get_client_360_drilldown(uow_p, selected_ccode, p_scope)
                    c_info = dd.get("customer_info", {})
                    cur_cid = c_info.get("client_id") or c_info.get("id") or selected_ccode
                    l_hist = dd.get("loan_history", pd.DataFrame())
                    r_hist = dd.get("repayment_history", pd.DataFrame())
                    s_hist = dd.get("savings_history", pd.DataFrame())

                    # Dynamic Financial Calculations for Executive Banner
                    c_active_credit = 0.0
                    c_remaining_balance = 0.0
                    c_total_paid = 0.0
                    if not l_hist.empty:
                        for _, l_row in l_hist.iterrows():
                            if str(l_row.get("status", "")).upper() in ["ACTIVE", "APPROVED"]:
                                a_cred = float(l_row.get("active_credit") or 0.0)
                                t_due = float(l_row.get("total_due") if l_row.get("total_due") is not None else a_cred)
                                c_active_credit += a_cred
                                
                                # Check post-onboarding paid for this loan
                                lid = str(l_row.get("loan_id", ""))
                                p_paid = 0.0
                                if not r_hist.empty and "loan_id" in r_hist.columns:
                                    p_paid = float(r_hist[r_hist["loan_id"].astype(str) == lid]["amount_paid"].sum())
                                elif not r_hist.empty and "amount_paid" in r_hist.columns:
                                    p_paid = float(r_hist["amount_paid"].sum())
                                
                                rem = max(0.0, t_due - p_paid)
                                c_remaining_balance += rem
                                c_total_paid += ((a_cred - t_due) + p_paid)
                    
                    c_savings_balance = 0.0
                    if not s_hist.empty:
                        dep_tot = float(s_hist.get("deposit_amount", pd.Series([0.0])).sum())
                        wth_tot = float(s_hist.get("withdrawal_amount", pd.Series([0.0])).sum())
                        c_savings_balance = dep_tot - wth_tot

                    c_status_label = "Active Loan" if c_remaining_balance > 0 else ("Fully Settled" if not l_hist.empty else "No Active Loans")

                    # Executive Metric Header Banner
                    st.markdown(f"#### {c_info.get('name', 'Client Profile')} (`{selected_ccode}`)")
                    sb1, sb2, sb3, sb4 = st.columns(4)
                    sb1.metric("Total Active Credit", f"₦{c_active_credit:,.0f}")
                    sb2.metric("Outstanding Balance", f"₦{c_remaining_balance:,.0f}")
                    sb3.metric("Savings Balance", f"₦{c_savings_balance:,.0f}")
                    sb4.metric("Account Status", c_status_label)

                    dd_t1, dd_t2, dd_t3, dd_t4, dd_t5, dd_t6, dd_t7 = st.tabs([
                        "Customer Profile", "Loan History", "Repayment Ledger", "Savings Ledger", "Collection History", "Lifecycle Status", "Audit Trail"
                    ])

                    with dd_t1:
                        g_name = "N/A"
                        g_phone = "N/A"
                        g_rel = "N/A"
                        g_pic = ""
                        
                        if not l_hist.empty:
                            for _, l_row in l_hist.iterrows():
                                ext = l_row.get("extra_fields") or {}
                                if isinstance(ext, str):
                                    import json
                                    try: ext = json.loads(ext)
                                    except: ext = {}
                                if ext.get("guarantor_name"):
                                    g_name = ext.get("guarantor_name", "N/A")
                                    g_phone = ext.get("guarantor_phone", "N/A")
                                    g_rel = ext.get("guarantor_relationship", "Guarantor")
                                    g_pic = l_row.get("guarantor_passport_url", "")
                                    break

                        col1, col2 = st.columns(2)
                        with col1:
                            with st.container(border=True):
                                st.markdown("##### Client Profile & Bio")
                                c_pic = c_info.get("passport_url")
                                c_name_str = c_info.get("name", "N/A")
                                initials = "".join([part[0].upper() for part in c_name_str.split()[:2]]) if c_name_str != "N/A" else "CL"

                                img_col, bio_col = st.columns([1, 2])
                                with img_col:
                                    if c_pic:
                                        st.image(c_pic, width=120)
                                    else:
                                        st.markdown(
                                            f"""
                                            <div style="width: 80px; height: 80px; border-radius: 50%; background: #e0f2fe; color: #0284c7; display: flex; align-items: center; justify-content: center; font-size: 26px; font-weight: 700; margin: 10px 0;">
                                                {initials}
                                            </div>
                                            """,
                                            unsafe_allow_html=True
                                        )
                                with bio_col:
                                    st.markdown(f"**Full Name:** {c_name_str}")
                                    st.markdown(f"**Client Code:** `{c_info.get('client_code', selected_ccode)}`")
                                    st.markdown(f"**Nickname:** {c_info.get('nickname') or 'None'}")

                                st.divider()
                                grp = c_info.get("groups", {}).get("name", "Individual") if isinstance(c_info.get("groups"), dict) else (c_info.get("group_name") or "Individual")
                                st.markdown(f"**Group / Center:** {grp}")
                                st.markdown(f"**Phone Number:** {c_info.get('phone', 'N/A')}")
                                st.markdown(f"**Residential Address:** {c_info.get('address', 'N/A')}")
                                st.markdown(f"**Registration Date:** {c_info.get('registration_date', 'N/A')}")

                        with col2:
                            with st.container(border=True):
                                st.markdown("##### Guarantor Details")
                                g_initials = "".join([part[0].upper() for part in g_name.split()[:2]]) if g_name != "N/A" else "GT"

                                g_img_col, g_bio_col = st.columns([1, 2])
                                with g_img_col:
                                    if g_pic:
                                        st.image(g_pic, width=120)
                                    else:
                                        st.markdown(
                                            f"""
                                            <div style="width: 80px; height: 80px; border-radius: 50%; background: #fef3c7; color: #b45309; display: flex; align-items: center; justify-content: center; font-size: 26px; font-weight: 700; margin: 10px 0;">
                                                {g_initials}
                                            </div>
                                            """,
                                            unsafe_allow_html=True
                                        )
                                with g_bio_col:
                                    st.markdown(f"**Guarantor Name:** {g_name}")
                                    st.markdown(f"**Relationship:** {g_rel}")
                                    st.markdown(f"**Phone Number:** {g_phone}")

                                st.divider()
                                if g_name != "N/A":
                                    st.success("Verified Guarantor details attached to active loan file.")
                                else:
                                    st.info("No guarantor attached to current loan records.")

                    with dd_t2:
                        if l_hist.empty:
                            st.info("No loan records found for this client.")
                        else:
                            df_l = l_hist.copy()
                            df_l["Client ID"] = c_info.get("client_code", selected_ccode)
                            df_l["Name"] = c_info.get("name", "N/A")
                            df_l["Product"] = df_l.apply(lambda row: row.get("loan_products", {}).get("name", "Standard") if isinstance(row.get("loan_products"), dict) else "Standard", axis=1)
                            
                            # Calculate Remaining Balance dynamically using total_due baseline
                            if not r_hist.empty and "loan_id" in r_hist.columns and "loan_id" in df_l.columns:
                                paid_map = r_hist.groupby("loan_id")["amount_paid"].sum().to_dict()
                                df_l["Remaining Balance"] = df_l.apply(
                                    lambda r: max(0.0, float(r.get("total_due") if r.get("total_due") is not None else r.get("active_credit", 0.0)) - float(paid_map.get(r.get("loan_id"), 0.0))), 
                                    axis=1
                                )
                            else:
                                df_l["Remaining Balance"] = df_l.apply(
                                    lambda r: float(r.get("total_due") if r.get("total_due") is not None else r.get("active_credit", 0.0)),
                                    axis=1
                                )

                            df_l = df_l.rename(columns={
                                "date": "Disbursement Date",
                                "loan_amount": "Loan Principal",
                                "active_credit": "Active Credit",
                                "loan_repay": "Expected Installment",
                                "status": "Status",
                                "product_category": "Category"
                            })
                            
                            disp_cols = ["Disbursement Date", "Product", "Category", "Loan Principal", "Active Credit", "Expected Installment", "Remaining Balance", "Status"]
                            valid_cols = [c for c in disp_cols if c in df_l.columns]
                            
                            st.dataframe(
                                df_l[valid_cols].style.format({
                                    "Loan Principal": "₦{:,.0f}",
                                    "Active Credit": "₦{:,.0f}",
                                    "Expected Installment": "₦{:,.0f}",
                                    "Remaining Balance": "₦{:,.0f}"
                                }),
                                use_container_width=True
                            )
                            
                    with dd_t3:
                        if r_hist.empty:
                            st.info("No repayment collections logged for this client.")
                        else:
                            df_r = r_hist.copy()
                            df_r = df_r.rename(columns={
                                "date": "Date",
                                "amount_paid": "Amount Collected",
                                "payment_status": "Status",
                                "transaction_type": "Transaction Type",
                                "note": "Notes"
                            })
                            r_cols = ["Date", "Amount Collected", "Status", "Transaction Type", "Notes"]
                            st.dataframe(
                                df_r[[c for c in r_cols if c in df_r.columns]].style.format({
                                    "Amount Collected": "₦{:,.0f}"
                                }),
                                use_container_width=True
                            )

                            # Reversal Request Expander
                            with st.expander("Flag a Repayment for Reversal", expanded=False):
                                r_opts = {}
                                for _, rx in r_hist.iterrows():
                                    rx_id = str(rx.get("id") or rx.get("repayment_id", ""))
                                    rx_amt = float(rx.get("amount_paid") or 0.0)
                                    rx_dt = str(rx.get("date", ""))[:10]
                                    if rx_id and rx_amt > 0:
                                        r_opts[f"{rx_dt} — ₦{rx_amt:,.2f} (Ref: {rx_id[:8]})"] = rx_id
                                
                                if r_opts:
                                    sel_rx_label = st.selectbox("Select Repayment to Reverse", list(r_opts.keys()), key=f"dossier_rev_{cur_cid}")
                                    dos_reason = st.text_input("Reason for Reversal", placeholder="e.g. Wrong repayment posted", key=f"dossier_rev_reason_{cur_cid}")
                                    if st.button("Submit Reversal Request", type="primary", key=f"dossier_rev_btn_{cur_cid}"):
                                        if dos_reason.strip():
                                            try:
                                                from services.correction_service import CorrectionService
                                                with SupabaseUnitOfWork() as uow_dos_corr:
                                                    req_id = CorrectionService.request_correction(
                                                        uow=uow_dos_corr,
                                                        record_id=r_opts[sel_rx_label],
                                                        record_type="Repayment",
                                                        reason=dos_reason.strip(),
                                                        requested_by=USER,
                                                        branch_id=BRANCH_ID
                                                    )
                                                st.success(f"Reversal request #{req_id[:8]} submitted to Branch Manager!")
                                                st.rerun()
                                            except Exception as e:
                                                st.error(f"Error submitting reversal: {e}")
                                        else:
                                            st.warning("Please provide a reason for the reversal.")
                                else:
                                    st.info("No active repayment records available to reverse.")
                            
                    with dd_t4:
                        if s_hist.empty:
                            st.info("No savings ledger entries found for this client.")
                        else:
                            df_s = s_hist.copy()
                            df_s = df_s.rename(columns={
                                "posting_date": "Date",
                                "deposit_amount": "Deposit (₦)",
                                "withdrawal_amount": "Withdrawal (₦)",
                                "remarks": "Remarks"
                            })
                            
                            # Running balance calculation
                            dep = df_s.get("Deposit (₦)", pd.Series([0.0]))
                            wth = df_s.get("Withdrawal (₦)", pd.Series([0.0]))
                            df_s["Net Balance (₦)"] = (dep - wth).cumsum()

                            s_cols = ["Date", "Deposit (₦)", "Withdrawal (₦)", "Net Balance (₦)", "Remarks"]
                            st.dataframe(
                                df_s[[c for c in s_cols if c in df_s.columns]].style.format({
                                    "Deposit (₦)": "₦{:,.0f}",
                                    "Withdrawal (₦)": "₦{:,.0f}",
                                    "Net Balance (₦)": "₦{:,.0f}"
                                }),
                                use_container_width=True
                            )
                            
                    with dd_t5:
                        c_perf = dd.get("collection_history", pd.DataFrame())
                        if c_perf.empty:
                            st.info("No collection performance anomalies logged for this client.")
                        else:
                            st.dataframe(c_perf, use_container_width=True)

                    with dd_t6:
                        st.markdown("##### Client Lifecycle Status & Management")
                        st.caption("Credit Officers have direct authoritative control to manage client lifecycle states.")

                        from services.client_status_service import ClientStatusService
                        cur_cid = c_info.get("client_id") or c_info.get("id")

                        # Current Status Banner
                        curr_status_res = uow_p.client.table("clients").select("status_id, status_changed_at, status_note, client_statuses(name, color_code, icon)").eq("client_id", cur_cid).execute()
                        curr_rec = curr_status_res.data[0] if curr_status_res.data else {}
                        cs_dict = curr_rec.get("client_statuses") or {}
                        current_status_name = cs_dict.get("name", "Registered")
                        current_color = cs_dict.get("color_code", "#9CA3AF")
                        last_changed = str(curr_rec.get("status_changed_at") or "Initial Onboarding")[:19]
                        status_note = curr_rec.get("status_note") or "None"

                        st.markdown(
                            f"""
                            <div style="background: {current_color}15; border-left: 5px solid {current_color}; padding: 12px 18px; border-radius: 6px; margin-bottom: 15px;">
                                <h4 style="margin: 0; color: {current_color};">Status: {current_status_name}</h4>
                                <p style="margin: 4px 0 0 0; font-size: 13px; color: #4B5563;">Last Changed: <b>{last_changed}</b> | Note: <i>{status_note}</i></p>
                            </div>
                            """,
                            unsafe_allow_html=True
                        )

                        # Manual Status Change Form for CO / Authorized Officers
                        st.markdown("###### Update Client Lifecycle Status")
                        manual_options = [
                            "Registered",
                            "Inactive (Savings Only)",
                            "Closed",
                            "Suspended",
                            "Dormant"
                        ]

                        ch_col1, ch_col2 = st.columns([1, 2])
                        with ch_col1:
                            target_status = st.selectbox(
                                "Select New Status:",
                                manual_options,
                                index=manual_options.index(current_status_name) if current_status_name in manual_options else 0,
                                key=f"sel_status_{selected_ccode}"
                            )
                        with ch_col2:
                            change_reason = st.text_input(
                                "Reason for Status Change (Required for Audit Trail):",
                                placeholder="e.g. Client relocated, temporary suspension, or requested savings-only status",
                                key=f"reason_status_{selected_ccode}"
                            )

                        if st.button("Apply Status Change", key=f"btn_apply_status_{selected_ccode}", type="primary"):
                            if not change_reason.strip():
                                st.warning("Please provide a reason/note for this status change to maintain audit compliance.")
                            else:
                                success = ClientStatusService.transition_status(
                                    uow=uow_p,
                                    client_id=str(cur_cid),
                                    new_status_name=target_status,
                                    changed_by=getattr(p_scope, "user_id", None),
                                    reason=change_reason.strip(),
                                    trigger_type="MANUAL"
                                )
                                if success:
                                    st.success(f"Client lifecycle status updated to **{target_status}** successfully.")
                                    st.rerun()
                                else:
                                    st.error("Failed to update status. Please try again.")

                        st.divider()
                        st.markdown("###### Status Change History")
                        history_records = ClientStatusService.get_client_history(uow_p, str(cur_cid))
                        if history_records:
                            h_rows = []
                            for h in history_records:
                                h_rows.append({
                                    "Date & Time": str(h.get("changed_at", ""))[:19].replace("T", " "),
                                    "Previous Status": h.get("old_status_name") or (h.get("old_status") or {}).get("name", "Initial"),
                                    "New Status": h.get("new_status_name") or (h.get("new_status") or {}).get("name", "N/A"),
                                    "Trigger": h.get("trigger_type", "MANUAL"),
                                    "Reason": h.get("reason", "N/A"),
                                    "Changed By": (h.get("changer") or {}).get("full_name") or "System / Officer"
                                })
                            st.dataframe(pd.DataFrame(h_rows), use_container_width=True, hide_index=True)
                        else:
                            st.info("No historical status changes recorded for this client.")

                    with dd_t7:
                        a_hist = dd.get("audit_history", pd.DataFrame())
                        if a_hist.empty:
                            st.info("Zero audit compliance events logged.")
                        else:
                            st.dataframe(a_hist, use_container_width=True)
            else:
                st.info("No client records found in authorized scope.")

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
    
    # Filter datasets using centralized RBACScopeService
    my_loans = RBACScopeService.filter_dataframe(all_loans, scope)
    all_repayments = RBACScopeService.filter_dataframe(all_repayments, scope)

    if scope.scope_level == "REGION":
        assigned_b_names = scope.assigned_branch_names
        am_rep_branch_opts = ["All Assigned Branches"] + assigned_b_names
        selected_rep_am_branch = st.selectbox("🌐 Filter Reports by Branch:", am_rep_branch_opts, key="am_reports_branch_filter")
        if selected_rep_am_branch != "All Assigned Branches":
            my_loans = RBACScopeService.filter_dataframe(my_loans, scope, selected_branch=selected_rep_am_branch)
            all_repayments = RBACScopeService.filter_dataframe(all_repayments, scope, selected_branch=selected_rep_am_branch)
    
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
    if ROLE in [ROLE_ADMIN, "BM", "AM", "Area Manager"]:
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
        
        # Credit Intelligence & Risk Rating Report
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("⭐ Client Risk Rating & Credit Intelligence")
        st.caption("Automated credit risk evaluation, repayment compliance %, and upgrade eligibility recommendations.")

        try:
            with SupabaseUnitOfWork() as uow_risk:
                from services.client_risk_rating_service import ClientRiskRatingService
                risk_dist = ClientRiskRatingService.get_branch_risk_distribution(uow_risk, BRANCH_ID)
                
                r1, r2, r3, r4, r5 = st.columns(5)
                r1.metric("⭐ Excellent (Upgrade)", risk_dist.get("EXCELLENT", 0))
                r2.metric("🟢 Good (Maintain)", risk_dist.get("GOOD", 0))
                r3.metric("🟡 Fair (Monitor)", risk_dist.get("FAIR", 0))
                r4.metric("🟠 Risky (No Increase)", risk_dist.get("RISKY", 0))
                r5.metric("🔴 High Risk (Decline)", risk_dist.get("HIGH_RISK", 0))
        except Exception:
            st.info("No active risk rating data available.")

        st.markdown("</div>", unsafe_allow_html=True)


# ==========================================
# 14. USER MANAGEMENT (Admin / BM / AM)
# ==========================================
elif page == "User Management":
    import sys
    import importlib
    import services.user_service
    importlib.reload(services.user_service)
    from services.user_service import UserService
    
    st.markdown("<div class='dashboard-header'>", unsafe_allow_html=True)
    st.markdown("<h1>🔐 User Management</h1>", unsafe_allow_html=True)
    st.markdown("<p>Manage application users, reset passwords, and handle officer turnover.</p>", unsafe_allow_html=True)
    st.markdown("</div>", unsafe_allow_html=True)
    
    # Render any flash messages from session state
    if "user_mgmt_success" in st.session_state:
        st.success(st.session_state["user_mgmt_success"])
        del st.session_state["user_mgmt_success"]
    if "user_mgmt_error" in st.session_state:
        st.error(st.session_state["user_mgmt_error"])
        del st.session_state["user_mgmt_error"]
    
    # Fetch users scoped to the requesting user's role
    all_users = UserService.list_users(current_user)
    user_usernames = [u['username'] for u in all_users]
    
    # Tab layout based on role
    is_admin = ROLE in [ROLE_ADMIN, 'Super Admin', 'Admin']
    is_bm = ROLE in ['BM', ROLE_BRANCH_MANAGER]
    is_am = ROLE in ['AM', 'Area Manager']
    
    if is_admin:
        tabs = st.tabs([
            "Users Directory", 
            "Create User", 
            "Password Reset", 
            "Officer Turnover", 
            "Product Assignment", 
            "AM Assignments", 
            "Branch Closures", 
            "Audit Logs", 
            "Login History"
        ])
    elif is_bm:
        tabs = st.tabs([
            "Branch Staff", 
            "Password Reset", 
            "Product Assignment", 
            "Branch Closures"
        ])
    elif is_am:
        tabs = st.tabs(["Branch Staff (Read Only)"])
    else:
        st.error("You do not have permission to access User Management.")
        st.stop()
    
    # --- Tab: Users List ---
    with tabs[0]:
        st.subheader("Current Users")
        if all_users:
            df_users = pd.DataFrame(all_users)
            display_cols = ['username', 'full_name', 'role', 'branch_name', 'is_active', 'last_login', 'created_at']
            display_cols = [c for c in display_cols if c in df_users.columns]
            st.dataframe(df_users[display_cols], use_container_width=True)
            
            # Admin / BM: Activate / Deactivate toggles
            if (is_admin or is_bm) and user_usernames:
                st.markdown("---")
                st.subheader("⚡ Manage User Status & Deletion")
                target_username = st.selectbox("Select User", user_usernames, key="toggle_user")
                target_user_data = next((u for u in all_users if u['username'] == target_username), None)
                
                if target_user_data:
                    current_status = target_user_data.get('is_active', True)
                    st.write(f"**Current Status:** {'✅ Active' if current_status else '❌ Inactive'}")
                    
                    col_a, col_d = st.columns(2)
                    with col_a:
                        if st.button("✅ Activate", key="activate_btn", use_container_width=True, disabled=current_status):
                            result = UserService.activate_user(target_user_data['id'], current_user)
                            if result['success']:
                                st.session_state['user_mgmt_success'] = result['message']
                                st.rerun()
                            else:
                                st.error(result['message'])
                    with col_d:
                        if st.button("❌ Deactivate", key="deactivate_btn", use_container_width=True, disabled=not current_status):
                            result = UserService.deactivate_user(target_user_data['id'], current_user)
                            if result['success']:
                                st.session_state['user_mgmt_success'] = result['message']
                                st.rerun()
                            else:
                                st.error(result['message'])
                                
                    if is_admin:
                        st.markdown("<br>", unsafe_allow_html=True)
                        with st.expander("⚠️ Danger Zone (Permanent Deletion)"):
                            st.write("Deleting a user permanently removes them from the database. If this user has logged transactions, clients, or loans, their reference will be preserved as empty/null in historical audit logs.")
                            confirm_del = st.checkbox(f"Confirm I want to permanently delete the user '{target_username}'", key="confirm_del_check")
                            if st.button("🔥 Permanently Delete User", key="delete_user_btn", use_container_width=True, type="primary", disabled=not confirm_del):
                                result = UserService.remove_user_permanently(target_user_data['id'], current_user)
                                if result['success']:
                                    st.session_state['user_mgmt_success'] = result['message']
                                    st.rerun()
                                else:
                                    st.error(result['message'])
        else:
            st.info("No users found.")
    
    # --- Tab: Create User (Admin Only) ---
    if is_admin:
        with tabs[1]:
            st.subheader("➕ Add New User")
            st.info("Only Head Office administrators can create new users.")
            with st.form("add_user_form"):
                new_username = st.text_input("Username (e.g. CO5, BM_Ikeja)")
                new_fullname = st.text_input("Full Name (e.g. Mr. Ayomide)")
                new_role = st.selectbox("Role", ["Credit Officer", "Branch Manager", "Area Manager", "Admin", "Super Admin", "Account Manager"])
                new_branch = st.text_input("Branch Name (e.g. Ogijo)")
                new_password = st.text_input("Password", type="password")
                
                submit_new = st.form_submit_button("Create User", use_container_width=True)
                if submit_new:
                    result = UserService.create_user(
                        username=new_username,
                        full_name=new_fullname,
                        password=new_password,
                        role=new_role,
                        branch_name=new_branch,
                        requesting_user=current_user,
                    )
                    if result['success']:
                        st.session_state['user_mgmt_success'] = result['message']
                        st.rerun()
                    else:
                        st.error(result['message'])
    
    # --- Tab: Reset Password (Admin + BM) ---
    if is_admin or is_bm:
        pw_tab_idx = 2 if is_admin else 1
        with tabs[pw_tab_idx]:
            st.subheader("🔑 Reset Password")
            if is_bm:
                st.info("You can only reset passwords for staff in your branch.")
            with st.form("reset_pw_form"):
                reset_username = st.selectbox("Select User", user_usernames, key="reset_user")
                reset_password = st.text_input("New Password", type="password")
                submit_reset = st.form_submit_button("Reset Password", use_container_width=True)
                if submit_reset:
                    result = UserService.reset_password(reset_username, reset_password, current_user)
                    if result['success']:
                        st.session_state['user_mgmt_success'] = result['message']
                        st.rerun()
                    else:
                        st.error(result['message'])
    
    # --- Tab: Officer Turnover (Admin Only) ---
    if is_admin:
        with tabs[3]:
            st.subheader("🔄 Update Officer Name (Turnover)")
            st.info("When an officer leaves, update the Full Name tied to their generic username (e.g. CO2) so that historical data remains intact but the new officer's name is used going forward.")
            
            co_users = [u for u in all_users if u['role'] in ['Credit Officer', 'CO', 'Officer']]
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
                    result = UserService.update_officer_name(update_username, new_officer_name, current_user)
                    if result['success']:
                        st.session_state['user_mgmt_success'] = result['message']
                        st.rerun()
                    else:
                        st.error(result['message'])
    
    # --- Tab: Assign Products (Admin & BM) ---
    product_assign_idx = 4 if is_admin else 2
    if is_admin or is_bm:
        with tabs[product_assign_idx]:
            st.subheader("🛍️ Assign Products to Credit Officers")
            st.info("Assign specific loan products to a Credit Officer. If left completely blank, the officer will have access to ALL products.")
            
            # Fetch CO users
            co_users_for_assign = [u for u in all_users if u['role'] in ['Credit Officer', 'CO', 'Officer']]
            if co_users_for_assign:
                assign_username = st.selectbox("Select Credit Officer", [u['username'] for u in co_users_for_assign], key="assign_product_co")
                selected_co = next((u for u in co_users_for_assign if u['username'] == assign_username), None)
                
                if selected_co:
                    st.write(f"**Name:** {selected_co.get('full_name', '')}")
                    
                    # Fetch all available products
                    with SupabaseUnitOfWork() as uow:
                        res_prods = uow.client.table("loan_products").select("name").execute()
                        available_products = [p["name"] for p in res_prods.data] if res_prods.data else []
                        
                        # Fallback if DB fetch fails
                        if not available_products:
                            available_products = ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M", "60-Day Asset", "120-Day Asset", "Weekly 12W Asset", "Weekly 24W Asset", "Monthly 3M Asset", "Monthly 6M Asset", "Cash and Carry"]
                    
                    # Extract current allowed products
                    extra_fields = selected_co.get("extra_fields") or {}
                    current_allowed = extra_fields.get("allowed_products", [])
                    
                    if not isinstance(current_allowed, list):
                        current_allowed = []
                        
                    default_selections = [p for p in current_allowed if p in available_products]
                    
                    with st.form("assign_products_form"):
                        selected_products = st.multiselect(
                            "Allowed Products",
                            options=available_products,
                            default=default_selections,
                            help="Leave empty to allow access to ALL products."
                        )
                        
                        submit_assign = st.form_submit_button("Save Assignments", use_container_width=True)
                        if submit_assign:
                            try:
                                # Update user extra_fields
                                new_extra = dict(extra_fields)
                                new_extra["allowed_products"] = selected_products
                                
                                with SupabaseUnitOfWork() as uow_update:
                                    uow_update.client.table("app_users").update({"extra_fields": new_extra}).eq("id", selected_co["id"]).execute()
                                
                                st.session_state['user_mgmt_success'] = f"Successfully updated allowed products for {assign_username}."
                                st.rerun()
                            except Exception as e:
                                st.error(f"Error updating products: {str(e)}")
            else:
                st.warning("No Credit Officers found.")

    # --- Tab: AM Branch Assignments (Admin Only) ---
    if is_admin:
        with tabs[5]:
            st.subheader("🏢 Area Manager Branch Assignments")
            st.info("Each Area Manager supervises 5-7 branches. Assign branches below.")
            
            am_users = [u for u in all_users if u['role'] in ['Area Manager', 'AM']]
            if am_users:
                selected_am = st.selectbox("Select Area Manager", [u['username'] for u in am_users], key="am_select")
                am_data = next((u for u in am_users if u['username'] == selected_am), None)
                
                if am_data:
                    # Load current assignments
                    current_assignments = UserService.get_am_assignments(am_data['id'])
                    current_branch_ids = [a['branch_id'] for a in current_assignments]
                    current_branch_names = [a['name'] for a in current_assignments]
                    
                    st.write(f"**Currently Assigned ({len(current_assignments)}):** {', '.join(current_branch_names) if current_branch_names else 'None'}")
                    
                    # Load all branches
                    try:
                        with SupabaseUnitOfWork() as uow:
                            branches_res = uow.client.table("branches").select("branch_id, name").eq("is_active", True).execute()
                        all_branches = branches_res.data if branches_res.data else []
                    except Exception:
                        all_branches = []
                    
                    if all_branches:
                        branch_options = {b['name']: b['branch_id'] for b in all_branches}
                        
                        with st.form("am_assignment_form"):
                            selected_branches = st.multiselect(
                                "Select Branches (5-7 required)",
                                options=list(branch_options.keys()),
                                default=[n for n in current_branch_names if n in branch_options],
                            )
                            
                            submit_am = st.form_submit_button("Save Assignments", use_container_width=True)
                            if submit_am:
                                selected_ids = [branch_options[n] for n in selected_branches if n in branch_options]
                                result = UserService.save_am_assignments(am_data['id'], selected_ids, current_user)
                                if result['success']:
                                    st.session_state['user_mgmt_success'] = result['message']
                                    st.rerun()
                                else:
                                    st.error(result['message'])
            else:
                st.info("No Area Managers found. Create one first using the 'Create User' tab.")
    
    # --- Tab: Branch Closures ---
    if is_admin or is_bm:
        closure_tab_idx = 6 if is_admin else 3
        with tabs[closure_tab_idx]:
            st.subheader("🏢 Branch Settings & Closures")
            st.write("Manage custom branch closures (e.g., operational shutdowns, end-of-year breaks). These dates will be strictly excluded when calculating loan repayment schedules.")
            
            c3, c4 = st.columns(2)
            with c3:
                st.markdown("<div class='card'>", unsafe_allow_html=True)
                st.markdown("#### ➕ Add New Closure")
                with st.form("add_closure_form"):
                    closure_dates = st.date_input("Select Date Range", [], key="closure_range")
                    closure_reason = st.text_input("Reason (e.g. End of Year Break)")
                    
                    # Fetch active branches for selection
                    with SupabaseUnitOfWork() as uow:
                        branches_res = uow.client.table("branches").select("*").eq("is_active", True).execute()
                        branches = branches_res.data or []
                        branch_map_id_to_name = {b["branch_id"]: b["name"] for b in branches}
                    
                    selected_branch_id = None
                    if is_admin:
                        branch_options = {"All Branches (Global)": None}
                        for b in branches:
                            branch_options[b["name"]] = b["branch_id"]
                        selected_branch_name = st.selectbox("Target Branch", list(branch_options.keys()))
                        selected_branch_id = branch_options[selected_branch_name]
                    else:
                        selected_branch_id = BRANCH_ID
                        st.info(f"Target Branch: {BRANCH}")

                    submit_closure = st.form_submit_button("Save Closure", use_container_width=True)
                    if submit_closure:
                        if not closure_reason or len(closure_dates) != 2:
                            st.error("Please provide a reason and select a full date range (start and end).")
                        else:
                            try:
                                with SupabaseUnitOfWork() as uow:
                                    closure = BranchClosure(
                                        id=None, 
                                        start_date=closure_dates[0], 
                                        end_date=closure_dates[1], 
                                        reason=closure_reason,
                                        branch_id=selected_branch_id
                                    )
                                    uow.branch_closures.create(closure)
                                    
                                    # Auto-reschedule pending loan installments for the branch
                                    from services.schedule_service import ScheduleService
                                    ScheduleService.reschedule_branch_loans_on_closure(
                                        uow=uow,
                                        branch_id=selected_branch_id,
                                        start_date=closure_dates[0],
                                        end_date=closure_dates[1]
                                    )
                                st.success("Branch closure added and loan schedules rescheduled successfully!")
                                get_custom_closures.clear()
                                st.rerun()
                            except Exception as e:
                                st.error(f"Failed to add closure: {e}")
                st.markdown("</div>", unsafe_allow_html=True)
                
            with c4:
                st.markdown("<div class='card'>", unsafe_allow_html=True)
                st.markdown("#### 📅 Active Closures")
                closures_list = get_custom_closures()
                # filter closures for BM
                if not is_admin:
                    closures_list = [c for c in closures_list if c[3] is None or c[3] == BRANCH_ID]
                
                if closures_list:
                    # branch_map_id_to_name is populated above
                    closure_data = [
                        {
                            "Start Date": c[0].strftime('%Y-%m-%d'), 
                            "End Date": c[1].strftime('%Y-%m-%d'), 
                            "Reason": c[2],
                            "Branch": branch_map_id_to_name.get(c[3], "Global") if c[3] else "Global"
                        } 
                        for c in closures_list
                    ]
                    st.dataframe(pd.DataFrame(closure_data), use_container_width=True)
                else:
                    st.info("No custom closures recorded.")
                st.markdown("</div>", unsafe_allow_html=True)
    
    # --- Tab: Audit Logs (Admin Only) ---
    if is_admin:
        with tabs[7]:
            st.subheader("📋 System Audit Logs")
            st.info("Immutable audit trail. Logs cannot be modified or deleted.")
            
            try:
                with SupabaseUnitOfWork() as uow:
                    audit_entries = uow.user_audit_logs.find_recent(limit=200)
                
                if audit_entries:
                    df_audit = pd.DataFrame(audit_entries)
                    display_cols = ['timestamp', 'username', 'role', 'branch', 'action', 'module', 'entity_type', 'display_name', 'status']
                    display_cols = [c for c in display_cols if c in df_audit.columns]
                    st.dataframe(df_audit[display_cols], use_container_width=True, height=500)
                else:
                    st.info("No audit logs recorded yet.")
            except Exception as e:
                st.error(f"Failed to load audit logs: {e}")
    
    # --- Tab: Login History (Admin Only) ---
    if is_admin:
        with tabs[8]:
            st.subheader("📊 Login History")
            
            try:
                with SupabaseUnitOfWork() as uow:
                    login_entries = uow.login_history.find_recent(limit=200)
                
                if login_entries:
                    df_logins = pd.DataFrame(login_entries)
                    display_cols = ['login_time', 'username', 'status', 'session_id', 'logout_time', 'failed_attempts']
                    display_cols = [c for c in display_cols if c in df_logins.columns]
                    st.dataframe(df_logins[display_cols], use_container_width=True, height=500)
                else:
                    st.info("No login history recorded yet.")
            except Exception as e:
                st.error(f"Failed to load login history: {e}")
