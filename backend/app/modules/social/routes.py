"""
Endpoints HTTP del módulo social.

Por ahora, solo el router de admin está implementado (Etapa 1: esqueleto).
Los routers de OAuth, propietario y webhooks se agregarán en Etapas 2+.

Routers:
- router_admin: gestión de cuentas, config y publicaciones (requiere admin).
"""
import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query, status

from app.core.db import DbSession
from app.modules.social import services
from app.modules.social.deps import AdminUser
from app.modules.social.models import (
    EstadoPublicacion,
    PropietarioTipo,
    Red,
)
from app.modules.social.schemas import (
    ConfigSocialResponse,
    ConfigSocialUpdate,
    CuentaSocialCreate,
    CuentaSocialListResponse,
    CuentaSocialResponse,
    CuentaSocialUpdate,
    PaginacionMeta,
    PublicacionSocialCreate,
    PublicacionSocialListResponse,
    PublicacionSocialResponse,
)

logger = logging.getLogger(__name__)


# =========================================================
# Admin
# =========================================================
router_admin = APIRouter(prefix="/admin/social", tags=["social-admin"])


# ---------------------------------------------------------
# Cuentas
# ---------------------------------------------------------
@router_admin.get(
    "/cuentas",
    response_model=CuentaSocialListResponse,
    summary="Listar cuentas sociales conectadas",
    description=(
        "Listado con filtros por red y propietario. Requiere admin. "
        "Nunca expone tokens."
    ),
)
async def listar_cuentas(
    db: DbSession,
    _admin: AdminUser,
    red: Red | None = Query(None, description="Filtrar por red"),
    propietario_tipo: PropietarioTipo | None = Query(
        None, description="Filtrar por tipo de propietario"
    ),
    propietario_id: UUID | None = Query(
        None, description="Filtrar por ID de propietario específico"
    ),
    activas_solo: bool = Query(
        True, description="Excluir las inactivas (soft delete)"
    ),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> CuentaSocialListResponse:
    items, total = await services.listar_cuentas(
        db,
        red=red.value if red else None,
        propietario_tipo=propietario_tipo,
        propietario_id=propietario_id,
        activas_solo=activas_solo,
        limit=limit,
        offset=offset,
    )
    return CuentaSocialListResponse(
        items=[CuentaSocialResponse.model_validate(c) for c in items],
        meta=PaginacionMeta(total=total, limit=limit, offset=offset),
    )


@router_admin.get(
    "/cuentas/{cuenta_id}",
    response_model=CuentaSocialResponse,
    summary="Detalle de una cuenta social",
)
async def obtener_cuenta(
    cuenta_id: UUID,
    db: DbSession,
    _admin: AdminUser,
) -> CuentaSocialResponse:
    cuenta = await services.obtener_cuenta(db, cuenta_id)
    if cuenta is None:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cuenta social no encontrada",
        )
    return CuentaSocialResponse.model_validate(cuenta)


@router_admin.post(
    "/cuentas",
    response_model=CuentaSocialResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear una cuenta social",
    description=(
        "Crea una cuenta sin tokens. Los tokens se cargan aparte. "
        "Normalmente esto se hace vía OAuth (Etapa 2), pero el endpoint "
        "está disponible para casos puntuales."
    ),
)
async def crear_cuenta(
    datos: CuentaSocialCreate,
    db: DbSession,
    _admin: AdminUser,
) -> CuentaSocialResponse:
    cuenta = await services.crear_cuenta(db, datos)
    return CuentaSocialResponse.model_validate(cuenta)


@router_admin.patch(
    "/cuentas/{cuenta_id}",
    response_model=CuentaSocialResponse,
    summary="Actualizar una cuenta social",
)
async def actualizar_cuenta(
    cuenta_id: UUID,
    datos: CuentaSocialUpdate,
    db: DbSession,
    _admin: AdminUser,
) -> CuentaSocialResponse:
    cuenta = await services.obtener_cuenta(db, cuenta_id)
    if cuenta is None:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cuenta social no encontrada",
        )
    cuenta = await services.actualizar_cuenta(db, cuenta, datos)
    return CuentaSocialResponse.model_validate(cuenta)


