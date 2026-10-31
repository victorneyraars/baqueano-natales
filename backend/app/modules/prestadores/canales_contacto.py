"""Canales de contacto del prestador (email, whatsapp, redes, google).

Fuente de verdad: perfil_negocio.canales_contacto (JSONB).
Si el prestador no configuro nada, se devuelven los defaults regionales.

Consumido por:
- GET /perfil-completo (web)
- GET /prestadores/{slug} (app)
- GET /mis-prestadores/{id}/canales (app dueño, editable)

Cada canal tiene:
- tipo: identificador unico (reservas, contacto, ...)
- direccion: email@dominio (para emails)
- descripcion: explicacion detallada para el dueño
- visible_publico: mostrar en web (footer, /contacto, JSON-LD)
- activo: recibir notificaciones
- override_destino: si no es null, este canal forwardea a este email
                    (por defecto null -> usa email_reenvio_personal)
- orden: para ordenar en UI
"""


def _canal_email(tipo, descripcion, visible=True, activo=True, orden=0):
    return {
        "tipo": tipo,
        "direccion": f"{tipo}@rentacarvasquez.com",
        "descripcion": descripcion,
        "visible_publico": visible,
        "activo": activo,
        "override_destino": None,
        "orden": orden,
    }


DEFAULT_CANALES_EMAIL = [
    _canal_email(
        "reservas",
        "Recibe todas las notificaciones de nuevas reservas (con botones para aceptar o rechazar), confirmaciones y consultas de clientes sobre fechas especificas. Es el correo mas importante para operar el negocio.",
        orden=1,
    ),
    _canal_email(
        "contacto",
        "Consultas generales de personas interesadas en arrendar: precios, disponibilidad general, informacion turistica y dudas antes de reservar.",
        orden=2,
    ),
    _canal_email(
        "soporte",
        "Comunicaciones urgentes de clientes durante un alquiler activo: accidentes, problemas mecanicos, extensiones de plazo o asistencia en carretera.",
        orden=3,
    ),
    _canal_email(
        "facturacion",
        "Facturas, boletas, comprobantes de pago y documentos administrativos. Lo usan los clientes que necesitan factura a nombre de empresa.",
        orden=4,
    ),
    _canal_email(
        "no_reply",
        "Solo para envios automaticos del sistema (confirmaciones de reserva, recordatorios). Los clientes no deben responder. NO se muestra en la web.",
        visible=False,
        orden=5,
    ),
    _canal_email(
        "cobranzas",
        "Recordatorios de pagos pendientes y notificaciones de deuda. Uso interno del negocio.",
        visible=False,
        orden=6,
    ),
    _canal_email(
        "social",
        "Recuperacion de contrasenas, verificacion y gestion de cuentas de Instagram, Facebook y TikTok.",
        visible=False,
        orden=7,
    ),
    _canal_email(
        "seo",
        "Acceso a herramientas de SEO: Google Search Console, Google Analytics, PageSpeed Insights y sitemap.",
        visible=False,
        orden=8,
    ),
]


DEFAULT_WHATSAPP = [
    {
        "tipo": "principal",
        "numero": "+56941721688",
        "descripcion": "Numero principal para atencion al cliente y reservas. Se usa para notificaciones WhatsApp y boton directo en la web.",
        "activo": True,
    },
]

DEFAULT_REDES = [
    {
        "plataforma": "instagram",
        "url": "",
        "descripcion": "Fotos de la flota, destinos turisticos y resenas de clientes.",
    },
    {
        "plataforma": "facebook",
        "url": "",
        "descripcion": "Pagina oficial, resenas y publicaciones de la empresa.",
    },
    {
        "plataforma": "tiktok",
        "url": "",
        "descripcion": "Videos cortos de la flota y aventuras en la Patagonia.",
    },
]

DEFAULT_GOOGLE = {
    "service_account_email": "seo-bot@baqueano-natales-prod.iam.gserviceaccount.com",
    "gbp_place_id": None,
    "gbp_maps_url": None,
    "search_console_verificado": False,
}

# Email principal que recibe TODO por defecto (catch-all de Cloudflare)
DEFAULT_EMAIL_REENVIO = "victorneyraars@gmail.com"


def _merge_list(defaults, custom):
    """Merge: custom reemplaza por tipo/plataforma, defaults rellenan faltantes."""
    if not isinstance(custom, list):
        return [dict(d) for d in defaults]
    custom_by_key = {}
    for item in custom:
        if not isinstance(item, dict):
            continue
        key = item.get("tipo") or item.get("plataforma")
        if key:
            custom_by_key[key] = item
    result = []
    for default in defaults:
        key = default.get("tipo") or default.get("plataforma")
        if key in custom_by_key:
            result.append({**default, **custom_by_key[key]})
        else:
            result.append(dict(default))
    default_keys = {d.get("tipo") or d.get("plataforma") for d in defaults}
    for item in custom:
        if not isinstance(item, dict):
            continue
        key = item.get("tipo") or item.get("plataforma")
        if key and key not in default_keys:
            result.append(item)
    return result


def build_canales_contacto(prestador) -> dict:
    """Devuelve canales combinados: defaults + override del JSONB.

    Incluye email_reenvio_personal + flag _verificado (lo setea el router
    que consulta Cloudflare; aca solo devuelve el email sin estado).
    """
    perfil = prestador.perfil_negocio or {}
    custom = perfil.get("canales_contacto") or {}
    if not isinstance(custom, dict):
        custom = {}

    email_reenvio = custom.get("email_reenvio_personal") or DEFAULT_EMAIL_REENVIO

    return {
        "email": _merge_list(DEFAULT_CANALES_EMAIL, custom.get("email", [])),
        "whatsapp": _merge_list(DEFAULT_WHATSAPP, custom.get("whatsapp", [])),
        "redes_sociales": _merge_list(
            DEFAULT_REDES, custom.get("redes_sociales", [])
        ),
        "google": {**DEFAULT_GOOGLE, **(custom.get("google") or {})},
        "email_reenvio_personal": email_reenvio,
    }
