"""
Modelos de base de datos del módulo comercios.

Incluye:
- CategoriaComercio: categorías administradas por admin.
- Comercio: entidad principal (multi-tenant: un usuario puede tener varios).
- HorarioComercio: franjas horarias por día (soporta horario partido).

Convenciones alineadas con `app.modules.auth.models`:
- UUID como PK.
- Enums con `values_callable` para usar los `.value` en la DB.
- Timestamps con `server_default=func.now()` y `onupdate=func.now()`.
- Soft delete vía campo `activo`.
- `lazy="selectin"` en relaciones para compatibilidad con async.
"""
from datetime import datetime, time
from decimal import Decimal
from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum as SQLEnum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    Time,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


# =========================================================
# Enums
# =========================================================
class EstadoComercio(str, Enum):
    """
    Ciclo de vida de un comercio.

    Flujo típico:
        borrador → pendiente → verificado
                       ↓
                   rechazado → (edita) → pendiente
        verificado → suspendido (por admin) → verificado
    """

    BORRADOR = "borrador"
    PENDIENTE = "pendiente"
    VERIFICADO = "verificado"
    RECHAZADO = "rechazado"
    SUSPENDIDO = "suspendido"


# =========================================================
# Categoría de comercio (admin-managed)
# =========================================================
class CategoriaComercio(Base):
    """
    Categoría de comercio. Gestionada exclusivamente por admin.

    Ejemplos: Restaurante, Café, Panadería, Minimarket, Farmacia.

    Se desactivan (activo=False) en lugar de borrarse para preservar
    la integridad referencial y el historial.
    """

    __tablename__ = "categorias_comercio"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    nombre: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
    )
    slug: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
        index=True,
    )
    descripcion: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Visual (editable desde admin)
    icono: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Nombre del ícono Material (ej: 'restaurant')",
    )
    color_hex: Mapped[str | None] = mapped_column(
        String(7),
        nullable=True,
        comment="Color en formato #RRGGBB",
    )

    # Orden de aparición en listados públicos
    orden: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    activo: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )

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

    def __repr__(self) -> str:
        return f"<CategoriaComercio(id={self.id}, slug={self.slug}, activo={self.activo})>"


# =========================================================
# Comercio (entidad principal, multi-tenant)
# =========================================================
class Comercio(Base):
    """
    Comercio perteneciente a un usuario.

    Multi-tenant: un usuario puede tener varios comercios.

    La verificación sigue el flujo de `EstadoComercio`. Solo los
    comercios en estado VERIFICADO son visibles públicamente.
    """

    __tablename__ = "comercios"

    # -----------------------------------------------------
    # Identificadores
    # -----------------------------------------------------
    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    propietario_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    categoria_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("categorias_comercio.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
        comment="Se asigna al verificar (o la elige el dueño al crear)",
    )

    # -----------------------------------------------------
    # Identidad
    # -----------------------------------------------------
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    slug: Mapped[str] = mapped_column(
        String(180),
        unique=True,
        nullable=False,
        index=True,
    )
    descripcion_corta: Mapped[str | None] = mapped_column(
        String(300),
        nullable=True,
        comment="Se muestra en el listado",
    )
    descripcion_larga: Mapped[str | None] = mapped_column(Text, nullable=True)

    # -----------------------------------------------------
    # Contacto
    # -----------------------------------------------------
    telefono: Mapped[str | None] = mapped_column(String(20), nullable=True)
    whatsapp: Mapped[str | None] = mapped_column(String(20), nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    sitio_web: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # -----------------------------------------------------
    # Ubicación
    # -----------------------------------------------------
    direccion: Mapped[str] = mapped_column(String(255), nullable=False)
    ciudad: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        default="Puerto Natales",
        server_default="Puerto Natales",
    )
    region: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        default="Magallanes",
        server_default="Magallanes",
    )
    latitud: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 7),
        nullable=True,
        comment="Precisión ~1cm",
    )
    longitud: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 7),
        nullable=True,
    )
    referencia: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Ej: 'frente a la plaza'",
    )

    # -----------------------------------------------------
    # Media
    # -----------------------------------------------------
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    portada_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # -----------------------------------------------------
    # Estado y verificación
    # -----------------------------------------------------
    estado: Mapped[EstadoComercio] = mapped_column(
        SQLEnum(
            EstadoComercio,
            name="estado_comercio",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=EstadoComercio.BORRADOR,
        server_default=EstadoComercio.BORRADOR.value,
        index=True,
    )
    motivo_rechazo: Mapped[str | None] = mapped_column(Text, nullable=True)
    destacado: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )
    verificado_en: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    verificado_por_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        nullable=True,
    )

    # -----------------------------------------------------
    # Configuración de delivery
    # -----------------------------------------------------
    acepta_delivery: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )
    acepta_retiro: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )
    costo_envio_clp: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
        comment="En pesos chilenos",
    )
    pedido_minimo_clp: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
    radio_entrega_km: Mapped[Decimal | None] = mapped_column(
        Numeric(4, 2),
        nullable=True,
    )
    tiempo_preparacion_min: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )

    # -----------------------------------------------------
    # Stats (calculadas, se actualizan por workers/reseñas futuras)
    # -----------------------------------------------------
    rating_promedio: Mapped[Decimal] = mapped_column(
        Numeric(3, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    total_resenas: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    # -----------------------------------------------------
    # Soft delete
    # -----------------------------------------------------
    activo: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )

    # -----------------------------------------------------
    # Metadata
    # -----------------------------------------------------
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

    # -----------------------------------------------------
    # Relaciones
    # -----------------------------------------------------
    # lazy="selectin" evita el error MissingGreenlet en async
    categoria: Mapped["CategoriaComercio | None"] = relationship(
        lazy="selectin",
    )
    horarios: Mapped[list["HorarioComercio"]] = relationship(
        back_populates="comercio",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="HorarioComercio.dia_semana, HorarioComercio.abre",
    )

    def __repr__(self) -> str:
        return (
            f"<Comercio(id={self.id}, slug={self.slug}, "
            f"estado={self.estado.value}, activo={self.activo})>"
        )


# =========================================================
# Horarios (multi-franja por día)
# =========================================================
class HorarioComercio(Base):
    """
    Franja horaria de un comercio.

    Soporta MÚLTIPLES franjas por día (ej: 12-15 y 19-23),
    típico en restaurantes chilenos.

    Si `cerrado=True`, el comercio está cerrado ese día
    (se ignora `abre`/`cierra`).
    """

    __tablename__ = "horarios_comercio"
    __table_args__ = (
        UniqueConstraint(
            "comercio_id",
            "dia_semana",
            "abre",
            name="uq_horario_comercio_dia_franja",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    comercio_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("comercios.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # 0=lunes, 1=martes, ..., 6=domingo
    dia_semana: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="0=lunes ... 6=domingo",
    )

    # Si `cerrado=True`, el día está cerrado y abre/cierra se ignoran
    cerrado: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )
    abre: Mapped[time | None] = mapped_column(Time, nullable=True)
    cierra: Mapped[time | None] = mapped_column(Time, nullable=True)

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

    # Relaciones
    comercio: Mapped[Comercio] = relationship(back_populates="horarios")

    def __repr__(self) -> str:
        return (
            f"<HorarioComercio(comercio_id={self.comercio_id}, "
            f"dia={self.dia_semana}, ab={self.abre}, ci={self.cierra}, "
            f"cerrado={self.cerrado})>"
        )