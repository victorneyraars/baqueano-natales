"""Lógica de negocio para Rent a Car Vásquez."""
import secrets
from datetime import datetime, timedelta, timezone
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

    # Generar OTP de 6 digitos (expira en 15 min)
    otp = f"{secrets.randbelow(1000000):06d}"
    reserva = RentacarReserva(
        **data.model_dump(),
        otp_code=otp,
        otp_expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
        otp_intentos=0,
        email_verificado=False,
    )
    db.add(reserva)
    await db.commit()
    await db.refresh(reserva)
    return reserva


async def verificar_email_reserva(
    db: AsyncSession, reserva_id: UUID, codigo: str
) -> RentacarReserva:
    """Valida el OTP y marca la reserva como email_verificado=True."""
    stmt = select(RentacarReserva).where(RentacarReserva.id == reserva_id)
    reserva = (await db.execute(stmt)).scalar_one_or_none()
    if reserva is None:
        raise ValueError("Reserva no encontrada")

    if reserva.email_verificado:
        raise ValueError("Esta reserva ya esta verificada")

    if reserva.otp_intentos >= 5:
        raise ValueError("Demasiados intentos. Pedi un nuevo codigo.")

    if reserva.otp_code is None or reserva.otp_expires_at is None:
        raise ValueError("No hay codigo pendiente. Pedi uno nuevo.")

    if datetime.now(timezone.utc) > reserva.otp_expires_at:
        raise ValueError("El codigo expiro. Pedi uno nuevo.")

    if codigo.strip() != reserva.otp_code:
        reserva.otp_intentos += 1
        await db.commit()
        remaining = 5 - reserva.otp_intentos
        raise ValueError(f"Codigo incorrecto. Intentos restantes: {remaining}")

    reserva.email_verificado = True
    reserva.email_verificado_at = datetime.now(timezone.utc)
    reserva.otp_code = None
    reserva.otp_expires_at = None
    await db.commit()
    await db.refresh(reserva)
    return reserva


async def reenviar_otp(db: AsyncSession, reserva_id: UUID) -> RentacarReserva:
    """Regenera el OTP (invalida el anterior)."""
    stmt = select(RentacarReserva).where(RentacarReserva.id == reserva_id)
    reserva = (await db.execute(stmt)).scalar_one_or_none()
    if reserva is None:
        raise ValueError("Reserva no encontrada")

    if reserva.email_verificado:
        raise ValueError("Esta reserva ya esta verificada")

    # Rate limit: ultimo envio hace menos de 60s
    if reserva.otp_expires_at is not None:
        elapsed = datetime.now(timezone.utc) - (
            reserva.otp_expires_at - timedelta(minutes=15)
        )
        if elapsed.total_seconds() < 60:
            wait = 60 - int(elapsed.total_seconds())
            raise ValueError(f"Espera {wait}s antes de pedir otro codigo")

    reserva.otp_code = f"{secrets.randbelow(1000000):06d}"
    reserva.otp_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
    reserva.otp_intentos = 0
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


# =========================================================
# Reservas propietario
# =========================================================
ESTADOS_VALIDOS = {"pendiente", "confirmada", "en_curso", "completada", "cancelada"}

TRANSICIONES_VALIDAS = {
    "pendiente": {"confirmada", "cancelada"},
    "confirmada": {"en_curso", "cancelada"},
    "en_curso": {"completada"},
    "completada": set(),
    "cancelada": set(),
}


async def listar_mis_reservas(
    db: AsyncSession, usuario: Usuario, estado: str | None = None
) -> list[RentacarReserva]:
    """Lista reservas del prestador del usuario, con filtro opcional por estado."""
    prestador = await _resolver_prestador_rentacar(db, usuario)
    stmt = (
        select(RentacarReserva)
        .join(RentacarVehiculo, RentacarVehiculo.id == RentacarReserva.vehiculo_id)
        .where(RentacarVehiculo.prestador_id == prestador.id)
        .order_by(RentacarReserva.created_at.desc())
    )
    if estado is not None:
        if estado not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado invalido: {estado}")
        stmt = stmt.where(RentacarReserva.estado == estado)
    return list((await db.execute(stmt)).scalars().all())


async def _obtener_mi_reserva(
    db: AsyncSession, usuario: Usuario, reserva_id: UUID
) -> RentacarReserva:
    """Obtiene una reserva validando que pertenece al prestador del usuario."""
    prestador = await _resolver_prestador_rentacar(db, usuario)
    stmt = (
        select(RentacarReserva)
        .join(RentacarVehiculo, RentacarVehiculo.id == RentacarReserva.vehiculo_id)
        .where(
            RentacarReserva.id == reserva_id,
            RentacarVehiculo.prestador_id == prestador.id,
        )
    )
    reserva = (await db.execute(stmt)).scalar_one_or_none()
    if reserva is None:
        raise ValueError("Reserva no encontrada o no es tuya.")
    return reserva


async def cambiar_estado_reserva(
    db: AsyncSession, usuario: Usuario, reserva_id: UUID, nuevo_estado: str
) -> RentacarReserva:
    """Cambia el estado de una reserva validando transiciones."""
    if nuevo_estado not in ESTADOS_VALIDOS:
        raise ValueError(f"Estado invalido: {nuevo_estado}")

    reserva = await _obtener_mi_reserva(db, usuario, reserva_id)
    transiciones = TRANSICIONES_VALIDAS.get(reserva.estado, set())

    if nuevo_estado not in transiciones:
        raise ValueError(
            f"Transicion invalida: {reserva.estado} -> {nuevo_estado}. "
            f"Permitidos desde {reserva.estado}: {sorted(transiciones) or 'ninguno'}"
        )

    reserva.estado = nuevo_estado
    await db.commit()
    await db.refresh(reserva)
    return reserva


