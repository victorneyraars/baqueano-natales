"""Schemas del modulo notificaciones."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


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


# ==================== Admin ====================


class SegmentoRequest(BaseModel):
    """Segmento de destinatarios.

    - tipo="todos": todos los usuarios activos.
    - tipo="rol": usuarios con rol especifico (valor="cliente"|"prestador"|...).
    - tipo="usuarios": lista explicita de UUIDs.
    """

    tipo: str = Field(..., pattern="^(todos|rol|usuarios)$")
    valor: str | list[UUID] | None = None


class NotificacionAdminCreate(BaseModel):
    """Payload para enviar una notificacion manual."""

    titulo: str = Field(..., min_length=1, max_length=200)
    body: str = Field(..., min_length=1, max_length=2000)
    tipo: str = Field("sistema", pattern="^(recordatorio|promocion|sistema|campana)$")
    segmento: SegmentoRequest
    data: dict | None = None
    analytics_label: str | None = Field(None, max_length=50)


class EnvioMasivoResponse(BaseModel):
    """Resultado del envio masivo."""

    total: int
    enviados: int
    fallidos: int
    skipped: int


class NotificacionAdminResponse(BaseModel):
    """Vista admin de un log (incluye usuario_id)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    usuario_id: UUID | None
    tipo: str
    canal: str
    titulo: str
    body: str
    data: dict | None
    analytics_label: str | None
    estado: str
    error: str | None
    creado_en: datetime
    enviado_en: datetime | None
    abierto_en: datetime | None


class EstadoCount(BaseModel):
    """Conteo por estado."""
    estado: str
    count: int


class TipoCount(BaseModel):
    """Conteo por tipo."""
    tipo: str
    count: int


class TopNotificacion(BaseModel):
    """Notificacion con mas aperturas (por titulo)."""
    titulo: str
    total: int
    abiertas: int
    open_rate: float


class StatsResponse(BaseModel):
    """Dashboard de estadisticas."""
    total: int
    enviadas: int
    entregadas: int
    abiertas: int
    fallidas: int
    skipped: int
    delivery_rate: float
    open_rate: float
    por_estado: list[EstadoCount]
    por_tipo: list[TipoCount]
    top_5: list[TopNotificacion]


# ==================== Rate limit ====================


class RateLimitConfigResponse(BaseModel):
    """Config de rate limit de un tipo."""

    model_config = ConfigDict(from_attributes=True)

    tipo: str
    max_por_hora: int | None
    max_por_dia: int | None
    max_por_semana: int | None
    min_intervalo_seg: int | None
    strict: bool


class RateLimitConfigUpdate(BaseModel):
    """Update parcial de la config."""

    max_por_hora: int | None = None
    max_por_dia: int | None = None
    max_por_semana: int | None = None
    min_intervalo_seg: int | None = None
    strict: bool | None = None
