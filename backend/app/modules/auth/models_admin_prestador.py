"""
Modelo de relación N:N entre admins y prestadores.

Un admin puede tener asignados 0, 1 o N prestadores.
- Si tiene 0 y es_super_admin=True → ve TODO
- Si tiene 0 y es_super_admin=False → no ve nada (rol admin sin permisos)
- Si tiene 1+ → ve solo esos prestadores
"""
from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class AdminPrestador(Base):
    """Relación N:N entre admins y prestadores."""

    __tablename__ = "admin_prestadores"

    admin_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        primary_key=True,
    )
    prestador_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("prestadores.id", ondelete="CASCADE"),
        primary_key=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
