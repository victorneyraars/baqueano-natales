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
    DateTime,
    Enum as SQLEnum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
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


# =========================================================
# CORE: Orden de trabajo (M2)
# =========================================================
class EstadoOrden(str, Enum):
    """Ciclo de vida de una orden de trabajo.

    Flujo principal:
        ingresado -> diagnosticando -> presupuestado -> aprobado
            -> en_proceso -> listo -> entregado

    Ramas:
        presupuestado -> rechazado (cliente rechaza)
        cualquier estado inicial -> cancelado
        entregado -> garantia (si el cliente reclama)
    """

    INGRESADO = "ingresado"
    DIAGNOSTICANDO = "diagnosticando"
    PRESUPUESTADO = "presupuestado"
    APROBADO = "aprobado"
    RECHAZADO = "rechazado"
    EN_PROCESO = "en_proceso"
    LISTO = "listo"
    ENTREGADO = "entregado"
    CANCELADO = "cancelado"
    GARANTIA = "garantia"


class PrioridadOrden(str, Enum):
    BAJA = "baja"
    NORMAL = "normal"
    ALTA = "alta"
    URGENTE = "urgente"


class TipoItemOrden(str, Enum):
    SERVICIO = "servicio"
    REPUESTO = "repuesto"
    MANO_OBRA = "mano_obra"
    OTRO = "otro"


class TipoEventoHistorial(str, Enum):
    ESTADO_CAMBIO = "estado_cambio"
    COMENTARIO = "comentario"
    FOTO = "foto"
    PRESUPUESTO = "presupuesto"
    APROBACION = "aprobacion"
    RECHAZO = "rechazo"
    GARANTIA = "garantia"


