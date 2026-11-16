"""Schemas Pydantic de reviews (M6)."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ReviewCreate(BaseModel):
    """Cliente crea una review de una orden entregada."""

    rating: int = Field(..., ge=1, le=5, description="1 a 5 estrellas")
    comentario: str | None = Field(None, max_length=2000)




class ReviewCreateGeneric(BaseModel):
    """Cliente crea una review para cualquier entidad (orden, reserva, etc.)."""
    
    entidad_tipo: str = Field(..., pattern="^(orden|reserva)$", description="Tipo de entidad: 'orden' o 'reserva'")
    entidad_id: UUID = Field(..., description="ID de la orden o reserva")
    rating: int = Field(..., ge=1, le=5, description="1 a 5 estrellas")
    comentario: str | None = Field(None, max_length=2000)

class ReviewResponderRequest(BaseModel):
    """Prestador responde una review (una sola vez)."""

    respuesta: str = Field(..., min_length=1, max_length=2000)


class ReviewResponse(BaseModel):
    """Review completa (para endpoints autenticados)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    prestador_id: UUID
    cliente_id: UUID
    orden_id: UUID | None = None  # Nullable para reviews de reserva
    entidad_tipo: str = "orden"
    entidad_id: UUID | None = None
    rating: int
    comentario: str | None
    respuesta_prestador: str | None
    respuesta_en: datetime | None
    activo: bool
    created_at: datetime


class ReviewPublicaItem(BaseModel):
    """Review en el listado publico del prestador."""

    id: UUID
    cliente_nombre: str | None = None
    rating: int
    comentario: str | None
    respuesta_prestador: str | None
    respuesta_en: datetime | None
    created_at: datetime


class ReviewPublicaListResponse(BaseModel):
    """Listado publico paginado de reviews."""

    items: list[ReviewPublicaItem]
    total: int
    promedio: float
    page: int
    page_size: int
