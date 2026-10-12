"""
Endpoints HTTP del módulo comercios.

Dividido en 4 routers:
- router_publico: listado/detalle público + categorías activas.
- router_propietario: gestión por el dueño (/mis-comercios).
- router_admin_comercios: gestión admin de comercios (/admin/comercios).
- router_admin_categorias: CRUD admin de categorías
  (/admin/categorias-comercio).
"""
import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query, status
from pydantic import BaseModel

from app.core.db import DbSession
from app.modules.auth.deps import AdminUser, CurrentUser
from app.modules.comercios import services
from app.modules.comercios.deps import ComercioPropietario
from app.modules.comercios.models import EstadoComercio
from app.modules.comercios.schemas import (
    CategoriaComercioCreate,
    CategoriaComercioResponse,
    CategoriaComercioUpdate,
    ComercioCreate,
    ComercioDetalleResponse,
    ComercioListResponse,
    ComercioPrivadoListResponse,
    ComercioPrivadoResponse,
    ComercioPublicoResponse,
    ComercioRechazarRequest,
    ComercioUpdate,
    ComercioVerificarRequest,
    HorarioResponse,
    HorariosBulkUpdate,
    PaginacionMeta,
)

logger = logging.getLogger(__name__)


# =========================================================
# Público
# =========================================================
router_publico = APIRouter(prefix="/comercios", tags=["comercios"])


@router_publico.get(
    "/categorias",
    response_model=list[CategoriaComercioResponse],
    summary="Listar categorías activas",
    description="Categorías activas para filtros y selección en el cliente.",
)
async def listar_categorias_publicas(
    db: DbSession,
) -> list[CategoriaComercioResponse]:
    categorias = await services.listar_categorias(db, solo_activas=True)
    return [CategoriaComercioResponse.model_validate(c) for c in categorias]


