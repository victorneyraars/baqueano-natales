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
from ._serializers import _serializar_orden

logger = logging.getLogger(__name__)


# =========================================================
# Publico
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

router_mis_ordenes_cliente = APIRouter(
    prefix="/mis-ordenes",
    tags=["oficios-ordenes-cliente"],
)


@router_mis_ordenes_cliente.get(
    "",
    response_model=list[OrdenListItemResponse],
    summary="Listar mis ordenes (cliente)",
)
async def listar_mis_ordenes(
    user: CurrentUser,
    db: DbSession,
    estado: str | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
):
    ordenes = await services.listar_mis_ordenes_cliente(
        db, user.id, estado=estado, limit=limit
    )
    return [_serializar_orden(o, incluir_notas_internas=False) for o in ordenes]


@router_mis_ordenes_cliente.get(
    "/{orden_id}",
    response_model=OrdenTrabajoDetalleResponse,
    summary="Ver detalle de mi orden (cliente)",
)
async def detalle_mi_orden(
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    orden = await services.obtener_orden(db, orden_id)
    if orden.cliente_id != user.id and user.rol != "admin":
        raise HTTPException(status_code=403, detail="No tenes permiso")
    # Sin notas internas para el cliente
    return _serializar_orden(orden, incluir_notas_internas=False, con_historial=True)


@router_mis_ordenes_cliente.post(
    "/{orden_id}/aprobar",
    response_model=OrdenTrabajoResponse,
    summary="Aprobar/rechazar presupuesto (cliente)",
)
async def aprobar_presupuesto(
    orden_id: UUID,
    data: OrdenAprobarRequest,
    user: CurrentUser,
    db: DbSession,
):
    orden = await services.obtener_orden(db, orden_id)
    if orden.cliente_id != user.id and user.rol != "admin":
        raise HTTPException(status_code=403, detail="No tenes permiso")
    orden = await services.aprobar_presupuesto(db, orden_id, user.id, data)
    orden = await services.obtener_orden(db, orden.id)
    return _serializar_orden(orden, incluir_notas_internas=False)


# =========================================================
# M2+: Utilidades del prestador (busqueda para crear ordenes)
# =========================================================

router_turnos_cliente = APIRouter(
    prefix="/mis-turnos",
    tags=["oficios-turnos-cliente"],
)


@router_turnos_cliente.get(
    "",
    response_model=list[TurnoListItemResponse],
    summary="Listar mis turnos (cliente)",
)
async def listar_mis_turnos(
    user: CurrentUser,
    db: DbSession,
    estado: str | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
):
    turnos = await services.listar_turnos_cliente(
        db, user.id, estado=estado, limit=limit
    )
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, turnos)
    return [TurnoListItemResponse(**t) for t in enriquecidos]


@router_turnos_cliente.post(
    "",
    response_model=TurnoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Reservar un turno",
)
async def crear_turno(
    data: TurnoCreate,
    user: CurrentUser,
    db: DbSession,
):
    turno = await services.crear_turno(db, user.id, data)
    await db.refresh(turno)
    await services._notificar_nuevo_turno_prestador(db, turno)
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, [turno])
    return TurnoResponse(**enriquecidos[0])


@router_turnos_cliente.get(
    "/{turno_id}",
    response_model=TurnoResponse,
    summary="Ver detalle de un turno",
)
async def detalle_mi_turno(
    turno_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    turno = await services.obtener_turno(db, turno_id)
    if turno.cliente_id != user.id and user.rol != "admin":
        raise HTTPException(status_code=403, detail="No tenes permiso")
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, [turno])
    return TurnoResponse(**enriquecidos[0])


@router_turnos_cliente.get(
    "/{turno_id}/media",
    summary="Listar evidencia (fotos/videos) de un turno",
    description=(
        "Devuelve los assets de evidencia del turno que ya fueron "
        "aprobados por el admin. Solo el cliente dueno del turno (o "
        "admin) puede verlos."
    ),
)
async def listar_media_del_turno(
    turno_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    from sqlalchemy import text
    # 1. Validar que el turno exista y sea del cliente
    result = await db.execute(
        text("SELECT cliente_id FROM turnos WHERE id = :id"),
        {"id": str(turno_id)},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(404, "Turno no encontrado")
    if str(row[0]) != str(user.id) and user.rol != "admin":
        raise HTTPException(403, "No tenes permiso para ver este turno")

    # 2. Traer assets aprobados
    result = await db.execute(
        text("""
            SELECT id, tipo, fase, url_publica, descripcion, created_at
            FROM media_assets
            WHERE entidad_tipo = 'turno'
              AND entidad_id = :turno_id
              AND estado_moderacion = 'aprobado'
              AND activo = true
            ORDER BY
              CASE fase
                WHEN 'ingreso' THEN 1
                WHEN 'diagnostico' THEN 2
                WHEN 'en_proceso' THEN 3
                WHEN 'entrega' THEN 4
                WHEN 'reclamo' THEN 5
                ELSE 6
              END,
              created_at ASC
        """),
        {"turno_id": str(turno_id)},
    )
    rows = result.fetchall()
    items = []
    for r in rows:
        items.append({
            "id": str(r[0]),
            "tipo": r[1],
            "fase": r[2],
            "url_publica": r[3],
            "descripcion": r[4],
            "created_at": r[5].isoformat() if r[5] else None,
        })
    return {"items": items, "total": len(items)}


@router_turnos_cliente.patch(
    "/{turno_id}",
    response_model=TurnoResponse,
    summary="Editar un turno (solo pendientes)",
)
async def editar_mi_turno(
    turno_id: UUID,
    data: TurnoUpdate,
    user: CurrentUser,
    db: DbSession,
):
    turno = await services.actualizar_turno(db, turno_id, user.id, data)
    await db.refresh(turno)
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, [turno])
    return TurnoResponse(**enriquecidos[0])


@router_turnos_cliente.post(
    "/{turno_id}/cancelar",
    response_model=TurnoResponse,
    summary="Cancelar un turno (cliente)",
)
async def cancelar_mi_turno(
    turno_id: UUID,
    data: TurnoCancelarRequest,
    user: CurrentUser,
    db: DbSession,
):
    turno = await services.cancelar_turno(
        db, turno_id, user.id, es_prestador=False, motivo=data.motivo
    )
    await db.refresh(turno)
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, [turno])
    return TurnoResponse(**enriquecidos[0])


