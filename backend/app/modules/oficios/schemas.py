"""Schemas Pydantic del modulo oficios."""
from datetime import date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# =========================================================
# Objeto de servicio / Vehiculo
# =========================================================
class VehiculoBase(BaseModel):
    """Campos comunes de un vehiculo."""

    patente: str = Field(..., min_length=1, max_length=10, description="Patente unica")
    vin: str | None = Field(None, max_length=17)
    marca: str = Field(..., min_length=1, max_length=50)
    modelo: str = Field(..., min_length=1, max_length=50)
    anio: int = Field(..., ge=1900, le=2100)
    color: str | None = Field(None, max_length=30)
    tipo_vehiculo: str = Field("otro", description="sedan|suv|camioneta|moto|camion|otro")
    kilometraje_actual: int = Field(0, ge=0)
    fecha_ultima_revision: date | None = None


class VehiculoCreate(VehiculoBase):
    """Crear un vehiculo. Crea objeto_servicio + vehiculo en 1 llamada."""

    alias: str | None = Field(None, max_length=80, description="Alias: 'Mi auto'")
    notas: str | None = None


class VehiculoUpdate(BaseModel):
    """Actualizar un vehiculo. Todos los campos opcionales."""

    alias: str | None = Field(None, max_length=80)
    notas: str | None = None
    vin: str | None = Field(None, max_length=17)
    marca: str | None = Field(None, min_length=1, max_length=50)
    modelo: str | None = Field(None, min_length=1, max_length=50)
    anio: int | None = Field(None, ge=1900, le=2100)
    color: str | None = Field(None, max_length=30)
    tipo_vehiculo: str | None = None
    kilometraje_actual: int | None = Field(None, ge=0)
    fecha_ultima_revision: date | None = None


class VehiculoResponse(BaseModel):
    """Vehiculo completo (objeto_servicio + datos del vehiculo)."""

    model_config = ConfigDict(from_attributes=True)

    # Campos del objeto_servicio
    objeto_servicio_id: UUID
    alias: str | None
    notas: str | None
    activo: bool
    created_at: datetime
    updated_at: datetime

    # Campos del vehiculo
    patente: str
    vin: str | None
    marca: str
    modelo: str
    anio: int
    color: str | None
    tipo_vehiculo: str
    kilometraje_actual: int
    fecha_ultima_revision: date | None


# =========================================================
# Mecanica: Categorias de servicio
# =========================================================
class MecanicaCategoriaResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    nombre: str
    slug: str
    descripcion: str | None
    icono: str | None
    color_hex: str | None
    orden: int
    activo: bool


class MecanicaCategoriaCreate(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=100)
    slug: str | None = Field(None, max_length=100, description="Si None, se autogenera")
    descripcion: str | None = None
    icono: str | None = Field(None, max_length=100)
    color_hex: str | None = Field(None, max_length=7)
    orden: int = 0


class MecanicaCategoriaUpdate(BaseModel):
    nombre: str | None = Field(None, min_length=1, max_length=100)
    descripcion: str | None = None
    icono: str | None = Field(None, max_length=100)
    color_hex: str | None = Field(None, max_length=7)
    orden: int | None = None
    activo: bool | None = None


# =========================================================
# Mecanica: Repuestos
# =========================================================
class MecanicaRepuestoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    nombre: str
    marca: str | None
    codigo_oem: str | None
    categoria_id: UUID | None
    precio_referencia_clp: Decimal | None
    unidad: str
    notas: str | None
    activo: bool


class MecanicaRepuestoCreate(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=150)
    marca: str | None = Field(None, max_length=80)
    codigo_oem: str | None = Field(None, max_length=50)
    categoria_id: UUID | None = None
    precio_referencia_clp: Decimal | None = None
    unidad: str = Field("unidad", max_length=30)
    notas: str | None = None


class MecanicaRepuestoUpdate(BaseModel):
    nombre: str | None = Field(None, min_length=1, max_length=150)
    marca: str | None = Field(None, max_length=80)
    codigo_oem: str | None = Field(None, max_length=50)
    categoria_id: UUID | None = None
    precio_referencia_clp: Decimal | None = None
    unidad: str | None = Field(None, max_length=30)
    notas: str | None = None
    activo: bool | None = None


