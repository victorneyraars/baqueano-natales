"""
Dependencias de FastAPI para autenticación.
Se inyectan en los endpoints con Depends().
"""
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import decode_access_token
from app.modules.auth.models import RolUsuario, Usuario

# Esquema HTTP Bearer para documentación automática
bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Usuario:
    """
    Extrae el usuario actual desde el JWT en el header Authorization.

    Espera: `Authorization: Bearer <jwt>`

    Raises:
        HTTPException 401: si falta el header, el JWT es inválido, o el usuario no existe/inactivo.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Falta el header Authorization",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Decodificar el JWT (valida firma y expiración)
    payload = decode_access_token(credentials.credentials)

    # Buscar el usuario por ID
    user_id_str = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token sin subject",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        user_id = UUID(user_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Subject inválido",
            headers={"WWW-Authenticate": "Bearer"},
        )

    result = await db.execute(select(Usuario).where(Usuario.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.activo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuario desactivado",
        )

    return user


async def require_admin(
    user: Annotated[Usuario, Depends(get_current_user)],
) -> Usuario:
    """
    Verifica que el usuario actual tenga rol admin.

    Raises:
        HTTPException 403: si el usuario no es admin.
    """
    if user.rol != RolUsuario.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol admin",
        )
    return user


# Tipos anotados para usar en endpoints
CurrentUser = Annotated[Usuario, Depends(get_current_user)]
AdminUser = Annotated[Usuario, Depends(require_admin)]
