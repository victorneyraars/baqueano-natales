"""Tests del wrapper push.py (compatibilidad con la implementacion previa).

push.py es un thin wrapper sobre:
- FcmProvider (para enviar_push por token).
- NotificationService.enviar_legacy() (para enviar_push_a_usuario).

Los mocks ahora apuntan a:
- app.core.notifications.providers.fcm.messaging.send
- app.core.notifications.providers.fcm.settings.FCM_ENABLED
"""
from unittest.mock import patch
from uuid import uuid4

from app.core import push


# ==================== enviar_push (por token) ====================


async def test_enviar_push_ok():
    """FCM acepta el mensaje -> True."""
    with patch(
        "app.core.notifications.providers.fcm.messaging.send",
        return_value="msg-id-123",
    ):
        ok = await push.enviar_push("token_test", "Titulo", "Body")
    assert ok is True


async def test_enviar_push_token_vacio():
    """Token vacio -> False, sin llamar a FCM."""
    with patch(
        "app.core.notifications.providers.fcm.messaging.send"
    ) as mock_send:
        ok = await push.enviar_push("", "Titulo", "Body")
    assert ok is False
    mock_send.assert_not_called()


async def test_enviar_push_error_no_propaga():
    """Excepcion de FCM -> False, no propaga."""
    with patch(
        "app.core.notifications.providers.fcm.messaging.send",
        side_effect=Exception("FCM down"),
    ):
        ok = await push.enviar_push("token_test", "Titulo", "Body")
    assert ok is False


async def test_enviar_push_deshabilitado(monkeypatch):
    """FCM_ENABLED=False -> False sin llamar a FCM."""
    from app.core.notifications.providers import fcm as fcm_module
    monkeypatch.setattr(fcm_module.settings, "FCM_ENABLED", False)

    with patch(
        "app.core.notifications.providers.fcm.messaging.send"
    ) as mock_send:
        ok = await push.enviar_push("token_test", "Titulo", "Body")
    assert ok is False
    mock_send.assert_not_called()


# ==================== enviar_push_a_usuario (por usuario) ====================


async def test_enviar_push_a_usuario_sin_token(db, usuario_cliente):
    """Usuario sin token (ni en fcm_tokens ni legacy) -> False, sin FCM."""
    with patch(
        "app.core.notifications.providers.fcm.messaging.send"
    ) as mock_send:
        ok = await push.enviar_push_a_usuario(
            usuario_cliente.id, "Titulo", "Body", db=db,
        )
    assert ok is False
    mock_send.assert_not_called()


async def test_enviar_push_a_usuario_con_token(db, usuario_cliente):
    """Usuario con token legacy -> True (auto-migracion a fcm_tokens).

    Nota: el flujo por usuario usa send_batch -> messaging.send_each_for_multicast
    (no messaging.send). El mock devuelve un BatchResponse fake con 1 success.
    """
    from unittest.mock import MagicMock

    usuario_cliente.fcm_token = "token_real_de_prueba"
    await db.flush()

    fake_response = MagicMock()
    fake_response.responses = [MagicMock(success=True, message_id="msg-id")]

    with patch(
        "app.core.notifications.providers.fcm.messaging.send_each_for_multicast",
        return_value=fake_response,
    ) as mock_send:
        ok = await push.enviar_push_a_usuario(
            usuario_cliente.id, "Titulo", "Body", db=db,
        )

    assert ok is True
    mock_send.assert_called_once()


async def test_enviar_push_a_usuario_inexistente(db):
    """Usuario que no existe -> False, sin FCM."""
    user_id_fake = uuid4()
    with patch(
        "app.core.notifications.providers.fcm.messaging.send"
    ) as mock_send:
        ok = await push.enviar_push_a_usuario(
            user_id_fake, "Titulo", "Body", db=db,
        )
    assert ok is False
    mock_send.assert_not_called()
