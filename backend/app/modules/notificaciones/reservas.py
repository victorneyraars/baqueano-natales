"""Plantillas y logica de notificaciones para reservas."""

from datetime import datetime
from html import escape as _esc
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


_DIAS_ES = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
_DIAS_ES_SHORT = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]


def _dia_semana_es(fecha_iso: str) -> str:
    """Devuelve el día de la semana en español (Lunes, Martes, ...)."""
    try:
        dt = datetime.fromisoformat(fecha_iso.replace("Z", "+00:00"))
        return _DIAS_ES[dt.weekday()]
    except Exception:
        return ""


def _fecha_hora_es(fecha_iso: str) -> tuple[str, str]:
    """Devuelve (fecha_corta, hora). Ej: ('Lun 01/08/2027', '10:00')."""
    try:
        dt = datetime.fromisoformat(fecha_iso.replace("Z", "+00:00"))
        dia = _DIAS_ES_SHORT[dt.weekday()]
        return f"{dia} {dt.strftime('%d/%m/%Y')}", dt.strftime("%H:%M")
    except Exception:
        return fecha_iso, ""


def _calc_iva(total: float) -> tuple[int, int]:
    """Devuelve (neto, iva) desglosado desde un total con IVA incluido."""
    iva_pct = 0.19
    neto = round(total / (1 + iva_pct))
    iva = round(total - neto)
    return neto, iva


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
    # Datos opcionales (enriquecimiento)
    patente: str | None = None,
    imagen_url: str | None = None,
    metodo_pago: str | None = None,
    email_verificado: bool = False,
    categoria: str | None = None,
    nombre_negocio: str = "Rent a Car Vásquez",
    rut_negocio: str = "78.356.635-4",
    direccion_negocio: str = "Miraflores 708, Puerto Natales",
    telefono_negocio: str = "+56 9 4172 1688",
) -> bool:
    """Email transaccional enriquecido (mobile-first, dark-mode, WCAG AA)."""

    # ── Cálculos ──
    iva_pct = 0.19
    neto = round(total / (1 + iva_pct))
    iva = round(total - neto)

    # ── Fechas ──
    fecha_ini, hora_ini = _fecha_hora_es(inicio)
    fecha_fin, hora_fin = _fecha_hora_es(fin)

    try:
        dt_ini = datetime.fromisoformat(inicio.replace("Z", "+00:00"))
        dt_fin = datetime.fromisoformat(fin.replace("Z", "+00:00"))
        duracion_dias = max(1, (dt_fin - dt_ini).days)
    except Exception:
        duracion_dias = 1

    # ── URLs con tokens ──
    base_url = "https://api-dev.baqueanonatales.com/api/v1/public/rentacar/reservas"
    token_ok = generar_token_accion(reserva_id, "confirmar")
    token_cancel = generar_token_accion(reserva_id, "cancelar")
    url_ok = f"{base_url}/{reserva_id}/accion?token={token_ok}"
    url_cancel = f"{base_url}/{reserva_id}/accion?token={token_cancel}"
    url_detalle = f"https://rentacarvasquez.com/admin/dashboard/{reserva_id}"

    # ── WhatsApp al cliente (si tiene teléfono) ──
    wa_url = ""
    if telefono_cliente:
        tel_clean = "".join(c for c in telefono_cliente if c.isdigit() or c == "+")
        wa_msg = f"Hola {nombre_cliente}, te contacto de {nombre_negocio} por tu reserva del {vehiculo}."
        from urllib.parse import quote
        wa_url = f"https://wa.me/{tel_clean.replace('+', '')}?text={quote(wa_msg)}"

    # ── Escapes (seguridad) ──
    e_nombre = _esc(nombre_cliente)
    e_email = _esc(email_cliente or "")
    e_tel = _esc(telefono_cliente or "")
    e_vehiculo = _esc(vehiculo)
    e_patente = _esc(patente or "")
    e_pago = _esc((metodo_pago or "No especificado").capitalize())
    e_cat = _esc(categoria or "")

    # ── Preheader (90 chars que se ven en la bandeja) ──
    preheader = f"{e_vehiculo} · {fecha_ini} {hora_ini} → {fecha_fin} {hora_fin} · ${total:,.0f}".replace(",", ".")

    # ── Subject optimizado ──
    asunto = f"🔔 Nueva reserva: {vehiculo} · {fecha_ini}"

    # ── Chip estado email cliente ──
    if email_verificado:
        chip_color = "#16A34A"; chip_bg = "#DCFCE7"; chip_txt = "Email verificado"
    else:
        chip_color = "#CA8A04"; chip_bg = "#FEF9C3"; chip_txt = "Email sin verificar"

    # ── Imagen del vehículo ──
    img_html = ""
    if imagen_url:
        img_html = f"""
        <td width="110" style="vertical-align: top; padding-right: 12px;">
          <img src="{imagen_url}" width="100" height="70" alt="{e_vehiculo}"
               style="border-radius: 8px; object-fit: cover; display: block; border: 1px solid #E2E8F0;" />
        </td>
        """

    # ── Botón WhatsApp cliente ──
    wa_html = ""
    if wa_url:
        wa_html = f"""
        <a href="{wa_url}" style="display: inline-block; background: #25D366; color: #FFFFFF;
           padding: 10px 18px; border-radius: 6px; text-decoration: none;
           font-weight: 600; font-size: 14px;">💬 WhatsApp al cliente</a>
        """

    # ── HTML principal ──
    html = f"""<!DOCTYPE html>
<html lang="es" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <title>Nueva reserva · {e_vehiculo}</title>
  <style>
    @media (prefers-color-scheme: dark) {{
      .email-bg {{ background: #0F172A !important; }}
      .card {{ background: #1E293B !important; }}
      .txt-main {{ color: #F1F5F9 !important; }}
      .txt-muted {{ color: #94A3B8 !important; }}
      .divider {{ border-color: #334155 !important; }}
      .stat-bg {{ background: #0F172A !important; }}
      .btn-secondary {{ background: #334155 !important; color: #F1F5F9 !important; }}
    }}
    @media only screen and (max-width: 600px) {{
      .container {{ width: 100% !important; }}
      .col-stack {{ display: block !important; width: 100% !important; padding: 8px 0 !important; }}
      .btn-action {{ display: block !important; width: 100% !important; margin: 6px 0 !important; }}
    }}
    a {{ color: #2E7D32; }}
  </style>
</head>
<body style="margin: 0; padding: 0; background: #F1F5F9;" class="email-bg">
  <!-- Preheader (oculto) -->
  <div style="display: none; font-size: 1px; color: #F1F5F9; line-height: 1px; max-height: 0; max-width: 0; opacity: 0; overflow: hidden;">
    {preheader}
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F1F5F9;" class="email-bg">
    <tr><td align="center" style="padding: 24px 12px;">
      <table role="presentation" class="container" width="600" cellpadding="0" cellspacing="0" border="0" style="max-width: 600px; width: 100%;">

        <!-- Header con marca -->
        <tr><td style="padding: 0 0 16px 0; text-align: left;">
          <div style="font-size: 13px; color: #64748B; font-weight: 600; letter-spacing: 0.5px;" class="txt-muted">
            {nombre_negocio.upper()}
          </div>
        </td></tr>

        <!-- Card principal -->
        <tr><td style="background: #FFFFFF; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.05);" class="card">

          <!-- Título -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr><td style="padding: 24px 24px 8px 24px;">
              <h1 style="margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; font-size: 22px; font-weight: 700; color: #0F172A; line-height: 1.3;" class="txt-main">
                🔔 Nueva reserva recibida
              </h1>
              <p style="margin: 6px 0 0 0; font-family: -apple-system, sans-serif; font-size: 14px; color: #64748B;" class="txt-muted">
                Revisá los datos y aceptá o rechazá desde el email o el panel.
              </p>
            </td></tr>

            <!-- Vehículo + imagen -->
            <tr><td style="padding: 16px 24px 0 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F8FAFC; border-radius: 8px;" class="stat-bg">
                <tr>
                  {img_html}
                  <td style="padding: 14px 16px; vertical-align: middle;">
                    <div style="font-family: -apple-system, sans-serif; font-size: 16px; font-weight: 700; color: #0F172A;" class="txt-main">
                      {e_vehiculo}
                    </div>
                    {f'<div style="font-family: monospace; font-size: 13px; color: #64748B; margin-top: 2px;" class="txt-muted">Patente: {e_patente}</div>' if e_patente else ''}
                    {f'<div style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B; margin-top: 4px;" class="txt-muted">{e_cat}</div>' if e_cat else ''}
                  </td>
                </tr>
              </table>
            </td></tr>

            <!-- Fechas -->
            <tr><td style="padding: 20px 24px 0 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="col-stack" width="50%" style="vertical-align: top; padding-right: 8px;">
                    <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;" class="txt-muted">RETIRO</div>
                    <div style="font-family: -apple-system, sans-serif; font-size: 15px; font-weight: 700; color: #0F172A; margin-top: 4px;" class="txt-main">{fecha_ini}</div>
                    <div style="font-family: -apple-system, sans-serif; font-size: 13px; color: #64748B; margin-top: 2px;" class="txt-muted">{hora_ini} hrs</div>
                  </td>
                  <td class="col-stack" width="50%" style="vertical-align: top; padding-left: 8px;">
                    <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;" class="txt-muted">DEVOLUCIÓN</div>
                    <div style="font-family: -apple-system, sans-serif; font-size: 15px; font-weight: 700; color: #0F172A; margin-top: 4px;" class="txt-main">{fecha_fin}</div>
                    <div style="font-family: -apple-system, sans-serif; font-size: 13px; color: #64748B; margin-top: 2px;" class="txt-muted">{hora_fin} hrs</div>
                  </td>
                </tr>
              </table>
            </td></tr>

            <tr><td style="padding: 16px 24px 0 24px;">
              <div style="border-top: 1px solid #E2E8F0;" class="divider"></div>
            </td></tr>

            <!-- Cliente -->
            <tr><td style="padding: 16px 24px 0 24px;">
              <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;" class="txt-muted">CLIENTE</div>
              <div style="font-family: -apple-system, sans-serif; font-size: 15px; font-weight: 700; color: #0F172A; margin-bottom: 4px;" class="txt-main">{e_nombre}</div>
              <div style="font-family: -apple-system, sans-serif; font-size: 14px; color: #0F172A; margin-bottom: 4px;" class="txt-main">
                <a href="mailto:{e_email}" style="color: #0F172A; text-decoration: none;">{e_email}</a>
                <span style="display: inline-block; background: {chip_bg}; color: {chip_color}; font-size: 10px; font-weight: 700; padding: 2px 8px; border-radius: 10px; margin-left: 6px; text-transform: uppercase;">{chip_txt}</span>
              </div>
              {f'<div style="font-family: -apple-system, sans-serif; font-size: 14px; color: #0F172A;" class="txt-main">{e_tel}</div>' if e_tel else ''}
            </td></tr>

            {f"""<tr><td style="padding: 12px 24px 0 24px;">
              {wa_html}
            </td></tr>""" if wa_html else ""}

            <tr><td style="padding: 16px 24px 0 24px;">
              <div style="border-top: 1px solid #E2E8F0;" class="divider"></div>
            </td></tr>

            <!-- Pago + IVA -->
            <tr><td style="padding: 16px 24px 0 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F8FAFC; border-radius: 8px;" class="stat-bg">
                <tr><td style="padding: 14px 16px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td style="font-family: -apple-system, sans-serif; font-size: 13px; color: #64748B;" class="txt-muted">Método de pago</td>
                      <td align="right" style="font-family: -apple-system, sans-serif; font-size: 13px; font-weight: 600; color: #0F172A;" class="txt-main">{e_pago}</td>
                    </tr>
                    <tr><td colspan="2" style="padding-top: 8px; border-top: 1px solid #E2E8F0; margin-top: 8px;" class="divider"></td></tr>
                    <tr>
                      <td style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B; padding-top: 10px;" class="txt-muted">Neto</td>
                      <td align="right" style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B; padding-top: 10px;" class="txt-muted">${neto:,.0f}</td>
                    </tr>
                    <tr>
                      <td style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B;" class="txt-muted">IVA 19%</td>
                      <td align="right" style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B;" class="txt-muted">${iva:,.0f}</td>
                    </tr>
                    <tr>
                      <td style="font-family: -apple-system, sans-serif; font-size: 16px; font-weight: 700; color: #0F172A; padding-top: 8px;" class="txt-main">Total (IVA incluido)</td>
                      <td align="right" style="font-family: -apple-system, sans-serif; font-size: 18px; font-weight: 800; color: #0F172A; padding-top: 8px;" class="txt-main">${total:,.0f}</td>
                    </tr>
                  </table>
                </td></tr>
              </table>
            </td></tr>

            <!-- Botones de acción -->
            <tr><td style="padding: 24px 24px 8px 24px;" align="center">
              <a href="{url_ok}" class="btn-action" style="display: inline-block; background: #16A34A; color: #FFFFFF; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 700; font-size: 15px; margin: 4px 6px; min-width: 140px;">✓ Aceptar reserva</a>
              <a href="{url_cancel}" class="btn-action" style="display: inline-block; background: #DC2626; color: #FFFFFF; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 700; font-size: 15px; margin: 4px 6px; min-width: 140px;">✕ Rechazar reserva</a>
            </td></tr>

            <!-- Ver detalle -->
            <tr><td style="padding: 8px 24px 24px 24px;" align="center">
              <a href="{url_detalle}" style="color: #64748B; text-decoration: underline; font-family: -apple-system, sans-serif; font-size: 13px;" class="txt-muted">
                Ver detalle completo en el panel →
              </a>
              <div style="margin-top: 8px; font-family: -apple-system, sans-serif; font-size: 11px; color: #94A3B8;" class="txt-muted">
                Requiere iniciar sesión con tu cuenta de administrador.
              </div>
            </td></tr>

        </td></tr>

        <!-- Footer legal -->
        <tr><td style="padding: 20px 12px 12px 12px; text-align: center;">
          <div style="font-family: -apple-system, sans-serif; font-size: 11px; color: #64748B; line-height: 1.6;" class="txt-muted">
            <strong style="color: #475569;">{nombre_negocio}</strong> · RUT {rut_negocio}<br>
            {direccion_negocio} · {telefono_negocio}<br>
            <a href="https://rentacarvasquez.com" style="color: #64748B; text-decoration: none;">rentacarvasquez.com</a>
          </div>
          <div style="margin-top: 12px; font-family: -apple-system, sans-serif; font-size: 10px; color: #94A3B8;" class="txt-muted">
            Recibís este email porque tenés acceso al panel de gestión de {nombre_negocio}.
          </div>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>"""

    # ── Texto plano (fallback) ──
    text = f"""NUEVA RESERVA RECIBIDA
{'=' * 50}

VEHÍCULO: {vehiculo}{f' ({patente})' if patente else ''}
Retiro:    {fecha_ini} a las {hora_ini}
Devolución:{fecha_fin} a las {hora_fin}
Duración:  {duracion_dias} día{'s' if duracion_dias > 1 else ''}

CLIENTE
Nombre:  {nombre_cliente}
Email:   {email_cliente}{' (verificado)' if email_verificado else ' (sin verificar)'}
{'Teléfono: ' + telefono_cliente if telefono_cliente else ''}

PAGO
Método:  {metodo_pago or 'No especificado'}
Neto:    ${neto:,.0f}
IVA 19%: ${iva:,.0f}
TOTAL:   ${total:,.0f} (IVA incluido)

ACEPTAR:  {url_ok}
RECHAZAR: {url_cancel}
DETALLE:  {url_detalle}

--
{nombre_negocio} · RUT {rut_negocio}
{direccion_negocio} · {telefono_negocio}
"""

    # ── Envío con reply-to al cliente ──
    return await enviar_email(
        to=email_prestador,
        subject=asunto,
        html=html,
        from_name=nombre_negocio,
        reply_to=email_cliente or None,
        text=text,
    )


