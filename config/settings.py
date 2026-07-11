import os
from dotenv import load_dotenv

load_dotenv()

COMPANY_NAME = "ICARE Microfinance"
APP_VERSION = "3.0.0"
CURRENCY_SYMBOL = "₦"

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")

DEFAULT_PAGE_CONFIG = {
    "page_title": f"{COMPANY_NAME} | Core System",
    "page_icon": "🏛️",
    "layout": "wide"
}
