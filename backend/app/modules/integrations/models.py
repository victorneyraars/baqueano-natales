"""Modelo de telemetría para las consultas a Boostr (RUT y Patentes).

Persiste cada consulta (API o caché) para:
- Analytics de capacity planning (¿vamos a necesitar plan mayor?).
- Proyección de consumo mensual.
- Auditoría de consultas (quién, cuándo, qué resultado).
"""
from uuid import UUID, uuid4

from sqlalchemy import Boolean, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.core.mixins import TimestampMixin


class ApiUsageEvent(TimestampMixin, Base):
    """Evento de consulta a una API externa (Boostr)."""

    __tablename__ = "api_usage_events"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    api: Mapped[str] = mapped_column(String(20), index=True)
    input_value: Mapped[str] = mapped_column(String(50))
    was_cached: Mapped[bool] = mapped_column(Boolean, default=False)
    remaining: Mapped[int | None] = mapped_column(Integer, nullable=True)
    api_limit: Mapped[int | None] = mapped_column(Integer, nullable=True)
    reset_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    error_message: Mapped[str | None] = mapped_column(String(255), nullable=True)
