"""Services del modulo oficios (M1: objetos_servicio + vehiculos + catalogos)."""
import logging
from datetime import datetime
from decimal import Decimal
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.auth.models import RolUsuario, Usuario
from app.modules.oficios.models import (
    EstadoOrden,
    EstadoTurno,
    MecanicaCategoriaServicio,
    MecanicaRepuesto,
    ObjetoServicio,
    OrdenHistorial,
    OrdenItem,
    OrdenTrabajo,
    PrioridadOrden,
    TipoEventoHistorial,
    TipoItemOrden,
    TipoObjetoServicio,
    TipoVehiculo,
    Turno,
    Vehiculo,
)
from app.modules.oficios.schemas import (
    MecanicaCategoriaCreate,
    MecanicaCategoriaUpdate,
    MecanicaRepuestoCreate,
    MecanicaRepuestoUpdate,
    VehiculoCreate,
    VehiculoUpdate,
)

logger = logging.getLogger(__name__)


# =========================================================
# Helpers
# =========================================================
def _slugify(texto: str) -> str:
    """Slug basico (sin acentos, lowercase, guiones)."""
    import re
    import unicodedata

    nfkd = unicodedata.normalize("NFKD", texto)
    sin_ac = "".join(c for c in nfkd if not unicodedata.combining(c))
    s = sin_ac.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def _vehiculo_a_response(obj: ObjetoServicio, veh: Vehiculo) -> dict:
    """Combina objeto_servicio + vehiculo en un dict de respuesta."""
    return {
        "objeto_servicio_id": obj.id,
        "alias": obj.alias,
        "notas": obj.notas,
        "activo": obj.activo,
        "created_at": obj.created_at,
        "updated_at": obj.updated_at,
        "patente": veh.patente,
        "vin": veh.vin,
        "marca": veh.marca,
        "modelo": veh.modelo,
        "anio": veh.anio,
        "color": veh.color,
        "tipo_vehiculo": veh.tipo_vehiculo.value,
        "kilometraje_actual": veh.kilometraje_actual,
        "fecha_ultima_revision": veh.fecha_ultima_revision,
    }


# =========================================================
# Vehiculos (cliente)
# =========================================================
async def crear_vehiculo(
    db: AsyncSession,
    usuario: Usuario,
    data: VehiculoCreate,
) -> dict:
    """Crea objeto_servicio (tipo=vehiculo) + vehiculo en una transaccion."""
    # Validar patente unica
    existente = (
        await db.execute(
            select(Vehiculo).where(Vehiculo.patente == data.patente.upper())
        )
    ).scalar_one_or_none()
    if existente is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"La patente {data.patente} ya esta registrada",
        )

    # Validar tipo_vehiculo
    try:
        tipo = TipoVehiculo(data.tipo_vehiculo)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"tipo_vehiculo invalido: {data.tipo_vehiculo}",
        )

    # 1) Objeto de servicio
    obj = ObjetoServicio(
        tipo=TipoObjetoServicio.VEHICULO,
        propietario_id=usuario.id,
        alias=data.alias,
        notas=data.notas,
    )
    db.add(obj)
    await db.flush()  # para tener obj.id

    # 2) Vehiculo satelite
    veh = Vehiculo(
        objeto_servicio_id=obj.id,
        patente=data.patente.upper(),
        vin=data.vin,
        marca=data.marca,
        modelo=data.modelo,
        anio=data.anio,
        color=data.color,
        tipo_vehiculo=tipo,
        kilometraje_actual=data.kilometraje_actual,
        fecha_ultima_revision=data.fecha_ultima_revision,
    )
    db.add(veh)
    await db.flush()

    return _vehiculo_a_response(obj, veh)


async def listar_mis_vehiculos(db: AsyncSession, usuario: Usuario) -> list[dict]:
    """Lista los vehiculos activos del usuario."""
    stmt = (
        select(ObjetoServicio, Vehiculo)
        .join(Vehiculo, Vehiculo.objeto_servicio_id == ObjetoServicio.id)
        .where(
            ObjetoServicio.propietario_id == usuario.id,
            ObjetoServicio.tipo == TipoObjetoServicio.VEHICULO,
            ObjetoServicio.activo.is_(True),
        )
        .order_by(ObjetoServicio.created_at.desc())
    )
    rows = (await db.execute(stmt)).all()
    return [_vehiculo_a_response(obj, veh) for obj, veh in rows]