# =========================================================
# M3: Turnos - Prestador
# =========================================================

router_garantias_cliente = APIRouter(
    prefix="/mis-ordenes/{orden_id}/garantia",
    tags=["oficios-garantias-cliente"],
)


@router_garantias_cliente.get(
    "",
    response_model=GarantiaResponse | None,
    summary="Ver garantia de mi orden",
)
async def ver_garantia_mi_orden(
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    orden = await services.obtener_orden(db, orden_id)
    if orden.cliente_id != user.id and user.rol != "admin":
        raise HTTPException(status_code=403, detail="No tenes permiso")
    g = await services.obtener_garantia_de_orden(db, orden_id)
    return GarantiaResponse.model_validate(g) if g else None

router_recordatorios = APIRouter(
    prefix="/mis-vehiculos/{objeto_id}/recordatorios",
    tags=["oficios-recordatorios"],
)


async def _validar_objeto_del_usuario(db, objeto_id: UUID, user):
    obj = (
        await db.execute(
            select(ObjetoServicio).where(ObjetoServicio.id == objeto_id)
        )
    ).scalar_one_or_none()
    if obj is None:
        raise HTTPException(status_code=404, detail="Vehiculo no encontrado")
    if obj.propietario_id != user.id and user.rol != "admin":
        raise HTTPException(status_code=403, detail="No tenes permiso")
    return obj


async def _validar_recordatorio_del_usuario(db, objeto_id: UUID, rec_id: UUID):
    rec = (
        await db.execute(
            select(Recordatorio).where(
                Recordatorio.id == rec_id,
                Recordatorio.objeto_servicio_id == objeto_id,
            )
        )
    ).scalar_one_or_none()
    if rec is None:
        raise HTTPException(status_code=404, detail="Recordatorio no encontrado")
    return rec


@router_recordatorios.get(
    "",
    response_model=list[RecordatorioResponse],
    summary="Listar mis recordatorios de un vehiculo",
)
async def listar_recordatorios(
    objeto_id: UUID,
    user: CurrentUser,
    db: DbSession,
    incluir_enviados: bool = Query(False),
):
    await _validar_objeto_del_usuario(db, objeto_id, user)
    recs = await services.listar_recordatorios_de_objeto(
        db, objeto_id, incluir_enviados=incluir_enviados
    )
    return [RecordatorioResponse.model_validate(r) for r in recs]


@router_recordatorios.post(
    "",
    response_model=RecordatorioResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear recordatorio",
)
async def crear_recordatorio_endpoint(
    objeto_id: UUID,
    data: RecordatorioCreate,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_objeto_del_usuario(db, objeto_id, user)
    # Forzar que el objeto sea el del path
    if data.objeto_servicio_id != objeto_id:
        raise HTTPException(
            status_code=400,
            detail="objeto_servicio_id no coincide con el path",
        )
    rec = await services.crear_recordatorio(db, data)
    await db.refresh(rec)
    return RecordatorioResponse.model_validate(rec)


@router_recordatorios.patch(
    "/{recordatorio_id}",
    response_model=RecordatorioResponse,
    summary="Actualizar recordatorio",
)
async def actualizar_recordatorio_endpoint(
    objeto_id: UUID,
    recordatorio_id: UUID,
    data: RecordatorioUpdate,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_objeto_del_usuario(db, objeto_id, user)
    rec = await _validar_recordatorio_del_usuario(db, objeto_id, recordatorio_id)
    if data.condicion is not None:
        rec.condicion = data.condicion
    if data.mensaje is not None:
        rec.mensaje = data.mensaje
    await db.flush()
    return RecordatorioResponse.model_validate(rec)


@router_recordatorios.delete(
    "/{recordatorio_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar recordatorio",
)
async def eliminar_recordatorio_endpoint(
    objeto_id: UUID,
    recordatorio_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_objeto_del_usuario(db, objeto_id, user)
    await _validar_recordatorio_del_usuario(db, objeto_id, recordatorio_id)
    await services.eliminar_recordatorio(db, recordatorio_id)

