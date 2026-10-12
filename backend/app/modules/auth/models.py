"""
Modelos de base de datos del módulo auth.
Incluye la tabla de usuarios con roles y vinculación de métodos de auth.
"""
from datetime import datetime
from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum as SQLEnum,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class RolUsuario(str, Enum):
    """Roles disponibles en el sistema."""

    CLIENTE = "cliente"
    COMERCIO = "comercio"
    PRESTADOR = "prestador"
    ADMIN = "admin"


class Usuario(Base):
    """
    Usuario del sistema.
    Un usuario puede autenticarse por múltiples métodos (Google, WhatsApp OTP, SMS OTP)
    pero tiene una sola identidad en la base de datos.
    """

    __tablename__ = "usuarios"

    # Identificadores
    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    # Vinculación con Firebase (el UID del usuario en Firebase Auth)
    firebase_uid: Mapped[str] = mapped_column(
        String(128),
        unique=True,
        nullable=False,
        index=True,
    )

    # Datos personales
    email: Mapped[str | None] = mapped_column(
        String(255),
        unique=True,
        nullable=True,
        index=True,
    )
    phone: Mapped[str | None] = mapped_column(
        String(20),
        unique=True,
        nullable=True,
        index=True,
    )
    nombre: Mapped[str | None] = mapped_column(String(100), nullable=True)
    apellido: Mapped[str | None] = mapped_column(String(100), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Rol y estado
    rol: Mapped[RolUsuario] = mapped_column(
        SQLEnum(
            RolUsuario,
            name="rol_usuario",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=RolUsuario.CLIENTE,
        index=True,
    )
    verificado: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    activo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    # Métodos de auth vinculados
    tiene_google: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    tiene_whatsapp: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    tiene_sms: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    # Push notifications (FCM). Single-device: se sobreescribe en cada login.
    fcm_token: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Metadata
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
    ultimo_login: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    def __repr__(self) -> str:
        """Representación del usuario (sin datos sensibles completos)."""
        return f"<Usuario(id={self.id}, rol={self.rol.value}, activo={self.activo})>"
