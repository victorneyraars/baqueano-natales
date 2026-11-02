"""Lógica de negocio para Rent a Car Vásquez."""
import secrets
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .models import RentacarBloqueo, RentacarConfig, RentacarReserva, RentacarVehiculo
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
    """Crea una reserva publica en una sola transaccion.

    1. INSERT reserva (con OTP).
    2. INSERT bloqueo tipo=reserva con daterange [inicio, fin).
    La constraint EXCLUDE USING gist en rentacar_bloqueos impide
    doble-booking a nivel motor. Si falla, todo revierte -> 409.
    """
    vehiculo = await get_vehiculo(db, data.vehiculo_id)
    if vehiculo is None:
        raise ValueError("Vehiculo no encontrado")
    if not vehiculo.disponible:
        raise ValueError("Vehiculo no disponible")

    if data.fecha_fin <= data.fecha_inicio:
        raise ValueError("Fecha de fin debe ser posterior a fecha de inicio")

    otp = f"{secrets.randbelow(1000000):06d}"
    reserva = RentacarReserva(
        **data.model_dump(),
        otp_code=otp,
        otp_expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
        otp_intentos=0,
        email_verificado=False,
    )
    db.add(reserva)
    await db.flush()  # obtener reserva.id sin commit

    # Rango del bloqueo: al menos 1 dia, fin inclusivo -> [inicio, max(fin, inicio+1))
    fin_date = data.fecha_fin.date()
    ini_date = data.fecha_inicio.date()
    if fin_date <= ini_date:
        fin_date = ini_date + timedelta(days=1)
    bloqueo = RentacarBloqueo(
        vehiculo_id=vehiculo.id,
        reserva_id=reserva.id,
        fecha_inicio=ini_date,
        fecha_fin=fin_date,
        tipo="reserva",
    )
    db.add(bloqueo)
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        if "no_solapamiento" in str(getattr(exc, "orig", exc)):
            raise ValueError(
                "El vehiculo ya tiene una reserva o bloqueo en ese rango de fechas"
            )
        raise
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
    from sqlalchemy import text as sql_text, or_
    stmt = (
        select(Prestador)
        .join(CategoriaOficio, Prestador.categoria_id == CategoriaOficio.id)
        .where(
            or_(
                Prestador.usuario_id == usuario.id,
                sql_text(
                    "EXISTS ("
                    "  SELECT 1 FROM jsonb_array_elements(COALESCE(prestadores.colaboradores, '[]'::jsonb)) AS c "
                    "  WHERE c->>'email' = :email "
                    "  AND c->>'activado_at' IS NOT NULL"
                    ")"
                ).bindparams(email=usuario.email or ""),
            ),
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
    db: AsyncSession,
    usuario: Usuario,
    estado: str | None = None,
    busqueda: str | None = None,
    fecha_desde: str | None = None,
    fecha_hasta: str | None = None,
    vehiculo_id: UUID | None = None,
) -> list[RentacarReserva]:
    """Lista reservas del prestador con filtros avanzados."""
    from datetime import datetime
    from sqlalchemy import or_, func as sqlfunc

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
    if vehiculo_id is not None:
        stmt = stmt.where(RentacarReserva.vehiculo_id == vehiculo_id)
    if busqueda:
        like = f"%{busqueda.lower()}%"
        stmt = stmt.where(
            or_(
                sqlfunc.lower(RentacarReserva.nombre_cliente).like(like),
                sqlfunc.lower(RentacarReserva.email_cliente).like(like),
                sqlfunc.lower(RentacarVehiculo.patente).like(like),
                sqlfunc.lower(RentacarVehiculo.marca).like(like),
                sqlfunc.lower(RentacarVehiculo.modelo).like(like),
            )
        )
    if fecha_desde:
        try:
            fd = datetime.fromisoformat(fecha_desde)
            stmt = stmt.where(RentacarReserva.fecha_inicio >= fd)
        except ValueError:
            pass
    if fecha_hasta:
        try:
            fh = datetime.fromisoformat(fecha_hasta)
            stmt = stmt.where(RentacarReserva.fecha_fin <= fh)
        except ValueError:
            pass
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
    """Cambia el estado de una reserva validando transiciones.

    Si el nuevo estado es 'cancelada', libera el bloqueo asociado.
    """
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
    if nuevo_estado == "cancelada":
        await db.execute(
            delete(RentacarBloqueo).where(RentacarBloqueo.reserva_id == reserva_id)
        )
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
    """Cambia estado 'pendiente' -> 'cancelada' y libera el bloqueo."""
    from sqlalchemy import select, delete
    stmt = select(RentacarReserva).where(RentacarReserva.id == reserva_id)
    reserva = (await db.execute(stmt)).scalar_one_or_none()
    if reserva is None:
        raise ValueError("Reserva no encontrada")
    if reserva.estado != "pendiente":
        raise ValueError(f"Reserva en estado '{reserva.estado}', no se puede cancelar")
    reserva.estado = "cancelada"
    # Liberar bloqueo asociado
    await db.execute(
        delete(RentacarBloqueo).where(RentacarBloqueo.reserva_id == reserva_id)
    )
    await db.commit()
    await db.refresh(reserva)
    return reserva


# =========================================================
# Disponibilidad y bloqueos
# =========================================================
async def verificar_disponibilidad(
    db: AsyncSession, vehiculo_id: UUID, desde: date, hasta: date
) -> bool:
    """True si el vehiculo NO tiene ningun bloqueo que solape [desde, hasta)."""
    if hasta <= desde:
        raise ValueError("Fecha hasta debe ser posterior a desde")
    stmt = (
        select(RentacarBloqueo.id)
        .where(
            RentacarBloqueo.vehiculo_id == vehiculo_id,
            RentacarBloqueo.fecha_inicio < hasta,
            RentacarBloqueo.fecha_fin > desde,
        )
        .limit(1)
    )
    return (await db.execute(stmt)).scalar_one_or_none() is None


async def listar_disponibles(
    db: AsyncSession, desde: date, hasta: date, prestador_id: UUID | None = None
) -> list[RentacarVehiculo]:
    """Vehiculos disponibles en [desde, hasta). Excluye los que tienen solapamiento."""
    if hasta <= desde:
        raise ValueError("Fecha hasta debe ser posterior a desde")
    stmt = (
        select(RentacarVehiculo)
        .where(RentacarVehiculo.disponible.is_(True))
        .where(
            ~RentacarVehiculo.id.in_(
                select(RentacarBloqueo.vehiculo_id).where(
                    RentacarBloqueo.fecha_inicio < hasta,
                    RentacarBloqueo.fecha_fin > desde,
                )
            )
        )
        .order_by(RentacarVehiculo.created_at.desc())
    )
    if prestador_id is not None:
        stmt = stmt.where(RentacarVehiculo.prestador_id == prestador_id)
    return list((await db.execute(stmt)).scalars().all())


async def crear_bloqueo(
    db: AsyncSession,
    vehiculo_id: UUID,
    fecha_inicio: date,
    fecha_fin: date,
    tipo: str = "manual",
    motivo: str | None = None,
    created_by: UUID | None = None,
    reserva_id: UUID | None = None,
) -> RentacarBloqueo:
    """Crea un bloqueo (mantenimiento o manual). Falla con ValueError si solapa."""
    if tipo not in ("manual", "mantenimiento", "reserva"):
        raise ValueError(f"Tipo invalido: {tipo}")
    if fecha_fin <= fecha_inicio:
        raise ValueError("fecha_fin debe ser posterior a fecha_inicio")
    bloqueo = RentacarBloqueo(
        vehiculo_id=vehiculo_id,
        reserva_id=reserva_id,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        tipo=tipo,
        motivo=motivo,
        created_by=created_by,
    )
    db.add(bloqueo)
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        if "no_solapamiento" in str(getattr(exc, "orig", exc)):
            raise ValueError(
                "El vehiculo ya tiene una reserva o bloqueo en ese rango de fechas"
            )
        raise
    await db.refresh(bloqueo)
    return bloqueo


async def eliminar_bloqueo(db: AsyncSession, bloqueo_id: UUID) -> None:
    """Elimina un bloqueo. No permite borrar bloqueos tipo=reserva."""
    bloqueo = await db.get(RentacarBloqueo, bloqueo_id)
    if bloqueo is None:
        raise ValueError("Bloqueo no encontrado")
    if bloqueo.tipo == "reserva":
        raise ValueError("No se puede borrar un bloqueo de reserva (cancelar la reserva)")
    await db.delete(bloqueo)
    await db.commit()


async def listar_bloqueos(
    db: AsyncSession, vehiculo_id: UUID, desde: date, hasta: date
) -> list[RentacarBloqueo]:
    """Lista bloqueos del vehiculo en el rango (para calendario admin)."""
    stmt = (
        select(RentacarBloqueo)
        .where(
            RentacarBloqueo.vehiculo_id == vehiculo_id,
            RentacarBloqueo.fecha_inicio < hasta,
            RentacarBloqueo.fecha_fin > desde,
        )
        .order_by(RentacarBloqueo.fecha_inicio)
    )
    return list((await db.execute(stmt)).scalars().all())


# =========================================================
# Reservas desde panel del prestador (walk-in / WhatsApp)
# =========================================================
async def crear_reserva_propietario(
    db: AsyncSession, usuario: Usuario, data
) -> RentacarReserva:
    """Crear reserva desde el panel (sin OTP, walk-in friendly).

    - Valida que el vehiculo sea del prestador del usuario.
    - Crea reserva + bloqueo en la misma transaccion.
    - Estado default = confirmada (walk-in ya reservado en el momento).
    - Sin OTP: no manda email de verificacion.
    """
    # Validar que el vehiculo es del prestador
    vehiculo = await _obtener_mi_vehiculo(db, usuario, data.vehiculo_id)
    if not vehiculo.disponible:
        raise ValueError("Vehiculo marcado como no disponible")
    if data.fecha_fin <= data.fecha_inicio:
        raise ValueError("Fecha de fin debe ser posterior a fecha de inicio")
    if data.estado not in {"pendiente", "confirmada"}:
        raise ValueError("Estado inicial invalido (debe ser pendiente o confirmada)")

    reserva = RentacarReserva(
        vehiculo_id=data.vehiculo_id,
        fecha_inicio=data.fecha_inicio,
        fecha_fin=data.fecha_fin,
        metodo_pago=data.metodo_pago,
        precio_total=data.precio_total,
        nombre_cliente=data.nombre_cliente,
        email_cliente=data.email_cliente,
        telefono_cliente=data.telefono_cliente,
        estado=data.estado,
        email_verificado=True,  # creada por el prestador, no requiere OTP
    )
    db.add(reserva)
    await db.flush()

    fin_date = data.fecha_fin.date()
    ini_date = data.fecha_inicio.date()
    if fin_date <= ini_date:
        fin_date = ini_date + timedelta(days=1)
    bloqueo = RentacarBloqueo(
        vehiculo_id=data.vehiculo_id,
        reserva_id=reserva.id,
        fecha_inicio=ini_date,
        fecha_fin=fin_date,
        tipo="reserva",
    )
    db.add(bloqueo)
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        if "no_solapamiento" in str(getattr(exc, "orig", exc)):
            raise ValueError(
                "El vehiculo ya tiene una reserva o bloqueo en ese rango de fechas"
            )
        raise
    await db.refresh(reserva)
    return reserva


async def modificar_reserva(
    db: AsyncSession, usuario: Usuario, reserva_id: UUID, data
) -> RentacarReserva:
    """Modificar fechas y/o precio de una reserva existente.

    - Solo reservas en estado pendiente o confirmada.
    - Mueve el bloqueo asociado en la misma transaccion.
    - Si hay solapamiento con otro bloqueo -> 409.
    """
    reserva = await _obtener_mi_reserva(db, usuario, reserva_id)
    if reserva.estado not in {"pendiente", "confirmada"}:
        raise ValueError(
            f"No se puede modificar una reserva en estado '{reserva.estado}'"
        )

    nueva_ini = data.fecha_inicio or reserva.fecha_inicio
    nueva_fin = data.fecha_fin or reserva.fecha_fin
    if nueva_fin <= nueva_ini:
        raise ValueError("Fecha de fin debe ser posterior a fecha de inicio")

    # Actualizar reserva
    reserva.fecha_inicio = nueva_ini
    reserva.fecha_fin = nueva_fin
    if data.precio_total is not None:
        reserva.precio_total = data.precio_total

    # Actualizar bloqueo asociado (mover rango)
    fin_date = nueva_fin.date()
    ini_date = nueva_ini.date()
    if fin_date <= ini_date:
        fin_date = ini_date + timedelta(days=1)

    stmt = select(RentacarBloqueo).where(
        RentacarBloqueo.reserva_id == reserva_id
    )
    bloqueo = (await db.execute(stmt)).scalar_one_or_none()
    if bloqueo is not None:
        bloqueo.fecha_inicio = ini_date
        bloqueo.fecha_fin = fin_date
    else:
        # Caso borde: bloqueo inexistente, crearlo
        bloqueo = RentacarBloqueo(
            vehiculo_id=reserva.vehiculo_id,
            reserva_id=reserva.id,
            fecha_inicio=ini_date,
            fecha_fin=fin_date,
            tipo="reserva",
        )
        db.add(bloqueo)

    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        if "no_solapamiento" in str(getattr(exc, "orig", exc)):
            raise ValueError(
                "El vehiculo ya tiene una reserva o bloqueo en ese rango de fechas"
            )
        raise
    await db.refresh(reserva)
    return reserva
