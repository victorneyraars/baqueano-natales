"""Plantillas y logica de notificaciones para reservas."""

from datetime import datetime
from app.modules.notificaciones.email import enviar_email
from app.modules.notificaciones.tokens import generar_token_accion


def _formatear_fecha(fecha_iso: str) -> str:
    try:
        dt = datetime.fromisoformat(fecha_iso.replace("Z", "+00:00"))
        return dt.strftime("%d/%m/%Y")
    except Exception:
        return fecha_iso


def _formatear_clp(monto: float) -> str:
    return f"${monto:,.0f}".replace(",", ".")


async def notificar_nueva_reserva_prestador(
    reserva_id: str,
    email_prestador: str,
    nombre_cliente: str,
    email_cliente: str,
    telefono_cliente: str,
    vehiculo: str,
    inicio: str,
    fin: str,
    total: float,
):
    asunto = f"Nueva reserva: {vehiculo} - {_formatear_fecha(inicio)} al {_formatear_fecha(fin)}"
    
    # Generar URLs con tokens seguros
    base_url = "https://api-dev.baqueanonatales.com/api/v1/public/rentacar/reservas"
    token_ok = generar_token_accion(reserva_id, "confirmar")
    token_cancel = generar_token_accion(reserva_id, "cancelar")
    url_ok = f"{base_url}/{reserva_id}/accion?token={token_ok}"
    url_cancel = f"{base_url}/{reserva_id}/accion?token={token_cancel}"

    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #2E7D32;">Nueva Reserva Recibida</h2>
        <p>Hola, has recibido una nueva solicitud de reserva.</p>
        <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
            <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Vehiculo:</strong></td><td style="padding: 8px; border-bottom: 1px solid #eee;">{vehiculo}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Fechas:</strong></td><td style="padding: 8px; border-bottom: 1px solid #eee;">Del {_formatear_fecha(inicio)} al {_formatear_fecha(fin)}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Total estimado:</strong></td><td style="padding: 8px; border-bottom: 1px solid #eee;">{_formatear_clp(total)}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Cliente:</strong></td><td style="padding: 8px; border-bottom: 1px solid #eee;">{nombre_cliente}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Email:</strong></td><td style="padding: 8px; border-bottom: 1px solid #eee;">{email_cliente}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Telefono:</strong></td><td style="padding: 8px; border-bottom: 1px solid #eee;">{telefono_cliente or 'No proporcionado'}</td></tr>
        </table>
        <p style="margin-top: 30px; text-align: center;">
            <a href="{url_ok}" style="background-color: #16A34A; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; margin-right: 10px;">Aceptar Reserva</a>
            <a href="{url_cancel}" style="background-color: #DC2626; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">Rechazar Reserva</a>
        </p>
    </div>
    """
    await enviar_email(to=email_prestador, subject=asunto, html=html)


async def notificar_nueva_reserva_cliente(
    email_cliente: str,
    nombre_cliente: str,
    vehiculo: str,
    inicio: str,
    fin: str,
    total: float,
):
    asunto = f"Recibimos tu solicitud - {vehiculo}"
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #2E7D32;">Gracias por tu reserva, {nombre_cliente}</h2>
        <p>Hemos recibido tu solicitud. Nos pondremos en contacto contigo a la brevedad para confirmar los detalles.</p>
        <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #333;">Resumen de tu reserva:</h3>
            <p><strong>Vehiculo:</strong> {vehiculo}</p>
            <p><strong>Retiro:</strong> {_formatear_fecha(inicio)}</p>
            <p><strong>Devolucion:</strong> {_formatear_fecha(fin)}</p>
            <p><strong>Total:</strong> {_formatear_clp(total)}</p>
        </div>
        <p>Si tienes alguna duda, puedes responder a este correo.</p>
        <p>Te esperamos en Puerto Natales!</p>
    </div>
    """
    await enviar_email(to=email_cliente, subject=asunto, html=html)


async def notificar_reserva_confirmada_cliente(
    email_cliente: str,
    nombre_cliente: str,
    vehiculo: str,
    inicio: str,
    fin: str,
    total: float,
):
    asunto = f"Reserva confirmada: {vehiculo}"
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #16A34A;">Reserva Confirmada</h2>
        <p>Hola {nombre_cliente}, te confirmamos que tu reserva del <strong>{vehiculo}</strong> ha sido confirmada.</p>
        <div style="background-color: #f0fdf4; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <p><strong>Retiro:</strong> {_formatear_fecha(inicio)}</p>
            <p><strong>Devolucion:</strong> {_formatear_fecha(fin)}</p>
            <p><strong>Total:</strong> {_formatear_clp(total)}</p>
        </div>
        <p><strong>Instrucciones de retiro:</strong></p>
        <ul>
            <li>Direccion: Miraflores 708, Puerto Natales</li>
            <li>Telefono: +56941721688</li>
            <li>Traer licencia de conducir y tarjeta de credito a nombre del titular</li>
        </ul>
        <p>Te esperamos!</p>
    </div>
    """
    await enviar_email(to=email_cliente, subject=asunto, html=html)


async def notificar_reserva_cancelada_cliente(
    email_cliente: str,
    nombre_cliente: str,
    vehiculo: str,
    inicio: str,
    fin: str,
):
    asunto = f"Reserva cancelada: {vehiculo}"
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #DC2626;">Reserva Cancelada</h2>
        <p>Hola {nombre_cliente}, tu reserva del <strong>{vehiculo}</strong> del {_formatear_fecha(inicio)} al {_formatear_fecha(fin)} ha sido cancelada.</p>
        <p>Si tienes consultas, responde a este correo o llamanos al +56941721688.</p>
        <p>Esperamos atenderte en otra ocasion.</p>
    </div>
    """
    await enviar_email(to=email_cliente, subject=asunto, html=html)
