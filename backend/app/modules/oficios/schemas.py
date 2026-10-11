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
