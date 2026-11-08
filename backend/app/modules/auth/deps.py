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


# =========================================================
# Helper de superusuario (admin del ecosistema)
# =========================================================

def es_admin(user) -> bool:
    """Devuelve True si el usuario es admin del ecosistema Baqueano.
    
    Los admins tienen acceso total a todos los prestadores, oficios y
    comercios, sin necesidad de ser dueños ni colaboradores.
    """
    from app.modules.auth.models import RolUsuario
    return user.rol == RolUsuario.ADMIN


# =========================================================
# Multi-tenant: helpers de super admin y prestadores
# =========================================================

async def require_super_admin(
    user: Annotated[Usuario, Depends(require_admin)],
) -> Usuario:
    """
    Verifica que el usuario sea super admin del ecosistema.
    Solo ellos pueden asignar admins a prestadores.
    """
    if not user.es_super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere ser super admin del ecosistema",
        )
    return user


async def get_admin_prestadores_ids(
    user: Usuario,
    db: AsyncSession,
) -> list[UUID] | None:
    """
    Devuelve la lista de prestador_ids que el admin puede gestionar.
    - Retorna None si es super admin (ve todo)
    - Retorna [] si es admin sin prestadores asignados
    - Retorna [uuid1, uuid2, ...] si tiene prestadores asignados
    """
    if not es_admin(user):
        return []

    if user.es_super_admin:
        return None  # None = ve todo

    from app.modules.auth.models_admin_prestador import AdminPrestador
    result = await db.execute(
        select(AdminPrestador.prestador_id).where(AdminPrestador.admin_id == user.id)
    )
    return [row[0] for row in result.all()]


async def admin_puede_gestionar_prestador(
    user: Usuario,
    prestador_id: UUID,
    db: AsyncSession,
) -> bool:
    """Verifica si el admin puede gestionar un prestador específico."""
    if not es_admin(user):
        return False
    if user.es_super_admin:
        return True
    prestador_ids = await get_admin_prestadores_ids(user, db)
    return prestador_ids is not None and prestador_id in prestador_ids


# Alias para usar en endpoints
SuperAdminUser = Annotated[Usuario, Depends(require_super_admin)]