async def _obtener_objeto_propietario(
    db: AsyncSession,
    usuario: Usuario,
    objeto_id: UUID,
) -> tuple[ObjetoServicio, Vehiculo]:
    """Carga objeto+vehiculo validando permisos (propietario o admin)."""
    stmt = (
        select(ObjetoServicio, Vehiculo)
        .join(Vehiculo, Vehiculo.objeto_servicio_id == ObjetoServicio.id)
        .where(
            ObjetoServicio.id == objeto_id,
            ObjetoServicio.activo.is_(True),
        )
    )
    row = (await db.execute(stmt)).one_or_none()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehiculo no encontrado",
        )
    obj, veh = row
    if usuario.rol != RolUsuario.ADMIN and obj.propietario_id != usuario.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso sobre este vehiculo",
        )
    return obj, veh


async def obtener_mi_vehiculo(
    db: AsyncSession, usuario: Usuario, objeto_id: UUID
) -> dict:
    obj, veh = await _obtener_objeto_propietario(db, usuario, objeto_id)
    return _vehiculo_a_response(obj, veh)


async def actualizar_vehiculo(
    db: AsyncSession,
    usuario: Usuario,
    objeto_id: UUID,
    data: VehiculoUpdate,
) -> dict:
    obj, veh = await _obtener_objeto_propietario(db, usuario, objeto_id)

    # Actualizar campos del objeto_servicio
    if data.alias is not None:
        obj.alias = data.alias
    if data.notas is not None:
        obj.notas = data.notas

    # Actualizar campos del vehiculo
    if data.vin is not None:
        veh.vin = data.vin
    if data.marca is not None:
        veh.marca = data.marca
    if data.modelo is not None:
        veh.modelo = data.modelo
    if data.anio is not None:
        veh.anio = data.anio
    if data.color is not None:
        veh.color = data.color
    if data.tipo_vehiculo is not None:
        try:
            veh.tipo_vehiculo = TipoVehiculo(data.tipo_vehiculo)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"tipo_vehiculo invalido: {data.tipo_vehiculo}",
            )
    if data.kilometraje_actual is not None:
        veh.kilometraje_actual = data.kilometraje_actual
    if data.fecha_ultima_revision is not None:
        veh.fecha_ultima_revision = data.fecha_ultima_revision

    await db.flush()
    return _vehiculo_a_response(obj, veh)


async def eliminar_vehiculo(
    db: AsyncSession, usuario: Usuario, objeto_id: UUID
) -> None:
    """Soft delete: marca el objeto_servicio como inactivo."""
    obj, _ = await _obtener_objeto_propietario(db, usuario, objeto_id)
    obj.activo = False
    await db.flush()


# =========================================================
# Mecanica: Categorias (publico + admin)
# =========================================================
async def listar_categorias_mecanica(
    db: AsyncSession, solo_activas: bool = True
) -> list[MecanicaCategoriaServicio]:
    stmt = select(MecanicaCategoriaServicio).order_by(
        MecanicaCategoriaServicio.orden,
        MecanicaCategoriaServicio.nombre,
    )
    if solo_activas:
        stmt = stmt.where(MecanicaCategoriaServicio.activo.is_(True))
    return list((await db.execute(stmt)).scalars().all())


async def crear_categoria_mecanica(
    db: AsyncSession, data: MecanicaCategoriaCreate
) -> MecanicaCategoriaServicio:
    slug = data.slug or _slugify(data.nombre)
    # Validar slug unico
    existente = (
        await db.execute(
            select(MecanicaCategoriaServicio).where(
                MecanicaCategoriaServicio.slug == slug
            )
        )
    ).scalar_one_or_none()
    if existente is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ya existe una categoria con slug '{slug}'",
        )
    obj = MecanicaCategoriaServicio(
        nombre=data.nombre,
        slug=slug,
        descripcion=data.descripcion,
        icono=data.icono,
        color_hex=data.color_hex,
        orden=data.orden,
    )
    db.add(obj)
    await db.flush()
    return obj


async def actualizar_categoria_mecanica(
    db: AsyncSession, cat_id: UUID, data: MecanicaCategoriaUpdate
) -> MecanicaCategoriaServicio:
    obj = (
        await db.execute(
            select(MecanicaCategoriaServicio).where(
                MecanicaCategoriaServicio.id == cat_id
            )
        )
    ).scalar_one_or_none()
    if obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoria no encontrada",
        )
    if data.nombre is not None:
        obj.nombre = data.nombre
    if data.descripcion is not None:
        obj.descripcion = data.descripcion
    if data.icono is not None:
        obj.icono = data.icono
    if data.color_hex is not None:
        obj.color_hex = data.color_hex
    if data.orden is not None:
        obj.orden = data.orden
    if data.activo is not None:
        obj.activo = data.activo
    await db.flush()
    return obj


