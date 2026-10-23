"""
ICARE Core Banking — Real FastAPI Backend Application Adapter.
Exposes authoritative REST APIs for Flutter clients directly wrapping Python domain services and Supabase Unit of Work.
"""
from fastapi import FastAPI, Request, HTTPException, status
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
from api.routes.bm import approvals as bm_approvals
from api.routes.am import dashboard as am_dashboard
from api.routes import audit
from api.routes import users
from api.routes import reports
from api.routes import onboarding

app = FastAPI(
    title="ICARE Core Banking Backend API",
    description="Production adapter for Flutter and web clients, strictly backed by Supabase and Python domain engines.",
    version="1.0.0"
)

# Enable CORS for Flutter Web, iOS, Android, and desktop clients
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


from api.core.errors import ICAREException, translate_error_to_icare_response
from fastapi.exceptions import RequestValidationError


@app.exception_handler(ICAREException)
async def icare_exception_handler(request: Request, exc: ICAREException):
    return JSONResponse(
        status_code=exc.status_code,
        content=exc.to_dict()
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    err_dict = translate_error_to_icare_response(exc)
    return JSONResponse(
        status_code=exc.status_code,
        content=err_dict
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    first_err = exc.errors()[0] if exc.errors() else {}
    field = " -> ".join(str(loc) for loc in first_err.get("loc", []))
    msg = first_err.get("msg", "Invalid input parameter.")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error_code": "VALIDATION_FAILED",
            "title": "Invalid Request Parameters",
            "message": f"Field '{field}': {msg}",
            "action": "Please check the required fields and submit valid data.",
            "details": exc.errors()
        }
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Structured global error handler providing human-friendly messages."""
    err_dict = translate_error_to_icare_response(exc)
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST if not isinstance(exc, (SystemError, MemoryError)) else status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=err_dict
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
app.include_router(bm_approvals.router)
app.include_router(am_dashboard.router)
app.include_router(audit.router)
app.include_router(users.router)
app.include_router(reports.router)
app.include_router(onboarding.router)


@app.get("/health")
@app.get("/api/health")
def health_check():
    """Service health check."""
    return {"status": "healthy", "service": "ICARE Core Banking API", "version": "1.0.0"}


import os
from starlette.staticfiles import StaticFiles

web_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "frontend_flutter", "build", "web")
if os.path.exists(web_dir):
    app.mount("/", StaticFiles(directory=web_dir, html=True), name="static")

