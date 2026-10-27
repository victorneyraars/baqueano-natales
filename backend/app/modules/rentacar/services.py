"""Lógica de negocio para Rent a Car Vásquez."""
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import RentacarConfig, RentacarReserva, RentacarVehiculo
from .schemas import RentacarReservaCreate, RentacarVehiculoCreate


# ---------------------------- Config ----------------------------
async def get_config(db: AsyncSession, prestador_id: UUID) -> RentacarConfig | None:
    stmt = select(RentacarConfig).where(RentacarConfig.prestador_id == prestador_id)
    return (await db.execute(stmt)).scalar_one_or_none()


async def upsert_config(
    db: AsyncSession, prestador_id: UUID, data: dict
) -> RentacarConfig:
    config = await get_config(db, prestador_id)
    if config is None:
        config = RentacarConfig(prestador_id=prestador_id, **data)
        db.add(config)
    else:
        for key, value in data.items():
            setattr(config, key, value)
    await db.commit()
    await db.refresh(config)
    return config


# ---------------------------- Vehículos ----------------------------
async def listar_vehiculos(
    db: AsyncSession, prestador_id: UUID | None = None
) -> list[RentacarVehiculo]:
    stmt = select(RentacarVehiculo).order_by(RentacarVehiculo.created_at.desc())
    if prestador_id is not None:
        stmt = stmt.where(RentacarVehiculo.prestador_id == prestador_id)
    return list((await db.execute(stmt)).scalars().all())


async def crear_vehiculo(
    db: AsyncSession, data: RentacarVehiculoCreate
) -> RentacarVehiculo:
    vehiculo = RentacarVehiculo(**data.model_dump())
    db.add(vehiculo)
    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo


async def get_vehiculo(db: AsyncSession, vehiculo_id: UUID) -> RentacarVehiculo | None:
    return await db.get(RentacarVehiculo, vehiculo_id)


async def actualizar_vehiculo(
    db: AsyncSession, vehiculo_id: UUID, data: dict
) -> RentacarVehiculo | None:
    vehiculo = await get_vehiculo(db, vehiculo_id)
    if vehiculo is None:
        return None
    for key, value in data.items():
        if value is not None:
            setattr(vehiculo, key, value)
    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo


async def eliminar_vehiculo(db: AsyncSession, vehiculo_id: UUID) -> bool:
    vehiculo = await get_vehiculo(db, vehiculo_id)
    if vehiculo is None:
        return False
    await db.delete(vehiculo)
    await db.commit()
    return True


# ---------------------------- Reservas ----------------------------
async def listar_reservas(
    db: AsyncSession, cliente_id: UUID | None = None
) -> list[RentacarReserva]:
    stmt = select(RentacarReserva).order_by(RentacarReserva.created_at.desc())
    if cliente_id is not None:
        stmt = stmt.where(RentacarReserva.cliente_id == cliente_id)
    return list((await db.execute(stmt)).scalars().all())


async def crear_reserva(
    db: AsyncSession, data: RentacarReservaCreate
) -> RentacarReserva:
    """Crea una reserva pública. Valida disponibilidad y fechas."""
    vehiculo = await get_vehiculo(db, data.vehiculo_id)
    if vehiculo is None:
        raise ValueError("Vehiculo no encontrado")
    if not vehiculo.disponible:
        raise ValueError("Vehiculo no disponible")

    if data.fecha_fin <= data.fecha_inicio:
        raise ValueError("Fecha de fin debe ser posterior a fecha de inicio")

    reserva = RentacarReserva(**data.model_dump())
    db.add(reserva)
    await db.commit()
    await db.refresh(reserva)
    return reserva
