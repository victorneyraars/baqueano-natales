"""
Schemas Pydantic del módulo prestadores.

Divide en:
- Categorías de oficio: admin CRUD + respuesta pública.
- Prestadores: crear, editar, respuesta pública vs. privada.
- Fotos de trabajos: galería ordenada.
- Filtros y paginación.
- Acciones admin (verificar, rechazar, suspender, destacar).
"""
from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.modules.prestadores.models import EstadoPrestador

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
# Categorías de oficio
# =========================================================
class CategoriaOficioBase(BaseModel):
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


class CategoriaOficioCreate(CategoriaOficioBase):
    """Payload para crear una categoría (admin)."""


class CategoriaOficioUpdate(BaseModel):
    """Payload para editar una categoría (admin, parcial)."""

    nombre: str | None = Field(default=None, min_length=2, max_length=100)
    slug: Slug | None = None
    descripcion: str | None = Field(default=None, max_length=500)
    icono: str | None = Field(default=None, max_length=100)
    color_hex: ColorHex | None = None
    orden: int | None = Field(default=None, ge=0)
    activo: bool | None = None


class CategoriaOficioResponse(CategoriaOficioBase):
    """Respuesta de categoría (con metadata)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    activo: bool
    created_at: datetime
    updated_at: datetime


# =========================================================
# Fotos de trabajos
# =========================================================
class FotoTrabajoBase(BaseModel):
    url: str = Field(min_length=1, max_length=500)
    descripcion: str | None = Field(default=None, max_length=255)
    orden: int = Field(default=0, ge=0)


class FotoTrabajoCreate(FotoTrabajoBase):
    """Payload para agregar una foto de trabajo."""


class FotoTrabajoResponse(FotoTrabajoBase):
    """Respuesta de foto de trabajo."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    prestador_id: UUID
    created_at: datetime
    updated_at: datetime


class FotosTrabajoBulkUpdate(BaseModel):
    """Payload para reemplazar toda la galería de fotos."""

    fotos: list[FotoTrabajoCreate] = Field(min_length=0, max_length=30)


# =========================================================
# Prestadores — Crear / Editar
# =========================================================
class PrestadorBase(BaseModel):
    nombre: str = Field(min_length=3, max_length=150)
    descripcion: str | None = None
    telefono: str | None = Field(default=None, max_length=20)
    whatsapp: str | None = Field(default=None, max_length=20)
    email: str | None = Field(default=None, max_length=255)
    sitio_web: str | None = Field(default=None, max_length=255)

    # Ubicación
    comuna: str = Field(default="Puerto Natales", max_length=100)
    region: str = Field(default="Magallanes", max_length=100)
    direccion: str | None = Field(default=None, max_length=255)
    latitud: Decimal | None = Field(default=None, ge=-90, le=90)
    longitud: Decimal | None = Field(default=None, ge=-180, le=180)
    radio_cobertura_km: Decimal | None = Field(default=None, ge=0, le=500)

    # Modalidad
    atiende_domicilio: bool = False
    atiende_local: bool = True
    atiende_emergencias: bool = False
    horario_descripcion: str | None = Field(default=None, max_length=255)

    # JSONB
    especialidades: list[str] | None = Field(
        default=None,
        max_length=30,
        description="Lista de especialidades dentro de la categoría",
    )
    datos_extra: dict | None = Field(
        default=None,
        description="Campos específicos por categoría",
    )

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
        cleaned = v.replace(" ", "").replace("-", "")
        if not cleaned.startswith("+") and not cleaned.isdigit():
            raise ValueError("Teléfono inválido")
        return v

    @field_validator("especialidades")
    @classmethod
    def _validate_especialidades(
        cls, v: list[str] | None
    ) -> list[str] | None:
        if v is None:
            return None
        # Normalizar: sin vacíos, minúsculas, sin duplicados (preservando orden)
        cleaned: list[str] = []
        seen: set[str] = set()
        for item in v:
            norm = item.strip().lower()
            if not norm or norm in seen:
                continue
            seen.add(norm)
            cleaned.append(norm)
        return cleaned or None


class PrestadorCreate(PrestadorBase):
    """Payload para crear un prestador (usuario dueño)."""

    categoria_id: UUID


