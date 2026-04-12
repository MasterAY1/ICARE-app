@echo off
REM TrustMicro Credit - Startup Script for Windows
REM Usage: run.bat [port]

set PORT=%1
if "%PORT%"=="" set PORT=8501

echo 🏦 TrustMicro Credit - Loan Management System
echo ==============================================
echo.

REM Check if virtual environment exists
if exist "venv\Scripts\activate.bat" (
    echo ✓ Virtual environment found
    call venv\Scripts\activate.bat
) else (
    echo ⚠ Virtual environment not found. Creating one...
    python -m venv venv
    call venv\Scripts\activate.bat
    pip install -r requirements.txt
)

REM Check if secrets.toml exists
if not exist ".streamlit\secrets.toml" (
    echo ⚠ Warning: .streamlit\secrets.toml not found!
    echo   Please create it with your Supabase and Google credentials.
    echo.
)

echo.
echo 🚀 Starting application on port %PORT%...
echo 📱 Open your browser at: http://localhost:%PORT%
echo.

streamlit run app.py --server.port=%PORT% --server.address=0.0.0.0
