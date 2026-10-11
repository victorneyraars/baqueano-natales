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

from app.modules.social.deps import AdminUser
from app.modules.promocion import services
from app.modules.promocion.schemas import (
    GenerarAficheRequest,
    GenerarAficheResponse,
    PlantillaInfo,
    PlantillasListResponse,
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
