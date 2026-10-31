"""Canales de contacto del prestador (email, whatsapp, redes, google)."""


def _canal_email(tipo, descripcion, visible=True, activo=True, orden=0):
    return {
        "tipo": tipo,
        "direccion": f"{tipo}@rentacarvasquez.com",
        "descripcion": descripcion,
        "visible_publico": visible,
        "activo": activo,
        "orden": orden,
    }


DEFAULT_CANALES_EMAIL = [
    _canal_email("reservas", "Recibe notificaciones de nuevas reservas.", orden=1),
    _canal_email("contacto", "Consultas generales y dudas previas.", orden=2),
    _canal_email("soporte", "Asistencia durante el alquiler.", orden=3),
    _canal_email("facturacion", "Facturas y documentos administrativos.", orden=4),
    _canal_email("no_reply", "Solo envios automaticos.", visible=False, orden=5),
    _canal_email("cobranzas", "Recordatorios de pagos pendientes.", visible=False, orden=6),
    _canal_email("social", "Gestion de redes sociales.", visible=False, orden=7),
    _canal_email("seo", "Herramientas SEO.", visible=False, orden=8),
]


DEFAULT_WHATSAPP = [
    {"tipo": "principal", "numero": "+56941721688", "descripcion": "Numero principal.", "activo": True},
]

DEFAULT_REDES = [
    {"plataforma": "instagram", "url": "", "descripcion": "Fotos de la flota."},
    {"plataforma": "facebook", "url": "", "descripcion": "Pagina oficial."},
    {"plataforma": "tiktok", "url": "", "descripcion": "Videos."},
]

DEFAULT_GOOGLE = {
    "service_account_email": "seo-bot@baqueano-natales-prod.iam.gserviceaccount.com",
    "gbp_place_id": None,
    "gbp_maps_url": None,
    "search_console_verificado": False,
}


def _merge_list(defaults, custom):
    if not isinstance(custom, list):
        return list(defaults)
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
    perfil = prestador.perfil_negocio or {}
    custom = perfil.get("canales_contacto") or {}
    if not isinstance(custom, dict):
        custom = {}
    return {
        "email": _merge_list(DEFAULT_CANALES_EMAIL, custom.get("email", [])),
        "whatsapp": _merge_list(DEFAULT_WHATSAPP, custom.get("whatsapp", [])),
        "redes_sociales": _merge_list(DEFAULT_REDES, custom.get("redes_sociales", [])),
        "google": {**DEFAULT_GOOGLE, **(custom.get("google") or {})},
        "email_reenvio_personal": custom.get("email_reenvio_personal"),
    }
