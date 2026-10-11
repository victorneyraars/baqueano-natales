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
from app.modules.social import instagram_service, services, worker
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

# ------------------------------------------------------------ instagram

@respx.mock
async def test_procesar_cola_instagram_ok(db, monkeypatch):
    """Worker publica en IG cuando pub.red == INSTAGRAM."""
    from datetime import datetime, timezone, timedelta

    cuenta = await _crear_cuenta(db)
    await _crear_token(db, cuenta)

    # Mock del helper de IG ID (no golpea Graph API real)
    async def fake_ig_id(db_, cuenta_id):
        return "17841429137816851"
    monkeypatch.setattr(services, "obtener_instagram_id_de_cuenta", fake_ig_id)

    # Mock de los 2 endpoints de IG
    respx.post("https://graph.facebook.com/v26.0/17841429137816851/media").mock(
        return_value=httpx.Response(200, json={"id": "CONTAINER_1"})
    )
    respx.post("https://graph.facebook.com/v26.0/17841429137816851/media_publish").mock(
        return_value=httpx.Response(200, json={"id": "IG_POST_1"})
    )

    # Crear publicacion con red=INSTAGRAM y con imagen (requerida)
    pub = PublicacionSocial(
        cuenta_id=cuenta.id,
        recurso_tipo="test_ig",
        recurso_id=uuid4(),
        red=Red.INSTAGRAM,
        contenido={
            "message": "Test IG desde worker",
            "image_urls": ["https://x.com/i.jpg"],
        },
        estado=EstadoPublicacion.PENDIENTE,
    )
    db.add(pub)
    await db.commit()
    await db.refresh(pub)

    stats = await worker.procesar_cola(db=db)
    assert stats["procesadas"] == 1
    assert stats["publicadas"] == 1

    await db.refresh(pub)
    assert pub.estado == EstadoPublicacion.PUBLICADO
    assert pub.external_post_id == "IG_POST_1"


async def test_procesar_cola_instagram_sin_imagen_falla(db):
    """IG requiere imagen. Sin image_url, falla con error claro."""
    cuenta = await _crear_cuenta(db)
    await _crear_token(db, cuenta)

    pub = PublicacionSocial(
        cuenta_id=cuenta.id,
        recurso_tipo="test_ig_sin_img",
        recurso_id=uuid4(),
        red=Red.INSTAGRAM,
        contenido={"message": "solo texto"},  # sin image_urls
        estado=EstadoPublicacion.PENDIENTE,
    )
    db.add(pub)
    await db.commit()
    await db.refresh(pub)

    stats = await worker.procesar_cola(db=db)
    assert stats["procesadas"] == 1
    assert stats["falladas"] == 1

    await db.refresh(pub)
    assert "image_url" in (pub.error_ultimo or "").lower() or "imagen" in (pub.error_ultimo or "").lower()

