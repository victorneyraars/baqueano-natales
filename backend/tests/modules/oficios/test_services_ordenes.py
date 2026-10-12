"""Tests de services de ordenes de trabajo (con DB)."""
import pytest
from fastapi import HTTPException

from app.modules.oficios import services
from app.modules.oficios.models import (
    EstadoOrden,
    MecanicaCategoriaServicio,
    OrdenTrabajo,
)
from app.modules.oficios.schemas import (
    OrdenAprobarItemRequest,
    OrdenAprobarRequest,
    OrdenItemCreate,
    OrdenTrabajoCreate,
    OrdenTrabajoUpdate,
)


# ------------------------------------------------------------ crear orden

@pytest.mark.asyncio
async def test_crear_orden_ok(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    data = OrdenTrabajoCreate(
        cliente_id=usuario_cliente.id,
        objeto_servicio_id=objeto_servicio_test.id,
        diagnostico_inicial="Ruido en suspension",
        prioridad="normal",
        km_ingreso=30000,
    )
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id, data
    )
    await db.flush()

    assert orden.id is not None
    assert orden.numero.startswith("OT-")
    assert orden.estado == EstadoOrden.INGRESADO
    assert orden.km_ingreso == 30000


@pytest.mark.asyncio
async def test_crear_orden_cliente_inexistente_404(
    db, prestador_test, objeto_servicio_test
):
    from uuid import uuid4
    data = OrdenTrabajoCreate(
        cliente_id=uuid4(),
        objeto_servicio_id=objeto_servicio_test.id,
    )
    with pytest.raises(HTTPException) as exc:
        await services.crear_orden(
            db, prestador_test.id, uuid4(), data
        )
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_crear_orden_objeto_inexistente_404(
    db, usuario_cliente, prestador_test
):
    from uuid import uuid4
    data = OrdenTrabajoCreate(
        cliente_id=usuario_cliente.id,
        objeto_servicio_id=uuid4(),
    )
    with pytest.raises(HTTPException) as exc:
        await services.crear_orden(
            db, prestador_test.id, usuario_cliente.id, data
        )
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_crear_orden_prioridad_invalida_400(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    data = OrdenTrabajoCreate(
        cliente_id=usuario_cliente.id,
        objeto_servicio_id=objeto_servicio_test.id,
        prioridad="super_urgente",
    )
    with pytest.raises(HTTPException) as exc:
        await services.crear_orden(
            db, prestador_test.id, usuario_cliente.id, data
        )
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_numeracion_secuencial(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    nums = []
    for i in range(3):
        data = OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        )
        o = await services.crear_orden(
            db, prestador_test.id, usuario_cliente.id, data
        )
        await db.flush()
        nums.append(o.numero)

    assert nums[0].endswith("0001")
    assert nums[1].endswith("0002")
    assert nums[2].endswith("0003")


# ------------------------------------------------------------ items

@pytest.mark.asyncio
async def test_agregar_item_calcula_subtotal(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    item = await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(
            tipo="servicio", descripcion="Cambio aceite",
            cantidad=2, precio_unitario=25000,
        ),
        usuario_cliente.id,
    )
    await db.flush()

    assert float(item.subtotal) == 50000.0


@pytest.mark.asyncio
async def test_agregar_item_estado_invalido_409(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    # Crear orden y avanzarla a presupuestado (no permite mas items)
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()
    await services.cambiar_estado(
        db, orden.id, "diagnosticando", usuario_cliente.id,
        es_prestador=True,
    )
    await services.cambiar_estado(
        db, orden.id, "presupuestado", usuario_cliente.id,
        es_prestador=True,
    )

    with pytest.raises(HTTPException) as exc:
        await services.agregar_item(
            db, orden.id,
            OrdenItemCreate(descripcion="X"),
            usuario_cliente.id,
        )
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_eliminar_item_recalcula_total(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    it1 = await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="A", cantidad=1, precio_unitario=1000),
        usuario_cliente.id,
    )
    it2 = await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="B", cantidad=1, precio_unitario=2000),
        usuario_cliente.id,
    )
    await db.flush()

    o_recargada = await services.obtener_orden(db, orden.id)
    assert float(o_recargada.total_presupuesto) == 3000.0

    await services.eliminar_item(db, orden.id, it1.id)
    await db.flush()

    o_recargada = await services.obtener_orden(db, orden.id)
    assert float(o_recargada.total_presupuesto) == 2000.0


