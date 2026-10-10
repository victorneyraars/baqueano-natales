"""
Dependencias FastAPI del módulo social.

Re-exporta `AdminUser` y `CurrentUser` del módulo auth para que los
routers de social importen de acá y sea fácil moverlos si hiciera falta.

Agrega la dependencia `get_cuenta_del_propietario` que carga una cuenta
por ID y verifica que el usuario actual tenga permiso para gestionarla.

Reglas de permisos (alineadas con `prestadores/deps.py`):
- Admin: acceso a cualquier cuenta (útil para soporte/debug).
- Usuario normal: solo si es el dueño del recurso apuntado
  (`propietario_tipo` + `propietario_id`).

En etapas posteriores, el módulo vertical (prestadores, comercios) va a
verificar más fino ("¿este usuario es dueño de este prestador?"). Por
ahora la verificación es simple: `propietario_id == user.id` para
propietarios no-BAQUEANO.
"""
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from sqlalchemy import select

from app.core.db import DbSession
from app.modules.auth.deps import AdminUser, CurrentUser  # re-export
from app.modules.auth.models import RolUsuario
from app.modules.social.models import CuentaSocial, PropietarioTipo

__all__ = [
    "AdminUser",
    "CurrentUser",
    "CuentaDelPropietario",
    "get_cuenta_del_propietario",
]


async def get_cuenta_del_propietario(
    cuenta_id: UUID,
    user: CurrentUser,
    db: DbSession,
) -> CuentaSocial:
    """
    Carga una cuenta social por ID y verifica que el usuario pueda
    gestionarla.

    Reglas:
    - Admin: acceso total.
    - Cuenta central (propietario_tipo=BAQUEANO, propietario_id=NULL):
        solo admin.
    - Cuenta de un recurso (PRESTADOR/COMERCIO): solo si el
        `propietario_id` coincide con el ID del usuario actual. En
        etapas posteriores esto se refina consultando al módulo vertical.

    Raises:
        HTTPException 404: cuenta no encontrada.
        HTTPException 403: usuario sin permiso.
    """
    stmt = select(CuentaSocial).where(CuentaSocial.id == cuenta_id)
    cuenta = (await db.execute(stmt)).scalar_one_or_none()

    if cuenta is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cuenta social no encontrada",
        )

    # Admin: acceso total
    if user.rol == RolUsuario.ADMIN:
        return cuenta

    # Cuenta central de Baqueano: solo admin
    if cuenta.propietario_tipo == PropietarioTipo.BAQUEANO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo admin puede gestionar la cuenta central",
        )

    # Cuenta de un recurso: verificar que sea del usuario actual
    if cuenta.propietario_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenés permiso sobre esta cuenta",
        )

    return cuenta


CuentaDelPropietario = Annotated[
    CuentaSocial, Depends(get_cuenta_del_propietario)
]