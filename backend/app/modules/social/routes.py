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

from fastapi import APIRouter, HTTPException, Query, status, Response
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
    summary="Leer la configuración de publicación (global o por propietario)",
    description=(
        "Devuelve la config global si no se pasan propietario_tipo/propietario_id, "
        "o la config individual del prestador/comercio (creandola desde defaults si no existe)."
    ),
)
async def obtener_config(
    db: DbSession,
    _admin: AdminUser,
    propietario_tipo: PropietarioTipo | None = Query(default=None),
    propietario_id: UUID | None = Query(default=None),
) -> ConfigSocialResponse:
    if (propietario_tipo is None) != (propietario_id is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe enviar ambos propietario_tipo y propietario_id, o ninguno.",
        )
    cfg = await services.obtener_o_crear_config(
        db,
        propietario_tipo=propietario_tipo,
        propietario_id=propietario_id,
    )
    return ConfigSocialResponse.model_validate(cfg)


@router_admin.patch(
    "/config",
    response_model=ConfigSocialResponse,
    summary="Actualizar la configuración de publicación (global o por propietario)",
)
async def actualizar_config(
    datos: ConfigSocialUpdate,
    db: DbSession,
    _admin: AdminUser,
    propietario_tipo: PropietarioTipo | None = Query(default=None),
    propietario_id: UUID | None = Query(default=None),
) -> ConfigSocialResponse:
    if (propietario_tipo is None) != (propietario_id is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe enviar ambos propietario_tipo y propietario_id, o ninguno.",
        )
    cfg = await services.obtener_o_crear_config(
        db,
        propietario_tipo=propietario_tipo,
        propietario_id=propietario_id,
    )
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
async def facebook_oauth_url(
    _admin: AdminUser,
    app_redirect: bool = Query(
        False,
        description="Si true, el callback redirige a baqueano://oauth/facebook",
    ),
) -> OAuthUrlResponse:
    url, state = await services.generar_url_oauth(
        _admin, app_redirect=app_redirect,
    )
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
) -> Response:
    from fastapi.responses import RedirectResponse
    try:
        _, token_ref, app_redirect = await services.procesar_callback_oauth(
            code, state,
        )
    except ValueError as e:
        return HTMLResponse(
            status_code=400,
            content=f"<h1>Error</h1><pre>{e}</pre>",
        )

    # Si el flujo inicio con app_redirect=true, redirigir al deep link
    if app_redirect:
        deep_link = f"baqueano://oauth/facebook?token_ref={token_ref}"
        return RedirectResponse(url=deep_link, status_code=302)

    # Si no, devolver el HTML (compatible con flujo manual/Swagger)
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


@router_admin.post(
    "/facebook/admin-token/setup-token",
    response_model=FacebookAdminTokenStatus,
    summary="Configurar admin token de Facebook con access_token directo",
)
async def facebook_admin_token_setup_directo(
    payload: dict,
    db: DbSession,
    _admin: AdminUser,
) -> FacebookAdminTokenStatus:
    raw_token = str(payload.get("access_token") or "")
    try:
        cfg = await services.guardar_admin_token_directo(db, raw_token)
    except ValueError as e:
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



from fastapi import Query, Request
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field
from app.core.config import settings as _social_settings
from app.modules.social import facebook_service as _fb


class _TextoRequest(BaseModel):
    mensaje: str = Field(..., min_length=1, max_length=5000)


class _OcultarComentarioRequest(BaseModel):
    ocultar: bool = True


class _EnviarMensajeRequest(BaseModel):
    recipient_id: str = Field(..., min_length=1, max_length=120)
    texto: str = Field(..., min_length=1, max_length=2000)


async def _resolver_pagina_y_token(db: DbSession, cuenta_id: str) -> tuple[str, str]:
    from uuid import UUID
    from fastapi import HTTPException
    from app.modules.social import services as social_services

    try:
        uid = UUID(cuenta_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="cuenta_id invalido") from exc

    cuenta = await social_services.obtener_cuenta(db, uid)
    if not cuenta:
        raise HTTPException(status_code=404, detail="Cuenta social no encontrada")
    token, _ = await social_services.obtener_token_vigente_de_cuenta(db, cuenta.id)
    if not token:
        raise HTTPException(status_code=400, detail="La cuenta no tiene token vigente")
    return cuenta.external_id, token


