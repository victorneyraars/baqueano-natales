"""Schemas para solicitudes de turno via landing publica."""
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, EmailStr, Field


class SolicitudTurnoCreate(BaseModel):
    nombre_cliente: str = Field(..., min_length=2, max_length=255)
    email_cliente: EmailStr
    telefono_cliente: str = Field(..., min_length=6, max_length=50)
    vehiculo_marca: str = Field(..., min_length=1, max_length=50)
    vehiculo_modelo: str = Field(..., min_length=1, max_length=50)
    vehiculo_anio: int | None = Field(None, ge=1900, le=2100)
    vehiculo_patente: str | None = Field(None, max_length=10)
    servicio_id: UUID | None = None
    fecha_preferida: datetime
    duracion_min: int = Field(30, ge=15, le=480)
    motivo: str | None = Field(None, max_length=500)
    modalidad: str = Field("domicilio", max_length=30)
    direccion_atencion: str | None = Field(None, max_length=500)
    metadata_extra: dict | None = None


class SolicitudTurnoResponse(BaseModel):
    turno_id: UUID
    mensaje: str


class VerificarOtpRequest(BaseModel):
    codigo: str = Field(..., min_length=6, max_length=6)


class VerificarOtpResponse(BaseModel):
    ok: bool
    mensaje: str
