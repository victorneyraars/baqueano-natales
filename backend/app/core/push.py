"""DEPRECATED: usar app.core.notifications.service.NotificationService.

Este modulo es un wrapper de compatibilidad. Delega al sistema de
notificaciones nuevo (app.core.notifications) manteniendo las firmas
legacy para no romper callers existentes (worker de recordatorios, etc).

Cuando todos los callers hayan migrado al service, este modulo se puede
eliminar.
"""
import logging
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.notifications.providers import FcmProvider
from app.core.notifications.service import get_notification_service

logger = logging.getLogger(__name__)


async def enviar_push(
    fcm_token: str,
    titulo: str,
    body: str,
    data: dict | None = None,
) -> bool:
    """Envia un push a un token especifico. Nunca lanza: devuelve True/False.

    Wrapper sobre FcmProvider. Para el flujo completo (preferencias, log,
    limpieza de tokens), usar NotificationService.enviar_a_usuario().
    """
    provider = FcmProvider()
    result = await provider.send(
        token=fcm_token,
        titulo=titulo,
        body=body,
        data=data,
    )
    return result.success


async def enviar_push_a_usuario(
    user_id: UUID,
    titulo: str,
    body: str,
    data: dict | None = None,
    db: AsyncSession | None = None,
) -> bool:
    """Busca los tokens del usuario y envia. Nunca lanza.

    Wrapper sobre NotificationService.enviar_legacy() (sin chequeo de
    preferencias ni quiet hours, para mantener el comportamiento legacy).
    """
    service = get_notification_service()
    return await service.enviar_legacy(
        usuario_id=user_id,
        titulo=titulo,
        body=body,
        data=data,
        db=db,
    )
