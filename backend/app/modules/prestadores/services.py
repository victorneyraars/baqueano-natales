"""
Servicios (lógica de negocio) del módulo prestadores.

Reglas clave:
- Solo los prestadores VERIFICADOS son visibles públicamente.
- El estado sigue el flujo: borrador → pendiente → verificado/rechazado.
- Un prestador solo puede ser editado por su propietario o un admin.
- Los prestadores pueden tener VARIOS servicios con precios orientativos
  y VARIAS fotos de trabajos (galerías ordenadas).
- `especialidades`, `datos_extra` y `redes_sociales` se guardan como JSONB.

Reusa:
- app.shared.utils.slug.generar_slug_unico
"""
from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.auth.models import Usuario
from app.modules.prestadores.models import (
    CategoriaOficio,
    EstadoPrestador,
    Prestador,
    PrestadorServicio,
)
from app.modules.prestadores.schemas import (
    CategoriaOficioCreate,
    CategoriaOficioUpdate,
    PrestadorCreate,
    PrestadorServicioCreate,
    PrestadorServicioUpdate,
    PrestadorUpdate,
)
from app.shared.utils.slug import generar_slug_unico


# =========================================================
# Helpers internos
# =========================================================
def _prestador_select_full():
    """Select base con eager loading de relaciones."""
    return select(Prestador).options(
        selectinload(Prestador.categoria),
        selectinload(Prestador.servicios),
    )


# =========================================================
# Categorías de oficio (admin)
# =========================================================
async def crear_categoria(
    db: AsyncSession,
    data: CategoriaOficioCreate,
) -> CategoriaOficio:
    """Crea una categoría. Valida nombre y slug únicos."""
    slug = data.slug or await generar_slug_unico(
        db, data.nombre, CategoriaOficio
    )
    existe = (
        await db.execute(
            select(CategoriaOficio).where(CategoriaOficio.slug == slug)
        )
    ).scalar_one_or_none()
    if existe:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ya existe una categoría con slug '{slug}'",
        )

    categoria = CategoriaOficio(
        nombre=data.nombre,
        slug=slug,
        descripcion=data.descripcion,
        icono=data.icono,
        color_hex=data.color_hex,
        orden=data.orden,
    )
    db.add(categoria)
    await db.flush()
    await db.refresh(categoria)
    return categoria


async def listar_categorias(
    db: AsyncSession,
    *,
    solo_activas: bool = True,
    incluir_inactivas: bool = False,
) -> list[CategoriaOficio]:
    """Lista categorías ordenadas por `orden` y `nombre`."""
    stmt = select(CategoriaOficio)
    if solo_activas and not incluir_inactivas:
        stmt = stmt.where(CategoriaOficio.activo.is_(True))
    stmt = stmt.order_by(CategoriaOficio.orden, CategoriaOficio.nombre)
    return list((await db.execute(stmt)).scalars().all())


async def obtener_categoria(
    db: AsyncSession,
    categoria_id: UUID,
) -> CategoriaOficio:
    cat = await db.get(CategoriaOficio, categoria_id)
    if cat is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoría no encontrada",
        )
    return cat


async def editar_categoria(
    db: AsyncSession,
    categoria_id: UUID,
    data: CategoriaOficioUpdate,
) -> CategoriaOficio:
    cat = await obtener_categoria(db, categoria_id)
    updates = data.model_dump(exclude_unset=True)

    if "slug" in updates and updates["slug"] != cat.slug:
        existe = (
            await db.execute(
                select(CategoriaOficio).where(
                    CategoriaOficio.slug == updates["slug"],
                    CategoriaOficio.id != cat.id,
                )
            )
        ).scalar_one_or_none()
        if existe:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Slug '{updates['slug']}' ya en uso",
            )

    for campo, valor in updates.items():
        setattr(cat, campo, valor)
    await db.flush()
    await db.refresh(cat)
    return cat


