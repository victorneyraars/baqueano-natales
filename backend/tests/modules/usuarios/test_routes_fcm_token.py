"""Tests HTTP del endpoint de registro de token FCM.

Cubre POST /api/v1/usuarios/me/fcm-token:
- 200 + token guardado en DB
- Sobrescribe token previo (modelo single-device)
- 422 si token > 500 chars
- 401 si no hay auth (sin override de get_current_user)
"""
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.db import get_db
from app.main import app
from app.modules.auth.deps import get_current_user


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


@pytest_asyncio.fixture
async def client_sin_auth(db):
    """Cliente HTTP sin override de auth (para testear 401).

    Solo overridea get_db, NO get_current_user. El endpoint deberia
    devolver 401 por falta de Authorization header.
    """

    async def _override_db():
        yield db

    app.dependency_overrides[get_db] = _override_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

    app.dependency_overrides.clear()


async def test_registrar_fcm_token_ok(client, usuario_cliente):
    """POST con token valido -> 200 + token guardado en DB."""
    token = "fcm_token_de_prueba_1234567890"
    r = await client.post(
        "/api/v1/usuarios/me/fcm-token",
        json={"token": token},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert "message" in body
    assert body["token_preview"].startswith("fcm_token_de_prueba")
    # Verificar en DB (el objeto usuario_cliente esta vivo en la sesion)
    assert usuario_cliente.fcm_token == token


async def test_registrar_fcm_token_sobreescribe(client, usuario_cliente):
    """Segundo POST sobrescribe el token anterior (single-device)."""
    r = await client.post(
        "/api/v1/usuarios/me/fcm-token",
        json={"token": "token_viejo"},
    )
    assert r.status_code == 200, r.text
    assert usuario_cliente.fcm_token == "token_viejo"

    r = await client.post(
        "/api/v1/usuarios/me/fcm-token",
        json={"token": "token_nuevo"},
    )
    assert r.status_code == 200, r.text
    assert usuario_cliente.fcm_token == "token_nuevo"


async def test_registrar_fcm_token_muy_largo(client):
    """Token > 500 chars -> 422."""
    token = "x" * 501
    r = await client.post(
        "/api/v1/usuarios/me/fcm-token",
        json={"token": token},
    )
    assert r.status_code == 422, r.text


async def test_registrar_fcm_token_sin_auth(client_sin_auth):
    """POST sin Authorization -> 401."""
    r = await client_sin_auth.post(
        "/api/v1/usuarios/me/fcm-token",
        json={"token": "cualquier_token"},
    )
    assert r.status_code == 401, r.text
