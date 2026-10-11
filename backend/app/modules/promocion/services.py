"""Servicios del modulo promocion.

Logica de negocio: valida inputs, elige plantilla, renderiza SVG.
No maneja HTTP directamente (eso lo hace routes.py).
"""
import logging

from fastapi import HTTPException, status

from app.modules.promocion import brand_kit as bk
from app.modules.promocion import svg_service as svg
from app.modules.promocion import templates

logger = logging.getLogger(__name__)


# Limites de seguridad (evitar abuso de recursos)
MAX_PARAMS_KEYS = 30
MAX_PARAM_STR_LEN = 2000
MAX_SVG_LEN = 200_000


def listar_plantillas() -> list[dict]:
    """Metadata de plantillas para la galeria."""
    return templates.listar_plantillas()


def _validar_params(params: dict) -> None:
    """Sanitiza y valida params antes de renderizar."""
    if len(params) > MAX_PARAMS_KEYS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Demasiados parametros (max {MAX_PARAMS_KEYS})",
        )
    for k, v in params.items():
        if not isinstance(k, str):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Las claves de params deben ser strings",
            )
        if isinstance(v, str) and len(v) > MAX_PARAM_STR_LEN:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Valor de '{k}' demasiado largo (max {MAX_PARAM_STR_LEN})",
            )
        if isinstance(v, list) and len(v) > 20:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Lista '{k}' demasiado larga (max 20)",
            )


def generar_afiche(plantilla: str, tamano: str, params: dict) -> dict:
    """Genera un afiche SVG.

    Returns:
        dict con {svg, plantilla, tamano, width, height}.

    Raises:
        HTTPException 404: plantilla o tamano no existen.
        HTTPException 422: params invalidos.
        HTTPException 500: SVG demasiado grande (proteccion).
    """
    if plantilla not in templates.TEMPLATES:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Plantilla desconocida: {plantilla}",
        )
    if tamano not in bk.TAMANOS:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tamano desconocido: {tamano}",
        )

    _validar_params(params)

    try:
        dwg = templates.render(plantilla, params, tamano)
    except Exception as e:
        logger.exception("Error renderizando plantilla %s", plantilla)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generando afiche: {e}",
        )

    svg_str = svg.to_string(dwg)
    if len(svg_str) > MAX_SVG_LEN:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="SVG resultante demasiado grande",
        )

    w, h = bk.TAMANOS[tamano]
    return {
        "svg": svg_str,
        "plantilla": plantilla,
        "tamano": tamano,
        "width": w,
        "height": h,
    }