async def desactivar_categoria(
    db: AsyncSession,
    categoria_id: UUID,
) -> None:
    """Soft-delete de categoría. Falla si hay prestadores activos."""
    cat = await obtener_categoria(db, categoria_id)
    activos = (
        await db.execute(
            select(func.count(Prestador.id)).where(
                Prestador.categoria_id == cat.id,
                Prestador.activo.is_(True),
            )
        )
    ).scalar_one()
    if activos > 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"No se puede desactivar: {activos} prestador(es) activo(s)"
            ),
        )
    cat.activo = False
    await db.flush()


# =========================================================
# Prestadores — creación y edición
# =========================================================
async def crear_prestador(
    db: AsyncSession,
    propietario: Usuario,
    data: PrestadorCreate,
) -> Prestador:
    """Crea un prestador en estado BORRADOR."""
    cat = await obtener_categoria(db, data.categoria_id)
    if not cat.activo:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La categoría está desactivada",
        )

    slug = await generar_slug_unico(db, data.nombre, Prestador)

    prestador = Prestador(
        usuario_id=propietario.id,
        categoria_id=data.categoria_id,
        nombre=data.nombre,
        slug=slug,
        descripcion=data.descripcion,
        anios_experiencia=data.anios_experiencia,
        telefono=data.telefono,
        whatsapp=data.whatsapp,
        whatsapp_mensaje=data.whatsapp_mensaje,
        email=data.email,
        sitio_web=data.sitio_web,
        comuna=data.comuna,
        region=data.region,
        direccion=data.direccion,
        latitud=data.latitud,
        longitud=data.longitud,
        radio_cobertura_km=data.radio_cobertura_km,
        atiende_domicilio=data.atiende_domicilio,
        atiende_local=data.atiende_local,
        atiende_emergencias=data.atiende_emergencias,
        horario_descripcion=data.horario_descripcion,
        especialidades=data.especialidades,
        datos_extra=data.datos_extra,
        redes_sociales=data.redes_sociales,
        estado=EstadoPrestador.BORRADOR,
    )
    db.add(prestador)
    await db.flush()
    await db.refresh(
        prestador,
        attribute_names=["categoria", "servicios"],
    )
    return prestador


async def obtener_prestador_por_id(
    db: AsyncSession,
    prestador_id: UUID,
) -> Prestador:
    """Obtiene un prestador activo por ID (cualquier estado)."""
    stmt = _prestador_select_full().where(
        Prestador.id == prestador_id,
        Prestador.activo.is_(True),
    )
    prestador = (await db.execute(stmt)).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prestador no encontrado",
        )
    return prestador


async def obtener_prestador_por_slug(
    db: AsyncSession,
    slug: str,
) -> Prestador:
    """Obtiene un prestador verificado por slug (uso público)."""
    stmt = _prestador_select_full().where(
        Prestador.slug == slug,
        Prestador.estado == EstadoPrestador.VERIFICADO,
        Prestador.activo.is_(True),
    )
    prestador = (await db.execute(stmt)).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prestador no encontrado",
        )
    return prestador


async def listar_prestadores_mios(
    db: AsyncSession,
    propietario: Usuario,
) -> list[Prestador]:
    """Lista todos los prestadores del usuario (cualquier estado)."""
    stmt = (
        _prestador_select_full()
        .where(
            Prestador.usuario_id == propietario.id,
            Prestador.activo.is_(True),
        )
        .order_by(Prestador.created_at.desc())
    )
    return list((await db.execute(stmt)).scalars().all())


async def editar_prestador(
    db: AsyncSession,
    prestador: Prestador,
    data: PrestadorUpdate,
) -> Prestador:
    """Edita parcialmente un prestador. Si estaba rechazado, vuelve a borrador."""
    updates = data.model_dump(exclude_unset=True)

    if "categoria_id" in updates and updates["categoria_id"] is not None:
        cat = await obtener_categoria(db, updates["categoria_id"])
        if not cat.activo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La categoría está desactivada",
            )

    for campo, valor in updates.items():
        setattr(prestador, campo, valor)

    if prestador.estado == EstadoPrestador.RECHAZADO:
        prestador.estado = EstadoPrestador.BORRADOR
        prestador.motivo_rechazo = None

    await db.flush()
    await db.refresh(
        prestador,
        attribute_names=["categoria", "servicios"],
    )
    # Solo revalidar si el prestador está verificado (público)
    if prestador.estado == EstadoPrestador.VERIFICADO:
        await _notify_web_revalidation(prestador)
    return prestador


