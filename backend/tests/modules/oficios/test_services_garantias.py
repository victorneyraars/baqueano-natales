"""Tests de services de garantias + recordatorios (con DB)."""
import pytest
from datetime import date, timedelta
from uuid import uuid4

from fastapi import HTTPException

from app.modules.oficios import services
from app.modules.oficios.models import EstadoOrden, TipoGarantia, TipoRecordatorio
from app.modules.oficios.schemas import (
    GarantiaCreate,
    GarantiaUpdate,
    OrdenItemCreate,
    OrdenTrabajoCreate,
    RecordatorioCreate,
    RecordatorioUpdate,
)


async def _orden_entregada(db, cliente, prestador, objeto):
    """Helper: crea una orden y la lleva hasta ENTREGADO."""
    orden = await services.crear_orden(
        db, prestador.id, cliente.id,
        OrdenTrabajoCreate(
            cliente_id=cliente.id,
            objeto_servicio_id=objeto.id,
        ),
    )
    await db.flush()

    # Item + presupuestar
    await services.agregar_item(
        db, orden.id,
        OrdenItemCreate(descripcion="A", cantidad=1, precio_unitario=1000),
        cliente.id,
    )
    await db.flush()
    await services.cambiar_estado(db, orden.id, "diagnosticando", cliente.id, es_prestador=True)
    await services.cambiar_estado(db, orden.id, "presupuestado", cliente.id, es_prestador=True)
    await db.flush()
    # Aprobar
    from app.modules.oficios.schemas import OrdenAprobarRequest
    await services.aprobar_presupuesto(
        db, orden.id, cliente.id, OrdenAprobarRequest(aprobar_todos=True),
    )
    await db.flush()
    # Ejecutar hasta entregado
    await services.cambiar_estado(db, orden.id, "en_proceso", cliente.id, es_prestador=True)
    await services.cambiar_estado(db, orden.id, "listo", cliente.id, es_prestador=True)
    await services.cambiar_estado(db, orden.id, "entregado", cliente.id, es_prestador=True)
    await db.flush()

    return await services.obtener_orden(db, orden.id)


# ------------------------------------------------------------ auto-generacion