# =========================================================
# Mecanica: Repuestos (publico + admin)
# =========================================================
async def listar_repuestos(
    db: AsyncSession,
    busqueda: str | None = None,
    categoria_id: UUID | None = None,
    solo_activos: bool = True,
) -> list[MecanicaRepuesto]:
    stmt = select(MecanicaRepuesto)
    if solo_activos:
        stmt = stmt.where(MecanicaRepuesto.activo.is_(True))
    if categoria_id is not None:
        stmt = stmt.where(MecanicaRepuesto.categoria_id == categoria_id)
    if busqueda:
        like = f"%{busqueda}%"
        stmt = stmt.where(
            MecanicaRepuesto.nombre.ilike(like)
            | MecanicaRepuesto.codigo_oem.ilike(like)
            | MecanicaRepuesto.marca.ilike(like)
        )
    stmt = stmt.order_by(MecanicaRepuesto.nombre).limit(200)
    return list((await db.execute(stmt)).scalars().all())


async def crear_repuesto(
    db: AsyncSession, data: MecanicaRepuestoCreate
) -> MecanicaRepuesto:
    obj = MecanicaRepuesto(**data.model_dump())
    db.add(obj)
    await db.flush()
    return obj


async def actualizar_repuesto(
    db: AsyncSession, rep_id: UUID, data: MecanicaRepuestoUpdate
) -> MecanicaRepuesto:
    obj = (
        await db.execute(
            select(MecanicaRepuesto).where(MecanicaRepuesto.id == rep_id)
        )
    ).scalar_one_or_none()
    if obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Repuesto no encontrado",
        )
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    await db.flush()
    return obj


# =========================================================
# M2: State machine de ordenes
# =========================================================
# Transiciones permitidas por rol.
# Prestador puede mover estados operativos.
# Cliente solo aprueba/rechaza presupuestos.
TRANSICIONES_PRESTADOR = {
    EstadoOrden.INGRESADO: {EstadoOrden.DIAGNOSTICANDO, EstadoOrden.CANCELADO},
    EstadoOrden.DIAGNOSTICANDO: {EstadoOrden.PRESUPUESTADO, EstadoOrden.CANCELADO},
    EstadoOrden.APROBADO: {EstadoOrden.EN_PROCESO, EstadoOrden.CANCELADO},
    EstadoOrden.EN_PROCESO: {EstadoOrden.LISTO, EstadoOrden.CANCELADO},
    EstadoOrden.LISTO: {EstadoOrden.ENTREGADO},
    EstadoOrden.ENTREGADO: {EstadoOrden.GARANTIA},
}

TRANSICIONES_CLIENTE = {
    EstadoOrden.PRESUPUESTADO: {EstadoOrden.APROBADO, EstadoOrden.RECHAZADO},
    EstadoOrden.RECHAZADO: {EstadoOrden.CANCELADO},
}


def _transicion_valida(
    estado_actual: EstadoOrden,
    nuevo_estado: EstadoOrden,
    es_prestador: bool,
) -> bool:
    """Valida si una transicion de estado esta permitida."""
    if es_prestador:
        return nuevo_estado in TRANSICIONES_PRESTADOR.get(estado_actual, set())
    return nuevo_estado in TRANSICIONES_CLIENTE.get(estado_actual, set())


def _calcular_subtotal(cantidad, precio_unitario) -> Decimal:
    return (Decimal(str(cantidad)) * Decimal(str(precio_unitario))).quantize(
        Decimal("0.01")
    )


async def _generar_numero_orden(db: AsyncSession) -> str:
    """Genera numero unico OT-YYYY-NNNN."""
    year = datetime.now().year
    prefix = f"OT-{year}-"
    stmt = select(func.count(OrdenTrabajo.id)).where(
        OrdenTrabajo.numero.like(f"{prefix}%")
    )
    count = (await db.execute(stmt)).scalar_one() or 0
    return f"{prefix}{count + 1:04d}"


async def _recalcular_totales(db: AsyncSession, orden: OrdenTrabajo) -> None:
    """Recalcula total_presupuesto y total_aprobado de la orden."""
    stmt = select(OrdenItem).where(OrdenItem.orden_id == orden.id)
    items = list((await db.execute(stmt)).scalars().all())
    orden.total_presupuesto = sum((i.subtotal for i in items), Decimal("0.00"))
    orden.total_aprobado = sum(
        (i.subtotal for i in items if i.aprobado is True), Decimal("0.00")
    )
    await db.flush()