async def notificar_nueva_reserva_cliente(
    email_cliente: str,
    nombre_cliente: str,
    vehiculo: str,
    inicio: str,
    fin: str,
    total: float,
    patente: str | None = None,
    imagen_url: str | None = None,
    metodo_pago: str | None = None,
    nombre_negocio: str = "Rent a Car Vásquez",
    rut_negocio: str = "78.356.635-4",
    direccion_negocio: str = "Miraflores 708, Puerto Natales",
    telefono_negocio: str = "+56 9 4172 1688",
    email_negocio: str = "reservas@rentacarvasquez.com",
) -> bool:
    """Email al cliente: confirmación de recepción de solicitud."""

    fecha_ini, hora_ini = _fecha_hora_es(inicio)
    fecha_fin, hora_fin = _fecha_hora_es(fin)
    neto, iva = _calc_iva(total)
    e_nombre = _esc(nombre_cliente)
    e_vehiculo = _esc(vehiculo)
    e_patente = _esc(patente or "")
    e_pago = _esc((metodo_pago or "No especificado").capitalize())

    # WhatsApp al negocio con mensaje pre-armado
    wa_negocio = f"https://wa.me/{telefono_negocio.replace('+', '').replace(' ', '')}?text=Hola, tengo una consulta sobre mi reserva del {vehiculo}."

    preheader = f"Recibimos tu solicitud del {e_vehiculo} · {fecha_ini} → {fecha_fin}"
    asunto = f"📩 Recibimos tu solicitud · {vehiculo}"

    img_html = ""
    if imagen_url:
        img_html = f"""
        <tr><td style="padding: 0 0 16px 0;">
          <img src="{imagen_url}" width="552" alt="{e_vehiculo}"
               style="width: 100%; max-width: 552px; height: auto; border-radius: 8px; display: block; border: 1px solid #E2E8F0;" />
        </td></tr>
        """

    html = f"""<!DOCTYPE html>
<html lang="es" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <title>Recibimos tu solicitud</title>
  <style>
    @media (prefers-color-scheme: dark) {{
      .email-bg {{ background: #0F172A !important; }}
      .card {{ background: #1E293B !important; }}
      .txt-main {{ color: #F1F5F9 !important; }}
      .txt-muted {{ color: #94A3B8 !important; }}
      .divider {{ border-color: #334155 !important; }}
      .stat-bg {{ background: #0F172A !important; }}
    }}
    @media only screen and (max-width: 600px) {{
      .container {{ width: 100% !important; }}
      .col-stack {{ display: block !important; width: 100% !important; padding: 8px 0 !important; }}
    }}
    a {{ color: #2E7D32; }}
  </style>
</head>
<body style="margin: 0; padding: 0; background: #F1F5F9;" class="email-bg">
  <div style="display: none; font-size: 1px; color: #F1F5F9; line-height: 1px; max-height: 0; max-width: 0; opacity: 0; overflow: hidden;">{preheader}</div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F1F5F9;" class="email-bg">
    <tr><td align="center" style="padding: 24px 12px;">
      <table role="presentation" class="container" width="600" cellpadding="0" cellspacing="0" border="0" style="max-width: 600px; width: 100%;">

        <tr><td style="padding: 0 0 16px 0; text-align: left;">
          <div style="font-size: 13px; color: #64748B; font-weight: 600; letter-spacing: 0.5px;" class="txt-muted">{nombre_negocio.upper()}</div>
        </td></tr>

        <tr><td style="background: #FFFFFF; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.05);" class="card">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr><td style="padding: 24px 24px 16px 24px;">
              <h1 style="margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; font-size: 22px; font-weight: 700; color: #0F172A; line-height: 1.3;" class="txt-main">
                📩 ¡Recibimos tu solicitud, {e_nombre}!
              </h1>
              <p style="margin: 8px 0 0 0; font-family: -apple-system, sans-serif; font-size: 14px; color: #64748B; line-height: 1.5;" class="txt-muted">
                Estamos revisando la disponibilidad del vehículo. En las próximas horas te confirmamos por email.
              </p>
            </td></tr>

            {img_html}

            <!-- Resumen -->
            <tr><td style="padding: 0 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F8FAFC; border-radius: 8px;" class="stat-bg">
                <tr><td style="padding: 16px;">
                  <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;" class="txt-muted">TU RESERVA</div>
                  <div style="font-family: -apple-system, sans-serif; font-size: 16px; font-weight: 700; color: #0F172A; margin-bottom: 4px;" class="txt-main">{e_vehiculo}</div>
                  {f'<div style="font-family: monospace; font-size: 12px; color: #64748B; margin-bottom: 12px;" class="txt-muted">Patente: {e_patente}</div>' if e_patente else '<div style="height: 8px;"></div>'}

                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td class="col-stack" width="50%" style="vertical-align: top; padding-right: 8px;">
                        <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase;" class="txt-muted">Retiro</div>
                        <div style="font-family: -apple-system, sans-serif; font-size: 14px; font-weight: 700; color: #0F172A; margin-top: 2px;" class="txt-main">{fecha_ini}</div>
                        <div style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B;" class="txt-muted">{hora_ini} hrs</div>
                      </td>
                      <td class="col-stack" width="50%" style="vertical-align: top; padding-left: 8px;">
                        <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase;" class="txt-muted">Devolución</div>
                        <div style="font-family: -apple-system, sans-serif; font-size: 14px; font-weight: 700; color: #0F172A; margin-top: 2px;" class="txt-main">{fecha_fin}</div>
                        <div style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B;" class="txt-muted">{hora_fin} hrs</div>
                      </td>
                    </tr>
                  </table>

                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top: 12px; padding-top: 12px; border-top: 1px solid #E2E8F0;" class="divider">
                    <tr>
                      <td style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B;" class="txt-muted">Método de pago</td>
                      <td align="right" style="font-family: -apple-system, sans-serif; font-size: 12px; font-weight: 600; color: #0F172A;" class="txt-main">{e_pago}</td>
                    </tr>
                    <tr>
                      <td style="font-family: -apple-system, sans-serif; font-size: 11px; color: #94A3B8; padding-top: 6px;" class="txt-muted">Neto ${neto:,.0f} + IVA 19% ${iva:,.0f}</td>
                      <td align="right" style="font-family: -apple-system, sans-serif; font-size: 16px; font-weight: 800; color: #0F172A; padding-top: 6px;" class="txt-main">${total:,.0f}</td>
                    </tr>
                  </table>
                </td></tr>
              </table>
            </td></tr>

            <!-- Próximos pasos -->
            <tr><td style="padding: 20px 24px 8px 24px;">
              <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px;" class="txt-muted">PRÓXIMOS PASOS</div>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr><td style="padding: 0 0 10px 0;">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
                    <td style="vertical-align: top; padding-right: 10px;"><div style="width: 24px; height: 24px; background: #DCFCE7; color: #16A34A; border-radius: 50%; text-align: center; line-height: 24px; font-weight: 700; font-size: 12px;">1</div></td>
                    <td style="vertical-align: top; font-family: -apple-system, sans-serif; font-size: 14px; color: #0F172A; line-height: 1.4;" class="txt-main"><strong>Verificá tu email</strong> con el código que te enviamos.</td>
                  </tr></table>
                </td></tr>
                <tr><td style="padding: 0 0 10px 0;">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
                    <td style="vertical-align: top; padding-right: 10px;"><div style="width: 24px; height: 24px; background: #FEF3C7; color: #CA8A04; border-radius: 50%; text-align: center; line-height: 24px; font-weight: 700; font-size: 12px;">2</div></td>
                    <td style="vertical-align: top; font-family: -apple-system, sans-serif; font-size: 14px; color: #0F172A; line-height: 1.4;" class="txt-main"><strong>Esperá nuestra confirmación</strong> (te avisamos por email).</td>
                  </tr></table>
                </td></tr>
                <tr><td style="padding: 0;">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
                    <td style="vertical-align: top; padding-right: 10px;"><div style="width: 24px; height: 24px; background: #DBEAFE; color: #2563EB; border-radius: 50%; text-align: center; line-height: 24px; font-weight: 700; font-size: 12px;">3</div></td>
                    <td style="vertical-align: top; font-family: -apple-system, sans-serif; font-size: 14px; color: #0F172A; line-height: 1.4;" class="txt-main"><strong>Coordiá el retiro</strong> con {nombre_negocio}.</td>
                  </tr></table>
                </td></tr>
              </table>
            </td></tr>

            <!-- CTA WhatsApp -->
            <tr><td style="padding: 16px 24px 24px 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F0FDF4; border-radius: 8px; border: 1px solid #BBF7D0;">
                <tr><td style="padding: 14px 16px; text-align: center;">
                  <div style="font-family: -apple-system, sans-serif; font-size: 13px; color: #166534; margin-bottom: 10px;">
                    ¿Tenés dudas? Escribinos por WhatsApp:
                  </div>
                  <a href="{wa_negocio}" style="display: inline-block; background: #25D366; color: #FFFFFF; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 700; font-size: 14px;">💬 WhatsApp {nombre_negocio}</a>
                </td></tr>
              </table>
            </td></tr>
          </table>
        </td></tr>

        <tr><td style="padding: 20px 12px 12px 12px; text-align: center;">
          <div style="font-family: -apple-system, sans-serif; font-size: 11px; color: #64748B; line-height: 1.6;" class="txt-muted">
            <strong style="color: #475569;">{nombre_negocio}</strong> · RUT {rut_negocio}<br>
            {direccion_negocio} · {telefono_negocio}<br>
            <a href="mailto:{email_negocio}" style="color: #64748B; text-decoration: none;">{email_negocio}</a>
          </div>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>"""

    text = f"""RECIBIMOS TU SOLICITUD

Hola {nombre_cliente}, recibimos tu solicitud de reserva.

VEHÍCULO: {vehiculo}{f' ({patente})' if patente else ''}
Retiro:    {fecha_ini} a las {hora_ini}
Devolución:{fecha_fin} a las {hora_fin}
Método de pago: {metodo_pago or 'No especificado'}
Total: ${total:,.0f} (IVA incluido)

PRÓXIMOS PASOS:
1. Verificá tu email con el código que te enviamos.
2. Esperá nuestra confirmación (te avisamos por email).
3. Coordiná el retiro con {nombre_negocio}.

¿Dudas? WhatsApp: {wa_negocio}
O respondé directamente a este email.

--
{nombre_negocio} · RUT {rut_negocio}
{direccion_negocio} · {telefono_negocio}
"""

    return await enviar_email(
        to=email_cliente,
        subject=asunto,
        html=html,
        from_name=nombre_negocio,
        reply_to=email_negocio,
        text=text,
    )


