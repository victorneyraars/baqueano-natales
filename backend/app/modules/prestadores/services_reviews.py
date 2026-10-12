"""Services de reviews (M6).

Recalcula los denormalizados `calificacion_promedio` + `total_resenas`
del Prestador en cada create/update/delete.
"""
import logging
from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import RolUsuario, Usuario
from app.modules.oficios.models import EstadoOrden, OrdenTrabajo
from app.modules.prestadores.models import Prestador, Review
from app.modules.prestadores.schemas_reviews import ReviewCreate

logger = logging.getLogger(__name__)


# =========================================================
# Helpers
# =========================================================
async def _recalcular_stats_prestador(
    db: AsyncSession, prestador_id: UUID
) -> None:
    """Recalcula calificacion_promedio + total_resenas del prestador.

    Solo cuenta reviews ACTIVAS.
    """
    stmt = select(
        func.count(Review.id),
        func.avg(Review.rating),
    ).where(
        Review.prestador_id == prestador_id,
        Review.activo.is_(True),
    )
    count, avg = (await db.execute(stmt)).one()
    count = count or 0
    prom = Decimal(str(round(float(avg), 2))) if avg is not None else Decimal("0.00")

    prestador = (
        await db.execute(
            select(Prestador).where(Prestador.id == prestador_id)
        )
    ).scalar_one()
    prestador.total_resenas = count
    prestador.calificacion_promedio = prom
    await db.flush()


async def _cargar_orden_y_validar_ownership(
    db: AsyncSession, orden_id: UUID, usuario: Usuario
) -> OrdenTrabajo:
    """Carga la orden y valida que el usuario sea el cliente dueno."""
    orden = (
        await db.execute(
            select(OrdenTrabajo).where(OrdenTrabajo.id == orden_id)
        )
    ).scalar_one_or_none()
    if orden is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Orden no encontrada",
        )
    if usuario.rol != RolUsuario.ADMIN and orden.cliente_id != usuario.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el cliente de la orden puede calificar",
        )
    return orden


# =========================================================
# API publica
# =========================================================
async def crear_review(
    db: AsyncSession,
    usuario: Usuario,
    orden_id: UUID,
    data: ReviewCreate,
) -> Review:
    """Cliente crea una review para una orden entregada.

    Validaciones:
    - Orden existe y el usuario es el cliente (o admin).
    - Orden en estado ENTREGADO (o GARANTIA).
    - No existe ya una review para esa orden.
    """
    orden = await _cargar_orden_y_validar_ownership(db, orden_id, usuario)

    if orden.estado not in (EstadoOrden.ENTREGADO, EstadoOrden.GARANTIA):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Solo se puede calificar cuando la orden esta entregada. "
                f"Estado actual: {orden.estado.value}"
            ),
        )

    # Una sola review por orden
    existente = (
        await db.execute(
            select(Review).where(Review.orden_id == orden_id)
        )
    ).scalar_one_or_none()
    if existente is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Esta orden ya tiene una review",
        )

    review = Review(
        prestador_id=orden.prestador_id,
        cliente_id=orden.cliente_id,
        orden_id=orden.id,
        rating=data.rating,
        comentario=data.comentario,
    )
    db.add(review)
    await db.flush()
    await _recalcular_stats_prestador(db, orden.prestador_id)
    await db.commit()
    await db.refresh(review)

    # Notificar al prestador (best-effort)
    try:
        from app.core.notifications.models import TipoNotificacion
        from app.core.notifications.service import NotificationService

        prestador = (
            await db.execute(
                select(Prestador).where(Prestador.id == orden.prestador_id)
            )
        ).scalar_one()
        service = NotificationService()
        await service.enviar_in_app(
            db=db,
            usuario_id=prestador.usuario_id,
            titulo=f"Nueva resena en {prestador.nombre}",
            body=f"Recibiste {data.rating} estrellas en la orden {orden.numero}.",
            tipo=TipoNotificacion.CAMPANA,
            data={
                "tipo": "review",
                "prestador_id": str(prestador.id),
                "review_id": str(review.id),
                "rating": data.rating,
            },
        )
        await db.commit()
    except Exception:
        logger.exception("Error enviando notif de review")

    return review


async def obtener_review_de_orden(
    db: AsyncSession, usuario: Usuario, orden_id: UUID
) -> Review | None:
    """Devuelve la review de la orden (si existe) si el user tiene permiso."""
    await _cargar_orden_y_validar_ownership(db, orden_id, usuario)
    return (
        await db.execute(
            select(Review).where(Review.orden_id == orden_id)
        )
    ).scalar_one_or_none()


async def responder_review(
    db: AsyncSession,
    usuario: Usuario,
    review_id: UUID,
    respuesta: str,
) -> Review:
    """Prestador responde una review (una sola vez)."""
    review = (
        await db.execute(
            select(Review).where(
                Review.id == review_id,
                Review.activo.is_(True),
            )
        )
    ).scalar_one_or_none()
    if review is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Review no encontrada",
        )

    # Validar ownership: usuario dueno del prestador o admin
    prestador = (
        await db.execute(
            select(Prestador).where(Prestador.id == review.prestador_id)
        )
    ).scalar_one()
    if usuario.rol != RolUsuario.ADMIN and prestador.usuario_id != usuario.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso sobre esta review",
        )

    if review.respuesta_prestador is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Esta review ya tiene una respuesta",
        )

    review.respuesta_prestador = respuesta
    review.respuesta_en = datetime.now(timezone.utc)
    await db.flush()
    await db.commit()
    await db.refresh(review)
    return review


async def listar_reviews_publicas(
    db: AsyncSession,
    prestador_id: UUID,
    page: int = 1,
    page_size: int = 20,
) -> dict:
    """Listado publico paginado de reviews activas de un prestador."""
    offset = (page - 1) * page_size
    base = [
        Review.prestador_id == prestador_id,
        Review.activo.is_(True),
    ]

    total = (
        await db.execute(
            select(func.count(Review.id)).where(*base)
        )
    ).scalar_one()
    avg = (
        await db.execute(
            select(func.avg(Review.rating)).where(*base)
        )
    ).scalar_one()
    promedio = round(float(avg), 2) if avg is not None else 0.0

    stmt = (
        select(Review, Usuario.nombre, Usuario.apellido)
        .join(Usuario, Usuario.id == Review.cliente_id)
        .where(*base)
        .order_by(Review.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    rows = (await db.execute(stmt)).all()

    items = []
    for review, nombre, apellido in rows:
        nombre_completo = " ".join(p for p in [nombre, apellido] if p) or None
        # Solo primer nombre + inicial para privacidad
        if nombre_completo:
            partes = nombre_completo.split()
            if len(partes) >= 2:
                nombre_completo = f"{partes[0]} {partes[-1][0]}."
            else:
                nombre_completo = partes[0]
        items.append({
            "id": review.id,
            "cliente_nombre": nombre_completo,
            "rating": review.rating,
            "comentario": review.comentario,
            "respuesta_prestador": review.respuesta_prestador,
            "respuesta_en": review.respuesta_en,
            "created_at": review.created_at,
        })

    return {
        "items": items,
        "total": int(total),
        "promedio": promedio,
        "page": page,
        "page_size": page_size,
    }
