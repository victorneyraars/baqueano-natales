"""Endpoints públicos de Rent a Car Vásquez.

Router: router_publico (SIN auth, CORS abierto).
Prefijo final: /api/v1/public/rentacar/...

Soporta ETag / If-None-Match para polling eficiente desde la web
(rentacarvasquez.com) sin transferir datos innecesarios.
"""
import hashlib
import json
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, Response
from fastapi.responses import HTMLResponse
from app.modules.notificaciones.tokens import validar_token_accion
import jwt

from app.core.db import DbSession

from . import services
from .schemas import (
    RentacarReservaCreate,
    RentacarReservaOut,
    RentacarVehiculoOut,
    VerificarEmailRequest,
    VerificarEmailResponse,
)

from app.modules.notificaciones.reservas import (
    notificar_nueva_reserva_cliente,
    notificar_nueva_reserva_prestador,
    notificar_otp_cliente,
    notificar_reserva_cancelada_cliente,
    notificar_reserva_confirmada_cliente,
)
from app.modules.prestadores.canales_contacto import (
    build_canales_contacto,
)
from app.modules.prestadores.services import (
    obtener_prestador_por_slug,
)

router_publico = APIRouter(
    prefix="/public/rentacar", tags=["rentacar-public"]
)


def _etag(payload: object) -> str:
    """Genera un ETag estable (SHA-256 del JSON serializado)."""
    raw = json.dumps(payload, sort_keys=True, default=str).encode()
    return '"' + hashlib.sha256(raw).hexdigest()[:32] + '"'


@router_publico.get(
    "/vehiculos",
    response_model=list[RentacarVehiculoOut],
    summary="Catálogo público de vehículos en alquiler",
)
async def listar_vehiculos_publico(
    db: DbSession,
    response: Response,
    if_none_match: str | None = Header(default=None, alias="If-None-Match"),
):
    vehiculos = await services.listar_vehiculos(db)
    # Serializar a dict para calcular ETag estable
    payload = [RentacarVehiculoOut.model_validate(v).model_dump() for v in vehiculos]
    current_etag = _etag(payload)

    if if_none_match == current_etag:
        return Response(status_code=304, headers={"ETag": current_etag})

    response.headers["ETag"] = current_etag
    response.headers["Cache-Control"] = "public, max-age=30"
    return vehiculos


@router_publico.get(
    "/vehiculos/{vehiculo_id}",
    response_model=RentacarVehiculoOut,
    summary="Detalle público de un vehículo",
)
async def detalle_vehiculo_publico(vehiculo_id: UUID, db: DbSession):
    vehiculo = await services.get_vehiculo(db, vehiculo_id)
    if vehiculo is None:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")
    return vehiculo


@router_publico.get(
    "/prestadores/{prestador_id}/vehiculos",
    response_model=list[RentacarVehiculoOut],
    summary="Vehículos de un prestador específico (para la web del prestador)",
)
async def vehiculos_por_prestador(
    prestador_id: UUID, db: DbSession,
):
    return await services.listar_vehiculos(db, prestador_id)




@router_publico.get(
    "/reservas/{id}/accion",
    summary="Pagina intermedia de confirmacion (protege contra escaneres de email)",
)
async def pagina_accion_reserva(id: UUID, token: str):
    try:
        payload = validar_token_accion(token)
    except jwt.ExpiredSignatureError:
        return HTMLResponse("<h2>El enlace ha expirado. Contacta al cliente.</h2>", status_code=400)
    except jwt.InvalidTokenError:
        return HTMLResponse("<h2>Enlace invalido.</h2>", status_code=400)

    if str(payload["reserva_id"]) != str(id):
        return HTMLResponse("<h2>Token no corresponde a la reserva.</h2>", status_code=400)

    accion = payload["accion"]
    color = "#16A34A" if accion == "confirmar" else "#DC2626"
    texto = "Confirmar Reserva" if accion == "confirmar" else "Cancelar Reserva"

    html = f"""
    <html>
    <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
        <h2>Estas seguro que deseas {texto.lower()}?</h2>
        <form method="POST" action="/api/v1/public/rentacar/reservas/{id}/accion?token={token}">
            <button type="submit" style="background-color: {color}; color: white; padding: 15px 30px; border: none; border-radius: 6px; font-size: 16px; cursor: pointer;">
                Si, {texto}
            </button>
        </form>
        <p style="margin-top: 20px;"><a href="https://rentacarvasquez.com">Volver al sitio</a></p>
    </body>
    </html>
    """
    return HTMLResponse(html)


