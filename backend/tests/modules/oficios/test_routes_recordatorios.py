"""Tests HTTP de los endpoints de recordatorios.

Regresion del bug 3a5941b: `_validar_objeto_del_usuario` usaba
`ObjetoServicio` sin importarlo, y los 3 endpoints de recordatorios
(GET x2 + POST) fallaban con NameError. Los tests unitarios de
`services.*` no lo detectaron porque nunca ejecutan `routes.py`.

Patron de auth: se overridean `get_current_user` Y `get_db` para que
la app use la MISMA sesion async que el fixture `db`. Sin el override
de `get_db`, la app abre su propia sesion en otro event loop y
SQLAlchemy/asyncpg explota con "Event loop is closed".
"""
from datetime import datetime, timezone
from uuid import uuid4

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.db import get_db
from app.main import app
from app.modules.auth.deps import get_current_user
from app.modules.auth.models import RolUsuario, Usuario
from app.modules.oficios.models import (
    ObjetoServicio,
    Recordatorio,
    TipoObjetoServicio,
)


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


async def test_listar_recordatorios_vacio(client, objeto_servicio_test):
    """GET -> 200 con lista vacia."""
    r = await client.get(
        f"/api/v1/mis-vehiculos/{objeto_servicio_test.id}/recordatorios"
    )
    assert r.status_code == 200, r.text
    assert r.json() == []


async def test_crear_recordatorio_km(client, objeto_servicio_test):
    """POST -> 201 + aparece en la lista."""
    payload = {
        "objeto_servicio_id": str(objeto_servicio_test.id),
        "tipo": "km",
        "mensaje": "Cambio de aceite a 10.000 km",
        "condicion": {"km_umbral": 10000},
    }
    r = await client.post(
        f"/api/v1/mis-vehiculos/{objeto_servicio_test.id}/recordatorios",
        json=payload,
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["tipo"] == "km"
    assert body["mensaje"] == payload["mensaje"]
    assert body["enviado"] is False

    r2 = await client.get(
        f"/api/v1/mis-vehiculos/{objeto_servicio_test.id}/recordatorios"
    )
    assert r2.status_code == 200
    assert len(r2.json()) == 1
    assert r2.json()[0]["id"] == body["id"]


async def test_listar_con_incluir_enviados(client, db, objeto_servicio_test):
    """GET con incluir_enviados=true incluye los ya enviados."""
    rec = Recordatorio(
        objeto_servicio_id=objeto_servicio_test.id,
        tipo="km",
        mensaje="Ya enviado",
        condicion={"km_umbral": 5000},
        enviado=True,
        fecha_envio=datetime.now(timezone.utc),
    )
    db.add(rec)
    await db.flush()

    r1 = await client.get(
        f"/api/v1/mis-vehiculos/{objeto_servicio_test.id}/recordatorios?incluir_enviados=false"
    )
    assert r1.status_code == 200, r1.text
    assert r1.json() == []

    r2 = await client.get(
        f"/api/v1/mis-vehiculos/{objeto_servicio_test.id}/recordatorios?incluir_enviados=true"
    )
    assert r2.status_code == 200, r2.text
    assert len(r2.json()) == 1


async def test_crear_recordatorio_validacion(client, objeto_servicio_test):
    """POST con tipo invalido -> 400 (validacion de negocio, no de schema).

    El backend valida el tipo en el service y devuelve 400, no 422.
    Si en el futuro se migra a un enum de Pydantic, este assert pasara
    a 422.
    """
    r = await client.post(
        f"/api/v1/mis-vehiculos/{objeto_servicio_test.id}/recordatorios",
        json={
            "objeto_servicio_id": str(objeto_servicio_test.id),
            "tipo": "invalido",
            "mensaje": "x",
            "condicion": {},
        },
    )
    assert r.status_code == 400, r.text
    assert "invalido" in r.text.lower()


async def test_crear_recordatorio_objeto_ajeno(
    client, db, usuario_cliente, objeto_servicio_test
):
    """Usuario A no puede crear recordatorio en objeto de usuario B."""
    otro = Usuario(
        firebase_uid=f"otro_{uuid4().hex[:12]}",
        email=f"otro_{uuid4().hex[:8]}@test.com",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(otro)
    await db.flush()

    obj_ajeno = ObjetoServicio(
        tipo=TipoObjetoServicio.VEHICULO,
        propietario_id=otro.id,
        alias="Ajeno",
    )
    db.add(obj_ajeno)
    await db.flush()

    r = await client.post(
        f"/api/v1/mis-vehiculos/{obj_ajeno.id}/recordatorios",
        json={
            "objeto_servicio_id": str(obj_ajeno.id),
            "tipo": "km",
            "mensaje": "x",
            "condicion": {"km_umbral": 1},
        },
    )
    assert r.status_code in (403, 404), r.text
