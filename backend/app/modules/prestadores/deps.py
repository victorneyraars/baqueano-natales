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
    if prestador.usuario_id == user.id:
        return prestador

    # Colaborador activo (verificar email en JSONB)
    email_user = (user.email or "").lower()
    if email_user:
        colaboradores = prestador.colaboradores or []
        for c in colaboradores:
            if not isinstance(c, dict):
                continue
            if (
                (c.get("email") or "").lower() == email_user
                and c.get("activado_at") is not None
            ):
                return prestador

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="No tenés permiso sobre este prestador",
    )


async def get_prestador_del_owner(
    prestador_id: UUID,
    user: CurrentUser,
    db: DbSession,
) -> Prestador:
    """Carga un prestador y valida que el usuario sea SU PROPIETARIO.

    A diferencia de get_prestador_del_propietario, los colaboradores
    NO tienen acceso a los endpoints que dependen de esta dependencia
    (colaboradores CRUD, audit log completo, etc.).

    El admin global también pasa (útil para soporte).
    """
    prestador = await get_prestador_del_propietario(
        prestador_id=prestador_id, user=user, db=db
    )
    # Admin sigue pasando (soporte interno)
    if user.rol == RolUsuario.ADMIN:
        return prestador
    # Solo el dueño real
    if prestador.usuario_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el propietario puede realizar esta acción",
        )
    return prestador


PrestadorPropietario = Annotated[
    Prestador, Depends(get_prestador_del_propietario)
]
PrestadorOwner = Annotated[
    Prestador, Depends(get_prestador_del_owner)
]