async def _registrar_evento(
    db: AsyncSession,
    orden_id: UUID,
    tipo: TipoEventoHistorial,
    usuario_id: UUID | None = None,
    estado_anterior: str | None = None,
    estado_nuevo: str | None = None,
    contenido: dict | None = None,
) -> OrdenHistorial:
    """Registra un evento en el timeline (append-only)."""
    ev = OrdenHistorial(
        orden_id=orden_id,
        tipo=tipo,
        usuario_id=usuario_id,
        estado_anterior=estado_anterior,
        estado_nuevo=estado_nuevo,
        contenido=contenido,
    )
    db.add(ev)
    await db.flush()
    return ev


# =========================================================
# M2: Ordenes - Prestador
# =========================================================
async def crear_orden(
    db: AsyncSession,
    prestador_id: UUID,
    usuario_id: UUID,
    data,
) -> OrdenTrabajo:
    """Crea una orden en estado INGRESADO."""
    # Validar cliente existe
    from app.modules.auth.models import Usuario
    cliente = (
        await db.execute(select(Usuario).where(Usuario.id == data.cliente_id))
    ).scalar_one_or_none()
    if cliente is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cliente no encontrado",
        )

    # Validar objeto_servicio existe
    obj = (
        await db.execute(
            select(ObjetoServicio).where(ObjetoServicio.id == data.objeto_servicio_id)
        )
    ).scalar_one_or_none()
    if obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Objeto de servicio no encontrado",
        )

    # Validar prioridad
    try:
        prioridad = PrioridadOrden(data.prioridad)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Prioridad invalida: {data.prioridad}",
        )

    numero = await _generar_numero_orden(db)

    orden = OrdenTrabajo(
        numero=numero,
        cliente_id=data.cliente_id,
        prestador_id=prestador_id,
        objeto_servicio_id=data.objeto_servicio_id,
        estado=EstadoOrden.INGRESADO,
        prioridad=prioridad,
        diagnostico_inicial=data.diagnostico_inicial,
        notas_internas=data.notas_internas,
        notas_cliente=data.notas_cliente,
        fecha_estimada_entrega=data.fecha_estimada_entrega,
        km_ingreso=data.km_ingreso,
    )
    db.add(orden)
    await db.flush()

    await _registrar_evento(
        db, orden.id, TipoEventoHistorial.ESTADO_CAMBIO,
        usuario_id=usuario_id,
        estado_anterior=None,
        estado_nuevo=EstadoOrden.INGRESADO.value,
        contenido={"mensaje": "Orden creada"},
    )

    return orden


async def listar_ordenes_prestador(
    db: AsyncSession,
    prestador_id: UUID,
    estado: str | None = None,
    limit: int = 100,
) -> list[OrdenTrabajo]:
    """Lista ordenes de un prestador (con filtro opcional por estado)."""
    stmt = (
        select(OrdenTrabajo)
        .where(OrdenTrabajo.prestador_id == prestador_id)
        .options(selectinload(OrdenTrabajo.items))
        .order_by(OrdenTrabajo.fecha_ingreso.desc())
        .limit(limit)
    )
    if estado:
        try:
            stmt = stmt.where(OrdenTrabajo.estado == EstadoOrden(estado))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Estado invalido: {estado}",
            )
    return list((await db.execute(stmt)).scalars().all())


async def obtener_orden(
    db: AsyncSession, orden_id: UUID
) -> OrdenTrabajo:
    """Carga una orden con items + historial."""
    stmt = (
        select(OrdenTrabajo)
        .where(OrdenTrabajo.id == orden_id)
        .options(
            selectinload(OrdenTrabajo.items),
            selectinload(OrdenTrabajo.historial),
        )
        .execution_options(populate_existing=True)
    )
    orden = (await db.execute(stmt)).scalar_one_or_none()
    if orden is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Orden no encontrada",
        )
    return orden


async def actualizar_orden(
    db: AsyncSession, orden_id: UUID, data
) -> OrdenTrabajo:
    """Actualiza campos mutables de la orden (solo prestador)."""
    orden = await obtener_orden(db, orden_id)
    for k, v in data.model_dump(exclude_unset=True).items():
        if k == "prioridad" and v is not None:
            try:
                v = PrioridadOrden(v)
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Prioridad invalida: {v}",
                )
        setattr(orden, k, v)
    await db.flush()
    return orden


