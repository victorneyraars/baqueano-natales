"""
Endpoints HTTP del módulo prestadores.

Dividido en 4 routers:
- router_publico: listado/detalle público + categorías activas.
- router_propietario: gestión por el dueño (/mis-prestadores).
- router_admin_prestadores: gestión admin (/admin/prestadores).
- router_admin_categorias: CRUD admin de categorías
  (/admin/categorias-oficio).
"""
import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, HTTPException, Query, Request, status
from pydantic import BaseModel, EmailStr

from app.core.db import DbSession
from app.modules.auth.deps import AdminUser, CurrentUser
from app.modules.prestadores import services
from app.modules.prestadores.whatsapp import build_whatsapp_info
from app.modules.prestadores.deps import PrestadorOwner, PrestadorPropietario
from app.modules.social import eventos_prestadores as social_eventos
from app.modules.prestadores.models import EstadoPrestador, PrestadorAuditLog
from app.modules.prestadores.audit_service import log_audit
from app.modules.notificaciones.colaboradores import (
    notificar_invitacion_colaborador,
)
from app.modules.notificaciones.tokens import (
    generar_token_invitacion,
    validar_token_invitacion,
)
from datetime import datetime, timezone
from sqlalchemy import func, select
from sqlalchemy.orm.attributes import flag_modified
import jwt
from app.modules.prestadores.schemas import (
    AuditLogEntry,
    AuditLogPage,
    ColaboradorInviteRequest,
    ColaboradorPermisosUpdate,
    ColaboradorResponse,
    CategoriaOficioCreate,
    CategoriaOficioResponse,
    CategoriaOficioUpdate,
    PaginacionMeta,
    PrestadorCreate,
    PrestadorDetalleResponse,
    PrestadorDestacarRequest,
    PrestadorListResponse,
    PrestadorPrivadoListResponse,
    PrestadorPrivadoResponse,
    PrestadorPublicoResponse,
    PrestadorRechazarRequest,
    PrestadorServicioCreate,
    PrestadorServicioResponse,
    PrestadorServicioUpdate,
    ModalidadesResponse,
    ModalidadesUpdateRequest,
    PrestadorServiciosBulkUpdate,
    PrestadorUpdate,
    PrestadorVerificarRequest,
)

logger = logging.getLogger(__name__)


# =========================================================
# Público
# =========================================================
router_publico = APIRouter(prefix="/prestadores", tags=["prestadores"])


@router_publico.get(
    "/categorias",
    response_model=list[CategoriaOficioResponse],
    summary="Listar categorías activas de oficios",
    description="Categorías activas para filtros y selección en el cliente.",
)
async def listar_categorias_publicas(
    db: DbSession,
) -> list[CategoriaOficioResponse]:
    categorias = await services.listar_categorias(db, solo_activas=True)
    return [CategoriaOficioResponse.model_validate(c) for c in categorias]


@router_publico.get(
    "",
    response_model=PrestadorListResponse,
    summary="Listar prestadores verificados",
    description="Listado público con filtros y paginación.",
)
async def listar_prestadores_publicos(
    db: DbSession,
    categoria_id: UUID | None = Query(None, description="Filtrar por categoría"),
    q: str | None = Query(
        None,
        description="Búsqueda por nombre o descripción",
        max_length=100,
    ),
    destacados: bool | None = Query(None, description="Solo destacados"),
    domicilio: bool | None = Query(
        None, description="Solo los que atienden a domicilio"
    ),
    emergencias: bool | None = Query(
        None, description="Solo los que atienden emergencias"
    ),
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> PrestadorListResponse:
    items, total = await services.listar_prestadores_publicos(
        db,
        categoria_id=categoria_id,
        busqueda=q,
        solo_destacados=destacados or False,
        atiende_domicilio=domicilio,
        atiende_emergencias=emergencias,
        page=page,
        page_size=page_size,
    )
    total_pages = (total + page_size - 1) // page_size
    return PrestadorListResponse(
        items=[PrestadorPublicoResponse.model_validate(p) for p in items],
        meta=PaginacionMeta(
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        ),
    )


@router_publico.get(
    "/{slug}/perfil-completo",
    summary="Perfil publico completo (web, GBP, JSON-LD)",
    description=(
        "Devuelve TODO lo que cualquier servicio externo necesita: "
        "NAP consistente, JSON-LD, GBP, WhatsApp, Open Graph y PWA. "
        "Fuente unica de verdad de los datos del prestador."
    ),
)
async def obtener_perfil_completo(slug: str, db: DbSession) -> dict:
    perfil = await services.get_perfil_completo(db, slug)
    if perfil is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Prestador no encontrado: {slug}",
        )
    return perfil


