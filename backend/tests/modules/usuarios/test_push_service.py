"""Tests del servicio de push FCM (con mock de messaging.send).

Cubre:
- enviar_push OK / error / token vacio / FCM deshabilitado
- enviar_push_a_usuario sin token / con token / usuario inexistente
"""
from unittest.mock import patch
from uuid import uuid4

from app.core import push


async def test_enviar_push_ok():
    """FCM acepta el mensaje -> True."""
    with patch("app.core.push.messaging.send", return_value="msg-id-123"):
        ok = await push.enviar_push("token_test", "Titulo", "Body")
    assert ok is True


async def test_enviar_push_token_vacio():
    """Token vacio -> False, sin llamar a FCM."""
    with patch("app.core.push.messaging.send") as mock_send:
        ok = await push.enviar_push("", "Titulo", "Body")
    assert ok is False
    mock_send.assert_not_called()


async def test_enviar_push_error_no_propaga():
    """Excepcion de FCM -> False, no propaga."""
    with patch(
        "app.core.push.messaging.send",
        side_effect=Exception("FCM down"),
    ):
        ok = await push.enviar_push("token_test", "Titulo", "Body")
    assert ok is False


async def test_enviar_push_deshabilitado(monkeypatch):
    """FCM_ENABLED=False -> False sin llamar a FCM."""
    monkeypatch.setattr(push.settings, "FCM_ENABLED", False)
    with patch("app.core.push.messaging.send") as mock_send:
        ok = await push.enviar_push("token_test", "Titulo", "Body")
    assert ok is False
    mock_send.assert_not_called()


async def test_enviar_push_a_usuario_sin_token(db, usuario_cliente):
    """Usuario sin fcm_token -> False sin llamar a FCM."""
    with patch("app.core.push.messaging.send") as mock_send:
        ok = await push.enviar_push_a_usuario(
            usuario_cliente.id, "Titulo", "Body", db=db,
        )
    assert ok is False
    mock_send.assert_not_called()


async def test_enviar_push_a_usuario_con_token(db, usuario_cliente):
    """Usuario con fcm_token -> True, llama a FCM."""
    usuario_cliente.fcm_token = "token_real_de_prueba"
    await db.flush()

    with patch(
        "app.core.push.messaging.send", return_value="msg-id"
    ) as mock_send:
        ok = await push.enviar_push_a_usuario(
            usuario_cliente.id, "Titulo", "Body", db=db,
        )

    assert ok is True
    mock_send.assert_called_once()


async def test_enviar_push_a_usuario_inexistente(db):
    """Usuario que no existe -> False, sin llamar a FCM."""
    user_id_fake = uuid4()
    with patch("app.core.push.messaging.send") as mock_send:
        ok = await push.enviar_push_a_usuario(
            user_id_fake, "Titulo", "Body", db=db,
        )
    assert ok is False
    mock_send.assert_not_called()
