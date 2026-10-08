"""
Servicios (lógica de negocio) del módulo comercios.

Reglas clave:
- Solo los comercios VERIFICADOS son visibles públicamente.
- El estado sigue el flujo: borrador → pendiente → verificado/rechazado
- Un comercio solo puede ser editado por su propietario o un admin.
- Los horarios se reemplazan en bloque (PUT) para simplificar la UI.
- El cálculo de "abierto ahora" usa timezone de Chile continental.
"""
from datetime import datetime, time, timezone
from decimal import Decimal
from uuid import UUID
from zoneinfo import ZoneInfo

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import RolUsuario, Usuario
from app.modules.comercios.models import (
    CategoriaComercio,
    Comercio,
    EstadoComercio,
    HorarioComercio,
)
from app.modules.comercios.schemas import (
    CategoriaComercioCreate,
    CategoriaComercioUpdate,
    ComercioCreate,
    ComercioUpdate,
    HorarioCreate,
)

# =========================================================
# Constantes
# =========================================================
TZ_CHILE = ZoneInfo("America/Santiago")


# =========================================================
# Utilidades
# =========================================================
def _slugify(texto: str) -> str:
    """Convierte texto a slug URL-safe (minúsculas, guiones)."""
    import re
    import unicodedata

    # Normalizar: quitar acentos
    normalizado = unicodedata.normalize("NFKD", texto)
    sin_acentos = "".join(c for c in normalizado if not unicodedata.combining(c))
    # Reemplazar caracteres no alfanuméricos por guiones
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", sin_acentos).strip("-").lower()
    return slug or "sin-nombre"


async def generar_slug_unico(
    db: AsyncSession,
    texto: str,
    *,
    tabla: str = "comercios",
    excluir_id: UUID | None = None,
) -> str:
    """
    Genera un slug único a partir del texto.
    Si el slug ya existe, agrega sufijo -2, -3, etc.

    `tabla` puede ser "comercios" o "categorias_comercio".
    """
    base = _slugify(texto)
    modelo = Comercio if tabla == "comercios" else CategoriaComercio
    slug = base
    contador = 2

    while True:
        stmt = select(modelo.id).where(modelo.slug == slug)
        if excluir_id is not None:
            stmt = stmt.where(modelo.id != excluir_id)
        existe = (await db.execute(stmt)).scalar_one_or_none()
        if existe is None:
            return slug
        slug = f"{base}-{contador}"
        contador += 1


def esta_abierto_ahora(horarios: list[HorarioComercio]) -> bool:
    """
    Determina si el comercio está abierto en este momento
    según sus franjas horarias.
    """
    ahora = datetime.now(TZ_CHILE)
    dia = ahora.weekday()  # 0=lunes ... 6=domingo
    hora = ahora.time()

    for h in horarios:
        if h.dia_semana != dia or h.cerrado:
            continue
        if h.abre is None or h.cierra is None:
            continue
        # Franja que cruza medianoche (ej: 22:00 - 02:00)
        if h.cierra <= h.abre:
            if hora >= h.abre or hora <= h.cierra:
                return True
        else:
            if h.abre <= hora <= h.cierra:
                return True
    return False


# =========================================================
# Categorías (admin)
# =========================================================
async def crear_categoria(
    db: AsyncSession,
    data: CategoriaComercioCreate,
) -> CategoriaComercio:
    """Crea una categoría. Valida nombre y slug únicos."""
    # Slug auto-generado si no se envía explícito
    slug = data.slug or await generar_slug_unico(
        db, data.nombre, tabla="categorias_comercio"
    )
    existe = (
        await db.execute(
            select(CategoriaComercio).where(CategoriaComercio.slug == slug)
        )
    ).scalar_one_or_none()
    if existe:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ya existe una categoría con slug '{slug}'",
        )

    categoria = CategoriaComercio(
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
) -> list[CategoriaComercio]:
    """Lista categorías ordenadas por `orden` y `nombre`."""
    stmt = select(CategoriaComercio)
    if solo_activas and not incluir_inactivas:
        stmt = stmt.where(CategoriaComercio.activo.is_(True))
    stmt = stmt.order_by(CategoriaComercio.orden, CategoriaComercio.nombre)
    return list((await db.execute(stmt)).scalars().all())


