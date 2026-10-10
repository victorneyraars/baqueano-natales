"""
Tests de modelos SQLAlchemy del módulo social.

Requieren DB (fixture `db`). Se saltan automáticamente si no hay
TEST_DATABASE_URL configurada.
"""
from uuid import uuid4

import pytest
from sqlalchemy.exc import IntegrityError

from app.modules.social.models import (
    ConfigSocial,
    CuentaSocial,
    DestinoPublicacion,
    EstadoPublicacion,
    PropietarioTipo,
    PublicacionSocial,
    Red,
    TokenSocial,
)


# =========================================================
# CuentaSocial
# =========================================================
async def test_cuenta_central_se_crea(db):
    cuenta = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="fb_central",
        propietario_tipo=PropietarioTipo.BAQUEANO,
        propietario_id=None,
    )
    db.add(cuenta)
    await db.commit()
    await db.refresh(cuenta)

    assert cuenta.id is not None
    assert cuenta.propietario_id is None
    assert cuenta.activo is True
    assert cuenta.auto_publish is False


async def test_cuenta_de_prestador(db):
    pid = uuid4()
    cuenta = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="fb_taller",
        propietario_tipo=PropietarioTipo.PRESTADOR,
        propietario_id=pid,
    )
    db.add(cuenta)
    await db.commit()
    await db.refresh(cuenta)

    assert cuenta.propietario_tipo == PropietarioTipo.PRESTADOR
    assert cuenta.propietario_id == pid


async def test_unique_red_external_id(db):
    """Dos cuentas con misma (red, external_id) deben fallar."""
    c1 = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="fb_dup",
        propietario_tipo=PropietarioTipo.BAQUEANO,
    )
    db.add(c1)
    await db.commit()

    c2 = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="fb_dup",
        propietario_tipo=PropietarioTipo.PRESTADOR,
        propietario_id=uuid4(),
    )
    db.add(c2)
    with pytest.raises(IntegrityError):
        await db.commit()
    await db.rollback()


async def test_misma_external_id_diferente_red_ok(db):
    """Mismo external_id en distintas redes NO debe fallar."""
    c1 = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="123",
        propietario_tipo=PropietarioTipo.BAQUEANO,
    )
    c2 = CuentaSocial(
        red=Red.INSTAGRAM,
        external_id="123",
        propietario_tipo=PropietarioTipo.BAQUEANO,
    )
    db.add(c1)
    db.add(c2)
    await db.commit()
    # Si llegamos acá, no hubo IntegrityError
    assert c1.id != c2.id


async def test_cuenta_padre_id_para_instagram(db):
    """IG apunta a la cuenta de FB que lo contiene."""
    fb = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="fb_padre",
        propietario_tipo=PropietarioTipo.BAQUEANO,
    )
    db.add(fb)
    await db.commit()
    await db.refresh(fb)

    ig = CuentaSocial(
        red=Red.INSTAGRAM,
        external_id="ig_hijo",
        propietario_tipo=PropietarioTipo.BAQUEANO,
        cuenta_padre_id=fb.id,
    )
    db.add(ig)
    await db.commit()
    await db.refresh(ig)

    assert ig.cuenta_padre_id == fb.id


# =========================================================
# TokenSocial
# =========================================================
async def test_token_ligado_a_cuenta(db):
    cuenta = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="fb_token",
        propietario_tipo=PropietarioTipo.BAQUEANO,
    )
    db.add(cuenta)
    await db.commit()
    await db.refresh(cuenta)

    token = TokenSocial(
        cuenta_id=cuenta.id,
        access_token="enc:fake_cifrado_aqui",
        token_type="Bearer",
    )
    db.add(token)
    await db.commit()
    await db.refresh(token)

    assert token.id is not None
    assert token.cuenta_id == cuenta.id


async def test_token_cascade_al_borrar_cuenta(db):
    """Si se borra la cuenta (DELETE real), los tokens caen en cascada."""
    cuenta = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="fb_cascade",
        propietario_tipo=PropietarioTipo.BAQUEANO,
    )
    db.add(cuenta)
    await db.commit()
    await db.refresh(cuenta)

    token = TokenSocial(
        cuenta_id=cuenta.id,
        access_token="enc:x",
    )
    db.add(token)
    await db.commit()

    # DELETE real (no soft delete)
    await db.delete(cuenta)
    await db.commit()

    # Verificar que el token ya no existe
    from sqlalchemy import select
    stmt = select(TokenSocial).where(TokenSocial.cuenta_id == cuenta.id)
    restantes = (await db.execute(stmt)).scalars().all()
    assert len(restantes) == 0


# =========================================================
# PublicacionSocial
# =========================================================
async def test_publicacion_estado_default_pendiente(db):
    cuenta = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="fb_pub",
        propietario_tipo=PropietarioTipo.BAQUEANO,
    )
    db.add(cuenta)
    await db.commit()
    await db.refresh(cuenta)

    pub = PublicacionSocial(
        cuenta_id=cuenta.id,
        recurso_tipo="prestador_servicio",
        recurso_id=uuid4(),
        red=Red.FACEBOOK,
        contenido={"message": "hola"},
    )
    db.add(pub)
    await db.commit()
    await db.refresh(pub)

    assert pub.estado == EstadoPublicacion.PENDIENTE
    assert pub.intentos == 0
    assert pub.proximo_intento_en is None
    assert pub.external_post_id is None
    assert pub.error_ultimo is None


async def test_publicacion_cascade_al_borrar_cuenta(db):
    cuenta = CuentaSocial(
        red=Red.FACEBOOK,
        external_id="fb_pub_cascade",
        propietario_tipo=PropietarioTipo.BAQUEANO,
    )
    db.add(cuenta)
    await db.commit()
    await db.refresh(cuenta)

    pub = PublicacionSocial(
        cuenta_id=cuenta.id,
        recurso_tipo="prestador_servicio",
        recurso_id=uuid4(),
        red=Red.FACEBOOK,
        contenido={"message": "x"},
    )
    db.add(pub)
    await db.commit()

    await db.delete(cuenta)
    await db.commit()

    from sqlalchemy import select
    stmt = select(PublicacionSocial).where(
        PublicacionSocial.cuenta_id == cuenta.id
    )
    restantes = (await db.execute(stmt)).scalars().all()
    assert len(restantes) == 0


# =========================================================
# ConfigSocial
# =========================================================
async def test_config_global(db):
    cfg = ConfigSocial(
        propietario_tipo=None,
        propietario_id=None,
        auto_publish=False,
        destino=DestinoPublicacion.AMBOS,
    )
    db.add(cfg)
    await db.commit()
    await db.refresh(cfg)

    assert cfg.id is not None
    assert cfg.publicar_en_facebook is True
    assert cfg.publicar_en_instagram is False
    assert cfg.publicar_en_google is False


async def test_config_unica_global(db):
    """Dos config globales (ambos NULL) deben fallar por el UNIQUE."""
    c1 = ConfigSocial(propietario_tipo=None, propietario_id=None)
    db.add(c1)
    await db.commit()

    c2 = ConfigSocial(propietario_tipo=None, propietario_id=None)
    db.add(c2)
    with pytest.raises(IntegrityError):
        await db.commit()
    await db.rollback()


async def test_config_por_propietario(db):
    pid = uuid4()
    cfg = ConfigSocial(
        propietario_tipo=PropietarioTipo.PRESTADOR,
        propietario_id=pid,
        auto_publish=True,
    )
    db.add(cfg)
    await db.commit()
    await db.refresh(cfg)

    assert cfg.auto_publish is True
    assert cfg.propietario_tipo == PropietarioTipo.PRESTADOR