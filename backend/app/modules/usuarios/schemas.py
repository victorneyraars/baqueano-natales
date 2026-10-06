"""
Schemas Pydantic del módulo usuarios.
Definen el contrato de entrada/salida de los endpoints.
"""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.modules.auth.models import RolUsuario


# ---------------------------------------------------------
# Schemas de entrada
# ---------------------------------------------------------
class UsuarioUpdate(BaseModel):
    """
    Campos editables por el propio usuario.
    No se puede cambiar email, phone, rol, etc. desde acá.
    """

    nombre: str | None = Field(None, min_length=1, max_length=100)
    apellido: str | None = Field(None, min_length=1, max_length=100)


# ---------------------------------------------------------
# Schemas de salida
# ---------------------------------------------------------
class UsuarioMeResponse(BaseModel):
    """
    Datos completos del usuario autenticado.
    Es el que ve el dueño de la cuenta (todos sus datos).
    """

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    firebase_uid: str
    email: str | None
    phone: str | None
    nombre: str | None
    apellido: str | None
    avatar_url: str | None

    rol: RolUsuario
    verificado: bool
    activo: bool

    tiene_google: bool
    tiene_whatsapp: bool
    tiene_sms: bool

    created_at: datetime
    updated_at: datetime
    ultimo_login: datetime | None


class UsuarioPublicoResponse(BaseModel):
    """
    Datos públicos de un usuario.
    Es lo que ven otros usuarios (ej: para ver un prestador).
    NO incluye email, phone, firebase_uid, etc.
    """

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    nombre: str | None
    apellido: str | None
    avatar_url: str | None
    rol: RolUsuario
    verificado: bool


class AvatarUploadResponse(BaseModel):
    """Respuesta después de subir un avatar."""

    avatar_url: str
    message: str = "Avatar actualizado correctamente"


class MessageResponse(BaseModel):
    """Respuesta genérica con un mensaje."""

    message: str
