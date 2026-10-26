"""
Dependencias de FastAPI para el módulo prestadores.

Incluye la dependencia que carga un prestador por ID y verifica que el
usuario sea su propietario (o admin, que puede gestionar cualquiera).
"""
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.db import DbSession
from app.modules.auth.deps import CurrentUser
from app.modules.auth.models import RolUsuario
from app.modules.prestadores.models import Prestador


async def get_prestador_del_propietario(
    prestador_id: UUID,
    user: CurrentUser,
    db: DbSession,
) -> Prestador:
    """
    Carga un prestador por ID y verifica permisos.

    Reglas:
    - Admin puede acceder a cualquier prestador (útil para debug/soporte).
    - Un usuario normal solo puede acceder a prestadores propios.

    Raises:
        HTTPException 404: si el prestador no existe o está inactivo.
        HTTPException 403: si el usuario no es propietario ni admin.
    """
    stmt = (
        select(Prestador)
        .where(
            Prestador.id == prestador_id,
            Prestador.activo.is_(True),
        )
        .options(
            selectinload(Prestador.categoria),
        )
    )
    prestador = (await db.execute(stmt)).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prestador no encontrado",
        )

    # Admin puede gestionar cualquier prestador
    if user.rol == RolUsuario.ADMIN:
        return prestador

    # Propietario
    if prestador.usuario_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenés permiso sobre este prestador",
        )
    return prestador


PrestadorPropietario = Annotated[
    Prestador, Depends(get_prestador_del_propietario)
]