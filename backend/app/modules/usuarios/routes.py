"""
Endpoints HTTP del módulo usuarios.
"""
import logging
from uuid import UUID

from fastapi import APIRouter, File, HTTPException, UploadFile, status

from app.core.db import DbSession
from app.modules.auth.deps import CurrentUser
from app.modules.usuarios import services
from app.modules.usuarios.schemas import (
    AvatarUploadResponse,
    MessageResponse,
    UsuarioMeResponse,
    UsuarioPublicoResponse,
    UsuarioUpdate,
)
from app.shared.storage.base import (
    AvatarStorage,
    FileTooLargeError,
    InvalidFileTypeError,
    StorageError,
)
from app.shared.storage.local import LocalAvatarStorage

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/usuarios", tags=["usuarios"])


# Instancia global del storage (se puede cambiar por otra implementación)
# Nota: en el futuro esto podría venir de un factory o dependency injection
_avatar_storage: AvatarStorage = LocalAvatarStorage()


def get_avatar_storage() -> AvatarStorage:
    """Dependency para obtener el storage de avatares."""
    return _avatar_storage


# ---------------------------------------------------------
# Endpoints del usuario actual (/me)
# ---------------------------------------------------------
@router.get(
    "/me",
    response_model=UsuarioMeResponse,
    summary="Perfil del usuario actual",
    description="Devuelve todos los datos del usuario autenticado.",
)
async def get_me(user: CurrentUser) -> UsuarioMeResponse:
    """Devuelve el perfil completo del usuario autenticado."""
    return UsuarioMeResponse.model_validate(user)


@router.patch(
    "/me",
    response_model=UsuarioMeResponse,
    summary="Actualizar perfil",
    description="Actualiza nombre y apellido del usuario autenticado.",
)
async def update_me(
    data: UsuarioUpdate,
    user: CurrentUser,
    db: DbSession,
) -> UsuarioMeResponse:
    """Actualiza los datos editables del usuario actual."""
    updated = await services.update_usuario(db, user, data)
    return UsuarioMeResponse.model_validate(updated)


@router.post(
    "/me/avatar",
    response_model=AvatarUploadResponse,
    summary="Subir avatar",
    description=(
        "Sube un avatar (JPEG, PNG o WebP, máximo 5 MB). "
        "La imagen se redimensiona a 512px y se comprime."
    ),
)
async def upload_avatar(
    user: CurrentUser,
    db: DbSession,
    file: UploadFile = File(..., description="Archivo de imagen"),
) -> AvatarUploadResponse:
    """
    Sube y procesa el avatar del usuario.
    """
    # Validar que venga archivo
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se recibió ningún archivo",
        )

    # Leer contenido
    try:
        content = await file.read()
    except Exception as e:
        logger.error(f"Error leyendo archivo: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Error leyendo el archivo",
        )

    # Validar tamaño antes de procesar (fail fast)
    if len(content) > _avatar_storage.MAX_SIZE_BYTES:
        max_mb = _avatar_storage.MAX_SIZE_BYTES // (1024 * 1024)
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"El archivo excede el máximo permitido ({max_mb} MB)",
        )

    # Guardar con el storage
    try:
        updated = await services.update_avatar(db, user, content, _avatar_storage)
    except FileTooLargeError as e:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=str(e),
        )
    except InvalidFileTypeError as e:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=str(e),
        )
    except StorageError as e:
        logger.error(f"Error de storage: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error guardando el avatar",
        )

    return AvatarUploadResponse(avatar_url=updated.avatar_url or "")


@router.delete(
    "/me",
    response_model=MessageResponse,
    summary="Desactivar cuenta",
    description=(
        "Desactiva la cuenta del usuario actual (soft delete). "
        "Los datos se preservan pero el usuario no puede volver a loguearse."
    ),
)
async def deactivate_me(
    user: CurrentUser,
    db: DbSession,
) -> MessageResponse:
    """Desactiva la cuenta del usuario actual."""
    await services.deactivate_usuario(db, user)
    return MessageResponse(message="Cuenta desactivada correctamente")


# ---------------------------------------------------------
# Endpoints públicos
# ---------------------------------------------------------
@router.get(
    "/{user_id}",
    response_model=UsuarioPublicoResponse,
    summary="Perfil público de un usuario",
    description=(
        "Devuelve el perfil público de un usuario (nombre, apellido, "
        "avatar, rol). No requiere autenticación."
    ),
)
async def get_usuario(
    user_id: UUID,
    db: DbSession,
) -> UsuarioPublicoResponse:
    """Devuelve el perfil público de un usuario activo."""
    user = await services.get_usuario_publico(db, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )
    return UsuarioPublicoResponse.model_validate(user)
