"""Google Sheets Integration Module for TrustMicro Credit"""
import gspread
from google.oauth2.service_account import Credentials
import pandas as pd
from datetime import datetime
import streamlit as st

SCOPES = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
]

def get_google_credentials():
    """Get Google credentials from Streamlit secrets"""
    try:
        creds_info = dict(st.secrets["google_service_account"])
        creds = Credentials.from_service_account_info(creds_info, scopes=SCOPES)
        return creds
    except Exception as e:
        st.error(f"Google Auth Error: {e}")
        return None

def init_sheets_client():
    """Initialize Google Sheets client"""
    creds = get_google_credentials()
    if creds:
        return gspread.authorize(creds)
    return None

def create_or_get_spreadsheet(client, spreadsheet_name="TrustMicro Credit Data"):
    """Create or get existing spreadsheet"""
    try:
        # Try to open existing
        spreadsheet = client.open(spreadsheet_name)
        return spreadsheet
    except gspread.SpreadsheetNotFound:
        # Create new
        spreadsheet = client.create(spreadsheet_name)
        # Share with service account
        spreadsheet.share(creds_info['client_email'], perm_type='user', role='writer')
        return spreadsheet

def export_loans_to_sheet(df, spreadsheet_name="TrustMicro Credit Data"):
    """Export loans data to Google Sheets"""
    client = init_sheets_client()
    if not client:
        return None, "Failed to initialize Google Sheets client"
    
    try:
        spreadsheet = create_or_get_spreadsheet(client, spreadsheet_name)
        
        # Try to get or create worksheet
        try:
            worksheet = spreadsheet.worksheet("Loans")
            worksheet.clear()
        except gspread.WorksheetNotFound:
            worksheet = spreadsheet.add_worksheet(title="Loans", rows="1000", cols="50")
        
        # Prepare data
        if df.empty:
            worksheet.append_row(["No data available"])
            return spreadsheet.url, "No data to export"
        
        # Convert DataFrame to list of lists
        data = [df.columns.tolist()] + df.values.tolist()
        
        # Update worksheet
        worksheet.update(data)
        
        # Format header
        worksheet.format('A1:Z1', {
            'textFormat': {'bold': True},
            'backgroundColor': {'red': 0.0, 'green': 0.2, 'blue': 0.4}
        })
        
        return spreadsheet.url, "Loans exported successfully"
    except Exception as e:
        return None, f"Export error: {e}"

def export_repayments_to_sheet(df, spreadsheet_name="TrustMicro Credit Data"):
    """Export repayments data to Google Sheets"""
    client = init_sheets_client()
    if not client:
        return None, "Failed to initialize Google Sheets client"
    
    try:
        spreadsheet = create_or_get_spreadsheet(client, spreadsheet_name)
        
        try:
            worksheet = spreadsheet.worksheet("Repayments")
            worksheet.clear()
        except gspread.WorksheetNotFound:
            worksheet = spreadsheet.add_worksheet(title="Repayments", rows="5000", cols="20")
        
        if df.empty:
            worksheet.append_row(["No data available"])
            return spreadsheet.url, "No data to export"
        
        data = [df.columns.tolist()] + df.values.tolist()
        worksheet.update(data)
        
        worksheet.format('A1:Z1', {
            'textFormat': {'bold': True},
            'backgroundColor': {'red': 0.0, 'green': 0.2, 'blue': 0.4}
        })
        
        return spreadsheet.url, "Repayments exported successfully"
    except Exception as e:
        return None, f"Export error: {e}"

def export_summary_report(summary_data, spreadsheet_name="TrustMicro Credit Reports"):
    """Export summary report to Google Sheets"""
    client = init_sheets_client()
    if not client:
        return None, "Failed to initialize Google Sheets client"
    
    try:
        spreadsheet = create_or_get_spreadsheet(client, spreadsheet_name)
        
        # Create dated worksheet
        date_str = datetime.now().strftime("%Y-%m-%d")
        worksheet_title = f"Report_{date_str}"
        
        try:
            worksheet = spreadsheet.worksheet(worksheet_title)
            worksheet.clear()
        except gspread.WorksheetNotFound:
            worksheet = spreadsheet.add_worksheet(title=worksheet_title, rows="100", cols="20")
        
        # Build report data
        report_rows = [
            ["TrustMicro Credit - Summary Report"],
            [f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}"],
            [],
            ["Metric", "Value"],
            ["Total Active Loans", summary_data.get('active_loans', 0)],
            ["Total Cash In", summary_data.get('total_cash_in', 0)],
            ["Total Savings Held", summary_data.get('total_savings', 0)],
            ["Total Active Portfolio", summary_data.get('total_portfolio', 0)],
            ["Total Overdue", summary_data.get('total_overdue', 0)],
            ["PAR %", f"{summary_data.get('par_percentage', 0):.2f}%"],
            ["Pending Approvals", summary_data.get('pending_count', 0)],
        ]
        
        worksheet.update(report_rows)
        
        # Format
        worksheet.format('A1', {'textFormat': {'bold': True, 'fontSize': 14}})
        worksheet.format('A4:B4', {
            'textFormat': {'bold': True},
            'backgroundColor': {'red': 0.9, 'green': 0.9, 'blue': 0.9}
        })
        
        return spreadsheet.url, "Report exported successfully"
    except Exception as e:
        return None, f"Export error: {e}"
