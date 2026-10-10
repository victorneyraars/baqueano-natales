"""Tests unitarios para oauth_state.py (JWT firmados)."""
from datetime import datetime, timedelta, timezone

import jwt
import pytest

from app.core.config import settings
from app.modules.social import oauth_state


def test_state_roundtrip():
    state = oauth_state.generar_state("user-123")
    assert oauth_state.verificar_state(state) == "user-123"


def test_state_tipo_incorrecto():
    """Un token_ref NO debe pasar por state."""
    tr = oauth_state.generar_token_ref("u1", "tok")
    with pytest.raises(oauth_state.OAuthTokenError, match="Tipo de token"):
        oauth_state.verificar_state(tr)


def test_state_expirado():
    """Construimos un state con exp en el pasado."""
    payload = {
        "tipo": oauth_state._TIPO_STATE,
        "sub": "u1",
        "iat": int((datetime.now(timezone.utc) - timedelta(hours=1)).timestamp()),
        "exp": int((datetime.now(timezone.utc) - timedelta(minutes=1)).timestamp()),
        "jti": "test",
    }
    token = jwt.encode(
        payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM
    )
    with pytest.raises(oauth_state.OAuthTokenError, match="expirado"):
        oauth_state.verificar_state(token)


def test_state_firma_invalida():
    """Firmado con otra clave debe fallar."""
    payload = {
        "tipo": oauth_state._TIPO_STATE,
        "sub": "u1",
        "iat": int(datetime.now(timezone.utc).timestamp()),
        "exp": int((datetime.now(timezone.utc) + timedelta(minutes=5)).timestamp()),
        "jti": "test",
    }
    token = jwt.encode(payload, "clave_mala", algorithm="HS256")
    with pytest.raises(oauth_state.OAuthTokenError, match="inv"):
        oauth_state.verificar_state(token)


def test_token_ref_roundtrip():
    """El token_ref debe devolver el user_id y el user token descifrado."""
    tr = oauth_state.generar_token_ref("admin-1", "EAAB_user_token")
    user_id, uat = oauth_state.leer_token_ref(tr)
    assert user_id == "admin-1"
    assert uat == "EAAB_user_token"


def test_token_ref_no_expone_token_plano():
    """El token_ref NO debe contener el token en claro."""
    tr = oauth_state.generar_token_ref("admin-1", "EAAB_secreto_muy_largo")
    assert "EAAB_secreto_muy_largo" not in tr


def test_token_ref_con_clave_incorrecta_falla(monkeypatch):
    """Si TOKEN_ENCRYPTION_KEY cambia, descifrar debe fallar."""
    tr = oauth_state.generar_token_ref("u1", "tok")
    from app.core import crypto
    monkeypatch.setattr(crypto, "_cargar_fernet", lambda: None)
    with pytest.raises(oauth_state.OAuthTokenError, match="descifrar"):
        oauth_state.leer_token_ref(tr)
