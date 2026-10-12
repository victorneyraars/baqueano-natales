"""Tests HTTP de los endpoints admin de notificaciones.

Cubre:
- POST /api/v1/admin/notificaciones/enviar (segmentos: todos, rol, usuarios)
- GET /api/v1/admin/notificaciones (historial + filtros)
- GET /api/v1/admin/notificaciones/stats (dashboard)
- 401/403 sin auth / sin rol admin
"""
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.db import get_db
from app.core.notifications.models import (
    EstadoNotificacion,
    NotificationLog,
    TipoNotificacion,
)
from app.main import app
from app.modules.auth.deps import get_current_user
from app.modules.auth.models import RolUsuario, Usuario


@pytest_asyncio.fixture
async def admin_user(db):
    """Usuario con rol ADMIN."""
    user = Usuario(
        firebase_uid=f"admin_{uuid4().hex[:12]}",
        email=f"admin_{uuid4().hex[:8]}@test.com",
        nombre="Admin",
        rol=RolUsuario.ADMIN,
        activo=True,
    )
    db.add(user)
    await db.flush()
    return user


@pytest_asyncio.fixture
async def client_admin(db, admin_user):
    """Cliente HTTP con auth override a admin."""

    async def _override_user():
        return admin_user

    async def _override_db():
        yield db

    app.dependency_overrides[get_current_user] = _override_user
    app.dependency_overrides[get_db] = _override_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def client_no_admin(db, usuario_cliente):
    """Cliente HTTP con auth override a cliente (no admin)."""

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


async def _crear_notif_log(
    db, usuario_id, estado=EstadoNotificacion.ENVIADA,
    tipo=TipoNotificacion.SISTEMA, titulo="Test",
):
    """Helper: crea un NotificationLog."""
    notif = NotificationLog(
        usuario_id=usuario_id,
        tipo=tipo,
        titulo=titulo,
        body="Body",
        estado=estado,
    )
    db.add(notif)
    await db.flush()
    return notif


# ==================== Envio masivo ====================


async def test_enviar_segmento_todos(client_admin, db, usuario_cliente):
    """POST a segmento=todos -> envia a todos los usuarios activos."""
    # usuario_cliente ya existe (1 user activo + el admin del fixture)
    with patch(
        "app.core.notifications.providers.fcm.messaging.send_each_for_multicast",
    ) as mock_send:
        from unittest.mock import MagicMock
        # Simular 1 success por cada llamada
        def _fake(tokens):
            resp = MagicMock()
            resp.responses = [MagicMock(success=True, message_id="id") for _ in tokens]
            return resp
        mock_send.side_effect = _fake

        r = await client_admin.post(
            "/api/v1/admin/notificaciones/enviar",
            json={
                "titulo": "Broadcast test",
                "body": "Cuerpo del broadcast",
                "tipo": "sistema",
                "segmento": {"tipo": "todos"},
            },
        )

    assert r.status_code == 200, r.text
    body = r.json()
    # Al menos usuario_cliente + admin_user estan activos
    assert body["total"] >= 2


async def test_enviar_segmento_rol(client_admin, db, usuario_cliente):
    """POST a segmento=rol:cliente -> solo clientes."""
    with patch(
        "app.core.notifications.providers.fcm.messaging.send_each_for_multicast",
    ) as mock_send:
        from unittest.mock import MagicMock
        def _fake(tokens):
            resp = MagicMock()
            resp.responses = [MagicMock(success=True, message_id="id") for _ in tokens]
            return resp
        mock_send.side_effect = _fake

        r = await client_admin.post(
            "/api/v1/admin/notificaciones/enviar",
            json={
                "titulo": "Solo clientes",
                "body": "Body",
                "tipo": "promocion",
                "segmento": {"tipo": "rol", "valor": "cliente"},
            },
        )

    assert r.status_code == 200, r.text
    body = r.json()
    # Solo hay 1 cliente (usuario_cliente)
    assert body["total"] >= 1


async def test_enviar_segmento_usuarios(client_admin, db, usuario_cliente):
    """POST a segmento=usuarios -> solo los IDs especificados."""
    with patch(
        "app.core.notifications.providers.fcm.messaging.send_each_for_multicast",
    ) as mock_send:
        from unittest.mock import MagicMock
        def _fake(tokens):
            resp = MagicMock()
            resp.responses = [MagicMock(success=True, message_id="id") for _ in tokens]
            return resp
        mock_send.side_effect = _fake

        r = await client_admin.post(
            "/api/v1/admin/notificaciones/enviar",
            json={
                "titulo": "Individual",
                "body": "Body",
                "tipo": "sistema",
                "segmento": {
                    "tipo": "usuarios",
                    "valor": [str(usuario_cliente.id)],
                },
            },
        )

    assert r.status_code == 200, r.text
    assert r.json()["total"] == 1


