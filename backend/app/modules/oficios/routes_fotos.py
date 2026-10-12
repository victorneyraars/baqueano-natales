"""Endpoints de fotos de ordenes (M5.1).

Routers:
- /mis-ordenes/{oid}/fotos (cliente)
- /mis-prestadores/{pid}/ordenes/{oid}/fotos (prestador)
- /ordenes/fotos/{foto_id}/archivo/{variante} (servir archivo, cualquier rol con ownership)
"""
import logging
from uuid import UUID

from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import Response

from app.core.db import DbSession
from app.modules.auth.deps import CurrentUser
from app.modules.oficios import services_fotos
from app.modules.oficios.models import MomentoFoto
from app.modules.oficios.schemas import OrdenFotoResponse
from app.modules.prestadores.models import Prestador

logger = logging.getLogger(__name__)


router_fotos_cliente = APIRouter(
    prefix="/mis-ordenes",
    tags=["oficios-fotos-cliente"],
)
router_fotos_prestador = APIRouter(
    prefix="/mis-prestadores",
    tags=["oficios-fotos-prestador"],
)
router_fotos_archivo = APIRouter(
    prefix="/ordenes/fotos",
    tags=["oficios-fotos-archivo"],
)


# =========================================================
# Helpers
# =========================================================
def _parse_momento(momento: str) -> MomentoFoto:
    """Convierte el string del form al enum, con 400 si es invalido."""
    try:
        return MomentoFoto(momento)
    except ValueError:
        validos = [m.value for m in MomentoFoto]
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Momento invalido '{momento}'. Validos: {validos}",
        ) from None


# =========================================================
# CLIENTE
# =========================================================
@router_fotos_cliente.post(
    "/{orden_id}/fotos",
    response_model=OrdenFotoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Subir foto a una orden (cliente)",
)
async def subir_foto_cliente(
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
    archivo: UploadFile = File(..., description="Imagen JPEG/PNG/WebP (max 15 MB)"),
    momento: str = Form("otro", description="ingreso|diagnostico|en_proceso|entrega|reclamo|otro"),
    item_id: UUID | None = Form(None),
    descripcion: str | None = Form(None, max_length=255),
):
    if not archivo.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se recibio archivo",
        )
    content = await archivo.read()
    momento_enum = _parse_momento(momento)

    foto_dict = await services_fotos.subir_foto(
        db=db,
        usuario=user,
        orden_id=orden_id,
        content=content,
        momento=momento_enum,
        item_id=item_id,
        descripcion=descripcion,
    )
    return OrdenFotoResponse.model_validate(foto_dict)


@router_fotos_cliente.get(
    "/{orden_id}/fotos",
    response_model=list[OrdenFotoResponse],
    summary="Listar fotos de una orden (cliente)",
)
async def listar_fotos_cliente(
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
    momento: str | None = Query(None, description="Filtrar por momento"),
):
    momento_enum = _parse_momento(momento) if momento else None
    fotos = await services_fotos.listar_fotos(
        db=db,
        usuario=user,
        orden_id=orden_id,
        momento=momento_enum,
    )
    return [OrdenFotoResponse.model_validate(f) for f in fotos]


@router_fotos_cliente.delete(
    "/{orden_id}/fotos/{foto_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar (soft) una foto (cliente)",
)
async def eliminar_foto_cliente(
    orden_id: UUID,
    foto_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    await services_fotos.eliminar_foto(
        db=db, usuario=user, foto_id=foto_id,
    )


# =========================================================
# PRESTADOR
# =========================================================
@router_fotos_prestador.post(
    "/{prestador_id}/ordenes/{orden_id}/fotos",
    response_model=OrdenFotoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Subir foto a una orden (prestador)",
)
async def subir_foto_prestador(
    prestador_id: UUID,
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
    archivo: UploadFile = File(..., description="Imagen JPEG/PNG/WebP (max 15 MB)"),
    momento: str = Form("otro", description="ingreso|diagnostico|en_proceso|entrega|reclamo|otro"),
    item_id: UUID | None = Form(None),
    descripcion: str | None = Form(None, max_length=255),
):
    from sqlalchemy import select

    prestador_orm = (
        await db.execute(
            select(Prestador).where(Prestador.id == prestador_id)
        )
    ).scalar_one_or_none()
    if prestador_orm is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prestador no encontrado",
        )
    if user.rol != "admin" and prestador_orm.usuario_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso sobre este prestador",
        )

    if not archivo.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se recibio archivo",
        )
    content = await archivo.read()
    momento_enum = _parse_momento(momento)

    foto_dict = await services_fotos.subir_foto(
        db=db,
        usuario=user,
        orden_id=orden_id,
        content=content,
        momento=momento_enum,
        item_id=item_id,
        descripcion=descripcion,
    )
    return OrdenFotoResponse.model_validate(foto_dict)


@router_fotos_prestador.get(
    "/{prestador_id}/ordenes/{orden_id}/fotos",
    response_model=list[OrdenFotoResponse],
    summary="Listar fotos de una orden (prestador)",
)
async def listar_fotos_prestador(
    prestador_id: UUID,
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
    momento: str | None = Query(None, description="Filtrar por momento"),
):
    from sqlalchemy import select

    prestador_orm = (
        await db.execute(
            select(Prestador).where(Prestador.id == prestador_id)
        )
    ).scalar_one_or_none()
    if prestador_orm is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prestador no encontrado",
        )
    if user.rol != "admin" and prestador_orm.usuario_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso sobre este prestador",
        )

    momento_enum = _parse_momento(momento) if momento else None
    fotos = await services_fotos.listar_fotos(
        db=db,
        usuario=user,
        orden_id=orden_id,
        momento=momento_enum,
    )
    return [OrdenFotoResponse.model_validate(f) for f in fotos]


@router_fotos_prestador.delete(
    "/{prestador_id}/ordenes/{orden_id}/fotos/{foto_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar (soft) una foto (prestador)",
)
async def eliminar_foto_prestador(
    prestador_id: UUID,
    orden_id: UUID,
    foto_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    from sqlalchemy import select

    prestador_orm = (
        await db.execute(
            select(Prestador).where(Prestador.id == prestador_id)
        )
    ).scalar_one_or_none()
    if prestador_orm is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prestador no encontrado",
        )
    if user.rol != "admin" and prestador_orm.usuario_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso sobre este prestador",
        )
    await services_fotos.eliminar_foto(
        db=db, usuario=user, foto_id=foto_id,
    )


# =========================================================
# SERVIR ARCHIVO (autenticado, valida ownership)
# =========================================================
@router_fotos_archivo.get(
    "/{foto_id}/archivo/{variante}",
    summary="Servir variante de una foto (requiere auth + ownership)",
    responses={
        200: {"content": {"image/jpeg": {}}},
        403: {"description": "Sin permiso"},
        404: {"description": "Foto o variante no encontrada"},
    },
)
async def servir_foto(
    foto_id: UUID,
    variante: str,
    user: CurrentUser,
    db: DbSession,
):
    if variante not in ("original", "medium", "thumb"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Variante invalida (original|medium|thumb)",
        )

    foto = await services_fotos.obtener_foto_para_servir(
        db=db, usuario=user, foto_id=foto_id,
    )
    content = await services_fotos.leer_variante(foto, variante)

    return Response(
        content=content,
        media_type="image/jpeg",
        headers={
            "Cache-Control": "private, max-age=3600",
            "ETag": f'"{foto.hash_sha256}-{variante}"',
        },
    )