async def eliminar_prestador(
    db: AsyncSession,
    prestador: Prestador,
) -> None:
    """Soft-delete: solo marca activo=False."""
    prestador.activo = False
    await db.flush()


# =========================================================
# Prestadores — flujo de verificación
# =========================================================
async def enviar_a_revision(
    db: AsyncSession,
    prestador: Prestador,
) -> Prestador:
    """borrador/rechazado → pendiente."""
    if prestador.estado not in (
        EstadoPrestador.BORRADOR,
        EstadoPrestador.RECHAZADO,
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"No se puede enviar a revisión desde estado "
                f"'{prestador.estado.value}'"
            ),
        )
    prestador.estado = EstadoPrestador.PENDIENTE
    prestador.motivo_rechazo = None
    await db.flush()
    await db.refresh(prestador)
    return prestador


async def verificar_prestador(
    db: AsyncSession,
    prestador: Prestador,
    admin: Usuario,
    categoria_id: UUID | None = None,
) -> Prestador:
    """pendiente/suspendido → verificado. Admin."""
    if prestador.estado not in (
        EstadoPrestador.PENDIENTE,
        EstadoPrestador.SUSPENDIDO,
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"No se puede verificar desde estado "
                f"'{prestador.estado.value}'"
            ),
        )
    if categoria_id is not None:
        await obtener_categoria(db, categoria_id)
        prestador.categoria_id = categoria_id

    prestador.estado = EstadoPrestador.VERIFICADO
    prestador.motivo_rechazo = None
    prestador.verificado = True
    prestador.verificado_en = datetime.now(timezone.utc)
    prestador.verificado_por_id = admin.id
    await db.flush()
    await db.refresh(prestador)
    await _notify_web_revalidation(prestador)
    return prestador


async def rechazar_prestador(
    db: AsyncSession,
    prestador: Prestador,
    admin: Usuario,
    motivo: str,
) -> Prestador:
    """pendiente → rechazado. Admin."""
    if prestador.estado != EstadoPrestador.PENDIENTE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Solo se puede rechazar desde 'pendiente'",
        )
    prestador.estado = EstadoPrestador.RECHAZADO
    prestador.motivo_rechazo = motivo
    prestador.verificado_por_id = admin.id
    await db.flush()
    await db.refresh(prestador)
    await _notify_web_revalidation(prestador)
    return prestador


async def suspender_prestador(
    db: AsyncSession,
    prestador: Prestador,
    admin: Usuario,
    motivo: str,
) -> Prestador:
    """verificado → suspendido. Admin."""
    if prestador.estado != EstadoPrestador.VERIFICADO:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Solo se puede suspender desde 'verificado'",
        )
    prestador.estado = EstadoPrestador.SUSPENDIDO
    prestador.motivo_rechazo = motivo
    prestador.verificado_por_id = admin.id
    await db.flush()
    await db.refresh(prestador)
    await _notify_web_revalidation(prestador)
    return prestador


async def destacar_prestador(
    db: AsyncSession,
    prestador: Prestador,
    destacado: bool,
) -> Prestador:
    """Toggle destacado. Admin."""
    prestador.destacado = destacado
    await db.flush()
    await db.refresh(prestador)
    # Solo revalidar si el prestador está verificado (público)
    if prestador.estado == EstadoPrestador.VERIFICADO:
        await _notify_web_revalidation(prestador)
    return prestador


