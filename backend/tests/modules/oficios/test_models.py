"""Tests de modelos SQLAlchemy de oficios (con DB)."""
import pytest
from uuid import uuid4

from app.modules.oficios.models import (
    EstadoOrden,
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
    Vehiculo,
)


# ------------------------------------------------------------ enums

def test_estado_orden_valores():
    valores = {e.value for e in EstadoOrden}
    assert "ingresado" in valores
    assert "presupuestado" in valores
    assert "entregado" in valores
    assert len(valores) == 10


def test_prioridad_orden_valores():
    valores = {p.value for p in PrioridadOrden}
    assert valores == {"baja", "normal", "alta", "urgente"}


def test_tipo_item_orden_valores():
    valores = {t.value for t in TipoItemOrden}
    assert valores == {"servicio", "repuesto", "mano_obra", "otro"}


def test_tipo_evento_historial_valores():
    valores = {t.value for t in TipoEventoHistorial}
    assert "estado_cambio" in valores
    assert "aprobacion" in valores
    assert "rechazo" in valores


# ------------------------------------------------------------ creacion

@pytest.mark.asyncio
async def test_objetos_servicio_creacion(db, usuario_cliente):
    obj = ObjetoServicio(
        tipo=TipoObjetoServicio.VEHICULO,
        propietario_id=usuario_cliente.id,
        alias="Mi auto",
    )
    db.add(obj)
    await db.flush()
    assert obj.id is not None
    assert obj.activo is True
    assert obj.tipo == TipoObjetoServicio.VEHICULO


@pytest.mark.asyncio
async def test_vehiculo_relacion_objeto(db, objeto_servicio_test):
    v = Vehiculo(
        objeto_servicio_id=objeto_servicio_test.id,
        patente="ABCD12",
        marca="Toyota",
        modelo="Corolla",
        anio=2020,
        tipo_vehiculo=TipoVehiculo.SEDAN,
    )
    db.add(v)
    await db.flush()
    assert v.id is not None
    assert v.tipo_vehiculo == TipoVehiculo.SEDAN
    assert v.kilometraje_actual == 0


@pytest.mark.asyncio
async def test_categoria_mecanica_creacion(db):
    cat = MecanicaCategoriaServicio(
        nombre="Frenos",
        slug="frenos",
        orden=1,
    )
    db.add(cat)
    await db.flush()
    assert cat.id is not None
    assert cat.activo is True


@pytest.mark.asyncio
async def test_repuesto_con_categoria(db, categoria_mecanica):
    r = MecanicaRepuesto(
        nombre="Pastillas",
        marca="Bosch",
        categoria_id=categoria_mecanica.id,
        precio_referencia_clp=15000,
    )
    db.add(r)
    await db.flush()
    assert r.id is not None
    assert r.unidad == "unidad"
    assert r.categoria_id == categoria_mecanica.id


@pytest.mark.asyncio
async def test_orden_trabajo_defaults(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    o = OrdenTrabajo(
        numero="OT-TEST-0001",
        cliente_id=usuario_cliente.id,
        prestador_id=prestador_test.id,
        objeto_servicio_id=objeto_servicio_test.id,
    )
    db.add(o)
    await db.flush()
    assert o.estado == EstadoOrden.INGRESADO
    assert o.prioridad == PrioridadOrden.NORMAL
    assert float(o.total_presupuesto) == 0.0
    assert float(o.total_aprobado) == 0.0


@pytest.mark.asyncio
async def test_orden_item_relacion(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    o = OrdenTrabajo(
        numero="OT-TEST-0002",
        cliente_id=usuario_cliente.id,
        prestador_id=prestador_test.id,
        objeto_servicio_id=objeto_servicio_test.id,
    )
    db.add(o)
    await db.flush()

    it = OrdenItem(
        orden_id=o.id,
        tipo=TipoItemOrden.SERVICIO,
        descripcion="Cambio aceite",
        cantidad=1,
        precio_unitario=25000,
        subtotal=25000,
    )
    db.add(it)
    await db.flush()
    assert it.id is not None
    assert it.aprobado is None
    assert it.orden_id == o.id


@pytest.mark.asyncio
async def test_orden_historial_append_only(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    o = OrdenTrabajo(
        numero="OT-TEST-0003",
        cliente_id=usuario_cliente.id,
        prestador_id=prestador_test.id,
        objeto_servicio_id=objeto_servicio_test.id,
    )
    db.add(o)
    await db.flush()

    ev = OrdenHistorial(
        orden_id=o.id,
        tipo=TipoEventoHistorial.ESTADO_CAMBIO,
        usuario_id=usuario_cliente.id,
        estado_anterior=None,
        estado_nuevo="ingresado",
        contenido={"mensaje": "Orden creada"},
    )
    db.add(ev)
    await db.flush()
    assert ev.id is not None
    assert ev.contenido["mensaje"] == "Orden creada"
