"""Tests de schemas Pydantic del módulo social."""
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.modules.social.models import (
    DestinoPublicacion,
    PropietarioTipo,
    Red,
)
from app.modules.social.schemas import (
    ConfigSocialUpdate,
    CuentaSocialCreate,
    CuentaSocialUpdate,
    PublicacionSocialCreate,
    TokenSocialGuardar,
)


class TestCuentaSocialCreate:
    def test_minimo_valido(self):
        c = CuentaSocialCreate(
            red=Red.FACEBOOK,
            external_id="123",
            propietario_tipo=PropietarioTipo.BAQUEANO,
        )
        assert c.red == Red.FACEBOOK
        assert c.propietario_id is None
        assert c.auto_publish is False

    def test_external_id_vacio_falla(self):
        with pytest.raises(ValidationError):
            CuentaSocialCreate(
                red=Red.FACEBOOK,
                external_id="",
                propietario_tipo=PropietarioTipo.BAQUEANO,
            )

    def test_external_id_muy_largo_falla(self):
        with pytest.raises(ValidationError):
            CuentaSocialCreate(
                red=Red.FACEBOOK,
                external_id="a" * 151,
                propietario_tipo=PropietarioTipo.BAQUEANO,
            )

    def test_red_invalida_falla(self):
        with pytest.raises(ValidationError):
            CuentaSocialCreate(
                red="linkedin",
                external_id="123",
                propietario_tipo=PropietarioTipo.BAQUEANO,
            )

    def test_propietario_tipo_invalido_falla(self):
        with pytest.raises(ValidationError):
            CuentaSocialCreate(
                red=Red.FACEBOOK,
                external_id="123",
                propietario_tipo="notario",
            )

    def test_propietario_id_seteado(self):
        pid = uuid4()
        c = CuentaSocialCreate(
            red=Red.FACEBOOK,
            external_id="123",
            propietario_tipo=PropietarioTipo.PRESTADOR,
            propietario_id=pid,
        )
        assert c.propietario_id == pid


class TestCuentaSocialUpdate:
    def test_todos_opcionales(self):
        u = CuentaSocialUpdate()
        assert u.external_name is None
        assert u.auto_publish is None

    def test_parcial(self):
        u = CuentaSocialUpdate(auto_publish=True)
        assert u.auto_publish is True
        assert u.external_name is None


class TestTokenSocialGuardar:
    def test_minimo_valido(self):
        t = TokenSocialGuardar(access_token="abc123")
        assert t.access_token == "abc123"
        assert t.token_type == "Bearer"

    def test_access_token_vacio_falla(self):
        with pytest.raises(ValidationError):
            TokenSocialGuardar(access_token="")


class TestPublicacionSocialCreate:
    def test_valido(self):
        pid = uuid4()
        cid = uuid4()
        p = PublicacionSocialCreate(
            cuenta_id=cid,
            recurso_tipo="prestador_servicio",
            recurso_id=pid,
            red=Red.FACEBOOK,
            contenido={"message": "hola"},
        )
        assert p.cuenta_id == cid
        assert p.red == Red.FACEBOOK

    def test_contenido_obligatorio(self):
        with pytest.raises(ValidationError):
            PublicacionSocialCreate(
                cuenta_id=uuid4(),
                recurso_tipo="prestador_servicio",
                recurso_id=uuid4(),
                red=Red.FACEBOOK,
            )

    def test_recurso_tipo_muy_largo_falla(self):
        with pytest.raises(ValidationError):
            PublicacionSocialCreate(
                cuenta_id=uuid4(),
                recurso_tipo="a" * 51,
                recurso_id=uuid4(),
                red=Red.FACEBOOK,
                contenido={"message": "x"},
            )


class TestConfigSocialUpdate:
    def test_todos_opcionales(self):
        u = ConfigSocialUpdate()
        assert u.auto_publish is None
        assert u.destino is None

    def test_destino_valido(self):
        u = ConfigSocialUpdate(destino=DestinoPublicacion.AMBOS)
        assert u.destino == DestinoPublicacion.AMBOS

    def test_destino_invalido_falla(self):
        with pytest.raises(ValidationError):
            ConfigSocialUpdate(destino="todos")