# =========================================================
# Servicios del prestador (catálogo)
# =========================================================
async def setear_servicios(
    db: AsyncSession,
    prestador: Prestador,
    servicios_data: list[PrestadorServicioCreate],
) -> list[PrestadorServicio]:
    """
    Reemplaza TODOS los servicios del prestador.
    Elimina los existentes y crea los nuevos en una transacción.
    """
    for srv in list(prestador.servicios):
        await db.delete(srv)
    await db.flush()

    nuevos: list[PrestadorServicio] = []
    for idx, sdata in enumerate(servicios_data):
        srv = PrestadorServicio(
            prestador_id=prestador.id,
            nombre=sdata.nombre,
            descripcion=sdata.descripcion,
            categoria_servicio=sdata.categoria_servicio,
            precio_desde_clp=sdata.precio_desde_clp,
            precio_hasta_clp=sdata.precio_hasta_clp,
            duracion_estimada_min=sdata.duracion_estimada_min,
            garantia_dias=sdata.garantia_dias,
            destacado=sdata.destacado,
            orden=sdata.orden if sdata.orden > 0 else idx,
        )
        db.add(srv)
        nuevos.append(srv)
    await db.flush()
    return nuevos


async def agregar_servicio(
    db: AsyncSession,
    prestador: Prestador,
    data: PrestadorServicioCreate,
) -> PrestadorServicio:
    """Agrega un servicio al catálogo del prestador."""
    # Si no se especifica orden, va al final
    orden = data.orden
    if orden == 0 and prestador.servicios:
        orden = max((s.orden for s in prestador.servicios), default=0) + 1

    srv = PrestadorServicio(
        prestador_id=prestador.id,
        nombre=data.nombre,
        descripcion=data.descripcion,
        categoria_servicio=data.categoria_servicio,
        precio_desde_clp=data.precio_desde_clp,
        precio_hasta_clp=data.precio_hasta_clp,
        duracion_estimada_min=data.duracion_estimada_min,
        garantia_dias=data.garantia_dias,
        destacado=data.destacado,
        orden=orden,
    )
    db.add(srv)
    await db.flush()
    await db.refresh(srv)
    return srv


async def obtener_servicio(
    db: AsyncSession,
    servicio_id: UUID,
) -> PrestadorServicio:
    srv = await db.get(PrestadorServicio, servicio_id)
    if srv is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Servicio no encontrado",
        )
    return srv


async def editar_servicio(
    db: AsyncSession,
    servicio: PrestadorServicio,
    data: PrestadorServicioUpdate,
) -> PrestadorServicio:
    updates = data.model_dump(exclude_unset=True)
    for campo, valor in updates.items():
        setattr(servicio, campo, valor)
    await db.flush()
    await db.refresh(servicio)
    return servicio


async def eliminar_servicio(
    db: AsyncSession,
    servicio: PrestadorServicio,
) -> None:
    await db.delete(servicio)
    await db.flush()


# =========================================================
# Fotos de trabajos
# =========================================================

# =========================================================
# Listados públicos y admin
# =========================================================
async def listar_prestadores_publicos(
    db: AsyncSession,
    *,
    categoria_id: UUID | None = None,
    busqueda: str | None = None,
    solo_verificados: bool = True,
    solo_destacados: bool = False,
    atiende_domicilio: bool | None = None,
    atiende_emergencias: bool | None = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Prestador], int]:
    """
    Lista prestadores con filtros.
    Por defecto solo muestra VERIFICADOS.
    Devuelve (items, total).
    """
    stmt = select(Prestador).where(Prestador.activo.is_(True))
    if solo_verificados:
        stmt = stmt.where(Prestador.estado == EstadoPrestador.VERIFICADO)
    if categoria_id is not None:
        stmt = stmt.where(Prestador.categoria_id == categoria_id)
    if busqueda:
        patron = f"%{busqueda.lower()}%"
        stmt = stmt.where(
            or_(
                func.lower(Prestador.nombre).like(patron),
                func.lower(Prestador.descripcion).like(patron),
            )
        )
    if solo_destacados:
        stmt = stmt.where(Prestador.destacado.is_(True))
    if atiende_domicilio is not None:
        stmt = stmt.where(
            Prestador.atiende_domicilio.is_(atiende_domicilio)
        )
    if atiende_emergencias is not None:
        stmt = stmt.where(
            Prestador.atiende_emergencias.is_(atiende_emergencias)
        )

    # Total
    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()

    # Orden: destacados primero, luego rating, luego nombre
    stmt = (
        stmt.order_by(
            Prestador.destacado.desc(),
            Prestador.calificacion_promedio.desc(),
            Prestador.nombre,
        )
        .options(
            selectinload(Prestador.categoria),
            selectinload(Prestador.servicios),
        )
        .offset((page - 1) * page_size)
        .limit(page_size)
    )

    items = list((await db.execute(stmt)).scalars().all())
    return items, total


