"""
Schemas Pydantic del módulo admin.
"""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.modules.auth.models import RolUsuario


# ---------------------------------------------------------
# Schemas de entrada
# ---------------------------------------------------------
class CambiarRolRequest(BaseModel):
    """Cambiar el rol de un usuario."""

    rol: RolUsuario = Field(..., description="Nuevo rol del usuario")


class ListarUsuariosQuery(BaseModel):
    """
    Query params para listar usuarios.
    Se valida en el endpoint con Depends().
    """

    rol: RolUsuario | None = Field(None, description="Filtrar por rol")
    activo: bool | None = Field(None, description="Filtrar por estado activo")
    verificado: bool | None = Field(None, description="Filtrar por verificación")
    search: str | None = Field(
        None,
        max_length=100,
        description="Buscar por email, nombre o apellido (substring)",
    )
    limit: int = Field(50, ge=1, le=200, description="Registros por página (1-200)")
    offset: int = Field(0, ge=0, description="Desplazamiento para paginación")


# ---------------------------------------------------------
# Schemas de salida
# ---------------------------------------------------------
class UsuarioAdminResponse(BaseModel):
    """
    Vista completa de un usuario para el panel admin.
    Incluye todos los campos (incluidos los internos).
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


class ListarUsuariosResponse(BaseModel):
    """Respuesta paginada del listado de usuarios."""

    total: int = Field(..., description="Total de usuarios que matchean el filtro")
    limit: int
    offset: int
    items: list[UsuarioAdminResponse]


class EstadisticasUsuarios(BaseModel):
    """Estadísticas globales de usuarios."""

    total: int
    activos: int
    inactivos: int
    verificados: int
    por_rol: dict[str, int] = Field(
        ...,
        description="Cantidad de usuarios por rol",
    )
