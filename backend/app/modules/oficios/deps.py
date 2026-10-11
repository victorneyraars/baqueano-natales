"""Dependencias de FastAPI del modulo oficios."""
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from sqlalchemy import select

from app.core.db import DbSession
from app.modules.auth.deps import CurrentUser
from app.modules.auth.models import RolUsuario
from app.modules.oficios.models import (
    MecanicaCategoriaServicio,
    MecanicaRepuesto,
    OrdenTrabajo,
)


async def get_categoria_mecanica(
    categoria_id: UUID,
    user: CurrentUser,
    db: DbSession,
) -> MecanicaCategoriaServicio:
    """Carga una categoria de mecanica (solo admin puede modificarla)."""
    obj = (
        await db.execute(
            select(MecanicaCategoriaServicio).where(
                MecanicaCategoriaServicio.id == categoria_id
            )
        )
    ).scalar_one_or_none()
    if obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoria no encontrada",
        )
    return obj


CategoriaMecanica = Annotated[
    MecanicaCategoriaServicio, Depends(get_categoria_mecanica)
]


async def get_repuesto(
    repuesto_id: UUID,
    user: CurrentUser,
    db: DbSession,
) -> MecanicaRepuesto:
    """Carga un repuesto (solo admin puede modificarlo)."""
    obj = (
        await db.execute(
            select(MecanicaRepuesto).where(MecanicaRepuesto.id == repuesto_id)
        )
    ).scalar_one_or_none()
    if obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Repuesto no encontrado",
        )
    return obj


Repuesto = Annotated[MecanicaRepuesto, Depends(get_repuesto)]


async def get_orden(
    orden_id: UUID,
    user: CurrentUser,
    db: DbSession,
) -> OrdenTrabajo:
    """Carga una orden validando permisos (prestador due?o, cliente due?o o admin)."""
    from app.modules.oficios.models import OrdenTrabajo as _OT

    stmt = (
        select(_OT)
        .where(_OT.id == orden_id)
        .options(
            selectinload(_OT.items),
            selectinload(_OT.historial),
        )
    )
    orden = (await db.execute(stmt)).scalar_one_or_none()
    if orden is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Orden no encontrada",
        )

    # Admin puede ver cualquier orden
    if user.rol == RolUsuario.ADMIN:
        return orden

    # Cliente due?o
    if orden.cliente_id == user.id:
        return orden

    # Prestador due?o: validar que el prestador pertenezca al usuario
    from app.modules.prestadores.models import Prestador
    prestador = (
        await db.execute(
            select(Prestador).where(Prestador.id == orden.prestador_id)
        )
    ).scalar_one_or_none()
    if prestador is not None and prestador.usuario_id == user.id:
        return orden

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="No tenes permiso sobre esta orden",
    )


OrdenDelUsuario = Annotated[OrdenTrabajo, Depends(get_orden)]
