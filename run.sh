#!/bin/bash

# TrustMicro Credit - Startup Script
# Usage: ./run.sh [port]

PORT=${1:-8501}

echo "🏦 TrustMicro Credit - Loan Management System"
echo "=============================================="
echo ""

# Check if virtual environment exists
if [ -d "venv" ]; then
    echo "✓ Virtual environment found"
    source venv/bin/activate
else
    echo "⚠ Virtual environment not found. Creating one..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
fi

# Check if secrets.toml exists
if [ ! -f ".streamlit/secrets.toml" ]; then
    echo "⚠ Warning: .streamlit/secrets.toml not found!"
    echo "  Please create it with your Supabase and Google credentials."
    echo ""
fi

echo ""
echo "🚀 Starting application on port $PORT..."
echo "📱 Open your browser at: http://localhost:$PORT"
echo ""

streamlit run app.py --server.port=$PORT --server.address=0.0.0.0
