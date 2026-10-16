"""Preview token: firma lo que el usuario vio en el preview.

Cuando el usuario pide /release/preview, se le devuelve un JWT con:
- version_name, target_tag, next_version_code, head_sha, nonce
- expira en 5 min

Cuando el usuario manda /release/trigger, hay que presentar el mismo
preview_token. Asi nos aseguramos que:
1. El usuario vio un preview antes (no hay trigger a ciegas).
2. El head_sha no cambio en el medio (no cambia el codigo bajo los pies).
3. El token no es de hace 3 dias (5 min de ventana).

Notas:
- Usa PyJWT (pyjwt==2.10.1), NO python-jose.
- El algoritmo viene de settings.ALGORITHM.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from jwt.exceptions import InvalidTokenError

from app.core.config import settings

logger = logging.getLogger(__name__)

PREVIEW_TTL_SECONDS = 5 * 60  # 5 minutos
ISSUER = "baqueano-natales"
TOKEN_KIND = "release_preview"


class PreviewTokenError(Exception):
    """El token es invalido, expiro, o no es del tipo esperado."""


def crear_preview_token(
    *,
    version_name: str,
    target_tag: str,
    next_version_code: int,
    head_sha: str,
    branch: str,
    user_id: str,
) -> tuple[str, datetime]:
    """Crea un JWT firmado con el preview. Devuelve (token, expires_at)."""
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(seconds=PREVIEW_TTL_SECONDS)

    payload = {
        "iss": ISSUER,
        "sub": user_id,
        "kind": TOKEN_KIND,
        "nonce": uuid.uuid4().hex,
        "version_name": version_name,
        "target_tag": target_tag,
        "next_version_code": next_version_code,
        "head_sha": head_sha,
        "branch": branch,
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return token, expires_at


def validar_preview_token(token: str, *, expected_user_id: str) -> dict[str, Any]:
    """Valida el token. Devuelve el payload o levanta PreviewTokenError."""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
            issuer=ISSUER,
        )
    except InvalidTokenError as e:
        logger.warning("ops.preview_token.invalid", extra={"error": str(e)})
        raise PreviewTokenError(f"Token invalido o expirado: {e}") from e

    if payload.get("kind") != TOKEN_KIND:
        raise PreviewTokenError("Token no es de tipo release_preview")

    if payload.get("sub") != expected_user_id:
        raise PreviewTokenError("Token pertenece a otro usuario")

    return payload