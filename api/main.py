"""
ICARE Core Banking — Real FastAPI Backend Application Adapter.
Exposes authoritative REST APIs for Flutter clients directly wrapping Python domain services and Supabase Unit of Work.
"""
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from api.routes import auth
from api.routes.co import dashboard as co_dashboard
from api.routes.co import portfolio as co_portfolio
from api.routes.co import collections as co_collections
from api.routes.co import cashbook as co_cashbook
from api.routes.co import withdrawals as co_withdrawals
from api.routes.co import origination as co_origination
from api.routes.bm import dashboard as bm_dashboard
from api.routes.bm import cashbook as bm_cashbook
from api.routes import audit
from api.routes import users
from api.routes import reports

app = FastAPI(
    title="ICARE Core Banking Backend API",
    description="Production adapter for Flutter and web clients, strictly backed by Supabase and Python domain engines.",
    version="1.0.0"
)

# Enable CORS for Flutter Web, iOS, Android, and desktop clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Structured global error handler."""
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": f"Internal Server Error: {str(exc)}"}
    )


# Include Routers
app.include_router(auth.router)
app.include_router(co_dashboard.router)
app.include_router(co_portfolio.router)
app.include_router(co_collections.router)
app.include_router(co_cashbook.router)
app.include_router(co_withdrawals.router)
app.include_router(co_origination.router)
app.include_router(bm_dashboard.router)
app.include_router(bm_cashbook.router)
app.include_router(audit.router)
app.include_router(users.router)
app.include_router(reports.router)


@app.get("/health")
def health_check():
    """Service health check."""
    return {"status": "healthy", "service": "ICARE Core Banking API", "version": "1.0.0"}


import os
from starlette.staticfiles import StaticFiles

web_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "frontend_flutter", "build", "web")
if os.path.exists(web_dir):
    app.mount("/", StaticFiles(directory=web_dir, html=True), name="static")

