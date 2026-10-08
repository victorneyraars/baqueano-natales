"""
Baqueano Natales - Backend API
Entry point de FastAPI.
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.firebase import init_firebase
from app.core.logging import setup_logging
from app.modules.auth.routes import router as auth_router
from app.modules.usuarios.routes import router as usuarios_router
from app.modules.admin.routes import router as admin_router
from app.modules.comercios.routes import (
    router_admin_categorias as comercios_admin_categorias_router,
)
from app.modules.comercios.routes import (
    router_admin_comercios as comercios_admin_comercios_router,
)
from app.modules.comercios.routes import (
    router_propietario as comercios_propietario_router,
)
from app.modules.comercios.routes import (
    router_publico as comercios_publico_router,
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle: arranque y apagado."""
    setup_logging()
    logger.info(f"Iniciando Baqueano Natales API [{settings.ENVIRONMENT}]")

    # Inicializar Firebase Admin SDK
    try:
        init_firebase()
    except Exception as e:
        logger.error(f"Error inicializando Firebase: {e}")
        raise

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

# CORS
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


# ---------------------------------------------------------
# Routers
# ---------------------------------------------------------
app.include_router(auth_router, prefix="/api/v1")
app.include_router(usuarios_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")

# Comercios
app.include_router(comercios_publico_router, prefix="/api/v1")
app.include_router(comercios_propietario_router, prefix="/api/v1")
app.include_router(comercios_admin_categorias_router, prefix="/api/v1")
app.include_router(comercios_admin_comercios_router, prefix="/api/v1")


# ---------------------------------------------------------
# Endpoints de sistema
# ---------------------------------------------------------
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