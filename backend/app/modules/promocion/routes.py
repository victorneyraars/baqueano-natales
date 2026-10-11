"""Endpoints HTTP del modulo promocion.

Todos requieren rol admin (el modulo esta pensado para uso del admin
y potencialmente del propietario en el futuro).

Endpoints:
    GET  /api/v1/admin/promocion/plantillas
    POST /api/v1/admin/promocion/generar
    POST /api/v1/admin/promocion/generar-svg      (devuelve text/svg)
"""
import logging

from fastapi import APIRouter, status
from fastapi.responses import Response

from app.core.db import DbSession
from app.modules.social.deps import AdminUser
from app.modules.promocion import services
from app.modules.promocion.schemas import (
    GenerarAficheRequest,
    GenerarAficheResponse,
    PlantillaInfo,
    PlantillasListResponse,
    PublicarAficheRequest,
    PublicarAficheResponse,
)

logger = logging.getLogger(__name__)

router_admin = APIRouter(prefix="/admin/promocion", tags=["admin-promocion"])


@router_admin.get(
    "/plantillas",
    response_model=PlantillasListResponse,
    summary="Listar plantillas de afiches disponibles",
)
async def listar_plantillas(_admin: AdminUser) -> PlantillasListResponse:
    items = services.listar_plantillas()
    return PlantillasListResponse(
        plantillas=[PlantillaInfo(**p) for p in items]
    )


@router_admin.post(
    "/generar",
    response_model=GenerarAficheResponse,
    summary="Generar un afiche SVG (devuelve JSON con SVG inline)",
)
async def generar_afiche(
    datos: GenerarAficheRequest,
    _admin: AdminUser,
) -> GenerarAficheResponse:
    result = services.generar_afiche(
        plantilla=datos.plantilla,
        tamano=datos.tamano,
        params=datos.params,
    )
    return GenerarAficheResponse(**result)


@router_admin.post(
    "/generar-svg",
    summary="Generar un afiche SVG (devuelve directamente image/svg+xml)",
    responses={
        200: {
            "content": {"image/svg+xml": {}},
            "description": "Afiche SVG",
        },
    },
)
async def generar_afiche_svg(
    datos: GenerarAficheRequest,
    _admin: AdminUser,
) -> Response:
    result = services.generar_afiche(
        plantilla=datos.plantilla,
        tamano=datos.tamano,
        params=datos.params,
    )
    return Response(
        content=result["svg"],
        media_type="image/svg+xml",
        headers={
            "Content-Disposition": (
                f'inline; filename="afiche-{datos.plantilla}-{datos.tamano}.svg"'
            ),
            "Cache-Control": "private, max-age=0, no-store",
        },
    )

@router_admin.post(
    "/publicar",
    response_model=PublicarAficheResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Generar afiche y publicar en redes sociales",
    description=(
        "Genera el PNG del afiche, lo guarda en /media/promociones/ y "
        "encola publicaciones en las redes indicadas. Si `redes` es None "
        "o ['auto'], se usa ConfigSocial (respeta auto_publish + flags)."
    ),
)
async def generar_y_publicar(
    datos: PublicarAficheRequest,
    db: DbSession,
    _admin: AdminUser,
) -> PublicarAficheResponse:
    result = await services.publicar_afiche(
        db,
        plantilla=datos.plantilla,
        tamano=datos.tamano,
        params=datos.params,
        redes=datos.redes,
        caption=datos.caption,
    )
    return PublicarAficheResponse(**result)

@router_admin.post(
    "/generar-png",
    summary="Generar un afiche como PNG (image/png)",
    responses={
        200: {
            "content": {"image/png": {}},
            "description": "Afiche PNG",
        },
    },
)
async def generar_png(
    datos: GenerarAficheRequest,
    _admin: AdminUser,
) -> Response:
    """Devuelve el PNG binario del afiche.

    Util para descargar y compartir desde la app. En el backend usa
    cairosvg (libcairo). El tamano se respeta al pixel exacto.
    """
    from app.modules.promocion import brand_kit as bk, svg_service
    result = services.generar_afiche(
        plantilla=datos.plantilla,
        tamano=datos.tamano,
        params=datos.params,
    )
    width = bk.TAMANOS[datos.tamano][0]
    png_bytes = svg_service.svg_a_png(result["svg"], width_px=width)
    return Response(
        content=png_bytes,
        media_type="image/png",
        headers={
            "Content-Disposition": (
                f'inline; filename="afiche-{datos.plantilla}-{datos.tamano}.png"'
            ),
            "Cache-Control": "private, max-age=0, no-store",
        },
    )

