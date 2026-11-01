"""Templates de email para invitaciones a colaboradores."""
from app.modules.notificaciones.email import enviar_email


async def notificar_invitacion_colaborador(
    email_invitado: str,
    nombre_invitado: str,
    nombre_prestador: str,
    nombre_invitador: str,
    token: str,
) -> bool:
    """Envia email de invitacion con link firmado al nuevo colaborador."""
    link = f"https://rentacarvasquez.com/admin?invite={token}"
    asunto = f"Invitacion para colaborar en {nombre_prestador}"
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #2E7D32;">Invitacion para colaborar</h2>
        <p>Hola <strong>{nombre_invitado}</strong>,</p>
        <p>
            <strong>{nombre_invitador}</strong> te invito a colaborar en
            <strong>{nombre_prestador}</strong>.
        </p>
        <p>Como colaborador vas a poder gestionar reservas y vehiculos,
           pero no tendras acceso a la configuracion completa.</p>
        <p style="margin: 30px 0; text-align: center;">
            <a href="{link}"
               style="background-color: #2E7D32; color: white;
                      padding: 12px 24px; text-decoration: none;
                      border-radius: 6px; font-weight: bold;">
                Aceptar invitacion
            </a>
        </p>
        <p style="color: #666; font-size: 13px;">
            El link expira en 7 dias. Si no solicitaste esta invitacion,
            ignora este email.
        </p>
    </div>
    """
    return await enviar_email(to=email_invitado, subject=asunto, html=html)
