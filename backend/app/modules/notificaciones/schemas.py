"""Schemas del modulo notificaciones."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class NotificacionResponse(BaseModel):
    """Vista de una notificacion del usuario."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    tipo: str
    canal: str
    titulo: str
    body: str
    data: dict | None
    estado: str
    creado_en: datetime
    enviado_en: datetime | None
    abierto_en: datetime | None
