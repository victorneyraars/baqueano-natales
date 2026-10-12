"""
Servicios de gestión de usuarios.
Contiene la lógica de negocio, separada de los endpoints.
"""
import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import Usuario
from app.modules.usuarios.schemas import UsuarioUpdate
from app.shared.storage.base import AvatarStorage

logger = logging.getLogger(__name__)


async def get_usuario_by_id(
    db: AsyncSession,
    user_id: UUID,
) -> Usuario | None:
    """
    Busca un usuario por ID.

    Returns:
        Usuario o None si no existe.
    """
    result = await db.execute(select(Usuario).where(Usuario.id == user_id))
    return result.scalar_one_or_none()


async def get_usuario_publico(
    db: AsyncSession,
    user_id: UUID,
) -> Usuario | None:
    """
    Busca un usuario activo para exposición pública.
    Solo devuelve usuarios activos (filtra desactivados).

    Returns:
        Usuario activo o None.
    """
    result = await db.execute(
        select(Usuario).where(
            Usuario.id == user_id,
            Usuario.activo.is_(True),
        )
    )
    return result.scalar_one_or_none()


async def update_usuario(
    db: AsyncSession,
    user: Usuario,
    data: UsuarioUpdate,
) -> Usuario:
    """
    Actualiza los campos editables del usuario.

    Solo actualiza los campos que vienen en el payload (no sobrescribe
    con None). El rol, email, phone, etc. NO son editables desde acá.

    Args:
        db: Sesión de base de datos.
        user: Usuario a actualizar.
        data: Datos nuevos.

    Returns:
        Usuario actualizado.
    """
    update_data = data.model_dump(exclude_unset=True, exclude_none=True)

    for field, value in update_data.items():
        setattr(user, field, value)

    await db.flush()
    await db.refresh(user)
    logger.info(f"Usuario actualizado: {user.id} (campos: {list(update_data.keys())})")
    return user


async def update_avatar(
    db: AsyncSession,
    user: Usuario,
    content: bytes,
    storage: AvatarStorage,
) -> Usuario:
    """
    Sube el avatar de un usuario.

    Flujo:
    1. Guarda el avatar en el storage (valida tamaño/tipo).
    2. Actualiza el campo avatar_url del usuario.
    3. Devuelve el usuario actualizado.

    Args:
        db: Sesión de base de datos.
        user: Usuario a actualizar.
        content: Bytes del archivo subido.
        storage: Implementación de AvatarStorage.

    Returns:
        Usuario con avatar_url actualizado.

    Raises:
        StorageError: si falla el guardado (tamaño, tipo, IO).
    """
    # Guardar (puede lanzar StorageError)
    avatar_url = await storage.save_avatar(str(user.id), content)

    # Actualizar el usuario
    user.avatar_url = avatar_url
    await db.flush()
    await db.refresh(user)

    logger.info(f"Avatar actualizado: {user.id}")
    return user


async def deactivate_usuario(
    db: AsyncSession,
    user: Usuario,
) -> Usuario:
    """
    Desactiva un usuario (soft delete).

    NO borra el usuario, solo marca `activo = False`. Los datos se
    preservan para auditoría y para permitir reactivación.

    Args:
        db: Sesión de base de datos.
        user: Usuario a desactivar.

    Returns:
        Usuario desactivado.
    """
    user.activo = False
    await db.flush()
    await db.refresh(user)
    logger.warning(f"Usuario desactivado: {user.id} (email: {user.email})")
    return user


# ---------------------------------------------------------
# Preferencias de notificacion
# ---------------------------------------------------------
async def get_or_create_preferencias(db, usuario):
    """Devuelve las preferencias del usuario, o las crea con defaults."""
    from sqlalchemy import select
    from app.core.notifications.models import PreferenciaNotificacion

    stmt = select(PreferenciaNotificacion).where(
        PreferenciaNotificacion.usuario_id == usuario.id
    )
    prefs = (await db.execute(stmt)).scalar_one_or_none()
    if prefs is None:
        prefs = PreferenciaNotificacion(usuario_id=usuario.id)
        db.add(prefs)
        await db.flush()
        await db.refresh(prefs)
    return prefs


async def update_preferencias(db, usuario, data):
    """Actualiza las preferencias (parcial). Crea si no existen."""
    prefs = await get_or_create_preferencias(db, usuario)
    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(prefs, key, value)
    await db.flush()
    await db.refresh(prefs)
    return prefs
