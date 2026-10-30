"""WhatsApp link info builder — shared across all verticals.

Single source of truth for:
- Phone normalization to E.164 (per country)
- Default message templates per vertical
- Merging of user-customized templates

Consumed by:
- GET /public/prestadores/{slug}/perfil-completo (web)
- GET /public/prestadores/{slug} (app)

Los placeholders ({sitio}, {marca}, etc.) los interpola el cliente.
"""

DEFAULT_TEMPLATES: dict[str, dict[str, str]] = {
    "arriendo-vehiculos": {
        "home": "Hola, vengo de {sitio}. Quiero consultar por arriendo de vehiculos.",
        "vehiculo": (
            "Hola, me interesa el {marca} {modelo} ({patente}). "
            "Esta disponible del {inicio} al {fin}?"
        ),
        "reserva": "Hola, quiero consultar por mi reserva del {inicio}.",
        "app": "Hola, vengo desde la app Baqueano. Quiero consultar por arriendo.",
    },
    "mecanica-automotriz": {
        "home": "Hola, vengo de {sitio}. Necesito un servicio de mecanica.",
        "servicio": "Hola, quiero consultar por el servicio de {servicio}.",
        "app": "Hola, vengo desde la app Baqueano. Necesito un servicio.",
    },
    "hostales": {
        "home": "Hola, vengo de {sitio}. Quiero consultar por disponibilidad.",
        "habitacion": (
            "Hola, me interesa la habitacion {habitacion}. "
            "Esta disponible del {inicio} al {fin}?"
        ),
        "app": "Hola, vengo desde la app Baqueano. Quiero consultar por alojamiento.",
    },
    "delivery": {
        "home": "Hola, vengo de {sitio}. Quiero hacer un pedido.",
        "producto": "Hola, me interesa el producto {producto}. Hacen envio a {direccion}?",
        "app": "Hola, vengo desde la app Baqueano. Quiero hacer un pedido.",
    },
    "taxis": {
        "home": "Hola, vengo de {sitio}. Quiero solicitar un viaje.",
        "viaje": "Hola, quiero un viaje de {origen} a {destino}.",
        "app": "Hola, vengo desde la app Baqueano. Quiero solicitar un viaje.",
    },
    "_default": {
        "home": "Hola, vengo de {sitio}. Quiero consultar.",
        "app": "Hola, vengo desde la app Baqueano. Quiero consultar.",
    },
}


def normalizar_whatsapp_e164(phone: str | None) -> str:
    """Normaliza un telefono a digitos E.164 SIN el + (ej: 56941721688).

    Acepta:
    - "+56 9 4172 1688" -> "56941721688"
    - "9 4172 1688"      -> "56941721688" (Chile, agrega 56)
    - "56941721688"      -> "56941721688" (ya normalizado)
    """
    if not phone:
        return ""
    digits = "".join(c for c in phone if c.isdigit())
    if not digits:
        return ""
    if digits.startswith("00"):
        return digits[2:]
    # Chile movil: 9 digitos empezando con 9 -> agregar 56
    if len(digits) == 9 and digits.startswith("9"):
        return "56" + digits
    return digits


def build_whatsapp_info(prestador, vertical_slug: str | None = None) -> dict:
    """Construye el bloque whatsapp_info del perfil.

    Returns:
        {
            "phone_e164": "+56941721688",
            "phone_digits": "56941721688",
            "templates": {
                "home": "...",
                "vehiculo": "...",
                ...
            }
        }
    """
    phone = prestador.whatsapp or prestador.telefono or ""
    digits = normalizar_whatsapp_e164(phone)
    if not digits:
        return {"phone_e164": "", "phone_digits": "", "templates": {}}

    templates = dict(DEFAULT_TEMPLATES.get(
        vertical_slug or "", DEFAULT_TEMPLATES["_default"],
    ))

    if prestador.whatsapp_mensaje:
        templates["home"] = prestador.whatsapp_mensaje

    perfil = prestador.perfil_negocio or {}
    custom = perfil.get("whatsapp", {}).get("templates", {})
    if isinstance(custom, dict):
        templates.update(
            {k: v for k, v in custom.items() if isinstance(v, str)},
        )

    return {
        "phone_e164": f"+{digits}",
        "phone_digits": digits,
        "templates": templates,
    }