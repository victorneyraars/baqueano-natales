"""Dependencia de auth mixta para endpoints de integraciones.

Acepta dos modos:
- X-API-Key: server-to-server (script externo, otro microservicio).
- Authorization: Bearer <JWT admin>: App Admin (modo actual).

Devuelve Usuario si es JWT admin, o None si es API Key.
"""
import secrets
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db import get_db
from app.modules.auth.deps import bearer_scheme, get_current_user
from app.modules.auth.models import RolUsuario, Usuario


def _verify_api_key(api_key: str | None) -> bool:
    """Compara constant-time contra la lista configurada."""
    if not api_key:
        return False
    return any(
        secrets.compare_digest(api_key, valid)
        for valid in settings.integrations_api_keys_list
    )


async def _try_jwt_admin(
    credentials: HTTPAuthorizationCredentials | None,
    db: AsyncSession,
) -> Usuario | None:
    """Intenta validar JWT admin. None si falla (silencioso)."""
    if credentials is None:
        return None
    try:
        user = await get_current_user(credentials, db)
    except HTTPException:
        return None
    if user.rol == RolUsuario.ADMIN:
        return user
    return None


async def require_integrations_auth(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
    x_api_key: Annotated[str | None, Header(alias="X-API-Key")] = None,
) -> Usuario | None:
    """Autoriza via X-API-Key o JWT admin. 401 si ninguno valido."""
    if x_api_key is not None:
        if _verify_api_key(x_api_key):
            return None
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API Key invalida",
        )

    user = await _try_jwt_admin(credentials, db)
    if user is not None:
        return user

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Requiere X-API-Key o Authorization: Bearer <JWT admin>",
        headers={"WWW-Authenticate": "Bearer"},
    )


AuthorizedIntegrations = Annotated[Usuario | None, Depends(require_integrations_auth)]