@router_publico.get(
    "/{slug}",
    response_model=PrestadorDetalleResponse,
    summary="Detalle público de un prestador",
    description=(
        "Detalle completo con contacto, servicios y galería "
        "de un prestador verificado."
    ),
)
async def obtener_prestador(
    slug: str,
    db: DbSession,
) -> PrestadorDetalleResponse:
    prestador = await services.obtener_prestador_por_slug(db, slug)
    response = PrestadorDetalleResponse.model_validate(prestador)
    categoria_slug = prestador.categoria.slug if prestador.categoria else None
    response.whatsapp_info = build_whatsapp_info(prestador, categoria_slug)
    return response


# =========================================================
# Propietario
# =========================================================
router_propietario = APIRouter(
    prefix="/mis-prestadores", tags=["mis-prestadores"]
)


@router_propietario.post(
    "",
    response_model=PrestadorPrivadoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear prestador",
    description="Crea un prestador en estado 'borrador'.",
)
async def crear_mi_prestador(
    data: PrestadorCreate,
    user: CurrentUser,
    db: DbSession,
) -> PrestadorPrivadoResponse:
    from app.modules.admin.services import obtener_onboarding_mode
    modo = await obtener_onboarding_mode(db)
    if modo == "closed":
        raise HTTPException(
            status_code=403,
            detail="El registro de prestadores está cerrado temporalmente.",
        )
    prestador = await services.crear_prestador(db, user, data)
    await db.refresh(prestador)
    return PrestadorPrivadoResponse.model_validate(prestador)


@router_publico.get(
    "/{prestador_id}/servicios",
    summary="Listar servicios activos de un prestador",
)
async def listar_servicios_publicos(
    prestador_id: UUID,
    db: DbSession,
):
    servicios = await services.listar_servicios_activos(db, prestador_id)
    return [
        {
            "id": str(s.id),
            "nombre": s.nombre,
            "descripcion": s.descripcion,
            "categoria_servicio": s.categoria_servicio,
            "precio_desde_clp": s.precio_desde_clp,
            "precio_hasta_clp": s.precio_hasta_clp,
            "duracion_estimada_min": s.duracion_estimada_min,
            "garantia_dias": s.garantia_dias,
            "destacado": s.destacado,
        }
        for s in servicios
    ]


@router_propietario.get(
    "",
    response_model=PrestadorPrivadoListResponse,
    summary="Listar mis prestadores",
    description="Devuelve todos los prestadores del usuario (cualquier estado).",
)
async def listar_mis_prestadores(
    user: CurrentUser,
    db: DbSession,
) -> PrestadorPrivadoListResponse:
    items = await services.listar_prestadores_mios(db, user)
    items_serialized = []
    for p in items:
        resp = PrestadorPrivadoResponse.model_validate(p)
        from app.modules.auth.models import RolUsuario as _Rol
        resp.es_owner = (str(user.id) == str(p.usuario_id)) or (user.rol == _Rol.ADMIN)
        items_serialized.append(resp)
    return PrestadorPrivadoListResponse(
        items=items_serialized,
        meta=PaginacionMeta(
            total=len(items),
            page=1,
            page_size=len(items) or 1,
            total_pages=1,
        ),
    )


@router_propietario.get(
    "/{prestador_id}",
    response_model=PrestadorPrivadoResponse,
    summary="Detalle de mi prestador",
)
async def obtener_mi_prestador(
    prestador: PrestadorPropietario,
    user: CurrentUser,
) -> PrestadorPrivadoResponse:
    resp = PrestadorPrivadoResponse.model_validate(prestador)
    from app.modules.auth.models import RolUsuario as _Rol
    resp.es_owner = (str(user.id) == str(prestador.usuario_id)) or (user.rol == _Rol.ADMIN)
    return resp


@router_propietario.patch(
    "/{prestador_id}",
    response_model=PrestadorPrivadoResponse,
    summary="Editar mi prestador",
)
async def editar_mi_prestador(
    prestador: PrestadorPropietario,
    data: PrestadorUpdate,
    db: DbSession,
) -> PrestadorPrivadoResponse:
    prestador = await services.editar_prestador(db, prestador, data)
    return PrestadorPrivadoResponse.model_validate(prestador)


@router_propietario.delete(
    "/{prestador_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar mi prestador",
    description="Soft-delete: marca el prestador como inactivo.",
)
async def eliminar_mi_prestador(
    prestador: PrestadorPropietario,
    db: DbSession,
) -> None:
    await services.eliminar_prestador(db, prestador)


@router_propietario.post(
    "/{prestador_id}/enviar-revision",
    response_model=PrestadorPrivadoResponse,
    summary="Enviar a revisión",
    description="Cambia el estado de borrador/rechazado a 'pendiente'.",
)
async def enviar_a_revision(
    prestador: PrestadorPropietario,
    db: DbSession,
) -> PrestadorPrivadoResponse:
    prestador = await services.enviar_a_revision(db, prestador)
    return PrestadorPrivadoResponse.model_validate(prestador)