# =========================================================
# M2: Ordenes de trabajo
# =========================================================
class OrdenItemCreate(BaseModel):
    """Item del presupuesto (crear)."""

    tipo: str = Field("servicio", description="servicio|repuesto|mano_obra|otro")
    descripcion: str = Field(..., min_length=1, max_length=255)
    cantidad: Decimal = Field(Decimal("1.00"), gt=0)
    precio_unitario: Decimal = Field(Decimal("0.00"), ge=0)
    orden_display: int = 0


class OrdenItemUpdate(BaseModel):
    """Actualizar item (parcial)."""

    tipo: str | None = None
    descripcion: str | None = Field(None, min_length=1, max_length=255)
    cantidad: Decimal | None = Field(None, gt=0)
    precio_unitario: Decimal | None = Field(None, ge=0)
    orden_display: int | None = None


class OrdenItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    tipo: str
    descripcion: str
    cantidad: Decimal
    precio_unitario: Decimal
    subtotal: Decimal
    aprobado: bool | None
    orden_display: int


class OrdenTrabajoCreate(BaseModel):
    """Crear una orden (prestador la crea para un cliente)."""

    cliente_id: UUID
    objeto_servicio_id: UUID
    diagnostico_inicial: str | None = None
    notas_internas: str | None = None
    notas_cliente: str | None = None
    prioridad: str = Field("normal", description="baja|normal|alta|urgente")
    fecha_estimada_entrega: datetime | None = None
    km_ingreso: int | None = Field(None, ge=0)


class OrdenTrabajoUpdate(BaseModel):
    """Actualizar orden (parcial, solo prestador)."""

    diagnostico_inicial: str | None = None
    notas_internas: str | None = None
    notas_cliente: str | None = None
    prioridad: str | None = None
    fecha_estimada_entrega: datetime | None = None
    km_ingreso: int | None = Field(None, ge=0)
    km_salida: int | None = Field(None, ge=0)


class OrdenCambiarEstadoRequest(BaseModel):
    """Cambiar estado de la orden."""

    nuevo_estado: str
    motivo: str | None = Field(None, max_length=500)


class OrdenAprobarItemRequest(BaseModel):
    """Aprobar/rechazar items individualmente."""

    item_id: UUID
    aprobado: bool


class OrdenAprobarRequest(BaseModel):
    """Aprobar/rechazar el presupuesto completo o por items."""

    aprobar_todos: bool = False
    items: list[OrdenAprobarItemRequest] | None = None
    motivo_rechazo: str | None = Field(None, max_length=500)


class OrdenHistorialEventoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    tipo: str
    estado_anterior: str | None
    estado_nuevo: str | None
    usuario_id: UUID | None
    contenido: dict | None
    created_at: datetime


class OrdenTrabajoResponse(BaseModel):
    """Vista completa de una orden."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    numero: str
    cliente_id: UUID
    prestador_id: UUID
    objeto_servicio_id: UUID
    estado: str
    prioridad: str
    diagnostico_inicial: str | None
    notas_cliente: str | None
    # notas_internas solo se incluye si el caller es el prestador (ver endpoint)
    notas_internas: str | None = None

    fecha_ingreso: datetime
    fecha_estimada_entrega: datetime | None
    fecha_entrega_real: datetime | None

    km_ingreso: int | None
    km_salida: int | None

    total_presupuesto: Decimal
    total_aprobado: Decimal

    items: list[OrdenItemResponse] = []


class OrdenTrabajoDetalleResponse(OrdenTrabajoResponse):
    """Vista con historial completo."""

    historial: list[OrdenHistorialEventoResponse] = []


class OrdenListItemResponse(BaseModel):
    """Item resumido para listados."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    numero: str
    estado: str
    prioridad: str
    cliente_id: UUID
    prestador_id: UUID
    objeto_servicio_id: UUID
    total_presupuesto: Decimal
    total_aprobado: Decimal
    fecha_ingreso: datetime
    fecha_estimada_entrega: datetime | None


