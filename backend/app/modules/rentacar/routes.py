"""Endpoints admin de Rent a Car Vásquez.

Router: router_admin (requiere JWT de admin).
Prefijo final: /api/v1/admin/rentacar/...
"""
from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.core.db import DbSession
from app.modules.social.deps import AdminUser
from app.modules.auth.deps import get_admin_prestadores_ids

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
async def listar_vehiculos(
    db: DbSession,
    _admin: AdminUser,
    prestador_id: UUID | None = None,
):
    """Lista vehiculos. Super admin ve todos; admin de servicio solo los suyos."""
    admin_prestadores = await get_admin_prestadores_ids(_admin, db)

    if admin_prestadores is None:
        return await services.listar_vehiculos(db, prestador_id=prestador_id)
    elif len(admin_prestadores) == 0:
        return []
    else:
        if prestador_id:
            if prestador_id not in admin_prestadores:
                raise HTTPException(status_code=403, detail="Sin acceso a este prestador")
            return await services.listar_vehiculos(db, prestador_id=prestador_id)
        else:
            all_vehiculos = []
            for pid in admin_prestadores:
                vehiculos = await services.listar_vehiculos(db, prestador_id=pid)
                all_vehiculos.extend(vehiculos)
            return all_vehiculos


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
async def listar_reservas(
    db: DbSession,
    _admin: AdminUser,
    prestador_id: UUID | None = None,
):
    """Lista reservas. Super admin ve todas; admin de servicio solo las suyas."""
    admin_prestadores = await get_admin_prestadores_ids(_admin, db)

    if admin_prestadores is None:
        return await services.listar_reservas(db, prestador_id=prestador_id)
    elif len(admin_prestadores) == 0:
        return []
    else:
        if prestador_id:
            if prestador_id not in admin_prestadores:
                raise HTTPException(status_code=403, detail="Sin acceso a este prestador")
            return await services.listar_reservas(db, prestador_id=prestador_id)
        else:
            return await services.listar_reservas(db, prestador_ids=admin_prestadores)


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


# =========================================================
# Acciones de admin sobre reservas (Fase Admin Web)
# =========================================================

@router_admin.post(
    "/reservas/{reserva_id}/confirmar",
    response_model=RentacarReservaOut,
    summary="Confirmar reserva (admin)",
)
async def admin_confirmar_reserva(
    reserva_id: UUID,
    db: DbSession,
    _admin: AdminUser,
):
    """Cambia estado 'pendiente' -> 'confirmada'. Solo admins."""
    try:
        return await services.confirmar_reserva(db, reserva_id, gestionado_por="Admin Web")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router_admin.post(
    "/reservas/{reserva_id}/cancelar",
    response_model=RentacarReservaOut,
    summary="Cancelar reserva (admin)",
)
async def admin_cancelar_reserva(
    reserva_id: UUID,
    db: DbSession,
    _admin: AdminUser,
):
    """Cambia estado 'pendiente' -> 'cancelada' y libera el bloqueo. Solo admins."""
    try:
        return await services.cancelar_reserva(db, reserva_id, gestionado_por="Admin Web")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# =========================================================
# Inspecciones de entrega/recepcion (admin multi-tenant)
# =========================================================
from datetime import datetime, timezone as _tz
from pydantic import BaseModel as _BaseModel


class _InspeccionCreate(_BaseModel):
    tipo: str  # "entrega" | "recepcion"
    kilometraje: int
    nivel_combustible: str
    fotos: list[str]
    firma_cliente: str | None = None


async def _validar_reserva_del_admin(db, admin_user, reserva_id):
    """Valida que el admin tenga permiso sobre la reserva."""
    from app.modules.rentacar.models import RentacarReserva as _RR, RentacarVehiculo as _RV
    from sqlalchemy import select as _sel

    stmt = _sel(_RR).where(_RR.id == reserva_id)
    reserva = (await db.execute(stmt)).scalar_one_or_none()
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    # Verificar que el vehiculo pertenezca a un prestador del admin
    stmt = _sel(_RV).where(_RV.id == reserva.vehiculo_id)
    vehiculo = (await db.execute(stmt)).scalar_one_or_none()
    if not vehiculo:
        raise HTTPException(status_code=404, detail="Vehiculo de la reserva no encontrado")

    admin_prestadores = await get_admin_prestadores_ids(admin_user, db)
    if admin_prestadores is not None and vehiculo.prestador_id not in admin_prestadores:
        raise HTTPException(status_code=403, detail="Sin acceso a esta reserva")

    return reserva, vehiculo


@router_admin.post(
    "/reservas/{reserva_id}/inspeccion",
    summary="Guardar inspeccion de entrega o recepcion (admin)",
)
async def admin_crear_inspeccion(
    reserva_id: UUID,
    data: _InspeccionCreate,
    db: DbSession,
    _admin: AdminUser,
):
    from app.modules.rentacar.models import RentacarInspeccion as _RI
    from uuid import uuid4 as _uuid4

    reserva, _ = await _validar_reserva_del_admin(db, _admin, reserva_id)

    inspeccion = _RI(
        id=_uuid4(),
        reserva_id=reserva_id,
        tipo=data.tipo,
        kilometraje=data.kilometraje,
        nivel_combustible=data.nivel_combustible,
        fotos=data.fotos,
        firma_cliente=data.firma_cliente,
        firmado_at=datetime.now(_tz.utc) if data.firma_cliente else None,
    )
    db.add(inspeccion)

    if data.tipo == "entrega":
        reserva.estado = "en_curso"

    await db.commit()
    return {"ok": True, "mensaje": "Inspeccion guardada correctamente"}


@router_admin.get(
    "/reservas/{reserva_id}/inspecciones",
    summary="Listar inspecciones de una reserva (admin)",
)
async def admin_listar_inspecciones(
    reserva_id: UUID,
    db: DbSession,
    _admin: AdminUser,
):
    from app.modules.rentacar.models import RentacarInspeccion as _RI
    from sqlalchemy import select as _sel

    await _validar_reserva_del_admin(db, _admin, reserva_id)

    stmt = _sel(_RI).where(_RI.reserva_id == reserva_id)
    inspecciones = (await db.execute(stmt)).scalars().all()

    return [
        {
            "id": str(i.id),
            "reserva_id": str(i.reserva_id),
            "tipo": i.tipo,
            "kilometraje": i.kilometraje,
            "nivel_combustible": i.nivel_combustible,
            "fotos": i.fotos,
            "firma_cliente": i.firma_cliente,
            "firmado_at": i.firmado_at.isoformat() if i.firmado_at else None,
            "created_at": i.created_at.isoformat() if i.created_at else None,
        }
        for i in inspecciones
    ]
