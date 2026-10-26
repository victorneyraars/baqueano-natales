"""
Schemas Pydantic del módulo social.

Convenciones (alineadas con `app.modules.prestadores.schemas`):
- `*Create`: lo que entra para crear (campos obligatorios).
- `*Update`: lo que entra para editar (todos opcionales).
- `*Response`: lo que sale de la API.
- `*ListResponse`: lista + paginación.

Regla de oro: NUNCA se expone `access_token` ni `refresh_token` en
responses. Si en el futuro hace falta mostrar "últimos 4 caracteres" o
similar, se hace en un schema específico (`TokenSocialHint`).
"""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.modules.social.models import (
    DestinoPublicacion,
    EstadoPublicacion,
    PropietarioTipo,
    Red,
)


# =========================================================
# Paginación (compartida por todos los listados)
# =========================================================
class PaginacionMeta(BaseModel):
    """Metadata de paginación devuelta en listados."""

    total: int
    limit: int
    offset: int


# =========================================================
# CuentaSocial
# =========================================================
class CuentaSocialBase(BaseModel):
    """
    Campos comunes de una cuenta social.

    No incluye tokens: los tokens van en su propio schema
    (`TokenSocialGuardar`) y solo se manipulan internamente.
    """

    red: Red
    external_id: str = Field(..., min_length=1, max_length=150)
    external_name: str | None = Field(None, max_length=255)
    propietario_tipo: PropietarioTipo
    propietario_id: UUID | None = Field(
        None,
        description="NULL = cuenta central de Baqueano Natales",
    )
    cuenta_padre_id: UUID | None = Field(
        None,
        description="Para IG: apunta a la cuenta de FB que lo contiene",
    )
    auto_publish: bool = False
    metadata_extra: dict | None = None


class CuentaSocialCreate(CuentaSocialBase):
    """Datos para crear una cuenta. Sin tokens (van aparte)."""


class CuentaSocialUpdate(BaseModel):
    """
    Actualización parcial de una cuenta. Todos los campos opcionales.

    Nota: `red` y `external_id` NO se pueden cambiar (identifican la
    cuenta externa). Para cambiar la cuenta, se desconecta y se vuelve
    a conectar.
    """

    external_name: str | None = Field(None, max_length=255)
    auto_publish: bool | None = None
    metadata_extra: dict | None = None


class CuentaSocialResponse(BaseModel):
    """Vista pública de una cuenta. NO incluye tokens."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    red: Red
    external_id: str
    external_name: str | None
    propietario_tipo: PropietarioTipo
    propietario_id: UUID | None
    cuenta_padre_id: UUID | None
    auto_publish: bool
    activo: bool
    metadata_extra: dict | None
    created_at: datetime
    updated_at: datetime


class CuentaSocialListResponse(BaseModel):
    """Listado paginado de cuentas."""

    items: list[CuentaSocialResponse]
    meta: PaginacionMeta


# =========================================================
# TokenSocial
# =========================================================
class TokenSocialGuardar(BaseModel):
    """
    Datos para guardar o rotar un token.

    Este schema es SOLO de uso interno (services). Nunca se expone en
    responses. Los campos se cifran antes de guardar en DB.
    """

    access_token: str = Field(..., min_length=1)
    refresh_token: str | None = None
    token_type: str = Field("Bearer", max_length=50)
    expires_at: datetime | None = None
    scope: str | None = None


# =========================================================
# PublicacionSocial
# =========================================================
class PublicacionSocialCreate(BaseModel):
    """
    Encolar una publicación manual (desde admin o desde un service del
    vertical).

    El `contenido` es un JSON libre con esta forma:
        {
            "message": "texto del post",
            "image_urls": ["https://..."],
            "link": "https://..."
        }
    """

    cuenta_id: UUID
    recurso_tipo: str = Field(..., min_length=1, max_length=50)
    recurso_id: UUID
    red: Red
    contenido: dict = Field(
        ...,
        description="{'message': str, 'image_urls': [str], 'link': str}",
    )
    prioridad: int = Field(
        default=0,
        description='Prioridad de la cola. 0=Baqueano, 10=Prestador, 20=otros',
    )


class PublicacionSocialResponse(BaseModel):
    """Vista pública de una publicación en la cola."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    cuenta_id: UUID
    recurso_tipo: str
    recurso_id: UUID
    red: Red
    contenido: dict
    estado: EstadoPublicacion
    intentos: int
    proximo_intento_en: datetime | None
    external_post_id: str | None
    error_ultimo: str | None
    created_at: datetime
    updated_at: datetime


class PublicacionSocialListResponse(BaseModel):
    """Listado paginado de publicaciones."""

    items: list[PublicacionSocialResponse]
    meta: PaginacionMeta


# =========================================================
# ConfigSocial
# =========================================================
class ConfigSocialUpdate(BaseModel):
    """
    Actualización parcial de la config social.

    Todos los campos opcionales. Se aplican solo los que vengan seteados.
    """

    auto_publish: bool | None = None
    destino: DestinoPublicacion | None = None
    publicar_en_facebook: bool | None = None
    publicar_en_instagram: bool | None = None
    publicar_en_google: bool | None = None


class ConfigSocialResponse(BaseModel):
    """Vista pública de la config social."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    propietario_tipo: PropietarioTipo | None
    propietario_id: UUID | None
    auto_publish: bool
    destino: DestinoPublicacion
    publicar_en_facebook: bool
    publicar_en_instagram: bool
    publicar_en_google: bool
    created_at: datetime
    updated_at: datetime

# =========================================================
# OAuth Facebook (Etapa 2)
# =========================================================

class OAuthUrlResponse(BaseModel):
    """URL de autorizaci?n + state que el admin debe guardar."""
    url: str
    state: str
    expires_in_min: int = 10


class OAuthCallbackResponse(BaseModel):
    """Respuesta del callback OAuth (?til para tests y API)."""
    token_ref: str
    user_id: str
    expires_in_min: int = 15


class PaginaFacebookPublic(BaseModel):
    """P?gina de Facebook lista para el admin, sin access_token."""
    id: str
    name: str
    category: str | None = None
    tasks: list[str] = Field(default_factory=list)
    ya_conectada: bool = False


class ListarPaginasRequest(BaseModel):
    token_ref: str = Field(..., min_length=10)


class ListarPaginasResponse(BaseModel):
    paginas: list[PaginaFacebookPublic]


class ConectarCuentaRequest(BaseModel):
    """Conecta una p?gina: crea cuenta_social + token_social."""
    token_ref: str = Field(..., min_length=10)
    page_id: str = Field(..., min_length=1)
    propietario_tipo: PropietarioTipo = PropietarioTipo.BAQUEANO
    propietario_id: UUID | None = None
    alias: str | None = Field(None, max_length=120)


class ConectarCuentaResponse(BaseModel):
    cuenta: CuentaSocialResponse
    nombre_pagina: str