@router_publico.post(
    "/reservas/{id}/accion",
    summary="Ejecutar accion de confirmacion/cancelacion",
)
async def ejecutar_accion_reserva(
    id: UUID,
    token: str,
    db: DbSession,
    background_tasks: BackgroundTasks,
):
    try:
        payload = validar_token_accion(token)
    except jwt.InvalidTokenError:
        return HTMLResponse("<h2>Enlace invalido o expirado.</h2>", status_code=400)

    if str(payload["reserva_id"]) != str(id):
        return HTMLResponse("<h2>Error de validacion.</h2>", status_code=400)

    accion = payload["accion"]
    try:
        if accion == "confirmar":
            reserva = await services.confirmar_reserva(db, id)
            msg = "Reserva Confirmada"
            color = "#16A34A"
        elif accion == "cancelar":
            reserva = await services.cancelar_reserva(db, id)
            msg = "Reserva Cancelada"
            color = "#DC2626"
        else:
            return HTMLResponse("<h2>Accion no reconocida.</h2>", status_code=400)
    except ValueError as e:
        return HTMLResponse(f"<h2>Error: {e}</h2>", status_code=400)

    # Notificar al cliente de la transicion (background)
    if reserva.email_cliente:
        vehiculo = await services.get_vehiculo(db, reserva.vehiculo_id)
        vehiculo_label = (
            f"{vehiculo.marca} {vehiculo.modelo}" if vehiculo else "Vehiculo"
        )
        if accion == "confirmar":
            background_tasks.add_task(
                notificar_reserva_confirmada_cliente,
                email_cliente=reserva.email_cliente,
                nombre_cliente=reserva.nombre_cliente or "Cliente",
                vehiculo=vehiculo_label,
                inicio=reserva.fecha_inicio.isoformat(),
                fin=reserva.fecha_fin.isoformat(),
                total=float(reserva.precio_total or 0),
            )
        elif accion == "cancelar":
            background_tasks.add_task(
                notificar_reserva_cancelada_cliente,
                email_cliente=reserva.email_cliente,
                nombre_cliente=reserva.nombre_cliente or "Cliente",
                vehiculo=vehiculo_label,
                inicio=reserva.fecha_inicio.isoformat(),
                fin=reserva.fecha_fin.isoformat(),
            )

    html = f"""
    <html>
    <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
        <h1 style="color: {color};">{msg} con exito</h1>
        <p>La reserva ha sido actualizada. El cliente sera notificado.</p>
    </body>
    </html>
    """
    return HTMLResponse(html)


