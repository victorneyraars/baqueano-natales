"""Tests de eventos_prestadores.py (integracion social <-> prestadores).

Usa DB real. Verifica que al disparar los eventos se encolen publicaciones
en la cuenta central segun config_social.
"""
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.modules.social import eventos_prestadores as ep
from app.modules.social.models import (
    ConfigSocial,
    CuentaSocial,
    EstadoPublicacion,
    PropietarioTipo,
    PublicacionSocial,
    Red,
)


# ------------------------------------------------------------ helpers

async def _crear_cuenta_central(db):
    cuenta = CuentaSocial(
        red=Red.FACEBOOK,
        propietario_tipo=PropietarioTipo.BAQUEANO,
        propietario_id=None,
        external_id="CENTRAL_1",
        external_name="Baqueano Natales Central",
        activo=True,
    )
    db.add(cuenta)
    await db.commit()
    await db.refresh(cuenta)
    return cuenta


async def _crear_config(db, *, auto=True, fb=True, ig=True):
    cfg = ConfigSocial(
        propietario_tipo=None,
        propietario_id=None,
        auto_publish=auto,
        publicar_en_facebook=fb,
        publicar_en_instagram=ig,
        publicar_en_google=False,
    )
    db.add(cfg)
    await db.commit()
    return cfg


class _FakeCategoria:
    def __init__(self, nombre="Mecanica"):
        self.nombre = nombre


class _FakePrestador:
    def __init__(self, **kw):
        self.id = kw.get("id", uuid4())
        self.nombre = kw.get("nombre", "Taller Test")
        self.slug = kw.get("slug", "taller-test")
        self.direccion = kw.get("direccion", "Av. Test 123")
        self.anios_experiencia = kw.get("anios_experiencia", 5)
        self.foto_portada_url = kw.get("foto_portada_url", None)
        self.foto_url = kw.get("foto_url", None)
        self.categoria = kw.get("categoria", _FakeCategoria())


class _FakeServicio:
    def __init__(self, **kw):
        self.id = kw.get("id", uuid4())
        self.nombre = kw.get("nombre", "Cambio de aceite")
        self.categoria_servicio = kw.get("categoria_servicio", "Mantenimiento")
        self.descripcion = kw.get("descripcion", "Cambio completo")
        self.precio_desde_clp = kw.get("precio_desde_clp", 15000)
        self.precio_hasta_clp = kw.get("precio_hasta_clp", 25000)


async def _contar_publicaciones(db, red=None):
    stmt = select(PublicacionSocial)
    if red is not None:
        stmt = stmt.where(PublicacionSocial.red == red)
    result = await db.execute(stmt)
    return list(result.scalars().all())


# ------------------------------------------------------------ tests

async def test_sin_config_no_encola(db):
    """Sin ConfigSocial, no se encola nada."""
    await _crear_cuenta_central(db)
    prestador = _FakePrestador()
    await ep.encolar_prestador_nuevo(db, prestador)

    pubs = await _contar_publicaciones(db)
    assert len(pubs) == 0


async def test_auto_publish_false_no_encola(db):
    """Con auto_publish=False, no se encola nada."""
    await _crear_cuenta_central(db)
    await _crear_config(db, auto=False)
    prestador = _FakePrestador()
    await ep.encolar_prestador_nuevo(db, prestador)

    pubs = await _contar_publicaciones(db)
    assert len(pubs) == 0


async def test_prestador_nuevo_encola_fb_e_ig(db):
    """Con imagen, se encola en FB + IG."""
    await _crear_cuenta_central(db)
    await _crear_config(db, auto=True, fb=True, ig=True)
    prestador = _FakePrestador(foto_portada_url="/media/prestadores/taller.jpg")
    await ep.encolar_prestador_nuevo(db, prestador)

    pubs = await _contar_publicaciones(db)
    assert len(pubs) == 2
    redes = {p.red.value for p in pubs}
    assert redes == {"facebook", "instagram"}
    for p in pubs:
        assert p.estado == EstadoPublicacion.PENDIENTE
        assert p.recurso_tipo == "prestador"
        assert p.recurso_id == prestador.id
        # Ambas tienen imagen
        assert p.contenido.get("image_urls")


async def test_prestador_sin_imagen_solo_fb(db):
    """Sin imagen, IG no se encola (IG requiere imagen)."""
    await _crear_cuenta_central(db)
    await _crear_config(db, auto=True, fb=True, ig=True)
    prestador = _FakePrestador()  # sin fotos
    await ep.encolar_prestador_nuevo(db, prestador)

    pubs = await _contar_publicaciones(db)
    assert len(pubs) == 1
    assert pubs[0].red.value == "facebook"


async def test_servicio_nuevo_encola_fb_e_ig(db):
    """Servicio nuevo con portada de prestador -> FB + IG."""
    await _crear_cuenta_central(db)
    await _crear_config(db, auto=True, fb=True, ig=True)
    prestador = _FakePrestador(foto_portada_url="/media/prestadores/taller.jpg")
    servicio = _FakeServicio()
    await ep.encolar_servicio_nuevo(db, prestador, servicio)

    pubs = await _contar_publicaciones(db)
    assert len(pubs) == 2
    for p in pubs:
        assert p.recurso_tipo == "prestador_servicio"
        assert p.recurso_id == servicio.id
        assert "Cambio de aceite" in p.contenido["message"]


async def test_config_solo_facebook(db):
    """Si publicar_en_instagram=False, solo FB."""
    await _crear_cuenta_central(db)
    await _crear_config(db, auto=True, fb=True, ig=False)
    prestador = _FakePrestador(foto_portada_url="/media/p/f.jpg")
    await ep.encolar_prestador_nuevo(db, prestador)

    pubs = await _contar_publicaciones(db)
    assert len(pubs) == 1
    assert pubs[0].red.value == "facebook"


async def test_sin_cuenta_central_no_encola(db):
    """Sin cuenta central activa, no se encola nada."""
    await _crear_config(db, auto=True)
    prestador = _FakePrestador()
    await ep.encolar_prestador_nuevo(db, prestador)

    pubs = await _contar_publicaciones(db)
    assert len(pubs) == 0
