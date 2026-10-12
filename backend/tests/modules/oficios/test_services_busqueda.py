"""Tests de busqueda de clientes y vehiculos (con DB)."""
import pytest
from uuid import uuid4

from app.modules.auth.models import RolUsuario, Usuario
from app.modules.oficios import services
from app.modules.oficios.schemas import VehiculoCreate


# ------------------------------------------------------------ buscar_clientes

@pytest.mark.asyncio
async def test_buscar_clientes_query_corta_vacia(db, usuario_cliente):
    """Query < 2 chars devuelve []."""
    assert await services.buscar_clientes(db, "") == []
    assert await services.buscar_clientes(db, "a") == []


@pytest.mark.asyncio
async def test_buscar_clientes_por_email(db):
    from uuid import uuid4
    u = Usuario(
        firebase_uid=f"b_{uuid4().hex[:12]}",
        email="busqueda_test@test.com",
        nombre="Juan",
        apellido="Perez",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(u)
    await db.flush()

    res = await services.buscar_clientes(db, "busqueda_test")
    assert any(r.email == "busqueda_test@test.com" for r in res)


@pytest.mark.asyncio
async def test_buscar_clientes_por_nombre(db):
    from uuid import uuid4
    u = Usuario(
        firebase_uid=f"n_{uuid4().hex[:12]}",
        email=f"n_{uuid4().hex[:6]}@x.com",
        nombre="Casimiro",
        apellido="Fernandez",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(u)
    await db.flush()

    res = await services.buscar_clientes(db, "Casimiro")
    assert any(r.id == u.id for r in res)


@pytest.mark.asyncio
async def test_buscar_clientes_excluye_inactivos(db):
    from uuid import uuid4
    u = Usuario(
        firebase_uid=f"in_{uuid4().hex[:12]}",
        email="inactivo_test@test.com",
        nombre="Inactivo",
        rol=RolUsuario.CLIENTE,
        activo=False,
    )
    db.add(u)
    await db.flush()

    res = await services.buscar_clientes(db, "inactivo_test")
    assert all(r.id != u.id for r in res)


@pytest.mark.asyncio
async def test_buscar_clientes_excluye_no_clientes(db, usuario_cliente):
    """El usuario_cliente tiene rol CLIENTE, pero admins/prestadores no deben aparecer."""
    from uuid import uuid4
    admin = Usuario(
        firebase_uid=f"adm_{uuid4().hex[:12]}",
        email="busqueda_admin@test.com",
        nombre="AdminBusqueda",
        rol=RolUsuario.ADMIN,
        activo=True,
    )
    db.add(admin)
    await db.flush()

    res = await services.buscar_clientes(db, "busqueda_admin")
    assert all(r.id != admin.id for r in res)


# ------------------------------------------------------------ listar_vehiculos_de_cliente

@pytest.mark.asyncio
async def test_listar_vehiculos_cliente_vacio(db, usuario_cliente):
    rows = await services.listar_vehiculos_de_cliente(db, usuario_cliente.id)
    assert rows == []


@pytest.mark.asyncio
async def test_listar_vehiculos_cliente_con_datos(db, usuario_cliente):
    for pat in ["VEH001", "VEH002"]:
        await services.crear_vehiculo(
            db, usuario_cliente,
            VehiculoCreate(patente=pat, marca="T", modelo="M", anio=2020),
        )
    await db.flush()

    rows = await services.listar_vehiculos_de_cliente(db, usuario_cliente.id)
    assert len(rows) == 2


@pytest.mark.asyncio
async def test_listar_vehiculos_no_incluye_eliminados(db, usuario_cliente):
    creado = await services.crear_vehiculo(
        db, usuario_cliente,
        VehiculoCreate(patente="DELVEH", marca="T", modelo="M", anio=2020),
    )
    await db.flush()
    await services.eliminar_vehiculo(
        db, usuario_cliente, creado["objeto_servicio_id"],
    )
    await db.flush()

    rows = await services.listar_vehiculos_de_cliente(db, usuario_cliente.id)
    assert len(rows) == 0