# ------------------------------------------------------------ cambiar estado

@pytest.mark.asyncio
async def test_cambiar_estado_prestador_ok(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    orden = await services.cambiar_estado(
        db, orden.id, "diagnosticando", usuario_cliente.id,
        es_prestador=True,
    )
    assert orden.estado == EstadoOrden.DIAGNOSTICANDO


@pytest.mark.asyncio
async def test_cambiar_estado_transicion_invalida_409(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    with pytest.raises(HTTPException) as exc:
        await services.cambiar_estado(
            db, orden.id, "entregado", usuario_cliente.id,
            es_prestador=True,
        )
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_cambiar_estado_registra_historial(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    await services.cambiar_estado(
        db, orden.id, "diagnosticando", usuario_cliente.id,
        es_prestador=True,
    )
    await db.flush()

    o = await services.obtener_orden(db, orden.id)
    assert len(o.historial) >= 2  # creacion + cambio estado


# ------------------------------------------------------------ aprobacion

@pytest.mark.asyncio
async def test_aprobar_todos_pasa_a_aprobado(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="A", cantidad=1, precio_unitario=1000),
        usuario_cliente.id,
    )
    await db.flush()

    await services.cambiar_estado(
        db, orden.id, "diagnosticando", usuario_cliente.id,
        es_prestador=True,
    )
    await services.cambiar_estado(
        db, orden.id, "presupuestado", usuario_cliente.id,
        es_prestador=True,
    )
    await db.flush()

    orden = await services.aprobar_presupuesto(
        db, orden.id, usuario_cliente.id,
        OrdenAprobarRequest(aprobar_todos=True),
    )
    assert orden.estado == EstadoOrden.APROBADO
    assert float(orden.total_aprobado) == 1000.0


@pytest.mark.asyncio
async def test_aprobar_parcial_sigue_presupuestado(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    it1 = await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="A", cantidad=1, precio_unitario=1000),
        usuario_cliente.id,
    )
    it2 = await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="B", cantidad=1, precio_unitario=2000),
        usuario_cliente.id,
    )
    await db.flush()

    await services.cambiar_estado(
        db, orden.id, "diagnosticando", usuario_cliente.id,
        es_prestador=True,
    )
    await services.cambiar_estado(
        db, orden.id, "presupuestado", usuario_cliente.id,
        es_prestador=True,
    )
    await db.flush()

    orden = await services.aprobar_presupuesto(
        db, orden.id, usuario_cliente.id,
        OrdenAprobarRequest(items=[
            OrdenAprobarItemRequest(item_id=it1.id, aprobado=True),
            OrdenAprobarItemRequest(item_id=it2.id, aprobado=False),
        ]),
    )
    assert orden.estado == EstadoOrden.PRESUPUESTADO
    assert float(orden.total_aprobado) == 1000.0


@pytest.mark.asyncio
async def test_rechazar_todos_pasa_a_rechazado(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    it1 = await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="A", cantidad=1, precio_unitario=1000),
        usuario_cliente.id,
    )
    await db.flush()

    await services.cambiar_estado(
        db, orden.id, "diagnosticando", usuario_cliente.id,
        es_prestador=True,
    )
    await services.cambiar_estado(
        db, orden.id, "presupuestado", usuario_cliente.id,
        es_prestador=True,
    )
    await db.flush()

    orden = await services.aprobar_presupuesto(
        db, orden.id, usuario_cliente.id,
        OrdenAprobarRequest(items=[
            OrdenAprobarItemRequest(item_id=it1.id, aprobado=False),
        ]),
    )
    assert orden.estado == EstadoOrden.RECHAZADO


