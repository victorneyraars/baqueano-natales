"""Endpoints propietario de Rent a Car Vásquez.

Router: router_propietario (requiere JWT de usuario prestador).
Prefijo final: /api/v1/mis-vehiculos-rentacar/...

Permite al prestador gestionar SU PROPIA flota (no la de otros).
Resuelve el prestador del usuario logueado automáticamente.
"""
from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.core.db import DbSession
from app.modules.social.deps import CurrentUser
from app.core.storage import (
    generate_object_key,
    generate_presigned_upload_url,
    get_public_url,
)

from . import services
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


@router_propietario.get("/{vehiculo_id}", response_model=RentacarVehiculoOut)
async def obtener_mi_vehiculo(
    vehiculo_id: UUID, db: DbSession, user: CurrentUser,
):
    try:
        return await services._obtener_mi_vehiculo(db, user, vehiculo_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router_propietario.put("/{vehiculo_id}", response_model=RentacarVehiculoOut)
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
    "/{vehiculo_id}", status_code=status.HTTP_204_NO_CONTENT,
)
async def eliminar_mi_vehiculo(
    vehiculo_id: UUID, db: DbSession, user: CurrentUser,
):
    try:
        await services.eliminar_mi_vehiculo(db, user, vehiculo_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router_propietario.post(
    "/{vehiculo_id}/imagen/presigned",
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
    "/{vehiculo_id}/imagen/confirmar",
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
