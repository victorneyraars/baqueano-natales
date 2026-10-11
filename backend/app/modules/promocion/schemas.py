"""Schemas Pydantic del modulo promocion."""
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


# =========================================================
# Plantillas
# =========================================================

class PlantillaInfo(BaseModel):
    """Metadata de una plantilla (para la galeria)."""
    id: str
    nombre: str
    descripcion: str
    params_requeridos: list[str]
    params_opcionales: list[str]


class PlantillasListResponse(BaseModel):
    """Listado de plantillas disponibles."""
    plantillas: list[PlantillaInfo]


# =========================================================
# Generar afiche
# =========================================================

class GenerarAficheRequest(BaseModel):
    """Request para generar un afiche SVG.

    `tamano` es una clave de brand_kit.TAMANOS:
        ig_feed, ig_story, ig_cuadrado, fb_feed, gbp_post
    """
    plantilla: str = Field(..., min_length=1, max_length=50)
    tamano: str = Field("ig_feed", min_length=1, max_length=30)
    params: dict[str, Any] = Field(
        ...,
        description="Datos del afiche (prestador, servicio, etc).",
    )


class GenerarAficheResponse(BaseModel):
    """Respuesta con el SVG generado."""
    svg: str
    plantilla: str
    tamano: str
    width: int
    height: int
