"""Endpoints HTTP del modulo notificaciones."""
from uuid import UUID

from fastapi import APIRouter, Query

from app.core.db import DbSession
from app.modules.auth.deps import CurrentUser
from app.modules.notificaciones import services
from app.modules.notificaciones.schemas import NotificacionResponse

router = APIRouter(prefix="/notificaciones", tags=["notificaciones"])


@router.get(
    "",
    response_model=list[NotificacionResponse],
    summary="Listar mis notificaciones",
)
async def listar_mis_notificaciones(
    user: CurrentUser,
    db: DbSession,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> list[NotificacionResponse]:
    """Devuelve el historial de notificaciones del usuario autenticado."""
    rows = await services.listar_mis_notificaciones(
        db, user, limit=limit, offset=offset
    )
    return [NotificacionResponse.model_validate(r) for r in rows]


@router.post(
    "/{notif_id}/recibida",
    response_model=NotificacionResponse,
    summary="Marcar notificacion como recibida",
)
async def marcar_recibida(
    notif_id: UUID,
    user: CurrentUser,
    db: DbSession,
) -> NotificacionResponse:
    """El dispositivo confirma que recibio la notificacion."""
    notif = await services.marcar_recibida(db, user, notif_id)
    return NotificacionResponse.model_validate(notif)


@router.post(
    "/{notif_id}/abierta",
    response_model=NotificacionResponse,
    summary="Marcar notificacion como abierta",
)
async def marcar_abierta(
    notif_id: UUID,
    user: CurrentUser,
    db: DbSession,
) -> NotificacionResponse:
    """El usuario toco la notificacion. Idempotente."""
    notif = await services.marcar_abierta(db, user, notif_id)
    return NotificacionResponse.model_validate(notif)
