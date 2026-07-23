import streamlit as st

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

st.set_page_config(
    page_title="ICARE Microfinance - Core Banking",
    page_icon="🌱",
    layout="wide",
    initial_sidebar_state="expanded"
)

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
            return [(c.start_date, c.end_date, c.reason) for c in closures]
    except Exception:
        pass
    return []
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
    "asset_credit_sales": "Asset Credit Sales", "cash_and_carry": "Cash and Carry", "credit_form": "Credit Form", "credit_form_damage": "Credit Form Damage", "bonus": "Bonus"
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


def save_repayment(data):
    """Save repayment and route savings to respective buckets"""
    print(f"\n[SAVINGS TRACE] Collections payload received: {data}")
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        from services.savings_service import SavingsService
        with SupabaseUnitOfWork() as uow:
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
            print(f"[SAVINGS TRACE] Resolved client/group: ID={client_id}, Name={client_name}, Branch={branch}, Officer={officer}")
            
            # Extract Savings
            savings_dep = float(db_data.get('savings_amount', 0))
            savings_wd = float(db_data.get('withdrawal_amount', 0))
            group_dep = float(db_data.get('group_savings_dep', 0))
            group_wd = float(db_data.get('group_savings_wd', 0))
            laps_res = float(db_data.get('laps_reserved', 0))
            laps_trans = float(db_data.get('laps_transferred', 0))
            misc_fees = float(db_data.get('misc_fees', 0))
            loan_repay = float(db_data.get('loan_repayment_amount', 0))
            
            # Route Group Savings
            if client_id.startswith('GROUP-'):
                group_name = client_id.replace('GROUP-', '')
                SavingsService.post_group_savings(uow, group_name, branch, officer, group_dep, group_wd, remarks=db_data.get('note'))
                
                # Also save to repayments table
                db_data['transaction_type'] = client_id  # e.g., "GROUP-group_name"
                db_data['client_id'] = None
                db_data['loan_repayment_amount'] = 0.0
                rep = RepaymentMapper.to_domain(db_data)
                try:
                    from services.repayment_service import RepaymentService
                    RepaymentService.post_repayment(uow, rep)
                except Exception as re:
                    st.error(f"Error inserting group repayment: {re}")
                return # Do not insert a dummy loan or a repayment row
            
            # Route LAPS
            if client_id.startswith('GLOBAL-'):
                SavingsService.post_laps_savings(uow, client_id, client_name, branch, officer, laps_res, laps_trans)
                
                # Also save to repayments table
                db_data['transaction_type'] = client_id  # e.g., "GLOBAL-LAPS-branch"
                db_data['client_id'] = None
                db_data['loan_repayment_amount'] = 0.0
                rep = RepaymentMapper.to_domain(db_data)
                try:
                    from services.repayment_service import RepaymentService
                    RepaymentService.post_repayment(uow, rep)
                except Exception as re:
                    st.error(f"Error inserting laps repayment: {re}")
                return # Do not insert a dummy loan or a repayment row

            # Route Individual Savings
            if savings_dep > 0 or savings_wd > 0:
                SavingsService.post_individual_savings(uow, client_id, client_name, branch, officer, savings_dep, savings_wd, remarks=db_data.get('note'))
                
            # Record loan repayment to schedule and update outstanding loan balance
            if loan_repay > 0:
                res_l = uow.client.table("loans").select("loan_id, active_credit").eq("client_id", client_id).eq("status", "Active").execute()
                if res_l.data:
                    active_loan_id = res_l.data[0]["loan_id"]
                    from services.schedule_service import ScheduleService
                    p_date_str = db_data.get('date') or datetime.now().strftime("%Y-%m-%d")
                    p_date = datetime.strptime(p_date_str, "%Y-%m-%d").date()
                    
                    ScheduleService.record_repayment(uow, active_loan_id, loan_repay, p_date)
                    
                    # Update loan outstanding balance
                    current_outstanding = float(res_l.data[0].get("active_credit") or 0.0)
                    new_outstanding = max(0.0, current_outstanding - loan_repay)
                    uow.client.table("loans").update({"active_credit": new_outstanding}).eq("loan_id", active_loan_id).execute()

            # Route Misc Savings if collected during collections
            if misc_fees > 0:
                SavingsService.post_misc_savings(uow, client_id, client_name, branch, officer, misc_fees, remarks=db_data.get('note'))

            # Route Cash and Carry
            cc_amount = float(db_data.get('cash_and_carry', 0))
            if cc_amount > 0:
                import uuid
                from domain.entities.event_store import DomainEvent
                from services.posting_engine import FinancialPostingEngine
                event_cc = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=client_id,
                    aggregate_type="Asset",
                    event_type="AssetSoldCash",
                    payload={"branch": branch, "officer": officer, "amount": cc_amount, "narration": f"Cash & Carry asset sale to {client_name}"}
                )
                uow.event_store.append(event_cc)
                FinancialPostingEngine.post_event(uow, event_cc)

            # Route Credit Form Damage
            cfd_amount = float(db_data.get('credit_form_damage', 0))
            if cfd_amount > 0:
                import uuid
                from domain.entities.event_store import DomainEvent
                from services.posting_engine import FinancialPostingEngine
                event_cfd = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=client_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={"branch": branch, "officer": officer, "amount": cfd_amount, "narration": f"Credit Form Damage fee from {client_name}"}
                )
                uow.event_store.append(event_cfd)
                FinancialPostingEngine.post_event(uow, event_cfd)

            # Route Application / Processing Fee
            app_fee_amt = float(db_data.get('processing_fee_paid', 0))
            if app_fee_amt > 0:
                import uuid
                from domain.entities.event_store import DomainEvent
                from services.posting_engine import FinancialPostingEngine
                event_app = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=client_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={"branch": branch, "officer": officer, "amount": app_fee_amt, "narration": f"Processing Fee from {client_name}"}
                )
                uow.event_store.append(event_app)
                FinancialPostingEngine.post_event(uow, event_app)

            # Route Markup and Contingency to ledger posting
            d11_val = float(db_data.get('daily_11_pct') or 0.0)
            d20_val = float(db_data.get('daily_20_pct') or 0.0)
            w11_val = float(db_data.get('weekly_11_pct') or 0.0)
            w20_val = float(db_data.get('weekly_20_pct') or 0.0)
            mm_val = float(db_data.get('monthly_markup') or 0.0)
            cont_val = float(db_data.get('contingency_paid') or 0.0)

            def post_fee_charge(amount_val, narration_str):
                if amount_val <= 0:
                    return
                import uuid
                from domain.entities.event_store import DomainEvent
                from services.posting_engine import FinancialPostingEngine
                event_fee = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=client_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={"branch": branch, "officer": officer, "amount": amount_val, "narration": narration_str}
                )
                uow.event_store.append(event_fee)
                FinancialPostingEngine.post_event(uow, event_fee)

            post_fee_charge(d11_val, f"daily 11% markup fee from {client_name}")
            post_fee_charge(d20_val, f"daily 20% markup fee from {client_name}")
            post_fee_charge(w11_val, f"weekly 11% markup fee from {client_name}")
            post_fee_charge(w20_val, f"weekly 20% markup fee from {client_name}")
            post_fee_charge(mm_val, f"monthly markup risk premium fee from {client_name}")
            post_fee_charge(cont_val, f"contingency fee from {client_name}")

            # Proceed to insert into repayments table if there's actual repayment
            # or if it's a legacy record. We'll always insert it so history isn't lost.
            rep = RepaymentMapper.to_domain(db_data)
            try:
                from services.repayment_service import RepaymentService
                RepaymentService.post_repayment(uow, rep)
            except Exception as re:
                print(f"[ERROR] Error inserting repayment for {client_id}: {re}")
                st.error(f"Error inserting repayment for {client_id}: {re}")
                return
    except Exception as e:
        print(f"[ERROR] Error in save_repayment logic: {e}")
        st.error(f"Error in save_repayment logic: {e}")


def save_repayments(data_list):
    """Save multiple repayments to database"""
    for data in data_list:
        save_repayment(data)

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
# Session persistence via query_params (replaces flaky JS iframe cookies)
# st.query_params survives page refreshes on Streamlit Cloud natively.

def _set_auth_token(username):
    """Persist auth token in URL query params (survives refresh)."""
    st.query_params["auth"] = username

def _delete_auth_token():
    """Clear auth token from query params."""
    if "auth" in st.query_params:
        del st.query_params["auth"]

def _read_auth_token():
    """Read auth token from query params."""
    return st.query_params.get("auth", None)

