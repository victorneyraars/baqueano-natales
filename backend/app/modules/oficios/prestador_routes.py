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

router_mis_ordenes = APIRouter(
    prefix="/mis-prestadores/{prestador_id}/ordenes",
    tags=["oficios-ordenes-prestador"],
)


@router_mis_ordenes.get(
    "",
    response_model=list[OrdenListItemResponse],
    summary="Listar ordenes del prestador",
)
async def listar_ordenes_prestador(
    prestador_id: UUID,
    user: CurrentUser,
    db: DbSession,
    estado: str | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
):
    # Validar permiso sobre el prestador
    from app.modules.prestadores.models import Prestador
    prestador = (
        await db.execute(select(Prestador).where(Prestador.id == prestador_id))
    ).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(status_code=404, detail="Prestador no encontrado")
    if user.rol != "admin" and prestador.usuario_id != user.id:
        raise HTTPException(status_code=403, detail="No tenes permiso")

    ordenes = await services.listar_ordenes_prestador(
        db, prestador_id, estado=estado, limit=limit
    )
    return [_serializar_orden(o, incluir_notas_internas=False) for o in ordenes]


@router_mis_ordenes.post(
    "",
    response_model=OrdenTrabajoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear una orden",
)
async def crear_orden(
    prestador_id: UUID,
    data: OrdenTrabajoCreate,
    user: CurrentUser,
    db: DbSession,
):
    from app.modules.prestadores.models import Prestador
    prestador = (
        await db.execute(select(Prestador).where(Prestador.id == prestador_id))
    ).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(status_code=404, detail="Prestador no encontrado")
    if user.rol != "admin" and prestador.usuario_id != user.id:
        raise HTTPException(status_code=403, detail="No tenes permiso")

    orden = await services.crear_orden(db, prestador_id, user.id, data)
    # Recargar con items+historial cargados (evita MissingGreenlet)
    orden = await services.obtener_orden(db, orden.id)
    return _serializar_orden(orden)


