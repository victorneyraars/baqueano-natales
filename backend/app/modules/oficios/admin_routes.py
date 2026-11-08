"""Endpoints HTTP del modulo oficios (M1)."""
import logging
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status

from sqlalchemy import select

from app.core.db import DbSession
from app.modules.auth.deps import AdminUser, CurrentUser
from app.modules.oficios import services
from app.modules.oficios.deps import CategoriaMecanica, OrdenDelUsuario, Repuesto
from app.modules.oficios.models import EstadoOrden, EstadoTurno, ObjetoServicio
from app.modules.oficios.schemas import (
    ClienteBusquedaResponse,
    GarantiaCreate,
    GarantiaResponse,
    GarantiaUpdate,
    RecordatorioCreate,
    RecordatorioResponse,
    RecordatorioUpdate,
    TurnoCambiarEstadoRequest,
    TurnoCancelarRequest,
    TurnoCreate,
    TurnoListItemResponse,
    TurnoRechazarRequest,
    TurnoCompletarRequest,
    TurnoResponse,
    TurnoUpdate,
    TurnoVincularOrdenRequest,
    MecanicaCategoriaCreate,
    MecanicaCategoriaResponse,
    MecanicaCategoriaUpdate,
    MecanicaRepuestoCreate,
    MecanicaRepuestoResponse,
    MecanicaRepuestoUpdate,
    OrdenAprobarRequest,
    OrdenCambiarEstadoRequest,
    OrdenItemCreate,
    OrdenItemResponse,
    OrdenItemUpdate,
    OrdenListItemResponse,
    OrdenTrabajoCreate,
    OrdenTrabajoDetalleResponse,
    OrdenTrabajoResponse,
    OrdenTrabajoUpdate,
    VehiculoCreate,
    VehiculoResponse,
    VehiculoUpdate,
)

logger = logging.getLogger(__name__)


# =========================================================
# Publico
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
    await db.refresh(obj)
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
    await db.refresh(obj)
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
    await db.refresh(obj)
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
    await db.refresh(obj)
    return MecanicaRepuestoResponse.model_validate(obj)


# =========================================================
# M2: Ordenes - Prestador
# =========================================================


router_admin_ordenes = APIRouter(
    prefix="/admin/oficios/ordenes",
    tags=["oficios-admin-ordenes"],
)

@router_admin_ordenes.get("", response_model=list[OrdenListItemResponse])
async def listar_ordenes_admin(
    user: AdminUser,
    db: DbSession,
    estado: str | None = Query(None),
):
    """Lista todas las ordenes de mecanica (solo admins)."""
    from ._serializers import _serializar_orden
    ordenes = await services.listar_todas_ordenes_admin(db, estado)
    return [_serializar_orden(o) for o in ordenes]


@router_admin_ordenes.get("/{orden_id}", response_model=OrdenTrabajoDetalleResponse)
async def detalle_orden_admin(
    orden_id: UUID,
    user: AdminUser,
    db: DbSession,
):
    """Detalle completo de una orden con historial (solo admins)."""
    from ._serializers import _serializar_orden
    orden = await services.obtener_orden(db, orden_id)
    if orden is None:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    return _serializar_orden(orden, incluir_notas_internas=True, con_historial=True)
