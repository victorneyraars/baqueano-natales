"""
Modelos de base de datos del módulo prestadores.

Un prestador es un profesional de un oficio (mecánico, gasfiter,
electricista, etc.). A diferencia de un socio (movilidad, en el mapa),
el prestador se encuentra por CATEGORÍA y se contacta por chat o
WhatsApp — no hay matching en tiempo real.

Modelo:
- CategoriaOficio: categoría admin-managed (editable sin release).
- Prestador: perfil del oficio (uno o varios por usuario).
- PrestadorServicio: catálogo de servicios con precios orientativos.
- FotoTrabajo: galería de trabajos (tabla relacional, no JSON).

Reusa:
- app.core.mixins.TimestampMixin + SoftDeleteMixin
"""
from datetime import datetime
from decimal import Decimal
from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum as SQLEnum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base
from app.core.mixins import SoftDeleteMixin, TimestampMixin


# =========================================================
# Enums
# =========================================================
class EstadoPrestador(str, Enum):
    """
    Ciclo de vida de un prestador.

    Flujo típico (igual que comercios):
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
# Categoría de oficio (admin-managed)
# =========================================================
class CategoriaOficio(TimestampMixin, SoftDeleteMixin, Base):
    """
    Categoría de oficio (mecánica, gasfitería, electricidad...).

    Se desactivan (`activo=False`) en lugar de borrarse para preservar
    la integridad referencial y el historial.
    """

    __tablename__ = "categorias_oficio"

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
        comment="Nombre del ícono Material (ej: 'build')",
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

    def __repr__(self) -> str:
        return (
            f"<CategoriaOficio(id={self.id}, slug={self.slug}, "
            f"activo={self.activo})>"
        )


# =========================================================
# Prestador (perfil del oficio)
# =========================================================
class Prestador(TimestampMixin, SoftDeleteMixin, Base):
    """
    Prestador de servicios / oficios.

    Puede tener varios prestadores un mismo usuario (ej: una persona
    con perfil de mecánico Y gasfiter). El campo `usuario_id` apunta
    al dueño de la cuenta que administra el perfil.

    Los `especialidades`, `datos_extra` y `redes_sociales` son JSONB nativo:
    - `especialidades`: lista de strings específicos del oficio
      (ej: para mecánica: ["frenos", "motor", "chapa", "electricidad_auto"])
    - `datos_extra`: campos variables por categoría
      (ej: para mecánica: {"acepta_auxilio_ruta": true, "marcas": ["Toyota", "Ford"]})
    - `redes_sociales`: links a redes
      (ej: {"instagram": "https://...", "facebook": "https://..."})
    """

    __tablename__ = "prestadores"

    # -----------------------------------------------------
    # Identificadores
    # -----------------------------------------------------
    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    usuario_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    categoria_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("categorias_oficio.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    # -----------------------------------------------------
    # Identidad
    # -----------------------------------------------------
    nombre: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        comment="Nombre o razón social",
    )
    slug: Mapped[str] = mapped_column(
        String(180),
        unique=True,
        nullable=False,
        index=True,
    )
    descripcion: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Qué hace, experiencia, especialidades generales",
    )
    anios_experiencia: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Años de experiencia en el oficio",
    )

    # -----------------------------------------------------
    # Contacto
    # -----------------------------------------------------
    telefono: Mapped[str | None] = mapped_column(String(20), nullable=True)
    whatsapp: Mapped[str | None] = mapped_column(String(20), nullable=True)
    whatsapp_mensaje: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Mensaje pre-armado para el botón WhatsApp",
    )
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    sitio_web: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # -----------------------------------------------------
    # Ubicación
    # -----------------------------------------------------
    comuna: Mapped[str] = mapped_column(
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
    direccion: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Dirección del local (opcional si solo atiende a domicilio)",
    )
    latitud: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 7),
        nullable=True,
    )
    longitud: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 7),
        nullable=True,
    )
    radio_cobertura_km: Mapped[Decimal | None] = mapped_column(
        Numeric(4, 2),
        nullable=True,
        comment="Hasta dónde presta servicio a domicilio",
    )

    # -----------------------------------------------------
    # Modalidad de atención
    # -----------------------------------------------------
    atiende_domicilio: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="Va al domicilio del cliente",
    )
    atiende_local: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        comment="Cliente puede ir a su local/taller",
    )
    atiende_emergencias: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="24/7, urgencias, auxilio en ruta",
    )
    horario_descripcion: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Texto libre: 'Lun-Vie 9-18h, Sáb 9-13h'",
    )

    # -----------------------------------------------------
    # Media
    # -----------------------------------------------------
    foto_url: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
        comment="Foto de perfil / logo",
    )
    foto_portada_url: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
        comment="Banner / portada del perfil",
    )

    # -----------------------------------------------------
    # Redes sociales (JSONB)
    # -----------------------------------------------------
    redes_sociales: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Links: {instagram, facebook, tiktok, youtube, ...}",
    )

    # -----------------------------------------------------
    # Estado y verificación
    # -----------------------------------------------------
    estado: Mapped[EstadoPrestador] = mapped_column(
        SQLEnum(
            EstadoPrestador,
            name="estado_prestador",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=EstadoPrestador.BORRADOR,
        server_default=EstadoPrestador.BORRADOR.value,
        index=True,
    )
    motivo_rechazo: Mapped[str | None] = mapped_column(Text, nullable=True)
    destacado: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    # -----------------------------------------------------
    # Verificación de identidad (KYC Didit)
    # -----------------------------------------------------
    verificado: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="Identidad verificada vía KYC (sello de confianza)",
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
    # Especialidades y datos variables (JSONB nativo)
    # -----------------------------------------------------
    especialidades: Mapped[list | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Lista de especialidades dentro de la categoría",
    )
    datos_extra: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Campos específicos por categoría",
    )

    # -----------------------------------------------------
    # Stats (denormalizadas, se actualizan con reviews)
    # -----------------------------------------------------
    calificacion_promedio: Mapped[Decimal] = mapped_column(
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
    # Relaciones
    # -----------------------------------------------------
    categoria: Mapped["CategoriaOficio"] = relationship(lazy="selectin")
    servicios: Mapped[list["PrestadorServicio"]] = relationship(
        back_populates="prestador",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="PrestadorServicio.orden, PrestadorServicio.nombre",
    )
    reviews: Mapped[list["Review"]] = relationship(
        back_populates="prestador",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="Review.created_at.desc()",
    )
    fotos_trabajos: Mapped[list["FotoTrabajo"]] = relationship(
        back_populates="prestador",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="FotoTrabajo.orden",
    )

    def __repr__(self) -> str:
        return (
            f"<Prestador(id={self.id}, slug={self.slug}, "
            f"estado={self.estado.value}, activo={self.activo})>"
        )


# =========================================================
# Servicios del prestador (catálogo con precios)
# =========================================================
class PrestadorServicio(TimestampMixin, Base):
    """
    Servicio ofrecido por un prestador, con precio orientativo.

    Inspirado en Thumbtack / YourMechanic / Fixd:
    - `nombre`: acción corta y clara (ej: "Cambio de aceite y filtro")
    - `categoria_servicio`: para agrupar visualmente en la UI
      (ej: "Mantenimiento", "Frenos", "Motor", "Suspensión")
    - `precio_desde_clp` / `precio_hasta_clp`: rango orientativo.
      Si ambos son null → "Consultar precio"
    - `duracion_estimada_min`: cuánto tarda (transparencia)
    - `garantia_dias`: sello de confianza (diferenciador industrial)
    - `destacado`: el servicio estrella del prestador (ej: cambio de aceite
      es el "hook" para captar clientes que después vuelven por más)

    Se replican para TODOS los oficios (gasfitería, electricidad, etc.).
    """

    __tablename__ = "prestador_servicios"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    prestador_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("prestadores.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    nombre: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        comment="Ej: 'Cambio de aceite y filtro'",
    )
    descripcion: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Qué incluye, detalles",
    )
    categoria_servicio: Mapped[str | None] = mapped_column(
        String(80),
        nullable=True,
        comment="Ej: 'Mantenimiento', 'Frenos', 'Motor'",
    )

    # Precios orientativos (en CLP). Null = "Consultar"
    precio_desde_clp: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )
    precio_hasta_clp: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )
    duracion_estimada_min: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Duración estimada en minutos",
    )
    garantia_dias: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Días de garantía del trabajo",
    )

    destacado: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="Servicio estrella / hook comercial",
    )
    activo: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )
    orden: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    # Relaciones
    prestador: Mapped[Prestador] = relationship(back_populates="servicios")

    def __repr__(self) -> str:
        return f"<PrestadorServicio(nombre={self.nombre})>"


# =========================================================
# Fotos de trabajos
# =========================================================
class FotoTrabajo(TimestampMixin, Base):
    """
    Foto de un trabajo anterior. Parte de la galería del prestador.

    A diferencia del legacy (JSON string), esto es tabla relacional:
    - Se puede ordenar, filtrar, paginar
    - Se pueden agregar campos (descripción, fecha del trabajo, etc.)
    - Se puede relacionar con `solicitudes_servicio` a futuro
    """

    __tablename__ = "fotos_trabajo"
    __table_args__ = (
        UniqueConstraint(
            "prestador_id",
            "orden",
            name="uq_foto_trabajo_prestador_orden",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    prestador_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("prestadores.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    url: Mapped[str] = mapped_column(String(500), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )
    orden: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    # Relaciones
    prestador: Mapped[Prestador] = relationship(back_populates="fotos_trabajos")

    def __repr__(self) -> str:
        return (
            f"<FotoTrabajo(prestador_id={self.prestador_id}, "
            f"orden={self.orden})>"
        )

# =========================================================
# M6: Reviews (calificaciones del cliente al prestador)
# =========================================================
class Review(TimestampMixin, SoftDeleteMixin, Base):
    """Calificacion de un cliente a un prestador, ligada a UNA orden.

    Reglas de negocio:
    - Una sola review por orden (UniqueConstraint en orden_id).
    - Solo el cliente dueno de la orden puede calificar.
    - Solo se puede calificar si la orden esta ENTREGADO.
    - Rating 1-5 (CheckConstraint).
    - El prestador puede responder una vez (respuesta_prestador +
      respuesta_en). No editable despues.
    - Los denormalizados calificacion_promedio + total_resenas del
      Prestador se recalculan en el service al crear/editar/borrar.
    """

    __tablename__ = "reviews"
    __table_args__ = (
        CheckConstraint(
            "rating >= 1 AND rating <= 5",
            name="ck_review_rating",
        ),
        UniqueConstraint("orden_id", name="uq_review_orden"),
    )

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    prestador_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("prestadores.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    cliente_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    orden_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("ordenes_trabajo.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Una sola review por orden (UNIQUE)",
    )

    rating: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="1 a 5 estrellas",
    )
    comentario: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Respuesta del prestador (una sola, no editable)
    respuesta_prestador: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
    respuesta_en: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relaciones
    prestador: Mapped[Prestador] = relationship(back_populates="reviews")

    def __repr__(self) -> str:
        return (
            f"<Review(prestador_id={self.prestador_id}, "
            f"rating={self.rating})>"
        )