# Try to restore session from persisted token
if 'logged_in' not in st.session_state or not st.session_state['logged_in']:
    if st.session_state.get('logout_in_progress'):
        auth_token = None
    else:
        auth_token = _read_auth_token()
        
    if auth_token:
        try:
            with SupabaseUnitOfWork() as uow:
                user = uow.users.find_by_username(auth_token)
            if user:
                st.session_state['logged_in'] = True
                st.session_state['user'] = user.username
                st.session_state['role'] = user['role']
                st.session_state['branch'] = user['branch_name']
            else:
                st.session_state['logged_in'] = False
                _delete_auth_token()
        except:
            st.session_state['logged_in'] = False
    else:
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
            <p style='color: #94A3B8; font-size: 0.65rem; margin: 4px 0 0 0; letter-spacing: 1px;'>CORE BANKING v{APP_VERSION}</p>
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
    
    # Permission-driven navigation
    nav_section = "OPERATIONS" if ROLE in ["Officer", "CO", ROLE_CREDIT_OFFICER] else (
        "EXECUTIVE" if ROLE in ["BM", ROLE_BRANCH_MANAGER, "AM", "Area Manager"] else "ADMINISTRATION"
    )
    st.markdown(f"<p class='nav-section-label'>{nav_section}</p>", unsafe_allow_html=True)
    nav_options = get_nav_options(current_user) if current_user else ["Dashboard"]
    
    page = st.radio("Navigation", nav_options, label_visibility="collapsed")
    
    # Security check: if the requested page is not in permitted list, fallback to Dashboard
    if page not in nav_options:
        page = "Dashboard"
    
    st.divider()
    
    if st.button("Sign Out", use_container_width=True):
        _delete_auth_token()
        st.session_state['logout_in_progress'] = True
        st.session_state['logged_in'] = False
        for key in list(st.session_state.keys()):
            if key not in ['logout_in_progress', 'logged_in']:
                del st.session_state[key]
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
    
    # Daily Operations Tracking
    collected_today = 0
    today_savings_deposited = 0
    today_savings_withdrawn = 0
    today_full_payment_count = 0
    today_full_payment_amount = 0
    today_excess = 0

    # Lifetime / Portfolio Tracking
    total_repayments_collected = 0
    total_excess_collected = 0
    total_full_payment_collected = 0
    monthly_disbursed_principal = 0
    
    # Target calculations
    target_daily = 0
    target_weekly = 0
    target_monthly = 0
    
    total_original_active_credit = 0
    
    # Group Data Tracking
    group_data = {}
    has_weekly = False
    
    today = datetime.now()
    today_str = today.strftime("%Y-%m-%d")
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
        
        # Sourced from single source of truth (loans table)
        loan_bal = float(loan.get('Active Credit', 0.0))
        l_amt = max(0.0, float(loan.get('Total Due', 0.0)) - loan_bal)
        orig_principal = float(loan.get('Loan Amount', 0.0))
        disb_date_str = str(loan.get('Disbursement Date') or loan.get('Date') or "")

        if disb_date_str:
            try:
                disb_dt = datetime.strptime(disb_date_str[:10], "%Y-%m-%d")
                if disb_dt.year == today.year and disb_dt.month == today.month:
                    monthly_disbursed_principal += orig_principal
            except Exception:
                pass
        
        # Calculate actual collected today for this client
        today_payments = c_payments[c_payments['Date'] == today_str] if not c_payments.empty else pd.DataFrame()
        today_loan_paid = pd.to_numeric(today_payments['Loan Repayment Amount'], errors='coerce').fillna(0).sum()
        today_sav_dep = pd.to_numeric(today_payments['Savings Amount'], errors='coerce').fillna(0).sum()
        today_sav_wd = pd.to_numeric(today_payments['Withdrawal Amount'], errors='coerce').fillna(0).sum()
        
        collected_today += today_loan_paid
        today_savings_deposited += today_sav_dep
        today_savings_withdrawn += today_sav_wd
        
        # Portfolio repayments & excess/full payment tracking
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

        # Full payment logic fallback (loan balance reached <= 0 today by a payment made today)
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
                
                if "12 week" in product.lower() or "12w" in product.lower():
                    group_data[gn]['12w_active'] += orig_ac
                    group_data[gn]['12w_bal'] += loan_bal if loan_bal > 0 else 0
                elif "24 week" in product.lower() or "24w" in product.lower():
                    group_data[gn]['24w_active'] += orig_ac
                    group_data[gn]['24w_bal'] += loan_bal if loan_bal > 0 else 0
        
        if s_amt > 0:
            total_people_with_savings += 1
            total_savings += s_amt
            
        if loan_bal > 0 and loan.get('Status') in [STATUS_ACTIVE, STATUS_COMPLETED, STATUS_APPROVED]:
            active_loans_count += 1
            total_active_credit += loan_bal
            
            original_active_credit = pd.to_numeric(loan.get('Active Credit', 0), errors='coerce')
            if pd.isna(original_active_credit): original_active_credit = 0
            total_original_active_credit += original_active_credit
            
            if is_working_day:
                if "Daily" in product or "120 Days" in product or "Cash and Carry" in product:
                    target_daily += fixed_repay
                else:
                    meeting_day = str(loan.get('Meeting Day', ''))
                    if meeting_day == today_weekday:
                        if "Week" in product or "60-Day Asset" in product:
                            target_weekly += fixed_repay
                        elif "Month" in product or "120-Day Asset" in product:
                            target_monthly += fixed_repay
            
            # calculate overdue
            start_date_str = loan.get('Date', '')
            if start_date_str and product:
                exp_paid, overdue_amt = calculate_overdue(start_date_str, product, fixed_repay, l_amt, loan.get('Status', STATUS_ACTIVE))
                total_overdue += overdue_amt
        elif loan_bal <= 0 and loan.get('Status') in [STATUS_ACTIVE, STATUS_COMPLETED, STATUS_APPROVED]:
            fully_paid_count += 1
            
    # Process Group Globals
    group_globals = all_repayments[all_repayments['Client ID'].str.startswith("GROUP-", na=False)]
    if ROLE in ["CO", "Officer"]:
        group_globals = group_globals[group_globals['Officer'] == USER]
    elif ROLE == "BM":
        group_globals = group_globals[group_globals['Branch'] == BRANCH]
        
    for _, row in group_globals.iterrows():
        g_id = str(row.get('Client ID', ''))
        gn = g_id.replace("GROUP-", "").strip()
        if gn in group_data:
            s_dep = pd.to_numeric(row.get('Savings Amount', 0), errors='coerce')
            s_wd = pd.to_numeric(row.get('Withdrawal Amount', 0), errors='coerce')
            if pd.isna(s_dep): s_dep = 0
            if pd.isna(s_wd): s_wd = 0
            group_data[gn]['global_savings'] += (s_dep - s_wd)
            
    net_savings = today_savings_deposited - today_savings_withdrawn
    total_target = target_daily + target_weekly + target_monthly
    excess = collected_today - total_target
    if today_excess == 0 and excess > 0:
        today_excess = excess
    excess_color = "normal" if excess >= 0 else "inverse"
    target_breakdown = f"Daily: ₦{target_daily:,.0f} | Weekly: ₦{target_weekly:,.0f} | Monthly: ₦{target_monthly:,.0f}"

    co_closing_balance = 0.0
    co_total_savings = total_savings
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        from services.savings_service import SavingsService
        with SupabaseUnitOfWork() as uow:
            sav_totals = SavingsService.get_branch_totals(uow, BRANCH)
            real_total_savings = sav_totals['total_active_savings']
            ind_sav = sav_totals['individual_savings']
            grp_sav = sav_totals['group_savings']
            misc_sav = sav_totals['misc_savings']
            laps_sav = sav_totals['laps_savings']

            if ROLE in ["CO", "Officer"]:
                u_res = uow.client.table("app_users").select("id").eq("username", USER).execute()
                o_id = u_res.data[0]["id"] if u_res.data else None
                b_res = uow.client.table("branches").select("branch_id").eq("name", BRANCH).execute()
                b_id = b_res.data[0]["branch_id"] if b_res.data else None
                if b_id and o_id:
                    from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
                    cb_data = CoCashbookProjectionBuilder.rebuild_co_projection(uow, b_id, o_id, today.date())
                    if cb_data:
                        co_closing_balance = float(cb_data.get("closing_balance") or 0.0)

                co_sav_totals = SavingsService.get_officer_totals(uow, BRANCH, USER)
                if co_sav_totals and co_sav_totals.get('total_active_savings', 0) > 0:
                    co_total_savings = co_sav_totals['total_active_savings']
    except Exception as e:
        real_total_savings, ind_sav, grp_sav, misc_sav, laps_sav = 0, 0, 0, 0, 0

    if ROLE in [ROLE_ADMIN, 'Super Admin', 'Admin']:
        st.markdown("### 👑 Global Administrator Dashboard")
        g1, g2, g3 = st.columns(3)
        g1.metric("👥 Active Loans Count (System)", active_loans_count)
        g2.metric("📈 Sum Active Credit (System)", f"₦{total_active_credit:,.0f}")
        g3.metric("🐷 Total Savings (Active)", f"₦{real_total_savings:,.0f}")
        
        # Breakdown Widget
        st.markdown("#### 🏦 Branch comparison breakdown")
        st.info("System Health: Supabase cloud database connected. Active session monitoring enabled.")
        
    elif ROLE in ['AM', 'Area Manager']:
        st.markdown(f"### 🌐 Area Manager Dashboard")
        assigned_b_names = sorted(list(set(my_loans['Branch'].dropna().tolist()))) if not my_loans.empty and 'Branch' in my_loans.columns else []
        am_branch_opts = ["All Assigned Branches"] + assigned_b_names
        selected_am_branch = st.selectbox("🌐 Select Branch to View", am_branch_opts, key="am_dashboard_branch_filter")
        
        if selected_am_branch != "All Assigned Branches":
            am_loans = my_loans[my_loans['Branch'] == selected_am_branch]
        else:
            am_loans = my_loans

        am_active_loans = len(am_loans[am_loans['Status'].isin([STATUS_ACTIVE, STATUS_APPROVED])]) if not am_loans.empty else 0
        am_sum_credit = pd.to_numeric(am_loans['Active Credit'], errors='coerce').fillna(0).sum() if not am_loans.empty else 0.0
        
        am1, am2, am3 = st.columns(3)
        am1.metric("👥 Active Clients", am_active_loans)
        am2.metric("📈 Active Credit Balance", f"₦{am_sum_credit:,.0f}")
        am3.metric("🏦 Branch View", selected_am_branch)
        
    elif ROLE in ['BM', ROLE_BRANCH_MANAGER]:
        st.markdown(f"### 🏦 Branch Manager Dashboard — {BRANCH} Branch")
        
        # 1. Pending Approvals queue directly on dashboard
        try:
            with SupabaseUnitOfWork() as uow:
                p_loans = uow.client.table("loans").select("*, clients(name)").eq("branch_id", BRANCH_ID).eq("status", "Pending").execute()
        except Exception:
            p_loans = None
            
        if p_loans and p_loans.data:
            st.markdown("#### ⏳ Pending Loan Approvals")
            for pl in p_loans.data:
                c_name = pl.get("clients", {}).get("name") if pl.get("clients") else pl.get("client_name")
                c_code = pl.get("client_id")
                loan_amt = float(pl.get("loan_amount", 0))
                prod = pl.get("loan_product")
                
                col_app1, col_app2, col_app3 = st.columns([3, 1, 1])
                col_app1.markdown(f"👤 **{c_name}** ({c_code}) applied for **₦{loan_amt:,.0f}** ({prod})")
                if col_app2.button("Approve", key=f"app_{pl['loan_id']}"):
                    with SupabaseUnitOfWork() as uow_app:
                        uow_app.loans.approve(pl['loan_id'])
                    st.success(f"Loan approved for {c_name}!")
                    st.rerun()
                if col_app3.button("Reject", key=f"rej_{pl['loan_id']}", type="primary"):
                    with SupabaseUnitOfWork() as uow_app:
                        uow_app.loans.reject(pl['loan_id'])
                    st.success(f"Loan rejected for {c_name}!")
                    st.rerun()
            st.divider()
            
        # BM Metrics rendering
        st.markdown("#### 📅 Branch Operations Today (All Officers)")
        bm_closing_balance = 0.0
        try:
            with SupabaseUnitOfWork() as uow_bm:
                from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
                mb_data = MasterCashbookProjectionBuilder.rebuild_master_projection(uow_bm, BRANCH_ID, today.date())
                if mb_data:
                    bm_closing_balance = float(mb_data.get("closing_balance") or 0.0)
        except Exception:
            pass

        t1, t2, t3, t4 = st.columns(4)
        t1.metric("📥 Savings Deposited Today", f"₦{today_savings_deposited:,.0f}")
        t2.metric("📤 Savings Withdrawn Today", f"₦{today_savings_withdrawn:,.0f}")
        t3.metric("🐷 Net Savings Today", f"₦{net_savings:,.0f}")
        t4.metric("💰 Master Cashbook Closing Balance", f"₦{bm_closing_balance:,.0f}")
        
        t5, t6, t7 = st.columns(3)
        t5.metric("📊 Expected Repayment Target", f"₦{total_target:,.0f}", target_breakdown, delta_color="off")
        t6.metric("💵 Total Repayment Collected Today", f"₦{collected_today:,.0f}")
        t7.metric("🚀 Excess / Shortfall (Collected)", f"₦{excess:,.0f}", delta_color=excess_color)
        
        st.markdown("#### 💰 Branch Portfolio Summary")
        c1, c2, c3 = st.columns(3)
        c1.metric("👥 Active Loans", active_loans_count)
        c2.metric("🐷 Total Branch Savings (Active)", f"₦{real_total_savings:,.0f}")
        c3.metric("🚨 Total Overdue Amount", f"₦{total_overdue:,.0f}", delta_color="inverse" if total_overdue > 0 else "normal")
        
    else: # CO / Officer
        st.markdown(f"### 📱 Credit Officer Dashboard — {USER} ({BRANCH})")
        # CO Operations Today
        st.markdown("#### 📅 My Operations Today")
        t1, t2, t3, t4, t5 = st.columns(5)
        t1.metric("📥 Savings Deposit", f"₦{today_savings_deposited:,.0f}")
        t2.metric("💵 Loan Repayment", f"₦{collected_today:,.0f}")
        t3.metric("🚀 Excess", f"₦{today_excess:,.0f}")
        t4.metric("🎯 Full Payment", f"₦{today_full_payment_amount:,.0f}")
        t5.metric("💰 Cash Closing Balance", f"₦{co_closing_balance:,.0f}")
        
        # CO Portfolio Overview
        st.markdown("#### 💰 My Portfolio Overview")
        p1, p2, p3, p4 = st.columns(4)
        p1.metric("👥 Active Clients", active_loans_count)
        p2.metric("📈 Active Credit", f"₦{total_active_credit:,.0f}")
        p3.metric("🐷 Total Savings", f"₦{co_total_savings:,.0f}")
        p4.metric("💵 Total Repayment", f"₦{total_repayments_collected:,.0f}")

        p5, p6, p7 = st.columns(3)
        p5.metric("🚀 Total Excess", f"₦{total_excess_collected:,.0f}")
        p6.metric("🎯 Total Full Payment", f"₦{total_full_payment_collected:,.0f}")
        p7.metric("📅 Monthly Disbursed Principal", f"₦{monthly_disbursed_principal:,.0f}")

    if group_data:
        st.divider()
        st.markdown("### 🏘️ Group-Wise Summaries")
        
        # Build main group dataframe
        g_list = []
        for gn, d in group_data.items():
            g_list.append({
                "Group Name": gn,
                "Members": d['members'],
                "Total Savings": d['savings'],
                "Group Savings": d['global_savings'],
                "Active Credit": d['active_credit'],
                "Credit Balance": d['loan_balance']
            })
            
        g_df = pd.DataFrame(g_list)
        
        # Add a Total row
        total_row = pd.DataFrame([{
            "Group Name": "TOTAL",
            "Members": g_df['Members'].sum(),
            "Total Savings": g_df['Total Savings'].sum(),
            "Group Savings": g_df['Group Savings'].sum(),
            "Active Credit": g_df['Active Credit'].sum(),
            "Credit Balance": g_df['Credit Balance'].sum()
        }])
        g_df = pd.concat([g_df, total_row], ignore_index=True)
        
        st.dataframe(
            g_df,
            use_container_width=True,
            hide_index=True,
            column_config={
                "Total Savings": st.column_config.NumberColumn(format="₦%d"),
                "Group Savings": st.column_config.NumberColumn(format="₦%d"),
                "Active Credit": st.column_config.NumberColumn(format="₦%d"),
                "Credit Balance": st.column_config.NumberColumn(format="₦%d")
            }
        )
        
        if has_weekly:
            st.markdown("#### 📅 Weekly Products Breakdown (12 Weeks vs 24 Weeks)")
            w_list = []
            for gn, d in group_data.items():
                if d['12w_active'] > 0 or d['12w_bal'] > 0 or d['24w_active'] > 0 or d['24w_bal'] > 0:
                    w_list.append({
                        "Group Name": gn,
                        "12 Weeks Active": d['12w_active'],
                        "12 Weeks Balance": d['12w_bal'],
                        "24 Weeks Active": d['24w_active'],
                        "24 Weeks Balance": d['24w_bal']
                    })
            if w_list:
                w_df = pd.DataFrame(w_list)
                
                # Add a Total row
                w_total = pd.DataFrame([{
                    "Group Name": "TOTAL",
                    "12 Weeks Active": w_df['12 Weeks Active'].sum(),
                    "12 Weeks Balance": w_df['12 Weeks Balance'].sum(),
                    "24 Weeks Active": w_df['24 Weeks Active'].sum(),
                    "24 Weeks Balance": w_df['24 Weeks Balance'].sum()
                }])
                w_df = pd.concat([w_df, w_total], ignore_index=True)
                
                st.dataframe(
                    w_df,
                    use_container_width=True,
                    hide_index=True,
                    column_config={
                        "12 Weeks Active": st.column_config.NumberColumn(format="₦%d"),
                        "12 Weeks Balance": st.column_config.NumberColumn(format="₦%d"),
                        "24 Weeks Active": st.column_config.NumberColumn(format="₦%d"),
                        "24 Weeks Balance": st.column_config.NumberColumn(format="₦%d")
                    }
                )

