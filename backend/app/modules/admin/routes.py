"""
Endpoints HTTP del módulo admin.
Todos requieren rol admin.
"""
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.db import DbSession
from app.modules.admin import services
from app.modules.admin.schemas import (
    CambiarRolRequest,
    EstadisticasUsuarios,
    ListarUsuariosQuery,
    ListarUsuariosResponse,
    UsuarioAdminResponse,
)
from app.modules.auth.deps import AdminUser
from app.modules.auth.models import RolUsuario

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[],  # La protección se hace por endpoint con AdminUser
)


# ---------------------------------------------------------
# Listado y detalle de usuarios
# ---------------------------------------------------------
@router.get(
    "/usuarios",
    response_model=ListarUsuariosResponse,
    summary="Listar usuarios",
    description=(
        "Lista usuarios con filtros opcionales y paginación. "
        "Solo admins."
    ),
)
async def listar_usuarios(
    admin: AdminUser,
    db: DbSession,
    rol: RolUsuario | None = Query(None, description="Filtrar por rol"),
    activo: bool | None = Query(None, description="Filtrar por estado activo"),
    verificado: bool | None = Query(None, description="Filtrar por verificación"),
    search: str | None = Query(
        None,
        max_length=100,
        description="Buscar por email, nombre o apellido",
    ),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> ListarUsuariosResponse:
    """Lista usuarios con filtros y paginación."""
    query = ListarUsuariosQuery(
        rol=rol,
        activo=activo,
        verificado=verificado,
        search=search,
        limit=limit,
        offset=offset,
    )

    usuarios, total = await services.listar_usuarios(db, query)

    return ListarUsuariosResponse(
        total=total,
        limit=limit,
        offset=offset,
        items=[UsuarioAdminResponse.model_validate(u) for u in usuarios],
    )


@router.get(
    "/usuarios/{user_id}",
    response_model=UsuarioAdminResponse,
    summary="Detalle de usuario",
    description="Devuelve todos los datos de un usuario. Solo admins.",
)
async def get_usuario(
    user_id: UUID,
    admin: AdminUser,
    db: DbSession,
) -> UsuarioAdminResponse:
    """Devuelve el detalle completo de un usuario."""
    user = await services.get_usuario_by_id(db, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )
    return UsuarioAdminResponse.model_validate(user)


# ---------------------------------------------------------
# Cambios de rol y estado
# ---------------------------------------------------------
@router.patch(
    "/usuarios/{user_id}/rol",
    response_model=UsuarioAdminResponse,
    summary="Cambiar rol de un usuario",
    description=(
        "Cambia el rol de un usuario. "
        "No puedes cambiar tu propio rol, ni degradar al último admin."
    ),
)
async def cambiar_rol(
    user_id: UUID,
    data: CambiarRolRequest,
    admin: AdminUser,
    db: DbSession,
) -> UsuarioAdminResponse:
    """Cambia el rol de un usuario."""
    user = await services.get_usuario_by_id(db, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )

    try:
        updated = await services.cambiar_rol(db, user, data.rol, admin)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return UsuarioAdminResponse.model_validate(updated)


@router.patch(
    "/usuarios/{user_id}/verificar",
    response_model=UsuarioAdminResponse,
    summary="Verificar/desverificar usuario",
    description="Marca o desmarca a un usuario como verificado.",
)
async def verificar_usuario(
    user_id: UUID,
    admin: AdminUser,
    db: DbSession,
    verificado: bool = Query(True, description="True para verificar, False para desverificar"),
) -> UsuarioAdminResponse:
    """Marca o desmarca como verificado."""
    user = await services.get_usuario_by_id(db, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )

    updated = await services.verificar_usuario(db, user, verificado, admin)
    return UsuarioAdminResponse.model_validate(updated)


@router.patch(
    "/usuarios/{user_id}/reactivar",
    response_model=UsuarioAdminResponse,
    summary="Reactivar usuario",
    description="Reactiva un usuario previamente desactivado.",
)
async def reactivar_usuario(
    user_id: UUID,
    admin: AdminUser,
    db: DbSession,
) -> UsuarioAdminResponse:
    """Reactiva un usuario."""
    user = await services.get_usuario_by_id(db, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )

    updated = await services.reactivar_usuario(db, user, admin)
    return UsuarioAdminResponse.model_validate(updated)


@router.delete(
    "/usuarios/{user_id}",
    response_model=UsuarioAdminResponse,
    summary="Desactivar usuario",
    description=(
        "Desactiva un usuario (soft delete). "
        "No puedes desactivarte a ti mismo, ni al último admin."
    ),
)
async def desactivar_usuario(
    user_id: UUID,
    admin: AdminUser,
    db: DbSession,
) -> UsuarioAdminResponse:
    """Desactiva un usuario."""
    user = await services.get_usuario_by_id(db, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )

    try:
        updated = await services.desactivar_usuario(db, user, admin)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return UsuarioAdminResponse.model_validate(updated)


# ---------------------------------------------------------
# Estadísticas
# ---------------------------------------------------------
@router.get(
    "/estadisticas",
    response_model=EstadisticasUsuarios,
    summary="Estadísticas de usuarios",
    description="Total, activos, inactivos, verificados, y desglose por rol.",
)
async def get_estadisticas(
    admin: AdminUser,
    db: DbSession,
) -> EstadisticasUsuarios:
    """Devuelve estadísticas globales de usuarios."""
    stats = await services.get_estadisticas(db)
    return EstadisticasUsuarios(**stats)
