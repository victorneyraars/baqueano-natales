"""JWT firmados para el flujo OAuth de Facebook.

Existen dos tipos de token, ambos firmados con `SECRET_KEY` del backend:

- **state** ? viaja a Facebook y vuelve en el callback. Previene CSRF.
  TTL: 10 minutos. Contiene `sub` (user_id del admin que inici? el flujo).

- **token_ref** ? contiene el user access token de Facebook (ya cifrado con
  Fernet) y viaja al frontend/admin. TTL: 15 minutos. Permite que el frontend
  liste p?ginas y conecte cuentas sin que el backend mantenga estado en Redis.

Ambos son stateless: no hay storage server-side. Expiran solos.
"""
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt

from app.core import crypto
from app.core.config import settings


STATE_TTL_MIN = 10
TOKEN_REF_TTL_MIN = 15

_TIPO_STATE = "fb_state"
_TIPO_TOKEN_REF = "fb_token_ref"


class OAuthTokenError(Exception):
    """Error de validaci?n de state/token_ref (firma, expiraci?n, tipo)."""


# --------------------------------------------------------------------- core

def _encode(payload: dict, ttl_min: int) -> str:
    now = datetime.now(timezone.utc)
    completo = {
        **payload,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=ttl_min)).timestamp()),
        "jti": str(uuid4()),
    }
    return jwt.encode(
        completo, settings.SECRET_KEY, algorithm=settings.ALGORITHM
    )


def _decode(token: str, tipo_esperado: str) -> dict:
    try:
        data = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
    except jwt.ExpiredSignatureError:
        raise OAuthTokenError("Token expirado")
    except jwt.InvalidTokenError as e:
        raise OAuthTokenError(f"Token inv?lido: {e}")

    if data.get("tipo") != tipo_esperado:
        raise OAuthTokenError(
            f"Tipo de token inv?lido (esperado {tipo_esperado}, "
            f"recibido {data.get('tipo')})"
        )
    return data


# ---------------------------------------------------------------- state (CSRF)

def generar_state(user_id: str, app_redirect: bool = False) -> str:
    """JWT con el user_id y flag de redirect a app. TTL: 10 min."""
    return _encode(
        {
            "sub": user_id,
            "tipo": _TIPO_STATE,
            "app_redirect": app_redirect,
        },
        STATE_TTL_MIN,
    )


def verificar_state(state: str) -> str:
    """Valida el `state` y devuelve el user_id (`sub`)."""
    data = _decode(state, _TIPO_STATE)
    sub = data.get("sub")
    if not sub:
        raise OAuthTokenError("state sin sub")
    return sub


# ------------------------------------------------------ token_ref (user token)

def generar_token_ref(user_id: str, user_access_token: str) -> str:
    """Empaqueta el user access token (cifrado con Fernet) en un JWT corto."""
    return _encode(
        {
            "tipo": _TIPO_TOKEN_REF,
            "sub": user_id,
            "uat": crypto.cifrar(user_access_token),
        },
        TOKEN_REF_TTL_MIN,
    )


def leer_token_ref(token_ref: str) -> tuple[str, str]:
    """Devuelve `(user_id, user_access_token)` desde el token_ref."""
    data = _decode(token_ref, _TIPO_TOKEN_REF)
    sub = data.get("sub")
    uat_cifrado = data.get("uat")
    if not sub or not uat_cifrado:
        raise OAuthTokenError("token_ref incompleto")

    uat = crypto.descifrar(uat_cifrado)
    if not uat:
        raise OAuthTokenError("No se pudo descifrar el user token")
    return sub, uat