async def obtener_categoria(
    db: AsyncSession,
    categoria_id: UUID,
) -> CategoriaComercio:
    cat = await db.get(CategoriaComercio, categoria_id)
    if cat is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoría no encontrada",
        )
    return cat


async def editar_categoria(
    db: AsyncSession,
    categoria_id: UUID,
    data: CategoriaComercioUpdate,
) -> CategoriaComercio:
    cat = await obtener_categoria(db, categoria_id)
    updates = data.model_dump(exclude_unset=True)

    if "slug" in updates and updates["slug"] != cat.slug:
        existe = (
            await db.execute(
                select(CategoriaComercio).where(
                    CategoriaComercio.slug == updates["slug"],
                    CategoriaComercio.id != cat.id,
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
    """Soft-delete de categoría. Falla si hay comercios activos."""
    cat = await obtener_categoria(db, categoria_id)
    # Verificar que no haya comercios activos en esa categoría
    activos = (
        await db.execute(
            select(func.count(Comercio.id)).where(
                Comercio.categoria_id == cat.id,
                Comercio.activo.is_(True),
            )
        )
    ).scalar_one()
    if activos > 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"No se puede desactivar: {activos} comercio(s) activo(s)",
        )
    cat.activo = False
    await db.flush()


# =========================================================
# Comercios — creación y edición
# =========================================================
async def crear_comercio(
    db: AsyncSession,
    propietario: Usuario,
    data: ComercioCreate,
) -> Comercio:
    """Crea un comercio en estado BORRADOR."""
    slug = await generar_slug_unico(db, data.nombre, tabla="comercios")

    comercio = Comercio(
        propietario_id=propietario.id,
        categoria_id=data.categoria_id,
        nombre=data.nombre,
        slug=slug,
        descripcion_corta=data.descripcion_corta,
        descripcion_larga=data.descripcion_larga,
        telefono=data.telefono,
        whatsapp=data.whatsapp,
        email=data.email,
        sitio_web=data.sitio_web,
        direccion=data.direccion,
        ciudad=data.ciudad,
        region=data.region,
        latitud=data.latitud,
        longitud=data.longitud,
        referencia=data.referencia,
        acepta_delivery=data.acepta_delivery,
        acepta_retiro=data.acepta_retiro,
        costo_envio_clp=data.costo_envio_clp,
        pedido_minimo_clp=data.pedido_minimo_clp,
        radio_entrega_km=data.radio_entrega_km,
        tiempo_preparacion_min=data.tiempo_preparacion_min,
        estado=EstadoComercio.BORRADOR,
    )
    db.add(comercio)
    await db.flush()
    await db.refresh(comercio)
    return comercio


async def obtener_comercio_por_id(
    db: AsyncSession,
    comercio_id: UUID,
) -> Comercio:
    comercio = await db.get(Comercio, comercio_id)
    if comercio is None or not comercio.activo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Comercio no encontrado",
        )
    return comercio


async def obtener_comercio_por_slug(
    db: AsyncSession,
    slug: str,
) -> Comercio:
    """Obtiene un comercio verificado por slug (uso público)."""
    stmt = select(Comercio).where(
        Comercio.slug == slug,
        Comercio.estado == EstadoComercio.VERIFICADO,
        Comercio.activo.is_(True),
    )
    comercio = (await db.execute(stmt)).scalar_one_or_none()
    if comercio is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Comercio no encontrado",
        )
    return comercio


async def listar_comercios_mios(
    db: AsyncSession,
    propietario: Usuario,
) -> list[Comercio]:
    """Lista todos los comercios del usuario (cualquier estado)."""
    stmt = (
        select(Comercio)
        .where(
            Comercio.propietario_id == propietario.id,
            Comercio.activo.is_(True),
        )
        .order_by(Comercio.created_at.desc())
    )
    return list((await db.execute(stmt)).scalars().all())