class PrestadorUpdate(BaseModel):
    """Payload para editar (parcial, dueño)."""

    categoria_id: UUID | None = None
    nombre: str | None = Field(default=None, min_length=3, max_length=150)
    descripcion: str | None = None
    telefono: str | None = Field(default=None, max_length=20)
    whatsapp: str | None = Field(default=None, max_length=20)
    email: str | None = Field(default=None, max_length=255)
    sitio_web: str | None = Field(default=None, max_length=255)

    comuna: str | None = Field(default=None, max_length=100)
    region: str | None = Field(default=None, max_length=100)
    direccion: str | None = Field(default=None, max_length=255)
    latitud: Decimal | None = Field(default=None, ge=-90, le=90)
    longitud: Decimal | None = Field(default=None, ge=-180, le=180)
    radio_cobertura_km: Decimal | None = Field(default=None, ge=0, le=500)

    atiende_domicilio: bool | None = None
    atiende_local: bool | None = None
    atiende_emergencias: bool | None = None
    horario_descripcion: str | None = Field(default=None, max_length=255)

    especialidades: list[str] | None = Field(default=None, max_length=30)
    datos_extra: dict | None = None


# =========================================================
# Prestadores — Respuestas
# =========================================================
class PrestadorPublicoResponse(BaseModel):
    """Respuesta pública (listado). Sin datos sensibles."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    slug: str
    nombre: str
    descripcion: str | None
    categoria: CategoriaOficioResponse
    comuna: str
    region: str
    foto_url: str | None
    atiende_domicilio: bool
    atiende_local: bool
    atiende_emergencias: bool
    horario_descripcion: str | None
    calificacion_promedio: Decimal
    total_resenas: int
    verificado: bool
    destacado: bool
    especialidades: list[str] | None


class PrestadorDetalleResponse(PrestadorPublicoResponse):
    """Detalle público completo con contacto y galería."""

    telefono: str | None
    whatsapp: str | None
    email: str | None
    sitio_web: str | None
    direccion: str | None
    latitud: Decimal | None
    longitud: Decimal | None
    radio_cobertura_km: Decimal | None
    datos_extra: dict | None
    fotos_trabajos: list[FotoTrabajoResponse] = []


class PrestadorPrivadoResponse(BaseModel):
    """Respuesta para el dueño/admin (incluye estado, motivo_rechazo, etc.)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    usuario_id: UUID
    categoria_id: UUID
    slug: str
    nombre: str
    descripcion: str | None
    telefono: str | None
    whatsapp: str | None
    email: str | None
    sitio_web: str | None
    comuna: str
    region: str
    direccion: str | None
    latitud: Decimal | None
    longitud: Decimal | None
    radio_cobertura_km: Decimal | None
    atiende_domicilio: bool
    atiende_local: bool
    atiende_emergencias: bool
    horario_descripcion: str | None
    foto_url: str | None
    estado: EstadoPrestador
    motivo_rechazo: str | None
    destacado: bool
    verificado: bool
    verificado_en: datetime | None
    verificado_por_id: UUID | None
    especialidades: list[str] | None
    datos_extra: dict | None
    calificacion_promedio: Decimal
    total_resenas: int
    activo: bool
    created_at: datetime
    updated_at: datetime
    fotos_trabajos: list[FotoTrabajoResponse] = []


# =========================================================
# Listados y filtros
# =========================================================
class PaginacionMeta(BaseModel):
    total: int
    page: int
    page_size: int
    total_pages: int


class PrestadorListResponse(BaseModel):
    items: list[PrestadorPublicoResponse]
    meta: PaginacionMeta


class PrestadorPrivadoListResponse(BaseModel):
    items: list[PrestadorPrivadoResponse]
    meta: PaginacionMeta


# =========================================================
# Acciones admin
# =========================================================
class PrestadorRechazarRequest(BaseModel):
    motivo: str = Field(min_length=5, max_length=1000)


class PrestadorVerificarRequest(BaseModel):
    categoria_id: UUID | None = Field(
        default=None,
        description="Si no se envía, se usa la que ya tenga asignada",
    )


class PrestadorDestacarRequest(BaseModel):
    destacado: bool