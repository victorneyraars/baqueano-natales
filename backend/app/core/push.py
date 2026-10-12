"""Servicio de push notifications via Firebase Cloud Messaging (FCM).

Transversal: cualquier modulo puede importar enviar_push / enviar_push_a_usuario.

Diseno:
- El SDK de FCM es sincrono (httpx interno). Se corre en un thread aparte
  con asyncio.to_thread para no bloquear el event loop de FastAPI.
- NUNCA propaga excepciones. Devuelve True/False. El caller (ej: worker)
  no debe crashear por un push fallido.
- Si FCM_ENABLED=False, es no-op (util para tests + fallback prod).
"""
import asyncio
import logging
from uuid import UUID

from firebase_admin import messaging
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db import AsyncSessionLocal
from app.core.firebase import get_firebase_app
from app.modules.auth.models import Usuario

logger = logging.getLogger(__name__)


async def enviar_push(
    fcm_token: str,
    titulo: str,
    body: str,
    data: dict | None = None,
) -> bool:
    """Envia un push a un token FCM. Nunca lanza: devuelve True/False.

    Args:
        fcm_token: Token FCM del dispositivo destino.
        titulo: Titulo de la notificacion.
        body: Cuerpo de la notificacion.
        data: Payload custom (strings). Util para routing en la app.

    Returns:
        True si FCM acepto el mensaje, False en cualquier otro caso
        (token vacio, FCM deshabilitado, error de red, token invalido, etc).
    """
    if not settings.FCM_ENABLED:
        logger.debug("FCM deshabilitado (FCM_ENABLED=False), skip push")
        return False

    if not fcm_token:
        logger.debug("FCM: token vacio, skip push")
        return False

    try:
        get_firebase_app()  # asegurar init del SDK

        message = messaging.Message(
            notification=messaging.Notification(title=titulo, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=fcm_token,
        )
        message_id = await asyncio.to_thread(messaging.send, message)
        logger.info("FCM push enviado: id=%s", message_id)
        return True
    except messaging.UnregisteredError:
        # Token invalido (app desinstalada, token expirado). Limpiar.
        logger.warning("FCM: token no registrado (%.20s...)", fcm_token)
        return False
    except Exception:
        logger.exception("FCM: error enviando push (token=%.20s...)", fcm_token)
        return False


async def enviar_push_a_usuario(
    user_id: UUID,
    titulo: str,
    body: str,
    data: dict | None = None,
    db: AsyncSession | None = None,
) -> bool:
    """Busca el token del usuario y envia. Nunca lanza.

    Si el usuario no tiene fcm_token o no existe, devuelve False sin enviar.

    Args:
        user_id: ID del usuario destino.
        titulo, body, data: ver enviar_push.
        db: Sesion opcional. Si es None, abre una propia (uso desde worker).

    Returns:
        True si el push se envio, False en cualquier otro caso.
    """
    try:
        if db is None:
            async with AsyncSessionLocal() as session:
                return await _enviar_con_db(session, user_id, titulo, body, data)
        return await _enviar_con_db(db, user_id, titulo, body, data)
    except Exception:
        logger.exception("FCM: error enviando push a user_id=%s", user_id)
        return False


async def _enviar_con_db(
    db: AsyncSession,
    user_id: UUID,
    titulo: str,
    body: str,
    data: dict | None,
) -> bool:
    stmt = select(Usuario).where(Usuario.id == user_id)
    user = (await db.execute(stmt)).scalar_one_or_none()
    if user is None:
        logger.warning("FCM: usuario %s no encontrado", user_id)
        return False
    if not user.fcm_token:
        logger.debug("FCM: usuario %s sin fcm_token registrado", user_id)
        return False
    return await enviar_push(user.fcm_token, titulo, body, data)
