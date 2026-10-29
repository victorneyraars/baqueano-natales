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
from app.modules.notificaciones.admin_routes import router as admin_notificaciones_router
from app.modules.notificaciones.routes import router as notificaciones_router
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
from app.modules.prestadores.routes_reviews import (
    router_reviews_cliente as prestadores_reviews_cliente_router,
    router_reviews_prestador as prestadores_reviews_prestador_router,
    router_reviews_publico as prestadores_reviews_publico_router,
)
from app.modules.prestadores.routes import (
    router_admin_categorias as prestadores_admin_categorias_router,
)
from app.modules.prestadores.routes import (
    router_admin_prestadores as prestadores_admin_router,
)
from app.modules.prestadores.routes import (
    router_propietario as prestadores_propietario_router,
)
from app.modules.prestadores.routes import (
    router_publico as prestadores_publico_router,
)
from app.modules.promocion.routes import (
    router_admin as promocion_admin_router,
)
from app.modules.oficios.routes_reportes import (
    router_reportes_prestador as oficios_reportes_prestador_router,
)
from app.modules.oficios.routes_fotos import (
    router_fotos_cliente as oficios_fotos_cliente_router,
    router_fotos_prestador as oficios_fotos_prestador_router,
    router_fotos_archivo as oficios_fotos_archivo_router,
)
from app.modules.oficios.routes import (
    router_garantias_cliente as oficios_garantias_cliente_router,
    router_garantias_prestador as oficios_garantias_prestador_router,
    router_prestador_utilidades as oficios_prestador_utilidades_router,
    router_recordatorios as oficios_recordatorios_router,
    router_turnos_cliente as oficios_turnos_cliente_router,
    router_turnos_prestador as oficios_turnos_prestador_router,
    router_publico as oficios_publico_router,
    router_propietario as oficios_propietario_router,
    router_admin_categorias as oficios_admin_categorias_router,
    router_admin_repuestos as oficios_admin_repuestos_router,
    router_mis_ordenes as oficios_ordenes_prestador_router,
    router_mis_ordenes_cliente as oficios_ordenes_cliente_router,
)
from app.modules.social.routes import (
    router_admin as social_admin_router,
)
from app.modules.rentacar.routes import (
    router_admin as rentacar_admin_router,
)
from app.modules.rentacar.public_routes import (
    router_publico as rentacar_publico_router,
)
from app.modules.rentacar.routes_propietario import (
    router_propietario as rentacar_propietario_router,
)
from app.modules.social.worker import start_worker, stop_worker
from app.modules.brand.routes import router_propietario as brand_propietario_router
# Ops Dashboard (admin — CI/CD, tracks, health)
from app.modules.ops.routes import router as ops_admin_router
from app.modules.analytics.routes import router as analytics_router
from app.modules.ops import services_github as ops_services_github
from app.modules.ops.revalidate import router as revalidate_router
from app.modules.ops.worker import (
    start_worker as start_cleanup_worker,
    stop_worker as stop_cleanup_worker,
)
from app.modules.media.routes import router as media_router
from app.modules.oficios.worker import (

    start_worker as start_recordatorios_worker,
    stop_worker as stop_recordatorios_worker,
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

    # Arrancar el worker de publicaciones sociales (APScheduler)
    # No-op si SOCIAL_WORKER_ENABLED=false
    start_worker()
    start_recordatorios_worker()
    start_cleanup_worker()

    yield

    # Detener el worker
    stop_worker()
    stop_recordatorios_worker()
    stop_cleanup_worker()
    # Cerrar el cliente HTTP del Ops Dashboard (httpx best practice)
    try:
        await ops_services_github.close_http_client()
    except Exception as e:
        logger.warning(f"Error cerrando ops.http_client: {e}")

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
# Los orígenes se leen de settings.CORS_ORIGINS (env var por entorno) y se
# parsean con la property `cors_origin_list`, que además valida que no haya
# wildcard "*" en producción con credentials (riesgo de seguridad).
#
# Antes estaba hardcodeado a baqueanonatales.com, lo que impedía:
#   - Fetch desde sealquilamarido.com (web pública, dominio separado)
#   - Fetch desde dev.sealquilamarido.com (staging web, rama dev)
#   - Fetch desde localhost:4321 (Astro dev server)
#
# Ahora cada entorno declara sus orígenes en .env.dev / .env.prod.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------
# Routers
# ---------------------------------------------------------
# Auth / usuarios / admin (base)
from app.modules.integrations.routes import router as integrations_router

app.include_router(auth_router, prefix="/api/v1")
app.include_router(integrations_router, prefix="/api/v1")
app.include_router(usuarios_router, prefix="/api/v1")
app.include_router(notificaciones_router, prefix="/api/v1")
app.include_router(admin_notificaciones_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")

# Comercios
app.include_router(comercios_publico_router, prefix="/api/v1")
app.include_router(comercios_propietario_router, prefix="/api/v1")
app.include_router(comercios_admin_categorias_router, prefix="/api/v1")
app.include_router(comercios_admin_comercios_router, prefix="/api/v1")

# Prestadores (oficios)
app.include_router(prestadores_publico_router, prefix="/api/v1")
app.include_router(prestadores_propietario_router, prefix="/api/v1")
app.include_router(prestadores_admin_categorias_router, prefix="/api/v1")
app.include_router(prestadores_admin_router, prefix="/api/v1")

# Social (redes: Facebook, Instagram, Google Business)
app.include_router(social_admin_router, prefix="/api/v1")
app.include_router(brand_propietario_router, prefix="/api/v1")

# Rent a Car Vásquez (vertical de alquiler de vehículos)
app.include_router(rentacar_admin_router, prefix="/api/v1")
app.include_router(rentacar_publico_router, prefix="/api/v1")
app.include_router(rentacar_propietario_router, prefix="/api/v1")

# Promocion (afiches SVG)
app.include_router(promocion_admin_router, prefix="/api/v1")
app.include_router(oficios_publico_router, prefix="/api/v1")
app.include_router(oficios_propietario_router, prefix="/api/v1")
app.include_router(oficios_admin_categorias_router, prefix="/api/v1")
app.include_router(oficios_admin_repuestos_router, prefix="/api/v1")
app.include_router(oficios_ordenes_prestador_router, prefix="/api/v1")
app.include_router(oficios_ordenes_cliente_router, prefix="/api/v1")
app.include_router(oficios_prestador_utilidades_router, prefix="/api/v1")
app.include_router(oficios_turnos_cliente_router, prefix="/api/v1")
app.include_router(oficios_turnos_prestador_router, prefix="/api/v1")
app.include_router(oficios_garantias_cliente_router, prefix="/api/v1")
app.include_router(oficios_garantias_prestador_router, prefix="/api/v1")
app.include_router(oficios_recordatorios_router, prefix="/api/v1")
app.include_router(oficios_fotos_cliente_router, prefix="/api/v1")
app.include_router(oficios_fotos_prestador_router, prefix="/api/v1")
app.include_router(oficios_fotos_archivo_router, prefix="/api/v1")
app.include_router(oficios_reportes_prestador_router, prefix="/api/v1")
app.include_router(prestadores_reviews_cliente_router, prefix="/api/v1")
app.include_router(prestadores_reviews_prestador_router, prefix="/api/v1")
app.include_router(prestadores_reviews_publico_router, prefix="/api/v1")

# Ops Dashboard (admin — solo lectura, Fase 1)
app.include_router(media_router, prefix="/api/v1")
app.include_router(ops_admin_router, prefix="/api/v1")

# Analytics (Cloudflare Web Analytics)
app.include_router(analytics_router, prefix="/api/v1")
app.include_router(revalidate_router, prefix="/api/v1")


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