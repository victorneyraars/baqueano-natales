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

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel, EmailStr

from app.core.db import DbSession
from app.modules.auth.deps import AdminUser, CurrentUser
from app.modules.prestadores import services
from app.modules.prestadores.whatsapp import build_whatsapp_info
from app.modules.prestadores.deps import PrestadorPropietario
from app.modules.social import eventos_prestadores as social_eventos
from app.modules.prestadores.models import EstadoPrestador
from app.modules.prestadores.schemas import (
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
    return PrestadorPrivadoListResponse(
        items=[PrestadorPrivadoResponse.model_validate(p) for p in items],
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
) -> PrestadorPrivadoResponse:
    return PrestadorPrivadoResponse.model_validate(prestador)


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
