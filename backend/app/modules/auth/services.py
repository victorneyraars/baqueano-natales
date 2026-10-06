"""
Servicios de autenticación: lógica de negocio.
Separa la lógica de los endpoints (routes) para mantenerlos delgados.
"""
import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.firebase import verify_id_token
from app.modules.auth.models import RolUsuario, Usuario

logger = logging.getLogger(__name__)


async def get_or_create_user_from_firebase(
    db: AsyncSession,
    id_token: str,
) -> Usuario:
    """
    Verifica un token de Firebase y crea/actualiza el usuario en la DB.

    Flujo:
    1. Verifica el ID token con Firebase Admin SDK.
    2. Busca el usuario por firebase_uid en la DB.
    3. Si no existe, lo crea con rol CLIENTE.
    4. Si existe, actualiza datos (email, nombre, avatar) y ultimo_login.

    Args:
        db: Sesión de base de datos.
        id_token: JWT de Firebase Auth enviado por la app.

    Returns:
        Usuario (nuevo o existente).

    Raises:
        ValueError: si el token es inválido o no tiene uid.
    """
    # 1. Verificar con Firebase
    try:
        decoded = verify_id_token(id_token)
    except Exception as e:
        logger.warning(f"Token de Firebase inválido: {e}")
        raise ValueError(f"Token inválido: {e}")

    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise ValueError("El token no contiene uid")

    # 2. Buscar en DB
    result = await db.execute(
        select(Usuario).where(Usuario.firebase_uid == firebase_uid)
    )
    user = result.scalar_one_or_none()

    # 3. Datos del token de Firebase
    email = decoded.get("email")
    nombre = decoded.get("name")
    avatar_url = decoded.get("picture")

    # Dividir nombre en nombre + apellido (heurística simple)
    nombre_parsed = None
    apellido_parsed = None
    if nombre:
        parts = nombre.strip().split(" ", 1)
        nombre_parsed = parts[0]
        if len(parts) > 1:
            apellido_parsed = parts[1]

    # 4. Crear o actualizar
    if user is None:
        # Usuario nuevo
        user = Usuario(
            firebase_uid=firebase_uid,
            email=email,
            nombre=nombre_parsed,
            apellido=apellido_parsed,
            avatar_url=avatar_url,
            rol=RolUsuario.CLIENTE,
            tiene_google=True,
            ultimo_login=datetime.now(timezone.utc),
        )
        db.add(user)
        await db.flush()  # Para obtener el id
        logger.info(f"Usuario nuevo creado: {user.id} (firebase_uid: {firebase_uid})")
    else:
        # Usuario existente: actualizar datos
        if email and user.email != email:
            user.email = email
        if nombre_parsed and user.nombre != nombre_parsed:
            user.nombre = nombre_parsed
        if apellido_parsed and user.apellido != apellido_parsed:
            user.apellido = apellido_parsed
        if avatar_url and user.avatar_url != avatar_url:
            user.avatar_url = avatar_url
        user.tiene_google = True
        user.ultimo_login = datetime.now(timezone.utc)
        logger.info(f"Usuario actualizado: {user.id}")

    return user
