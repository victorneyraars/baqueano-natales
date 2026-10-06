"""
Baqueano Natales - Backend API
Entry point de FastAPI.
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.logging import setup_logging


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle: arranque y apagado."""
    setup_logging()
    logger = __import__("logging").getLogger(__name__)
    logger.info(f"Iniciando Baqueano Natales API [{settings.ENVIRONMENT}]")
    yield
    logger.info("Cerrando Baqueano Natales API")


app = FastAPI(
    title="Baqueano Natales API",
    version="0.1.0",
    description="API de la superapp de movilidad y servicios de Puerto Natales",
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
    lifespan=lifespan,
)

# CORS - se ajustará cuando tengamos el dominio definitivo
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://baqueanonatales.com",
        "https://www.baqueanonatales.com",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["system"])
async def health():
    """Healthcheck para Docker y monitoreo."""
    return {
        "status": "ok",
        "environment": settings.ENVIRONMENT,
        "version": app.version,
    }


@app.get("/", tags=["system"])
async def root():
    """Raíz de la API."""
    return {
        "name": "Baqueano Natales API",
        "version": app.version,
        "docs": "/docs" if not settings.is_production else "disabled",
    }