# =========================================================
# M2+: Busqueda de clientes
# =========================================================
class ClienteBusquedaResponse(BaseModel):
    """Resultado de busqueda de cliente (para crear ordenes)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    nombre: str | None
    apellido: str | None
    email: str | None


# =========================================================
# M3: Turnos (agenda cliente-prestador)
# =========================================================
class TurnoCreate(BaseModel):
    """Crear un turno (cliente reserva con un prestador)."""

    prestador_id: UUID
    objeto_servicio_id: UUID
    fecha_inicio: datetime
    duracion_min: int = Field(30, ge=15, le=480)
    motivo: str | None = Field(None, max_length=255)
    notas_cliente: str | None = None


class TurnoUpdate(BaseModel):
    """Actualizar un turno (parcial, solo en estado pendiente)."""

    fecha_inicio: datetime | None = None
    duracion_min: int | None = Field(None, ge=15, le=480)
    motivo: str | None = Field(None, max_length=255)
    notas_cliente: str | None = None


class TurnoRechazarRequest(BaseModel):
    """Rechazar un turno (prestador)."""

    motivo: str | None = Field(None, max_length=500)


class TurnoCancelarRequest(BaseModel):
    """Cancelar un turno."""

    motivo: str | None = Field(None, max_length=500)


class TurnoCambiarEstadoRequest(BaseModel):
    """Cambiar estado de un turno."""

    nuevo_estado: str
    motivo: str | None = Field(None, max_length=500)


class TurnoVincularOrdenRequest(BaseModel):
    """Vincular una orden existente al turno."""

    orden_id: UUID


class TurnoResponse(BaseModel):
    """Vista completa de un turno."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    cliente_id: UUID
    prestador_id: UUID
    objeto_servicio_id: UUID
    fecha_inicio: datetime
    duracion_min: int
    estado: str
    motivo: str | None
    notas_cliente: str | None
    notas_prestador: str | None
    orden_id: UUID | None
    created_at: datetime
    updated_at: datetime


class TurnoListItemResponse(BaseModel):
    """Item resumido para listados."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    cliente_id: UUID
    prestador_id: UUID
    objeto_servicio_id: UUID
    fecha_inicio: datetime
    duracion_min: int
    estado: str
    motivo: str | None
    orden_id: UUID | None
    created_at: datetime
    updated_at: datetime


# =========================================================
# M4: Garantias y Recordatorios
# =========================================================
class GarantiaCreate(BaseModel):
    """Crear una garantia (prestador)."""

    tipo: str = Field("completo", description="mano_obra|repuesto|completo")
    duracion_dias: int = Field(30, ge=1, le=3650)
    cobertura: str | None = None
    condiciones: str | None = None


class GarantiaUpdate(BaseModel):
    """Actualizar garantia (parcial)."""

    tipo: str | None = None
    duracion_dias: int | None = Field(None, ge=1, le=3650)
    cobertura: str | None = None
    condiciones: str | None = None


class GarantiaResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    orden_id: UUID
    tipo: str
    duracion_dias: int
    fecha_inicio: date
    fecha_fin: date
    cobertura: str | None
    condiciones: str | None
    activo: bool
    created_at: datetime


class RecordatorioCreate(BaseModel):
    """Crear un recordatorio (cliente o sistema)."""

    objeto_servicio_id: UUID
    tipo: str = Field(..., description="km|fecha|evento")
    condicion: dict = Field(..., description='Ej: {"km_umbral": 5000}')
    mensaje: str = Field(..., min_length=1, max_length=255)


class RecordatorioUpdate(BaseModel):
    """Actualizar recordatorio (parcial)."""

    condicion: dict | None = None
    mensaje: str | None = Field(None, min_length=1, max_length=255)


class RecordatorioResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    objeto_servicio_id: UUID
    tipo: str
    condicion: dict
    mensaje: str
    enviado: bool
    fecha_envio: datetime | None
    activo: bool
    created_at: datetime

# =========================================================
# M5.1: Fotos de orden
# =========================================================
class OrdenFotoVarianteResponse(BaseModel):
    """Metadata de una variante generada (original/medium/thumb)."""

    ancho: int
    alto: int
    tamano_bytes: int
    url: str


class OrdenFotoResponse(BaseModel):
    """Foto de una orden con sus variantes y metadata."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    orden_id: UUID
    item_id: UUID | None
    momento: str

    subido_por_id: UUID
    subido_por_rol: str

    hash_sha256: str
    storage_backend: str
    storage_key: str
    variantes: dict  # {nombre: variante_dict}
    mime_type: str
    tamano_bytes: int
    ancho: int
    alto: int
    blurhash: str | None

    descripcion: str | None
    fecha_captura: datetime | None

    activo: bool
    created_at: datetime

