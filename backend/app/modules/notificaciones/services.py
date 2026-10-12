"""Services del modulo notificaciones."""
from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.notifications.models import (
    EstadoNotificacion,
    NotificationLog,
)
from app.modules.auth.models import Usuario


async def listar_mis_notificaciones(
    db: AsyncSession,
    usuario: Usuario,
    limit: int = 50,
    offset: int = 0,
) -> list[NotificationLog]:
    """Lista las notificaciones del usuario, mas recientes primero."""
    stmt = (
        select(NotificationLog)
        .where(NotificationLog.usuario_id == usuario.id)
        .order_by(
            NotificationLog.creado_en.desc(),
            NotificationLog.id.desc(),   # tie-breaker para orden estable
        )
        .limit(limit)
        .offset(offset)
    )
    return list((await db.execute(stmt)).scalars().all())


async def marcar_recibida(
    db: AsyncSession,
    usuario: Usuario,
    notif_id: UUID,
) -> NotificationLog:
    """Marca una notificacion como entregada (device confirma recepcion)."""
    notif = await _obtener_de_usuario(db, usuario, notif_id)
    if notif.estado in (
        EstadoNotificacion.PENDIENTE,
        EstadoNotificacion.ENVIADA,
    ):
        notif.estado = EstadoNotificacion.ENTREGADA
    await db.flush()
    await db.refresh(notif)
    return notif


async def marcar_abierta(
    db: AsyncSession,
    usuario: Usuario,
    notif_id: UUID,
) -> NotificationLog:
    """Marca una notificacion como abierta. Idempotente."""
    notif = await _obtener_de_usuario(db, usuario, notif_id)
    if notif.estado == EstadoNotificacion.ABIERTA:
        return notif
    notif.estado = EstadoNotificacion.ABIERTA
    notif.abierto_en = datetime.now(timezone.utc)
    await db.flush()
    await db.refresh(notif)
    return notif


async def _obtener_de_usuario(
    db: AsyncSession,
    usuario: Usuario,
    notif_id: UUID,
) -> NotificationLog:
    stmt = select(NotificationLog).where(
        NotificationLog.id == notif_id,
        NotificationLog.usuario_id == usuario.id,
    )
    notif = (await db.execute(stmt)).scalar_one_or_none()
    if notif is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notificacion no encontrada",
        )
    return notif