@router_publico.post(
    "/reservas",
    response_model=RentacarReservaOut,
    status_code=201,
    summary="Crear reserva pública (invitado)",
)
async def crear_reserva_publica(
    data: RentacarReservaCreate,
    db: DbSession,
    background_tasks: BackgroundTasks,
):
    try:
        reserva = await services.crear_reserva(db, data)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Notificaciones (background = no bloquea la respuesta al cliente)
    try:
        vehiculo = await services.get_vehiculo(db, reserva.vehiculo_id)
        prestador = await obtener_prestador_por_slug(db, "rentacar-vasquez")
        if vehiculo and prestador:
            canales = build_canales_contacto(prestador)
            email_prestador = next(
                (
                    c["direccion"]
                    for c in canales.get("email", [])
                    if c.get("tipo") == "reservas" and c.get("activo", True)
                ),
                prestador.email,
            )
            vehiculo_label = f"{vehiculo.marca} {vehiculo.modelo}"
            total = float(getattr(reserva, "precio_total", 0) or 0)

            if email_prestador:
                background_tasks.add_task(
                    notificar_nueva_reserva_prestador,
                    reserva_id=str(reserva.id),
                    email_prestador=email_prestador,
                    nombre_cliente=reserva.nombre_cliente or "Sin nombre",
                    email_cliente=reserva.email_cliente or "",
                    telefono_cliente=reserva.telefono_cliente or "",
                    vehiculo=vehiculo_label,
                    inicio=reserva.fecha_inicio.isoformat(),
                    fin=reserva.fecha_fin.isoformat(),
                    total=total,
                )

            # Enviar OTP al cliente (verifica que el email es real)
            if reserva.email_cliente and reserva.otp_code:
                background_tasks.add_task(
                    notificar_otp_cliente,
                    email_cliente=reserva.email_cliente,
                    nombre_cliente=reserva.nombre_cliente or "Cliente",
                    codigo=reserva.otp_code,
                    vehiculo=vehiculo_label,
                    inicio=reserva.fecha_inicio.isoformat(),
                    fin=reserva.fecha_fin.isoformat(),
                )

            if reserva.email_cliente:
                background_tasks.add_task(
                    notificar_nueva_reserva_cliente,
                    email_cliente=reserva.email_cliente,
                    nombre_cliente=reserva.nombre_cliente or "Cliente",
                    vehiculo=vehiculo_label,
                    inicio=reserva.fecha_inicio.isoformat(),
                    fin=reserva.fecha_fin.isoformat(),
                    total=total,
                )
    except Exception as exc:
        import logging
        logging.getLogger(__name__).warning(
            f"No se pudo notificar reserva {reserva.id}: {exc}"
        )

    return reserva


@router_publico.post(
    "/reservas/{reserva_id}/verificar-email",
    response_model=VerificarEmailResponse,
    summary="Verificar email de reserva via OTP",
    description=(
        "Valida el codigo de 6 digitos enviado al email del cliente. "
        "Si es correcto, marca la reserva como email_verificado=True."
    ),
)
async def verificar_email_reserva(
    reserva_id: UUID,
    data: VerificarEmailRequest,
    db: DbSession,
) -> VerificarEmailResponse:
    try:
        reserva = await services.verificar_email_reserva(
            db, reserva_id, data.codigo
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return VerificarEmailResponse(
        ok=True,
        mensaje="Email verificado. Tu reserva quedo confirmada como valida.",
        reserva_id=reserva.id,
        email_verificado=reserva.email_verificado,
    )


@router_publico.post(
    "/reservas/{reserva_id}/reenviar-otp",
    summary="Reenviar codigo OTP al email del cliente",
    description=(
        "Regenera el codigo OTP (invalida el anterior). "
        "Rate limit: 1 reenvio cada 60 segundos."
    ),
)
async def reenviar_otp_reserva(
    reserva_id: UUID,
    db: DbSession,
    background_tasks: BackgroundTasks,
):
    try:
        reserva = await services.reenviar_otp(db, reserva_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    vehiculo = await services.get_vehiculo(db, reserva.vehiculo_id)
    vehiculo_label = (
        f"{vehiculo.marca} {vehiculo.modelo}" if vehiculo else "Vehiculo"
    )

    if reserva.email_cliente and reserva.otp_code:
        background_tasks.add_task(
            notificar_otp_cliente,
            email_cliente=reserva.email_cliente,
            nombre_cliente=reserva.nombre_cliente or "Cliente",
            codigo=reserva.otp_code,
            vehiculo=vehiculo_label,
            inicio=reserva.fecha_inicio.isoformat(),
            fin=reserva.fecha_fin.isoformat(),
        )

    return {"ok": True, "mensaje": "Nuevo codigo enviado a tu email"}