async def editar_comercio(
    db: AsyncSession,
    comercio: Comercio,
    data: ComercioUpdate,
) -> Comercio:
    """Edita parcialmente un comercio. Si estaba rechazado, vuelve a borrador."""
    updates = data.model_dump(exclude_unset=True)

    # Si cambia la categoría, validar que exista
    if "categoria_id" in updates and updates["categoria_id"] is not None:
        await obtener_categoria(db, updates["categoria_id"])

    for campo, valor in updates.items():
        setattr(comercio, campo, valor)

    # Si estaba rechazado y se edita, vuelve a borrador
    if comercio.estado == EstadoComercio.RECHAZADO:
        comercio.estado = EstadoComercio.BORRADOR
        comercio.motivo_rechazo = None

    await db.flush()
    await db.refresh(comercio)
    return comercio


async def eliminar_comercio(
    db: AsyncSession,
    comercio: Comercio,
) -> None:
    """Soft-delete: solo marca activo=False."""
    comercio.activo = False
    await db.flush()


# =========================================================
# Comercios — flujo de verificación
# =========================================================
async def enviar_a_revision(
    db: AsyncSession,
    comercio: Comercio,
) -> Comercio:
    """borrador → pendiente. Requiere horarios cargados."""
    if comercio.estado not in (
        EstadoComercio.BORRADOR,
        EstadoComercio.RECHAZADO,
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No se puede enviar a revisión desde estado '{comercio.estado.value}'",
        )
    if not comercio.horarios:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe cargar al menos un horario antes de enviar a revisión",
        )
    comercio.estado = EstadoComercio.PENDIENTE
    comercio.motivo_rechazo = None
    await db.flush()
    await db.refresh(comercio)
    return comercio


async def verificar_comercio(
    db: AsyncSession,
    comercio: Comercio,
    admin: Usuario,
    categoria_id: UUID | None = None,
) -> Comercio:
    """pendiente → verificado. Admin."""
    if comercio.estado not in (
        EstadoComercio.PENDIENTE,
        EstadoComercio.SUSPENDIDO,
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No se puede verificar desde estado '{comercio.estado.value}'",
        )
    if categoria_id is not None:
        await obtener_categoria(db, categoria_id)
        comercio.categoria_id = categoria_id
    if comercio.categoria_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe asignar una categoría al verificar",
        )

    comercio.estado = EstadoComercio.VERIFICADO
    comercio.motivo_rechazo = None
    comercio.verificado_en = datetime.now(timezone.utc)
    comercio.verificado_por_id = admin.id
    await db.flush()
    await db.refresh(comercio)
    return comercio


async def rechazar_comercio(
    db: AsyncSession,
    comercio: Comercio,
    admin: Usuario,
    motivo: str,
) -> Comercio:
    """pendiente → rechazado. Admin."""
    if comercio.estado != EstadoComercio.PENDIENTE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Solo se puede rechazar desde 'pendiente'",
        )
    comercio.estado = EstadoComercio.RECHAZADO
    comercio.motivo_rechazo = motivo
    comercio.verificado_por_id = admin.id
    await db.flush()
    await db.refresh(comercio)
    return comercio


async def suspender_comercio(
    db: AsyncSession,
    comercio: Comercio,
    admin: Usuario,
    motivo: str,
) -> Comercio:
    """verificado → suspendido. Admin."""
    if comercio.estado != EstadoComercio.VERIFICADO:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Solo se puede suspender desde 'verificado'",
        )
    comercio.estado = EstadoComercio.SUSPENDIDO
    comercio.motivo_rechazo = motivo
    comercio.verificado_por_id = admin.id
    await db.flush()
    await db.refresh(comercio)
    return comercio


async def destacar_comercio(
    db: AsyncSession,
    comercio: Comercio,
    destacado: bool,
) -> Comercio:
    """Toggle destacado. Admin."""
    comercio.destacado = destacado
    await db.flush()
    await db.refresh(comercio)
    return comercio


