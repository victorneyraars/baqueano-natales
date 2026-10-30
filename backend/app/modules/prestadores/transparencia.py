"""Transparencia / politicas de renta por vertical.

Este modulo concentra los datos que el cliente necesita conocer ANTES
de reservar: deposito, kilometraje, combustible, politica de cancelacion,
edad minima y licencia requerida.

Los datos viven en `perfil_negocio.transparencia` (JSONB). Si el prestador
no configuro nada, se devuelven defaults regionales (Patagonia / Chile).

Consumido por:
- GET /prestadores/{slug}/perfil-completo (web)
- GET /prestadores/{slug} (app)
"""

# Defaults regionales (basados en practicas de rent a car en Puerto Natales)
DEFAULT_TRANSPARENCIA: dict[str, object] = {
    "deposito_clp": 100000,
    "kilometraje": "ilimitado",
    "combustible": "lleno_lleno",
    "cancelacion": "gratis_48h",
    "edad_minima": 21,
    "licencia_requerida": "chilena_o_internacional",
}

# Textos legibles (se resuelven en el cliente, aqui solo se persiste el enum)
CANCELACION_LABELS = {
    "gratis_48h": "Gratis hasta 48h antes",
    "gratis_24h": "Gratis hasta 24h antes",
    "no_reembolsable": "No reembolsable",
    "personalizada": "Personalizada",
}

KILOMETRAJE_LABELS = {
    "ilimitado": "Ilimitado",
    "limitado_dia": "Limitado por dia",
    "limitado_total": "Limitado total",
}

COMBUSTIBLE_LABELS = {
    "lleno_lleno": "Lleno / Lleno",
    "lleno_vacio": "Lleno / Vacio",
    "cargo_por_uso": "Cargo por uso",
}

LICENCIA_LABELS = {
    "chilena_o_internacional": "Chilena o internacional",
    "solo_chilena": "Solo chilena",
    "solo_internacional": "Solo internacional",
}


def build_transparencia(prestador) -> dict:
    """Devuelve transparencia combinada: defaults + override del JSONB.

    Si el prestador marco visible=False, devuelve {"visible": False}.
    Si algun campo esta en null explicitamente, se respeta (se oculta en web).
    """
    perfil = prestador.perfil_negocio or {}
    custom = perfil.get("transparencia") or {}
    if not isinstance(custom, dict):
        custom = {}

    # Si explicitamente deshabilitado -> solo visible=False
    if custom.get("visible") is False:
        return {"visible": False}

    # Merge: defaults <- custom (custom gana, incluso si es None para "ocultar")
    result: dict[str, object] = {"visible": True}
    for key, default in DEFAULT_TRANSPARENCIA.items():
        if key in custom:
            result[key] = custom[key]  # permite None para ocultar
        else:
            result[key] = default

    # Campos opcionales del override (si vienen, se incluyen)
    for key in (
        "kilometraje_km_dia",
        "cancelacion_detalle",
        "notas_extra",
    ):
        if key in custom and custom[key] is not None:
            result[key] = custom[key]

    return result
