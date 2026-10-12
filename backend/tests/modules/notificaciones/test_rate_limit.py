"""Tests de rate limiting por tipo de notificacion."""
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.db import get_db
from app.core.notifications.models import (
    EstadoNotificacion,
    NotificationLog,
    TipoNotificacion,
)
from app.core.notifications.service import NotificationService
from app.main import app
from app.modules.auth.deps import get_current_user
from app.modules.auth.models import RolUsuario, Usuario


@pytest_asyncio.fixture
async def usuario_test(db):
    user = Usuario(
        firebase_uid=f"rl_{uuid4().hex[:12]}",
        email=f"rl_{uuid4().hex[:8]}@test.com",
        nombre="RateLimit",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(user)
    await db.flush()
    return user


@pytest_asyncio.fixture
async def admin_user(db):
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
async def seed_rate_limits(db):
    """Re-seedea las 5 configs de rate limit al inicio del test.

    Necesario porque el conftest raiz hace drop_all + create_all, que
    recrea la tabla vacia (el seed real corre en la migracion Alembic).
    """
    from sqlalchemy import text

    await db.execute(text("DELETE FROM rate_limit_config"))
    await db.execute(text("""
        INSERT INTO rate_limit_config
            (id, tipo, max_por_hora, max_por_dia, max_por_semana, min_intervalo_seg, strict)
        VALUES
            (gen_random_uuid(), 'sistema',        NULL, NULL, NULL, NULL, false),
            (gen_random_uuid(), 'confirmaciones', NULL, NULL, NULL, NULL, false),
            (gen_random_uuid(), 'recordatorio',   2,    3,    7,    3600, false),
            (gen_random_uuid(), 'promocion',      1,    1,    2,    NULL, false),
            (gen_random_uuid(), 'campana',        1,    1,    3,    NULL, false)
    """))
    await db.flush()


async def _crear_log(
    db, usuario_id, tipo, estado=EstadoNotificacion.ENVIADA, creado_en=None,
):
    kwargs = dict(
        usuario_id=usuario_id,
        tipo=tipo,
        titulo="Test",
        body="Body",
        estado=estado,
    )
    if creado_en is not None:
        kwargs["creado_en"] = creado_en
    log = NotificationLog(**kwargs)
    db.add(log)
    await db.flush()
    return log


# ==================== Tests rate limit ====================


async def test_critico_strict_false_permite(db, usuario_test, seed_rate_limits):
    """Tipo sistema + strict=False -> permitido aunque exceda limites."""
    svc = NotificationService()
    for _ in range(100):
        await _crear_log(
            db, usuario_test.id, TipoNotificacion.SISTEMA,
            creado_en=datetime.now(timezone.utc) - timedelta(minutes=30),
        )
    permitido, _ = await svc._check_rate_limit(
        db, usuario_test.id, TipoNotificacion.SISTEMA,
    )
    assert permitido is True


async def test_promocion_max_por_hora_bloquea(db, usuario_test, seed_rate_limits):
    """Promocion: max 1 por hora. La 2da en la misma hora -> bloqueada."""
    svc = NotificationService()
    await _crear_log(
        db, usuario_test.id, TipoNotificacion.PROMOCION,
        creado_en=datetime.now(timezone.utc) - timedelta(minutes=10),
    )
    permitido, razon = await svc._check_rate_limit(
        db, usuario_test.id, TipoNotificacion.PROMOCION,
    )
    assert permitido is False
    assert razon == "max_por_hora"


async def test_promocion_fuera_ventana_permite(db, usuario_test, seed_rate_limits):
    """Promocion enviada hace 25 horas -> fuera de hora y dia -> permitido.

    Nota: promocion tiene max_por_hora=1 y max_por_dia=1. Una promo de
    hace 2h sigue cayendo dentro de la ventana de 24h, por eso usamos 25h.
    """
    svc = NotificationService()
    await _crear_log(
        db, usuario_test.id, TipoNotificacion.PROMOCION,
        creado_en=datetime.now(timezone.utc) - timedelta(hours=25),
    )
    permitido, _ = await svc._check_rate_limit(
        db, usuario_test.id, TipoNotificacion.PROMOCION,
    )
    assert permitido is True


async def test_skipped_no_cuenta(db, usuario_test, seed_rate_limits):
    """Los logs SKIPPED no cuentan para el rate limit."""
    svc = NotificationService()
    for _ in range(10):
        await _crear_log(
            db, usuario_test.id, TipoNotificacion.PROMOCION,
            estado=EstadoNotificacion.SKIPPED,
            creado_en=datetime.now(timezone.utc) - timedelta(minutes=10),
        )
    permitido, _ = await svc._check_rate_limit(
        db, usuario_test.id, TipoNotificacion.PROMOCION,
    )
    assert permitido is True


async def test_recordatorio_min_intervalo(db, usuario_test, seed_rate_limits):
    """Recordatorio: min_intervalo_seg=3600. Envio hace 5 min -> bloqueado."""
    svc = NotificationService()
    await _crear_log(
        db, usuario_test.id, TipoNotificacion.RECORDATORIO,
        creado_en=datetime.now(timezone.utc) - timedelta(minutes=5),
    )
    permitido, razon = await svc._check_rate_limit(
        db, usuario_test.id, TipoNotificacion.RECORDATORIO,
    )
    assert permitido is False
    assert razon == "min_intervalo"


async def test_recordatorio_min_intervalo_pasado(db, usuario_test, seed_rate_limits):
    """Recordatorio: ultimo envio hace 2 horas -> permitido."""
    svc = NotificationService()
    await _crear_log(
        db, usuario_test.id, TipoNotificacion.RECORDATORIO,
        creado_en=datetime.now(timezone.utc) - timedelta(hours=2),
    )
    permitido, _ = await svc._check_rate_limit(
        db, usuario_test.id, TipoNotificacion.RECORDATORIO,
    )
    assert permitido is True


# ==================== Tests endpoints admin ====================


async def test_listar_rate_limits(client_admin, seed_rate_limits):
    """GET devuelve las 5 configs del seed."""
    r = await client_admin.get("/api/v1/admin/notificaciones/rate-limits")
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body) >= 5
    tipos = {c["tipo"] for c in body}
    assert "promocion" in tipos
    assert "recordatorio" in tipos
    assert "sistema" in tipos


async def test_actualizar_rate_limit(client_admin, seed_rate_limits):
    """PATCH actualiza una config."""
    r = await client_admin.patch(
        "/api/v1/admin/notificaciones/rate-limits/promocion",
        json={"max_por_hora": 5},
    )
    assert r.status_code == 200, r.text
    assert r.json()["max_por_hora"] == 5

    r2 = await client_admin.get("/api/v1/admin/notificaciones/rate-limits")
    body = r2.json()
    promo = next(c for c in body if c["tipo"] == "promocion")
    assert promo["max_por_hora"] == 5


async def test_actualizar_rate_limit_inexistente(client_admin):
    """PATCH a tipo inexistente -> 404."""
    r = await client_admin.patch(
        "/api/v1/admin/notificaciones/rate-limits/tipo_inventado",
        json={"max_por_hora": 1},
    )
    assert r.status_code == 404, r.text
