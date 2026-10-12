"""Endpoints admin del modulo notificaciones (requieren rol admin)."""
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Query

from app.core.db import DbSession
from app.modules.auth.deps import AdminUser
from app.modules.notificaciones import services
from app.modules.notificaciones.schemas import (
    EnvioMasivoResponse,
    NotificacionAdminCreate,
    NotificacionAdminResponse,
    RateLimitConfigResponse,
    RateLimitConfigUpdate,
    StatsResponse,
)

router = APIRouter(
    prefix="/admin/notificaciones",
    tags=["admin-notificaciones"],
)


@router.post(
    "/enviar",
    response_model=EnvioMasivoResponse,
    summary="Enviar notificacion manual a un segmento",
)
async def enviar_notificacion(
    data: NotificacionAdminCreate,
    admin: AdminUser,
    db: DbSession,
) -> EnvioMasivoResponse:
    """Envia una notificacion push a todos los usuarios del segmento.

    Respeta preferencias del usuario y quiet hours (excepto si el tipo
    es "sistema", que siempre se envia).
    """
    result = await services.enviar_a_segmento(db, data)
    return EnvioMasivoResponse(**result)


@router.get(
    "",
    response_model=list[NotificacionAdminResponse],
    summary="Historial de notificaciones (admin)",
)
async def listar_notificaciones_admin(
    admin: AdminUser,
    db: DbSession,
    tipo: str | None = Query(None),
    estado: str | None = Query(None),
    desde: datetime | None = Query(None),
    hasta: datetime | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
) -> list[NotificacionAdminResponse]:
    """Historial de notificaciones con filtros."""
    rows, _ = await services.listar_admin(
        db, tipo=tipo, estado=estado, desde=desde, hasta=hasta,
        limit=limit, offset=offset,
    )
    return [NotificacionAdminResponse.model_validate(r) for r in rows]


@router.get(
    "/stats",
    response_model=StatsResponse,
    summary="Estadisticas de notificaciones",
)
async def stats_notificaciones(
    admin: AdminUser,
    db: DbSession,
    desde: datetime | None = Query(None),
    hasta: datetime | None = Query(None),
) -> StatsResponse:
    """Dashboard agregado: tasas de entrega y apertura, top 5, por tipo."""
    result = await services.stats_dashboard(db, desde=desde, hasta=hasta)
    return StatsResponse(**result)


@router.get(
    "/rate-limits",
    response_model=list[RateLimitConfigResponse],
    summary="Listar configs de rate limit",
)
async def listar_rate_limits_endpoint(
    admin: AdminUser,
    db: DbSession,
) -> list[RateLimitConfigResponse]:
    """Devuelve la config actual de rate limit por tipo."""
    rows = await services.listar_rate_limits(db)
    return [RateLimitConfigResponse.model_validate(r) for r in rows]


@router.patch(
    "/rate-limits/{tipo}",
    response_model=RateLimitConfigResponse,
    summary="Actualizar rate limit de un tipo",
)
async def actualizar_rate_limit_endpoint(
    tipo: str,
    data: RateLimitConfigUpdate,
    admin: AdminUser,
    db: DbSession,
) -> RateLimitConfigResponse:
    """Actualiza la config de rate limit de un tipo."""
    config = await services.actualizar_rate_limit(db, tipo, data)
    return RateLimitConfigResponse.model_validate(config)