# ---------------------------------------------------------
# Servicios del catálogo (dueño)
# ---------------------------------------------------------
@router_propietario.put(
    "/{prestador_id}/servicios",
    response_model=list[PrestadorServicioResponse],
    summary="Reemplazar catálogo de servicios",
    description="Reemplaza TODOS los servicios del prestador (bulk).",
)
async def setear_servicios_mi_prestador(
    prestador: PrestadorPropietario,
    data: PrestadorServiciosBulkUpdate,
    db: DbSession,
) -> list[PrestadorServicioResponse]:
    nuevos = await services.setear_servicios(db, prestador, data.servicios)
    return [PrestadorServicioResponse.model_validate(s) for s in nuevos]




@router_publico.post(
    "/invitaciones/aceptar",
    summary="Aceptar invitación a colaborar (Magic Link)",
)
async def aceptar_invitacion_publica(
    data: dict,
    db: DbSession,
):
    from app.modules.auth.models import Usuario
    from app.modules.auth.schemas import UsuarioResponse
    from app.core.security import create_access_token
    from app.modules.notificaciones.tokens import validar_token_invitacion

    token = data.get("token")
    if not token:
        raise HTTPException(400, "Token requerido")

    try:
        payload = validar_token_invitacion(token)
    except Exception as e:
        raise HTTPException(400, f"Token inválido o expirado: {e}")

    email = payload.get("email")
    prestador_id = payload.get("prestador_id")
    if not email or not prestador_id:
        raise HTTPException(400, "Token incompleto")

    res = await db.execute(select(Usuario).where(Usuario.email == email))
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(
            404,
            "No tenés cuenta de Baqueano con ese email. Registrate primero en la app.",
        )

    prestador = await services.obtener_prestador_por_id(db, UUID(prestador_id))
    if not prestador:
        raise HTTPException(404, "Prestador no encontrado")

    # Si el usuario es el OWNER del prestador, no hay nada que "activar":
    # solo generamos el token de acceso. Esto permite "Magic Links" de login
    # para el dueño (útil cuando Firebase falla en algunos navegadores).
    if str(user.id) == str(prestador.usuario_id):
        access_token = create_access_token(str(user.id))
        return {
            "access_token": access_token,
            "user": UsuarioResponse.model_validate(user).model_dump(mode="json"),
        }

    colaboradores = prestador.colaboradores or []
    encontrado = False
    for c in colaboradores:
        if c.get("email") == email:
            if not c.get("activado_at"):
                c["activado_at"] = datetime.now(timezone.utc).isoformat()
            if "permisos" not in c:
                c["permisos"] = []
            encontrado = True
            break
    if not encontrado:
        raise HTTPException(404, "No existe una invitación pendiente para ese email")
    prestador.colaboradores = colaboradores
    flag_modified(prestador, "colaboradores")

    await log_audit(
        db=db,
        prestador_id=prestador.id,
        user=user,
        accion="colaborador_activado",
        entidad="colaborador",
        entidad_id=email,
        metadata={"email": email},
        ip=None,
        user_agent=None,
    )

    await db.commit()

    access_token = create_access_token(str(user.id))

    return {
        "access_token": access_token,
        "user": UsuarioResponse.model_validate(user).model_dump(mode="json"),
    }



@router_propietario.get(
    "/{prestador_id}/publicaciones",
    summary="Publicaciones en redes del prestador",
    description=(
        "Lista las publicaciones en redes sociales relacionadas con el "
        "prestador (su alta como prestador + los servicios agregados). "
        "Solo el due?o o un admin pueden consultarla."
    ),
)
async def publicaciones_de_mi_prestador(
    prestador: PrestadorPropietario,
    db: DbSession,
) -> dict:
    from app.modules.social import services as social_services
    from app.modules.social.schemas import PublicacionSocialResponse

    pubs = await social_services.listar_publicaciones_de_prestador(
        db, prestador.id
    )
    return {
        "items": [
            PublicacionSocialResponse.model_validate(p).model_dump(mode="json")
            for p in pubs
        ],
        "meta": {
            "total": len(pubs),
            "limit": len(pubs),
            "offset": 0,
        },
    }


@router_propietario.post(
    "/{prestador_id}/servicios",
    response_model=PrestadorServicioResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar servicio al catálogo",
)
async def agregar_servicio_mi_prestador(
    prestador: PrestadorPropietario,
    data: PrestadorServicioCreate,
    db: DbSession,
) -> PrestadorServicioResponse:
    srv = await services.agregar_servicio(db, prestador, data)
    # Best-effort: encolar publicacion para redes (Etapa 5)
    await social_eventos.encolar_servicio_nuevo(db, prestador, srv)
    return PrestadorServicioResponse.model_validate(srv)


@router_propietario.patch(
    "/{prestador_id}/servicios/{servicio_id}",
    response_model=PrestadorServicioResponse,
    summary="Editar servicio del catálogo",
)
async def editar_servicio_mi_prestador(
    prestador: PrestadorPropietario,
    servicio_id: UUID,
    data: PrestadorServicioUpdate,
    db: DbSession,
) -> PrestadorServicioResponse:
    srv = await services.obtener_servicio(db, servicio_id)
    if srv.prestador_id != prestador.id:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Servicio no encontrado para este prestador",
        )
    srv = await services.editar_servicio(db, srv, data)
    return PrestadorServicioResponse.model_validate(srv)


