# Database to UI Mappings for Loans
DB_TO_UI_LOANS = {
    'id': 'ID',
    'client_id': 'Client ID',
    'client_name': 'Client Name',
    'product_type': 'Product',
    'amount': 'Amount',
    'duration': 'Duration',
    'frequency': 'Freq',
    'gap_fee': 'Gap Fee',
    'expected_installment': 'Installment',
    'total_payable': 'Total Payable',
    'status': 'Status',
    'branch': 'Branch',
    'credit_officer': 'CO',
    'start_date': 'Start Date',
    'end_date': 'End Date',
    'created_at': 'Created At',
    'group_name': 'Group Name',
    'is_asset': 'Is Asset'
}

UI_TO_DB_LOANS = {v: k for k, v in DB_TO_UI_LOANS.items()}

# Database to UI Mappings for Repayments
DB_TO_UI_REP = {
    'id': 'Trans ID',
    'loan_id': 'Loan ID',
    'client_id': 'Client ID',
    'amount_paid': 'Amount Paid',
    'savings_amount': 'Savings Amount',
    'loan_repayment_amount': 'Loan Repayment Amount',
    'withdrawal_amount': 'Withdrawal Amount',
    'others_amount': 'Others Amount',
    'recovery_amount': 'Recovery Amount',
    'initial_payment': 'initial_payment',
    'payment_date': 'Payment Date',
    'transaction_type': 'Transaction Type',
    'branch': 'Branch',
    'credit_officer': 'CO',
    'created_at': 'Created At'
}

UI_TO_DB_REP = {v: k for k, v in DB_TO_UI_REP.items()}
