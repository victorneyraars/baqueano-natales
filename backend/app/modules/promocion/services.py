"""Servicios del modulo promocion.

Logica de negocio: valida inputs, elige plantilla, renderiza SVG.
No maneja HTTP directamente (eso lo hace routes.py).
"""
import logging

from fastapi import HTTPException, status

from app.core.config import settings
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

# =========================================================
# Publicar afiche en redes
# =========================================================

import uuid as _uuid
from datetime import datetime, timezone
from pathlib import Path


MEDIA_PROMOCIONES_DIR = Path("/app/media/promociones")


def _guardar_png(png_bytes: bytes) -> tuple[str, str]:
    """Guarda el PNG en /app/media/promociones/.

    Returns:
        (filename, url_publica)
    """
    MEDIA_PROMOCIONES_DIR.mkdir(parents=True, exist_ok=True)
    fname = f"{_uuid.uuid4().hex}.png"
    path = MEDIA_PROMOCIONES_DIR / fname
    path.write_bytes(png_bytes)
    url = f"{settings.PUBLIC_MEDIA_URL.rstrip('/')}/media/promociones/{fname}"
    return fname, url


async def publicar_afiche(
    db,
    *,
    plantilla: str,
    tamano: str,
    params: dict,
    redes: list[str] | None = None,
    caption: str | None = None,
) -> dict:
    """Genera un afiche, lo guarda como PNG y encola publicaciones.

    Args:
        plantilla: id de plantilla.
        tamano: clave de TAMANOS.
        params: datos del afiche.
        redes: lista de redes ('facebook', 'instagram', 'google_business')
            o None/'auto' para usar ConfigSocial.
        caption: texto del post. Si None, usa params['message'] o
            params['titulo'].

    Returns:
        dict con:
          - afiche_url: URL publica del PNG.
          - publicaciones: lista de ids de PublicacionSocial encoladas.
          - redes: redes en las que se encolo.
    """
    from app.core.config import settings as _settings
    from app.modules.social import services as social_services
    from app.modules.social.models import PropietarioTipo, Red
    from app.modules.social.schemas import PublicacionSocialCreate

    # 1. Generar SVG + PNG
    svg_str = generar_afiche(plantilla, tamano, params)["svg"]
    png_bytes = svg.svg_a_png(svg_str, width_px=bk.TAMANOS[tamano][0])
    if not png_bytes:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo generar el PNG del afiche",
        )
    fname, url = _guardar_png(png_bytes)

    # 2. Resolver cuenta central
    from sqlalchemy import select
    from app.modules.social.models import CuentaSocial

    stmt = (
        select(CuentaSocial)
        .where(
            CuentaSocial.red == Red.FACEBOOK,
            CuentaSocial.propietario_tipo == PropietarioTipo.BAQUEANO,
            CuentaSocial.propietario_id.is_(None),
            CuentaSocial.activo.is_(True),
        )
        .limit(1)
    )
    cuenta = (await db.execute(stmt)).scalar_one_or_none()
    if cuenta is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No hay cuenta central de Facebook activa",
        )

    # 3. Determinar redes
    cfg = await social_services.obtener_config(db)
    if redes is None or "auto" in redes:
        redes_efectivas = []
        if cfg is None or cfg.publicar_en_facebook:
            redes_efectivas.append("facebook")
        if cfg is None or cfg.publicar_en_instagram:
            redes_efectivas.append("instagram")
        if cfg is not None and cfg.publicar_en_google:
            redes_efectivas.append("google_business")
    else:
        redes_efectivas = [r for r in redes if r]

    # 4. Caption
    mensaje = (
        caption
        or params.get("message")
        or params.get("titulo")
        or params.get("servicio")
        or "Nuevo en Baqueano Natales"
    )

    # 5. Encolar por red
    pubs_ids: list[str] = []
    redes_ok: list[str] = []
    mapa_red = {
        "facebook": Red.FACEBOOK,
        "instagram": Red.INSTAGRAM,
        "google_business": Red.GOOGLE_BUSINESS,
    }
    for red_str in redes_efectivas:
        red = mapa_red.get(red_str)
        if red is None:
            continue
        try:
            pub = await social_services.encolar_publicacion(
                db,
                PublicacionSocialCreate(
                    cuenta_id=cuenta.id,
                    recurso_tipo="promocion",
                    recurso_id=_uuid.uuid4(),
                    red=red,
                    contenido={
                        "message": mensaje,
                        "image_urls": [url],
                    },
                ),
            )
            pubs_ids.append(str(pub.id))
            redes_ok.append(red_str)
        except Exception as e:
            logger.warning("Fallo encolando red %s: %s", red_str, e)

    return {
        "afiche_filename": fname,
        "afiche_url": url,
        "publicaciones": pubs_ids,
        "redes": redes_ok,
    }