@router_propietario.delete(
    "/{prestador_id}/servicios/{servicio_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar servicio del catálogo",
)
async def eliminar_servicio_mi_prestador(
    prestador: PrestadorPropietario,
    servicio_id: UUID,
    db: DbSession,
) -> None:
    from fastapi import HTTPException

    srv = await services.obtener_servicio(db, servicio_id)
    if srv.prestador_id != prestador.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Servicio no encontrado para este prestador",
        )
    await services.eliminar_servicio(db, srv)


# ---------------------------------------------------------
# Fotos de trabajos (dueño)
# ---------------------------------------------------------

# =========================================================
# Colaboradores del prestador (JSONB)
# =========================================================
@router_propietario.get(
    "/{prestador_id:uuid}/colaboradores",
    response_model=list[ColaboradorResponse],
    summary="Listar colaboradores del prestador",
)
async def listar_colaboradores(
    prestador_id: UUID,
    prestador: PrestadorOwner,
):
    colaboradores = prestador.colaboradores or []
    return [
        ColaboradorResponse(
            email=c.get("email", ""),
            nombre=c.get("nombre", ""),
            invitado_por=c.get("invitado_por", ""),
            invitado_at=datetime.fromisoformat(c["invitado_at"])
                if c.get("invitado_at") else datetime.now(timezone.utc),
            activado_at=datetime.fromisoformat(c["activado_at"])
                if c.get("activado_at") else None,
            rol=c.get("rol", "colaborador"),
            permisos=c.get("permisos", []),
        )
        for c in colaboradores
        if isinstance(c, dict)
    ]


@router_propietario.post(
    "/{prestador_id:uuid}/colaboradores/invitar",
    response_model=ColaboradorResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Invitar a un colaborador",
)
async def invitar_colaborador(
    prestador_id: UUID,
    data: ColaboradorInviteRequest,
    prestador: PrestadorOwner,
    user: CurrentUser,
    db: DbSession,
    background_tasks: BackgroundTasks,
    request: Request,
) -> ColaboradorResponse:
    email = data.email.lower().strip()
    if user.email and user.email.lower() == email:
        raise HTTPException(400, "No podes invitarte a vos mismo")
    colaboradores = list(prestador.colaboradores or [])
    encontrado = False
    nuevos = []
    
    for c in colaboradores:
        if not isinstance(c, dict):
            nuevos.append(c)
            continue
        c_nuevo = dict(c)
        if (c_nuevo.get("email") or "").lower() == email.lower():
            c_nuevo["permisos"] = data.permisos
            encontrado = True
        nuevos.append(c_nuevo)

    if not encontrado:
        raise HTTPException(404, "Colaborador no encontrado")

    prestador.colaboradores = nuevos
    flag_modified(prestador, "colaboradores")
    await db.commit()
    await db.refresh(prestador)
    return {"status": "ok", "message": "Permisos actualizados"}


@router_propietario.post(
    "/{prestador_id:uuid}/colaboradores/reenviar",
    summary="Reenviar invitacion a un colaborador pendiente",
)
async def reenviar_invitacion_colaborador(
    prestador_id: UUID,
    data: dict,
    prestador: PrestadorOwner,
    user: CurrentUser,
    db: DbSession,
    background_tasks: BackgroundTasks,
    request: Request,
):
    email = data.get("email", "").lower().strip()
    if not email:
        raise HTTPException(400, "Email requerido")

    colaboradores = list(prestador.colaboradores or [])
    colab = next(
        (
            c
            for c in colaboradores
            if isinstance(c, dict) and (c.get("email") or "").lower() == email
        ),
        None,
    )

    if not colab:
        raise HTTPException(404, "Colaborador no encontrado")

    if colab.get("activado_at"):
        raise HTTPException(400, "El colaborador ya ha aceptado la invitacion")

    token = generar_token_invitacion(str(prestador.id), email)
    background_tasks.add_task(
        notificar_invitacion_colaborador,
        email_invitado=email,
        nombre_invitado=colab.get("nombre", "Colaborador"),
        nombre_prestador=prestador.nombre,
        nombre_invitador=user.nombre or user.email or "el administrador",
        token=token,
        whatsapp_invitado=colab.get("whatsapp"),
    )

    await log_audit(
        db=db,
        prestador_id=prestador.id,
        user=user,
        accion="colaborador_reenvio_invitacion",
        entidad="colaborador",
        entidad_id=email,
        ip=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )

    return {"status": "ok", "message": "Invitacion reenviada"}