# =========================================================
# M2: Items
# =========================================================
async def agregar_item(
    db: AsyncSession, orden_id: UUID, data, usuario_id: UUID
) -> OrdenItem:
    """Agrega un item al presupuesto."""
    orden = await obtener_orden(db, orden_id)

    # Solo se pueden agregar items en estados iniciales (antes de presupuestar)
    if orden.estado not in (EstadoOrden.INGRESADO, EstadoOrden.DIAGNOSTICANDO):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"No se pueden agregar items en estado '{orden.estado.value}'",
        )

    try:
        tipo = TipoItemOrden(data.tipo)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Tipo invalido: {data.tipo}",
        )

    subtotal = _calcular_subtotal(data.cantidad, data.precio_unitario)
    item = OrdenItem(
        orden_id=orden_id,
        tipo=tipo,
        descripcion=data.descripcion,
        cantidad=data.cantidad,
        precio_unitario=data.precio_unitario,
        subtotal=subtotal,
        orden_display=data.orden_display,
    )
    db.add(item)
    await db.flush()

    await _recalcular_totales(db, orden)
    return item


async def actualizar_item(
    db: AsyncSession, orden_id: UUID, item_id: UUID, data
) -> OrdenItem:
    orden = await obtener_orden(db, orden_id)
    if orden.estado not in (EstadoOrden.INGRESADO, EstadoOrden.DIAGNOSTICANDO):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"No se pueden editar items en estado '{orden.estado.value}'",
        )

    item = (
        await db.execute(
            select(OrdenItem).where(
                OrdenItem.id == item_id, OrdenItem.orden_id == orden_id
            )
        )
    ).scalar_one_or_none()
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item no encontrado",
        )

    cambios = data.model_dump(exclude_unset=True)
    if "tipo" in cambios and cambios["tipo"] is not None:
        try:
            item.tipo = TipoItemOrden(cambios["tipo"])
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Tipo invalido: {cambios['tipo']}",
            )
    if "descripcion" in cambios and cambios["descripcion"] is not None:
        item.descripcion = cambios["descripcion"]
    if "cantidad" in cambios and cambios["cantidad"] is not None:
        item.cantidad = cambios["cantidad"]
    if "precio_unitario" in cambios and cambios["precio_unitario"] is not None:
        item.precio_unitario = cambios["precio_unitario"]
    if "orden_display" in cambios and cambios["orden_display"] is not None:
        item.orden_display = cambios["orden_display"]

    item.subtotal = _calcular_subtotal(item.cantidad, item.precio_unitario)
    await db.flush()
    await _recalcular_totales(db, orden)
    return item


async def eliminar_item(
    db: AsyncSession, orden_id: UUID, item_id: UUID
) -> None:
    orden = await obtener_orden(db, orden_id)
    if orden.estado not in (EstadoOrden.INGRESADO, EstadoOrden.DIAGNOSTICANDO):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"No se pueden eliminar items en estado '{orden.estado.value}'",
        )

    item = (
        await db.execute(
            select(OrdenItem).where(
                OrdenItem.id == item_id, OrdenItem.orden_id == orden_id
            )
        )
    ).scalar_one_or_none()
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item no encontrado",
        )

    await db.delete(item)
    await db.flush()
    await _recalcular_totales(db, orden)


# =========================================================
# M2: Cambiar estado
# =========================================================
async def cambiar_estado(
    db: AsyncSession,
    orden_id: UUID,
    nuevo_estado_str: str,
    usuario_id: UUID,
    es_prestador: bool,
    motivo: str | None = None,
) -> OrdenTrabajo:
    """Cambia el estado de la orden validando la transicion."""
    orden = await obtener_orden(db, orden_id)

    try:
        nuevo_estado = EstadoOrden(nuevo_estado_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Estado invalido: {nuevo_estado_str}",
        )

    if not _transicion_valida(orden.estado, nuevo_estado, es_prestador):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Transicion invalida: {orden.estado.value} -> {nuevo_estado.value}. "
                f"Rol: {'prestador' if es_prestador else 'cliente'}."
            ),
        )

    estado_anterior = orden.estado.value
    orden.estado = nuevo_estado

    # Registrar fecha_entrega_real cuando pasa a entregado
    if nuevo_estado == EstadoOrden.ENTREGADO:
        from datetime import timezone
        orden.fecha_entrega_real = datetime.now(timezone.utc)

    await db.flush()

    await _registrar_evento(
        db,
        orden.id,
        TipoEventoHistorial.ESTADO_CAMBIO,
        usuario_id=usuario_id,
        estado_anterior=estado_anterior,
        estado_nuevo=nuevo_estado.value,
        contenido={"motivo": motivo} if motivo else None,
    )

    return orden


