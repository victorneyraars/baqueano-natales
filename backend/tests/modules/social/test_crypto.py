"""Tests de app.core.crypto (cifrado Fernet)."""
import pytest
from cryptography.fernet import Fernet

from app.core import crypto
from app.core.config import settings


@pytest.fixture(autouse=True)
def _restaurar_settings():
    """Guarda y restaura TOKEN_ENCRYPTION_KEY y ENVIRONMENT."""
    key_orig = settings.TOKEN_ENCRYPTION_KEY
    env_orig = settings.ENVIRONMENT
    yield
    settings.TOKEN_ENCRYPTION_KEY = key_orig
    settings.ENVIRONMENT = env_orig


@pytest.fixture
def con_clave():
    """Setea una clave Fernet válida."""
    settings.TOKEN_ENCRYPTION_KEY = Fernet.generate_key().decode()
    return settings.TOKEN_ENCRYPTION_KEY


@pytest.fixture
def sin_clave():
    """Deja la clave vacía."""
    settings.TOKEN_ENCRYPTION_KEY = ""


def test_cifrar_devuelve_prefijo_enc(con_clave):
    r = crypto.cifrar("hola mundo")
    assert r.startswith("enc:")
    assert r != "hola mundo"


def test_round_trip(con_clave):
    original = "hola mundo secreto"
    cifrado = crypto.cifrar(original)
    assert crypto.descifrar(cifrado) == original


def test_descifrar_texto_claro_devuelve_tal_cual():
    assert crypto.descifrar("texto sin cifrar") == "texto sin cifrar"


def test_cifrar_none_devuelve_none():
    assert crypto.cifrar(None) is None


def test_descifrar_none_devuelve_none():
    assert crypto.descifrar(None) is None


def test_cifrar_vacio_devuelve_vacio(con_clave):
    assert crypto.cifrar("") == ""


def test_cifrar_sin_clave_guarda_en_claro(sin_clave):
    # Sin clave configurada, guarda tal cual (con warning en log)
    assert crypto.cifrar("texto") == "texto"


def test_descifrar_con_clave_distinta_devuelve_none(con_clave):
    cifrado = crypto.cifrar("secreto")
    settings.TOKEN_ENCRYPTION_KEY = Fernet.generate_key().decode()
    assert crypto.descifrar(cifrado) is None


def test_descifrar_cifrado_sin_clave_devuelve_none(con_clave):
    cifrado = crypto.cifrar("secreto")
    settings.TOKEN_ENCRYPTION_KEY = ""
    assert crypto.descifrar(cifrado) is None


def test_cifrado_no_es_deterministico(con_clave):
    a = crypto.cifrar("hola")
    b = crypto.cifrar("hola")
    assert a != b
    assert crypto.descifrar(a) == crypto.descifrar(b) == "hola"


def test_validar_clave_con_clave_ok(con_clave):
    crypto.validar_clave_configurada()  # no debe lanzar


def test_validar_clave_sin_clave_en_prod_falla(sin_clave):
    settings.ENVIRONMENT = "production"
    with pytest.raises(RuntimeError):
        crypto.validar_clave_configurada()


def test_validar_clave_sin_clave_en_dev_no_falla(sin_clave):
    settings.ENVIRONMENT = "development"
    crypto.validar_clave_configurada()  # no debe lanzar