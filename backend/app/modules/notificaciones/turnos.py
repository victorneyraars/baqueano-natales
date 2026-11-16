"""Notificaciones transaccionales para turnos de oficios."""

import logging
from .email import enviar_email

logger = logging.getLogger(__name__)

# Marido (dominio verificado en Resend)
FROM_EMAIL = "contacto@sealquilamarido.com"
FROM_NAME = "Se Alquila Marido"


def _esc(text) -> str:
    if text is None:
        return ""
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _formatear_fecha(iso: str) -> str:
    try:
        from datetime import datetime
        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        dias = ["Lunes", "Martes", "Miercoles", "Jueves", "Viernes", "Sabado", "Domingo"]
        meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio",
                 "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
        return f"{dias[dt.weekday()]} {dt.day} de {meses[dt.month - 1]} {dt.year} a las {dt.strftime('%H:%M')}"
    except Exception:
        return iso


async def notificar_otp_turno_cliente(
    email_cliente, nombre_cliente, codigo, servicio, fecha, vehiculo, patente=None,
):
    """Email con OTP para verificar turno solicitado."""
    asunto = f"Verifica tu correo para confirmar tu turno ({codigo})"
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #F59E0B; text-align: center;">Verifica tu correo para continuar</h2>
        <p>Hola <strong>{_esc(nombre_cliente)}</strong>,</p>
        <p>Hemos recibido tu solicitud de turno. Ingresa el siguiente código en nuestra web para confirmar:</p>
        <div style="background:#f8f9fa; border:1px solid #e9ecef; padding:30px; border-radius:8px; margin:20px 0; text-align:center;">
            <div style="font-size:42px; font-weight:bold; letter-spacing:8px; color:#F59E0B; font-family:monospace;">{codigo}</div>
            <p style="color:#666; font-size:13px; margin-top:10px;">Expira en 15 minutos.</p>
        </div>
        <h3 style="color:#F59E0B; border-bottom:2px solid #F59E0B; padding-bottom:5px;">Resumen de tu solicitud</h3>
        <table style="width:100%; font-size:15px;">
            <tr><td style="padding:8px 0;"><strong>Servicio:</strong></td><td>{_esc(servicio)}</td></tr>
            <tr><td style="padding:8px 0;"><strong>Vehículo:</strong></td><td>{_esc(vehiculo)} ({_esc(patente or 'N/A')})</td></tr>
            <tr><td style="padding:8px 0;"><strong>Fecha:</strong></td><td>{_formatear_fecha(fecha)}</td></tr>
        </table>
        <p style="margin-top:30px; color:#666; font-size:13px;">Si no solicitaste este turno, ignora este correo.</p>
        <p style="margin-top:20px; font-size:12px; color:#999; text-align:center;">Se Alquila Marido · sealquilamarido.com</p>
    </div>"""
    return await enviar_email(
        to=email_cliente, subject=asunto, html=html,
        from_email=FROM_EMAIL, from_name=FROM_NAME, reply_to=FROM_EMAIL,
    )


async def notificar_turno_solicitado_cliente(
    email_cliente, nombre_cliente, servicio, fecha, vehiculo,
):
    """Confirmación post-verificación OTP."""
    asunto = "Turno solicitado - Se Alquila Marido"
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #F59E0B; text-align: center;">Tu correo fue verificado</h2>
        <p>Hola <strong>{_esc(nombre_cliente)}</strong>,</p>
        <p>Tu solicitud de turno fue registrada. El mecánico te confirmará en las próximas 24 horas.</p>
        <h3 style="color:#F59E0B; border-bottom:2px solid #F59E0B; padding-bottom:5px; margin-top:30px;">Tu solicitud</h3>
        <table style="width:100%; font-size:15px;">
            <tr><td style="padding:8px 0;"><strong>Servicio:</strong></td><td>{_esc(servicio)}</td></tr>
            <tr><td style="padding:8px 0;"><strong>Vehículo:</strong></td><td>{_esc(vehiculo)}</td></tr>
            <tr><td style="padding:8px 0;"><strong>Fecha:</strong></td><td>{_formatear_fecha(fecha)}</td></tr>
        </table>
        <p style="margin-top:30px; color:#666; font-size:14px;">¿Necesitas cambiar algo? Responde este correo o escribinos por WhatsApp.</p>
        <p style="margin-top:20px; font-size:12px; color:#999; text-align:center;">Se Alquila Marido · sealquilamarido.com</p>
    </div>"""
    return await enviar_email(
        to=email_cliente, subject=asunto, html=html,
        from_email=FROM_EMAIL, from_name=FROM_NAME, reply_to=FROM_EMAIL,
    )


async def notificar_nuevo_turno_prestador(
    email_prestador, nombre_cliente, email_cliente, telefono_cliente,
    servicio, fecha, vehiculo, patente=None, motivo=None,
):
    """Email al prestador (via redirect Cloudflare a super admin)."""
    asunto = f"Nuevo turno solicitado - {_esc(nombre_cliente)} - {fecha[:10]}"
    e_motivo = f'<tr><td style="padding:8px 0;"><strong>Motivo:</strong></td><td>{_esc(motivo)}</td></tr>' if motivo else ""
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #F59E0B; text-align: center;">Nuevo turno solicitado</h2>
        <p>Tenes una nueva solicitud de turno:</p>
        <h3 style="color:#F59E0B; border-bottom:2px solid #F59E0B; padding-bottom:5px;">Cliente</h3>
        <table style="width:100%; font-size:14px;">
            <tr><td style="padding:8px 0;"><strong>Nombre:</strong></td><td>{_esc(nombre_cliente)}</td></tr>
            <tr><td style="padding:8px 0;"><strong>Email:</strong></td><td><a href="mailto:{_esc(email_cliente)}">{_esc(email_cliente)}</a></td></tr>
            <tr><td style="padding:8px 0;"><strong>Telefono:</strong></td><td>{_esc(telefono_cliente or 'No especificado')}</td></tr>
        </table>
        <h3 style="color:#F59E0B; border-bottom:2px solid #F59E0B; padding-bottom:5px; margin-top:20px;">Turno</h3>
        <table style="width:100%; font-size:14px;">
            <tr><td style="padding:8px 0;"><strong>Servicio:</strong></td><td>{_esc(servicio)}</td></tr>
            <tr><td style="padding:8px 0;"><strong>Vehiculo:</strong></td><td>{_esc(vehiculo)} ({_esc(patente or 'N/A')})</td></tr>
            <tr><td style="padding:8px 0;"><strong>Fecha:</strong></td><td>{_formatear_fecha(fecha)}</td></tr>
            {e_motivo}
        </table>
        <p style="margin-top:30px; font-size:14px;">Abrí la app de Baqueano Prestador para aceptar o rechazar el turno.</p>
    </div>"""
    return await enviar_email(
        to=email_prestador, subject=asunto, html=html,
        from_email=FROM_EMAIL, from_name=FROM_NAME, reply_to=email_cliente,
    )
