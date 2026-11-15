from uuid import UUID
from fastapi import APIRouter
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.deps import CurrentUser
from app.core.db import DbSession
from app.modules.rentacar import services, schemas

router_cliente = APIRouter(prefix="/mis-reservas", tags=["rentacar-cliente"])

@router_cliente.get("", response_model=list[schemas.RentacarReservaOut])
async def mis_reservas(db: DbSession, user: CurrentUser):
    """Obtiene las reservas de Rent a Car del cliente logueado."""
    return await services.listar_reservas_cliente(db, user.id)


@router_cliente.get("/{reserva_id}", response_model=schemas.RentacarReservaDetalleOut)
async def detalle_reserva(reserva_id: UUID, db: DbSession, user: CurrentUser):
    """Obtiene el detalle completo de una reserva con sus inspecciones y contrato."""
    reserva = await services.obtener_detalle_reserva_cliente(db, reserva_id, user.id)
    if not reserva:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Reserva no encontrada o no tienes permiso para verla")

    # Buscar contrato asociado
    try:
        from app.modules.documents.services import obtener_contrato_por_reserva
        contrato = await obtener_contrato_por_reserva(db, reserva_id)
        if contrato:
            reserva.contrato = {
                "token": contrato.token,
                "estado": contrato.estado,
                "firmado_at": contrato.firmado_at.isoformat() if contrato.firmado_at else None,
                "pdf_url": f"/api/v1/documents/{contrato.token}/pdf",
                "url_firma": f"https://rentacarvasquez.com/firmar/{contrato.token}",
            }
        else:
            reserva.contrato = None
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"Error buscando contrato: {e}")
        reserva.contrato = None

    # Verificar si el cliente ya dejó review
    try:
        from app.modules.prestadores.models import Review
        from sqlalchemy import select
        stmt = select(Review).where(
            Review.entidad_tipo == "reserva",
            Review.entidad_id == reserva_id,
            Review.cliente_id == user.id,
        )
        review_existente = (await db.execute(stmt)).scalar_one_or_none()
        reserva.tiene_review = review_existente is not None
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"Error buscando review: {e}")
        reserva.tiene_review = False

    return reserva