# =========================================================
# Config propietario
# =========================================================
async def obtener_mi_config(
    db: AsyncSession, usuario: Usuario
) -> RentacarConfig:
    """Obtiene la config del prestador del usuario. Crea una por defecto si no existe."""
    prestador = await _resolver_prestador_rentacar(db, usuario)
    config = await get_config(db, prestador.id)
    if config is None:
        config = RentacarConfig(
            prestador_id=prestador.id,
            metodos_pago={"efectivo": True, "transferencia": True},
            deposito={"tipo": "porcentaje", "valor": 20, "monto_fijo": 0},
            conductor_adicional={"habilitado": True, "tarifa_por_dia": 5000},
            categorias=[
                {"codigo": "SUV", "nombre": "SUV"},
                {"codigo": "SEDAN", "nombre": "Sedán"},
                {"codigo": "PICKUP", "nombre": "Pickup"},
                {"codigo": "FURGONETA", "nombre": "Furgoneta"},
            ],
        )
        db.add(config)
        await db.commit()
        await db.refresh(config)
    return config


async def actualizar_mi_config(
    db: AsyncSession, usuario: Usuario, data: dict
) -> RentacarConfig:
    """Actualiza la config del prestador."""
    prestador = await _resolver_prestador_rentacar(db, usuario)
    return await upsert_config(db, prestador.id, data)


# =========================================================
# Stats dashboard
# =========================================================
async def obtener_mis_stats(
    db: AsyncSession, usuario: Usuario
) -> dict:
    """Dashboard: contadores de vehiculos, reservas e ingresos."""
    from datetime import datetime, timezone
    from sqlalchemy import func

    prestador = await _resolver_prestador_rentacar(db, usuario)

    # Vehiculos
    vehiculos_total = await db.scalar(
        select(func.count(RentacarVehiculo.id))
        .where(RentacarVehiculo.prestador_id == prestador.id)
    ) or 0
    vehiculos_disponibles = await db.scalar(
        select(func.count(RentacarVehiculo.id))
        .where(
            RentacarVehiculo.prestador_id == prestador.id,
            RentacarVehiculo.disponible.is_(True),
        )
    ) or 0

    # Reservas por estado
    reservas_por_estado = {}
    for estado in ESTADOS_VALIDOS:
        count = await db.scalar(
            select(func.count(RentacarReserva.id))
            .join(RentacarVehiculo, RentacarVehiculo.id == RentacarReserva.vehiculo_id)
            .where(
                RentacarVehiculo.prestador_id == prestador.id,
                RentacarReserva.estado == estado,
            )
        ) or 0
        reservas_por_estado[estado] = count

    reservas_total = sum(reservas_por_estado.values())

    # Ingresos (reservas completadas)
    ingresos_totales = float(
        await db.scalar(
            select(func.coalesce(func.sum(RentacarReserva.precio_total), 0))
            .join(RentacarVehiculo, RentacarVehiculo.id == RentacarReserva.vehiculo_id)
            .where(
                RentacarVehiculo.prestador_id == prestador.id,
                RentacarReserva.estado == "completada",
            )
        ) or 0
    )

    # Ingresos mes actual
    now = datetime.now(timezone.utc)
    inicio_mes = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    ingresos_mes_actual = float(
        await db.scalar(
            select(func.coalesce(func.sum(RentacarReserva.precio_total), 0))
            .join(RentacarVehiculo, RentacarVehiculo.id == RentacarReserva.vehiculo_id)
            .where(
                RentacarVehiculo.prestador_id == prestador.id,
                RentacarReserva.estado == "completada",
                RentacarReserva.fecha_inicio >= inicio_mes,
            )
        ) or 0
    )

    return {
        "vehiculos_total": vehiculos_total,
        "vehiculos_disponibles": vehiculos_disponibles,
        "reservas_total": reservas_total,
        "reservas_pendientes": reservas_por_estado["pendiente"],
        "reservas_confirmadas": reservas_por_estado["confirmada"],
        "reservas_en_curso": reservas_por_estado["en_curso"],
        "reservas_completadas": reservas_por_estado["completada"],
        "reservas_canceladas": reservas_por_estado["cancelada"],
        "ingresos_totales": ingresos_totales,
        "ingresos_mes_actual": ingresos_mes_actual,
    }


async def confirmar_reserva(
    db: AsyncSession, reserva_id: UUID
) -> RentacarReserva:
    """Cambia estado 'pendiente' -> 'confirmada'."""
    from sqlalchemy import select
    stmt = select(RentacarReserva).where(RentacarReserva.id == reserva_id)
    reserva = (await db.execute(stmt)).scalar_one_or_none()
    if reserva is None:
        raise ValueError("Reserva no encontrada")
    if reserva.estado != "pendiente":
        raise ValueError(f"Reserva en estado '{reserva.estado}', no se puede confirmar")
    reserva.estado = "confirmada"
    await db.commit()
    await db.refresh(reserva)
    return reserva


async def cancelar_reserva(
    db: AsyncSession, reserva_id: UUID
) -> RentacarReserva:
    """Cambia estado 'pendiente' -> 'cancelada'."""
    from sqlalchemy import select
    stmt = select(RentacarReserva).where(RentacarReserva.id == reserva_id)
    reserva = (await db.execute(stmt)).scalar_one_or_none()
    if reserva is None:
        raise ValueError("Reserva no encontrada")
    if reserva.estado != "pendiente":
        raise ValueError(f"Reserva en estado '{reserva.estado}', no se puede cancelar")
    reserva.estado = "cancelada"
    await db.commit()
    await db.refresh(reserva)
    return reserva
