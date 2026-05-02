# 🏦 TrustMicro Credit - Loan Management System

A comprehensive microfinance loan management application built with Streamlit and Supabase, featuring Google Sheets integration for data export and backup.

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![Python](https://img.shields.io/badge/python-3.9+-green)
![Streamlit](https://img.shields.io/badge/streamlit-1.32.0-red)

## ✨ Features

### Core Functionality
- **Multi-Role Authentication**: Admin, Branch Manager (BM), and Officer roles
- **Loan Application Processing**: Complete workflow from application to approval
- **Repayment Tracking**: Daily and weekly repayment schedules with savings tracking
- **Portfolio Management**: Real-time portfolio health monitoring
- **Risk Assessment**: Overdue calculation and Portfolio At Risk (PAR) metrics

### Reporting & Analytics
- **Interactive Dashboard**: Visual charts and metrics
- **Google Sheets Export**: Automatic backup to Google Drive
- **Excel Export**: Download comprehensive reports
- **Officer Performance**: Individual performance tracking
- **Weekly Trends**: Cash flow visualization

### Security & Data
- **Cloud Database**: Supabase PostgreSQL backend
- **Role-Based Access**: Data filtered by user permissions
- **Audit Trail**: Complete transaction history
- **Data Validation**: Input validation and error handling

## 🚀 Quick Start

### Prerequisites
- Python 3.9 or higher
- Supabase account (free tier works)
- Google Cloud account (for Sheets integration)

### 1. Installation

```bash
# Clone or download the project
cd trustmicro-credit

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Supabase Setup

1. Go to [Supabase](https://supabase.com) and create a new project
2. Create two tables in the SQL Editor:

```sql
-- Loans table
CREATE TABLE loans (
    client_id UUID PRIMARY KEY,
    date DATE NOT NULL,
    branch TEXT,
    officer TEXT,
    client_name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    business_type TEXT,
    group_name TEXT,
    meeting_day TEXT,
    loan_product TEXT,
    loan_amount NUMERIC,
    active_credit NUMERIC,
    loan_repay NUMERIC,
    total_due NUMERIC,
    status TEXT DEFAULT 'Pending'
);

-- Repayments table
CREATE TABLE repayments (
    id SERIAL PRIMARY KEY,
    date TIMESTAMP DEFAULT NOW(),
    branch TEXT,
    client_id UUID REFERENCES loans(client_id),
    client_name TEXT,
    amount_paid NUMERIC,
    officer TEXT,
    note TEXT,
    transaction_type TEXT DEFAULT 'Loan'
);
```

3. Get your Supabase credentials:
   - Go to Project Settings > API
   - Copy `URL` and `anon public` key

### 3. Configuration

1. Edit `.streamlit/secrets.toml`:

```toml
SUPABASE_URL = "your_supabase_url_here"
SUPABASE_KEY = "your_supabase_key_here"

[google_service_account]
type = "service_account"
project_id = "your_project_id"
private_key_id = "your_key_id"
private_key = """-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_HERE
-----END PRIVATE KEY-----"""
client_email = "your_service_account@project.iam.gserviceaccount.com"
client_id = "your_client_id"
auth_uri = "https://accounts.google.com/o/oauth2/auth"
token_uri = "https://oauth2.googleapis.com/token"
auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs"
client_x509_cert_url = "your_cert_url"
universe_domain = "googleapis.com"
```

### 4. Run the Application

```bash
streamlit run app.py
```

The app will open at `http://localhost:8501`

## 👥 User Roles

| Username | Password | Role | Access |
|----------|----------|------|--------|
| admin | 1234 | Admin | Full system access |
| bm | 1234 | Branch Manager | Branch-level access |
| john | 1234 | Officer | Personal portfolio only |
| jane | 1234 | Officer | Personal portfolio only |

## 📊 Loan Products

| Product | Duration | Interest Rate | Frequency |
|---------|----------|---------------|-----------|
| Daily Loan | 60 Days | 12% | Daily (Mon-Fri) |
| Weekly (12W) | 12 Weeks | 12% | Weekly |
| Weekly (24W) | 24 Weeks | 21% | Weekly |

## 📁 Project Structure

```
trustmicro-credit/
├── app.py                  # Main application
├── requirements.txt        # Python dependencies
├── README.md              # This file
├── .streamlit/
│   └── secrets.toml       # Configuration (not in git)
└── utils/
    ├── google_sheets.py   # Google Sheets integration
    └── reports.py         # Reporting functions
```

## 🔧 Customization

### Adding New Users
Edit the `USERS` dictionary in `app.py`:

```python
USERS = {
    "admin": {"pass": "1234", "role": "Admin", "branch": "Global", "name": "System Admin"},
    "newuser": {"pass": "password", "role": "Officer", "branch": "Lagos", "name": "New Officer"},
}
```

### Modifying Loan Products
Edit the `calculate_loan_setup` function in `app.py`:

```python
def calculate_loan_setup(amount, product_type):
    if "Your Product" in str(product_type):
        rate = 0.15  # 15% interest
        duration = 20  # 20 periods
        freq = "Weekly"
        # ... rest of configuration
```

## 🌐 Deployment

### Streamlit Cloud (Recommended)

1. Push code to GitHub
2. Go to [Streamlit Cloud](https://streamlit.io/cloud)
3. Connect your repository
4. Add secrets in the dashboard:
   - `SUPABASE_URL`
   - `SUPABASE_KEY`
   - `google_service_account` (as TOML)

### Docker Deployment

```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8501

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

## 📈 Key Metrics

The system tracks:

- **Active Loans**: Number of approved/active loans
- **Total Cash In**: Sum of all repayments
- **Total Savings**: Accumulated savings from overpayments
- **Active Portfolio**: Outstanding loan balance
- **Overdue Amount**: Missed payments
- **PAR %**: Portfolio At Risk percentage

## 🔒 Security Notes

1. **Never commit `secrets.toml`** to version control
2. Use strong passwords in production
3. Enable Row Level Security (RLS) in Supabase
4. Regularly rotate Google service account keys
5. Use HTTPS in production

## 🐛 Troubleshooting

### Database Connection Issues
- Verify Supabase URL and key
- Check network connectivity
- Ensure tables are created correctly

### Google Sheets Export Fails
- Verify service account has Google Sheets API enabled
- Share target spreadsheet with service account email
- Check JSON format in secrets.toml

### Import Errors
- Ensure all dependencies are installed: `pip install -r requirements.txt`
- Check Python version (3.9+)

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Review Streamlit and Supabase documentation
3. Open an issue on GitHub

## 📄 License

MIT License - Free for commercial and personal use.

---

Built with ❤️ for microfinance institutions
