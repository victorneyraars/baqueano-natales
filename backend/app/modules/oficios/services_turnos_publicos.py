"""Servicios para solicitudes de turno via landing publica."""
import logging
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import (
    EstadoTurno, ObjetoServicio, TipoObjetoServicio, TipoVehiculo,
    Turno, Vehiculo,
)
from app.modules.prestadores.models import Prestador, EstadoPrestador
from app.modules.auth.models import Usuario, RolUsuario

logger = logging.getLogger(__name__)

OTP_TTL_MIN = 15
OTP_MAX_INTENTOS = 5


async def _buscar_o_crear_cliente(db: AsyncSession, email: str, nombre: str, telefono: str) -> Usuario:
    """Busca cliente por email o lo crea como 'guest web'."""
    existing = (await db.execute(select(Usuario).where(Usuario.email == email))).scalar_one_or_none()
    if existing:
        return existing
    partes = nombre.strip().split(" ", 1)
    cliente = Usuario(
        firebase_uid=f"web_{uuid4().hex}",
        email=email,
        phone=telefono,
        nombre=partes[0],
        apellido=partes[1] if len(partes) > 1 else None,
        rol=RolUsuario.CLIENTE,
    )
    db.add(cliente)
    await db.flush()
    return cliente


async def _buscar_o_crear_vehiculo(
    db: AsyncSession, cliente: Usuario,
    marca: str, modelo: str, anio: int | None, patente: str | None,
) -> ObjetoServicio:
    """Busca objeto+vehiculo por patente del cliente, o crea uno."""
    if patente:
        veh = (await db.execute(
            select(Vehiculo).where(Vehiculo.patente == patente.upper())
        )).scalar_one_or_none()
        if veh:
            obj = (await db.execute(
                select(ObjetoServicio).where(ObjetoServicio.id == veh.objeto_servicio_id)
            )).scalar_one()
            if obj.propietario_id != cliente.id:
                obj.propietario_id = cliente.id
                await db.flush()
            return obj

    patente_final = (patente or f"WEB-{uuid4().hex[:8]}").upper()
    obj = ObjetoServicio(
        tipo=TipoObjetoServicio.VEHICULO,
        propietario_id=cliente.id,
        alias=f"{marca} {modelo}",
    )
    db.add(obj)
    await db.flush()

    veh = Vehiculo(
        objeto_servicio_id=obj.id,
        patente=patente_final,
        marca=marca,
        modelo=modelo,
        anio=anio or 2000,
        tipo_vehiculo=TipoVehiculo.OTRO,
    )
    db.add(veh)
    await db.flush()
    return obj


async def crear_solicitud_turno(db: AsyncSession, slug: str, data) -> Turno:
    """Crea turno pendiente + genera OTP + envia email."""
    # 1. Buscar prestador
    prestador = (await db.execute(
        select(Prestador).where(Prestador.slug == slug)
    )).scalar_one_or_none()
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador no encontrado")
    if prestador.estado != EstadoPrestador.VERIFICADO or not prestador.activo:
        raise HTTPException(status_code=403, detail="Prestador no disponible")

    # 2. Cliente
    cliente = await _buscar_o_crear_cliente(
        db, data.email_cliente, data.nombre_cliente, data.telefono_cliente
    )

    # 3. Objeto/Vehiculo
    obj = await _buscar_o_crear_vehiculo(
        db, cliente,
        data.vehiculo_marca, data.vehiculo_modelo,
        data.vehiculo_anio, data.vehiculo_patente,
    )

    # 3.5. Guardar metadata extra en el objeto_servicio (Boostr + correcciones)
    if hasattr(data, 'metadata_extra') and data.metadata_extra:
        existing_meta = obj.metadata_extra or {}
        existing_meta.update(data.metadata_extra)
        obj.metadata_extra = existing_meta
        await db.flush()

    # 4. Generar OTP
    otp = f"{secrets.randbelow(1000000):06d}"
    expira = datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MIN)

    # 5. Crear turno
    turno = Turno(
        cliente_id=cliente.id,
        prestador_id=prestador.id,
        objeto_servicio_id=obj.id,
        servicio_id=data.servicio_id,
        fecha_inicio=data.fecha_preferida,
        duracion_min=data.duracion_min,
        estado=EstadoTurno.PENDIENTE,
        motivo=data.motivo,
        modalidad=getattr(data, "modalidad", None) or "domicilio",
        direccion_atencion=getattr(data, "direccion_atencion", None),
        metadata_extra=getattr(data, "metadata_extra", None),
        email_cliente=data.email_cliente,
        nombre_cliente=data.nombre_cliente,
        telefono_cliente=data.telefono_cliente,
        otp_code=otp,
        otp_expires_at=expira,
        otp_intentos=0,
        email_verificado=False,
    )
    db.add(turno)
    await db.commit()
    await db.refresh(turno)

    # 6. Enviar email OTP (background task externo)
    return turno


async def verificar_otp_turno(db: AsyncSession, turno_id: UUID, codigo: str) -> Turno:
    """Valida OTP, marca email verificado."""
    turno = (await db.execute(
        select(Turno).where(Turno.id == turno_id)
    )).scalar_one_or_none()
    if not turno:
        raise HTTPException(status_code=404, detail="Turno no encontrado")
    if turno.email_verificado:
        raise HTTPException(status_code=400, detail="Email ya verificado")
    if turno.otp_intentos >= OTP_MAX_INTENTOS:
        raise HTTPException(status_code=400, detail="Demasiados intentos. Pedi nuevo codigo.")
    if not turno.otp_code or not turno.otp_expires_at:
        raise HTTPException(status_code=400, detail="No hay codigo pendiente")
    if datetime.now(timezone.utc) > turno.otp_expires_at:
        raise HTTPException(status_code=400, detail="Codigo expirado")

    if codigo.strip() != turno.otp_code:
        turno.otp_intentos += 1
        await db.commit()
        remaining = OTP_MAX_INTENTOS - turno.otp_intentos
        raise HTTPException(status_code=400, detail=f"Codigo incorrecto. Intentos: {remaining}")

    turno.email_verificado = True
    turno.email_verificado_at = datetime.now(timezone.utc)
    turno.otp_code = None
    turno.otp_expires_at = None
    await db.commit()
    await db.refresh(turno)
    from .services import _notificar_nuevo_turno_prestador
    await _notificar_nuevo_turno_prestador(db, turno)
    return turno


async def reenviar_otp_turno(db: AsyncSession, turno_id: UUID) -> Turno:
    """Regenera OTP."""
    turno = (await db.execute(
        select(Turno).where(Turno.id == turno_id)
    )).scalar_one_or_none()
    if not turno:
        raise HTTPException(status_code=404, detail="Turno no encontrado")
    if turno.email_verificado:
        raise HTTPException(status_code=400, detail="Email ya verificado")

    turno.otp_code = f"{secrets.randbelow(1000000):06d}"
    turno.otp_expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MIN)
    turno.otp_intentos = 0
    await db.commit()
    await db.refresh(turno)
    return turno