async def notificar_reserva_confirmada_cliente(
    email_cliente: str,
    nombre_cliente: str,
    vehiculo: str,
    inicio: str,
    fin: str,
    total: float,
    patente: str | None = None,
    imagen_url: str | None = None,
    metodo_pago: str | None = None,
    nombre_negocio: str = "Rent a Car Vásquez",
    rut_negocio: str = "78.356.635-4",
    direccion_negocio: str = "Miraflores 708, Puerto Natales",
    telefono_negocio: str = "+56 9 4172 1688",
    email_negocio: str = "reservas@rentacarvasquez.com",
    maps_url: str = "https://maps.google.com/?q=Miraflores+708+Puerto+Natales",
) -> bool:
    """Email al cliente: reserva confirmada con instrucciones de retiro."""

    fecha_ini, hora_ini = _fecha_hora_es(inicio)
    fecha_fin, hora_fin = _fecha_hora_es(fin)
    neto, iva = _calc_iva(total)
    e_nombre = _esc(nombre_cliente)
    e_vehiculo = _esc(vehiculo)
    e_patente = _esc(patente or "")
    e_pago = _esc((metodo_pago or "No especificado").capitalize())

    wa_negocio = f"https://wa.me/{telefono_negocio.replace('+', '').replace(' ', '')}?text=Hola, tengo una consulta sobre mi reserva confirmada del {vehiculo}."

    preheader = f"¡Tu reserva del {e_vehiculo} está confirmada! Retiro el {fecha_ini} a las {hora_ini}"
    asunto = f"✅ Reserva confirmada · {vehiculo} · {fecha_ini}"

    img_html = ""
    if imagen_url:
        img_html = f"""
        <tr><td style="padding: 0 0 16px 0;">
          <img src="{imagen_url}" width="552" alt="{e_vehiculo}"
               style="width: 100%; max-width: 552px; height: auto; border-radius: 8px; display: block; border: 1px solid #E2E8F0;" />
        </td></tr>
        """

    html = f"""<!DOCTYPE html>
<html lang="es" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <title>Reserva confirmada</title>
  <style>
    @media (prefers-color-scheme: dark) {{
      .email-bg {{ background: #0F172A !important; }}
      .card {{ background: #1E293B !important; }}
      .txt-main {{ color: #F1F5F9 !important; }}
      .txt-muted {{ color: #94A3B8 !important; }}
      .divider {{ border-color: #334155 !important; }}
      .stat-bg {{ background: #0F172A !important; }}
      .success-bg {{ background: #14532D !important; }}
    }}
    @media only screen and (max-width: 600px) {{
      .container {{ width: 100% !important; }}
      .col-stack {{ display: block !important; width: 100% !important; padding: 8px 0 !important; }}
    }}
    a {{ color: #2E7D32; }}
  </style>
</head>
<body style="margin: 0; padding: 0; background: #F1F5F9;" class="email-bg">
  <div style="display: none; font-size: 1px; color: #F1F5F9; line-height: 1px; max-height: 0; max-width: 0; opacity: 0; overflow: hidden;">{preheader}</div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F1F5F9;" class="email-bg">
    <tr><td align="center" style="padding: 24px 12px;">
      <table role="presentation" class="container" width="600" cellpadding="0" cellspacing="0" border="0" style="max-width: 600px; width: 100%;">

        <tr><td style="padding: 0 0 16px 0; text-align: left;">
          <div style="font-size: 13px; color: #64748B; font-weight: 600; letter-spacing: 0.5px;" class="txt-muted">{nombre_negocio.upper()}</div>
        </td></tr>

        <tr><td style="background: #FFFFFF; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.05);" class="card">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <!-- Header verde de éxito -->
            <tr><td style="background: #16A34A; padding: 20px 24px;" class="success-bg">
              <div style="font-family: -apple-system, sans-serif; font-size: 14px; color: #DCFCE7; font-weight: 600; letter-spacing: 0.5px;">✅ RESERVA CONFIRMADA</div>
              <h1 style="margin: 6px 0 0 0; font-family: -apple-system, sans-serif; font-size: 22px; font-weight: 700; color: #FFFFFF; line-height: 1.3;">
                ¡Todo listo, {e_nombre}!
              </h1>
            </td></tr>

            <tr><td style="padding: 20px 24px 16px 24px;">
              <p style="margin: 0; font-family: -apple-system, sans-serif; font-size: 14px; color: #64748B; line-height: 1.5;" class="txt-muted">
                Tu reserva está confirmada. Abajo encontrás todo lo que necesitás para el retiro.
              </p>
            </td></tr>

            {img_html}

            <!-- Resumen -->
            <tr><td style="padding: 0 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F8FAFC; border-radius: 8px;" class="stat-bg">
                <tr><td style="padding: 16px;">
                  <div style="font-family: -apple-system, sans-serif; font-size: 16px; font-weight: 700; color: #0F172A; margin-bottom: 4px;" class="txt-main">{e_vehiculo}</div>
                  {f'<div style="font-family: monospace; font-size: 12px; color: #64748B; margin-bottom: 12px;" class="txt-muted">Patente: {e_patente}</div>' if e_patente else '<div style="height: 8px;"></div>'}

                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td class="col-stack" width="50%" style="vertical-align: top; padding-right: 8px;">
                        <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase;" class="txt-muted">Retiro</div>
                        <div style="font-family: -apple-system, sans-serif; font-size: 14px; font-weight: 700; color: #0F172A; margin-top: 2px;" class="txt-main">{fecha_ini}</div>
                        <div style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B;" class="txt-muted">{hora_ini} hrs</div>
                      </td>
                      <td class="col-stack" width="50%" style="vertical-align: top; padding-left: 8px;">
                        <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase;" class="txt-muted">Devolución</div>
                        <div style="font-family: -apple-system, sans-serif; font-size: 14px; font-weight: 700; color: #0F172A; margin-top: 2px;" class="txt-main">{fecha_fin}</div>
                        <div style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B;" class="txt-muted">{hora_fin} hrs</div>
                      </td>
                    </tr>
                  </table>

                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top: 12px; padding-top: 12px; border-top: 1px solid #E2E8F0;" class="divider">
                    <tr>
                      <td style="font-family: -apple-system, sans-serif; font-size: 12px; color: #64748B;" class="txt-muted">Método de pago</td>
                      <td align="right" style="font-family: -apple-system, sans-serif; font-size: 12px; font-weight: 600; color: #0F172A;" class="txt-main">{e_pago}</td>
                    </tr>
                    <tr>
                      <td style="font-family: -apple-system, sans-serif; font-size: 11px; color: #94A3B8; padding-top: 6px;" class="txt-muted">Neto ${neto:,.0f} + IVA 19% ${iva:,.0f}</td>
                      <td align="right" style="font-family: -apple-system, sans-serif; font-size: 16px; font-weight: 800; color: #0F172A; padding-top: 6px;" class="txt-main">${total:,.0f}</td>
                    </tr>
                  </table>
                </td></tr>
              </table>
            </td></tr>

            <!-- Instrucciones de retiro -->
            <tr><td style="padding: 20px 24px 8px 24px;">
              <div style="font-family: -apple-system, sans-serif; font-size: 11px; font-weight: 600; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px;" class="txt-muted">📍 QUÉ TRAER Y DÓNDE RETIRAR</div>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #FEF9C3; border-radius: 8px; border: 1px solid #FDE68A;">
                <tr><td style="padding: 14px 16px;">
                  <div style="font-family: -apple-system, sans-serif; font-size: 13px; color: #854D0E; line-height: 1.6;">
                    <strong>Documentos:</strong><br>
                    ✓ Licencia de conducir vigente<br>
                    ✓ Cédula de identidad<br>
                    ✓ Tarjeta de crédito a nombre del titular<br><br>
                    <strong>Lugar de retiro:</strong><br>
                    {direccion_negocio}<br>
                    <a href="{maps_url}" style="color: #CA8A04; font-weight: 600;">Ver en Google Maps →</a>
                  </div>
                </td></tr>
              </table>
            </td></tr>

            <!-- CTA WhatsApp -->
            <tr><td style="padding: 20px 24px 24px 24px;" align="center">
              <a href="{wa_negocio}" style="display: inline-block; background: #25D366; color: #FFFFFF; padding: 14px 28px; border-radius: 8px; text-decoration: none; font-weight: 700; font-size: 15px;">💬 Coordinar por WhatsApp</a>
              <div style="margin-top: 10px; font-family: -apple-system, sans-serif; font-size: 12px; color: #94A3B8;" class="txt-muted">
                O llamanos al {telefono_negocio}
              </div>
            </td></tr>
          </table>
        </td></tr>

        <tr><td style="padding: 20px 12px 12px 12px; text-align: center;">
          <div style="font-family: -apple-system, sans-serif; font-size: 11px; color: #64748B; line-height: 1.6;" class="txt-muted">
            <strong style="color: #475569;">{nombre_negocio}</strong> · RUT {rut_negocio}<br>
            {direccion_negocio} · {telefono_negocio}<br>
            <a href="mailto:{email_negocio}" style="color: #64748B; text-decoration: none;">{email_negocio}</a>
          </div>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>"""

    text = f"""✅ RESERVA CONFIRMADA

¡Todo listo, {nombre_cliente}!

Tu reserva está confirmada:
VEHÍCULO: {vehiculo}{f' ({patente})' if patente else ''}
Retiro:    {fecha_ini} a las {hora_ini}
Devolución:{fecha_fin} a las {hora_fin}
Total: ${total:,.0f} (IVA incluido)
Pago: {metodo_pago or 'No especificado'}

QUÉ TRAER:
- Licencia de conducir vigente
- Cédula de identidad
- Tarjeta de crédito a nombre del titular

LUGAR DE RETIRO:
{direccion_negocio}
{maps_url}

Coordiná por WhatsApp: {wa_negocio}
O respondé directamente a este email.

--
{nombre_negocio} · RUT {rut_negocio}
{direccion_negocio} · {telefono_negocio}
"""

    return await enviar_email(
        to=email_cliente,
        subject=asunto,
        html=html,
        from_name=nombre_negocio,
        reply_to=email_negocio,
        text=text,
    )


