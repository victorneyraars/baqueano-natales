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
router_mis_ordenes = APIRouter(
    prefix="/mis-prestadores/{prestador_id}/ordenes",
    tags=["oficios-ordenes-prestador"],
)


def _serializar_orden(orden, incluir_notas_internas: bool = True, con_historial: bool = False):
    """Convierte ORM -> dict, respetando visibilidad de notas_internas."""
    data = {
        "id": orden.id,
        "numero": orden.numero,
        "cliente_id": orden.cliente_id,
        "prestador_id": orden.prestador_id,
        "objeto_servicio_id": orden.objeto_servicio_id,
        "estado": orden.estado.value,
        "prioridad": orden.prioridad.value,
        "diagnostico_inicial": orden.diagnostico_inicial,
        "notas_cliente": orden.notas_cliente,
        "notas_internas": orden.notas_internas if incluir_notas_internas else None,
        "fecha_ingreso": orden.fecha_ingreso,
        "fecha_estimada_entrega": orden.fecha_estimada_entrega,
        "fecha_entrega_real": orden.fecha_entrega_real,
        "km_ingreso": orden.km_ingreso,
        "km_salida": orden.km_salida,
        "total_presupuesto": orden.total_presupuesto,
        "total_aprobado": orden.total_aprobado,
        "items": [
            {
                "id": it.id,
                "tipo": it.tipo.value,
                "descripcion": it.descripcion,
                "cantidad": it.cantidad,
                "precio_unitario": it.precio_unitario,
                "subtotal": it.subtotal,
                "aprobado": it.aprobado,
                "orden_display": it.orden_display,
            }
            for it in orden.items
        ],
    }
    if con_historial:
        data["historial"] = [
            {
                "id": ev.id,
                "tipo": ev.tipo.value,
                "estado_anterior": ev.estado_anterior,
                "estado_nuevo": ev.estado_nuevo,
                "usuario_id": ev.usuario_id,
                "contenido": ev.contenido,
                "created_at": ev.created_at,
            }
            for ev in orden.historial
        ]
    return data

