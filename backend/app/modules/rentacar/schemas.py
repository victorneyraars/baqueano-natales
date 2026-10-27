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


class RentacarVehiculoCreate(RentacarVehiculoBase):
    prestador_id: UUID


class RentacarVehiculoOut(RentacarVehiculoBase):
    id: UUID
    prestador_id: UUID

    class Config:
        from_attributes = True


class RentacarReservaBase(BaseModel):
    vehiculo_id: UUID
    cliente_id: UUID
    fecha_inicio: datetime
    fecha_fin: datetime
    metodo_pago: str
    precio_total: float


class RentacarReservaCreate(RentacarReservaBase):
    pass


class RentacarReservaOut(RentacarReservaBase):
    id: UUID
    estado: str

    class Config:
        from_attributes = True
