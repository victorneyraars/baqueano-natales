"""
Dependencias de FastAPI para el módulo comercios.

Incluye la dependencia que carga un comercio por ID y verifica que el
usuario sea su propietario (o admin, que puede gestionar cualquiera).
"""
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status

from app.core.db import DbSession
from app.modules.auth.deps import CurrentUser
from app.modules.auth.models import RolUsuario
from app.modules.comercios.models import Comercio


async def get_comercio_del_propietario(
    comercio_id: UUID,
    user: CurrentUser,
    db: DbSession,
) -> Comercio:
    """
    Carga un comercio por ID y verifica permisos.

    Reglas:
    - Admin puede acceder a cualquier comercio (útil para debug/soporte).
    - Un usuario normal solo puede acceder a comercios propios.

    Raises:
        HTTPException 404: si el comercio no existe o está inactivo.
        HTTPException 403: si el usuario no es propietario ni admin.
    """
    comercio = await db.get(Comercio, comercio_id)
    if comercio is None or not comercio.activo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Comercio no encontrado",
        )

    # Admin puede gestionar cualquier comercio
    if user.rol == RolUsuario.ADMIN:
        return comercio

    # Propietario
    if comercio.propietario_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenés permiso sobre este comercio",
        )
    return comercio


ComercioPropietario = Annotated[
    Comercio, Depends(get_comercio_del_propietario)
]