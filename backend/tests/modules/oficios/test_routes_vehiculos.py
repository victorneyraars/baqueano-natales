"""Tests HTTP de los endpoints de vehiculos (router_propietario)."""
from uuid import uuid4

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.db import get_db
from app.main import app
from app.modules.auth.deps import get_current_user
from app.modules.auth.models import RolUsuario, Usuario


@pytest_asyncio.fixture
async def client(db, usuario_cliente):
    """Cliente HTTP con get_current_user y get_db overrideados."""

    async def _override_user():
        return usuario_cliente

    async def _override_db():
        yield db

    app.dependency_overrides[get_current_user] = _override_user
    app.dependency_overrides[get_db] = _override_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

    app.dependency_overrides.clear()


def _payload_vehiculo(**overrides) -> dict:
    base = {
        "patente": f"TST{uuid4().hex[:4].upper()}",
        "marca": "Toyota",
        "modelo": "Yaris",
        "anio": 2020,
        "kilometraje_actual": 50000,
        "alias": "Auto test",
    }
    base.update(overrides)
    return base


async def test_listar_mis_vehiculos_vacio(client):
    r = await client.get("/api/v1/mis-vehiculos")
    assert r.status_code == 200, r.text
    assert r.json() == []


async def test_crear_vehiculo(client):
    payload = _payload_vehiculo()
    r = await client.post("/api/v1/mis-vehiculos", json=payload)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["patente"] == payload["patente"]
    assert body["marca"] == payload["marca"]
    assert body["alias"] == payload["alias"]

    r2 = await client.get("/api/v1/mis-vehiculos")
    assert r2.status_code == 200
    assert len(r2.json()) == 1


async def test_detalle_vehiculo(client, vehiculo_test):
    r = await client.get(f"/api/v1/mis-vehiculos/{vehiculo_test.objeto_servicio_id}")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["objeto_servicio_id"] == str(vehiculo_test.objeto_servicio_id)
    assert body["alias"] == "Auto test"


async def test_actualizar_vehiculo(client, vehiculo_test):
    r = await client.patch(
        f"/api/v1/mis-vehiculos/{vehiculo_test.objeto_servicio_id}",
        json={"alias": "Nuevo alias", "kilometraje_actual": 99999},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["alias"] == "Nuevo alias"
    assert body["kilometraje_actual"] == 99999


async def test_eliminar_vehiculo(client, vehiculo_test):
    r = await client.delete(f"/api/v1/mis-vehiculos/{vehiculo_test.objeto_servicio_id}")
    assert r.status_code == 204, r.text
    r2 = await client.get(f"/api/v1/mis-vehiculos/{vehiculo_test.objeto_servicio_id}")
    assert r2.status_code == 404, r2.text


async def _crear_vehiculo_ajeno(db):
    """Helper: crea un usuario "otro" y su vehiculo."""
    from app.modules.oficios import services
    from app.modules.oficios.schemas import VehiculoCreate

    otro = Usuario(
        firebase_uid=f"otro_{uuid4().hex[:12]}",
        email=f"otro_{uuid4().hex[:8]}@test.com",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(otro)
    await db.flush()

    data = VehiculoCreate(
        patente=f"AJN{uuid4().hex[:4].upper()}",
        marca="Honda",
        modelo="Civic",
        anio=2021,
        alias="Ajeno",
    )
    row = await services.crear_vehiculo(db, otro, data)
    return row["objeto_servicio_id"]


async def test_no_puedo_ver_vehiculo_ajeno(client, db):
    ajeno_id = await _crear_vehiculo_ajeno(db)
    r = await client.get(f"/api/v1/mis-vehiculos/{ajeno_id}")
    assert r.status_code in (403, 404), r.text


async def test_no_puedo_editar_vehiculo_ajeno(client, db):
    ajeno_id = await _crear_vehiculo_ajeno(db)
    r = await client.patch(
        f"/api/v1/mis-vehiculos/{ajeno_id}",
        json={"alias": "Hackeado"},
    )
    assert r.status_code in (403, 404), r.text


async def test_no_puedo_eliminar_vehiculo_ajeno(client, db):
    ajeno_id = await _crear_vehiculo_ajeno(db)
    r = await client.delete(f"/api/v1/mis-vehiculos/{ajeno_id}")
    assert r.status_code in (403, 404), r.text


async def test_crear_vehiculo_patente_muy_larga(client):
    r = await client.post(
        "/api/v1/mis-vehiculos",
        json=_payload_vehiculo(patente="ESTAPATENTEESMUYLARGA"),
    )
    assert r.status_code == 422, r.text


async def test_crear_vehiculo_anio_invalido(client):
    r = await client.post(
        "/api/v1/mis-vehiculos",
        json=_payload_vehiculo(anio=1800),
    )
    assert r.status_code == 422, r.text