async def listar_prestadores_admin(
    db: AsyncSession,
    *,
    estado: EstadoPrestador | None = None,
    categoria_id: UUID | None = None,
    busqueda: str | None = None,
    incluir_inactivos: bool = False,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Prestador], int]:
    """Lista todos los prestadores con filtros (admin)."""
    stmt = select(Prestador)
    if not incluir_inactivos:
        stmt = stmt.where(Prestador.activo.is_(True))
    if estado is not None:
        stmt = stmt.where(Prestador.estado == estado)
    if categoria_id is not None:
        stmt = stmt.where(Prestador.categoria_id == categoria_id)
    if busqueda:
        patron = f"%{busqueda.lower()}%"
        stmt = stmt.where(func.lower(Prestador.nombre).like(patron))

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()

    stmt = (
        stmt.order_by(Prestador.created_at.desc())
        .options(
            selectinload(Prestador.categoria),
            selectinload(Prestador.servicios),
            )
        .offset((page - 1) * page_size)
        .limit(page_size)
    )

    items = list((await db.execute(stmt)).scalars().all())
    return items, total


# =========================================================
# Imágenes
# =========================================================
async def actualizar_foto_perfil(
    db: AsyncSession,
    prestador: Prestador,
    foto_url: str,
) -> Prestador:
    prestador.foto_url = foto_url
    await db.flush()
    await db.refresh(prestador)
    return prestador


async def actualizar_foto_portada(
    db: AsyncSession,
    prestador: Prestador,
    foto_portada_url: str,
) -> Prestador:
    prestador.foto_portada_url = foto_portada_url
    await db.flush()
    await db.refresh(prestador)
    return prestador
async def _notify_web_revalidation(prestador):
    """Notifica a Vercel para revalidar /prestadores y el detalle (best-effort)."""
    from app.core.config import settings
    import httpx
    try:
        paths = ["/prestadores"]
        if prestador.slug:
            paths.append(f"/prestadores/{prestador.slug}")

        async with httpx.AsyncClient() as client:
            await client.post(
                f"{settings.PUBLIC_API_URL}/api/v1/ops/webhooks/revalidate",
                json={"paths": paths},
                headers={"x-api-key": settings.REVALIDATE_API_KEY},
                timeout=5.0,
            )
    except Exception:
        pass

# ============================================================
# Modalidades de prestación (Fase 6)
# ============================================================
async def obtener_modalidades(db: AsyncSession, prestador):
    """Devuelve la configuración de modalidades (o defaults si no existe)."""
    from app.modules.prestadores.schemas import ModalidadesConfig
    if not prestador.modalidades:
        return ModalidadesConfig()
    return ModalidadesConfig(**prestador.modalidades)


async def actualizar_modalidades(db: AsyncSession, prestador, data):
    """Actualiza la configuración de modalidades del prestador."""
    prestador.modalidades = data.model_dump()
    await db.flush()
    return prestador


async def listar_servicios_activos(db, prestador_id):
    """Lista servicios activos del prestador, ordenados por orden y nombre."""
    from app.modules.prestadores.models import PrestadorServicio
    from sqlalchemy import select as _sel

    rows = (
        await db.execute(
            _sel(PrestadorServicio)
            .where(
                PrestadorServicio.prestador_id == prestador_id,
                PrestadorServicio.activo.is_(True),
            )
            .order_by(PrestadorServicio.orden, PrestadorServicio.nombre)
        )
    ).scalars().all()
    return list(rows)
