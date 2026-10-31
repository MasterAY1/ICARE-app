import os
from dotenv import load_dotenv

load_dotenv()

COMPANY_NAME = "ICARE Microfinance"
APP_VERSION = "3.0.0"
CURRENCY_SYMBOL = "₦"

# Base Supabase endpoint
SUPABASE_URL = os.getenv("SUPABASE_URL", "").strip()

# Explicit production backend credential (service_role only)
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()

# Legacy / client credential (anon key) - strictly disallowed as backend fallback in production
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "").strip()

# Environment indicator
ENVIRONMENT = (os.getenv("ENVIRONMENT") or os.getenv("APP_ENV") or "development").strip().lower()
IS_PRODUCTION = ENVIRONMENT in ("production", "prod") or bool(os.getenv("RENDER")) or bool(os.getenv("RENDER_SERVICE_ID"))

DEFAULT_PAGE_CONFIG = {
    "page_title": f"{COMPANY_NAME} | Core System",
    "page_icon": None,
    "layout": "wide"
}
