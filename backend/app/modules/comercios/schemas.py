"""
Schemas Pydantic del módulo comercios.

Divide en:
- Categorías: admin CRUD + respuesta pública.
- Comercios: crear, editar, respuesta pública vs. privada.
- Horarios: multi-franja por día.
- Filtros y paginación.
- Acciones admin (verificar, rechazar, suspender).
"""
from datetime import datetime, time
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.modules.comercios.models import EstadoComercio

# =========================================================
# Helpers / tipos comunes
# =========================================================
Slug = Annotated[
    str,
    Field(
        min_length=3,
        max_length=180,
        pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$",
        description="Slug en minúsculas, alfanumérico y guiones",
    ),
]

ColorHex = Annotated[
    str,
    Field(
        pattern=r"^#[0-9A-Fa-f]{6}$",
        description="Color en formato #RRGGBB",
    ),
]


# =========================================================
# Categorías
# =========================================================
class CategoriaComercioBase(BaseModel):
    nombre: str = Field(min_length=2, max_length=100)
    slug: Slug
    descripcion: str | None = Field(default=None, max_length=500)
    icono: str | None = Field(
        default=None,
        max_length=100,
        description="Nombre del ícono Material",
    )
    color_hex: ColorHex | None = None
    orden: int = Field(default=0, ge=0)


class CategoriaComercioCreate(CategoriaComercioBase):
    """Payload para crear una categoría (admin)."""


class CategoriaComercioUpdate(BaseModel):
    """Payload para editar una categoría (admin, parcial)."""

    nombre: str | None = Field(default=None, min_length=2, max_length=100)
    slug: Slug | None = None
    descripcion: str | None = Field(default=None, max_length=500)
    icono: str | None = Field(default=None, max_length=100)
    color_hex: ColorHex | None = None
    orden: int | None = Field(default=None, ge=0)
    activo: bool | None = None


class CategoriaComercioResponse(CategoriaComercioBase):
    """Respuesta de categoría (con metadata)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    activo: bool
    created_at: datetime
    updated_at: datetime


# =========================================================
# Horarios
# =========================================================
class HorarioBase(BaseModel):
    dia_semana: int = Field(
        ge=0,
        le=6,
        description="0=lunes ... 6=domingo",
    )
    cerrado: bool = False
    abre: time | None = None
    cierra: time | None = None

    @field_validator("abre", "cierra")
    @classmethod
    def _validate_horas(cls, v: time | None) -> time | None:
        if v is not None and (v.hour > 23 or v.minute > 59):
            raise ValueError("Hora fuera de rango (00:00 - 23:59)")
        return v


class HorarioCreate(HorarioBase):
    """Payload para crear un horario."""

    @field_validator("cierra")
    @classmethod
    def _validate_cierra(cls, v: time | None, info) -> time | None:
        # `info.data` puede no tener 'abre' si viene después
        abre = info.data.get("abre") if hasattr(info, "data") else None
        cerrado = info.data.get("cerrado") if hasattr(info, "data") else False
        if cerrado:
            return v
        if abre is None or v is None:
            raise ValueError("Si no está cerrado, 'abre' y 'cierra' son obligatorios")
        if v <= abre:
            raise ValueError("'cierra' debe ser mayor que 'abre'")
        return v


class HorarioResponse(HorarioBase):
    """Respuesta de horario."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    comercio_id: UUID
    created_at: datetime
    updated_at: datetime


class HorariosBulkUpdate(BaseModel):
    """Payload para reemplazar todos los horarios de un comercio."""

    horarios: list[HorarioCreate] = Field(min_length=1, max_length=21)


# =========================================================
# Comercios — Crear / Editar
# =========================================================
class ComercioBase(BaseModel):
    nombre: str = Field(min_length=3, max_length=150)
    descripcion_corta: str | None = Field(default=None, max_length=300)
    descripcion_larga: str | None = None
    telefono: str | None = Field(default=None, max_length=20)
    whatsapp: str | None = Field(default=None, max_length=20)
    email: str | None = Field(default=None, max_length=255)
    sitio_web: str | None = Field(default=None, max_length=255)
    direccion: str = Field(min_length=3, max_length=255)
    ciudad: str = Field(default="Puerto Natales", max_length=100)
    region: str = Field(default="Magallanes", max_length=100)
    latitud: Decimal | None = Field(default=None, ge=-90, le=90)
    longitud: Decimal | None = Field(default=None, ge=-180, le=180)
    referencia: str | None = Field(default=None, max_length=255)
    acepta_delivery: bool = False
    acepta_retiro: bool = True
    costo_envio_clp: int = Field(default=0, ge=0, le=999_999)
    pedido_minimo_clp: int = Field(default=0, ge=0, le=999_999)
    radio_entrega_km: Decimal | None = Field(default=None, ge=0, le=99)
    tiempo_preparacion_min: int | None = Field(default=None, ge=0, le=1440)

    @field_validator("email")
    @classmethod
    def _validate_email(cls, v: str | None) -> str | None:
        if v is None or v == "":
            return None
        if "@" not in v or "." not in v.split("@")[-1]:
            raise ValueError("Email inválido")
        return v.lower()

    @field_validator("telefono", "whatsapp")
    @classmethod
    def _validate_phone(cls, v: str | None) -> str | None:
        if v is None or v == "":
            return None
        # Solo dígitos, +, espacios, guiones
        cleaned = v.replace(" ", "").replace("-", "")
        if not cleaned.startswith("+") and not cleaned.isdigit():
            raise ValueError("Teléfono inválido")
        return v


