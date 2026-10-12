"""Tests HTTP del modulo notificaciones (tracking de entrega/apertura).

Cubre:
- GET /api/v1/notificaciones (listar historial)
- POST /api/v1/notificaciones/{id}/recibida (marcar entregada)
- POST /api/v1/notificaciones/{id}/abierta (marcar abierta, idempotente)
- Ownership (no puedo tocar notif de otro usuario)
"""
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


async def _crear_notif(
    db, usuario_id, titulo="Test",
    estado=EstadoNotificacion.ENVIADA, creado_en=None,
):
    """Helper: crea un NotificationLog para el usuario."""
    kwargs = dict(
        usuario_id=usuario_id,
        tipo=TipoNotificacion.SISTEMA,
        titulo=titulo,
        body="Body de prueba",
        estado=estado,
    )
    if creado_en is not None:
        kwargs["creado_en"] = creado_en
    notif = NotificationLog(**kwargs)
    db.add(notif)
    await db.flush()
    return notif


async def test_listar_notificaciones_vacio(client):
    """GET sin notifs -> lista vacia."""
    r = await client.get("/api/v1/notificaciones")
    assert r.status_code == 200, r.text
    assert r.json() == []


async def test_listar_notificaciones(client, db, usuario_cliente):
    """GET devuelve notifs del usuario, ordenadas por fecha desc.

    Nota: se setean timestamps explicitos porque en el test las dos
    notifs se crean al mismo tiempo (server_default=func.now() da el
    mismo valor para ambas). En produccion esto no pasa.
    """
    from datetime import datetime, timedelta, timezone

    base_time = datetime.now(timezone.utc)
    await _crear_notif(
        db, usuario_cliente.id, titulo="Primera",
        creado_en=base_time - timedelta(hours=1),
    )
    await _crear_notif(
        db, usuario_cliente.id, titulo="Segunda",
        creado_en=base_time,
    )

    r = await client.get("/api/v1/notificaciones")
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body) == 2
    assert body[0]["titulo"] == "Segunda"
    assert body[1]["titulo"] == "Primera"


async def test_marcar_recibida(client, db, usuario_cliente):
    """POST /recibida cambia estado ENVIADA -> ENTREGADA."""
    notif = await _crear_notif(db, usuario_cliente.id)
    r = await client.post(f"/api/v1/notificaciones/{notif.id}/recibida")
    assert r.status_code == 200, r.text
    assert r.json()["estado"] == "entregada"


async def test_marcar_abierta(client, db, usuario_cliente):
    """POST /abierta cambia estado y setea abierto_en."""
    notif = await _crear_notif(db, usuario_cliente.id)
    r = await client.post(f"/api/v1/notificaciones/{notif.id}/abierta")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["estado"] == "abierta"
    assert body["abierto_en"] is not None


async def test_marcar_abierta_idempotente(client, db, usuario_cliente):
    """POST /abierta dos veces -> mismo resultado, no error."""
    notif = await _crear_notif(db, usuario_cliente.id)
    r1 = await client.post(f"/api/v1/notificaciones/{notif.id}/abierta")
    abierto_en_1 = r1.json()["abierto_en"]

    r2 = await client.post(f"/api/v1/notificaciones/{notif.id}/abierta")
    assert r2.status_code == 200, r2.text
    assert r2.json()["estado"] == "abierta"
    assert r2.json()["abierto_en"] == abierto_en_1


async def test_marcar_abierta_notif_ajena(client, db, usuario_cliente):
    """No puedo abrir notif de otro usuario -> 404."""
    otro = Usuario(
        firebase_uid="otro_ajeno",
        email="ajeno@test.com",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(otro)
    await db.flush()
    notif_ajena = await _crear_notif(db, otro.id)

    r = await client.post(f"/api/v1/notificaciones/{notif_ajena.id}/abierta")
    assert r.status_code == 404, r.text


async def test_marcar_abierta_notif_inexistente(client):
    """Notif que no existe -> 404."""
    import uuid
    fake_id = uuid.uuid4()
    r = await client.post(f"/api/v1/notificaciones/{fake_id}/abierta")
    assert r.status_code == 404, r.text
