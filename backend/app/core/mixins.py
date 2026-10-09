"""
Mixins reutilizables para modelos SQLAlchemy.

Los mixins encapsulan patrones comunes que se repiten en cada módulo:
- TimestampMixin: created_at, updated_at
- SoftDeleteMixin: activo (borrado lógico)

NO incluyen estado/verificación porque cada módulo tiene su propio
Enum de estados y name único en Postgres. Eso se declara en cada modelo.

Uso:
    from app.core.mixins import SoftDeleteMixin, TimestampMixin

    class Prestador(TimestampMixin, SoftDeleteMixin, Base):
        __tablename__ = "prestadores"
        # ...columnas específicas...
"""
from datetime import datetime

from sqlalchemy import Boolean, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column


class TimestampMixin:
    """
    Agrega created_at y updated_at.

    Ambos usan `server_default=func.now()` para que la DB los llene
    aunque se inserte desde SQL puro. `updated_at` se actualiza
    automáticamente con `onupdate`.
    """

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class SoftDeleteMixin:
    """
    Agrega `activo` (bool) para borrado lógico.

    - default=True y server_default='true': los nuevos registros nacen activos.
    - Para "eliminar", se pone `activo=False` en lugar de DELETE.
    - Los queries deben filtrar por `activo.is_(True)`.
    """

    activo: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )