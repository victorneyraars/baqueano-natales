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

from fastapi import APIRouter, HTTPException, Query, status
from fastapi.responses import HTMLResponse

from app.core.db import DbSession
from app.modules.social import services, worker
from app.modules.social.deps import AdminUser
from app.modules.social.models import (
    EstadoPublicacion,
    PropietarioTipo,
    Red,
)
from app.modules.social.schemas import (
    ConectarCuentaRequest,
    ConectarCuentaResponse,
    ConfigSocialResponse,
    ConfigSocialUpdate,
    CuentaSocialCreate,
    CuentaSocialListResponse,
    CuentaSocialResponse,
    CuentaSocialUpdate,
    ListarPaginasRequest,
    ListarPaginasResponse,
    OAuthUrlResponse,
    PaginacionMeta,
    PublicacionSocialCreate,
    PublicacionSocialListResponse,
    PublicacionSocialResponse,
    FacebookAdminTokenSetup,
    FacebookAdminTokenStatus,
    ConectarPaginaDirectoRequest,
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
    await db.refresh(cuenta)
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
    await db.refresh(cuenta)
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
    await db.refresh(cfg)
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
    red: Red | None = Query(None),
    recurso_tipo: str | None = Query(None, max_length=50),
    recurso_id: UUID | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> PublicacionSocialListResponse:
    items, total = await services.listar_publicaciones(
        db,
        cuenta_id=cuenta_id,
        estado=estado,
        red=red,
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


@router_admin.patch(
    "/publicaciones/{publicacion_id}/reencolar",
    response_model=PublicacionSocialResponse,
    summary="Reencolar una publicacion (resetear para reintento)",
    description=(
        "Resetea la publicacion a PENDIENTE, limpia intentos y error, "
        "y la deja lista para que el worker la procese en el proximo "
        "ciclo (o cuando se llame a procesar-ahora)."
    ),
)
async def reencolar_publicacion(
    publicacion_id: UUID,
    db: DbSession,
    _admin: AdminUser,
) -> PublicacionSocialResponse:
    pub = await services.obtener_publicacion(db, publicacion_id)
    if pub is None:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Publicacion no encontrada",
        )
    try:
        pub = await services.reencolar_publicacion(db, pub)
    except ValueError as e:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
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

# =========================================================
# Facebook OAuth (Etapa 2)
# =========================================================

_CALLBACK_HTML = """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>Facebook autorizado</title>
  <style>
    body {{ font-family: -apple-system, sans-serif; max-width: 640px;
            margin: 40px auto; padding: 0 20px; color: #1a1a1a; }}
    h1 {{ color: #16a34a; }}
    pre {{ background: #f4f4f5; padding: 16px; border-radius: 8px;
           overflow-x: auto; font-size: 13px; word-break: break-all;
           white-space: pre-wrap; }}
    code {{ background: #f4f4f5; padding: 2px 6px; border-radius: 4px;
            font-size: 13px; }}
    .paso {{ background: #fffbeb; border-left: 4px solid #f59e0b;
             padding: 12px 16px; border-radius: 4px; margin: 16px 0; }}
  </style>
</head>
<body>
  <h1>Facebook autorizado</h1>
  <p>Copia este <strong>token_ref</strong> (expira en 15 minutos):</p>
  <pre id="tr">{token_ref}</pre>
  <div class="paso">
    <strong>Siguiente paso:</strong><br>
    <code>POST /api/v1/admin/social/facebook/pages</code><br>
    con body <code>{{"token_ref": "..."}}</code> para listar tus paginas.
  </div>
</body>
</html>"""


@router_admin.get(
    "/facebook/oauth/url",
    response_model=OAuthUrlResponse,
    summary="Iniciar OAuth con Facebook",
    description=(
        "Devuelve la URL del dialogo de Facebook y el state (10 min). "
        "El admin debe abrir `url` en el navegador."
    ),
)
async def facebook_oauth_url(_admin: AdminUser) -> OAuthUrlResponse:
    url, state = await services.generar_url_oauth(_admin)
    return OAuthUrlResponse(url=url, state=state)


@router_admin.get(
    "/facebook/oauth/callback",
    response_class=HTMLResponse,
    summary="Callback de Facebook (lo abre el navegador)",
    description=(
        "Facebook redirige aca tras la autorizacion. NO requiere auth: "
        "el state firmado prueba la identidad del admin que inicio el flujo. "
        "Devuelve HTML con el token_ref para el siguiente paso."
    ),
)
async def facebook_oauth_callback(
    code: str = Query(..., min_length=5),
    state: str = Query(..., min_length=10),
) -> HTMLResponse:
    try:
        _, token_ref = await services.procesar_callback_oauth(code, state)
    except ValueError as e:
        return HTMLResponse(
            status_code=400,
            content=f"<h1>Error</h1><pre>{e}</pre>",
        )
    return HTMLResponse(content=_CALLBACK_HTML.format(token_ref=token_ref))


@router_admin.post(
    "/facebook/pages",
    response_model=ListarPaginasResponse,
    summary="Listar paginas del usuario en Facebook",
    description=(
        "Lista las paginas del usuario con el page access token derivado "
        "del token_ref. Marca cuales ya estan conectadas al sistema."
    ),
)
async def facebook_listar_paginas(
    body: ListarPaginasRequest,
    db: DbSession,
    _admin: AdminUser,
) -> ListarPaginasResponse:
    try:
        paginas = await services.listar_paginas_disponibles(db, body.token_ref)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        )
    return ListarPaginasResponse(paginas=paginas)