@router_mis_ordenes.get(
    "/{orden_id}",
    response_model=OrdenTrabajoDetalleResponse,
    summary="Ver detalle de una orden (con historial)",
)
async def detalle_orden(
    prestador_id: UUID,
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    from app.modules.prestadores.models import Prestador
    await _validar_prestador_del_usuario(db, prestador_id, user, Prestador)
    orden = await services.obtener_orden(db, orden_id)
    if orden.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    return _serializar_orden(orden, con_historial=True)


@router_mis_ordenes.patch(
    "/{orden_id}",
    response_model=OrdenTrabajoResponse,
    summary="Actualizar orden",
)
async def actualizar_orden(
    prestador_id: UUID,
    orden_id: UUID,
    data: OrdenTrabajoUpdate,
    user: CurrentUser,
    db: DbSession,
):
    from app.modules.prestadores.models import Prestador
    await _validar_prestador_del_usuario(db, prestador_id, user, Prestador)
    orden = await services.obtener_orden(db, orden_id)
    if orden.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    orden = await services.actualizar_orden(db, orden_id, data)
    orden = await services.obtener_orden(db, orden.id)
    return _serializar_orden(orden)


@router_mis_ordenes.post(
    "/{orden_id}/items",
    response_model=OrdenItemResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar item al presupuesto",
)
async def agregar_item(
    prestador_id: UUID,
    orden_id: UUID,
    data: OrdenItemCreate,
    user: CurrentUser,
    db: DbSession,
):
    from app.modules.prestadores.models import Prestador
    await _validar_prestador_del_usuario(db, prestador_id, user, Prestador)
    orden = await services.obtener_orden(db, orden_id)
    if orden.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    item = await services.agregar_item(db, orden_id, data, user.id)
    await db.refresh(item)
    return OrdenItemResponse.model_validate(item)


@router_mis_ordenes.patch(
    "/{orden_id}/items/{item_id}",
    response_model=OrdenItemResponse,
    summary="Editar item",
)
async def editar_item(
    prestador_id: UUID,
    orden_id: UUID,
    item_id: UUID,
    data: OrdenItemUpdate,
    user: CurrentUser,
    db: DbSession,
):
    from app.modules.prestadores.models import Prestador
    await _validar_prestador_del_usuario(db, prestador_id, user, Prestador)
    orden = await services.obtener_orden(db, orden_id)
    if orden.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    item = await services.actualizar_item(db, orden_id, item_id, data)
    await db.refresh(item)
    return OrdenItemResponse.model_validate(item)


@router_mis_ordenes.delete(
    "/{orden_id}/items/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar item",
)
async def eliminar_item(
    prestador_id: UUID,
    orden_id: UUID,
    item_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    from app.modules.prestadores.models import Prestador
    await _validar_prestador_del_usuario(db, prestador_id, user, Prestador)
    orden = await services.obtener_orden(db, orden_id)
    if orden.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    await services.eliminar_item(db, orden_id, item_id)


@router_mis_ordenes.post(
    "/{orden_id}/estado",
    response_model=OrdenTrabajoResponse,
    summary="Cambiar estado de la orden",
)
async def cambiar_estado(
    prestador_id: UUID,
    orden_id: UUID,
    data: OrdenCambiarEstadoRequest,
    user: CurrentUser,
    db: DbSession,
):
    from app.modules.prestadores.models import Prestador
    await _validar_prestador_del_usuario(db, prestador_id, user, Prestador)
    orden = await services.obtener_orden(db, orden_id)
    if orden.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    orden = await services.cambiar_estado(
        db, orden_id, data.nuevo_estado, user.id, es_prestador=True, motivo=data.motivo
    )
    orden = await services.obtener_orden(db, orden.id)
    return _serializar_orden(orden)


# =========================================================
# M2: Ordenes - Cliente
# =========================================================

router_prestador_utilidades = APIRouter(
    prefix="/mis-prestadores/{prestador_id}",
    tags=["oficios-prestador-utilidades"],
)


async def _validar_prestador_del_usuario(
    db, prestador_id: UUID, user, prestador_repo
):
    """Valida que el usuario sea dueno del prestador o admin."""
    prestador = (
        await db.execute(
            select(prestador_repo).where(prestador_repo.id == prestador_id)
        )
    ).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(status_code=404, detail="Prestador no encontrado")
    if user.rol != "admin" and prestador.usuario_id != user.id:
        raise HTTPException(status_code=403, detail="No tenes permiso")
    return prestador


@router_prestador_utilidades.get(
    "/clientes",
    response_model=list[ClienteBusquedaResponse],
    summary="Buscar clientes por nombre/email",
)
async def buscar_clientes(
    prestador_id: UUID,
    user: CurrentUser,
    db: DbSession,
    q: str = Query(..., min_length=2, max_length=100),
    limit: int = Query(20, ge=1, le=50),
):
    from app.modules.prestadores.models import Prestador
    await _validar_prestador_del_usuario(db, prestador_id, user, Prestador)

    clientes = await services.buscar_clientes(db, q, limit=limit)
    return [ClienteBusquedaResponse.model_validate(c) for c in clientes]


@router_prestador_utilidades.get(
    "/clientes/{cliente_id}/vehiculos",
    response_model=list[VehiculoResponse],
    summary="Listar vehiculos de un cliente",
)
async def listar_vehiculos_de_cliente(
    prestador_id: UUID,
    cliente_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    from app.modules.prestadores.models import Prestador
    await _validar_prestador_del_usuario(db, prestador_id, user, Prestador)

    rows = await services.listar_vehiculos_de_cliente(db, cliente_id)
    return [VehiculoResponse(**r) for r in rows]


# =========================================================
# M3: Turnos - Cliente
# =========================================================

router_turnos_prestador = APIRouter(
    prefix="/mis-prestadores/{prestador_id}/turnos",
    tags=["oficios-turnos-prestador"],
)


async def _validar_prestador_dueno(db, prestador_id: UUID, user):
    from app.modules.prestadores.models import Prestador
    prestador = (
        await db.execute(select(Prestador).where(Prestador.id == prestador_id))
    ).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(status_code=404, detail="Prestador no encontrado")
    if user.rol != "admin" and prestador.usuario_id != user.id:
        raise HTTPException(status_code=403, detail="No tenes permiso")
    return prestador


@router_turnos_prestador.get(
    "",
    response_model=list[TurnoListItemResponse],
    summary="Listar turnos del taller (agenda)",
)
async def listar_turnos_prestador(
    prestador_id: UUID,
    user: CurrentUser,
    db: DbSession,
    estado: str | None = Query(None),
    desde: datetime | None = Query(None),
    hasta: datetime | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
):
    await _validar_prestador_dueno(db, prestador_id, user)
    turnos = await services.listar_turnos_prestador(
        db, prestador_id, estado=estado, desde=desde, hasta=hasta, limit=limit
    )
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, turnos)
    return [TurnoListItemResponse(**t) for t in enriquecidos]


@router_turnos_prestador.get(
    "/{turno_id}",
    response_model=TurnoResponse,
    summary="Ver detalle de un turno (prestador)",
)
async def detalle_turno_prestador(
    prestador_id: UUID,
    turno_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_prestador_dueno(db, prestador_id, user)
    turno = await services.obtener_turno(db, turno_id)
    if turno.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Turno no encontrado")
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, [turno])
    return TurnoResponse(**enriquecidos[0])


@router_turnos_prestador.post(
    "/{turno_id}/estado",
    response_model=TurnoResponse,
    summary="Cambiar estado (prestador)",
)
async def cambiar_estado_turno(
    prestador_id: UUID,
    turno_id: UUID,
    data: TurnoCambiarEstadoRequest,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_prestador_dueno(db, prestador_id, user)
    turno = await services.obtener_turno(db, turno_id)
    if turno.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Turno no encontrado")
    turno = await services.cambiar_estado_turno(
        db, turno_id, data.nuevo_estado, user.id, es_prestador=True
    )
    await db.refresh(turno)
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, [turno])
    return TurnoResponse(**enriquecidos[0])


@router_turnos_prestador.post(
    "/{turno_id}/completar",
    summary="Completar turno: crea orden con items y entrega (prestador)",
)
async def completar_turno_endpoint(
    prestador_id: UUID,
    turno_id: UUID,
    data: TurnoCompletarRequest,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_prestador_dueno(db, prestador_id, user)
    turno, orden = await services.completar_turno_y_crear_orden(
        db, turno_id, prestador_id, user.id, data,
    )
    return {
        "turno": TurnoResponse.model_validate(turno),
        "orden": OrdenTrabajoResponse.model_validate(orden),
    }


@router_turnos_prestador.post(
    "/{turno_id}/test-push-acciones",
    summary="Test push con botones Aceptar/Rechazar",
)
async def test_push_acciones(
    prestador_id: UUID,
    turno_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_prestador_dueno(db, prestador_id, user)
    turno = await services.obtener_turno(db, turno_id)
    if not turno or turno.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Turno no encontrado")
    await services._notificar_nuevo_turno_prestador(db, turno)
    return {"ok": True}

@router_turnos_prestador.post(
    "/{turno_id}/rechazar",
    response_model=TurnoResponse,
    summary="Rechazar un turno (prestador)",
)
async def rechazar_turno(
    prestador_id: UUID,
    turno_id: UUID,
    data: TurnoRechazarRequest,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_prestador_dueno(db, prestador_id, user)
    turno = await services.rechazar_turno(
        db, turno_id, prestador_id, motivo=data.motivo
    )
    await db.refresh(turno)
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, [turno])
    return TurnoResponse(**enriquecidos[0])


@router_turnos_prestador.post(
    "/{turno_id}/vincular-orden",
    response_model=TurnoResponse,
    summary="Vincular una orden existente al turno",
)
async def vincular_orden(
    prestador_id: UUID,
    turno_id: UUID,
    data: TurnoVincularOrdenRequest,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_prestador_dueno(db, prestador_id, user)
    turno = await services.vincular_orden_a_turno(
        db, turno_id, data.orden_id, prestador_id
    )
    enriquecidos = await services.enriquecer_turnos_con_reviews(db, [turno])
    return TurnoResponse(**enriquecidos[0])


# =========================================================
# M4: Garantias
# =========================================================

router_garantias_prestador = APIRouter(
    prefix="/mis-prestadores/{prestador_id}/ordenes/{orden_id}/garantia",
    tags=["oficios-garantias-prestador"],
)


async def _validar_garantia_prestador(
    db, prestador_id: UUID, orden_id: UUID, user
):
    from app.modules.prestadores.models import Prestador

    prestador = (
        await db.execute(select(Prestador).where(Prestador.id == prestador_id))
    ).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(status_code=404, detail="Prestador no encontrado")
    if user.rol != "admin" and prestador.usuario_id != user.id:
        raise HTTPException(status_code=403, detail="No tenes permiso")

    orden = await services.obtener_orden(db, orden_id)
    if orden.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    return orden


@router_garantias_prestador.get(
    "",
    response_model=GarantiaResponse | None,
    summary="Ver garantia de una orden del taller",
)
async def ver_garantia_orden_prestador(
    prestador_id: UUID,
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_garantia_prestador(db, prestador_id, orden_id, user)
    g = await services.obtener_garantia_de_orden(db, orden_id)
    return GarantiaResponse.model_validate(g) if g else None


@router_garantias_prestador.post(
    "",
    response_model=GarantiaResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear/actualizar garantia manual (solo ordenes entregadas)",
)
async def crear_garantia_orden(
    prestador_id: UUID,
    orden_id: UUID,
    data: GarantiaCreate,
    user: CurrentUser,
    db: DbSession,
):
    await _validar_garantia_prestador(db, prestador_id, orden_id, user)
    existente = await services.obtener_garantia_de_orden(db, orden_id)
    if existente is not None:
        # Actualizar la existente
        upd = GarantiaUpdate(
            tipo=data.tipo,
            duracion_dias=data.duracion_dias,
            cobertura=data.cobertura,
            condiciones=data.condiciones,
        )
        g = await services.actualizar_garantia(db, existente.id, upd)
        await db.refresh(g)
        return GarantiaResponse.model_validate(g)

    g = await services.crear_garantia(db, orden_id, data)
    await db.refresh(g)
    return GarantiaResponse.model_validate(g)


# =========================================================
# M4: Recordatorios
# =========================================================

