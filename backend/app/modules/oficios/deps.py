"""Dependencias de FastAPI del modulo oficios."""
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from sqlalchemy import select

from app.core.db import DbSession
from app.modules.auth.deps import CurrentUser
from app.modules.auth.models import RolUsuario
from app.modules.oficios.models import MecanicaCategoriaServicio, MecanicaRepuesto


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