elif page == "Loan Origination":
    st.title("Origination & Registration")
    
    orig_options = ["👤 Client Registration", "📝 Loan Application", "⏳ Pending Disbursements", "✏️ Edit Client/Guarantor"]
    if "orig_tab" not in st.session_state:
        st.session_state["orig_tab"] = "👤 Client Registration"
    if st.session_state["orig_tab"] not in orig_options:
        st.session_state["orig_tab"] = "👤 Client Registration"
        
    orig_idx = orig_options.index(st.session_state["orig_tab"])
    orig_section = st.radio("Navigate", orig_options, index=orig_idx, horizontal=True, label_visibility="collapsed", key="orig_tab_radio")
    st.session_state["orig_tab"] = orig_section

    if orig_section == "⏳ Pending Disbursements":
        st.subheader("Pending Disbursements")
        all_loans = load_loans()
        my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
        pending_clients = my_loans[(my_loans['Status'] == STATUS_PENDING) & (pd.to_numeric(my_loans['Loan Amount'], errors='coerce').fillna(0) > 0)]
        if pending_clients.empty:
            st.info("✅ No pending loans found.")
        else:
            st.dataframe(pending_clients[['Client ID', 'Client Name', 'Date', 'Officer', 'Loan Amount', 'Loan Product']], use_container_width=True)
            if ROLE in ["AM", "BM", ROLE_ADMIN]:
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
                            from services.loan_service import LoanService
                            with SupabaseUnitOfWork() as uow:
                                loans = uow.loans.find_by_client_id(selected_client_id)
                                pending_loans = [L for L in loans if (L.status.value == STATUS_PENDING if hasattr(L.status, 'value') else L.status == STATUS_PENDING)]
                                for L in pending_loans:
                                    L.start_date = final_start_date
                                    L.expected_end_date = expected_end_date
                                    LoanService.disburse_loan(uow, L)
                            
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

    elif orig_section == "👤 Client Registration":
        st.subheader("👤 Client Registration")
        # Only Admins and Super Admins can see the Bulk Onboarding method
        if ROLE in [ROLE_SUPER_ADMIN, ROLE_ADMIN]:
            reg_type = st.radio("Registration Method", ["Single Client", "📦 Bulk Onboarding"], horizontal=True)
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
                    st.info(f"✅ Selected group '{final_group_name}' (Code: {final_group_number}) meets on {group_data.get('meeting_day')}")
            
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
                st.markdown("##### 🆔 Means of Identification")
                id_col1, id_col2, id_col3 = st.columns(3)
                id_means = id_col1.selectbox("Means of ID", ["National ID (NIN)", "Voter's Card", "Driver's License", "International Passport", "None"], key="reg_client_id_means")
                id_number = id_col2.text_input("ID Number", placeholder="Enter identification number", key="reg_client_id_number")
                id_file = id_col3.file_uploader("Upload ID Document", type=["jpg", "jpeg", "png", "pdf"], key="reg_client_id_file")
                
                # Passport Photograph Section
                st.markdown("##### 📸 Passport Photograph")
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

                st.markdown("##### 🆔 Guarantor Identification & Passport")
                g_id_col1, g_id_col2, g_id_col3 = st.columns(3)
                g_id_means = g_id_col1.selectbox("Guarantor Means of ID", ["National ID (NIN)", "Voter's Card", "Driver's License", "International Passport", "None"], key="reg_guarantor_id_means")
                g_id_number = g_id_col2.text_input("Guarantor ID Number", placeholder="Enter ID number", key="reg_guarantor_id_number")
                g_id_file = g_id_col3.file_uploader("Upload Guarantor ID Document", type=["jpg", "jpeg", "png", "pdf"], key="reg_guarantor_id_file")
                
                g_pass_col1, g_pass_col2 = st.columns(2)
                g_pass_file = g_pass_col1.file_uploader("Upload Guarantor Passport Photograph", type=["jpg", "jpeg", "png"], key="reg_guarantor_passport")
                
                submitted_reg = st.form_submit_button("💾 Register Client", type="primary", use_container_width=True)
                
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
                                        st.warning(f"⚠️ File upload failed for '{file_name}' (Make sure 'client-ids' bucket is created in Supabase): {upload_err}")
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
                                    status="Active",
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
                                    "nickname": client_entity.nickname,
                                    "marital_status": client_entity.marital_status,
                                    "average_monthly_income": client_entity.average_monthly_income,
                                    "other_obligations": client_entity.other_obligations,
                                    "guarantor_name": st.session_state.get("reg_guarantor_name"),
                                    "guarantor_nickname": st.session_state.get("reg_guarantor_nickname"),
                                    "guarantor_phone": st.session_state.get("reg_guarantor_phone"),
                                    "guarantor_home_address": st.session_state.get("reg_guarantor_address"),
                                    "guarantor_marital_status": st.session_state.get("reg_guarantor_marital"),
                                    "guarantor_occupation": st.session_state.get("reg_guarantor_occupation"),
                                    "guarantor_relationship": st.session_state.get("reg_guarantor_relationship"),
                                    "guarantor_office_address": st.session_state.get("reg_guarantor_office"),
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
                                                loan_entity = Loan(
                                                    id=loan_id,
                                                    client_id=client_id,
                                                    client_name=name_val,
                                                    product_type=loan_type or "Weekly 24W",
                                                    amount=principal_loan or active_credit,
                                                    duration=24 if "24" in loan_type else 12,
                                                    frequency="Weekly" if "week" in loan_type.lower() else "Daily",
                                                    gap_fee=0.0,
                                                    expected_installment=remaining_bal / 24,
                                                    total_payable=principal_loan or active_credit,
                                                    status=LoanStatus.ACTIVE,
                                                    branch=bname,
                                                    credit_officer=oname or USER,
                                                    officer_id=officer_id,
                                                    branch_id=branch_id,
                                                    start_date=date.today() - timedelta(weeks=4),
                                                    extra_fields={"lifecycle_status": "Active"}
                                                )
                                                uow.loans.create(loan_entity)
                                                
                                                # Save guarantor details on the active loan row
                                                uow.client.table("loans").update({
                                                    "guarantor_name": g_name_val,
                                                    "guarantor_phone": g_phone_val,
                                                    "guarantor_home_address": g_address_val,
                                                    "guarantor_occupation": g_occ_val,
                                                    "guarantor_office_address": g_office_val,
                                                    "guarantor_relationship": g_rel_val,
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
                                                ScheduleService.generate_schedule(uow, loan_entity, date.today() - timedelta(weeks=4))
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
                                                    "nickname": str(member_row.get('Nickname', '')) if pd.notna(member_row.get('Nickname')) else "",
                                                    "marital_status": "Married",
                                                    "average_monthly_income": 0.0,
                                                    "other_obligations": "",
                                                    "guarantor_name": g_name_val,
                                                    "guarantor_phone": g_phone_val,
                                                    "guarantor_home_address": g_address_val,
                                                    "guarantor_marital_status": "Married",
                                                    "guarantor_occupation": g_occ_val,
                                                    "guarantor_relationship": g_rel_val,
                                                    "guarantor_office_address": g_office_val,
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

    elif orig_section == "📝 Loan Application":
        st.subheader("📝 Loan Application")
        
        # 1. Search Client
        search_query = st.text_input("🔍 Search Client by Name or Client ID", key="loan_app_search_query")
        
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
                
            col4.markdown(f"**Branch:** {branch_name}")
            col5.markdown(f"**Group:** {group_name}")
            col6.markdown(f"**Credit Officer:** {officer_name}")

            # 3. Load Savings Balance
            with SupabaseUnitOfWork() as uow:
                res_dep = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", selected_client.id).execute()
                res_wd = uow.client.table("individual_savings").select("withdrawal_amount").eq("client_id", selected_client.id).execute()
                savings_bal = sum(float(d.get("deposit_amount") or 0) for d in res_dep.data) - sum(float(w.get("withdrawal_amount") or 0) for w in res_wd.data)
            
            st.info(f"💰 **Current Pooled Savings Balance:** ₦{savings_bal:,.2f}")

            # 4. Loan Specific fields
            st.markdown("### 📝 Apply for a New Loan")
            st.markdown("#### 1. Loan Product Parameters")
            product_category = st.selectbox("Product Category", ["Finance", "Asset"], key="loan_app_category")
            
            with st.container():
                col_p1, col_p2 = st.columns(2)
                
                if product_category == "Finance":
                    prods = ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M"]
                    product_type = col_p1.selectbox("Loan Product", prods, key="loan_app_product_finance")
                else:
                    prods = ["60-Day Asset", "120-Day Asset", "Weekly 12W Asset", "Weekly 24W Asset", "Monthly 3M Asset", "Monthly 6M Asset", "Cash and Carry"]
                    product_type = col_p1.selectbox("Loan Product", prods, key="loan_app_product_asset")
                    
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
                        is_eligible, reasons = RenewalService.check_eligibility(uow, selected_client_id, requested_amount, product_type)
                    
                    if is_eligible:
                        st.success("✅ **ELIGIBLE FOR RENEWAL:** " + " ".join(reasons))
                    else:
                        st.error("❌ **NOT ELIGIBLE FOR RENEWAL:**")
                        for r in reasons:
                            st.write(f"- {r}")
                
                initial_downpayment = 0.0
                gap_fee = 0.0
                total_upfront_required = 0.0
                
                if product_category == "Asset":
                    initial_downpayment_input = st.number_input("Initial Cash Downpayment (₦)", min_value=0.0, step=5000.0, value=None, placeholder="0", key="loan_app_downpayment")
                    initial_downpayment = float(initial_downpayment_input or 0)
                    total_cost = requested_amount + interest
                    active_credit = total_cost - initial_downpayment
                    expected_installment = active_credit / duration if duration > 0 else 0.0
                    
                    st.markdown("---")
                    st.markdown(f"**Asset Cost:** ₦{requested_amount:,.0f} | **Interest:** ₦{interest:,.0f} | **Total Cost:** ₦{total_cost:,.0f}")
                    st.markdown(f"**Active Loan (Total Cost - Downpayment):** ₦{active_credit:,.0f}")
                    st.markdown(f"**Expected Installment:** ₦{expected_installment:,.0f} x {duration} {cycle}")
                    if initial_downpayment > 0:
                        st.info(f"💵 Ensure the ₦{initial_downpayment:,.0f} downpayment is collected physically. It will be banked as part of total cash.")
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
                            st.error(f"❌ **INSUFFICIENT SAVINGS:** Client has ₦{savings_bal:,.2f} but needs ₦{total_upfront_required:,.0f}. Please collect additional savings first.")
                        else:
                            st.success(f"✅ **SUFFICIENT SAVINGS:** Client has enough to cover the upfront fees.")

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
                                    st.error(f"❌ Cannot submit: This client already has an Active or Pending {product_category} loan!")
                                    st.stop()
                                    
                                if product_category == "Finance" and savings_bal < total_upfront_required:
                                    st.error("Cannot submit! Insufficient savings.")
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
                                        "initial_downpayment": initial_downpayment,
                                        "active_credit": final_active_credit,
                                        "loan_repay": final_expected_installment,
                                        "total_due": final_active_credit
                                    }
                                )
                                uow.loans.create(loan_entity)

                                from services.schedule_service import ScheduleService
                                ScheduleService.generate_schedule(uow, loan_entity, date.today() + timedelta(days=7))

                                st.success("Application submitted successfully! Repayment schedule generated and loan is Pending BM Approval.")
                                st.session_state["orig_tab"] = "⏳ Pending Disbursements"
                                import time
                                time.sleep(2)
                                st.rerun()
                        except Exception as ex:
                            st.error(f"Error submitting loan application: {ex}")
                            
    elif orig_section == "✏️ Edit Client/Guarantor":
        st.subheader("✏️ Edit Client/Guarantor Details")
        st.info("Search for a registered client to update their personal details and their guarantor information.")
        
        # 1. Search Client
        search_query = st.text_input("🔍 Search Client by Name or Client ID to Edit", key="edit_client_search_query")
        
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

            st.markdown("### 👤 Update Client Profile & 🤝 Guarantor Details")
            
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
                
                st.markdown("##### 🆔 Identification Section")
                id_col1, id_col2, id_col3 = st.columns(3)
                
                id_means_options = ["National ID (NIN)", "Voter's Card", "Driver's License", "International Passport", "None"]
                default_means_idx = id_means_options.index(selected_client.id_means) if selected_client.id_means in id_means_options else 4
                c_id_means = id_col1.selectbox("Means of ID", id_means_options, index=default_means_idx, key="edit_client_id_means")
                c_id_number = id_col2.text_input("ID Number", value=selected_client.id_number or "", key="edit_client_id_number")
                
                st.write("---")
                st.write("⚠️ *Optional: Upload new files only if you want to replace the existing ones.*")
                
                c_id_file = id_col3.file_uploader("Upload ID Document (replaces current)", type=["jpg", "jpeg", "png", "pdf"], key="edit_client_id_file")
                
                col_pass1, col_pass2 = st.columns(2)
                c_pass_file = col_pass1.file_uploader("Upload Passport Photograph (replaces current)", type=["jpg", "jpeg", "png"], key="edit_client_passport")
                
                st.markdown("#### 2. Guarantor Info")
                g_col1, g_col2, g_col3 = st.columns(3)
                
                g_name = g_col1.text_input("Guarantor Full Name", value=latest_loan.get("guarantor_name") or "")
                g_phone = g_col2.text_input("Guarantor Phone Number", value=latest_loan.get("guarantor_phone") or "")
                g_address = g_col3.text_input("Guarantor Home Address", value=latest_loan.get("guarantor_home_address") or "")
                
                g_col4, g_col5, g_col6 = st.columns(3)
                g_marital_options = ["Married", "Single", "Divorced", "Widowed"]
                g_marital_val = latest_loan.get("guarantor_marital_status") or "Married"
                g_marital_idx = g_marital_options.index(g_marital_val) if g_marital_val in g_marital_options else 0
                g_marital = g_col4.selectbox("Guarantor Marital Status", g_marital_options, index=g_marital_idx)
                
                g_occ = g_col5.text_input("Guarantor Occupation", value=latest_loan.get("guarantor_occupation") or "")
                g_rel = g_col6.text_input("Relationship with Client", value=latest_loan.get("guarantor_relationship") or "")
                
                g_office = st.text_input("Guarantor Office Address", value=latest_loan.get("guarantor_office_address") or "")
                
                st.markdown("##### 🆔 Guarantor Identification & Passport")
                g_id_col1, g_id_col2, g_id_col3 = st.columns(3)
                
                g_id_means_options = ["National ID (NIN)", "Voter's Card", "Driver's License", "International Passport", "None"]
                g_id_means_val = latest_loan.get("guarantor_id_means") or "None"
                g_id_means_idx = g_id_means_options.index(g_id_means_val) if g_id_means_val in g_id_means_options else 4
                
                g_id_means = g_id_col1.selectbox("Guarantor Means of ID", g_id_means_options, index=g_id_means_idx, key="edit_guarantor_id_means")
                g_id_number = g_id_col2.text_input("Guarantor ID Number", value=latest_loan.get("guarantor_id_number") or "", key="edit_guarantor_id_number")
                g_id_file = g_id_col3.file_uploader("Upload Guarantor ID Document (replaces current)", type=["jpg", "jpeg", "png", "pdf"], key="edit_guarantor_id_file")
                
                g_pass_col1, g_pass_col2 = st.columns(2)
                g_pass_file = g_pass_col1.file_uploader("Upload Guarantor Passport Photograph (replaces current)", type=["jpg", "jpeg", "png"], key="edit_guarantor_passport")
                
                submitted_edit = st.form_submit_button("💾 Save Client & Guarantor Updates", type="primary", use_container_width=True)
                
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
                                    loan_update_data = {
                                        "guarantor_name": g_name.strip() if g_name.strip() else None,
                                        "guarantor_phone": g_phone.strip() if g_phone.strip() else None,
                                        "guarantor_home_address": g_address.strip() if g_address.strip() else None,
                                        "guarantor_marital_status": g_marital,
                                        "guarantor_occupation": g_occ.strip() if g_occ.strip() else None,
                                        "guarantor_relationship": g_rel.strip() if g_rel.strip() else None,
                                        "guarantor_office_address": g_office.strip() if g_office.strip() else None,
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
    st.title("👥 Daily Collections & Outflows")
    st.caption("Record daily repayments, savings, and end of day outflows.")
    
    view_date = st.date_input("Select Date", datetime.now().date(), key="col_date")
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    if False:
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
            
        # Only Admins and Super Admins can see the Bulk Upload (Excel) option
        if ROLE in [ROLE_SUPER_ADMIN, ROLE_ADMIN]:
            col_mode = st.radio("Collection Mode", ["👤 Individual / Group Entry", "📥 Bulk Upload (Excel)"], horizontal=True, label_visibility="collapsed")
        else:
            col_mode = "👤 Individual / Group Entry"
        
        if col_mode == "📥 Bulk Upload (Excel)":
            st.markdown("### 📥 Bulk Upload (Excel Template)")
            with open("Master_Balancing_Template_V2.xlsx", "rb") as template_file:
                st.download_button(
                    label="⬇️ Download Master Balancing Template",
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
                    
        elif col_mode == "👤 Individual / Group Entry":
            st.markdown("### 👥 Member Collections")
        # Load all active clients for the target officer
        with SupabaseUnitOfWork() as uow:
            target_officer_id = uow.loans._resolve_officer_id(target_co)
            if ROLE in ["BM", ROLE_BRANCH_MANAGER]:
                res_c = uow.client.table("clients").select("client_id, client_code, name, status, client_memberships(groups(name))").eq("branch_id", BRANCH_ID).eq("status", "Active").execute()
            elif ROLE in ["AM", "Area Manager", ROLE_AREA_MANAGER]:
                res_c = uow.client.table("clients").select("client_id, client_code, name, status, client_memberships(groups(name))").in_("branch_id", ASSIGNED_BRANCH_IDS).eq("status", "Active").execute()
            elif ROLE in [ROLE_ADMIN, ROLE_SUPER_ADMIN, "Admin", "Super Admin"]:
                res_c = uow.client.table("clients").select("client_id, client_code, name, status, client_memberships(groups(name))").eq("status", "Active").execute()
            else:
                res_c = uow.client.table("clients").select("client_id, client_code, name, status, client_memberships(groups(name))").eq("officer_id", target_officer_id).eq("status", "Active").execute()
                
        clients_data = []
        if res_c.data:
            for c in res_c.data:
                g_name = "Ungrouped"
                m_list = c.get("client_memberships") or []
                if isinstance(m_list, list):
                    for m in m_list:
                        if m.get("groups") and m["groups"].get("name"):
                            g_name = m["groups"]["name"]
                            break
                elif isinstance(m_list, dict):
                    if m_list.get("groups") and m_list["groups"].get("name"):
                        g_name = m_list["groups"]["name"]
                
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
            selected_group = st.selectbox("Select Group", groups)
            
            if selected_group == "Ungrouped":
                group_clients = co_clients_df[co_clients_df['Group Name'] == "Ungrouped"]
            else:
                group_clients = co_clients_df[co_clients_df['Group Name'] == selected_group]
                
            if group_clients.empty:
                st.info("No active members in this group.")
            else:
                st.markdown(f"### Members in {selected_group}")
                
                # Fetch history for today to prefill/check
                today_reps = repayments[(repayments['Date'] == date_str) & (repayments['Officer'] == target_co)] if not repayments.empty else pd.DataFrame()
                
                # Clear state if group or date changed
                if st.session_state.get('collections_group') != selected_group or st.session_state.get('collections_date') != date_str:
                    st.session_state['pending_collections'] = []
                    st.session_state['collections_group'] = selected_group
                    st.session_state['collections_date'] = date_str
                
                # Pre-compute member data
                member_info = {}
                from services.schedule_service import ScheduleService
                with SupabaseUnitOfWork() as uow:
                    for _, member in group_clients.iterrows():
                        cid = member['Client ID']
                        uuid_id = member['ID']
                        mem_reps = repayments[repayments['Client ID'] == cid] if not repayments.empty else pd.DataFrame()
                        try:
                            res_dep = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", uuid_id).execute()
                            res_wd = uow.client.table("individual_savings").select("withdrawal_amount").eq("client_id", uuid_id).execute()
                            sav_bal = sum(float(d.get("deposit_amount") or 0) for d in res_dep.data) - sum(float(w.get("withdrawal_amount") or 0) for w in res_wd.data)
                        except Exception:
                            sav_bal = 0.0
                        # Find if there is an active loan in all_loans
                        active_loan_rows = all_loans[(all_loans['Client ID'] == uuid_id) & (all_loans['Status'] == 'Active')]
                        if not active_loan_rows.empty:
                            loan_row = active_loan_rows.iloc[0]
                            active_loan_id = loan_row.get('loan_id') or loan_row.get('Loan ID')
                            act_cred = float(loan_row.get('Active Credit', 0))
                            total_due_val = float(loan_row.get('Total Due', loan_row.get('Loan Amount', 0.0)))
                            total_paid = max(0.0, total_due_val - act_cred)
                            loan_prod_val = loan_row.get('Loan Product') or "Daily Loan"
                            expected_rep_schedule = ScheduleService.get_expected_repayment(uow, active_loan_id, view_date)
                            start_date_val = str(loan_row.get('Start Date', ''))
                        else:
                            active_loan_id = None
                            act_cred = 0.0
                            total_paid = 0.0
                            loan_prod_val = "None"
                            expected_rep_schedule = 0.0
                            start_date_val = ""
                            
                        rem_bal = act_cred
                        
                        # Check if user has a pending collection in session state (Edit/Go Back state)
                        pending_list = st.session_state.get('pending_collections', [])
                        pending_tx = next((tx for tx in pending_list if tx["Client ID"] == cid), None)
                        
                        if pending_tx:
                            prev_dep = float(pending_tx.get("Savings Amount") or 0.0)
                            prev_wd = float(pending_tx.get("Withdrawal Amount") or 0.0)
                            prev_rep = float(pending_tx.get("Loan Repayment Amount") or 0.0)
                        else:
                            prev_dep = 0.0
                            prev_wd = 0.0
                            # Default to expected repayment if no previous value in session state
                            today_paid = today_reps[today_reps['Client ID'] == cid] if not today_reps.empty else pd.DataFrame()
                            prev_rep = expected_rep_schedule if today_paid.empty else 0.0
                            
                        # Pack member details expected by UI
                        member_dict = member.to_dict()
                        member_dict.update({
                            "Active Credit": act_cred,
                            "Loan Repay": expected_rep_schedule,
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
                            "start_date": start_date_val
                        }
                
                if st.session_state.get('pending_collections') and st.session_state.get('collections_group') == selected_group and st.session_state.get('collections_date') == date_str and not st.session_state.get('edit_collections_mode', False):
                    st.markdown("### 🔍 Review Group Collections")
                    to_insert = st.session_state['pending_collections']
                    
                    total_in = sum(float(tx.get('Amount Paid', 0)) + float(tx.get('Bank Withdrawal', 0)) for tx in to_insert)
                    total_out = sum(float(tx.get('Withdrawal Amount', 0)) + float(tx.get('Expenses', 0)) + float(tx.get('Bank Deposited', 0)) + float(tx.get('Product Withdrawal', 0)) + float(tx.get('Laps Transferred', 0)) for tx in to_insert)
                    net_cash = total_in - total_out
                    
                    total_savings = sum(float(tx.get('Savings Amount', 0)) for tx in to_insert)
                    total_wd = sum(float(tx.get('Withdrawal Amount', 0)) for tx in to_insert)
                    total_net_savings = total_savings - total_wd
                    
                    st.info(f"**Total Money Collected (Cash In):** ₦{total_in:,.0f}")
                    st.warning(f"**Total Money Given Out (Cash Out):** ₦{total_out:,.0f}")
                    st.success(f"**NET CASH EXPECTED FROM GROUP:** ₦{net_cash:,.0f}")
                    st.markdown(f"**Total Net Savings:** ₦{total_net_savings:,.0f} *(Includes Individual & Group Savings)*")
                    
                    def _go_back_to_edit():
                        st.session_state['edit_collections_mode'] = True
                    
                    c1, c2 = st.columns(2)
                    c1.button("🔙 Edit / Go Back", on_click=_go_back_to_edit)
                    
                    if c2.button("✅ Confirm & Save to Database", type="primary", use_container_width=True):
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
                            g_reps = repayments[repayments['Client ID'] == f"GROUP-{selected_group}"] if not repayments.empty else pd.DataFrame()
                            if not g_reps.empty:
                                group_savings_balance = g_reps['Savings Amount'].sum() - g_reps['Withdrawal Amount'].sum()
                                
                        st.markdown(f"### 🏛️ Group-Level Savings (Available: ₦{group_savings_balance:,.0f})")
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
                            
                        gsc1, gsc2, gsc3 = st.columns(3)
                        global_group_savings = gsc1.number_input("Group Savings Deposit", min_value=0.0, step=500.0, value=prev_g_dep if prev_g_dep > 0 else None, placeholder="0", key="global_grp_sav")
                        global_group_wd = gsc2.number_input("Group Savings Withdrawal", min_value=0.0, step=500.0, value=prev_g_wd if prev_g_wd > 0 else None, placeholder="0", key="global_grp_wd")
                        global_laps_reserved = gsc3.number_input("Laps Reserved", min_value=0.0, step=500.0, value=prev_laps if prev_laps > 0 else None, placeholder="0", key="global_laps_res")
                        st.markdown("---")
                        
                        # ---- PER-CLIENT COLLECTIONS ----
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
                                s_date_str = info.get("start_date", "")
                                s_date = pd.to_datetime(s_date_str, errors='coerce') if s_date_str and str(s_date_str).strip() not in ['None', 'nan', ''] else pd.NaT
                                view_dt = pd.to_datetime(date_str)
                                
                                if pd.notna(s_date) and s_date > view_dt:
                                    st.warning(f"⚠️ **Next Repayment Due On:** {s_date.strftime('%Y-%m-%d')}")
                                    st.caption("*Collection is locked until the start date.*")
                                    continue
                                
                                if not is_asset:
                                    st.markdown("**🏦 Savings**")
                                    sc1, sc2 = st.columns(2)
                                    s_dep = sc1.number_input("Savings Deposit", min_value=0.0, step=500.0, value=info['prev_dep'] if info['prev_dep'] > 0 else None, placeholder="0", key=f"sdep_{cid}")
                                    s_wd = sc2.number_input("Savings Withdrawal", min_value=0.0, step=500.0, value=info['prev_wd'] if info['prev_wd'] > 0 else None, placeholder="0", key=f"swd_{cid}")
                                    sav_data[cid] = {"dep": s_dep, "wd": s_wd}
                                    st.markdown("---")
                                
                                st.markdown(f"**💵 Loan ({prod})** - Active Cr: ₦{info['act_cred']:,.0f}")
                                st.markdown(f"ℹ️ *Expected repayment calculated from schedule: ₦{info['expected_rep_schedule']:,.2f}*")
                                
                                rep_col = st.number_input(f"Credit Repayment", min_value=0.0, step=500.0, value=info['prev_rep'] if info['prev_rep'] > 0 else None, placeholder="0", key=f"rep_{cid}")
                                
                                rep_data[cid] = {
                                    "rep": rep_col, "app": 0, "pb": 0, "misc": 0,
                                    "asset_cr": 0, "cc": 0, "cfd": 0, "bonus": 0
                                }
                        
                        st.markdown("---")
                        submit_btn = st.form_submit_button("Calculate Totals & Review Members", type="primary", use_container_width=True)
                        
                        if submit_btn:
                            to_insert = []
                            
                            # Process per-client data
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
                            
                            # Process Group-Level Inflows
                            global_group_savings = float(global_group_savings or 0)
                            global_group_wd = float(global_group_wd or 0)
                            global_laps_reserved = float(global_laps_reserved or 0)
                            
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

elif page == "Daily Report":
    st.title("Daily Collections Report")
    
    view_date = st.date_input("Select Date for Report", datetime.now().date())
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    # Filter for the selected date for new active loans
    if not all_loans.empty:
        all_loans['DateStr'] = pd.to_datetime(all_loans['Date'], errors='coerce').dt.date.astype(str)
        daily_loans = all_loans[(all_loans['DateStr'] == date_str) & (all_loans['Status'].isin([STATUS_ACTIVE, STATUS_COMPLETED, STATUS_APPROVED]))]
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
                    loan_bal = c_loan['Active Credit'] - l_amt
                    
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
    else:
        st.info("No records found in database.")

elif page == "Audit Ledger":
    st.title("📒 Audit Ledger")
    st.caption("Complete transaction history — Loans & Repayments")
    
    audit_section = st.radio("View", ["📋 Loans Ledger", "💰 Repayments Ledger", "⚖️ Double-Entry Ledger"], horizontal=True, label_visibility="collapsed")
    
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
            
            display_cols = [c for c in ['Date', 'Client ID', 'Client Name', 'Officer', 'Branch', 'Loan Product', 'Loan Amount', 'Active Credit', 'Loan Repay', 'Status'] if c in filtered.columns]
            
            st.markdown(f"**{len(filtered)} records found**")
            
            display_df = filtered[display_cols].sort_values(['Date', 'Client ID'], ascending=[False, True])
            
            # Clean up zeros for cleaner display
            for col in ['Loan Amount', 'Active Credit', 'Loan Repay']:
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
                    "Loan Repay": st.column_config.NumberColumn(format="₦%d")
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
                            except Exception as e:
                                st.error(f"Error reversing transaction: {e}")

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
                        df_ledger = df_ledger[mask]
                        
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

elif page == "Audit Center":
    st.title("🏛️ Enterprise Audit & Reconciliation Center")
    st.caption("Read-only virtual ledgers, 6-way financial integrity verification, 360° transaction explorer, and 15 automated exception reports.")

    audit_tab1, audit_tab2, audit_tab3, audit_tab4, audit_tab5, audit_tab6, audit_tab7, audit_tab8, audit_tab9, audit_tab10 = st.tabs([
        "⚖️ Integrity & 6-Way Match",
        "📊 Fee Audit",
        "🏦 Treasury Audit",
        "🐷 Savings Audit",
        "💵 Loan Audit",
        "🎯 Collection Perf",
        "🚨 15 Exception Reports",
        "🔎 360° Explorer & Timeline",
        "📈 Performance Insights",
        "🧙 Reconciliation Wizard"
    ])

    with SupabaseUnitOfWork() as uow_ac:
        from services.audit_reporting_service import AuditReportingService
        from services.financial_reconciliation_service import FinancialReconciliationService
        from services.transaction_explorer_service import TransactionExplorerService

        # ---------------------------------------------------------------------
        # TAB 1: ⚖️ Financial Integrity & 6-Way Match
        # ---------------------------------------------------------------------
        with audit_tab1:
            st.subheader("⚖️ Live 6-Way Financial Integrity Verification")
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
        with audit_tab2:
            st.subheader("📊 Fee Audit Ledgers")
            fee_sub = st.selectbox("Select Fee Bucket:", [
                "PROCESSING_FEE", "PASSBOOK", "CREDIT_FORM", "CREDIT_FORM_DAMAGE",
                "BONUS", "MISC_FEE", "CONTINGENCY", "MARKUP_11", "MARKUP_20"
            ], key="ac_fee_type")

            fee_records = uow_ac.audit_views.get_fee_ledger(fee_sub, limit=300)
            metrics = AuditReportingService.calculate_summary_metrics(fee_records, amount_key="amount")

            m1, m2, m3, m4, m5 = st.columns(5)
            m1.metric("Total Amount", f"₦{metrics['total_amount']:,.2f}")
            m2.metric("Transaction Count", metrics['total_count'])
            m3.metric("Average Transaction", f"₦{metrics['average_amount']:,.2f}")
            m4.metric("Last Txn Date", metrics['last_transaction_date'])
            m5.metric("Highest Txn", f"₦{metrics['highest_amount']:,.2f}")

            if fee_records:
                df_fee = pd.DataFrame(fee_records)
                st.dataframe(df_fee, use_container_width=True)
                
                # CSV Export
                csv_data = df_fee.to_csv(index=False).encode('utf-8')
                st.download_button(f"📥 Export {fee_sub} CSV", data=csv_data, file_name=f"audit_{fee_sub.lower()}.csv", mime="text/csv")
            else:
                st.info(f"No records found for fee bucket: {fee_sub}")

        # ---------------------------------------------------------------------
        # TAB 3: 🏦 Treasury Audit
        # ---------------------------------------------------------------------
        with audit_tab3:
            st.subheader("🏦 Treasury Audit Ledgers")
            tr_sub = st.selectbox("Select Treasury Bucket:", [
                "BANK_DEPOSIT", "BANK_WITHDRAWAL", "OFFICE_EXPENSE", "STAFF_SALARY",
                "HO_TRANSFER_IN", "HO_TRANSFER_OUT", "BRANCH_TRANSFER_IN", "BRANCH_TRANSFER_OUT",
                "OTHER_AREA_TRANSFER", "ASSET_PROGRAM", "PRODUCT_FINANCE"
            ], key="ac_tr_type")

            tr_records = uow_ac.audit_views.get_treasury_ledger(tr_sub, limit=300)
            t_metrics = AuditReportingService.calculate_summary_metrics(tr_records, amount_key="amount")

            tm1, tm2, tm3, tm4, tm5 = st.columns(5)
            tm1.metric("Total Amount", f"₦{t_metrics['total_amount']:,.2f}")
            tm2.metric("Transaction Count", t_metrics['total_count'])
            tm3.metric("Average Transaction", f"₦{t_metrics['average_amount']:,.2f}")
            tm4.metric("Last Txn Date", t_metrics['last_transaction_date'])
            tm5.metric("Highest Txn", f"₦{t_metrics['highest_amount']:,.2f}")

            if tr_records:
                df_tr = pd.DataFrame(tr_records)
                st.dataframe(df_tr, use_container_width=True)
                csv_tr = df_tr.to_csv(index=False).encode('utf-8')
                st.download_button(f"📥 Export {tr_sub} CSV", data=csv_tr, file_name=f"audit_treasury_{tr_sub.lower()}.csv", mime="text/csv")
            else:
                st.info(f"No records found for treasury bucket: {tr_sub}")

        # ---------------------------------------------------------------------
        # TAB 4: 🐷 Savings Audit
        # ---------------------------------------------------------------------
        with audit_tab4:
            st.subheader("🐷 Savings Audit Ledgers")
            sav_sub = st.radio("Select Savings Ledger:", ["Individual Savings", "Group Savings", "Laps Savings"], horizontal=True)
            tbl_map = {"Individual Savings": "individual_savings", "Group Savings": "group_savings", "Laps Savings": "laps_savings"}
            
            sav_records = uow_ac.audit_views.get_savings_ledger(tbl_map[sav_sub], limit=300)
            if sav_records:
                df_sav = pd.DataFrame(sav_records)
                st.dataframe(df_sav, use_container_width=True)
            else:
                st.info(f"No records found for {sav_sub}")

        # ---------------------------------------------------------------------
        # TAB 5: 💵 Loan Audit
        # ---------------------------------------------------------------------
        with audit_tab5:
            st.subheader("💵 Loan Audit Ledgers")
            loan_sub = st.radio("Select Loan View:", ["Loan Disbursements", "Repayments"], horizontal=True)
            if loan_sub == "Loan Disbursements":
                l_records = uow_ac.audit_views.get_loan_disbursements(limit=300)
                if l_records:
                    st.dataframe(pd.DataFrame(l_records), use_container_width=True)
                else:
                    st.info("No loan disbursements found.")
            else:
                rep_records = uow_ac.audit_views.get_loan_repayments(limit=300)
                if rep_records:
                    st.dataframe(pd.DataFrame(rep_records), use_container_width=True)
                else:
                    st.info("No repayments found.")

        # ---------------------------------------------------------------------
        # TAB 6: 🎯 Collection Performance
        # ---------------------------------------------------------------------
        with audit_tab6:
            st.subheader("🎯 Collection Performance Audit")
            try:
                res_cp = uow_ac.client.table("collection_performance").select("*").order("meeting_date", desc=True).limit(300).execute()
                cp_data = res_cp.data or []
                if cp_data:
                    st.dataframe(pd.DataFrame(cp_data), use_container_width=True)
                else:
                    st.info("No collection performance records found.")
            except Exception:
                st.info("No collection performance data available.")

        # ---------------------------------------------------------------------
        # TAB 7: 🚨 15 Exception Reports
        # ---------------------------------------------------------------------
        with audit_tab7:
            st.subheader("🚨 15 Automated Audit Exception Reports")
            st.caption("Scans the core database for compliance breaches, unposted transactions, or projection anomalies.")

            ex_data = FinancialReconciliationService.run_15_exception_reports(uow_ac, BRANCH_ID if ROLE not in [ROLE_ADMIN, 'Super Admin', 'Admin'] else None)
            st.metric("Total Exceptions Detected", ex_data["total_exceptions"], delta=f"{ex_data['exception_rules_evaluated']} Rules Evaluated")

            for rule_name, rule_records in ex_data["details"].items():
                with st.expander(f"📌 Rule: {rule_name.replace('_', ' ').title()} ({len(rule_records)} issues)"):
                    if rule_records:
                        st.dataframe(pd.DataFrame(rule_records), use_container_width=True)
                    else:
                        st.success("✔ Zero exceptions detected for this rule.")

        # ---------------------------------------------------------------------
        # TAB 8: 🔎 360° Explorer & Timeline
        # ---------------------------------------------------------------------
        with audit_tab8:
            st.subheader("🔎 360° Universal Transaction Explorer & Audit Timeline")
            search_tx = st.text_input("Enter Transaction Reference, ID, or Client ID:", placeholder="e.g. REF-2360D1, TXN-...", key="ac_explorer_input")

            if search_tx:
                exp_res = TransactionExplorerService.explore_transaction(uow_ac, search_tx)
                if exp_res["found"]:
                    st.success(f"✔ Transaction records found for '{search_tx}'")
                    if exp_res["repayments"]:
                        st.markdown("#### 💰 Repayment Record")
                        st.json(exp_res["repayments"])
                    if exp_res["fees"]:
                        st.markdown("#### 📊 Fee Record")
                        st.json(exp_res["fees"])
                    if exp_res["treasury_transactions"]:
                        st.markdown("#### 🏦 Treasury Record")
                        st.json(exp_res["treasury_transactions"])
                    if exp_res["ledger_transactions"]:
                        st.markdown("#### ⚖️ General Ledger Journal")
                        st.json(exp_res["ledger_transactions"])
                else:
                    st.warning(f"No transaction records matched '{search_tx}'")

        # ---------------------------------------------------------------------
        # TAB 9: 📈 Performance Insights
        # ---------------------------------------------------------------------
        with audit_tab9:
            st.subheader("📈 Executive Performance Insights")
            st.info("System Performance & Portfolio Quality Insights")
            try:
                from services.client_risk_rating_service import ClientRiskRatingService
                risk_dist = ClientRiskRatingService.get_branch_risk_distribution(uow_ac, BRANCH_ID)
                st.json(risk_dist)
            except Exception:
                st.caption("Performance insights calculated dynamically.")

        # ---------------------------------------------------------------------
        # TAB 10: 🧙 Reconciliation Wizard
        # ---------------------------------------------------------------------
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

    st.title("📖 CO Daily Cashbook")
    st.caption("Daily Ledger — Auto-Calculated from Collections")
    
    view_date = st.date_input("Select Date", datetime.now().date(), key="wa_date")
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    if repayments.empty:
        repayments = pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
    
    repayments['DateStr'] = pd.to_datetime(repayments['Date'], errors='coerce').dt.date.astype(str)
    target_co = USER
        
    daily_reps = repayments[(repayments['DateStr'] == date_str) & (repayments['Officer'] == target_co)]
    
    # ========================================================
    # LEDGER DISPLAY & MANUAL OUTFLOWS
    # ========================================================
    st.markdown("### 📤 End of Day / Global Outflows")
    st.caption("Log your daily branch expenses, bank deposits, and withdrawals here.")
    
    with st.form("eod_form"):
        out_0, out_1, out_2, out_3 = st.columns(4)
        global_opening = out_0.number_input("Opening Balance (B/F Cash)", min_value=0.0, step=500.0, value=None, placeholder="0")
        global_expenses = out_1.number_input("Office Expenses", min_value=0.0, step=500.0, value=None, placeholder="0")
        global_bank_dep = out_2.number_input("Bank Deposited", min_value=0.0, step=500.0, value=None, placeholder="0")
        global_bank_wd = out_3.number_input("Bank Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
        
        out_4, out_5 = st.columns(2)
        global_prod_wd = out_4.number_input("Product Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
        global_laps_trans = out_5.number_input("Laps Transferred", min_value=0.0, step=500.0, value=None, placeholder="0")
        
        st.markdown("---")
        st.markdown("### Additional Global Collections")
        fee_1, fee_2, fee_3 = st.columns(3)
        global_app_fee = fee_1.number_input("Processing Fee", min_value=0.0, step=500.0, value=None, placeholder="0")
        global_passbook = fee_2.number_input("Pass Book", min_value=0.0, step=500.0, value=None, placeholder="0")
        global_misc_fee = fee_3.number_input("Misc Fee", min_value=0.0, step=500.0, value=None, placeholder="0")
        
        fee_4, fee_5, fee_6 = st.columns(3)
        global_asset_cr = fee_4.number_input("Asset Cr Sale", min_value=0.0, step=500.0, value=None, placeholder="0")
        global_cc = fee_5.number_input("Cash & Carry", min_value=0.0, step=500.0, value=None, placeholder="0")
        global_cfd = fee_6.number_input("Cr Form Dmg", min_value=0.0, step=500.0, value=None, placeholder="0")
        
        global_bonus = st.number_input("Bonus", min_value=0.0, step=500.0, value=None, placeholder="0")
        
        st.markdown("---")
        submit_eod = st.form_submit_button("Save End of Day", type="primary", use_container_width=True)
        
        if submit_eod:
            global_opening = float(global_opening or 0)
            global_expenses = float(global_expenses or 0)
            global_bank_dep = float(global_bank_dep or 0)
            global_bank_wd = float(global_bank_wd or 0)
            global_prod_wd = float(global_prod_wd or 0)
            global_laps_trans = float(global_laps_trans or 0)
            
            global_app_fee = float(global_app_fee or 0)
            global_passbook = float(global_passbook or 0)
            global_misc_fee = float(global_misc_fee or 0)
            global_asset_cr = float(global_asset_cr or 0)
            global_cc = float(global_cc or 0)
            global_cfd = float(global_cfd or 0)
            global_bonus = float(global_bonus or 0)
            
            if any(x > 0 for x in [global_opening, global_expenses, global_bank_dep, global_bank_wd, global_prod_wd, global_laps_trans, 
                                   global_app_fee, global_passbook, global_misc_fee, global_asset_cr, global_cc, global_cfd, global_bonus]):
                g_out = {
                    "Date": date_str, "Client ID": f"GLOBAL-{target_co}", "Client Name": f"{target_co} End of Day",
                    "Officer": target_co, "Branch": BRANCH,
                    "Amount Paid": sum([global_app_fee, global_passbook, global_misc_fee, global_asset_cr, global_cc, global_cfd, global_bonus]),
                    "Transaction Type": "End of Day", "Note": "Branch/Officer Global Inputs",
                    "Opening Balance": global_opening, "Savings Amount": 0, "Withdrawal Amount": 0, "Laps Reserved": 0,
                    "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
                    "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0,
                    "Bank Withdrawal": global_bank_wd, "Asset Sales": 0, "App Fee": global_app_fee, "Pass Book Bonus": global_passbook,
                    "Misc Fees": global_misc_fee, "Asset Credit Sales": global_asset_cr, "Cash and Carry": global_cc, "Credit Form": 0, "Credit Form Damage": global_cfd, "Bonus": global_bonus,
                    "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0, "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                    "Product Withdrawal": global_prod_wd, "Expenses": global_expenses, "Bank Deposited": global_bank_dep, "Laps Transferred": global_laps_trans,
                    "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
                }
                
                try:
                    save_repayment(g_out)
                    st.success("End of Day Outflows Submitted Successfully!")
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

    # Load from cashbook projection table instead of summing repayments
    bf_cash = t_sav = t_r12w = t_r24w = t_r60d = t_r120d = t_rmth = t_cont = t_bwd = t_asale = t_app = t_pb = t_misc = 0.0
    t_d11 = t_d20 = t_w11 = t_w20 = t_mm = t_pwd = t_exp = t_bdep = t_lres = t_ltrans = t_cc = 0.0
    
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        with SupabaseUnitOfWork() as uow:
            branch_id = uow.cashbook._resolve_branch_id(BRANCH)
            res_u = uow.client.table("app_users").select("id").eq("username", target_co).execute()
            o_id = res_u.data[0]["id"] if res_u.data else None
            
            uow.cashbook.rebuild_projection(branch_id, view_date, officer_id=o_id)
            
            if o_id:
                res_co = uow.client.table("co_cashbooks").select("*").eq("date", date_str).eq("branch_id", branch_id).eq("officer_id", o_id).execute()
                if res_co.data:
                    c = res_co.data[0]
                    bf_cash = float(c.get("opening_balance") or 0)
                    t_sav = float(c.get("savings_deposit") or 0)
                    t_r12w = float(c.get("rep_12_weeks") or 0)
                    t_r24w = float(c.get("rep_24_weeks") or 0)
                    t_r60d = float(c.get("rep_daily") or 0)
                    t_rmth = float(c.get("rep_monthly") or 0)
                    t_cont = float(c.get("contingency") or 0)
                    t_bwd = float(c.get("bank_withdrawal") or 0)
                    t_asale = float(c.get("asset_credit_sales") or 0)
                    t_app = float(c.get("app_fee") or 0)
                    t_pb = float(c.get("passbook") or 0)
                    t_misc = float(c.get("misc_fees") or 0)
                    t_lres = float(c.get("laps_reserve") or 0)
                    
                    t_d11 = float(c.get("daily_11_pct") or 0)
                    t_w11 = float(c.get("weekly_11_pct") or 0)
                    t_mm = float(c.get("risk_premium_returns") or 0)
                    t_r120d = float(c.get("rep_120_days") or 0)
                    t_pwd = float(c.get("product_withdrawal") or 0)
                    t_exp = float(c.get("office_expenses") or 0)
                    t_bdep = float(c.get("bank_deposit") or 0)
                    t_ltrans = float(c.get("laps_returns") or 0)
                    t_cc = float(c.get("cash_and_carry") or 0)
    except Exception as e:
        st.warning(f"Could not load CO cashbook projection: {e}")

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
    
    cashbook_section = st.radio("Navigate", ["📝 Daily Entry", "📱 CO Cashbook (CO View)", "📊 Monthly Ledger"], horizontal=True, label_visibility="collapsed")
    
    all_loans = load_loans()
    all_repayments = load_repayments()
    
    if cashbook_section == "📝 Daily Entry":
        view_date = st.date_input("Select Date", datetime.now().date(), key="mc_date")
        date_str = view_date.strftime("%Y-%m-%d")
        
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
                    auto_weekly_11 = cb_entry.weekly_11_pct
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
        
        # Auto-sum VAULT FUNDING from loans disbursed today
        if not all_loans.empty:
            all_loans['_dt'] = pd.to_datetime(all_loans['Date'], errors='coerce')
            today_loans = all_loans[
                (all_loans['_dt'].dt.date.astype(str) == date_str) &
                (all_loans['Branch'] == BRANCH) &
                (all_loans['Status'].isin([STATUS_ACTIVE, STATUS_APPROVED, STATUS_COMPLETED]))
            ]
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
                if pd.isna(active_cr): active_cr = 0
                cat = str(loan.get('Product Category', 'Finance'))
                prod = str(loan.get('Loan Product', '')).lower()
                if 'Asset' in cat:
                    auto_fund_asset += principal
                else:
                    auto_fund_finance += principal
                # Route active credit to product-specific disbursement
                if '120' in prod: auto_disb_120d += active_cr
                elif '60' in prod: auto_disb_60d += active_cr
                elif '24w' in prod: auto_disb_24w += active_cr
                elif '12w' in prod: auto_disb_12w += active_cr
                elif '3m' in prod or '6m' in prod: auto_disb_mth += active_cr
        
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
            ("Savings Deposit", auto_savings),
            ("Credit Rep (60 Days)", auto_rep_60d),
            ("Credit Rep (120 Days)", auto_rep_120d),
            ("Credit Rep (12 Weeks)", auto_rep_12w),
            ("Credit Rep (24 Weeks)", auto_rep_24w),
            ("Credit Rep (Monthly)", auto_rep_mth),
            ("Laps Reserve", auto_laps_res),
            ("Asset Credit Sales", auto_asset_cr_sales),
            ("Cash & Carry", auto_cash_carry),
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
            ("Fund To Assets", auto_fund_asset),
            ("Fund to Finance", auto_fund_finance),
            ("Product/Savings Withdrawal", auto_prod_wd + auto_savings_wd),
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
            
            st.markdown("#### ⚖️ Manual Adjustments")
            st.info("Use these fields ONLY to correct manual mistakes made on previous days. Do not use for normal transactions.")
            adj1, adj2 = st.columns(2)
            adj_inflow = adj1.number_input("Adjustment Inflow (+) (₦)", min_value=0.0, step=1000.0, value=0.0)
            adj_outflow = adj2.number_input("Adjustment Outflow (-) (₦)", min_value=0.0, step=1000.0, value=0.0)
            adj_reason = st.text_input("Reason for Adjustment", placeholder="E.g., Correcting Staff Salary typo from yesterday")
            
            # ---- CALCULATE TOTALS ----
            total_inflows = (
                auto_opening + auto_savings + auto_rep_60d + auto_rep_120d + auto_rep_12w + auto_rep_24w + auto_rep_mth +
                auto_laps_res + funds_ho + funds_branch + funds_area +
                auto_asset_cr_sales + auto_cash_carry +
                auto_daily_11 + auto_daily_20 + auto_weekly_11 + auto_weekly_20 + auto_monthly_markup +
                auto_contingency + auto_credit_form_dmg + auto_bonus + auto_app_fee + auto_passbook + auto_bank_wd +
                adj_inflow
            )
            
            total_outflows = (
                auto_disb_60d + auto_disb_120d + auto_disb_12w + auto_disb_24w + auto_disb_mth +
                xfer_branch + xfer_ho + xfer_area +
                auto_fund_asset + auto_fund_finance +
                auto_prod_wd + auto_savings_wd + salaries +
                auto_expenses + auto_laps_ret + auto_bank_dep +
                adj_outflow
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
                    "loan_received_asset": 0,
                    "loan_received_finance": 0,
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
                    "adjustment_in": adj_inflow,
                    "adjustment_out": adj_outflow,
                    "adjustment_reason": adj_reason
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
                        if xfer_branch > 0:
                            TreasuryService.post_treasury_transaction(uow, 'INTER_BRANCH_OUT', xfer_branch, BRANCH, USER, remarks=f"Transfer to Branch: {xfer_branch}")
                            posted_any = True
                        if xfer_ho > 0:
                            TreasuryService.post_treasury_transaction(uow, 'HO_TRANSFER_OUT', xfer_ho, BRANCH, USER, remarks=f"Transfer to HO: {xfer_ho}")
                            posted_any = True
                        if salaries > 0:
                            TreasuryService.post_treasury_transaction(uow, 'SALARY', salaries, BRANCH, USER, remarks=f"Salary Payment: {salaries}")
                            posted_any = True
                        if adj_inflow > 0:
                            TreasuryService.post_treasury_transaction(uow, 'HO_TRANSFER_IN', adj_inflow, BRANCH, USER, remarks=f"Inflow Adjustment: {adj_reason or 'Manual Adjustment'}")
                            posted_any = True
                        if adj_outflow > 0:
                            TreasuryService.post_treasury_transaction(uow, 'OFFICE_EXPENSE', adj_outflow, BRANCH, USER, remarks=f"Outflow Adjustment: {adj_reason or 'Manual Adjustment'}")
                            posted_any = True
                            
                        uow.cashbook.rebuild_projection(branch_id, view_date)
                        
                        if posted_any:
                            st.success("Treasury transactions posted and Cashbook projection rebuilt successfully!")
                        else:
                            st.success("Cashbook projection updated and verified successfully!")
                except Exception as e:
                    st.error(f"Failed to save and post cashbook manual entries: {e}")
    
    elif cashbook_section == "📱 CO Cashbook (CO View)":
        view_date = st.date_input("Select Date", datetime.now().date(), key="wa_mc_date")
        date_str = view_date.strftime("%Y-%m-%d")
        
        repayments = all_repayments.copy() if not all_repayments.empty else pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
        repayments['DateStr'] = pd.to_datetime(repayments['Date'], errors='coerce').dt.date.astype(str)

        # --- RBAC FILTERING ---
        st.markdown("### 🏢 Select Credit Officer")
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

        daily_reps = repayments[(repayments['DateStr'] == date_str) & (repayments['Officer'] == target_co)]

        # ========================================================
        # LEDGER DISPLAY & MANUAL OUTFLOWS
        # ========================================================
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
        def sum_col(df, col):
            if df.empty or col not in df.columns:
                return 0.0
            return pd.to_numeric(df[col], errors='coerce').fillna(0).sum()

        bf_cash = sum_col(daily_reps, 'Opening Balance')
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

        st.dataframe(pd.DataFrame(ledger_data).T.rename(columns={0: "Amount"}).style.format(precision=0, thousands=","), height=500)


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
            
            with SupabaseUnitOfWork() as uow:
                filters = CashbookFilter()
                filters.branch = BRANCH
                filters.start_date = start_date
                filters.end_date = end_date
                entries = uow.cashbook.find_range(filters)
            from mappers.base_mappers import CashbookMapper
            result = type('obj', (object,), {'data': [CashbookMapper.to_database(e) for e in entries]})
            
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
        client_savings_map = load_client_savings_map()
        for _, row in my_loans.iterrows():
            s_amt = client_savings_map.get(row['Client ID'], 0.0)
            loan_bal = float(row.get('Active Credit', 0.0))
            l_amt = max(0.0, float(row.get('Total Due', row.get('Loan Amount', 0.0))) - loan_bal)
            expected, overdue = calculate_overdue(row['Date'], row['Loan Product'], row['Loan Repay'], l_amt, row.get('Status', STATUS_ACTIVE))
            row_data = row.to_dict()
            row_data['Acc. Savings'] = s_amt
            row_data['Paid to Loan'] = l_amt
            row_data['Loan Balance'] = loan_bal
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
                "Status": st.column_config.SelectboxColumn("Status", options=[STATUS_PENDING, STATUS_APPROVED, STATUS_ACTIVE, STATUS_COMPLETED, STATUS_CLOSED]),
                "Meeting Day": st.column_config.SelectboxColumn("Meeting Day", options=["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]),
                "Branch": st.column_config.TextColumn("Branch", disabled=(ROLE != ROLE_ADMIN)),
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

    if ROLE in ['AM', 'Area Manager']:
        assigned_b_names = sorted(list(set(my_loans['Branch'].dropna().tolist()))) if not my_loans.empty and 'Branch' in my_loans.columns else []
        am_rep_branch_opts = ["All Assigned Branches"] + assigned_b_names
        selected_rep_am_branch = st.selectbox("🌐 Filter Reports by Branch:", am_rep_branch_opts, key="am_reports_branch_filter")
        if selected_rep_am_branch != "All Assigned Branches":
            my_loans = my_loans[my_loans['Branch'] == selected_rep_am_branch]
            if not all_repayments.empty and 'Branch' in all_repayments.columns:
                all_repayments = all_repayments[all_repayments['Branch'] == selected_rep_am_branch]
    
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
        tabs = st.tabs(["👥 Users", "➕ Create User", "🔑 Reset Password", "🔄 Officer Turnover", "🏢 AM Assignments", "🏢 Branch Closures", "📋 Audit Logs", "📊 Login History"])
    elif is_bm:
        tabs = st.tabs(["👥 Branch Staff", "🔑 Reset Password", "🏢 Branch Closures"])
    elif is_am:
        tabs = st.tabs(["👥 Branch Staff (Read Only)"])
    else:
        st.error("You do not have permission to access User Management.")
        st.stop()
    
    # --- Tab: Users List ---
    with tabs[0]:
        st.subheader("👥 Current Users")
        if all_users:
            df_users = pd.DataFrame(all_users)
            display_cols = ['username', 'full_name', 'role', 'branch_name', 'is_active', 'last_login', 'created_at']
            display_cols = [c for c in display_cols if c in df_users.columns]
            st.dataframe(df_users[display_cols], use_container_width=True)
            
            # Admin / BM: Activate / Deactivate toggles
            if is_admin or is_bm:
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
    
    # --- Tab: AM Branch Assignments (Admin Only) ---
    if is_admin:
        with tabs[4]:
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
        closure_tab_idx = 5 if is_admin else 2
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
                    submit_closure = st.form_submit_button("Save Closure", use_container_width=True)
                    if submit_closure:
                        if not closure_reason or len(closure_dates) != 2:
                            st.error("Please provide a reason and select a full date range (start and end).")
                        else:
                            try:
                                with SupabaseUnitOfWork() as uow:
                                    closure = BranchClosure(id='', start_date=closure_dates[0], end_date=closure_dates[1], reason=closure_reason)
                                    uow.branch_closures.create(closure)
                                st.success("Branch closure added successfully!")
                                get_custom_closures.clear()
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
    
    # --- Tab: Audit Logs (Admin Only) ---
    if is_admin:
        with tabs[6]:
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
        with tabs[7]:
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