# =========================================================
# Horarios
# =========================================================
async def setear_horarios(
    db: AsyncSession,
    comercio: Comercio,
    horarios_data: list[HorarioCreate],
) -> list[HorarioComercio]:
    """
    Reemplaza TODOS los horarios del comercio.
    Elimina los existentes y crea los nuevos en una transacción.
    """
    # Eliminar existentes (cascade delete por relationship)
    for h in list(comercio.horarios):
        await db.delete(h)
    await db.flush()

    # Crear nuevos
    nuevos: list[HorarioComercio] = []
    for hdata in horarios_data:
        h = HorarioComercio(
            comercio_id=comercio.id,
            dia_semana=hdata.dia_semana,
            cerrado=hdata.cerrado,
            abre=hdata.abre if not hdata.cerrado else None,
            cierra=hdata.cierra if not hdata.cerrado else None,
        )
        db.add(h)
        nuevos.append(h)
    await db.flush()
    return nuevos


# =========================================================
# Listados públicos y admin
# =========================================================
async def listar_comercios_publicos(
    db: AsyncSession,
    *,
    categoria_id: UUID | None = None,
    busqueda: str | None = None,
    solo_destacados: bool = False,
    acepta_delivery: bool | None = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Comercio], int]:
    """
    Lista comercios verificados con filtros.
    Devuelve (items, total).
    """
    stmt = select(Comercio).where(
        Comercio.estado == EstadoComercio.VERIFICADO,
        Comercio.activo.is_(True),
    )
    if categoria_id is not None:
        stmt = stmt.where(Comercio.categoria_id == categoria_id)
    if busqueda:
        patron = f"%{busqueda.lower()}%"
        stmt = stmt.where(
            or_(
                func.lower(Comercio.nombre).like(patron),
                func.lower(Comercio.descripcion_corta).like(patron),
            )
        )
    if solo_destacados:
        stmt = stmt.where(Comercio.destacado.is_(True))
    if acepta_delivery is not None:
        stmt = stmt.where(Comercio.acepta_delivery.is_(acepta_delivery))

    # Total
    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()

    # Orden: destacados primero, luego rating, luego nombre
    stmt = stmt.order_by(
        Comercio.destacado.desc(),
        Comercio.rating_promedio.desc(),
        Comercio.nombre,
    ).offset((page - 1) * page_size).limit(page_size)

    items = list((await db.execute(stmt)).scalars().all())
    return items, total


async def listar_comercios_admin(
    db: AsyncSession,
    *,
    estado: EstadoComercio | None = None,
    categoria_id: UUID | None = None,
    busqueda: str | None = None,
    incluir_inactivos: bool = False,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Comercio], int]:
    """Lista todos los comercios con filtros (admin)."""
    stmt = select(Comercio)
    if not incluir_inactivos:
        stmt = stmt.where(Comercio.activo.is_(True))
    if estado is not None:
        stmt = stmt.where(Comercio.estado == estado)
    if categoria_id is not None:
        stmt = stmt.where(Comercio.categoria_id == categoria_id)
    if busqueda:
        patron = f"%{busqueda.lower()}%"
        stmt = stmt.where(func.lower(Comercio.nombre).like(patron))

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()

    stmt = stmt.order_by(Comercio.created_at.desc()).offset(
        (page - 1) * page_size
    ).limit(page_size)

    items = list((await db.execute(stmt)).scalars().all())
    return items, total


# =========================================================
# Imágenes
# =========================================================
async def actualizar_logo(
    db: AsyncSession,
    comercio: Comercio,
    logo_url: str,
) -> Comercio:
    comercio.logo_url = logo_url
    await db.flush()
    await db.refresh(comercio)
    return comercio


async def actualizar_portada(
    db: AsyncSession,
    comercio: Comercio,
    portada_url: str,
) -> Comercio:
    comercio.portada_url = portada_url
    await db.flush()
    await db.refresh(comercio)
    return comercio