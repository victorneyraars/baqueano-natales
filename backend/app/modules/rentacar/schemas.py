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
