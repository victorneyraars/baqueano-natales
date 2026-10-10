"""
Tests de las funciones de services.py del módulo social.

Requieren DB (fixture `db`). Se saltan automáticamente si no hay
TEST_DATABASE_URL configurada.
"""
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.modules.social import services
from app.modules.social.models import (
    CuentaSocial,
    DestinoPublicacion,
    EstadoPublicacion,
    PropietarioTipo,
    PublicacionSocial,
    Red,
    TokenSocial,
)
from app.modules.social.schemas import (
    ConfigSocialUpdate,
    CuentaSocialCreate,
    CuentaSocialUpdate,
    PublicacionSocialCreate,
    TokenSocialGuardar,
)


# =========================================================
# Fixtures de dominio (crear cuentas rápido)
# =========================================================
async def _crear_cuenta(db, *, external_id: str = "fb_1", red=Red.FACEBOOK):
    datos = CuentaSocialCreate(
        red=red,
        external_id=external_id,
        propietario_tipo=PropietarioTipo.BAQUEANO,
    )
    return await services.crear_cuenta(db, datos)


# =========================================================
# Cuentas
# =========================================================
async def test_crear_cuenta(db):
    cuenta = await _crear_cuenta(db, external_id="fb_nueva")
    assert cuenta.id is not None
    assert cuenta.red == Red.FACEBOOK
    assert cuenta.external_id == "fb_nueva"


async def test_crear_cuenta_duplicada_lanza_409(db):
    await _crear_cuenta(db, external_id="fb_dup")

    with pytest.raises(HTTPException) as exc:
        await _crear_cuenta(db, external_id="fb_dup")
    assert exc.value.status_code == 409


async def test_obtener_cuenta(db):
    cuenta = await _crear_cuenta(db, external_id="fb_get")
    resultado = await services.obtener_cuenta(db, cuenta.id)
    assert resultado is not None
    assert resultado.id == cuenta.id


async def test_obtener_cuenta_inexistente(db):
    resultado = await services.obtener_cuenta(db, uuid4())
    assert resultado is None


async def test_listar_cuentas(db):
    await _crear_cuenta(db, external_id="fb_a")
    await _crear_cuenta(db, external_id="fb_b")
    await _crear_cuenta(db, external_id="ig_a", red=Red.INSTAGRAM)

    items, total = await services.listar_cuentas(db)
    assert total == 3
    assert len(items) == 3


async def test_listar_cuentas_filtro_red(db):
    await _crear_cuenta(db, external_id="fb_a")
    await _crear_cuenta(db, external_id="ig_a", red=Red.INSTAGRAM)

    items, total = await services.listar_cuentas(db, red="facebook")
    assert total == 1
    assert items[0].red == Red.FACEBOOK


async def test_actualizar_cuenta(db):
    cuenta = await _crear_cuenta(db, external_id="fb_upd")
    datos = CuentaSocialUpdate(external_name="Mi pagina", auto_publish=True)
    cuenta = await services.actualizar_cuenta(db, cuenta, datos)

    assert cuenta.external_name == "Mi pagina"
    assert cuenta.auto_publish is True


async def test_desactivar_cuenta(db):
    cuenta = await _crear_cuenta(db, external_id="fb_del")
    cuenta.auto_publish = True
    await db.commit()

    cuenta = await services.desactivar_cuenta(db, cuenta)
    assert cuenta.activo is False
    assert cuenta.auto_publish is False


# =========================================================
# Tokens
# =========================================================
async def test_guardar_token_cifra_access(db):
    cuenta = await _crear_cuenta(db, external_id="fb_tok")
    datos = TokenSocialGuardar(access_token="EAAG_token_en_claro")
    token = await services.guardar_token(db, cuenta, datos)

    # El token guardado debe estar cifrado
    assert token.access_token.startswith("enc:")
    assert "EAAG" not in token.access_token


async def test_guardar_token_cifra_refresh(db):
    cuenta = await _crear_cuenta(db, external_id="fb_tok2")
    datos = TokenSocialGuardar(
        access_token="access_x",
        refresh_token="refresh_y",
    )
    token = await services.guardar_token(db, cuenta, datos)

    assert token.refresh_token is not None
    assert token.refresh_token.startswith("enc:")


async def test_descifrar_token_round_trip(db):
    cuenta = await _crear_cuenta(db, external_id="fb_tok3")
    datos = TokenSocialGuardar(
        access_token="EAAG_original",
        refresh_token="refresh_original",
    )
    token = await services.guardar_token(db, cuenta, datos)

    access, refresh = services.descifrar_token(token)
    assert access == "EAAG_original"
    assert refresh == "refresh_original"


async def test_obtener_token_vigente_sin_expiry(db):
    cuenta = await _crear_cuenta(db, external_id="fb_tok4")
    datos = TokenSocialGuardar(access_token="EAAG_x")
    await services.guardar_token(db, cuenta, datos)

    token = await services.obtener_token_vigente(db, cuenta.id)
    assert token is not None


async def test_obtener_token_vigente_expirado_devuelve_none(db):
    cuenta = await _crear_cuenta(db, external_id="fb_tok5")
    expirado = datetime.now(timezone.utc) - timedelta(hours=1)
    datos = TokenSocialGuardar(access_token="EAAG_x", expires_at=expirado)
    await services.guardar_token(db, cuenta, datos)

    token = await services.obtener_token_vigente(db, cuenta.id)
    assert token is None


