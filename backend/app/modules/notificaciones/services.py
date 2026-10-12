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


# ==================== Admin: envio masivo ====================


async def _resolver_segmento(db: AsyncSession, segmento) -> list[UUID]:
    """Resuelve un segmento a una lista de usuario_ids (solo activos)."""
    from app.modules.auth.models import RolUsuario

    if segmento.tipo == "todos":
        stmt = select(Usuario.id).where(Usuario.activo.is_(True))
        return list((await db.execute(stmt)).scalars().all())

    if segmento.tipo == "rol":
        if not segmento.valor or not isinstance(segmento.valor, str):
            return []
        try:
            rol = RolUsuario(segmento.valor)
        except ValueError:
            return []
        stmt = select(Usuario.id).where(
            Usuario.activo.is_(True),
            Usuario.rol == rol,
        )
        return list((await db.execute(stmt)).scalars().all())

    if segmento.tipo == "usuarios":
        if not segmento.valor or not isinstance(segmento.valor, list):
            return []
        ids = [UUID(str(x)) if not isinstance(x, UUID) else x for x in segmento.valor]
        stmt = select(Usuario.id).where(
            Usuario.activo.is_(True),
            Usuario.id.in_(ids),
        )
        return list((await db.execute(stmt)).scalars().all())

    return []


async def enviar_a_segmento(db: AsyncSession, data) -> dict:
    """Envia una notificacion a un segmento. Devuelve contadores."""
    from app.core.notifications.models import TipoNotificacion
    from app.core.notifications.service import get_notification_service

    usuario_ids = await _resolver_segmento(db, data.segmento)
    tipo = TipoNotificacion(data.tipo)
    service = get_notification_service()

    enviados = 0
    fallidos = 0
    skipped = 0

    for uid in usuario_ids:
        result = await service.enviar_a_usuario(
            db=db,
            usuario_id=uid,
            titulo=data.titulo,
            body=data.body,
            tipo=tipo,
            data=data.data,
            analytics_label=data.analytics_label,
        )
        if result.success:
            enviados += 1
        elif result.error_code in ("PREFERENCE_DISABLED", "QUIET_HOURS", "NO_TOKENS"):
            skipped += 1
        else:
            fallidos += 1

    return {
        "total": len(usuario_ids),
        "enviados": enviados,
        "fallidos": fallidos,
        "skipped": skipped,
    }


# ==================== Admin: historial + stats ====================


async def listar_admin(
    db: AsyncSession,
    tipo: str | None = None,
    estado: str | None = None,
    desde=None,
    hasta=None,
    limit: int = 100,
    offset: int = 0,
) -> tuple[list[NotificationLog], int]:
    """Lista admin con filtros. Devuelve (rows, total)."""
    from app.core.notifications.models import (
        EstadoNotificacion as Estado,
        TipoNotificacion as Tipo,
    )
    from sqlalchemy import func

    base_where = []
    if tipo:
        try:
            base_where.append(NotificationLog.tipo == Tipo(tipo))
        except ValueError:
            pass
    if estado:
        try:
            base_where.append(NotificationLog.estado == Estado(estado))
        except ValueError:
            pass
    if desde:
        base_where.append(NotificationLog.creado_en >= desde)
    if hasta:
        base_where.append(NotificationLog.creado_en <= hasta)

    stmt = (
        select(NotificationLog)
        .where(*base_where)
        .order_by(NotificationLog.creado_en.desc(), NotificationLog.id.desc())
        .limit(limit)
        .offset(offset)
    )
    rows = list((await db.execute(stmt)).scalars().all())

    count_stmt = select(func.count()).select_from(NotificationLog).where(*base_where)
    total = (await db.execute(count_stmt)).scalar_one()

    return rows, total


async def stats_dashboard(db: AsyncSession, desde=None, hasta=None) -> dict:
    """Estadisticas agregadas del sistema."""
    from sqlalchemy import func, case
    from app.core.notifications.models import EstadoNotificacion as Estado

    base_where = []
    if desde:
        base_where.append(NotificationLog.creado_en >= desde)
    if hasta:
        base_where.append(NotificationLog.creado_en <= hasta)

    # Conteos por estado (una sola query)
    stmt = (
        select(
            NotificationLog.estado,
            func.count().label("count"),
        )
        .where(*base_where)
        .group_by(NotificationLog.estado)
    )
    por_estado_rows = (await db.execute(stmt)).all()
    por_estado = {row.estado.value: row.count for row in por_estado_rows}

    total = sum(por_estado.values())
    enviadas = (
        por_estado.get("enviada", 0)
        + por_estado.get("entregada", 0)
        + por_estado.get("abierta", 0)
        + por_estado.get("impresa", 0)
    )
    entregadas = por_estado.get("entregada", 0) + por_estado.get("abierta", 0) + por_estado.get("impresa", 0)
    abiertas = por_estado.get("abierta", 0)
    fallidas = por_estado.get("fallida", 0)
    skipped = por_estado.get("skipped", 0)

    delivery_rate = round(entregadas / enviadas, 4) if enviadas else 0.0
    open_rate = round(abiertas / entregadas, 4) if entregadas else 0.0

    # Conteos por tipo
    stmt = (
        select(NotificationLog.tipo, func.count().label("count"))
        .where(*base_where)
        .group_by(NotificationLog.tipo)
    )
    por_tipo = [
        {"tipo": row.tipo.value, "count": row.count}
        for row in (await db.execute(stmt)).all()
    ]

    # Top 5 por titulo (mas abiertas)
    stmt = (
        select(
            NotificationLog.titulo,
            func.count().label("total"),
            func.sum(
                case((NotificationLog.estado == Estado.ABIERTA, 1), else_=0)
            ).label("abiertas"),
        )
        .where(*base_where)
        .group_by(NotificationLog.titulo)
        .order_by(func.sum(case((NotificationLog.estado == Estado.ABIERTA, 1), else_=0)).desc())
        .limit(5)
    )
    top_5 = []
    for row in (await db.execute(stmt)).all():
        tot = row.total or 0
        ab = int(row.abiertas or 0)
        top_5.append({
            "titulo": row.titulo,
            "total": tot,
            "abiertas": ab,
            "open_rate": round(ab / tot, 4) if tot else 0.0,
        })

    return {
        "total": total,
        "enviadas": enviadas,
        "entregadas": entregadas,
        "abiertas": abiertas,
        "fallidas": fallidas,
        "skipped": skipped,
        "delivery_rate": delivery_rate,
        "open_rate": open_rate,
        "por_estado": [
            {"estado": k, "count": v} for k, v in por_estado.items()
        ],
        "por_tipo": por_tipo,
        "top_5": top_5,
    }
