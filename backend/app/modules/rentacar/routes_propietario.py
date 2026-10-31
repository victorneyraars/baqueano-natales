"""Endpoints propietario de Rent a Car Vásquez.

Router: router_propietario (requiere JWT de usuario prestador).
Prefijo final: /api/v1/mis-vehiculos-rentacar/...

Permite al prestador gestionar SU PROPIA flota (no la de otros).
Resuelve el prestador del usuario logueado automáticamente.
"""
from uuid import UUID

from fastapi import APIRouter, HTTPException, status, BackgroundTasks

from app.core.db import DbSession
from app.modules.social.deps import CurrentUser
from app.core.storage import (
    generate_object_key,
    generate_presigned_upload_url,
    get_public_url,
)

from . import services
from app.modules.notificaciones.reservas import (
    notificar_reserva_cancelada_cliente,
    notificar_reserva_confirmada_cliente,
)
from .schemas import (
    RentacarImagenPresignedRequest,
    RentacarImagenPresignedResponse,
    RentacarVehiculoCreatePropietario,
    RentacarVehiculoOut,
    RentacarVehiculoUpdatePropietario,
)

router_propietario = APIRouter(
    prefix="/mis-vehiculos-rentacar",
    tags=["rentacar-propietario"],
)

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router_propietario.get("", response_model=list[RentacarVehiculoOut])
async def listar_mis_vehiculos(db: DbSession, user: CurrentUser):
    """Lista todos los vehículos del prestador del usuario."""
    try:
        return await services.listar_mis_vehiculos(db, user)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router_propietario.post(
    "",
    response_model=RentacarVehiculoOut,
    status_code=status.HTTP_201_CREATED,
)
async def crear_mi_vehiculo(
    data: RentacarVehiculoCreatePropietario,
    db: DbSession,
    user: CurrentUser,
):
    """Crea un vehículo para el prestador del usuario."""
    try:
        return await services.crear_mi_vehiculo(db, user, data)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router_propietario.get("/{vehiculo_id:uuid}", response_model=RentacarVehiculoOut)