def _fb_http_error(err: _fb.FacebookError | None) -> None:
    from fastapi import HTTPException
    if err is not None:
        http_status = (
            status.HTTP_401_UNAUTHORIZED
            if err.code == 190
            else (
                err.http_status
                if isinstance(err.http_status, int) and 400 <= err.http_status < 500
                else status.HTTP_422_UNPROCESSABLE_ENTITY
            )
        )
        raise HTTPException(
            status_code=http_status,
            detail=err.to_dict(),
        )


class _CrearPostFacebookRequest(BaseModel):
    mensaje: str = ""
    link: str | None = None
    image_url: str | None = None


@router_admin.get("/cuentas/{cuenta_id}/facebook/posts", summary="Listar posts de la pagina")
async def fb_listar_posts(
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
    limit: int = Query(20, ge=1, le=100),
) -> dict:
    page_id, token = await _resolver_pagina_y_token(db, cuenta_id)
    items, err = await _fb.listar_posts_pagina(page_id, token, limit=limit)
    _fb_http_error(err)
    return {"items": items}


@router_admin.post("/cuentas/{cuenta_id}/facebook/posts", summary="Publicar post directo en la pagina")
async def fb_crear_post(
    cuenta_id: str,
    data: _CrearPostFacebookRequest,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    page_id, token = await _resolver_pagina_y_token(db, cuenta_id)
    post_id, err = await _fb.publicar_post_en_pagina(
        page_id,
        token,
        mensaje=data.mensaje,
        image_url=data.image_url,
        link=data.link,
    )
    _fb_http_error(err)
    return {"ok": True, "id": post_id}


@router_admin.post("/facebook/posts/{post_id}/editar", summary="Editar texto de un post")
async def fb_editar_post(
    post_id: str,
    data: _TextoRequest,
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    _, token = await _resolver_pagina_y_token(db, cuenta_id)
    ok, err = await _fb.actualizar_post_pagina(post_id, token, data.mensaje)
    _fb_http_error(err)
    return {"ok": ok}


@router_admin.delete("/facebook/posts/{post_id}", summary="Eliminar un post")
async def fb_eliminar_post(
    post_id: str,
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    _, token = await _resolver_pagina_y_token(db, cuenta_id)
    ok, err = await _fb.eliminar_post_pagina(post_id, token)
    _fb_http_error(err)
    return {"ok": ok}


@router_admin.get("/facebook/objetos/{object_id}/comentarios", summary="Listar comentarios")
async def fb_listar_comentarios(
    object_id: str,
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
    limit: int = Query(50, ge=1, le=100),
) -> dict:
    _, token = await _resolver_pagina_y_token(db, cuenta_id)
    items, err = await _fb.listar_comentarios_post(object_id, token, limit=limit)
    _fb_http_error(err)
    return {"items": items}


@router_admin.post("/facebook/objetos/{object_id}/comentarios", summary="Responder o comentar")
async def fb_responder_comentario(
    object_id: str,
    data: _TextoRequest,
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    _, token = await _resolver_pagina_y_token(db, cuenta_id)
    comment_id, err = await _fb.responder_comentario(object_id, token, data.mensaje)
    _fb_http_error(err)
    return {"id": comment_id}


@router_admin.post("/facebook/comentarios/{comment_id}/ocultar", summary="Ocultar o mostrar comentario")
async def fb_ocultar_comentario(
    comment_id: str,
    data: _OcultarComentarioRequest,
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    _, token = await _resolver_pagina_y_token(db, cuenta_id)
    ok, err = await _fb.ocultar_comentario(comment_id, token, ocultar=data.ocultar)
    _fb_http_error(err)
    return {"ok": ok}


@router_admin.delete("/facebook/comentarios/{comment_id}", summary="Eliminar comentario")
async def fb_eliminar_comentario(
    comment_id: str,
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    _, token = await _resolver_pagina_y_token(db, cuenta_id)
    ok, err = await _fb.eliminar_comentario(comment_id, token)
    _fb_http_error(err)
    return {"ok": ok}


@router_admin.get("/cuentas/{cuenta_id}/facebook/conversaciones", summary="Listar conversaciones Inbox")
async def fb_listar_conversaciones(
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
    platform: str = Query("messenger"),
    limit: int = Query(25, ge=1, le=100),
) -> dict:
    page_id, token = await _resolver_pagina_y_token(db, cuenta_id)
    items, err = await _fb.listar_conversaciones_pagina(
        page_id, token, platform=platform, limit=limit
    )
    _fb_http_error(err)
    return {"items": items}


@router_admin.get("/facebook/conversaciones/{conversation_id}/mensajes", summary="Listar mensajes")
async def fb_listar_mensajes(
    conversation_id: str,
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
    limit: int = Query(50, ge=1, le=100),
) -> dict:
    _, token = await _resolver_pagina_y_token(db, cuenta_id)
    items, err = await _fb.listar_mensajes_conversacion(
        conversation_id, token, limit=limit
    )
    _fb_http_error(err)
    return {"items": items}


@router_admin.post("/cuentas/{cuenta_id}/facebook/mensajes", summary="Enviar mensaje desde la pagina")
async def fb_enviar_mensaje(
    cuenta_id: str,
    data: _EnviarMensajeRequest,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    page_id, token = await _resolver_pagina_y_token(db, cuenta_id)
    msg_id, err = await _fb.enviar_mensaje_pagina(
        page_id, token, recipient_id=data.recipient_id, texto=data.texto
    )
    _fb_http_error(err)
    return {"message_id": msg_id}


@router_admin.get("/cuentas/{cuenta_id}/facebook/insights", summary="Metricas de la pagina")
async def fb_insights(
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
    period: str = Query("day"),
) -> dict:
    page_id, token = await _resolver_pagina_y_token(db, cuenta_id)
    items, err = await _fb.obtener_insights_pagina(page_id, token, period=period)
    _fb_http_error(err)
    return {"items": items}


@router_admin.post("/cuentas/{cuenta_id}/facebook/suscribir-webhook", summary="Suscribir pagina a webhooks")
async def fb_suscribir_webhook(
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    page_id, token = await _resolver_pagina_y_token(db, cuenta_id)
    info, err = await _fb.suscribir_webhooks_pagina(page_id, token)
    _fb_http_error(err)
    return {"ok": info.get("ok", True), **info}


@router_admin.delete("/cuentas/{cuenta_id}/facebook/suscribir-webhook", summary="Desuscribir pagina de webhooks")
async def fb_desuscribir_webhook(
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    page_id, token = await _resolver_pagina_y_token(db, cuenta_id)
    ok, err = await _fb.desuscribir_webhooks_pagina(page_id, token)
    _fb_http_error(err)
    return {"ok": ok}


class _ActualizarConfigPaginaRequest(BaseModel):
    about: str | None = None
    phone: str | None = None
    website: str | None = None
    auto_publish: bool | None = None


@router_admin.get("/cuentas/{cuenta_id}/facebook/configuracion", summary="Configuracion de la pagina")
async def fb_obtener_configuracion(
    cuenta_id: str,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    import uuid as _uuid
    from app.modules.social import services as _svc
    cuenta = await _svc.obtener_cuenta(db, _uuid.UUID(cuenta_id))
    page_id, token = await _resolver_pagina_y_token(db, cuenta_id)
    admin_token = await _svc.obtener_admin_token(db)
    cfg_data, err = await _fb.obtener_configuracion_pagina(
        page_id, token, admin_token=admin_token
    )
    _fb_http_error(err)
    return {
        "cuenta_id": str(cuenta.id),
        "external_id": cuenta.external_id,
        "auto_publish": bool(cuenta.auto_publish),
        **cfg_data,
    }


@router_admin.patch("/cuentas/{cuenta_id}/facebook/configuracion", summary="Actualizar configuracion de la pagina")
async def fb_actualizar_configuracion(
    cuenta_id: str,
    data: _ActualizarConfigPaginaRequest,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    import uuid as _uuid
    from app.modules.social import services as _svc
    cuenta = await _svc.obtener_cuenta(db, _uuid.UUID(cuenta_id))
    page_id, token = await _resolver_pagina_y_token(db, cuenta_id)

    if data.auto_publish is not None:
        cuenta.auto_publish = data.auto_publish
        await db.flush()
        await db.commit()

    has_page_updates = any(
        val is not None for val in (data.about, data.phone, data.website)
    )
    if has_page_updates:
        ok, err = await _fb.actualizar_configuracion_pagina(
            page_id,
            token,
            about=data.about,
            phone=data.phone,
            website=data.website,
        )
        _fb_http_error(err)
        return {"ok": ok, "auto_publish": bool(cuenta.auto_publish)}

    return {"ok": True, "auto_publish": bool(cuenta.auto_publish)}


@router_admin.get("/facebook/webhook", summary="Verificacion webhook Meta")
async def fb_webhook_verify(
    hub_mode: str = Query("", alias="hub.mode"),
    hub_verify_token: str = Query("", alias="hub.verify_token"),
    hub_challenge: str = Query("", alias="hub.challenge"),
) -> PlainTextResponse:
    from fastapi import HTTPException
    expected = _social_settings.FACEBOOK_WEBHOOK_VERIFY_TOKEN
    if hub_mode == "subscribe" and expected and hub_verify_token == expected:
        return PlainTextResponse(content=hub_challenge, status_code=200)
    raise HTTPException(status_code=403, detail="Verificacion de webhook invalida")


@router_admin.post("/facebook/webhook", summary="Recepcion de eventos de webhook Meta")
async def fb_webhook_event(request: Request) -> dict:
    payload = await request.json()
    entries = len(payload.get("entry", [])) if isinstance(payload, dict) else 0
    return {"received": True, "entries": entries}


# =========================================================
# Trazabilidad de compartidos por grupo / envío individual
# =========================================================
import re as _re
import secrets as _secrets
from datetime import datetime as _dt, timezone as _tz
from typing import Literal as _Literal
from urllib.parse import parse_qsl as _parse_qsl, urlencode as _urlencode, urlsplit as _urlsplit, urlunsplit as _urlunsplit
from sqlalchemy import desc as _desc, select as _select
from app.modules.social.models import SocialShareTracking as _ShareTrack

_COOLDOWN_SEGUNDOS = 1500  # 25 minutos entre compartidos en grupos externos


def _slug_grupo(nombre: str) -> str:
    limpio = _re.sub(r"[^a-z0-9]+", "_", nombre.strip().lower()).strip("_")
    return (limpio[:90] or "grupo_externo")


def _construir_url_utm(base_url: str, grupo_slug: str, share_id: str) -> str:
    limpia = (base_url or "https://sealquilamarido.com/mecanica").strip()
    if not limpia.startswith("http") or "facebook.com/" in limpia.lower() or "fb.com/" in limpia.lower():
        limpia = "https://sealquilamarido.com/mecanica"
    parts = _urlsplit(limpia)
    params = dict(_parse_qsl(parts.query, keep_blank_values=True))
    params["utm_source"] = "facebook"
    params["utm_medium"] = "grupo"
    params["utm_campaign"] = "natales_mecanica"
    params["utm_content"] = grupo_slug
    params["utm_term"] = share_id
    return _urlunsplit((parts.scheme, parts.netloc, parts.path, _urlencode(params), parts.fragment))


class _RegistrarCompartidoRequest(BaseModel):
    publicacion_id: str | None = None
    red: str = Field("facebook", max_length=32)
    grupo_nombre: str = Field(..., min_length=2, max_length=160)
    url_base: str = Field("https://sealquilamarido.com/mecanica", max_length=1000)


class _ConfirmarCompartidoRequest(BaseModel):
    estado_reportado: _Literal["publicado", "pendiente_aprobacion", "cancelado"]


class _EventoCompartidoRequest(BaseModel):
    share_id: str | None = Field(default=None, max_length=64)
    utm_content: str | None = Field(default=None, max_length=120)
    evento: _Literal["visita", "clic_whatsapp", "reserva_abierta", "reserva_enviada"]


def _serializar_share(row: _ShareTrack) -> dict:
    return {
        "id": str(row.id),
        "share_id": row.share_id,
        "publicacion_id": str(row.publicacion_id) if row.publicacion_id else None,
        "red": row.red,
        "grupo_nombre": row.grupo_nombre,
        "grupo_slug": row.grupo_slug,
        "url_compartida": row.url_compartida,
        "estado_reportado": row.estado_reportado,
        "confirmado_en": row.confirmado_en.isoformat() if row.confirmado_en else None,
        "visitas": row.visitas,
        "clics_whatsapp": row.clics_whatsapp,
        "reservas_iniciadas": row.reservas_iniciadas,
        "reservas_enviadas": row.reservas_enviadas,
        "ultima_interaccion_en": row.ultima_interaccion_en.isoformat() if row.ultima_interaccion_en else None,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


@router_admin.get("/compartidos", summary="Listar trazabilidad de compartidos")
async def listar_compartidos(
    db: DbSession,
    _admin: AdminUser,
    publicacion_id: str | None = Query(default=None),
    grupo_slug: str | None = Query(default=None),
    limit: int = Query(50, ge=1, le=200),
) -> dict:
    stmt = _select(_ShareTrack).order_by(_desc(_ShareTrack.created_at)).limit(limit)
    if publicacion_id:
        try:
            stmt = stmt.where(_ShareTrack.publicacion_id == UUID(publicacion_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="publicacion_id invalido")
    if grupo_slug:
        stmt = stmt.where(_ShareTrack.grupo_slug == grupo_slug.strip().lower())

    res = await db.execute(stmt)
    rows = list(res.scalars().all())

    ultimo_stmt = _select(_ShareTrack).order_by(_desc(_ShareTrack.created_at)).limit(1)
    ultimo = (await db.execute(ultimo_stmt)).scalar_one_or_none()
    segundos_restantes = 0
    if ultimo and ultimo.created_at:
        transcurridos = int((_dt.now(_tz.utc) - ultimo.created_at).total_seconds())
        if transcurridos < _COOLDOWN_SEGUNDOS:
            segundos_restantes = _COOLDOWN_SEGUNDOS - transcurridos

    return {
        "items": [_serializar_share(r) for r in rows],
        "cooldown_segundos_restantes": segundos_restantes,
    }


@router_admin.post("/compartidos", status_code=status.HTTP_201_CREATED, summary="Registrar inicio de compartir con trazabilidad")
async def registrar_compartido(
    data: _RegistrarCompartidoRequest,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    pub_uuid: UUID | None = None
    if data.publicacion_id:
        try:
            pub_uuid = UUID(data.publicacion_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="publicacion_id invalido")

    ahora = _dt.now(_tz.utc)
    ultimo = (await db.execute(_select(_ShareTrack).order_by(_desc(_ShareTrack.created_at)).limit(1))).scalar_one_or_none()
    segundos_restantes = 0
    if ultimo and ultimo.created_at:
        transcurridos = int((ahora - ultimo.created_at).total_seconds())
        if transcurridos < _COOLDOWN_SEGUNDOS:
            segundos_restantes = _COOLDOWN_SEGUNDOS - transcurridos

    sufijo = _secrets.token_hex(2).upper()
    share_id = f"sh_{ahora.strftime('%Y%m%d_%H%M%S')}_{sufijo}"
    grupo_nombre = data.grupo_nombre.strip()
    grupo_slug = _slug_grupo(grupo_nombre)
    url_utm = _construir_url_utm(data.url_base, grupo_slug, share_id)

    row = _ShareTrack(
        share_id=share_id,
        publicacion_id=pub_uuid,
        red=(data.red or "facebook").strip().lower(),
        grupo_nombre=grupo_nombre,
        grupo_slug=grupo_slug,
        url_compartida=url_utm,
        estado_reportado="pendiente_confirmacion",
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    payload = _serializar_share(row)
    payload["cooldown_segundos_restantes"] = segundos_restantes
    return payload


@router_admin.patch("/compartidos/{share_id}/confirmar", summary="Confirmar resultado del compartir al volver de la red")
async def confirmar_compartido(
    share_id: str,
    data: _ConfirmarCompartidoRequest,
    db: DbSession,
    _admin: AdminUser,
) -> dict:
    row = (await db.execute(_select(_ShareTrack).where(_ShareTrack.share_id == share_id.strip()))).scalar_one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Registro de compartido no encontrado")
    row.estado_reportado = data.estado_reportado
    row.confirmado_en = _dt.now(_tz.utc)
    await db.commit()
    await db.refresh(row)
    return _serializar_share(row)


router_publico_compartidos = APIRouter(prefix="/social", tags=["social-public"])


@router_publico_compartidos.post("/compartidos/evento", summary="Registrar interacción en landing asociada a un share_id")
async def registrar_evento_compartido(
    data: _EventoCompartidoRequest,
    db: DbSession,
) -> dict:
    row: _ShareTrack | None = None
    if data.share_id:
        row = (await db.execute(_select(_ShareTrack).where(_ShareTrack.share_id == data.share_id.strip()))).scalar_one_or_none()
    if not row and data.utm_content:
        row = (
            await db.execute(
                _select(_ShareTrack)
                .where(_ShareTrack.grupo_slug == data.utm_content.strip().lower())
                .order_by(_desc(_ShareTrack.created_at))
                .limit(1)
            )
        ).scalar_one_or_none()

    if not row:
        return {"ok": True, "matched": False}

    if data.evento == "visita":
        row.visitas = (row.visitas or 0) + 1
    elif data.evento == "clic_whatsapp":
        row.clics_whatsapp = (row.clics_whatsapp or 0) + 1
    elif data.evento == "reserva_abierta":
        row.reservas_iniciadas = (row.reservas_iniciadas or 0) + 1
    elif data.evento == "reserva_enviada":
        row.reservas_enviadas = (row.reservas_enviadas or 0) + 1

    row.ultima_interaccion_en = _dt.now(_tz.utc)
    await db.commit()
    return {"ok": True, "matched": True, "share_id": row.share_id}
