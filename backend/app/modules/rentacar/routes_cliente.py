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
    """Obtiene el detalle completo de una reserva con sus inspecciones (fotos, firmas)."""
    reserva = await services.obtener_detalle_reserva_cliente(db, reserva_id, user.id)
    if not reserva:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Reserva no encontrada o no tienes permiso para verla")
    return reserva
