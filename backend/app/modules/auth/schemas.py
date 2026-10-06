"""
Schemas Pydantic del módulo auth.
Definen el contrato de entrada/salida de la API.
"""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.modules.auth.models import RolUsuario


class UsuarioBase(BaseModel):
    """Campos comunes del usuario."""

    email: EmailStr | None = None
    phone: str | None = Field(None, max_length=20)
    nombre: str | None = Field(None, max_length=100)
    apellido: str | None = Field(None, max_length=100)


class UsuarioCreate(UsuarioBase):
    """Schema para crear un usuario (uso interno)."""

    firebase_uid: str
    rol: RolUsuario = RolUsuario.CLIENTE
    avatar_url: str | None = None


class UsuarioUpdate(BaseModel):
    """Schema para actualizar datos del usuario."""

    nombre: str | None = Field(None, max_length=100)
    apellido: str | None = Field(None, max_length=100)
    avatar_url: str | None = Field(None, max_length=500)


class UsuarioResponse(UsuarioBase):
    """Schema de respuesta pública del usuario."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    rol: RolUsuario
    verificado: bool
    activo: bool
    avatar_url: str | None
    tiene_google: bool
    tiene_whatsapp: bool
    tiene_sms: bool
    created_at: datetime
    ultimo_login: datetime | None
