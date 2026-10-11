"""
Modelos de base de datos del modulo oficios.

Arquitectura en 2 capas:
- CORE: objetos_servicio (polimorfico). Aplica a TODOS los oficios.
- VERTICAL MECANICA: vehiculos, mecanica_categorias_servicio,
  mecanica_repuestos. Especifico, se replica a otros oficios.

`objetos_servicio` es el punto de extension: en mecanica es un auto,
en gasfiteria sera una propiedad, en jardineria un jardin.

En esta fase (M1a) solo se definen los modelos base:
- objetos_servicio
- vehiculos (satelite 1:1)
- mecanica_categorias_servicio (catalogo)
- mecanica_repuestos (catalogo)

Las tablas de ordenes_trabajo, orden_items, etc. se agregaran en M2.
"""
from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    Date,
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
class TipoObjetoServicio(str, Enum):
    """Tipo de objeto sobre el que se presta un servicio.

    En mecanica es VEHICULO. En otros oficios seran PROPIEDAD (gasfiteria),
    JARDIN (jardineria), etc. Es el punto de extension polimorfico.
    """

    VEHICULO = "vehiculo"
    PROPIEDAD = "propiedad"
    JARDIN = "jardin"
    OTRO = "otro"


class TipoVehiculo(str, Enum):
    """Tipo de vehiculo (capa vertical mecanica)."""

    SEDAN = "sedan"
    SUV = "suv"
    CAMIONETA = "camioneta"
    MOTO = "moto"
    CAMION = "camion"
    OTRO = "otro"


# =========================================================
# CORE: Objeto de servicio (polimorfico)
# =========================================================
class ObjetoServicio(TimestampMixin, SoftDeleteMixin, Base):
    """Sujeto sobre el que se presta un servicio.

    En mecanica: un vehiculo. En gasfiteria: una propiedad. En jardineria:
    un jardin. Es la abstraccion clave que permite reutilizar ordenes,
    garantias, recordatorios y todo el core para CUALQUIER oficio.

    El campo `metadata_extra` guarda campos libres por tipo (JSONB), asi
    agregar nuevos tipos no requiere migracion.
    """

    __tablename__ = "objetos_servicio"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    tipo: Mapped[TipoObjetoServicio] = mapped_column(
        SQLEnum(
            TipoObjetoServicio,
            name="tipo_objeto_servicio",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        index=True,
    )
    propietario_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Usuario dueno del objeto (puede tener N)",
    )
    alias: Mapped[str | None] = mapped_column(
        String(80),
        nullable=True,
        comment="Nombre amigable: 'Mi auto', 'Casa playa'",
    )
    notas: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Notas libres del propietario",
    )
    metadata_extra: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Campos especificos por tipo (extension sin migracion)",
    )

    # Relaciones
    vehiculo: Mapped["Vehiculo | None"] = relationship(
        back_populates="objeto_servicio",
        cascade="all, delete-orphan",
        uselist=False,
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<ObjetoServicio(id={self.id}, tipo={self.tipo.value}, "
            f"activo={self.activo})>"
        )


# =========================================================
# VERTICAL MECANICA: Vehiculo (satelite 1:1)
# =========================================================
class Vehiculo(TimestampMixin, Base):
    """Datos especificos de un vehiculo (mecanica).

    Relacion 1:1 con `objetos_servicio`. Cuando se crea un objeto de tipo
    VEHICULO, se crea automaticamente su fila en `vehiculos`.

    La patente es unica en todo el sistema: un vehiculo no puede existir
    dos veces (evita duplicacion por parte del cliente).
    """

    __tablename__ = "vehiculos"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    objeto_servicio_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("objetos_servicio.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )

    # Identificacion
    patente: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        unique=True,
        index=True,
        comment="Patente unica en el sistema (formato chileno o extranjero)",
    )
    vin: Mapped[str | None] = mapped_column(
        String(17),
        nullable=True,
        comment="Vehicle Identification Number (17 chars)",
    )

    # Marca / modelo / anio
    marca: Mapped[str] = mapped_column(String(50), nullable=False)
    modelo: Mapped[str] = mapped_column(String(50), nullable=False)
    anio: Mapped[int] = mapped_column(Integer, nullable=False)
    color: Mapped[str | None] = mapped_column(String(30), nullable=True)
    tipo_vehiculo: Mapped[TipoVehiculo] = mapped_column(
        SQLEnum(
            TipoVehiculo,
            name="tipo_vehiculo",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=TipoVehiculo.OTRO,
        server_default=TipoVehiculo.OTRO.value,
    )

    # Estado / kilometraje
    kilometraje_actual: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
    fecha_ultima_revision: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )

    # Relaciones
    objeto_servicio: Mapped[ObjetoServicio] = relationship(
        back_populates="vehiculo"
    )

    def __repr__(self) -> str:
        return (
            f"<Vehiculo(patente={self.patente}, marca={self.marca}, "
            f"modelo={self.modelo})>"
        )


# =========================================================
# VERTICAL MECANICA: Categoria de servicio (catalogo admin)
# =========================================================
class MecanicaCategoriaServicio(TimestampMixin, SoftDeleteMixin, Base):
    """Categoria de servicios mecanicos (Frenos, Motor, etc.).

    Se usa para agrupar visualmente en la UI. Admin-managed.
    """

    __tablename__ = "mecanica_categorias_servicio"

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
    icono: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Nombre del icono Material",
    )
    color_hex: Mapped[str | None] = mapped_column(
        String(7),
        nullable=True,
        comment="Color en formato #RRGGBB",
    )
    orden: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    def __repr__(self) -> str:
        return f"<MecanicaCategoriaServicio(slug={self.slug})>"


# =========================================================
# VERTICAL MECANICA: Repuesto (catalogo)
# =========================================================
class MecanicaRepuesto(TimestampMixin, SoftDeleteMixin, Base):
    """Catalogo de repuestos mecanicos (referencia para presupuestos).

    En MVP es un catalogo base. El mecanico puede elegir de aqui o
    agregar items manuales en el presupuesto de la orden.

    Si `categoria_id` es NULL, es un repuesto generico. Si apunta a una
    categoria, se agrupa visualmente.
    """

    __tablename__ = "mecanica_repuestos"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    nombre: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        index=True,
    )
    marca: Mapped[str | None] = mapped_column(
        String(80),
        nullable=True,
        comment="Marca del repuesto (ej: Bosch, Genuine Toyota)",
    )
    codigo_oem: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        index=True,
        comment="Codigo OEM / parte del fabricante",
    )
    categoria_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("mecanica_categorias_servicio.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    precio_referencia_clp: Mapped[Decimal | None] = mapped_column(
        Numeric(12, 2),
        nullable=True,
        comment="Precio referencial (el mecanico puede variar)",
    )
    unidad: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="unidad",
        server_default="unidad",
        comment="unidad, litro, juego, par, kit",
    )
    notas: Mapped[str | None] = mapped_column(Text, nullable=True)

    def __repr__(self) -> str:
        return f"<MecanicaRepuesto(nombre={self.nombre})>"