@router_propietario.post(
    "/{prestador_id:uuid}/colaboradores/aceptar",
    summary="Aceptar invitacion como colaborador",
)
async def aceptar_invitacion(
    prestador_id: UUID,
    data: dict,
    user: CurrentUser,
    db: DbSession,
    request: Request,
):
    token = data.get("token", "")
    if not token:
        raise HTTPException(400, "Token requerido")
    try:
        payload = validar_token_invitacion(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(400, "El enlace expiro. Pedile al owner que te reenvie la invitacion")
    except jwt.InvalidTokenError as e:
        raise HTTPException(400, f"Token invalido: {e}")
    if payload.get("prestador_id") != str(prestador_id):
        raise HTTPException(400, "Token no corresponde a este prestador")
    email_token = (payload.get("email") or "").lower()
    email_user = (user.email or "").lower()
    if email_token != email_user:
        raise HTTPException(403, "El email de tu cuenta no coincide con el de la invitacion")
    stmt = select(Prestador).where(
        Prestador.id == prestador_id, Prestador.activo.is_(True)
    )
    prestador = (await db.execute(stmt)).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(404, "Prestador no encontrado")
    colaboradores = list(prestador.colaboradores or [])
    found = False
    for c in colaboradores:
        if isinstance(c, dict) and (c.get("email") or "").lower() == email_token:
            c["activado_at"] = datetime.now(timezone.utc).isoformat()
            found = True
            break
    if not found:
        raise HTTPException(404, "Invitacion no encontrada o eliminada")
    prestador.colaboradores = colaboradores
    flag_modified(prestador, "colaboradores")
    await log_audit(
        db=db,
        prestador_id=prestador.id,
        user=user,
        accion="colaborador_activado",
        entidad="colaborador",
        entidad_id=email_user,
        metadata={"email": email_user},
        ip=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    await db.commit()
    return {"ok": True, "mensaje": "Invitacion aceptada. Ya podes operar."}


@router_propietario.patch(
    "/{prestador_id:uuid}/colaboradores/permisos",
    summary="Actualizar permisos de un colaborador",
)
async def actualizar_permisos_colaborador(
    prestador_id: UUID,
    email: str,
    data: ColaboradorPermisosUpdate,
    prestador: PrestadorOwner,
    user: CurrentUser,
    db: DbSession,
):
    colaboradores = list(prestador.colaboradores or [])
    encontrado = False
    nuevos = []

    for c in colaboradores:
        if not isinstance(c, dict):
            nuevos.append(c)
            continue
        c_nuevo = dict(c)
        if (c_nuevo.get("email") or "").lower() == email.lower():
            c_nuevo["permisos"] = data.permisos
            encontrado = True
        nuevos.append(c_nuevo)

    if not encontrado:
        raise HTTPException(404, "Colaborador no encontrado")

    prestador.colaboradores = nuevos
    flag_modified(prestador, "colaboradores")
    await db.commit()
    await db.refresh(prestador)
    return {"status": "ok", "message": "Permisos actualizados"}

@router_propietario.delete(
    "/{prestador_id:uuid}/colaboradores/{email}",
    summary="Eliminar colaborador",
)
async def eliminar_colaborador(
    prestador_id: UUID,
    email: str,
    prestador: PrestadorOwner,
    user: CurrentUser,
    db: DbSession,
    request: Request,
):
    email_norm = email.lower().strip()
    colaboradores = list(prestador.colaboradores or [])
    original_len = len(colaboradores)
    colaboradores = [
        c for c in colaboradores
        if not (isinstance(c, dict) and (c.get("email") or "").lower() == email_norm)
    ]
    if len(colaboradores) == original_len:
        raise HTTPException(404, "Colaborador no encontrado")
    prestador.colaboradores = colaboradores
    flag_modified(prestador, "colaboradores")
    await log_audit(
        db=db,
        prestador_id=prestador.id,
        user=user,
        accion="colaborador_eliminado",
        entidad="colaborador",
        entidad_id=email_norm,
        metadata={"email": email_norm},
        ip=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    await db.commit()
    return {"ok": True, "mensaje": f"Colaborador {email_norm} eliminado"}


@router_propietario.get(
    "/{prestador_id:uuid}/audit-log",
    response_model=AuditLogPage,
    summary="Audit log paginado",
)
async def listar_audit_log(
    prestador_id: UUID,
    prestador: PrestadorOwner,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    accion: str | None = Query(None),
    entidad: str | None = Query(None),
) -> AuditLogPage:
    offset = (page - 1) * page_size
    filters = [PrestadorAuditLog.prestador_id == prestador.id]
    if accion:
        filters.append(PrestadorAuditLog.accion == accion)
    if entidad:
        filters.append(PrestadorAuditLog.entidad == entidad)
    total = await db.scalar(
        select(func.count(PrestadorAuditLog.id)).where(*filters)
    ) or 0
    stmt = (
        select(PrestadorAuditLog)
        .where(*filters)
        .order_by(PrestadorAuditLog.created_at.desc())
        .limit(page_size)
        .offset(offset)
    )
    entries = list((await db.execute(stmt)).scalars().all())
    return AuditLogPage(
        data=[AuditLogEntry.model_validate(e) for e in entries],
        total=total,
        page=page,
        page_size=page_size,
    )

# =========================================================
# Admin — Categorías
# =========================================================
router_admin_categorias = APIRouter(
    prefix="/admin/categorias-oficio",
    tags=["admin-categorias-oficio"],
)


@router_admin_categorias.get(
    "",
    response_model=list[CategoriaOficioResponse],
    summary="Listar todas las categorías (admin)",
)
async def admin_listar_categorias(
    admin: AdminUser,
    db: DbSession,
    incluir_inactivas: bool = Query(
        False, description="Incluir categorías desactivadas"
    ),
) -> list[CategoriaOficioResponse]:
    cats = await services.listar_categorias(
        db,
        solo_activas=False,
        incluir_inactivas=incluir_inactivas,
    )
    return [CategoriaOficioResponse.model_validate(c) for c in cats]


@router_admin_categorias.post(
    "",
    response_model=CategoriaOficioResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear categoría de oficio",
)
async def admin_crear_categoria(
    data: CategoriaOficioCreate,
    admin: AdminUser,
    db: DbSession,
) -> CategoriaOficioResponse:
    cat = await services.crear_categoria(db, data)
    await db.refresh(cat)
    return CategoriaOficioResponse.model_validate(cat)


@router_admin_categorias.patch(
    "/{categoria_id}",
    response_model=CategoriaOficioResponse,
    summary="Editar categoría de oficio",
)
async def admin_editar_categoria(
    categoria_id: UUID,
    data: CategoriaOficioUpdate,
    admin: AdminUser,
    db: DbSession,
) -> CategoriaOficioResponse:
    cat = await services.editar_categoria(db, categoria_id, data)
    return CategoriaOficioResponse.model_validate(cat)


@router_admin_categorias.delete(
    "/{categoria_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Desactivar categoría de oficio",
    description=(
        "Soft-delete. Falla si hay prestadores activos en esa categoría."
    ),
)
async def admin_desactivar_categoria(
    categoria_id: UUID,
    admin: AdminUser,
    db: DbSession,
) -> None:
    await services.desactivar_categoria(db, categoria_id)


# =========================================================
# Admin — Prestadores
# =========================================================
router_admin_prestadores = APIRouter(
    prefix="/admin/prestadores", tags=["admin-prestadores"]
)


@router_admin_prestadores.get(
    "",
    response_model=PrestadorPrivadoListResponse,
    summary="Listar todos los prestadores (admin)",
)
async def admin_listar_prestadores(
    admin: AdminUser,
    db: DbSession,
    estado: EstadoPrestador | None = Query(None),
    categoria_id: UUID | None = Query(None),
    q: str | None = Query(None, max_length=100),
    incluir_inactivos: bool = Query(False),
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> PrestadorPrivadoListResponse:
    items, total = await services.listar_prestadores_admin(
        db,
        estado=estado,
        categoria_id=categoria_id,
        busqueda=q,
        incluir_inactivos=incluir_inactivos,
        page=page,
        page_size=page_size,
    )
    total_pages = (total + page_size - 1) // page_size
    return PrestadorPrivadoListResponse(
        items=[PrestadorPrivadoResponse.model_validate(p) for p in items],
        meta=PaginacionMeta(
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        ),
    )


@router_admin_prestadores.get(
    "/{prestador_id}",
    response_model=PrestadorPrivadoResponse,
    summary="Detalle de prestador (admin)",
)
async def admin_obtener_prestador(
    prestador_id: UUID,
    admin: AdminUser,
    db: DbSession,
) -> PrestadorPrivadoResponse:
    prestador = await services.obtener_prestador_por_id(db, prestador_id)
    return PrestadorPrivadoResponse.model_validate(prestador)


@router_admin_prestadores.post(
    "/{prestador_id}/verificar",
    response_model=PrestadorPrivadoResponse,
    summary="Verificar prestador",
)
async def admin_verificar_prestador(
    prestador_id: UUID,
    data: PrestadorVerificarRequest,
    admin: AdminUser,
    db: DbSession,
) -> PrestadorPrivadoResponse:
    prestador = await services.obtener_prestador_por_id(db, prestador_id)
    prestador = await services.verificar_prestador(
        db, prestador, admin, categoria_id=data.categoria_id
    )
    # Best-effort: encolar publicacion para redes (Etapa 5)
    await social_eventos.encolar_prestador_nuevo(db, prestador)
    return PrestadorPrivadoResponse.model_validate(prestador)


@router_admin_prestadores.post(
    "/{prestador_id}/rechazar",
    response_model=PrestadorPrivadoResponse,
    summary="Rechazar prestador",
)
async def admin_rechazar_prestador(
    prestador_id: UUID,
    data: PrestadorRechazarRequest,
    admin: AdminUser,
    db: DbSession,
) -> PrestadorPrivadoResponse:
    prestador = await services.obtener_prestador_por_id(db, prestador_id)
    prestador = await services.rechazar_prestador(
        db, prestador, admin, data.motivo
    )
    return PrestadorPrivadoResponse.model_validate(prestador)


@router_admin_prestadores.post(
    "/{prestador_id}/suspender",
    response_model=PrestadorPrivadoResponse,
    summary="Suspender prestador",
)
async def admin_suspender_prestador(
    prestador_id: UUID,
    data: PrestadorRechazarRequest,
    admin: AdminUser,
    db: DbSession,
) -> PrestadorPrivadoResponse:
    prestador = await services.obtener_prestador_por_id(db, prestador_id)
    prestador = await services.suspender_prestador(
        db, prestador, admin, data.motivo
    )
    return PrestadorPrivadoResponse.model_validate(prestador)


@router_admin_prestadores.post(
    "/{prestador_id}/destacar",
    response_model=PrestadorPrivadoResponse,
    summary="Marcar/desmarcar como destacado",
)
async def admin_destacar_prestador(
    prestador_id: UUID,
    data: PrestadorDestacarRequest,
    admin: AdminUser,
    db: DbSession,
) -> PrestadorPrivadoResponse:
    prestador = await services.obtener_prestador_por_id(db, prestador_id)
    prestador = await services.destacar_prestador(
        db, prestador, data.destacado
    )
    return PrestadorPrivadoResponse.model_validate(prestador)

# ============================================================
# Modalidades de prestación (Fase 6)
# ============================================================
@router_propietario.get(
    "/{prestador_id}/modalidades",
    response_model=ModalidadesResponse,
    summary="Ver configuración de modalidades",
)
async def obtener_modalidades_endpoint(
    prestador: PrestadorPropietario,
    db: DbSession,
) -> ModalidadesResponse:
    """Devuelve la config de modalidades del prestador."""
    config = await services.obtener_modalidades(db, prestador)
    return ModalidadesResponse(modalidades=config)


@router_propietario.patch(
    "/{prestador_id}/modalidades",
    response_model=ModalidadesResponse,
    summary="Actualizar configuración de modalidades",
)
async def actualizar_modalidades_endpoint(
    prestador: PrestadorPropietario,
    data: ModalidadesUpdateRequest,
    db: DbSession,
) -> ModalidadesResponse:
    """Actualiza la config de modalidades del prestador."""
    prestador = await services.actualizar_modalidades(db, prestador, data.modalidades)
    config = await services.obtener_modalidades(db, prestador)
    return ModalidadesResponse(modalidades=config)


# =========================================================
# Canales de contacto (emails, whatsapp, redes, google)
# =========================================================
class CanalesEmailReenvioUpdate(BaseModel):
    email: EmailStr


class CanalEmailUpdate(BaseModel):
    visible_publico: bool | None = None
    activo: bool | None = None
    override_destino: str | None = None


@router_propietario.get(
    "/{prestador_id}/canales",
    summary="Listar canales de contacto del prestador",
    description=(
        "Devuelve todos los correos con sus descripciones, "
        "email de reenvio personal, estado de verificacion "
        "y redes sociales. Usado por la app Flutter."
    ),
)
async def listar_canales_contacto(
    prestador: PrestadorPropietario,
    db: DbSession,
) -> dict:
    from app.modules.prestadores.canales_contacto import build_canales_contacto
    from app.modules.prestadores.cloudflare_email import verificar_destination

    canales = build_canales_contacto(prestador)
    email_reenvio = canales.get("email_reenvio_personal", "")
    canales["email_reenvio_verificado"] = (
        verificar_destination(email_reenvio) if email_reenvio else False
    )
    return canales


@router_propietario.post(
    "/{prestador_id}/canales/email-reenvio",
    summary="Cambiar email de reenvio personal",
    description=(
        "Guarda el nuevo email en JSONB + lo agrega como destination "
        "en Cloudflare. Cloudflare envia un correo de verificacion al "
        "nuevo email. Despues el usuario debe usar /confirmar."
    ),
)
async def cambiar_email_reenvio(
    prestador: PrestadorPropietario,
    data: CanalesEmailReenvioUpdate,
    db: DbSession,
) -> dict:
    from app.modules.prestadores.cloudflare_email import (
        actualizar_catch_all, agregar_destination,
    )

    resultado = agregar_destination(data.email)
    if not resultado["ok"]:
        raise HTTPException(
            status_code=400,
            detail=f"Cloudflare: {resultado['error']}",
        )

    # Guardar en JSONB
    perfil = dict(prestador.perfil_negocio or {})
    cc = dict(perfil.get("canales_contacto") or {})
    cc["email_reenvio_personal"] = data.email
    perfil["canales_contacto"] = cc
    prestador.perfil_negocio = perfil
    from sqlalchemy.orm.attributes import flag_modified
    flag_modified(prestador, "perfil_negocio")
    await db.commit()
    await db.refresh(prestador)

    if resultado["verified"]:
        # Ya estaba verificado: actualizar catch-all inmediatamente
        upd = actualizar_catch_all(data.email)
        return {
            "ok": True,
            "verificado": True,
            "mensaje": f"Email verificado. Todos los correos llegan a {data.email}.",
            "catch_all": upd,
        }

    return {
        "ok": True,
        "verificado": False,
        "mensaje": (
            f"Revisa {data.email} y hace click en el link de verificacion de "
            "Cloudflare. Despues volve a la app y presiona 'Ya verifique'."
        ),
    }


@router_propietario.post(
    "/{prestador_id}/canales/email-reenvio/confirmar",
    summary="Confirmar verificacion del email de reenvio",
    description=(
        "Consulta Cloudflare. Si el email esta verificado, "
        "actualiza la regla catch-all para forwardear a ese email."
    ),
)
async def confirmar_email_reenvio(
    prestador: PrestadorPropietario,
    db: DbSession,
) -> dict:
    from app.modules.prestadores.canales_contacto import build_canales_contacto
    from app.modules.prestadores.cloudflare_email import (
        actualizar_catch_all, verificar_destination,
    )

    canales = build_canales_contacto(prestador)
    email = canales.get("email_reenvio_personal", "")
    if not email:
        raise HTTPException(400, "No hay email de reenvio configurado")

    if not verificar_destination(email):
        raise HTTPException(
            400,
            f"{email} todavia no esta verificado. Revisa tu correo y hace click en el link de Cloudflare.",
        )

    resultado = actualizar_catch_all(email)
    if not resultado["ok"]:
        raise HTTPException(
            500, f"Cloudflare: {resultado['error']}"
        )

    return {
        "ok": True,
        "mensaje": f"Verificado. Todos los correos llegan a {email}.",
    }


@router_propietario.patch(
    "/{prestador_id}/canales/email/{tipo}",
    summary="Actualizar configuracion de un canal email",
    description=(
        "Toggle visible_publico/activo + override_destino por canal. "
        "Si override_destino es un email, crea regla especifica en CF "
        "(requiere verificacion previa). Si es string vacio, elimina la regla."
    ),
)
async def actualizar_canal_email(
    prestador: PrestadorPropietario,
    tipo: str,
    data: CanalEmailUpdate,
    db: DbSession,
) -> dict:
    from app.modules.prestadores.cloudflare_email import (
        agregar_destination, crear_regla_override,
        eliminar_regla_override,
    )

    perfil = dict(prestador.perfil_negocio or {})
    cc = dict(perfil.get("canales_contacto") or {})
    emails_custom = list(cc.get("email") or [])

    # Buscar o crear entrada para este tipo
    target = None
    for item in emails_custom:
        if item.get("tipo") == tipo:
            target = item
            break
    if target is None:
        target = {"tipo": tipo}
        emails_custom.append(target)

    if data.visible_publico is not None:
        target["visible_publico"] = data.visible_publico
    if data.activo is not None:
        target["activo"] = data.activo

    cloudflare_result = None

    # Override: agregar / quitar regla especifica en CF
    if data.override_destino is not None:
        old_rule_id = target.get("override_rule_id")

        if data.override_destino == "":
            # Eliminar override
            if old_rule_id:
                eliminado = eliminar_regla_override(old_rule_id)
                cloudflare_result = {"ok": eliminado, "accion": "eliminar"}
            target.pop("override_destino", None)
            target.pop("override_rule_id", None)
        else:
            # Crear override
            add = agregar_destination(data.override_destino)
            if not add["ok"]:
                raise HTTPException(
                    400, f"Cloudflare: {add['error']}"
                )
            if not add["verified"]:
                raise HTTPException(
                    400,
                    f"{data.override_destino} no verificado. "
                    "Revisa su correo y clickea el link de Cloudflare.",
                )
            # Eliminar regla vieja si existia
            if old_rule_id:
                eliminar_regla_override(old_rule_id)
            # Crear regla nueva
            rule = crear_regla_override(tipo, data.override_destino)
            if not rule.get("ok"):
                raise HTTPException(
                    500, f"Cloudflare: {rule.get('error')}"
                )
            target["override_destino"] = data.override_destino
            target["override_rule_id"] = rule.get("rule_id")
            cloudflare_result = {
                "ok": True,
                "accion": "crear",
                "rule_id": rule.get("rule_id"),
            }

    cc["email"] = emails_custom
    perfil["canales_contacto"] = cc
    prestador.perfil_negocio = perfil
    from sqlalchemy.orm.attributes import flag_modified
    flag_modified(prestador, "perfil_negocio")
    await db.commit()
    await db.refresh(prestador)

    return {
        "ok": True,
        "tipo": tipo,
        "canal": target,
        "cloudflare": cloudflare_result,
    }