@pytest.mark.asyncio
async def test_aprobar_en_estado_incorrecto_409(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    with pytest.raises(HTTPException) as exc:
        await services.aprobar_presupuesto(
            db, orden.id, usuario_cliente.id,
            OrdenAprobarRequest(aprobar_todos=True),
        )
    assert exc.value.status_code == 409


# ------------------------------------------------------------ listados

@pytest.mark.asyncio
async def test_listar_ordenes_prestador(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    for i in range(3):
        await services.crear_orden(
            db, prestador_test.id, usuario_cliente.id,
            OrdenTrabajoCreate(
                cliente_id=usuario_cliente.id,
                objeto_servicio_id=objeto_servicio_test.id,
            ),
        )
    await db.flush()

    ordenes = await services.listar_ordenes_prestador(db, prestador_test.id)
    assert len(ordenes) == 3


@pytest.mark.asyncio
async def test_listar_ordenes_prestador_filtro_estado(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    o1 = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    await services.cambiar_estado(
        db, o1.id, "diagnosticando", usuario_cliente.id,
        es_prestador=True,
    )
    await db.flush()

    solo_diag = await services.listar_ordenes_prestador(
        db, prestador_test.id, estado="diagnosticando"
    )
    assert len(solo_diag) == 1


@pytest.mark.asyncio
async def test_listar_mis_ordenes_cliente(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    for i in range(2):
        await services.crear_orden(
            db, prestador_test.id, usuario_cliente.id,
            OrdenTrabajoCreate(
                cliente_id=usuario_cliente.id,
                objeto_servicio_id=objeto_servicio_test.id,
            ),
        )
    await db.flush()

    ordenes = await services.listar_mis_ordenes_cliente(db, usuario_cliente.id)
    assert len(ordenes) == 2


# ------------------------------------------------------------ workflow completo

@pytest.mark.asyncio
async def test_workflow_completo_end_to_end(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    """Ciclo completo: crear -> items -> presupuestar -> aprobar -> ejecutar."""
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    # 3 items
    await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="Servicio", cantidad=2, precio_unitario=45000),
        usuario_cliente.id,
    )
    await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="Repuesto", cantidad=2, precio_unitario=85000),
        usuario_cliente.id,
    )
    await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="Mano obra", cantidad=1, precio_unitario=35000),
        usuario_cliente.id,
    )
    await db.flush()

    # Avanzar a presupuestado
    await services.cambiar_estado(
        db, orden.id, "diagnosticando", usuario_cliente.id, es_prestador=True
    )
    await services.cambiar_estado(
        db, orden.id, "presupuestado", usuario_cliente.id, es_prestador=True
    )
    await db.flush()

    o = await services.obtener_orden(db, orden.id)
    assert float(o.total_presupuesto) == 295000.0

    # Aprobar todos
    o = await services.aprobar_presupuesto(
        db, orden.id, usuario_cliente.id,
        OrdenAprobarRequest(aprobar_todos=True),
    )
    assert o.estado == EstadoOrden.APROBADO

    # Ejecucion
    await services.cambiar_estado(
        db, orden.id, "en_proceso", usuario_cliente.id, es_prestador=True
    )
    await services.cambiar_estado(
        db, orden.id, "listo", usuario_cliente.id, es_prestador=True
    )
    await services.cambiar_estado(
        db, orden.id, "entregado", usuario_cliente.id, es_prestador=True
    )
    await db.flush()

    o = await services.obtener_orden(db, orden.id)
    assert o.estado == EstadoOrden.ENTREGADO
    assert o.fecha_entrega_real is not None
    assert len(o.historial) >= 7  # creacion + 3 items? no, items no van a historial. Son estados.