@router_admin.delete(
    "/cuentas/{cuenta_id}",
    response_model=CuentaSocialResponse,
    summary="Desactivar una cuenta social (soft delete)",
    description="Marca activo=False. Los tokens se conservan pero no se usan.",
)
async def desactivar_cuenta(
    cuenta_id: UUID,
    db: DbSession,
    _admin: AdminUser,
) -> CuentaSocialResponse:
    cuenta = await services.obtener_cuenta(db, cuenta_id)
    if cuenta is None:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cuenta social no encontrada",
        )
    cuenta = await services.desactivar_cuenta(db, cuenta)
    return CuentaSocialResponse.model_validate(cuenta)


# ---------------------------------------------------------
# Config
# ---------------------------------------------------------
@router_admin.get(
    "/config",
    response_model=ConfigSocialResponse,
    summary="Leer la configuración global de publicación",
    description=(
        "Devuelve la config global. Si no existe, la crea con defaults "
        "y la devuelve (así el panel siempre tiene algo editable)."
    ),
)
async def obtener_config(
    db: DbSession,
    _admin: AdminUser,
) -> ConfigSocialResponse:
    cfg = await services.obtener_o_crear_config_global(db)
    return ConfigSocialResponse.model_validate(cfg)


@router_admin.patch(
    "/config",
    response_model=ConfigSocialResponse,
    summary="Actualizar la configuración global",
)
async def actualizar_config(
    datos: ConfigSocialUpdate,
    db: DbSession,
    _admin: AdminUser,
) -> ConfigSocialResponse:
    cfg = await services.obtener_o_crear_config_global(db)
    cfg = await services.actualizar_config(db, cfg, datos)
    return ConfigSocialResponse.model_validate(cfg)


# ---------------------------------------------------------
# Publicaciones
# ---------------------------------------------------------
@router_admin.get(
    "/publicaciones",
    response_model=PublicacionSocialListResponse,
    summary="Listar publicaciones (historial de cola)",
)
async def listar_publicaciones(
    db: DbSession,
    _admin: AdminUser,
    cuenta_id: UUID | None = Query(None),
    estado: EstadoPublicacion | None = Query(None),
    recurso_tipo: str | None = Query(None, max_length=50),
    recurso_id: UUID | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> PublicacionSocialListResponse:
    items, total = await services.listar_publicaciones(
        db,
        cuenta_id=cuenta_id,
        estado=estado,
        recurso_tipo=recurso_tipo,
        recurso_id=recurso_id,
        limit=limit,
        offset=offset,
    )
    return PublicacionSocialListResponse(
        items=[PublicacionSocialResponse.model_validate(p) for p in items],
        meta=PaginacionMeta(total=total, limit=limit, offset=offset),
    )


@router_admin.get(
    "/publicaciones/{publicacion_id}",
    response_model=PublicacionSocialResponse,
    summary="Detalle de una publicación",
)
async def obtener_publicacion(
    publicacion_id: UUID,
    db: DbSession,
    _admin: AdminUser,
) -> PublicacionSocialResponse:
    pub = await services.obtener_publicacion(db, publicacion_id)
    if pub is None:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Publicación no encontrada",
        )
    return PublicacionSocialResponse.model_validate(pub)


@router_admin.post(
    "/publicaciones",
    response_model=PublicacionSocialResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Encolar una publicación manualmente",
    description=(
        "Encola una publicación sin esperar a un evento automático. "
        "Útil para pruebas y para publicar contenido ad-hoc. El worker "
        "(etapa posterior) la procesará."
    ),
)
async def encolar_publicacion(
    datos: PublicacionSocialCreate,
    db: DbSession,
    _admin: AdminUser,
) -> PublicacionSocialResponse:
    pub = await services.encolar_publicacion(db, datos)
    return PublicacionSocialResponse.model_validate(pub)