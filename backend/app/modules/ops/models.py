"""Modelos del modulo ops (Fase 2: audit log de acciones admin).

Append-only: cada accion del admin (trigger, cancel, etc.) genera una
fila inmutable. Es la fuente de verdad para:
- Auditoria: quien hizo que, cuando, con que resultado.
- Historial UI: pantalla de Ops muestra las ultimas N acciones.
- Live streaming (Fase 3): SSE escucha esta tabla.

Regla: nunca se actualiza ni se borra. Si hay que corregir, se agrega
otra fila.
"""
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class OpsAuditLog(Base):
    """Registro append-only de acciones del Ops Dashboard."""

    __tablename__ = "ops_audit_log"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid4,
    )

    # --- Quien ---
    user_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        index=True, nullable=True,
    )
    user_email: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # --- Que ---
    action: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    target: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # --- Resultado ---
    status: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    # --- Detalle ---
    payload: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    result: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    duration_ms: Mapped[int | None] = mapped_column(nullable=True)

    # --- Contexto tecnico ---
    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # --- Timestamp ---
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True,
    )