class ComercioCreate(ComercioBase):
    """Payload para crear un comercio (dueño)."""

    categoria_id: UUID | None = None


class ComercioUpdate(BaseModel):
    """Payload para editar (parcial, dueño)."""

    nombre: str | None = Field(default=None, min_length=3, max_length=150)
    descripcion_corta: str | None = Field(default=None, max_length=300)
    descripcion_larga: str | None = None
    categoria_id: UUID | None = None
    telefono: str | None = Field(default=None, max_length=20)
    whatsapp: str | None = Field(default=None, max_length=20)
    email: str | None = Field(default=None, max_length=255)
    sitio_web: str | None = Field(default=None, max_length=255)
    direccion: str | None = Field(default=None, min_length=3, max_length=255)
    ciudad: str | None = Field(default=None, max_length=100)
    region: str | None = Field(default=None, max_length=100)
    latitud: Decimal | None = Field(default=None, ge=-90, le=90)
    longitud: Decimal | None = Field(default=None, ge=-180, le=180)
    referencia: str | None = Field(default=None, max_length=255)
    acepta_delivery: bool | None = None
    acepta_retiro: bool | None = None
    costo_envio_clp: int | None = Field(default=None, ge=0, le=999_999)
    pedido_minimo_clp: int | None = Field(default=None, ge=0, le=999_999)
    radio_entrega_km: Decimal | None = Field(default=None, ge=0, le=99)
    tiempo_preparacion_min: int | None = Field(default=None, ge=0, le=1440)


# =========================================================
# Comercios — Respuestas
# =========================================================
class ComercioPublicoResponse(BaseModel):
    """Respuesta pública (listado y detalle). Sin campos sensibles."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    slug: str
    nombre: str
    descripcion_corta: str | None
    categoria: CategoriaComercioResponse | None
    direccion: str
    ciudad: str
    region: str
    latitud: Decimal | None
    longitud: Decimal | None
    referencia: str | None
    logo_url: str | None
    portada_url: str | None
    acepta_delivery: bool
    acepta_retiro: bool
    costo_envio_clp: int
    pedido_minimo_clp: int
    radio_entrega_km: Decimal | None
    tiempo_preparacion_min: int | None
    rating_promedio: Decimal
    total_resenas: int
    destacado: bool


class ComercioDetalleResponse(ComercioPublicoResponse):
    """Detalle público completo con horarios."""

    descripcion_larga: str | None
    telefono: str | None
    whatsapp: str | None
    email: str | None
    sitio_web: str | None
    horarios: list[HorarioResponse] = []


class ComercioPrivadoResponse(BaseModel):
    """Respuesta para el dueño (incluye estado, motivo_rechazo, etc.)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    propietario_id: UUID
    categoria_id: UUID | None
    slug: str
    nombre: str
    descripcion_corta: str | None
    descripcion_larga: str | None
    telefono: str | None
    whatsapp: str | None
    email: str | None
    sitio_web: str | None
    direccion: str
    ciudad: str
    region: str
    latitud: Decimal | None
    longitud: Decimal | None
    referencia: str | None
    logo_url: str | None
    portada_url: str | None
    estado: EstadoComercio
    motivo_rechazo: str | None
    destacado: bool
    verificado_en: datetime | None
    verificado_por_id: UUID | None
    acepta_delivery: bool
    acepta_retiro: bool
    costo_envio_clp: int
    pedido_minimo_clp: int
    radio_entrega_km: Decimal | None
    tiempo_preparacion_min: int | None
    rating_promedio: Decimal
    total_resenas: int
    activo: bool
    created_at: datetime
    updated_at: datetime
    horarios: list[HorarioResponse] = []


# =========================================================
# Listados y filtros
# =========================================================
class PaginacionMeta(BaseModel):
    total: int
    page: int
    page_size: int
    total_pages: int


class ComercioListResponse(BaseModel):
    items: list[ComercioPublicoResponse]
    meta: PaginacionMeta


class ComercioPrivadoListResponse(BaseModel):
    items: list[ComercioPrivadoResponse]
    meta: PaginacionMeta


# =========================================================
# Acciones admin
# =========================================================
class ComercioRechazarRequest(BaseModel):
    motivo: str = Field(min_length=5, max_length=1000)


class ComercioVerificarRequest(BaseModel):
    categoria_id: UUID | None = Field(
        default=None,
        description="Si no se envía, se usa la que ya tenga asignada",
    )