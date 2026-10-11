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

# =========================================================
# Publicar afiche en redes
# =========================================================

class PublicarAficheRequest(BaseModel):
    """Request para generar + publicar un afiche en redes.

    `redes` puede ser:
    - None o ["auto"]: usa ConfigSocial (respeta auto_publish + flags).
    - ["facebook", "instagram", "google_business"]: publica solo en las
      indicadas (override del admin).
    """
    plantilla: str = Field(..., min_length=1, max_length=50)
    tamano: str = Field("ig_feed", min_length=1, max_length=30)
    params: dict[str, Any] = Field(..., description="Datos del afiche.")
    redes: list[str] | None = Field(
        None,
        description="Redes a publicar. None/['auto'] = usar config.",
    )
    caption: str | None = Field(
        None,
        max_length=2000,
        description="Texto del post. Si None, se deduce de params.",
    )


class PublicarAficheResponse(BaseModel):
    """Respuesta de publicar afiche.

    - afiche_url: URL publica del PNG (para preview o reuso).
    - publicaciones: ids de PublicacionSocial encoladas.
    - redes: redes donde se encolo (subconjunto de las pedidas).
    """
    afiche_url: str
    afiche_filename: str
    publicaciones: list[str]
    redes: list[str]

