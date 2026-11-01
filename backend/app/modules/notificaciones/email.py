"""Cliente de envio de emails transaccionales via Resend."""

import os
import logging
import resend

logger = logging.getLogger(__name__)

# Remitente por defecto (dominio debe estar verificado en Resend)
FROM_EMAIL = "reservas@rentacarvasquez.com"
FROM_NAME = "Rent a Car Vasquez"


async def enviar_email(
    to: str | list[str],
    subject: str,
    html: str,
    from_email: str = FROM_EMAIL,
    from_name: str = FROM_NAME,
    reply_to: str | None = None,
    text: str | None = None,
) -> bool:
    """Envia un email via Resend. Devuelve True si fue exitoso.

    Args:
        to: Destinatario (o lista de destinatarios).
        subject: Asunto del email.
        html: Cuerpo HTML.
        from_email: Remitente (dominio verificado en Resend).
        from_name: Nombre visible del remitente.
        reply_to: Email de respuesta (default: from_email).
        text: Version texto plano (fallback para clientes sin HTML).
    """
    api_key = os.environ.get("RESEND_API_KEY")
    if not api_key or api_key == "re_tu_key_real_aqui":
        logger.warning("RESEND_API_KEY no configurada. Emails deshabilitados.")
        return False

    resend.api_key = api_key

    try:
        recipients = [to] if isinstance(to, str) else to
        params: dict = {
            "from": f"{from_name} <{from_email}>",
            "to": recipients,
            "subject": subject,
            "html": html,
        }
        if reply_to:
            params["reply_to"] = reply_to
        if text:
            params["text"] = text

        response = resend.Emails.send(params)
        logger.info(
            f"Email enviado a {', '.join(recipients)} (id={response.get('id', 'unknown')})"
        )
        return True
    except Exception as e:
        logger.error(f"Error enviando email a {to}: {e}")
        return False
