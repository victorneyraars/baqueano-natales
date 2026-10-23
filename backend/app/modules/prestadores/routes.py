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

from fastapi import APIRouter, Query, status

from app.core.db import DbSession
from app.modules.auth.deps import AdminUser, CurrentUser
from app.modules.prestadores import services
from app.modules.prestadores.deps import PrestadorPropietario
from app.modules.social import eventos_prestadores as social_eventos
from app.modules.prestadores.models import EstadoPrestador
from app.modules.prestadores.schemas import (
    CategoriaOficioCreate,
    CategoriaOficioResponse,
    CategoriaOficioUpdate,
    FotoTrabajoResponse,
    FotosTrabajoBulkUpdate,
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
    return PrestadorDetalleResponse.model_validate(prestador)


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
@router_propietario.put(
    "/{prestador_id}/fotos",
    response_model=list[FotoTrabajoResponse],
    summary="Reemplazar galería de fotos",
    description="Reemplaza TODAS las fotos del prestador (bulk).",
)
async def setear_fotos_mi_prestador(
    prestador: PrestadorPropietario,
    data: FotosTrabajoBulkUpdate,
    db: DbSession,
) -> list[FotoTrabajoResponse]:
    nuevas = await services.setear_fotos_trabajo(db, prestador, data.fotos)
    return [FotoTrabajoResponse.model_validate(f) for f in nuevas]


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