async def test_obtener_token_vigente_futuro(db):
    cuenta = await _crear_cuenta(db, external_id="fb_tok6")
    futuro = datetime.now(timezone.utc) + timedelta(days=30)
    datos = TokenSocialGuardar(access_token="EAAG_x", expires_at=futuro)
    await services.guardar_token(db, cuenta, datos)

    token = await services.obtener_token_vigente(db, cuenta.id)
    assert token is not None


# =========================================================
# Config
# =========================================================
async def test_obtener_o_crear_config_global_crea_si_no_existe(db):
    cfg = await services.obtener_o_crear_config_global(db)
    assert cfg.id is not None
    assert cfg.propietario_tipo is None
    assert cfg.propietario_id is None
    assert cfg.auto_publish is False


async def test_obtener_o_crear_config_global_idempotente(db):
    cfg1 = await services.obtener_o_crear_config_global(db)
    cfg2 = await services.obtener_o_crear_config_global(db)
    assert cfg1.id == cfg2.id


async def test_actualizar_config(db):
    cfg = await services.obtener_o_crear_config_global(db)
    datos = ConfigSocialUpdate(
        auto_publish=True,
        destino=DestinoPublicacion.CENTRAL,
    )
    cfg = await services.actualizar_config(db, cfg, datos)
    assert cfg.auto_publish is True
    assert cfg.destino == DestinoPublicacion.CENTRAL


async def test_obtener_config_hereda_global(db):
    # Sin propietario, debe devolver la global
    await services.obtener_o_crear_config_global(db)
    cfg = await services.obtener_config(db)
    assert cfg is not None
    assert cfg.propietario_id is None


# =========================================================
# Publicaciones
# =========================================================
async def test_encolar_publicacion(db):
    cuenta = await _crear_cuenta(db, external_id="fb_enc")
    datos = PublicacionSocialCreate(
        cuenta_id=cuenta.id,
        recurso_tipo="prestador_servicio",
        recurso_id=uuid4(),
        red=Red.FACEBOOK,
        contenido={"message": "hola"},
    )
    pub = await services.encolar_publicacion(db, datos)

    assert pub.id is not None
    assert pub.estado == EstadoPublicacion.PENDIENTE
    assert pub.intentos == 0


async def test_encolar_publicacion_cuenta_inexistente(db):
    datos = PublicacionSocialCreate(
        cuenta_id=uuid4(),
        recurso_tipo="prestador_servicio",
        recurso_id=uuid4(),
        red=Red.FACEBOOK,
        contenido={"message": "x"},
    )
    with pytest.raises(HTTPException) as exc:
        await services.encolar_publicacion(db, datos)
    assert exc.value.status_code == 404


async def test_encolar_publicacion_cuenta_inactiva(db):
    cuenta = await _crear_cuenta(db, external_id="fb_inact")
    await services.desactivar_cuenta(db, cuenta)

    datos = PublicacionSocialCreate(
        cuenta_id=cuenta.id,
        recurso_tipo="prestador_servicio",
        recurso_id=uuid4(),
        red=Red.FACEBOOK,
        contenido={"message": "x"},
    )
    with pytest.raises(HTTPException) as exc:
        await services.encolar_publicacion(db, datos)
    assert exc.value.status_code == 404


async def test_listar_publicaciones(db):
    cuenta = await _crear_cuenta(db, external_id="fb_list")
    for i in range(3):
        await services.encolar_publicacion(
            db,
            PublicacionSocialCreate(
                cuenta_id=cuenta.id,
                recurso_tipo="prestador_servicio",
                recurso_id=uuid4(),
                red=Red.FACEBOOK,
                contenido={"message": f"msg {i}"},
            ),
        )

    items, total = await services.listar_publicaciones(db)
    assert total == 3
    assert len(items) == 3


async def test_listar_publicaciones_filtro_estado(db):
    cuenta = await _crear_cuenta(db, external_id="fb_flt")
    await services.encolar_publicacion(
        db,
        PublicacionSocialCreate(
            cuenta_id=cuenta.id,
            recurso_tipo="prestador_servicio",
            recurso_id=uuid4(),
            red=Red.FACEBOOK,
            contenido={"message": "x"},
        ),
    )

    items, total = await services.listar_publicaciones(
        db, estado=EstadoPublicacion.PENDIENTE
    )
    assert total == 1

    items, total = await services.listar_publicaciones(
        db, estado=EstadoPublicacion.PUBLICADO
    )
    assert total == 0


async def test_obtener_publicacion(db):
    cuenta = await _crear_cuenta(db, external_id="fb_get")
    pub = await services.encolar_publicacion(
        db,
        PublicacionSocialCreate(
            cuenta_id=cuenta.id,
            recurso_tipo="prestador_servicio",
            recurso_id=uuid4(),
            red=Red.FACEBOOK,
            contenido={"message": "x"},
        ),
    )

    encontrada = await services.obtener_publicacion(db, pub.id)
    assert encontrada is not None
    assert encontrada.id == pub.id