import logging
import os
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import get_settings
from app.database import Base, engine
from app.api.routers.auth import router as auth_router
from app.api.routers.sync import router as sync_router
from app.api.routers.admin import router as admin_router

settings = get_settings()

logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO))
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: create all tables if they don't exist yet
    import app.models  # noqa: F401 — registers all mappers with Base.metadata
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables ready")

    # Ensure upload directory exists
    upload_path = Path(settings.upload_dir)
    upload_path.mkdir(parents=True, exist_ok=True)
    logger.info("Upload directory ready: %s", settings.upload_dir)
    yield
    # Shutdown (nothing to clean up)


app = FastAPI(
    title="Servicios Main PC — API",
    version="1.0.0",
    description="Backend de sincronización para industrial_service_reports",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

# Routers
app.include_router(auth_router)
app.include_router(sync_router)
app.include_router(admin_router)

# Static files — serve uploaded photos/signatures/PDFs
_upload_path = Path(settings.upload_dir)
_upload_path.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(_upload_path)), name="uploads")


@app.get("/")
def root() -> dict:
    return {
        "message": "Servicios Main PC API",
        "version": "1.0.0",
        "docs": "/docs",
    }
