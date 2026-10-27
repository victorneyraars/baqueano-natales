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


# ---------------------------- Endpoints Propietario ----------------------------
from app.modules.prestadores.models import Prestador
from app.modules.auth.models import Usuario


async def _resolver_prestador_rentacar(
    db: AsyncSession, usuario: Usuario
) -> Prestador:
    """Resuelve el prestador de rentacar del usuario logueado.
    
    Reglas:
    - El usuario debe tener al menos un prestador con categoría
      'arriendo-vehiculos' y estado verificado.
    - Si no tiene, lanzar ValueError.
    """
    from app.modules.prestadores.models import CategoriaOficio
    stmt = (
        select(Prestador)
        .join(CategoriaOficio, Prestador.categoria_id == CategoriaOficio.id)
        .where(
            Prestador.usuario_id == usuario.id,
            CategoriaOficio.slug == "arriendo-vehiculos",
        )
        .limit(1)
    )
    prestador = (await db.execute(stmt)).scalar_one_or_none()
    if prestador is None:
        raise ValueError(
            "No tienes un prestador de arriendo de vehículos registrado."
        )
    return prestador


async def listar_mis_vehiculos(
    db: AsyncSession, usuario: Usuario
) -> list[RentacarVehiculo]:
    """Lista los vehículos del prestador de rentacar del usuario."""
    prestador = await _resolver_prestador_rentacar(db, usuario)
    return await listar_vehiculos(db, prestador.id)


async def crear_mi_vehiculo(
    db: AsyncSession, usuario: Usuario, data
) -> RentacarVehiculo:
    """Crea un vehículo para el prestador del usuario logueado.
    
    Ignora el prestador_id del payload y usa el del usuario.
    """
    prestador = await _resolver_prestador_rentacar(db, usuario)
    # Sobrescribir prestador_id con el del usuario
    data_dict = data.model_dump()
    data_dict["prestador_id"] = prestador.id
    # Verificar que la patente no exista
    stmt = select(RentacarVehiculo).where(
        RentacarVehiculo.patente == data.patente
    )
    existente = (await db.execute(stmt)).scalar_one_or_none()
    if existente is not None:
        raise ValueError(f"Ya existe un vehículo con patente {data.patente}.")
    vehiculo = RentacarVehiculo(**data_dict)
    db.add(vehiculo)
    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo


async def _obtener_mi_vehiculo(
    db: AsyncSession, usuario: Usuario, vehiculo_id: UUID
) -> RentacarVehiculo:
    """Obtiene un vehículo validando que pertenece al usuario."""
    prestador = await _resolver_prestador_rentacar(db, usuario)
    stmt = select(RentacarVehiculo).where(
        RentacarVehiculo.id == vehiculo_id,
        RentacarVehiculo.prestador_id == prestador.id,
    )
    vehiculo = (await db.execute(stmt)).scalar_one_or_none()
    if vehiculo is None:
        raise ValueError("Vehículo no encontrado o no es tuyo.")
    return vehiculo


async def actualizar_mi_vehiculo(
    db: AsyncSession, usuario: Usuario, vehiculo_id: UUID, data: dict
) -> RentacarVehiculo:
    """Actualiza un vehículo validando que es del usuario."""
    vehiculo = await _obtener_mi_vehiculo(db, usuario, vehiculo_id)
    for key, value in data.items():
        if value is not None and key in {
            "patente", "marca", "modelo", "anio", "categoria",
            "precio_dia", "disponible", "imagen_url",
        }:
            setattr(vehiculo, key, value)
    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo


async def eliminar_mi_vehiculo(
    db: AsyncSession, usuario: Usuario, vehiculo_id: UUID
) -> None:
    """Elimina un vehículo validando que es del usuario."""
    vehiculo = await _obtener_mi_vehiculo(db, usuario, vehiculo_id)
    await db.delete(vehiculo)
    await db.commit()