@router_publico.get(
    "",
    response_model=ComercioListResponse,
    summary="Listar comercios verificados",
    description="Listado público con filtros y paginación.",
)
async def listar_comercios_publicos(
    db: DbSession,
    categoria_id: UUID | None = Query(None, description="Filtrar por categoría"),
    q: str | None = Query(
        None,
        description="Búsqueda por nombre o descripción",
        max_length=100,
    ),
    destacados: bool | None = Query(None, description="Solo destacados"),
    delivery: bool | None = Query(None, description="Solo con delivery"),
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> ComercioListResponse:
    items, total = await services.listar_comercios_publicos(
        db,
        categoria_id=categoria_id,
        busqueda=q,
        solo_destacados=destacados or False,
        acepta_delivery=delivery,
        page=page,
        page_size=page_size,
    )
    total_pages = (total + page_size - 1) // page_size
    return ComercioListResponse(
        items=[ComercioPublicoResponse.model_validate(c) for c in items],
        meta=PaginacionMeta(
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        ),
    )


@router_publico.get(
    "/{slug}",
    response_model=ComercioDetalleResponse,
    summary="Detalle público de un comercio",
    description="Detalle completo con horarios de un comercio verificado.",
)
async def obtener_comercio(
    slug: str,
    db: DbSession,
) -> ComercioDetalleResponse:
    comercio = await services.obtener_comercio_por_slug(db, slug)
    return ComercioDetalleResponse.model_validate(comercio)


# =========================================================
# Propietario
# =========================================================
router_propietario = APIRouter(
    prefix="/mis-comercios", tags=["mis-comercios"]
)


@router_propietario.post(
    "",
    response_model=ComercioPrivadoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear comercio",
    description="Crea un comercio en estado 'borrador'.",
)
async def crear_mi_comercio(
    data: ComercioCreate,
    user: CurrentUser,
    db: DbSession,
) -> ComercioPrivadoResponse:
    comercio = await services.crear_comercio(db, user, data)
    await db.refresh(comercio)
    return ComercioPrivadoResponse.model_validate(comercio)


@router_propietario.get(
    "",
    response_model=ComercioPrivadoListResponse,
    summary="Listar mis comercios",
    description="Devuelve todos los comercios del usuario (cualquier estado).",
)
async def listar_mis_comercios(
    user: CurrentUser,
    db: DbSession,
) -> ComercioPrivadoListResponse:
    items = await services.listar_comercios_mios(db, user)
    return ComercioPrivadoListResponse(
        items=[ComercioPrivadoResponse.model_validate(c) for c in items],
        meta=PaginacionMeta(
            total=len(items),
            page=1,
            page_size=len(items) or 1,
            total_pages=1,
        ),
    )


@router_propietario.get(
    "/{comercio_id}",
    response_model=ComercioPrivadoResponse,
    summary="Detalle de mi comercio",
)
async def obtener_mi_comercio(
    comercio: ComercioPropietario,
) -> ComercioPrivadoResponse:
    return ComercioPrivadoResponse.model_validate(comercio)


@router_propietario.patch(
    "/{comercio_id}",
    response_model=ComercioPrivadoResponse,
    summary="Editar mi comercio",
)
async def editar_mi_comercio(
    comercio: ComercioPropietario,
    data: ComercioUpdate,
    db: DbSession,
) -> ComercioPrivadoResponse:
    comercio = await services.editar_comercio(db, comercio, data)
    return ComercioPrivadoResponse.model_validate(comercio)


@router_propietario.delete(
    "/{comercio_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar mi comercio",
    description="Soft-delete: marca el comercio como inactivo.",
)
async def eliminar_mi_comercio(
    comercio: ComercioPropietario,
    db: DbSession,
) -> None:
    await services.eliminar_comercio(db, comercio)


@router_propietario.put(
    "/{comercio_id}/horarios",
    response_model=list[HorarioResponse],
    summary="Reemplazar horarios",
    description="Reemplaza TODOS los horarios del comercio (bulk).",
)
async def setear_horarios_mi_comercio(
    comercio: ComercioPropietario,
    data: HorariosBulkUpdate,
    db: DbSession,
) -> list[HorarioResponse]:
    nuevos = await services.setear_horarios(db, comercio, data.horarios)
    return [HorarioResponse.model_validate(h) for h in nuevos]


@router_propietario.post(
    "/{comercio_id}/enviar-revision",
    response_model=ComercioPrivadoResponse,
    summary="Enviar a revisión",
    description="Cambia el estado de borrador/rechazado a 'pendiente'.",
)
async def enviar_a_revision(
    comercio: ComercioPropietario,
    db: DbSession,
) -> ComercioPrivadoResponse:
    comercio = await services.enviar_a_revision(db, comercio)
    return ComercioPrivadoResponse.model_validate(comercio)


# =========================================================
# Admin — Categorías
# =========================================================
router_admin_categorias = APIRouter(
    prefix="/admin/categorias-comercio",
    tags=["admin-categorias"],
)


@router_admin_categorias.get(
    "",
    response_model=list[CategoriaComercioResponse],
    summary="Listar todas las categorías (admin)",
)
async def admin_listar_categorias(
    admin: AdminUser,
    db: DbSession,
    incluir_inactivas: bool = Query(
        False, description="Incluir categorías desactivadas"
    ),
) -> list[CategoriaComercioResponse]:
    cats = await services.listar_categorias(
        db,
        solo_activas=False,
        incluir_inactivas=incluir_inactivas,
    )
    return [CategoriaComercioResponse.model_validate(c) for c in cats]


@router_admin_categorias.post(
    "",
    response_model=CategoriaComercioResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear categoría",
)
async def admin_crear_categoria(
    data: CategoriaComercioCreate,
    admin: AdminUser,
    db: DbSession,
) -> CategoriaComercioResponse:
    cat = await services.crear_categoria(db, data)
    await db.refresh(cat)
    return CategoriaComercioResponse.model_validate(cat)


@router_admin_categorias.patch(
    "/{categoria_id}",
    response_model=CategoriaComercioResponse,
    summary="Editar categoría",
)
async def admin_editar_categoria(
    categoria_id: UUID,
    data: CategoriaComercioUpdate,
    admin: AdminUser,
    db: DbSession,
) -> CategoriaComercioResponse:
    cat = await services.editar_categoria(db, categoria_id, data)
    return CategoriaComercioResponse.model_validate(cat)


@router_admin_categorias.delete(
    "/{categoria_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Desactivar categoría",
    description=(
        "Soft-delete. Falla si hay comercios activos en esa categoría."
    ),
)
async def admin_desactivar_categoria(
    categoria_id: UUID,
    admin: AdminUser,
    db: DbSession,
) -> None:
    await services.desactivar_categoria(db, categoria_id)


# =========================================================
# Admin — Comercios
# =========================================================
router_admin_comercios = APIRouter(
    prefix="/admin/comercios", tags=["admin-comercios"]
)


class DestacarRequest(BaseModel):
    """Payload para marcar/desmarcar destacado."""

    destacado: bool


@router_admin_comercios.get(
    "",
    response_model=ComercioPrivadoListResponse,
    summary="Listar todos los comercios (admin)",
)
async def admin_listar_comercios(
    admin: AdminUser,
    db: DbSession,
    estado: EstadoComercio | None = Query(None),
    categoria_id: UUID | None = Query(None),
    q: str | None = Query(None, max_length=100),
    incluir_inactivos: bool = Query(False),
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> ComercioPrivadoListResponse:
    items, total = await services.listar_comercios_admin(
        db,
        estado=estado,
        categoria_id=categoria_id,
        busqueda=q,
        incluir_inactivos=incluir_inactivos,
        page=page,
        page_size=page_size,
    )
    total_pages = (total + page_size - 1) // page_size
    return ComercioPrivadoListResponse(
        items=[ComercioPrivadoResponse.model_validate(c) for c in items],
        meta=PaginacionMeta(
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        ),
    )


@router_admin_comercios.get(
    "/{comercio_id}",
    response_model=ComercioPrivadoResponse,
    summary="Detalle de comercio (admin)",
)
async def admin_obtener_comercio(
    comercio_id: UUID,
    admin: AdminUser,
    db: DbSession,
) -> ComercioPrivadoResponse:
    comercio = await services.obtener_comercio_por_id(db, comercio_id)
    return ComercioPrivadoResponse.model_validate(comercio)


@router_admin_comercios.post(
    "/{comercio_id}/verificar",
    response_model=ComercioPrivadoResponse,
    summary="Verificar comercio",
)
async def admin_verificar_comercio(
    comercio_id: UUID,
    data: ComercioVerificarRequest,
    admin: AdminUser,
    db: DbSession,
) -> ComercioPrivadoResponse:
    comercio = await services.obtener_comercio_por_id(db, comercio_id)
    comercio = await services.verificar_comercio(
        db, comercio, admin, categoria_id=data.categoria_id
    )
    return ComercioPrivadoResponse.model_validate(comercio)


@router_admin_comercios.post(
    "/{comercio_id}/rechazar",
    response_model=ComercioPrivadoResponse,
    summary="Rechazar comercio",
)
async def admin_rechazar_comercio(
    comercio_id: UUID,
    data: ComercioRechazarRequest,
    admin: AdminUser,
    db: DbSession,
) -> ComercioPrivadoResponse:
    comercio = await services.obtener_comercio_por_id(db, comercio_id)
    comercio = await services.rechazar_comercio(
        db, comercio, admin, data.motivo
    )
    return ComercioPrivadoResponse.model_validate(comercio)


@router_admin_comercios.post(
    "/{comercio_id}/suspender",
    response_model=ComercioPrivadoResponse,
    summary="Suspender comercio",
)
async def admin_suspender_comercio(
    comercio_id: UUID,
    data: ComercioRechazarRequest,
    admin: AdminUser,
    db: DbSession,
) -> ComercioPrivadoResponse:
    comercio = await services.obtener_comercio_por_id(db, comercio_id)
    comercio = await services.suspender_comercio(
        db, comercio, admin, data.motivo
    )
    return ComercioPrivadoResponse.model_validate(comercio)


@router_admin_comercios.post(
    "/{comercio_id}/destacar",
    response_model=ComercioPrivadoResponse,
    summary="Marcar/desmarcar como destacado",
)
async def admin_destacar_comercio(
    comercio_id: UUID,
    data: DestacarRequest,
    admin: AdminUser,
    db: DbSession,
) -> ComercioPrivadoResponse:
    comercio = await services.obtener_comercio_por_id(db, comercio_id)
    comercio = await services.destacar_comercio(
        db, comercio, data.destacado
    )
    return ComercioPrivadoResponse.model_validate(comercio)