"""Reporting Module for TrustMicro Credit"""
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import streamlit as st

def generate_portfolio_summary(loans_df, repayments_df):
    """Generate portfolio summary metrics"""
    if loans_df.empty:
        return {
            'active_loans': 0,
            'total_cash_in': 0,
            'total_savings': 0,
            'total_portfolio': 0,
            'total_overdue': 0,
            'par_percentage': 0,
            'pending_count': 0
        }
    
    active_loans = loans_df[loans_df['Status'].isin(['Approved', 'Active'])]
    pending_count = len(loans_df[loans_df['Status'] == 'Pending'])
    
    total_cash_in = pd.to_numeric(repayments_df['Amount Paid'], errors='coerce').sum() if not repayments_df.empty else 0
    
    total_savings = 0
    total_portfolio = 0
    total_overdue = 0
    par_balance = 0
    
    for _, row in active_loans.iterrows():
        client_payments = repayments_df[repayments_df['Client ID'] == row['Client ID']] if not repayments_df.empty else pd.DataFrame()
        
        fixed_repay = float(row['Loan Repay'])
        active_credit = float(row['Active Credit'])
        
        # Calculate savings and loan paid
        total_loan_paid = 0
        savings = 0
        if not client_payments.empty:
            for _, p_row in client_payments.iterrows():
                # Backward compatibility
                amount = float(p_row.get('Amount Paid', 0))
                trans_type = p_row.get('Transaction Type', 'Loan')
                
                # Granular columns
                savings_dep = float(p_row.get('Savings Amount', 0))
                loan_rep = float(p_row.get('Loan Repayment Amount', 0))
                withdrawal = float(p_row.get('Withdrawal Amount', 0))
                
                if savings_dep > 0 or loan_rep > 0 or withdrawal > 0:
                    savings += savings_dep
                    savings -= withdrawal
                    total_loan_paid += loan_rep
                else:
                    if trans_type == 'Savings':
                        savings += amount
                    else:
                        if amount > fixed_repay:
                            savings += (amount - fixed_repay)
                            total_loan_paid += fixed_repay
                        else:
                            total_loan_paid += amount
        
        total_savings += savings
        loan_balance = max(0, active_credit - total_loan_paid)
        total_portfolio += loan_balance
        
        # Calculate overdue
        try:
            start_date = datetime.strptime(row['Date'], "%Y-%m-%d")
            today = datetime.now()
            
            if "Daily" in str(row['Loan Product']):
                business_days = len(pd.bdate_range(start_date.date(), today.date()))
                days_passed = max(0, business_days - 1)
                capped_days = min(days_passed, 60)
                expected_paid = capped_days * fixed_repay
            elif "12 Weeks" in str(row['Loan Product']):
                weeks_passed = max(0, (today - start_date).days // 7)
                capped_weeks = min(weeks_passed, 12)
                expected_paid = capped_weeks * fixed_repay
            elif "24 Weeks" in str(row['Loan Product']):
                weeks_passed = max(0, (today - start_date).days // 7)
                capped_weeks = min(weeks_passed, 24)
                expected_paid = capped_weeks * fixed_repay
            else:
                expected_paid = 0
            
            overdue = max(0, expected_paid - total_loan_paid)
            total_overdue += overdue
            if overdue > 0:
                par_balance += loan_balance
        except:
            pass
    
    par_percentage = (par_balance / total_portfolio * 100) if total_portfolio > 0 else 0
    
    return {
        'active_loans': len(active_loans),
        'total_cash_in': total_cash_in,
        'total_savings': total_savings,
        'total_portfolio': total_portfolio,
        'total_overdue': total_overdue,
        'par_percentage': par_percentage,
        'pending_count': pending_count
    }

def create_portfolio_chart(loans_df):
    """Create portfolio distribution chart"""
    if loans_df.empty:
        return None
    
    status_counts = loans_df['Status'].value_counts()
    
    fig = px.pie(
        values=status_counts.values,
        names=status_counts.index,
        title="Loan Status Distribution",
        color_discrete_sequence=['#003366', '#0066cc', '#4da6ff', '#99ccff']
    )
    fig.update_traces(textposition='inside', textinfo='percent+label')
    return fig

def create_officer_performance_chart(officer_data):
    """Create officer performance chart"""
    if not officer_data:
        return None
    
    df = pd.DataFrame(officer_data)
    if df.empty:
        return None
    
    summary = df.groupby('Officer').agg({
        'Active Portfolio': 'sum',
        'Overdue Cash': 'sum'
    }).reset_index()
    
    fig = go.Figure()
    fig.add_trace(go.Bar(
        name='Active Portfolio',
        x=summary['Officer'],
        y=summary['Active Portfolio'],
        marker_color='#003366'
    ))
    fig.add_trace(go.Bar(
        name='Overdue Amount',
        x=summary['Officer'],
        y=summary['Overdue Cash'],
        marker_color='#cc0000'
    ))
    
    fig.update_layout(
        title="Officer Performance",
        barmode='group',
        xaxis_title="Officer",
        yaxis_title="Amount (₦)",
        legend=dict(orientation="h", yanchor="bottom", y=1.02)
    )
    
    return fig

def create_weekly_trend_chart(repayments_df, weeks=8):
    """Create weekly repayment trend chart"""
    if repayments_df.empty:
        return None
    
    df = repayments_df.copy()
    df['Date'] = pd.to_datetime(df['Date'], errors='coerce')
    df = df.dropna(subset=['Date'])
    
    # Group by week
    df['Week'] = df['Date'].dt.to_period('W').dt.start_time
    
    # Get last N weeks
    end_date = datetime.now()
    start_date = end_date - timedelta(weeks=weeks)
    df = df[df['Week'] >= start_date]
    
    weekly_data = df.groupby('Week')['Amount Paid'].sum().reset_index()
    
    fig = px.line(
        weekly_data,
        x='Week',
        y='Amount Paid',
        title=f"Weekly Cash In Trend (Last {weeks} Weeks)",
        markers=True
    )
    fig.update_traces(line_color='#003366', marker_size=8)
    fig.update_layout(
        xaxis_title="Week",
        yaxis_title="Amount Paid (₦)",
        hovermode='x unified'
    )
    
    return fig

def generate_officer_report(loans_df, repayments_df, officer_name=None):
    """Generate detailed officer report"""
    if officer_name:
        loans_df = loans_df[loans_df['Officer'] == officer_name]
        repayments_df = repayments_df[repayments_df['Officer'] == officer_name]
    
    if loans_df.empty:
        return pd.DataFrame()
    
    report_data = []
    
    for _, row in loans_df.iterrows():
        client_payments = repayments_df[repayments_df['Client ID'] == row['Client ID']] if not repayments_df.empty else pd.DataFrame()
        
        fixed_repay = float(row['Loan Repay'])
        active_credit = float(row['Active Credit'])
        
        total_loan_paid = 0
        savings = 0
        if not client_payments.empty:
            for _, p_row in client_payments.iterrows():
                # Backward compatibility
                amount = float(p_row.get('Amount Paid', 0))
                trans_type = p_row.get('Transaction Type', 'Loan')
                
                # Granular columns
                savings_dep = float(p_row.get('Savings Amount', 0))
                loan_rep = float(p_row.get('Loan Repayment Amount', 0))
                withdrawal = float(p_row.get('Withdrawal Amount', 0))
                
                if savings_dep > 0 or loan_rep > 0 or withdrawal > 0:
                    savings += savings_dep
                    savings -= withdrawal
                    total_loan_paid += loan_rep
                else:
                    if trans_type == 'Savings':
                        savings += amount
                    else:
                        if amount > fixed_repay:
                            savings += (amount - fixed_repay)
                            total_loan_paid += fixed_repay
                        else:
                            total_loan_paid += amount
        
        loan_balance = max(0, active_credit - total_loan_paid)
        
        # Calculate overdue
        overdue = 0
        try:
            start_date = datetime.strptime(row['Date'], "%Y-%m-%d")
            today = datetime.now()
            
            if "Daily" in str(row['Loan Product']):
                business_days = len(pd.bdate_range(start_date.date(), today.date()))
                days_passed = max(0, business_days - 1)
                capped_days = min(days_passed, 60)
                expected_paid = capped_days * fixed_repay
            elif "12 Weeks" in str(row['Loan Product']):
                weeks_passed = max(0, (today - start_date).days // 7)
                capped_weeks = min(weeks_passed, 12)
                expected_paid = capped_weeks * fixed_repay
            elif "24 Weeks" in str(row['Loan Product']):
                weeks_passed = max(0, (today - start_date).days // 7)
                capped_weeks = min(weeks_passed, 24)
                expected_paid = capped_weeks * fixed_repay
            else:
                expected_paid = 0
            
            overdue = max(0, expected_paid - total_loan_paid)
        except:
            pass
        
        report_data.append({
            'Client ID': row['Client ID'],
            'Client Name': row['Client Name'],
            'Phone': row['Phone'],
            'Group': row['Group Name'],
            'Product': row['Loan Product'],
            'Active Credit': active_credit,
            'Loan Repay': fixed_repay,
            'Paid to Loan': total_loan_paid,
            'Loan Balance': loan_balance,
            'Savings': savings,
            'Overdue': overdue,
            'Status': row['Status']
        })
    
    return pd.DataFrame(report_data)

def generate_daily_collection_df(repayments_df):
    if repayments_df.empty:
        return pd.DataFrame(columns=["S/N", "GROUP", "SAVINGS", "PROC FEE", "MARKUP", "PASS BOOK", "OTHERS", "INSTALMENTAL", "OVERDUE", "RECOVERY", "TOTAL"])
    
    # Simple grouping by Client/Group for the sake of the template
    # Realistically they enter by day, so we show total collections grouped by date/client
    data = []
    # If we have group names in repayments we could group, but we'll leave it as a general log
    for idx, row in repayments_df.iterrows():
        total = (float(row.get('Savings Amount', 0)) + float(row.get('Processing Fee Paid', 0)) +
                 float(row.get('Markup Paid', 0)) + float(row.get('Pass Book Paid', 0)) +
                 float(row.get('Others Amount', 0)) + float(row.get('Loan Repayment Amount', 0)) +
                 float(row.get('Recovery Amount', 0)))
        
        data.append({
            "S/N": len(data) + 1,
            "GROUP": row.get('Client Name', ''),
            "SAVINGS": row.get('Savings Amount', 0),
            "PROC FEE": row.get('Processing Fee Paid', 0),
            "MARKUP": row.get('Markup Paid', 0),
            "PASS BOOK": row.get('Pass Book Paid', 0),
            "OTHERS": row.get('Others Amount', 0),
            "INSTALMENTAL": row.get('Loan Repayment Amount', 0),
            "OVERDUE": "", # Manual entry
            "RECOVERY": row.get('Recovery Amount', 0),
            "TOTAL": total
        })
    return pd.DataFrame(data)

def generate_saving_withdrawal_df(loans_df):
    if loans_df.empty:
        return pd.DataFrame(columns=["S/N", "NAME", "GROUP", "SAVING BAL", "CREDIT BAL", "CASH RETURN", "SAVING WITHDRAWAL", "MGT FEES", "SIGN"])
    data = []
    for idx, row in loans_df.iterrows():
        data.append({
            "S/N": len(data) + 1,
            "NAME": row.get('Client Name', ''),
            "GROUP": row.get('Group Name', ''),
            "SAVING BAL": "", 
            "CREDIT BAL": row.get('Active Credit', 0),
            "CASH RETURN": "",
            "SAVING WITHDRAWAL": "",
            "MGT FEES": "",
            "SIGN": ""
        })
    return pd.DataFrame(data)

def generate_monthly_savings_df():
    return pd.DataFrame(columns=["Date", "Actual Deposits", "Savings Withdrawal", "Savings return", "Balance"])

def generate_monthly_credit_df():
    return pd.DataFrame(columns=["Date", "Credit Amount", "Excess Amount", "Actual Collection", "Credit Balance"])

def export_to_excel(loans_df, repayments_df, filename="trustmicro_export.xlsx"):
    """Export data to Excel file"""
    try:
        with pd.ExcelWriter(filename, engine='openpyxl') as writer:
            # Standard sheets
            loans_df.to_excel(writer, sheet_name='Raw_Loans', index=False)
            repayments_df.to_excel(writer, sheet_name='Raw_Repayments', index=False)
            
            summary = generate_portfolio_summary(loans_df, repayments_df)
            pd.DataFrame([summary]).to_excel(writer, sheet_name='Summary', index=False)
            
            # --- CUSTOM MANUAL TEMPLATES ---
            generate_daily_collection_df(repayments_df).to_excel(writer, sheet_name='Daily Collection', index=False)
            generate_saving_withdrawal_df(loans_df).to_excel(writer, sheet_name='Saving Withdrawal', index=False)
            generate_monthly_savings_df().to_excel(writer, sheet_name='Monthly Savings', index=False)
            generate_monthly_credit_df().to_excel(writer, sheet_name='Monthly Credit', index=False)
            
            # Get workbook and apply formatting
            workbook = writer.book
            
            # Helper to style header
            def style_header(ws_name):
                if ws_name in writer.sheets:
                    ws = writer.sheets[ws_name]
                    for cell in ws[1]:
                        cell.font = cell.font.copy(bold=True)
                        if 'Raw' in ws_name or ws_name == 'Summary':
                            cell.fill = cell.fill.copy(patternType='solid', fgColor='003366')
                        else:
                            # Light gray for templates
                            cell.fill = cell.fill.copy(patternType='solid', fgColor='D9D9D9')

            for sheet in ['Raw_Loans', 'Raw_Repayments', 'Daily Collection', 'Saving Withdrawal', 'Monthly Savings', 'Monthly Credit']:
                style_header(sheet)
                
        return True, filename
    except Exception as e:
        return False, str(e)
