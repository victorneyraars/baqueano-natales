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
    orden = await services.obtener_orden(db, orden_id)
    if orden.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    item = await services.agregar_item(db, orden_id, data, user.id)
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
    orden = await services.obtener_orden(db, orden_id)
    if orden.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    item = await services.actualizar_item(db, orden_id, item_id, data)
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
    return [TurnoListItemResponse.model_validate(t) for t in turnos]


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
    return TurnoResponse.model_validate(turno)


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
    return TurnoResponse.model_validate(turno)


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
    return TurnoResponse.model_validate(turno)


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
    return TurnoResponse.model_validate(turno)


# =========================================================
# M3: Turnos - Prestador
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
    return [TurnoListItemResponse.model_validate(t) for t in turnos]


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
    return TurnoResponse.model_validate(turno)


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
    return TurnoResponse.model_validate(turno)


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
    return TurnoResponse.model_validate(turno)


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
    return TurnoResponse.model_validate(turno)


# =========================================================
# M4: Garantias
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
        return GarantiaResponse.model_validate(g)

    g = await services.crear_garantia(db, orden_id, data)
    return GarantiaResponse.model_validate(g)


# =========================================================
# M4: Recordatorios
# =========================================================
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
