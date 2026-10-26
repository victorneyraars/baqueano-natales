from enum import Enum
"""
Schemas Pydantic del módulo prestadores.

Divide en:
- Categorías de oficio: admin CRUD + respuesta pública.
- Prestadores: crear, editar, respuesta pública vs. privada.
- PrestadorServicio: catálogo de servicios con precios.
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
# Servicios del prestador
# =========================================================
class PrestadorServicioBase(BaseModel):
    nombre: str = Field(min_length=3, max_length=150)
    descripcion: str | None = None
    categoria_servicio: str | None = Field(default=None, max_length=80)
    precio_desde_clp: int | None = Field(default=None, ge=0, le=99_999_999)
    precio_hasta_clp: int | None = Field(default=None, ge=0, le=99_999_999)
    duracion_estimada_min: int | None = Field(
        default=None, ge=0, le=10_080
    )
    garantia_dias: int | None = Field(default=None, ge=0, le=3650)
    destacado: bool = False
    orden: int = Field(default=0, ge=0)

    @field_validator("precio_hasta_clp")
    @classmethod
    def _validate_rango_precio(
        cls, v: int | None, info
    ) -> int | None:
        """Si hay ambos precios, el hasta debe ser >= desde."""
        desde = info.data.get("precio_desde_clp") if hasattr(info, "data") else None
        if v is not None and desde is not None and v < desde:
            raise ValueError(
                "El precio 'hasta' debe ser mayor o igual al 'desde'"
            )
        return v


class PrestadorServicioCreate(PrestadorServicioBase):
    """Payload para agregar un servicio al catálogo."""


class PrestadorServicioUpdate(BaseModel):
    """Payload para editar un servicio (parcial)."""

    nombre: str | None = Field(default=None, min_length=3, max_length=150)
    descripcion: str | None = None
    categoria_servicio: str | None = Field(default=None, max_length=80)
    precio_desde_clp: int | None = Field(default=None, ge=0, le=99_999_999)
    precio_hasta_clp: int | None = Field(default=None, ge=0, le=99_999_999)
    duracion_estimada_min: int | None = Field(
        default=None, ge=0, le=10_080
    )
    garantia_dias: int | None = Field(default=None, ge=0, le=3650)
    destacado: bool | None = None
    activo: bool | None = None
    orden: int | None = Field(default=None, ge=0)


class PrestadorServicioResponse(PrestadorServicioBase):
    """Respuesta de un servicio del catálogo."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    prestador_id: UUID
    activo: bool
    created_at: datetime
    updated_at: datetime


class PrestadorServiciosBulkUpdate(BaseModel):
    """Payload para reemplazar TODOS los servicios del prestador."""

    servicios: list[PrestadorServicioCreate] = Field(
        min_length=0, max_length=100
    )


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



# =========================================================
# Prestadores — Crear / Editar
# =========================================================
class PrestadorBase(BaseModel):
    nombre: str = Field(min_length=3, max_length=150)
    descripcion: str | None = None
    anios_experiencia: int | None = Field(default=None, ge=0, le=100)

    # Contacto
    telefono: str | None = Field(default=None, max_length=20)
    whatsapp: str | None = Field(default=None, max_length=20)
    whatsapp_mensaje: str | None = Field(default=None, max_length=255)
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
    redes_sociales: dict | None = Field(
        default=None,
        description="Links: {instagram, facebook, tiktok, youtube, ...}",
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
    anios_experiencia: int | None = Field(default=None, ge=0, le=100)

    telefono: str | None = Field(default=None, max_length=20)
    whatsapp: str | None = Field(default=None, max_length=20)
    whatsapp_mensaje: str | None = Field(default=None, max_length=255)
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
    redes_sociales: dict | None = None


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
    anios_experiencia: int | None
    categoria: CategoriaOficioResponse
    comuna: str
    region: str
    foto_url: str | None
    foto_portada_url: str | None
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
    """Detalle público completo con contacto, galería y servicios."""

    telefono: str | None
    whatsapp: str | None
    whatsapp_mensaje: str | None
    email: str | None
    sitio_web: str | None
    direccion: str | None
    latitud: Decimal | None
    longitud: Decimal | None
    radio_cobertura_km: Decimal | None
    datos_extra: dict | None
    redes_sociales: dict | None
    modalidades: dict | None = None
    servicios: list[PrestadorServicioResponse] = []
    fotos_trabajos: list = []


class PrestadorPrivadoResponse(BaseModel):
    """Respuesta para el dueño/admin (incluye estado, motivo_rechazo, etc.)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    usuario_id: UUID
    categoria_id: UUID
    slug: str
    nombre: str
    descripcion: str | None
    anios_experiencia: int | None
    telefono: str | None
    whatsapp: str | None
    whatsapp_mensaje: str | None
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
    foto_portada_url: str | None
    estado: EstadoPrestador
    motivo_rechazo: str | None
    destacado: bool
    verificado: bool
    verificado_en: datetime | None
    verificado_por_id: UUID | None
    especialidades: list[str] | None
    datos_extra: dict | None
    redes_sociales: dict | None
    calificacion_promedio: Decimal
    total_resenas: int
    activo: bool
    created_at: datetime
    updated_at: datetime
    servicios: list[PrestadorServicioResponse] = []
    fotos_trabajos: list = []


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

# ============================================================
# Modalidades de prestación (Fase 6)
# ============================================================
class TipoModalidad(str, Enum):
    TALLER_FISICO = "taller_fisico"
    DOMICILIO = "domicilio"
    PUNTO_ESTRATEGICO = "punto_estrategico"
    RECOGIDA_ENTREGA = "recogida_entrega"
    SUSCRIPCION = "suscripcion"
    FLOTAS = "flotas"
    HIBRIDO = "hibrido"


class ConfigModalidad(BaseModel):
    activo: bool = False
    notas: str | None = None


class ConfigTallerFisico(ConfigModalidad):
    pass


class ConfigDomicilio(ConfigModalidad):
    radio_km: int = Field(15, ge=0, le=100)
    costo_desplazamiento_clp: int = Field(0, ge=0)


class ConfigPuntoEstrategico(ConfigModalidad):
    punto_descripcion: str | None = None


class ConfigRecogidaEntrega(ConfigModalidad):
    costo_traslado_clp: int = Field(0, ge=0)


class ConfigSuscripcion(ConfigModalidad):
    planes: list[dict] = Field(default_factory=list)


class ConfigFlotas(ConfigModalidad):
    pass


class ModalidadesConfig(BaseModel):
    taller_fisico: ConfigTallerFisico = Field(default_factory=ConfigTallerFisico)
    domicilio: ConfigDomicilio = Field(default_factory=ConfigDomicilio)
    punto_estrategico: ConfigPuntoEstrategico = Field(default_factory=ConfigPuntoEstrategico)
    recogida_entrega: ConfigRecogidaEntrega = Field(default_factory=ConfigRecogidaEntrega)
    suscripcion: ConfigSuscripcion = Field(default_factory=ConfigSuscripcion)
    flotas: ConfigFlotas = Field(default_factory=ConfigFlotas)
    hibrido: ConfigModalidad = Field(default_factory=ConfigModalidad)


class ModalidadesResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    modalidades: ModalidadesConfig = Field(default_factory=ModalidadesConfig)


class ModalidadesUpdateRequest(BaseModel):
    modalidades: ModalidadesConfig
