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

