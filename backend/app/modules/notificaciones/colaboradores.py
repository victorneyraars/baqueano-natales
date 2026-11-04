"""Templates de email para invitaciones a colaboradores."""
from app.modules.notificaciones.email import enviar_email


async def notificar_invitacion_colaborador(
    email_invitado: str,
    nombre_invitado: str,
    nombre_prestador: str,
    nombre_invitador: str,
    token: str,
    whatsapp_invitado: str | None = None,
) -> bool:
    """Envia email de invitacion con link firmado al nuevo colaborador."""
    link = f"https://rentacarvasquez.com/admin?invite={token}"
    asunto = f"Invitacion para colaborar en {nombre_prestador}"
    
    # Diseño ultra-simple para evitar la pestaña de Promociones
    texto_whatsapp = f"\n\nTu WhatsApp registrado: {whatsapp_invitado}" if whatsapp_invitado else ""
    
    html = f"""
    <div style="font-family: sans-serif; color: #333; font-size: 14px; line-height: 1.5;">
        <p>Hola {nombre_invitado},</p>
        <p>{nombre_invitador} te ha invitado a colaborar en {nombre_prestador}.</p>
        <p>Como colaborador vas a poder gestionar reservas y vehículos, pero no tendrás acceso a la configuración completa.{texto_whatsapp}</p>
        <p>Para aceptar la invitación, haz clic en el siguiente enlace:</p>
        <p><a href="{link}">{link}</a></p>
        <p>El enlace expira en 7 días. Si no solicitaste esta invitación, puedes ignorar este correo.</p>
        <br>
        <p>Saludos,<br>El equipo de {nombre_prestador}</p>
    </div>
    """
    return await enviar_email(to=email_invitado, subject=asunto, html=html)
