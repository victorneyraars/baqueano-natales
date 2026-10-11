"""Endpoints HTTP del modulo oficios (M1)."""
import logging
from uuid import UUID

from fastapi import APIRouter, Query, status

from app.core.db import DbSession
from app.modules.auth.deps import AdminUser, CurrentUser
from app.modules.oficios import services
from app.modules.oficios.deps import CategoriaMecanica, Repuesto
from app.modules.oficios.schemas import (
    MecanicaCategoriaCreate,
    MecanicaCategoriaResponse,
    MecanicaCategoriaUpdate,
    MecanicaRepuestoCreate,
    MecanicaRepuestoResponse,
    MecanicaRepuestoUpdate,
    VehiculoCreate,
    VehiculoResponse,
    VehiculoUpdate,
)

logger = logging.getLogger(__name__)


# =========================================================
# Publico
# =========================================================
router_publico = APIRouter(prefix="/oficios/mecanica", tags=["oficios-mecanica"])


@router_publico.get(
    "/categorias",
    response_model=list[MecanicaCategoriaResponse],
    summary="Listar categorias de mecanica activas",
)
async def listar_categorias(db: DbSession) -> list[MecanicaCategoriaResponse]:
    cats = await services.listar_categorias_mecanica(db, solo_activas=True)
    return [MecanicaCategoriaResponse.model_validate(c) for c in cats]


@router_publico.get(
    "/repuestos",
    response_model=list[MecanicaRepuestoResponse],
    summary="Buscar repuestos del catalogo",
)
async def listar_repuestos(
    db: DbSession,
    busqueda: str | None = Query(None, max_length=100),
    categoria_id: UUID | None = Query(None),
) -> list[MecanicaRepuestoResponse]:
    reps = await services.listar_repuestos(
        db, busqueda=busqueda, categoria_id=categoria_id, solo_activos=True
    )
    return [MecanicaRepuestoResponse.model_validate(r) for r in reps]


# =========================================================
# Cliente: mis vehiculos
# =========================================================
router_propietario = APIRouter(prefix="/mis-vehiculos", tags=["oficios-mis-vehiculos"])


@router_propietario.get(
    "",
    response_model=list[VehiculoResponse],
    summary="Listar mis vehiculos",
)
async def listar_mis_vehiculos(user: CurrentUser, db: DbSession) -> list[VehiculoResponse]:
    rows = await services.listar_mis_vehiculos(db, user)
    return [VehiculoResponse(**r) for r in rows]


@router_propietario.post(
    "",
    response_model=VehiculoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar un vehiculo",
)
async def crear_vehiculo(
    data: VehiculoCreate, user: CurrentUser, db: DbSession
) -> VehiculoResponse:
    row = await services.crear_vehiculo(db, user, data)
    return VehiculoResponse(**row)


@router_propietario.get(
    "/{objeto_id}",
    response_model=VehiculoResponse,
    summary="Ver detalle de un vehiculo",
)
async def obtener_mi_vehiculo(
    objeto_id: UUID, user: CurrentUser, db: DbSession
) -> VehiculoResponse:
    row = await services.obtener_mi_vehiculo(db, user, objeto_id)
    return VehiculoResponse(**row)


@router_propietario.patch(
    "/{objeto_id}",
    response_model=VehiculoResponse,
    summary="Actualizar un vehiculo",
)
async def actualizar_mi_vehiculo(
    objeto_id: UUID,
    data: VehiculoUpdate,
    user: CurrentUser,
    db: DbSession,
) -> VehiculoResponse:
    row = await services.actualizar_vehiculo(db, user, objeto_id, data)
    return VehiculoResponse(**row)


@router_propietario.delete(
    "/{objeto_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Desactivar un vehiculo",
)
async def eliminar_mi_vehiculo(
    objeto_id: UUID, user: CurrentUser, db: DbSession
) -> None:
    await services.eliminar_vehiculo(db, user, objeto_id)
    return None


# =========================================================
# Admin: categorias mecanica
# =========================================================
router_admin_categorias = APIRouter(
    prefix="/admin/oficios/mecanica/categorias",
    tags=["admin-oficios-mecanica"],
)


@router_admin_categorias.get(
    "",
    response_model=list[MecanicaCategoriaResponse],
    summary="Listar TODAS las categorias (incluye inactivas)",
)
async def admin_listar_categorias(
    admin: AdminUser, db: DbSession
) -> list[MecanicaCategoriaResponse]:
    cats = await services.listar_categorias_mecanica(db, solo_activas=False)
    return [MecanicaCategoriaResponse.model_validate(c) for c in cats]


@router_admin_categorias.post(
    "",
    response_model=MecanicaCategoriaResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear categoria de mecanica",
)
async def admin_crear_categoria(
    data: MecanicaCategoriaCreate, admin: AdminUser, db: DbSession
) -> MecanicaCategoriaResponse:
    obj = await services.crear_categoria_mecanica(db, data)
    return MecanicaCategoriaResponse.model_validate(obj)


@router_admin_categorias.patch(
    "/{categoria_id}",
    response_model=MecanicaCategoriaResponse,
    summary="Actualizar categoria",
)
async def admin_actualizar_categoria(
    categoria: CategoriaMecanica,
    data: MecanicaCategoriaUpdate,
    admin: AdminUser,
    db: DbSession,
) -> MecanicaCategoriaResponse:
    obj = await services.actualizar_categoria_mecanica(db, categoria.id, data)
    return MecanicaCategoriaResponse.model_validate(obj)


# =========================================================
# Admin: repuestos
# =========================================================
router_admin_repuestos = APIRouter(
    prefix="/admin/oficios/mecanica/repuestos",
    tags=["admin-oficios-mecanica"],
)


@router_admin_repuestos.get(
    "",
    response_model=list[MecanicaRepuestoResponse],
    summary="Listar repuestos (incluye inactivos)",
)
async def admin_listar_repuestos(
    admin: AdminUser,
    db: DbSession,
    busqueda: str | None = Query(None, max_length=100),
    categoria_id: UUID | None = Query(None),
) -> list[MecanicaRepuestoResponse]:
    reps = await services.listar_repuestos(
        db, busqueda=busqueda, categoria_id=categoria_id, solo_activos=False
    )
    return [MecanicaRepuestoResponse.model_validate(r) for r in reps]


@router_admin_repuestos.post(
    "",
    response_model=MecanicaRepuestoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear repuesto",
)
async def admin_crear_repuesto(
    data: MecanicaRepuestoCreate, admin: AdminUser, db: DbSession
) -> MecanicaRepuestoResponse:
    obj = await services.crear_repuesto(db, data)
    return MecanicaRepuestoResponse.model_validate(obj)


@router_admin_repuestos.patch(
    "/{repuesto_id}",
    response_model=MecanicaRepuestoResponse,
    summary="Actualizar repuesto",
)
async def admin_actualizar_repuesto(
    repuesto: Repuesto,
    data: MecanicaRepuestoUpdate,
    admin: AdminUser,
    db: DbSession,
) -> MecanicaRepuestoResponse:
    obj = await services.actualizar_repuesto(db, repuesto.id, data)
    return MecanicaRepuestoResponse.model_validate(obj)
