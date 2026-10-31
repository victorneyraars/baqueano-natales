"""Cliente de envio de emails transaccionales via Resend."""

import os
import logging
import resend

logger = logging.getLogger(__name__)

# Remitente por defecto (dominio debe estar verificado en Resend)
FROM_EMAIL = "reservas@rentacarvasquez.com"
FROM_NAME = "Rent a Car Vasquez"


async def enviar_email(
    to: str,
    subject: str,
    html: str,
    from_email: str = FROM_EMAIL,
) -> bool:
    """Envia un email via Resend. Devuelve True si fue exitoso."""
    api_key = os.environ.get("RESEND_API_KEY")
    if not api_key or api_key == "re_tu_key_real_aqui":
        logger.warning("RESEND_API_KEY no configurada. Emails deshabilitados.")
        return False

    resend.api_key = api_key

    try:
        params = {
            "from": f"{FROM_NAME} <{from_email}>",
            "to": [to],
            "subject": subject,
            "html": html,
        }
        # Usamos el SDK. En algunas versiones, .send() devuelve un dict.
        response = resend.Emails.send(params)
        logger.info(f"Email enviado a {to} (id={response.get('id', 'unknown')})")
        return True
    except Exception as e:
        logger.error(f"Error enviando email a {to}: {e}")
        return False
