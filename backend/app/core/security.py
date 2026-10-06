"""
Seguridad: JWT propio del backend + utilidades de tokens.
Después de validar un token de Firebase, generamos un JWT propio con
roles y permisos para no depender de Firebase en cada request.
"""
import logging
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from fastapi import HTTPException, status

from app.core.config import settings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------
# Generación de JWT propio
# ---------------------------------------------------------
def create_access_token(
    subject: str,
    *,
    expires_delta: timedelta | None = None,
    extra_claims: dict[str, Any] | None = None,
) -> str:
    """
    Crea un JWT de acceso firmado.

    Args:
        subject: identificador del usuario (UUID como string).
        expires_delta: duración del token (default: settings.ACCESS_TOKEN_EXPIRE_MINUTES).
        extra_claims: claims adicionales (rol, email, etc.).

    Returns:
        JWT firmado como string.
    """
    now = datetime.now(timezone.utc)
    if expires_delta is None:
        expires_delta = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    payload: dict[str, Any] = {
        "sub": subject,
        "iat": now,
        "exp": now + expires_delta,
        "iss": "baqueano-natales",
    }

    if extra_claims:
        payload.update(extra_claims)

    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


# ---------------------------------------------------------
# Validación de JWT propio
# ---------------------------------------------------------
def decode_access_token(token: str) -> dict[str, Any]:
    """
    Decodifica y valida un JWT propio.

    Args:
        token: JWT a validar.

    Returns:
        Payload decodificado.

    Raises:
        HTTPException 401: si el token es inválido o expirado.
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
            issuer="baqueano-natales",
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidIssuerError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Issuer inválido",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token inválido: {e}",
            headers={"WWW-Authenticate": "Bearer"},
        )
