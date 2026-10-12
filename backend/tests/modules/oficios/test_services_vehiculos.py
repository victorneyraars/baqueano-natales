"""Tests de services de vehiculos (con DB)."""
import pytest
from fastapi import HTTPException

from app.modules.oficios import services
from app.modules.oficios.schemas import VehiculoCreate, VehiculoUpdate


# ------------------------------------------------------------ crear

@pytest.mark.asyncio
async def test_crear_vehiculo_ok(db, usuario_cliente):
    data = VehiculoCreate(
        patente="ABCD12", marca="Toyota", modelo="Corolla",
        anio=2020, tipo_vehiculo="sedan", kilometraje_actual=50000,
        alias="Mi auto",
    )
    row = await services.crear_vehiculo(db, usuario_cliente, data)
    await db.commit()

    assert row["patente"] == "ABCD12"
    assert row["marca"] == "Toyota"
    assert row["anio"] == 2020
    assert row["tipo_vehiculo"] == "sedan"
    assert row["kilometraje_actual"] == 50000
    assert row["alias"] == "Mi auto"
    assert row["objeto_servicio_id"] is not None


@pytest.mark.asyncio
async def test_crear_vehiculo_patente_minusculas_se_normaliza(db, usuario_cliente):
    data = VehiculoCreate(
        patente="abcd12", marca="T", modelo="M", anio=2020,
    )
    row = await services.crear_vehiculo(db, usuario_cliente, data)
    await db.commit()
    assert row["patente"] == "ABCD12"


@pytest.mark.asyncio
async def test_crear_vehiculo_patente_duplicada_409(db, usuario_cliente):
    data = VehiculoCreate(patente="XYZW99", marca="T", modelo="M", anio=2020)
    await services.crear_vehiculo(db, usuario_cliente, data)
    await db.flush()

    with pytest.raises(HTTPException) as exc:
        await services.crear_vehiculo(db, usuario_cliente, data)
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_crear_vehiculo_tipo_invalido_400(db, usuario_cliente):
    data = VehiculoCreate(
        patente="TIPO01", marca="T", modelo="M", anio=2020,
        tipo_vehiculo="nave_espacial",
    )
    with pytest.raises(HTTPException) as exc:
        await services.crear_vehiculo(db, usuario_cliente, data)
    assert exc.value.status_code == 400


# ------------------------------------------------------------ listar

@pytest.mark.asyncio
async def test_listar_vacio(db, usuario_cliente):
    rows = await services.listar_mis_vehiculos(db, usuario_cliente)
    assert rows == []


@pytest.mark.asyncio
async def test_listar_con_datos(db, usuario_cliente):
    for patente in ["AAA111", "BBB222", "CCC333"]:
        await services.crear_vehiculo(
            db, usuario_cliente,
            VehiculoCreate(patente=patente, marca="T", modelo="M", anio=2020),
        )
    await db.flush()

    rows = await services.listar_mis_vehiculos(db, usuario_cliente)
    assert len(rows) == 3


# ------------------------------------------------------------ obtener

@pytest.mark.asyncio
async def test_obtener_ok(db, usuario_cliente):
    creado = await services.crear_vehiculo(
        db, usuario_cliente,
        VehiculoCreate(patente="OBT001", marca="T", modelo="M", anio=2020),
    )
    await db.flush()

    row = await services.obtener_mi_vehiculo(
        db, usuario_cliente, creado["objeto_servicio_id"]
    )
    assert row["patente"] == "OBT001"


@pytest.mark.asyncio
async def test_obtener_ajeno_403(db, usuario_cliente):
    from app.modules.auth.models import RolUsuario, Usuario
    from uuid import uuid4

    otro = Usuario(
        firebase_uid=f"otro_{uuid4().hex[:12]}",
        email=f"otro_{uuid4().hex[:8]}@x.com",
        rol=RolUsuario.CLIENTE,
    )
    db.add(otro)
    await db.flush()

    creado = await services.crear_vehiculo(
        db, usuario_cliente,
        VehiculoCreate(patente="AJE001", marca="T", modelo="M", anio=2020),
    )
    await db.flush()

    with pytest.raises(HTTPException) as exc:
        await services.obtener_mi_vehiculo(
            db, otro, creado["objeto_servicio_id"]
        )
    assert exc.value.status_code == 403


# ------------------------------------------------------------ actualizar

@pytest.mark.asyncio
async def test_actualizar_ok(db, usuario_cliente):
    creado = await services.crear_vehiculo(
        db, usuario_cliente,
        VehiculoCreate(patente="ACT001", marca="T", modelo="M", anio=2020),
    )
    await db.flush()

    upd = VehiculoUpdate(kilometraje_actual=75000, color="Rojo")
    row = await services.actualizar_vehiculo(
        db, usuario_cliente, creado["objeto_servicio_id"], upd
    )
    assert row["kilometraje_actual"] == 75000
    assert row["color"] == "Rojo"


# ------------------------------------------------------------ eliminar

@pytest.mark.asyncio
async def test_eliminar_soft_delete(db, usuario_cliente):
    creado = await services.crear_vehiculo(
        db, usuario_cliente,
        VehiculoCreate(patente="DEL001", marca="T", modelo="M", anio=2020),
    )
    await db.flush()

    await services.eliminar_vehiculo(
        db, usuario_cliente, creado["objeto_servicio_id"]
    )
    await db.flush()

    rows = await services.listar_mis_vehiculos(db, usuario_cliente)
    assert len(rows) == 0