# =========================================================
# M2: Aprobar/rechazar presupuesto (cliente)
# =========================================================
async def aprobar_presupuesto(
    db: AsyncSession,
    orden_id: UUID,
    usuario_id: UUID,
    data,
) -> OrdenTrabajo:
    """El cliente aprueba total o parcialmente el presupuesto."""
    orden = await obtener_orden(db, orden_id)

    if orden.estado != EstadoOrden.PRESUPUESTADO:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"La orden debe estar en 'presupuestado'. Actual: {orden.estado.value}",
        )

    if data.aprobar_todos:
        # Aprobar todos los items
        for item in orden.items:
            item.aprobado = True
    elif data.items:
        # Aprobar/rechazar items especificos
        item_ids = {str(i.item_id) for i in data.items}
        for it in orden.items:
            if str(it.id) in item_ids:
                match = next(x for x in data.items if str(x.item_id) == str(it.id))
                it.aprobado = match.aprobado
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe especificar aprobar_todos=true o lista de items",
        )

    await db.flush()
    await _recalcular_totales(db, orden)

    # Determinar nuevo estado
    todos_aprobados = all(i.aprobado is True for i in orden.items)
    algun_aprobado = any(i.aprobado is True for i in orden.items)

    if todos_aprobados and orden.items:
        orden.estado = EstadoOrden.APROBADO
        tipo_evento = TipoEventoHistorial.APROBACION
        msg = "Presupuesto aprobado en su totalidad"
    elif algun_aprobado:
        # Aprobacion parcial -> sigue en presupuestado (para que el prestador re-cotice)
        tipo_evento = TipoEventoHistorial.APROBACION
        msg = "Presupuesto aprobado parcialmente"
    else:
        orden.estado = EstadoOrden.RECHAZADO
        tipo_evento = TipoEventoHistorial.RECHAZO
        msg = "Presupuesto rechazado"

    await db.flush()

    await _registrar_evento(
        db,
        orden.id,
        tipo_evento,
        usuario_id=usuario_id,
        estado_anterior=EstadoOrden.PRESUPUESTADO.value,
        estado_nuevo=orden.estado.value,
        contenido={
            "mensaje": msg,
            "motivo_rechazo": data.motivo_rechazo,
            "total_aprobado": str(orden.total_aprobado),
        },
    )

    return orden


# =========================================================
# M2: Listar ordenes del cliente
# =========================================================
async def listar_mis_ordenes_cliente(
    db: AsyncSession,
    cliente_id: UUID,
    estado: str | None = None,
    limit: int = 100,
) -> list[OrdenTrabajo]:
    """Lista ordenes de un cliente."""
    stmt = (
        select(OrdenTrabajo)
        .where(OrdenTrabajo.cliente_id == cliente_id)
        .options(selectinload(OrdenTrabajo.items))
        .order_by(OrdenTrabajo.fecha_ingreso.desc())
        .limit(limit)
    )
    if estado:
        try:
            stmt = stmt.where(OrdenTrabajo.estado == EstadoOrden(estado))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Estado invalido: {estado}",
            )
    return list((await db.execute(stmt)).scalars().all())


# =========================================================
# M2+: Busqueda de clientes y vehiculos (para crear ordenes)
# =========================================================
async def buscar_clientes(
    db: AsyncSession,
    query: str,
    limit: int = 20,
) -> list:
    """Busca usuarios con rol CLIENTE por email, nombre o apellido.

    Query minima de 2 chars. Devuelve hasta `limit` resultados.
    Excluye usuarios inactivos.
    """
    from app.modules.auth.models import Usuario

    if not query or len(query.strip()) < 2:
        return []

    like = f"%{query.strip()}%"
    stmt = (
        select(Usuario)
        .where(
            Usuario.rol == RolUsuario.CLIENTE,
            Usuario.activo.is_(True),
        )
        .where(
            Usuario.email.ilike(like)
            | Usuario.nombre.ilike(like)
            | Usuario.apellido.ilike(like)
        )
        .order_by(Usuario.nombre, Usuario.apellido)
        .limit(limit)
    )
    return list((await db.execute(stmt)).scalars().all())


