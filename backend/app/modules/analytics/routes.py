"""Endpoints HTTP del módulo analytics."""
import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.modules.analytics import services
from app.modules.analytics.schemas import StatsRequest, StatsResponse
from app.modules.auth.deps import AdminUser, CurrentUser
from app.modules.prestadores.models import Prestador

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get(
    "/stats",
    response_model=StatsResponse,
    summary="Estadísticas Web Analytics (admin)",
    description="Devuelve stats de todos los sitios. Solo admins.",
)
async def get_stats(
    current_user: AdminUser,
    days: int = Query(default=7, ge=1, le=90),
    hostname: str | None = Query(default=None),
) -> StatsResponse:
    try:
        return await services.fetch_web_analytics(
            StatsRequest(days=days, hostname=hostname)
        )
    except RuntimeError as e:
        logger.error("Error CF: %s", e)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Cloudflare no disponible: {e}",
        )


@router.get(
    "/mi-prestador/stats",
    response_model=StatsResponse,
    summary="Estadísticas del prestador autenticado",
    description="Devuelve las stats del sitio del prestador. Filtra por hostname según su slug.",
)
async def get_my_stats(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    days: int = Query(default=7, ge=1, le=90),
) -> StatsResponse:
    # Buscar el prestador asociado al usuario
    result = await db.execute(
        select(Prestador).where(Prestador.usuario_id == current_user.id).order_by(Prestador.created_at.desc())
    )
    prestador = result.scalars().first()

    if not prestador:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No tenés un perfil de prestador asociado",
        )

    # Mapeo manual slug → hostname
    # Si el user tiene múltiples prestadores, priorizamos el que tiene hostname definido
    hostname_map = {
        "se-alquila-marido": "sealquilamarido.com",
    }

    # Buscar entre todos los prestadores del user el que tenga hostname
    if prestador and prestador.slug not in hostname_map:
        # Fallback: buscar cualquier prestador del user que tenga hostname
        all_prestadores = await db.execute(
            select(Prestador).where(Prestador.usuario_id == current_user.id)
        )
        for p in all_prestadores.scalars().all():
            if p.slug in hostname_map:
                prestador = p
                break

    hostname = hostname_map.get(prestador.slug) if prestador else None

    try:
        return await services.fetch_web_analytics(
            StatsRequest(days=days, hostname=hostname)
        )
    except RuntimeError as e:
        logger.error("Error CF: %s", e)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Cloudflare no disponible: {e}",
        )