async def test_enviar_segmento_usuarios_vacio(client_admin):
    """POST a usuarios=[] -> total=0, sin error."""
    r = await client_admin.post(
        "/api/v1/admin/notificaciones/enviar",
        json={
            "titulo": "Vacio",
            "body": "Body",
            "tipo": "sistema",
            "segmento": {"tipo": "usuarios", "valor": []},
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["total"] == 0
    assert r.json()["enviados"] == 0


async def test_enviar_validacion_titulo_vacio(client_admin):
    """Titulo vacio -> 422."""
    r = await client_admin.post(
        "/api/v1/admin/notificaciones/enviar",
        json={
            "titulo": "",
            "body": "Body",
            "tipo": "sistema",
            "segmento": {"tipo": "todos"},
        },
    )
    assert r.status_code == 422, r.text


async def test_enviar_validacion_segmento_invalido(client_admin):
    """Tipo de segmento invalido -> 422."""
    r = await client_admin.post(
        "/api/v1/admin/notificaciones/enviar",
        json={
            "titulo": "Test",
            "body": "Body",
            "tipo": "sistema",
            "segmento": {"tipo": "invalido"},
        },
    )
    assert r.status_code == 422, r.text


# ==================== Historial ====================


async def test_historial_vacio(client_admin):
    """GET sin logs -> lista vacia."""
    r = await client_admin.get("/api/v1/admin/notificaciones")
    assert r.status_code == 200, r.text
    assert r.json() == []


async def test_historial_con_datos(client_admin, db, usuario_cliente):
    """GET devuelve los logs creados."""
    await _crear_notif_log(db, usuario_cliente.id, titulo="Notif 1")
    await _crear_notif_log(db, usuario_cliente.id, titulo="Notif 2")

    r = await client_admin.get("/api/v1/admin/notificaciones")
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body) >= 2
    titulos = {n["titulo"] for n in body}
    assert "Notif 1" in titulos
    assert "Notif 2" in titulos


async def test_historial_filtro_estado(client_admin, db, usuario_cliente):
    """Filtro por estado funciona."""
    await _crear_notif_log(
        db, usuario_cliente.id, titulo="Enviada",
        estado=EstadoNotificacion.ENVIADA,
    )
    await _crear_notif_log(
        db, usuario_cliente.id, titulo="Fallida",
        estado=EstadoNotificacion.FALLIDA,
    )

    r = await client_admin.get(
        "/api/v1/admin/notificaciones?estado=fallida"
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body) == 1
    assert body[0]["titulo"] == "Fallida"


# ==================== Stats ====================


async def test_stats_vacio(client_admin):
    """GET con 0 logs -> todos los contadores en 0."""
    r = await client_admin.get("/api/v1/admin/notificaciones/stats")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["total"] == 0
    assert body["enviadas"] == 0
    assert body["delivery_rate"] == 0.0
    assert body["open_rate"] == 0.0
    assert body["top_5"] == []


async def test_stats_con_datos(client_admin, db, usuario_cliente):
    """GET con logs -> tasas correctas."""
    # 3 enviadas, 1 abierta -> enviadas=3, entregadas=1, abiertas=1
    await _crear_notif_log(db, usuario_cliente.id, estado=EstadoNotificacion.ENVIADA)
    await _crear_notif_log(db, usuario_cliente.id, estado=EstadoNotificacion.ENVIADA)
    await _crear_notif_log(db, usuario_cliente.id, estado=EstadoNotificacion.ABIERTA)

    r = await client_admin.get("/api/v1/admin/notificaciones/stats")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["total"] == 3
    assert body["enviadas"] == 3  # enviada + abierta cuentan
    assert body["abiertas"] == 1
    assert body["open_rate"] == 1.0  # 1/1 (abiertas / entregadas)
    assert len(body["por_estado"]) >= 1
    assert len(body["por_tipo"]) >= 1


# ==================== Auth ====================


async def test_usuario_no_admin_no_puede_enviar(client_no_admin):
    """Usuario no-admin -> 403."""
    r = await client_no_admin.post(
        "/api/v1/admin/notificaciones/enviar",
        json={
            "titulo": "Test",
            "body": "Body",
            "tipo": "sistema",
            "segmento": {"tipo": "todos"},
        },
    )
    assert r.status_code == 403, r.text


async def test_usuario_no_admin_no_puede_ver_historial(client_no_admin):
    """Usuario no-admin -> 403 en historial."""
    r = await client_no_admin.get("/api/v1/admin/notificaciones")
    assert r.status_code == 403, r.text