async def listar_vehiculos_de_cliente(
    db: AsyncSession,
    cliente_id: UUID,
) -> list[dict]:
    """Lista los vehiculos de un cliente (sin validar permisos).

    La validacion de permisos (que el caller sea prestador o admin) se hace
    en el endpoint. Este service solo consulta.
    """
    stmt = (
        select(ObjetoServicio, Vehiculo)
        .join(Vehiculo, Vehiculo.objeto_servicio_id == ObjetoServicio.id)
        .where(
            ObjetoServicio.propietario_id == cliente_id,
            ObjetoServicio.tipo == TipoObjetoServicio.VEHICULO,
            ObjetoServicio.activo.is_(True),
        )
        .order_by(ObjetoServicio.created_at.desc())
    )
    rows = (await db.execute(stmt)).all()
    return [_vehiculo_a_response(obj, veh) for obj, veh in rows]


# =========================================================
# M3: Turnos (agenda cliente-prestador)
# =========================================================
# Transiciones validas por rol.
TRANSICIONES_TURNO_PRESTADOR = {
    EstadoTurno.PENDIENTE: {EstadoTurno.CONFIRMADO, EstadoTurno.RECHAZADO},
    EstadoTurno.CONFIRMADO: {
        EstadoTurno.EN_CURSO,
        EstadoTurno.CANCELADO,
        EstadoTurno.NO_ASISTIO,
    },
    EstadoTurno.EN_CURSO: {EstadoTurno.COMPLETADO, EstadoTurno.CANCELADO},
}

TRANSICIONES_TURNO_CLIENTE = {
    EstadoTurno.PENDIENTE: {EstadoTurno.CANCELADO},
    EstadoTurno.CONFIRMADO: {EstadoTurno.CANCELADO},
}


def _transicion_turno_valida(
    actual: EstadoTurno,
    nuevo: EstadoTurno,
    es_prestador: bool,
) -> bool:
    """Valida si una transicion de turno esta permitida por rol."""
    if es_prestador:
        return nuevo in TRANSICIONES_TURNO_PRESTADOR.get(actual, set())
    return nuevo in TRANSICIONES_TURNO_CLIENTE.get(actual, set())


async def crear_turno(
    db: AsyncSession,
    cliente_id: UUID,
    data,
) -> Turno:
    """Crea un turno nuevo en estado PENDIENTE."""
    # Validar que el prestador exista
    from app.modules.prestadores.models import Prestador
    prestador = (
        await db.execute(
            select(Prestador).where(Prestador.id == data.prestador_id)
        )
    ).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prestador no encontrado",
        )

    # Validar que el objeto_servicio exista y sea del cliente
    obj = (
        await db.execute(
            select(ObjetoServicio).where(ObjetoServicio.id == data.objeto_servicio_id)
        )
    ).scalar_one_or_none()
    if obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Objeto de servicio no encontrado",
        )
    if obj.propietario_id != cliente_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El objeto de servicio no es tuyo",
        )

    turno = Turno(
        cliente_id=cliente_id,
        prestador_id=data.prestador_id,
        objeto_servicio_id=data.objeto_servicio_id,
        fecha_inicio=data.fecha_inicio,
        duracion_min=data.duracion_min,
        estado=EstadoTurno.PENDIENTE,
        motivo=data.motivo,
        notas_cliente=data.notas_cliente,
    )
    db.add(turno)
    await db.flush()
    return turno


async def listar_turnos_cliente(
    db: AsyncSession,
    cliente_id: UUID,
    estado: str | None = None,
    desde: datetime | None = None,
    limit: int = 100,
) -> list[Turno]:
    """Lista turnos de un cliente."""
    stmt = (
        select(Turno)
        .where(Turno.cliente_id == cliente_id)
        .order_by(Turno.fecha_inicio.desc())
        .limit(limit)
    )
    if estado:
        try:
            stmt = stmt.where(Turno.estado == EstadoTurno(estado))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Estado invalido: {estado}",
            )
    if desde:
        stmt = stmt.where(Turno.fecha_inicio >= desde)
    return list((await db.execute(stmt)).scalars().all())


async def listar_turnos_prestador(
    db: AsyncSession,
    prestador_id: UUID,
    estado: str | None = None,
    desde: datetime | None = None,
    hasta: datetime | None = None,
    limit: int = 100,
) -> list[Turno]:
    """Lista turnos de un prestador (agenda del taller)."""
    stmt = (
        select(Turno)
        .where(Turno.prestador_id == prestador_id)
        .order_by(Turno.fecha_inicio.asc())
        .limit(limit)
    )
    if estado:
        try:
            stmt = stmt.where(Turno.estado == EstadoTurno(estado))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Estado invalido: {estado}",
            )
    if desde:
        stmt = stmt.where(Turno.fecha_inicio >= desde)
    if hasta:
        stmt = stmt.where(Turno.fecha_inicio <= hasta)
    return list((await db.execute(stmt)).scalars().all())


