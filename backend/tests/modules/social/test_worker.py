"""Tests del worker de publicaciones sociales.

Usa DB real (baqueano_test) + respx para mockear la Graph API de Meta.
Verifica el ciclo completo: leer cola -> verificar cuenta -> publicar ->
marcar resultado (con backoff).
"""
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import httpx
import pytest
import respx

from app.core import crypto
from app.modules.social import services, worker
from app.modules.social.models import (
    CuentaSocial,
    EstadoPublicacion,
    PropietarioTipo,
    PublicacionSocial,
    Red,
    TokenSocial,
)


# ------------------------------------------------------------ helpers

async def _crear_cuenta(db, *, activa=True, external_id="PAGE_TEST"):
    cuenta = CuentaSocial(
        red=Red.FACEBOOK,
        propietario_tipo=PropietarioTipo.BAQUEANO,
        propietario_id=None,
        external_id=external_id,
        external_name="Test Page",
        activo=activa,
    )
    db.add(cuenta)
    await db.flush()
    return cuenta


async def _crear_token(db, cuenta, *, expira_en_dias=60):
    token = TokenSocial(
        cuenta_id=cuenta.id,
        access_token=crypto.cifrar("EAAB_token_test"),
        token_type="page",
        expires_at=datetime.now(timezone.utc) + timedelta(days=expira_en_dias),
        scope="pages_manage_posts",
    )
    db.add(token)
    await db.commit()
    return token


async def _crear_pub(db, cuenta, *, contenido=None, estado=EstadoPublicacion.PENDIENTE):
    if contenido is None:
        contenido = {"message": "Hola mundo"}
    pub = PublicacionSocial(
        cuenta_id=cuenta.id,
        recurso_tipo="test",
        recurso_id=uuid4(),
        red=Red.FACEBOOK,
        contenido=contenido,
        estado=estado,
    )
    db.add(pub)
    await db.commit()
    await db.refresh(pub)
    return pub


# ------------------------------------------------------------ tests

async def test_procesar_cola_vacia(db):
    stats = await worker.procesar_cola(db=db)
    assert stats["procesadas"] == 0
    assert stats["publicadas"] == 0
    assert stats["falladas"] == 0


@respx.mock
async def test_procesar_cola_publica_ok(db):
    cuenta = await _crear_cuenta(db)
    await _crear_token(db, cuenta)
    pub = await _crear_pub(db, cuenta)

    # Mock Graph API
    respx.post(f"https://graph.facebook.com/v26.0/{cuenta.external_id}/feed").mock(
        return_value=httpx.Response(200, json={"id": "PAGE_TEST_99999"})
    )

    stats = await worker.procesar_cola(db=db)
    assert stats["procesadas"] == 1
    assert stats["publicadas"] == 1
    assert stats["falladas"] == 0

    await db.refresh(pub)
    assert pub.estado == EstadoPublicacion.PUBLICADO
    assert pub.external_post_id == "PAGE_TEST_99999"
    assert pub.error_ultimo is None
    assert pub.intentos == 0


async def test_procesar_cola_cuenta_inactiva_falla(db):
    cuenta = await _crear_cuenta(db, activa=False)
    await _crear_token(db, cuenta)
    pub = await _crear_pub(db, cuenta)

    stats = await worker.procesar_cola(db=db)
    assert stats["procesadas"] == 1
    assert stats["falladas"] == 1

    await db.refresh(pub)
    assert pub.estado == EstadoPublicacion.PENDIENTE
    assert pub.intentos == 1
    assert "inactiva" in (pub.error_ultimo or "").lower()
    assert pub.proximo_intento_en is not None


async def test_procesar_cola_sin_token_falla(db):
    cuenta = await _crear_cuenta(db)
    # Sin token
    pub = await _crear_pub(db, cuenta)

    stats = await worker.procesar_cola(db=db)
    assert stats["procesadas"] == 1
    assert stats["falladas"] == 1

    await db.refresh(pub)
    assert pub.estado == EstadoPublicacion.PENDIENTE
    assert pub.intentos == 1
    assert "token" in (pub.error_ultimo or "").lower()


async def test_procesar_cola_contenido_vacio_falla(db):
    cuenta = await _crear_cuenta(db)
    await _crear_token(db, cuenta)
    pub = await _crear_pub(db, cuenta, contenido={"message": ""})

    stats = await worker.procesar_cola(db=db)
    assert stats["procesadas"] == 1
    assert stats["falladas"] == 1

    await db.refresh(pub)
    assert "contenido" in (pub.error_ultimo or "").lower() or "mensaje" in (pub.error_ultimo or "").lower()


async def test_backoff_llega_a_agotado(db):
    """Simula fallos repetidos: al 5to intento, estado=AGOTADO."""
    cuenta = await _crear_cuenta(db, activa=False)
    await _crear_token(db, cuenta)
    pub = await _crear_pub(db, cuenta)

    # Forzar el proximo_intento_en para que cada ciclo lo procese
    for intento in range(services.MAX_INTENTOS):
        # Forzar que este listo para procesar
        pub.proximo_intento_en = None
        await db.commit()
        await worker.procesar_cola(db=db)
        await db.refresh(pub)

    # Tras MAX_INTENTOS fallos -> AGOTADO
    assert pub.estado == EstadoPublicacion.AGOTADO
    assert pub.intentos == services.MAX_INTENTOS
    assert pub.proximo_intento_en is None
