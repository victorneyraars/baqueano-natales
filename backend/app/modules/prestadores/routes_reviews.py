"""Endpoints HTTP de reviews (M6).

Routers:
- /mis-ordenes/{oid}/review       (cliente crea/lee su review)
- /mis-prestadores/{pid}/reviews/{rid}/respuesta (prestador responde)
- /prestadores/{slug}/reviews     (publico: listado paginado)
"""
import logging
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select

from app.core.db import DbSession
from app.modules.auth.deps import CurrentUser
from app.modules.prestadores import services_reviews
from app.modules.prestadores.models import Prestador
from app.modules.prestadores.schemas_reviews import (
    ReviewCreate,
    ReviewPublicaListResponse,
    ReviewResponderRequest,
    ReviewResponse,
)

logger = logging.getLogger(__name__)


router_reviews_cliente = APIRouter(
    prefix="/mis-ordenes",
    tags=["reviews-cliente"],
)
router_reviews_prestador = APIRouter(
    prefix="/mis-prestadores",
    tags=["reviews-prestador"],
)
router_reviews_publico = APIRouter(
    prefix="/prestadores",
    tags=["reviews-publico"],
)


# =========================================================
# CLIENTE
# =========================================================
@router_reviews_cliente.post(
    "/{orden_id}/review",
    response_model=ReviewResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Calificar una orden entregada",
)
async def crear_review_endpoint(
    orden_id: UUID,
    data: ReviewCreate,
    user: CurrentUser,
    db: DbSession,
):
    review = await services_reviews.crear_review(
        db, user, orden_id, data,
    )
    return ReviewResponse.model_validate(review)


@router_reviews_cliente.get(
    "/{orden_id}/review",
    response_model=ReviewResponse | None,
    summary="Ver mi review de la orden (o null si no existe)",
)
async def obtener_mi_review_endpoint(
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    review = await services_reviews.obtener_review_de_orden(
        db, user, orden_id,
    )
    if review is None:
        return None
    return ReviewResponse.model_validate(review)


# =========================================================
# PRESTADOR
# =========================================================
@router_reviews_prestador.post(
    "/{prestador_id}/reviews/{review_id}/respuesta",
    response_model=ReviewResponse,
    summary="Responder una review (una sola vez)",
)
async def responder_review_endpoint(
    prestador_id: UUID,
    review_id: UUID,
    data: ReviewResponderRequest,
    user: CurrentUser,
    db: DbSession,
):
    # Validar que la review pertenece al prestador del path
    from app.modules.prestadores import services_reviews as _sr

    review = await _sr.responder_review(db, user, review_id, data.respuesta)
    if review.prestador_id != prestador_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Review no pertenece a este prestador",
        )
    return ReviewResponse.model_validate(review)


# =========================================================
# PUBLICO
# =========================================================
@router_reviews_publico.get(
    "/{slug}/reviews",
    response_model=ReviewPublicaListResponse,
    summary="Listar reviews publicas de un prestador",
)
async def listar_reviews_publicas_endpoint(
    slug: str,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
):
    prestador = (
        await db.execute(
            select(Prestador).where(
                Prestador.slug == slug,
                Prestador.activo.is_(True),
            )
        )
    ).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prestador no encontrado",
        )

    data = await services_reviews.listar_reviews_publicas(
        db, prestador.id, page=page, page_size=page_size,
    )
    return data
