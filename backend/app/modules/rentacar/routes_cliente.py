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
