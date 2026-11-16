"""Endpoints publicos para solicitudes de turno desde la landing."""

import logging
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks
from sqlalchemy import select

from app.core.db import DbSession
from app.modules.oficios.models import Turno, Vehiculo
from app.modules.oficios.schemas_turnos_publicos import (
    SolicitudTurnoCreate, SolicitudTurnoResponse,
    VerificarOtpRequest, VerificarOtpResponse,
)
from app.modules.oficios.services_turnos_publicos import (
    crear_solicitud_turno, verificar_otp_turno, reenviar_otp_turno,
)
from app.modules.notificaciones.turnos import (
    notificar_otp_turno_cliente,
    notificar_turno_solicitado_cliente,
    notificar_nuevo_turno_prestador,
)
from app.modules.prestadores.models import Prestador

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/public/oficios", tags=["Oficios - Turnos Publicos"])


async def _email_data(db, turno: Turno) -> dict:
    """Extrae datos del turno para el email."""
    veh = None
    try:
        veh = (await db.execute(
            select(Vehiculo).where(Vehiculo.objeto_servicio_id == turno.objeto_servicio_id)
        )).scalar_one_or_none()
    except Exception as e:
        logger.warning(f"No se pudo obtener vehiculo: {e}")

    vehiculo_str = f"{veh.marca} {veh.modelo}" if veh else "Vehiculo"
    patente = veh.patente if veh else None
    servicio_str = (turno.motivo or "Servicio general")[:80]

    return {
        "vehiculo": vehiculo_str,
        "patente": patente,
        "servicio": servicio_str,
        "fecha": turno.fecha_inicio.isoformat(),
    }


@router.post(
    "/{slug}/solicitar-turno",
    response_model=SolicitudTurnoResponse,
    status_code=201,
    summary="Solicitar turno desde la landing",
)
async def solicitar_turno(
    slug: str,
    data: SolicitudTurnoCreate,
    db: DbSession,
    background_tasks: BackgroundTasks,
):
    turno = await crear_solicitud_turno(db, slug, data)
    email_data = await _email_data(db, turno)

    background_tasks.add_task(
        notificar_otp_turno_cliente,
        email_cliente=turno.email_cliente,
        nombre_cliente=turno.nombre_cliente or "Cliente",
        codigo=turno.otp_code,
        servicio=email_data["servicio"],
        fecha=email_data["fecha"],
        vehiculo=email_data["vehiculo"],
        patente=email_data["patente"],
    )

    return SolicitudTurnoResponse(
        turno_id=turno.id,
        mensaje="Solicitud recibida. Revisa tu email para el codigo de verificacion.",
    )


@router.post(
    "/turnos/{turno_id}/verificar-email",
    response_model=VerificarOtpResponse,
    summary="Verificar email de turno con OTP",
)
async def verificar_email_turno(
    turno_id: UUID,
    data: VerificarOtpRequest,
    db: DbSession,
    background_tasks: BackgroundTasks,
):
    turno = await verificar_otp_turno(db, turno_id, data.codigo)
    email_data = await _email_data(db, turno)

    background_tasks.add_task(
        notificar_turno_solicitado_cliente,
        email_cliente=turno.email_cliente,
        nombre_cliente=turno.nombre_cliente or "Cliente",
        servicio=email_data["servicio"],
        fecha=email_data["fecha"],
        vehiculo=email_data["vehiculo"],
    )

    prestador = (await db.execute(
        select(Prestador).where(Prestador.id == turno.prestador_id)
    )).scalar_one_or_none()
    if prestador and prestador.email:
        background_tasks.add_task(
            notificar_nuevo_turno_prestador,
            email_prestador=prestador.email,
            nombre_cliente=turno.nombre_cliente or "Cliente",
            email_cliente=turno.email_cliente,
            telefono_cliente=turno.telefono_cliente,
            servicio=email_data["servicio"],
            fecha=email_data["fecha"],
            vehiculo=email_data["vehiculo"],
            patente=email_data["patente"],
            motivo=turno.motivo,
        )

    return VerificarOtpResponse(ok=True, mensaje="Email verificado. Turno registrado.")


@router.post(
    "/turnos/{turno_id}/reenviar-otp",
    response_model=VerificarOtpResponse,
    summary="Reenviar codigo OTP al cliente",
)
async def reenviar_codigo(
    turno_id: UUID,
    db: DbSession,
    background_tasks: BackgroundTasks,
):
    turno = await reenviar_otp_turno(db, turno_id)
    email_data = await _email_data(db, turno)

    background_tasks.add_task(
        notificar_otp_turno_cliente,
        email_cliente=turno.email_cliente,
        nombre_cliente=turno.nombre_cliente or "Cliente",
        codigo=turno.otp_code,
        servicio=email_data["servicio"],
        fecha=email_data["fecha"],
        vehiculo=email_data["vehiculo"],
        patente=email_data["patente"],
    )

    return VerificarOtpResponse(ok=True, mensaje="Codigo reenviado.")