@pytest.mark.asyncio
async def test_auto_generacion_al_entregar(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await _orden_entregada(
        db, usuario_cliente, prestador_test, objeto_servicio_test
    )
    assert orden.estado == EstadoOrden.ENTREGADO

    g = await services.obtener_garantia_de_orden(db, orden.id)
    assert g is not None
    assert g.tipo == TipoGarantia.COMPLETO
    assert g.duracion_dias == 30
    assert g.fecha_fin == date.today() + timedelta(days=30)
    assert g.activo is True


@pytest.mark.asyncio
async def test_auto_generacion_idempotente(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await _orden_entregada(
        db, usuario_cliente, prestador_test, objeto_servicio_test
    )
    g1 = await services.obtener_garantia_de_orden(db, orden.id)

    # Llamar de nuevo
    g2 = await services.generar_garantia_automatica(db, orden.id)
    assert g1.id == g2.id  # no se duplica


# ------------------------------------------------------------ crear manual

@pytest.mark.asyncio
async def test_crear_garantia_manual(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await _orden_entregada(
        db, usuario_cliente, prestador_test, objeto_servicio_test
    )
    # Borrar la auto-generada para testear la manual
    g_auto = await services.obtener_garantia_de_orden(db, orden.id)
    g_auto.activo = False
    await db.flush()

    data = GarantiaCreate(
        tipo="mano_obra",
        duracion_dias=90,
        cobertura="Solo mano de obra",
        condiciones="No cubre repuestos",
    )
    g = await services.crear_garantia(db, orden.id, data)
    await db.flush()

    assert g.tipo == TipoGarantia.MANO_OBRA
    assert g.duracion_dias == 90
    assert g.fecha_fin == date.today() + timedelta(days=90)


@pytest.mark.asyncio
async def test_crear_garantia_orden_no_entregada_409(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    # Orden en INGRESADO
    orden = await services.crear_orden(
        db, prestador_test.id, usuario_cliente.id,
        OrdenTrabajoCreate(
            cliente_id=usuario_cliente.id,
            objeto_servicio_id=objeto_servicio_test.id,
        ),
    )
    await db.flush()

    data = GarantiaCreate()
    with pytest.raises(HTTPException) as exc:
        await services.crear_garantia(db, orden.id, data)
    assert exc.value.status_code == 409


# ------------------------------------------------------------ actualizar

@pytest.mark.asyncio
async def test_actualizar_garantia_recalcula_fecha_fin(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    orden = await _orden_entregada(
        db, usuario_cliente, prestador_test, objeto_servicio_test
    )
    g = await services.obtener_garantia_de_orden(db, orden.id)

    upd = GarantiaUpdate(duracion_dias=180, condiciones="Solo por defecto de fabrica")
    g2 = await services.actualizar_garantia(db, g.id, upd)
    assert g2.duracion_dias == 180
    assert g2.fecha_fin == g2.fecha_inicio + timedelta(days=180)


# ------------------------------------------------------------ recordatorios

@pytest.mark.asyncio
async def test_crear_recordatorio_km(
    db, usuario_cliente, objeto_servicio_test
):
    data = RecordatorioCreate(
        objeto_servicio_id=objeto_servicio_test.id,
        tipo="km",
        condicion={"km_umbral": 10000},
        mensaje="Cambio de aceite a los 10k km",
    )
    r = await services.crear_recordatorio(db, data)
    await db.flush()

    assert r.tipo == TipoRecordatorio.KM
    assert r.condicion["km_umbral"] == 10000
    assert r.enviado is False


@pytest.mark.asyncio
async def test_crear_recordatorio_fecha(
    db, usuario_cliente, objeto_servicio_test
):
    data = RecordatorioCreate(
        objeto_servicio_id=objeto_servicio_test.id,
        tipo="fecha",
        condicion={"fecha": "2027-03-15"},
        mensaje="Revision anual",
    )
    r = await services.crear_recordatorio(db, data)
    assert r.tipo == TipoRecordatorio.FECHA


@pytest.mark.asyncio
async def test_crear_recordatorio_objeto_inexistente_404(db):
    data = RecordatorioCreate(
        objeto_servicio_id=uuid4(),
        tipo="km",
        condicion={"km_umbral": 1000},
        mensaje="X",
    )
    with pytest.raises(HTTPException) as exc:
        await services.crear_recordatorio(db, data)
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_listar_recordatorios(
    db, usuario_cliente, objeto_servicio_test
):
    for i in range(3):
        await services.crear_recordatorio(db, RecordatorioCreate(
            objeto_servicio_id=objeto_servicio_test.id,
            tipo="km",
            condicion={"km_umbral": 1000 * (i + 1)},
            mensaje=f"Rec {i}",
        ))
    await db.flush()

    recs = await services.listar_recordatorios_de_objeto(
        db, objeto_servicio_test.id
    )
    assert len(recs) == 3


@pytest.mark.asyncio
async def test_marcar_recordatorio_enviado(
    db, usuario_cliente, objeto_servicio_test
):
    r = await services.crear_recordatorio(db, RecordatorioCreate(
        objeto_servicio_id=objeto_servicio_test.id,
        tipo="km",
        condicion={"km_umbral": 5000},
        mensaje="X",
    ))
    await db.flush()

    r2 = await services.marcar_recordatorio_enviado(db, r.id)
    assert r2.enviado is True
    assert r2.fecha_envio is not None


@pytest.mark.asyncio
async def test_eliminar_recordatorio(
    db, usuario_cliente, objeto_servicio_test
):
    r = await services.crear_recordatorio(db, RecordatorioCreate(
        objeto_servicio_id=objeto_servicio_test.id,
        tipo="km",
        condicion={"km_umbral": 5000},
        mensaje="X",
    ))
    await db.flush()

    await services.eliminar_recordatorio(db, r.id)
    await db.flush()

    recs = await services.listar_recordatorios_de_objeto(
        db, objeto_servicio_test.id
    )
    assert len(recs) == 0


@pytest.mark.asyncio
async def test_buscar_recordatorios_pendientes(
    db, usuario_cliente, objeto_servicio_test
):
    for i in range(4):
        await services.crear_recordatorio(db, RecordatorioCreate(
            objeto_servicio_id=objeto_servicio_test.id,
            tipo="km",
            condicion={"km_umbral": 1000 * (i + 1)},
            mensaje=f"Rec {i}",
        ))
    await db.flush()

    pendientes = await services.buscar_recordatorios_pendientes(db)
    assert len(pendientes) == 4

    # Marcar uno como enviado
    await services.marcar_recordatorio_enviado(db, pendientes[0].id)
    await db.flush()

    pendientes2 = await services.buscar_recordatorios_pendientes(db)
    assert len(pendientes2) == 3