class OrdenTrabajo(TimestampMixin, Base):
    """Orden de trabajo entre un cliente y un prestador.

    Es el objeto central del modulo oficios. Une:
    - cliente (usuario)
    - prestador (taller/oficio)
    - objeto_servicio (vehiculo, propiedad, etc.)

    Flujo: cliente agenda -> prestador diagnostica -> presupuesto ->
    cliente aprueba -> prestador ejecuta -> entrega.

    Los cambios de estado se registran en `orden_historial` (append-only).
    """

    __tablename__ = "ordenes_trabajo"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    numero: Mapped[str] = mapped_column(
        String(20),
        unique=True,
        nullable=False,
        index=True,
        comment="Formato OT-YYYY-NNNN",
    )
    cliente_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    prestador_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("prestadores.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    objeto_servicio_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("objetos_servicio.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    estado: Mapped[EstadoOrden] = mapped_column(
        SQLEnum(
            EstadoOrden,
            name="estado_orden",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=EstadoOrden.INGRESADO,
        server_default=EstadoOrden.INGRESADO.value,
        index=True,
    )
    prioridad: Mapped[PrioridadOrden] = mapped_column(
        SQLEnum(
            PrioridadOrden,
            name="prioridad_orden",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=PrioridadOrden.NORMAL,
        server_default=PrioridadOrden.NORMAL.value,
    )

    diagnostico_inicial: Mapped[str | None] = mapped_column(Text, nullable=True)
    notas_internas: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Notas del prestador (no visibles al cliente)",
    )
    notas_cliente: Mapped[str | None] = mapped_column(Text, nullable=True)

    fecha_ingreso: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    fecha_estimada_entrega: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    fecha_entrega_real: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    km_ingreso: Mapped[int | None] = mapped_column(Integer, nullable=True)
    km_salida: Mapped[int | None] = mapped_column(Integer, nullable=True)

    total_presupuesto: Mapped[Decimal] = mapped_column(
        Numeric(12, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
        comment="Suma de todos los items",
    )
    total_aprobado: Mapped[Decimal] = mapped_column(
        Numeric(12, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
        comment="Suma de items aprobados por el cliente",
    )

    # Relaciones
    cliente: Mapped["Usuario"] = relationship(
        foreign_keys=[cliente_id],
        lazy="selectin",
    )
    prestador: Mapped["Prestador"] = relationship(
        foreign_keys=[prestador_id],
        lazy="selectin",
    )
    objeto_servicio: Mapped["ObjetoServicio"] = relationship(lazy="selectin")
    items: Mapped[list["OrdenItem"]] = relationship(
        back_populates="orden",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="OrdenItem.orden_display, OrdenItem.created_at",
    )
    historial: Mapped[list["OrdenHistorial"]] = relationship(
        back_populates="orden",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="OrdenHistorial.created_at",
    )

    def __repr__(self) -> str:
        return (
            f"<OrdenTrabajo(numero={self.numero}, "
            f"estado={self.estado.value})>"
        )


class OrdenItem(TimestampMixin, Base):
    """Item del presupuesto de una orden.

    Puede ser:
    - servicio (mano de obra con descripcion)
    - repuesto (pieza)
    - mano_obra (cargo separado)
    - otro (cualquier otra cosa)

    El cliente puede aprobar/rechazar cada item individualmente.
    `aprobado=None` significa pendiente. True/False son decisiones.
    """

    __tablename__ = "orden_items"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    orden_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("ordenes_trabajo.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tipo: Mapped[TipoItemOrden] = mapped_column(
        SQLEnum(
            TipoItemOrden,
            name="tipo_item_orden",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=TipoItemOrden.SERVICIO,
        server_default=TipoItemOrden.SERVICIO.value,
    )
    descripcion: Mapped[str] = mapped_column(String(255), nullable=False)
    cantidad: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        default=Decimal("1.00"),
        server_default="1.00",
    )
    precio_unitario: Mapped[Decimal] = mapped_column(
        Numeric(12, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    subtotal: Mapped[Decimal] = mapped_column(
        Numeric(12, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
        comment="cantidad * precio_unitario (calculado)",
    )
    aprobado: Mapped[bool | None] = mapped_column(
        Boolean,
        nullable=True,
        comment="None=pendiente, True=aprobado, False=rechazado",
    )
    orden_display: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
        comment="Para ordenar visualmente",
    )

    orden: Mapped[OrdenTrabajo] = relationship(back_populates="items")

    def __repr__(self) -> str:
        return f"<OrdenItem(desc={self.descripcion[:30]}, subtotal={self.subtotal})>"


class OrdenHistorial(TimestampMixin, Base):
    """Evento del timeline de una orden (append-only).

    NUNCA se modifica ni se borra. Es la fuente de verdad.
    Registra:
    - Cambios de estado (con estado_anterior y estado_nuevo)
    - Comentarios (contenido JSONB con texto)
    - Aprobaciones / rechazos del cliente
    - Adjuntos (contenido JSONB con URL de foto)
    """

    __tablename__ = "orden_historial"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    orden_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("ordenes_trabajo.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tipo: Mapped[TipoEventoHistorial] = mapped_column(
        SQLEnum(
            TipoEventoHistorial,
            name="tipo_evento_historial",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
    )
    estado_anterior: Mapped[str | None] = mapped_column(String(30), nullable=True)
    estado_nuevo: Mapped[str | None] = mapped_column(String(30), nullable=True)
    usuario_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        nullable=True,
        comment="Quien genero el evento (NULL = sistema)",
    )
    contenido: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Datos libres: texto, motivo, url de foto, etc.",
    )

    orden: Mapped[OrdenTrabajo] = relationship(back_populates="historial")

    def __repr__(self) -> str:
        return f"<OrdenHistorial(orden_id={self.orden_id}, tipo={self.tipo.value})>"


# =========================================================
# M3: Turnos (agenda cliente-prestador)
# =========================================================
class EstadoTurno(str, Enum):
    """Ciclo de vida de un turno agendado.

    Flujo principal:
        pendiente -> confirmado -> en_curso -> completado

    Ramas:
        pendiente -> cancelado (cliente o prestador cancela)
        pendiente -> rechazado (prestador rechaza)
        confirmado -> no_asistio (cliente no se presento)
        confirmado -> cancelado (cancelacion tardia)
    """

    PENDIENTE = "pendiente"
    CONFIRMADO = "confirmado"
    EN_CURSO = "en_curso"
    COMPLETADO = "completado"
    CANCELADO = "cancelado"
    RECHAZADO = "rechazado"
    NO_ASISTIO = "no_asistio"


class Turno(TimestampMixin, Base):
    """Turno agendado entre un cliente y un prestador.

    El cliente reserva un horario con un prestador para atender un
    objeto_servicio (vehiculo). El prestador confirma o rechaza.
    Cuando se atiende, puede generar una orden de trabajo vinculada
    (campo `orden_id`).
    """

    __tablename__ = "turnos"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    cliente_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    prestador_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("prestadores.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    objeto_servicio_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("objetos_servicio.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    fecha_inicio: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )
    duracion_min: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=30,
        server_default="30",
        comment="Duracion estimada en minutos",
    )

    estado: Mapped[EstadoTurno] = mapped_column(
        SQLEnum(
            EstadoTurno,
            name="estado_turno",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=EstadoTurno.PENDIENTE,
        server_default=EstadoTurno.PENDIENTE.value,
        index=True,
    )

    motivo: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Motivo de la visita (ej: 'Cambio de aceite')",
    )
    notas_cliente: Mapped[str | None] = mapped_column(Text, nullable=True)
    notas_prestador: Mapped[str | None] = mapped_column(Text, nullable=True)

    orden_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("ordenes_trabajo.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Orden generada al atender el turno (opcional)",
    )

    # Relaciones (opcionales, para hidratar)
    objeto_servicio: Mapped["ObjetoServicio"] = relationship(lazy="selectin")
    orden: Mapped["OrdenTrabajo | None"] = relationship(lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<Turno(id={self.id}, estado={self.estado.value}, "
            f"fecha={self.fecha_inicio})>"
        )


# =========================================================
# M4: Garantias y Recordatorios
# =========================================================
class TipoGarantia(str, Enum):
    MANO_OBRA = "mano_obra"
    REPUESTO = "repuesto"
    COMPLETO = "completo"


class TipoRecordatorio(str, Enum):
    KM = "km"
    FECHA = "fecha"
    EVENTO = "evento"


class Garantia(TimestampMixin, SoftDeleteMixin, Base):
    """Garantia asociada a una orden entregada.

    Se genera (automatica o manualmente) cuando una orden pasa a ENTREGADO.
    El cliente puede reclamar dentro de la ventana fecha_inicio..fecha_fin.
    """

    __tablename__ = "garantias"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    orden_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("ordenes_trabajo.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tipo: Mapped[TipoGarantia] = mapped_column(
        SQLEnum(
            TipoGarantia,
            name="tipo_garantia",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=TipoGarantia.COMPLETO,
        server_default=TipoGarantia.COMPLETO.value,
    )
    duracion_dias: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=30,
        server_default="30",
    )
    fecha_inicio: Mapped[date] = mapped_column(Date, nullable=False)
    fecha_fin: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    cobertura: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Que cubre la garantia",
    )
    condiciones: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Que NO cubre la garantia",
    )

    # Relaciones
    orden: Mapped["OrdenTrabajo"] = relationship(lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<Garantia(id={self.id}, orden_id={self.orden_id}, "
            f"fin={self.fecha_fin})>"
        )


class Recordatorio(TimestampMixin, SoftDeleteMixin, Base):
    """Recordatorio automatico por km/fecha para un objeto_servicio.

    El worker diario revisa recordatorios pendientes y envia notificacion
    al propietario cuando se cumple la condicion.

    Condicion (JSONB):
    - tipo=km: {"km_umbral": 5000} (comparar contra Vehiculo.kilometraje_actual)
    - tipo=fecha: {"fecha": "2027-03-15"}
    - tipo=evento: {descripcion libre}
    """

    __tablename__ = "recordatorios"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    objeto_servicio_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("objetos_servicio.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tipo: Mapped[TipoRecordatorio] = mapped_column(
        SQLEnum(
            TipoRecordatorio,
            name="tipo_recordatorio",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
    )
    condicion: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        comment="Datos de la condicion (km_umbral o fecha)",
    )
    mensaje: Mapped[str] = mapped_column(String(255), nullable=False)
    enviado: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        index=True,
    )
    fecha_envio: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relaciones
    objeto_servicio: Mapped["ObjetoServicio"] = relationship(lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<Recordatorio(id={self.id}, tipo={self.tipo.value}, "
            f"enviado={self.enviado})>"
        )