async def notificar_reserva_cancelada_cliente(
    email_cliente: str,
    nombre_cliente: str,
    vehiculo: str,
    inicio: str,
    fin: str,
    motivo: str | None = None,
    nombre_negocio: str = "Rent a Car Vásquez",
    rut_negocio: str = "78.356.635-4",
    direccion_negocio: str = "Miraflores 708, Puerto Natales",
    telefono_negocio: str = "+56 9 4172 1688",
    email_negocio: str = "reservas@rentacarvasquez.com",
    sitio_web: str = "https://rentacarvasquez.com",
) -> bool:
    """Email al cliente: reserva cancelada (tono empático + re-engagement)."""

    fecha_ini, _ = _fecha_hora_es(inicio)
    fecha_fin, _ = _fecha_hora_es(fin)
    e_nombre = _esc(nombre_cliente)
    e_vehiculo = _esc(vehiculo)
    e_motivo = _esc(motivo or "")

    wa_negocio = f"https://wa.me/{telefono_negocio.replace('+', '').replace(' ', '')}?text=Hola, tengo una consulta sobre mi reserva cancelada del {vehiculo}."

    preheader = f"Tu reserva del {e_vehiculo} fue cancelada. Escribinos si necesitás ayuda."
    asunto = f"Reserva cancelada · {vehiculo}"

    motivo_html = ""
    if motivo:
        motivo_html = f"""
        <tr><td style="padding: 0 24px 12px 24px;">
          <div style="background: #FEF2F2; border-left: 3px solid #DC2626; padding: 12px 16px; border-radius: 4px;">
            <div style="font-family: -apple-system, sans-serif; font-size: 12px; color: #991B1B; font-weight: 600; margin-bottom: 4px;">MOTIVO</div>
            <div style="font-family: -apple-system, sans-serif; font-size: 14px; color: #7F1D1D;">{e_motivo}</div>
          </div>
        </td></tr>
        """

    html = f"""<!DOCTYPE html>
<html lang="es" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <title>Reserva cancelada</title>
  <style>
    @media (prefers-color-scheme: dark) {{
      .email-bg {{ background: #0F172A !important; }}
      .card {{ background: #1E293B !important; }}
      .txt-main {{ color: #F1F5F9 !important; }}
      .txt-muted {{ color: #94A3B8 !important; }}
      .stat-bg {{ background: #0F172A !important; }}
    }}
    @media only screen and (max-width: 600px) {{
      .container {{ width: 100% !important; }}
    }}
    a {{ color: #2E7D32; }}
  </style>
</head>
<body style="margin: 0; padding: 0; background: #F1F5F9;" class="email-bg">
  <div style="display: none; font-size: 1px; color: #F1F5F9; line-height: 1px; max-height: 0; max-width: 0; opacity: 0; overflow: hidden;">{preheader}</div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F1F5F9;" class="email-bg">
    <tr><td align="center" style="padding: 24px 12px;">
      <table role="presentation" class="container" width="600" cellpadding="0" cellspacing="0" border="0" style="max-width: 600px; width: 100%;">

        <tr><td style="padding: 0 0 16px 0; text-align: left;">
          <div style="font-size: 13px; color: #64748B; font-weight: 600; letter-spacing: 0.5px;" class="txt-muted">{nombre_negocio.upper()}</div>
        </td></tr>

        <tr><td style="background: #FFFFFF; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.05);" class="card">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr><td style="padding: 24px 24px 8px 24px;">
              <h1 style="margin: 0; font-family: -apple-system, sans-serif; font-size: 22px; font-weight: 700; color: #0F172A; line-height: 1.3;" class="txt-main">
                Hola {e_nombre}, tu reserva fue cancelada
              </h1>
              <p style="margin: 8px 0 0 0; font-family: -apple-system, sans-serif; font-size: 14px; color: #64748B; line-height: 1.5;" class="txt-muted">
                Lamentamos los inconvenientes. Abajo te dejamos el detalle.
              </p>
            </td></tr>

            {motivo_html}

            <tr><td style="padding: 12px 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #F8FAFC; border-radius: 8px;" class="stat-bg">
                <tr><td style="padding: 14px 16px;">
                  <div style="font-family: -apple-system, sans-serif; font-size: 15px; font-weight: 700; color: #0F172A;" class="txt-main">{e_vehiculo}</div>
                  <div style="font-family: -apple-system, sans-serif; font-size: 13px; color: #64748B; margin-top: 4px;" class="txt-muted">Del {fecha_ini} al {fecha_fin}</div>
                </td></tr>
              </table>
            </td></tr>

            <tr><td style="padding: 20px 24px 24px 24px;">
              <div style="font-family: -apple-system, sans-serif; font-size: 14px; color: #0F172A; line-height: 1.6; margin-bottom: 14px;" class="txt-main">
                <strong>¿Querés reservar otro vehículo?</strong> Tenemos más opciones disponibles. Escribinos por WhatsApp o respondé este email y te ayudamos.
              </div>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr><td style="text-align: center;">
                  <a href="{sitio_web}/vehiculos" style="display: inline-block; background: #2E7D32; color: #FFFFFF; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 700; font-size: 14px; margin: 4px;">Ver vehículos disponibles</a>
                  <a href="{wa_negocio}" style="display: inline-block; background: #25D366; color: #FFFFFF; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 700; font-size: 14px; margin: 4px;">💬 WhatsApp</a>
                </td></tr>
              </table>
            </td></tr>
          </table>
        </td></tr>

        <tr><td style="padding: 20px 12px 12px 12px; text-align: center;">
          <div style="font-family: -apple-system, sans-serif; font-size: 11px; color: #64748B; line-height: 1.6;" class="txt-muted">
            <strong style="color: #475569;">{nombre_negocio}</strong> · RUT {rut_negocio}<br>
            {direccion_negocio} · {telefono_negocio}<br>
            <a href="mailto:{email_negocio}" style="color: #64748B; text-decoration: none;">{email_negocio}</a>
          </div>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>"""

    text = f"""RESERVA CANCELADA

Hola {nombre_cliente},

Te informamos que tu reserva del {vehiculo} del {fecha_ini} al {fecha_fin} fue cancelada.
{f'MOTIVO: {motivo}' if motivo else ''}

¿Querés reservar otro vehículo? Escribinos:
WhatsApp: {wa_negocio}
Web: {sitio_web}/vehiculos
O respondé directamente a este email.

--
{nombre_negocio} · RUT {rut_negocio}
{direccion_negocio} · {telefono_negocio}
"""

    return await enviar_email(
        to=email_cliente,
        subject=asunto,
        html=html,
        from_name=nombre_negocio,
        reply_to=email_negocio,
        text=text,
    )


