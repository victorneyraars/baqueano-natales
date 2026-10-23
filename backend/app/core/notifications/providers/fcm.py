"""Provider FCM. Implementa NotificationProvider usando firebase-admin."""
import asyncio
import logging
from datetime import timedelta

from firebase_admin import messaging

from app.core.config import settings
from app.core.firebase import get_firebase_app
from app.core.notifications.providers.base import NotificationProvider, SendResult

logger = logging.getLogger(__name__)


class FcmProvider(NotificationProvider):
    """Envia notificaciones via Firebase Cloud Messaging."""

    def __init__(self, channel_id: str = "baqueano_turnos_v6"):
        self.channel_id = channel_id

    async def send(self, token, titulo, body, data=None, analytics_label=None,
                   prioridad="high", ttl_hours=24, collapse_key=None):
        if not settings.FCM_ENABLED:
            return SendResult(success=False, error_code="FCM_DISABLED",
                              error_message="FCM disabled in settings")
        if not token:
            return SendResult(success=False, error_code="EMPTY_TOKEN",
                              error_message="Empty token")

        try:
            get_firebase_app()
            message = self._build_message(
                token=token, titulo=titulo, body=body, data=data,
                analytics_label=analytics_label, prioridad=prioridad,
                ttl_hours=ttl_hours, collapse_key=collapse_key,
            )
            message_id = await asyncio.to_thread(messaging.send, message)
            logger.info("FCM enviado: id=%s", message_id)
            return SendResult(success=True, message_id=message_id)
        except messaging.UnregisteredError:
            logger.warning("FCM: token unregistered (%.20s...)", token)
            return SendResult(success=False, error_code="UNREGISTERED",
                              error_message="Token unregistered")
        except messaging.SenderIdMismatchError:
            logger.error("FCM: sender ID mismatch")
            return SendResult(success=False, error_code="SENDER_ID_MISMATCH",
                              error_message="Sender ID mismatch")
        except Exception as e:
            logger.exception("FCM: error enviando push")
            return SendResult(success=False, error_code="UNKNOWN",
                              error_message=str(e))

    async def send_batch(self, tokens, titulo, body, data=None,
                         analytics_label=None, prioridad="high",
                         ttl_hours=24, collapse_key=None):
        if not settings.FCM_ENABLED:
            return [SendResult(success=False, error_code="FCM_DISABLED")
                    for _ in tokens]
        if not tokens:
            return []

        try:
            get_firebase_app()
            multicast = messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(title=titulo, body=body),
                data={k: str(v) for k, v in (data or {}).items()},
                android=messaging.AndroidConfig(
                    priority=prioridad,
                    ttl=timedelta(hours=ttl_hours),
                    collapse_key=collapse_key,
                    notification=messaging.AndroidNotification(
                        channel_id=self.channel_id,
                        sound="default",
                    ),
                ),
                fcm_options=(
                    messaging.FCMOptions(analytics_label=analytics_label)
                    if analytics_label else None
                ),
            )
            response = await asyncio.to_thread(
                messaging.send_each_for_multicast, multicast
            )
            results = [self._parse_response(r) for r in response.responses]
            success_count = sum(1 for r in results if r.success)
            logger.info(
                "FCM batch: %d/%d enviados", success_count, len(tokens)
            )
            return results
        except Exception as e:
            logger.exception("FCM: error en send_batch")
            return [SendResult(success=False, error_code="UNKNOWN",
                               error_message=str(e)) for _ in tokens]

    def _build_message(self, token, titulo, body, data, analytics_label,
                       prioridad, ttl_hours, collapse_key):
        return messaging.Message(
            notification=messaging.Notification(title=titulo, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
            android=messaging.AndroidConfig(
                priority=prioridad,
                ttl=timedelta(hours=ttl_hours),
                collapse_key=collapse_key,
                notification=messaging.AndroidNotification(
                    channel_id=self.channel_id,
                    sound="default",
                ),
            ),
            fcm_options=(
                messaging.FCMOptions(analytics_label=analytics_label)
                if analytics_label else None
            ),
        )

    def _parse_response(self, resp):
        if resp.success:
            return SendResult(success=True, message_id=resp.message_id)
        error_code = "UNKNOWN"
        error_message = "Unknown error"
        if resp.exception is not None:
            error_message = str(resp.exception)
            if hasattr(resp.exception, "code") and resp.exception.code:
                error_code = resp.exception.code
            elif isinstance(resp.exception, messaging.UnregisteredError):
                error_code = "UNREGISTERED"
        return SendResult(success=False, error_code=error_code,
                          error_message=error_message)
