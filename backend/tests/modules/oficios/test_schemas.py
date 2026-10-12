"""Tests de schemas Pydantic de oficios (unit, sin DB)."""
import pytest
from pydantic import ValidationError

from app.modules.oficios.schemas import (
    MecanicaCategoriaCreate,
    MecanicaRepuestoCreate,
    OrdenItemCreate,
    OrdenTrabajoCreate,
    VehiculoCreate,
    VehiculoUpdate,
)


# ------------------------------------------------------------ VehiculoCreate

def test_vehiculo_create_minimo_ok():
    v = VehiculoCreate(
        patente="ABCD12",
        marca="Toyota",
        modelo="Corolla",
        anio=2020,
    )
    assert v.patente == "ABCD12"
    assert v.tipo_vehiculo == "otro"
    assert v.kilometraje_actual == 0


def test_vehiculo_create_patente_vacia_falla():
    with pytest.raises(ValidationError):
        VehiculoCreate(patente="", marca="Toyota", modelo="X", anio=2020)


def test_vehiculo_create_anio_fuera_de_rango_falla():
    with pytest.raises(ValidationError):
        VehiculoCreate(patente="ABCD12", marca="T", modelo="X", anio=1800)
    with pytest.raises(ValidationError):
        VehiculoCreate(patente="ABCD12", marca="T", modelo="X", anio=2200)


def test_vehiculo_create_km_negativo_falla():
    with pytest.raises(ValidationError):
        VehiculoCreate(
            patente="ABCD12", marca="T", modelo="X", anio=2020,
            kilometraje_actual=-1,
        )


def test_vehiculo_update_todos_opcionales():
    u = VehiculoUpdate()
    assert u.marca is None
    assert u.anio is None


# ------------------------------------------------------------ OrdenItemCreate

def test_orden_item_create_ok():
    it = OrdenItemCreate(descripcion="Cambio de aceite")
    assert it.tipo == "servicio"
    assert float(it.cantidad) == 1.0
    assert float(it.precio_unitario) == 0.0


def test_orden_item_cantidad_cero_falla():
    with pytest.raises(ValidationError):
        OrdenItemCreate(descripcion="X", cantidad=0)


def test_orden_item_precio_negativo_falla():
    with pytest.raises(ValidationError):
        OrdenItemCreate(descripcion="X", precio_unitario=-100)


# ------------------------------------------------------------ OrdenTrabajoCreate

def test_orden_create_requiere_cliente_y_objeto():
    with pytest.raises(ValidationError):
        OrdenTrabajoCreate(objeto_servicio_id="00000000-0000-0000-0000-000000000000")


# ------------------------------------------------------------ MecanicaCategoria

def test_categoria_create_minimo_ok():
    c = MecanicaCategoriaCreate(nombre="Frenos")
    assert c.nombre == "Frenos"
    assert c.orden == 0


# ------------------------------------------------------------ Repuesto

def test_repuesto_create_ok():
    r = MecanicaRepuestoCreate(nombre="Amortiguador")
    assert r.unidad == "unidad"