@router_admin.post(
    "/facebook/conectar",
    response_model=ConectarCuentaResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Conectar una pagina de Facebook al sistema",
    description=(
        "Crea (o actualiza) una cuenta social y guarda el page access "
        "token cifrado. Si la pagina ya existe, rota el token."
    ),
)
async def facebook_conectar(
    body: ConectarCuentaRequest,
    db: DbSession,
    _admin: AdminUser,
) -> ConectarCuentaResponse:
    try:
        cuenta, nombre = await services.conectar_cuenta_facebook(
            db=db,
            user=_admin,
            token_ref=body.token_ref,
            page_id=body.page_id,
            propietario_tipo=body.propietario_tipo,
            propietario_id=body.propietario_id,
            alias=body.alias,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        )
    return ConectarCuentaResponse(cuenta=cuenta, nombre_pagina=nombre)

# =========================================================
# Worker de publicaciones (Etapa 3)
# =========================================================

@router_admin.post(
    "/publicaciones/procesar-ahora",
    summary="Ejecutar un ciclo del worker de publicaciones ahora",
    description=(
        "Ejecuta un ciclo del worker (procesa publicaciones PENDIENTES "
        "listas). Devuelve stats del ciclo. Util para smoke tests y "
        "reintentos manuales tras un fix."
    ),
)
async def procesar_cola_ahora(_admin: AdminUser) -> dict:
    return await worker.ejecutar_ciclo_manual()



@router_admin.patch(
    "/cuentas/{cuenta_id}/toggle-auto-publish",
    response_model=CuentaSocialResponse,
    summary="Activar/desactivar publicacion automatica por cuenta",
)
async def toggle_auto_publish(
    cuenta_id: UUID,
    activo: bool,
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
    cuenta.auto_publish = activo
    await db.commit()
    await db.refresh(cuenta)
    return CuentaSocialResponse.model_validate(cuenta)

# =========================================================
# Admin token de Facebook (setup escalable)
# =========================================================

@router_admin.get(
    "/facebook/admin-token/status",
    response_model=FacebookAdminTokenStatus,
    summary="Estado del admin token de Facebook",
    description=(
        "Indica si hay un admin token guardado. NO expone el token. "
        "La app usa esto para saber si mostrar 'Configurar' o 'Agregar cuenta'."
    ),
)
async def facebook_admin_token_status(
    db: DbSession,
    _admin: AdminUser,
) -> FacebookAdminTokenStatus:
    from app.modules.social import services as social_services
    cfg = await social_services.obtener_config(db)
    return FacebookAdminTokenStatus(
        has_token=bool(cfg and cfg.facebook_admin_token),
        updated_at=cfg.facebook_admin_token_updated_at if cfg else None,
    )


@router_admin.post(
    "/facebook/admin-token/setup",
    response_model=FacebookAdminTokenStatus,
    summary="Configurar admin token de Facebook (setup inicial)",
    description=(
        "Recibe un token_ref del OAuth, extrae el user_access_token, "
        "lo cifra y lo guarda en la config global. "
        "Despues de esto, el admin puede conectar paginas sin re-autenticarse."
    ),
)
async def facebook_admin_token_setup(
    data: FacebookAdminTokenSetup,
    db: DbSession,
    _admin: AdminUser,
) -> FacebookAdminTokenStatus:
    from app.modules.social import services as social_services
    try:
        cfg = await social_services.guardar_admin_token(db, data.token_ref)
    except ValueError as e:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        )
    await db.commit()
    await db.refresh(cfg)
    return FacebookAdminTokenStatus(
        has_token=True,
        updated_at=cfg.facebook_admin_token_updated_at,
    )


@router_admin.get(
    "/facebook/paginas",
    response_model=ListarPaginasResponse,
    summary="Listar paginas del admin (usando admin token guardado)",
    description=(
        "Lista las paginas de Facebook usando el admin token guardado. "
        "No requiere token_ref. Marca cuales ya estan conectadas."
    ),
)
async def facebook_listar_paginas_admin(
    db: DbSession,
    _admin: AdminUser,
) -> ListarPaginasResponse:
    from app.modules.social import services as social_services
    try:
        paginas = await social_services.listar_paginas_admin(db)
    except ValueError as e:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        )
    return ListarPaginasResponse(paginas=paginas)


@router_admin.post(
    "/facebook/conectar-directo",
    response_model=ConectarCuentaResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Conectar pagina usando admin token guardado",
    description=(
        "Conecta una pagina de Facebook usando el admin token guardado. "
        "No requiere token_ref."
    ),
)
async def facebook_conectar_directo(
    data: ConectarPaginaDirectoRequest,
    db: DbSession,
    _admin: AdminUser,
) -> ConectarCuentaResponse:
    from app.modules.social import services as social_services
    try:
        cuenta, nombre = await social_services.conectar_cuenta_admin(
            db=db,
            user=_admin,
            page_id=data.page_id,
            propietario_tipo=data.propietario_tipo,
            propietario_id=data.propietario_id,
            alias=data.alias,
        )
    except ValueError as e:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        )
    await db.commit()
    return ConectarCuentaResponse(cuenta=cuenta, nombre_pagina=nombre)