async def notificar_otp_cliente(
    email_cliente: str,
    nombre_cliente: str,
    codigo: str,
    vehiculo: str,
    inicio: str,
    fin: str,
):
    """Email con el codigo OTP de 6 digitos para verificar la reserva."""
    asunto = f"Tu codigo de verificacion: {codigo}"
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #2E7D32;">Verifica tu reserva</h2>
        <p>Hola {nombre_cliente},</p>
        <p>Recibimos tu solicitud de reserva del <strong>{vehiculo}</strong>
           del {_formatear_fecha(inicio)} al {_formatear_fecha(fin)}.</p>
        <p>Ingresa este codigo en la web para confirmar que tu email es real:</p>
        <div style="background-color: #f5f5f5; padding: 30px; border-radius: 8px;
                    margin: 20px 0; text-align: center;">
            <div style="font-size: 42px; font-weight: bold;
                        letter-spacing: 8px; color: #2E7D32; font-family: monospace;">
                {codigo}
            </div>
        </div>
        <p style="color: #666; font-size: 13px;">
            Este codigo expira en 15 minutos. Si no solicitaste esta reserva,
            ignora este email.
        </p>
        <p>Gracias,<br>Rent a Car Vasquez</p>
    </div>
    """
    await enviar_email(to=email_cliente, subject=asunto, html=html)