async def obtener_turno(db: AsyncSession, turno_id: UUID) -> Turno:
    """Carga un turno o lanza 404."""
    turno = (
        await db.execute(select(Turno).where(Turno.id == turno_id))
    ).scalar_one_or_none()
    if turno is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Turno no encontrado",
        )
    return turno


async def actualizar_turno(
    db: AsyncSession,
    turno_id: UUID,
    cliente_id: UUID,
    data,
) -> Turno:
    """Actualiza un turno (solo cliente dueno y solo en estado pendiente)."""
    turno = await obtener_turno(db, turno_id)
    if turno.cliente_id != cliente_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso sobre este turno",
        )
    if turno.estado != EstadoTurno.PENDIENTE:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Solo se puede editar un turno pendiente. Estado actual: {turno.estado.value}",
        )
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(turno, k, v)
    await db.flush()
    return turno


async def cambiar_estado_turno(
    db: AsyncSession,
    turno_id: UUID,
    nuevo_estado_str: str,
    usuario_id: UUID,
    es_prestador: bool,
) -> Turno:
    """Cambia el estado de un turno validando la transicion por rol."""
    turno = await obtener_turno(db, turno_id)

    try:
        nuevo_estado = EstadoTurno(nuevo_estado_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Estado invalido: {nuevo_estado_str}",
        )

    if not _transicion_turno_valida(turno.estado, nuevo_estado, es_prestador):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Transicion invalida: {turno.estado.value} -> {nuevo_estado.value}. "
                f"Rol: {'prestador' if es_prestador else 'cliente'}."
            ),
        )

    turno.estado = nuevo_estado
    await db.flush()
    return turno


async def rechazar_turno(
    db: AsyncSession,
    turno_id: UUID,
    prestador_id: UUID,
    motivo: str | None = None,
) -> Turno:
    """Rechaza un turno pendiente (prestador)."""
    turno = await obtener_turno(db, turno_id)
    if turno.prestador_id != prestador_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso",
        )
    if turno.estado != EstadoTurno.PENDIENTE:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Solo se puede rechazar un turno pendiente. Actual: {turno.estado.value}",
        )
    turno.estado = EstadoTurno.RECHAZADO
    if motivo:
        turno.notas_prestador = motivo
    await db.flush()
    return turno


async def cancelar_turno(
    db: AsyncSession,
    turno_id: UUID,
    usuario_id: UUID,
    es_prestador: bool,
    motivo: str | None = None,
) -> Turno:
    """Cancela un turno (cliente o prestador)."""
    turno = await obtener_turno(db, turno_id)

    # Validar pertenencia
    if es_prestador:
        # El caller debe ser dueno del prestador
        from app.modules.prestadores.models import Prestador
        prestador = (
            await db.execute(
                select(Prestador).where(Prestador.id == turno.prestador_id)
            )
        ).scalar_one_or_none()
        if prestador is None or prestador.usuario_id != usuario_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tenes permiso",
            )
    else:
        if turno.cliente_id != usuario_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tenes permiso",
            )

    if turno.estado in (
        EstadoTurno.CANCELADO,
        EstadoTurno.RECHAZADO,
        EstadoTurno.COMPLETADO,
        EstadoTurno.NO_ASISTIO,
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"No se puede cancelar un turno en estado {turno.estado.value}",
        )

    turno.estado = EstadoTurno.CANCELADO
    if motivo:
        if es_prestador:
            turno.notas_prestador = motivo
        else:
            turno.notas_cliente = motivo
    await db.flush()
    return turno


async def vincular_orden_a_turno(
    db: AsyncSession,
    turno_id: UUID,
    orden_id: UUID,
    prestador_id: UUID,
) -> Turno:
    """Vincula una orden existente al turno (prestador)."""
    turno = await obtener_turno(db, turno_id)
    if turno.prestador_id != prestador_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso",
        )
    # Validar que la orden exista y sea del mismo prestador
    orden = (
        await db.execute(
            select(OrdenTrabajo).where(OrdenTrabajo.id == orden_id)
        )
    ).scalar_one_or_none()
    if orden is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Orden no encontrada",
        )
    if orden.prestador_id != prestador_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="La orden no pertenece a este taller",
        )
    turno.orden_id = orden_id
    await db.flush()
    return turno