async def obtener_mi_vehiculo(
    vehiculo_id: UUID, db: DbSession, user: CurrentUser,
):
    try:
        return await services._obtener_mi_vehiculo(db, user, vehiculo_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router_propietario.put("/{vehiculo_id:uuid}", response_model=RentacarVehiculoOut)
async def actualizar_mi_vehiculo(
    vehiculo_id: UUID,
    data: RentacarVehiculoUpdatePropietario,
    db: DbSession,
    user: CurrentUser,
):
    try:
        return await services.actualizar_mi_vehiculo(
            db, user, vehiculo_id, data.model_dump(exclude_unset=True)
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router_propietario.delete(
    "/{vehiculo_id:uuid}", status_code=status.HTTP_204_NO_CONTENT,
)
async def eliminar_mi_vehiculo(
    vehiculo_id: UUID, db: DbSession, user: CurrentUser,
):
    try:
        await services.eliminar_mi_vehiculo(db, user, vehiculo_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router_propietario.post(
    "/{vehiculo_id:uuid}/imagen/presigned",
    response_model=RentacarImagenPresignedResponse,
)
async def presigned_upload_mi_imagen(
    vehiculo_id: UUID,
    data: RentacarImagenPresignedRequest,
    db: DbSession,
    user: CurrentUser,
):
    """Genera URL prefirmada para subir imagen a R2."""
    if data.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo no permitido: {data.content_type}",
        )
    try:
        await services._obtener_mi_vehiculo(db, user, vehiculo_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

    object_key = generate_object_key(
        f"rentacar/vehiculos/{vehiculo_id}", data.filename
    )
    upload_url = generate_presigned_upload_url(object_key, data.content_type)
    imagen_url = get_public_url(object_key)

    return RentacarImagenPresignedResponse(
        upload_url=upload_url,
        object_key=object_key,
        imagen_url=imagen_url,
    )


@router_propietario.post(
    "/{vehiculo_id:uuid}/imagen/confirmar",
    response_model=RentacarVehiculoOut,
)
async def confirmar_mi_imagen(
    vehiculo_id: UUID,
    object_key: str,
    db: DbSession,
    user: CurrentUser,
):
    """Confirma la subida de imagen y actualiza el vehículo."""
    try:
        vehiculo = await services._obtener_mi_vehiculo(db, user, vehiculo_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

    vehiculo.imagen_url = get_public_url(object_key)
    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo


# =========================================================
# Reservas propietario
# =========================================================
from .schemas import (
    RentacarReservaDetalleOut,
    RentacarReservaEstadoUpdate,
    RentacarStatsOut,
    RentacarConfigOut,
    RentacarConfigUpdate,
)
from app.modules.rentacar.schemas import RentacarReservaOut


@router_propietario.get(
    "/reservas",
    response_model=list[RentacarReservaDetalleOut],
    summary="Listar mis reservas",
)
async def listar_mis_reservas(
    db: DbSession,
    user: CurrentUser,
    estado: str | None = None,
):
    """Lista reservas del prestador, con filtro opcional por estado."""
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"[listar_mis_reservas] user={user.id} estado={estado}")
    try:
        reservas = await services.listar_mis_reservas(db, user, estado)
        logger.info(f"[listar_mis_reservas] encontradas {len(reservas)}")
    except ValueError as e:
        logger.error(f"[listar_mis_reservas] ValueError: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"[listar_mis_reservas] Exception: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error interno: {e}")

    # Enriquecer con datos del vehiculo
    result = []
    for r in reservas:
        vehiculo = await services.get_vehiculo(db, r.vehiculo_id)
        out = RentacarReservaDetalleOut.model_validate(r)
        if vehiculo:
            out.vehiculo_patente = vehiculo.patente
            out.vehiculo_marca = vehiculo.marca
            out.vehiculo_modelo = vehiculo.modelo
            out.vehiculo_imagen_url = vehiculo.imagen_url
        result.append(out)
    return result


@router_propietario.get(
    "/reservas/{reserva_id:uuid}",
    response_model=RentacarReservaDetalleOut,
    summary="Detalle de una reserva",
)
async def obtener_mi_reserva(
    reserva_id: UUID,
    db: DbSession,
    user: CurrentUser,
):
    try:
        reserva = await services._obtener_mi_reserva(db, user, reserva_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

    vehiculo = await services.get_vehiculo(db, reserva.vehiculo_id)
    out = RentacarReservaDetalleOut.model_validate(reserva)
    if vehiculo:
        out.vehiculo_patente = vehiculo.patente
        out.vehiculo_marca = vehiculo.marca
        out.vehiculo_modelo = vehiculo.modelo
        out.vehiculo_imagen_url = vehiculo.imagen_url
    return out


@router_propietario.patch(
    "/reservas/{reserva_id:uuid}/estado",
    response_model=RentacarReservaOut,
    summary="Cambiar estado de reserva",
)
async def cambiar_estado_mi_reserva(
    reserva_id: UUID,
    data: RentacarReservaEstadoUpdate,
    db: DbSession,
    user: CurrentUser,
    background_tasks: BackgroundTasks,
):
    try:
        reserva = await services.cambiar_estado_reserva(
            db, user, reserva_id, data.estado
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Notificar al cliente del cambio de estado (background, no bloquea respuesta)
    if reserva.email_cliente and data.estado in ("confirmada", "cancelada"):
        try:
            vehiculo = await services.get_vehiculo(db, reserva.vehiculo_id)
            vehiculo_label = (
                f"{vehiculo.marca} {vehiculo.modelo}" if vehiculo else "Vehiculo"
            )
            if data.estado == "confirmada":
                background_tasks.add_task(
                    notificar_reserva_confirmada_cliente,
                    email_cliente=reserva.email_cliente,
                    nombre_cliente=reserva.nombre_cliente or "Cliente",
                    vehiculo=vehiculo_label,
                    inicio=reserva.fecha_inicio.isoformat(),
                    fin=reserva.fecha_fin.isoformat(),
                    total=float(reserva.precio_total or 0),
                )
            elif data.estado == "cancelada":
                background_tasks.add_task(
                    notificar_reserva_cancelada_cliente,
                    email_cliente=reserva.email_cliente,
                    nombre_cliente=reserva.nombre_cliente or "Cliente",
                    vehiculo=vehiculo_label,
                    inicio=reserva.fecha_inicio.isoformat(),
                    fin=reserva.fecha_fin.isoformat(),
                )
        except Exception as exc:
            import logging
            logging.getLogger(__name__).warning(
                f"Fallo notificando reserva {reserva.id}: {exc}"
            )

    return reserva


# =========================================================
# Stats dashboard
# =========================================================
@router_propietario.get(
    "/stats",
    response_model=RentacarStatsOut,
    summary="Dashboard de estadisticas",
)
async def obtener_mis_stats(db: DbSession, user: CurrentUser):
    try:
        stats = await services.obtener_mis_stats(db, user)
        return RentacarStatsOut(**stats)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))


# =========================================================
# Config propietario
# =========================================================
@router_propietario.get(
    "/config",
    response_model=RentacarConfigOut,
    summary="Mi configuracion",
)
async def obtener_mi_config(db: DbSession, user: CurrentUser):
    try:
        return await services.obtener_mi_config(db, user)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router_propietario.patch(
    "/config",
    response_model=RentacarConfigOut,
    summary="Actualizar mi configuracion",
)
async def actualizar_mi_config(
    data: RentacarConfigUpdate,
    db: DbSession,
    user: CurrentUser,
):
    try:
        return await services.actualizar_mi_config(
            db, user, data.model_dump(exclude_unset=True)
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
