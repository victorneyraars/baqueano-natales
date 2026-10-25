"""Modelos del módulo admin."""
from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.core.db import Base
from app.core.mixins import TimestampMixin

class Configuracion(TimestampMixin, Base):
    __tablename__ = "configuraciones"
    clave: Mapped[str] = mapped_column(String(100), primary_key=True)
    valor: Mapped[str] = mapped_column(Text, nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text, nullable=True)
