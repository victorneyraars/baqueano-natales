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
    FcmTokenResponse,
    FcmTokenUpdate,
    MessageResponse,
    PreferenciaNotificacionResponse,
    PreferenciaNotificacionUpdate,
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
    "/me/fcm-token",
    response_model=FcmTokenResponse,
    summary="Registrar token FCM del dispositivo",
    description=(
        "Guarda el token de Firebase Cloud Messaging del dispositivo actual. "
        "El token se sobreescribe en cada login (modelo single-device)."
    ),
)
async def registrar_fcm_token(
    data: FcmTokenUpdate,
    user: CurrentUser,
    db: DbSession,
) -> FcmTokenResponse:
    """Registra o actualiza el token FCM del usuario actual."""
    from sqlalchemy import select, update
    from app.core.notifications.models import FcmToken

    # 1. Actualizar columna legacy (compatibilidad)
    user.fcm_token = data.token

    # 2. Desactivar tokens viejos del mismo usuario (single-device)
    await db.execute(
        update(FcmToken)
        .where(FcmToken.usuario_id == user.id)
        .where(FcmToken.token != data.token)
        .values(activo=False)
    )

    # 3. UPSERT en fcm_tokens (tabla que usa NotificationService)
    existing = await db.execute(
        select(FcmToken).where(FcmToken.token == data.token)
    )
    existing_token = existing.scalar_one_or_none()

    if existing_token:
        existing_token.usuario_id = user.id
        existing_token.activo = True
    else:
        db.add(FcmToken(
            usuario_id=user.id,
            token=data.token,
            plataforma='android',
            activo=True,
        ))

    await db.flush()
    await db.refresh(user)
    preview = data.token[:20] + "..." if len(data.token) > 20 else data.token
    return FcmTokenResponse(token_preview=preview)


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
    "/me/preferencias-notificacion",
    response_model=PreferenciaNotificacionResponse,
    summary="Preferencias de notificacion del usuario",
)
async def get_preferencias_notificacion(
    user: CurrentUser,
    db: DbSession,
) -> PreferenciaNotificacionResponse:
    """Devuelve las preferencias del usuario (crea defaults si no existen)."""
    prefs = await services.get_or_create_preferencias(db, user)
    return PreferenciaNotificacionResponse.model_validate(prefs)


@router.put(
    "/me/preferencias-notificacion",
    response_model=PreferenciaNotificacionResponse,
    summary="Actualizar preferencias de notificacion",
)
async def update_preferencias_notificacion(
    data: PreferenciaNotificacionUpdate,
    user: CurrentUser,
    db: DbSession,
) -> PreferenciaNotificacionResponse:
    """Actualiza las preferencias del usuario (parcial)."""
    prefs = await services.update_preferencias(db, user, data)
    return PreferenciaNotificacionResponse.model_validate(prefs)


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
