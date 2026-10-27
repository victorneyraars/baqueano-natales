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



# ---------------------------- Upload de imagen (R2) ----------------------------
from app.core.storage import (
    generate_object_key,
    generate_presigned_upload_url,
    get_public_url,
)
from .schemas import (
    RentacarImagenPresignedRequest,
    RentacarImagenPresignedResponse,
)

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router_admin.post(
    "/vehiculos/{vehiculo_id}/imagen/presigned",
    response_model=RentacarImagenPresignedResponse,
    summary="Genera URL prefirmada para subir imagen a R2",
)
async def presigned_upload_imagen(
    vehiculo_id: UUID,
    data: RentacarImagenPresignedRequest,
    db: DbSession,
    _admin: AdminUser,
):
    """Devuelve una URL prefirmada de R2 para que el cliente suba la foto
    directamente. Dura 15 minutos. Después el cliente debe hacer
    PUT /vehiculos/{id}/imagen/confirmar con el object_key."""
    if data.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo no permitido: {data.content_type}. Usar JPG, PNG o WebP.",
        )

    vehiculo = await services.get_vehiculo(db, vehiculo_id)
    if vehiculo is None:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")

    object_key = generate_object_key(f"rentacar/vehiculos/{vehiculo_id}", data.filename)
    upload_url = generate_presigned_upload_url(object_key, data.content_type)
    imagen_url = get_public_url(object_key)

    return RentacarImagenPresignedResponse(
        upload_url=upload_url,
        object_key=object_key,
        imagen_url=imagen_url,
    )


@router_admin.post(
    "/vehiculos/{vehiculo_id}/imagen/confirmar",
    response_model=RentacarVehiculoOut,
    summary="Confirma la subida de imagen y actualiza el vehículo",
)
async def confirmar_imagen_vehiculo(
    vehiculo_id: UUID,
    object_key: str,
    db: DbSession,
    _admin: AdminUser,
):
    """Después del PUT exitoso a R2, el cliente llama este endpoint con
    el object_key devuelto por el presigned para guardar la imagen_url."""
    vehiculo = await services.get_vehiculo(db, vehiculo_id)
    if vehiculo is None:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")

    vehiculo.imagen_url = get_public_url(object_key)
    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo
