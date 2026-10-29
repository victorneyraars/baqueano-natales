"""Esquemas Pydantic para Rent a Car Vásquez."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class RentacarVehiculoBase(BaseModel):
    patente: str
    marca: str
    modelo: str
    anio: int
    categoria: str
    precio_dia: float
    disponible: bool = True
    imagen_url: str | None = None


class RentacarVehiculoCreate(RentacarVehiculoBase):
    prestador_id: UUID


class RentacarVehiculoOut(RentacarVehiculoBase):
    id: UUID
    prestador_id: UUID

    class Config:
        from_attributes = True


class RentacarReservaBase(BaseModel):
    vehiculo_id: UUID
    fecha_inicio: datetime
    fecha_fin: datetime
    metodo_pago: str
    precio_total: float


class RentacarReservaCreate(RentacarReservaBase):
    """Reserva pública: incluye datos de contacto del cliente invitado."""
    nombre_cliente: str
    email_cliente: str
    telefono_cliente: str


class RentacarReservaOut(RentacarReservaBase):
    id: UUID
    estado: str
    nombre_cliente: str | None = None
    email_cliente: str | None = None
    telefono_cliente: str | None = None

    class Config:
        from_attributes = True


class RentacarImagenPresignedRequest(BaseModel):
    filename: str
    content_type: str


class RentacarImagenPresignedResponse(BaseModel):
    upload_url: str
    object_key: str
    imagen_url: str


class RentacarVehiculoCreatePropietario(BaseModel):
    """Schema para que el propietario cree un vehículo.
    
    NO incluye prestador_id (se infiere del usuario logueado).
    """
    patente: str
    marca: str
    modelo: str
    anio: int
    categoria: str
    precio_dia: float
    disponible: bool = True
    imagen_url: str | None = None


class RentacarVehiculoUpdatePropietario(BaseModel):
    """Schema para actualizar parcialmente un vehículo (propietario)."""
    patente: str | None = None
    marca: str | None = None
    modelo: str | None = None
    anio: int | None = None
    categoria: str | None = None
    precio_dia: float | None = None
    disponible: bool | None = None
    imagen_url: str | None = None


# =========================================================
# Reservas propietario (detalle con vehiculo + cliente)
# =========================================================
class RentacarReservaDetalleOut(RentacarReservaOut):
    """Reserva con datos del vehiculo para el panel del prestador."""
    vehiculo_patente: str | None = None
    vehiculo_marca: str | None = None
    vehiculo_modelo: str | None = None
    vehiculo_imagen_url: str | None = None

    class Config:
        from_attributes = True


class RentacarReservaEstadoUpdate(BaseModel):
    """Cambio de estado de una reserva."""
    estado: str


class RentacarReservaEstado(str):
    """Estados validos de una reserva."""
    PENDIENTE = "pendiente"
    CONFIRMADA = "confirmada"
    EN_CURSO = "en_curso"
    COMPLETADA = "completada"
    CANCELADA = "cancelada"


# =========================================================
# Config propietario
# =========================================================
class RentacarConfigOut(BaseModel):
    id: UUID
    prestador_id: UUID
    metodos_pago: dict
    deposito: dict
    conductor_adicional: dict
    categorias: list

    class Config:
        from_attributes = True


class RentacarConfigUpdate(BaseModel):
    metodos_pago: dict | None = None
    deposito: dict | None = None
    conductor_adicional: dict | None = None
    categorias: list | None = None


# =========================================================
# Stats dashboard
# =========================================================
class RentacarStatsOut(BaseModel):
    vehiculos_total: int
    vehiculos_disponibles: int
    reservas_total: int
    reservas_pendientes: int
    reservas_confirmadas: int
    reservas_en_curso: int
    reservas_completadas: int
    reservas_canceladas: int
    ingresos_totales: float
    ingresos_mes_actual: float
