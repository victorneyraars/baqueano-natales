"""Endpoints admin de Rent a Car Vásquez.

Router: router_admin (requiere JWT de admin).
Prefijo final: /api/v1/admin/rentacar/...
"""
from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.core.db import DbSession
from app.modules.social.deps import AdminUser

from . import services
from .schemas import (
    RentacarReservaCreate,
    RentacarReservaOut,
    RentacarVehiculoCreate,
    RentacarVehiculoOut,
)

router_admin = APIRouter(prefix="/admin/rentacar", tags=["rentacar-admin"])


# ---------------------------- Config ----------------------------
@router_admin.get("/config/{prestador_id}")
async def obtener_config(
    prestador_id: UUID, db: DbSession, _admin: AdminUser,
):
    config = await services.get_config(db, prestador_id)
    if config is None:
        raise HTTPException(status_code=404, detail="Configuración no encontrada")
    return config


@router_admin.put("/config/{prestador_id}")
async def actualizar_config(
    prestador_id: UUID, data: dict, db: DbSession, _admin: AdminUser,
):
    config = await services.upsert_config(db, prestador_id, data)
    return config


# ---------------------------- Vehículos ----------------------------
@router_admin.get("/vehiculos", response_model=list[RentacarVehiculoOut])
async def listar_vehiculos(db: DbSession, _admin: AdminUser):
    return await services.listar_vehiculos(db)


@router_admin.get(
    "/vehiculos/{prestador_id}",
    response_model=list[RentacarVehiculoOut],
)
async def listar_vehiculos_prestador(
    prestador_id: UUID, db: DbSession, _admin: AdminUser,
):
    return await services.listar_vehiculos(db, prestador_id)


@router_admin.post(
    "/vehiculos",
    response_model=RentacarVehiculoOut,
    status_code=status.HTTP_201_CREATED,
)
async def crear_vehiculo(
    data: RentacarVehiculoCreate, db: DbSession, _admin: AdminUser,
):
    return await services.crear_vehiculo(db, data)


@router_admin.put(
    "/vehiculos/{vehiculo_id}",
    response_model=RentacarVehiculoOut,
)
async def actualizar_vehiculo(
    vehiculo_id: UUID, data: dict, db: DbSession, _admin: AdminUser,
):
    vehiculo = await services.actualizar_vehiculo(db, vehiculo_id, data)
    if vehiculo is None:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")
    return vehiculo


@router_admin.delete(
    "/vehiculos/{vehiculo_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def eliminar_vehiculo(
    vehiculo_id: UUID, db: DbSession, _admin: AdminUser,
):
    if not await services.eliminar_vehiculo(db, vehiculo_id):
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")
    return None


# ---------------------------- Reservas ----------------------------
@router_admin.get("/reservas", response_model=list[RentacarReservaOut])
async def listar_reservas(db: DbSession, _admin: AdminUser):
    return await services.listar_reservas(db)


@router_admin.post(
    "/reservas",
    response_model=RentacarReservaOut,
    status_code=status.HTTP_201_CREATED,
)
async def crear_reserva(
    data: RentacarReservaCreate, db: DbSession, _admin: AdminUser,
):
    return await services.crear_reserva(db, data)
