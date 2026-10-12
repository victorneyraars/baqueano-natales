"""Tests HTTP del endpoint de preferencias de notificacion.

Cubre:
- GET /api/v1/usuarios/me/preferencias-notificacion (crea defaults)
- PUT /api/v1/usuarios/me/preferencias-notificacion (parcial y total)
- Validaciones (quiet_hours formato HH:MM)
- 401 sin auth
"""
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.db import get_db
from app.main import app
from app.modules.auth.deps import get_current_user


@pytest_asyncio.fixture
async def client(db, usuario_cliente):
    """Cliente HTTP con auth override."""

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


@pytest_asyncio.fixture
async def client_sin_auth(db):
    """Cliente HTTP sin override de auth (para 401)."""

    async def _override_db():
        yield db

    app.dependency_overrides[get_db] = _override_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

    app.dependency_overrides.clear()


async def test_get_preferencias_crea_default(client):
    """GET crea defaults: recordatorios=True, promociones=False, quiet off."""
    r = await client.get("/api/v1/usuarios/me/preferencias-notificacion")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["recordatorios"] is True
    assert body["promociones"] is False  # opt-in
    assert body["confirmaciones"] is True
    assert body["sistema"] is True
    assert body["quiet_hours_enabled"] is False
    assert body["timezone"] == "America/Santiago"


async def test_put_preferencias_parcial(client):
    """PUT con 1 campo solo actualiza ese campo."""
    # Primero GET para crear
    await client.get("/api/v1/usuarios/me/preferencias-notificacion")

    r = await client.put(
        "/api/v1/usuarios/me/preferencias-notificacion",
        json={"promociones": True},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["promociones"] is True
    # Los demas siguen en default
    assert body["recordatorios"] is True
    assert body["confirmaciones"] is True


async def test_put_preferencias_todas(client):
    """PUT con todos los campos actualiza todo."""
    r = await client.put(
        "/api/v1/usuarios/me/preferencias-notificacion",
        json={
            "recordatorios": False,
            "promociones": True,
            "confirmaciones": True,
            "sistema": False,
            "quiet_hours_enabled": True,
            "quiet_hours_inicio": "22:00",
            "quiet_hours_fin": "08:00",
            "timezone": "America/Santiago",
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["recordatorios"] is False
    assert body["promociones"] is True
    assert body["sistema"] is False
    assert body["quiet_hours_enabled"] is True
    assert body["quiet_hours_inicio"] == "22:00"
    assert body["quiet_hours_fin"] == "08:00"


async def test_put_preferencias_persiste(client):
    """PUT persiste: GET posterior devuelve los cambios."""
    await client.put(
        "/api/v1/usuarios/me/preferencias-notificacion",
        json={"promociones": True},
    )
    r = await client.get("/api/v1/usuarios/me/preferencias-notificacion")
    assert r.status_code == 200, r.text
    assert r.json()["promociones"] is True


async def test_put_preferencias_formato_hora_invalido(client):
    """quiet_hours_inicio debe ser HH:MM. Formato invalido -> 422."""
    r = await client.put(
        "/api/v1/usuarios/me/preferencias-notificacion",
        json={"quiet_hours_inicio": "25:99"},
    )
    assert r.status_code == 422, r.text


async def test_put_preferencias_hora_invalida_letras(client):
    """quiet_hours_inicio con letras -> 422."""
    r = await client.put(
        "/api/v1/usuarios/me/preferencias-notificacion",
        json={"quiet_hours_inicio": "abc"},
    )
    assert r.status_code == 422, r.text


async def test_get_preferencias_sin_auth(client_sin_auth):
    """Sin Authorization -> 401."""
    r = await client_sin_auth.get("/api/v1/usuarios/me/preferencias-notificacion")
    assert r.status_code == 401, r.text
