"""Services del modulo oficios (M1: objetos_servicio + vehiculos + catalogos)."""
import logging
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import RolUsuario, Usuario
from app.modules.oficios.models import (
    MecanicaCategoriaServicio,
    MecanicaRepuesto,
    ObjetoServicio,
    TipoObjetoServicio,
    TipoVehiculo,
    Vehiculo,
)
from app.modules.oficios.schemas import (
    MecanicaCategoriaCreate,
    MecanicaCategoriaUpdate,
    MecanicaRepuestoCreate,
    MecanicaRepuestoUpdate,
    VehiculoCreate,
    VehiculoUpdate,
)

logger = logging.getLogger(__name__)


# =========================================================
# Helpers
# =========================================================
def _slugify(texto: str) -> str:
    """Slug basico (sin acentos, lowercase, guiones)."""
    import re
    import unicodedata

    nfkd = unicodedata.normalize("NFKD", texto)
    sin_ac = "".join(c for c in nfkd if not unicodedata.combining(c))
    s = sin_ac.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def _vehiculo_a_response(obj: ObjetoServicio, veh: Vehiculo) -> dict:
    """Combina objeto_servicio + vehiculo en un dict de respuesta."""
    return {
        "objeto_servicio_id": obj.id,
        "alias": obj.alias,
        "notas": obj.notas,
        "activo": obj.activo,
        "created_at": obj.created_at,
        "updated_at": obj.updated_at,
        "patente": veh.patente,
        "vin": veh.vin,
        "marca": veh.marca,
        "modelo": veh.modelo,
        "anio": veh.anio,
        "color": veh.color,
        "tipo_vehiculo": veh.tipo_vehiculo.value,
        "kilometraje_actual": veh.kilometraje_actual,
        "fecha_ultima_revision": veh.fecha_ultima_revision,
    }


# =========================================================
# Vehiculos (cliente)
# =========================================================
async def crear_vehiculo(
    db: AsyncSession,
    usuario: Usuario,
    data: VehiculoCreate,
) -> dict:
    """Crea objeto_servicio (tipo=vehiculo) + vehiculo en una transaccion."""
    # Validar patente unica
    existente = (
        await db.execute(
            select(Vehiculo).where(Vehiculo.patente == data.patente.upper())
        )
    ).scalar_one_or_none()
    if existente is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"La patente {data.patente} ya esta registrada",
        )

    # Validar tipo_vehiculo
    try:
        tipo = TipoVehiculo(data.tipo_vehiculo)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"tipo_vehiculo invalido: {data.tipo_vehiculo}",
        )

    # 1) Objeto de servicio
    obj = ObjetoServicio(
        tipo=TipoObjetoServicio.VEHICULO,
        propietario_id=usuario.id,
        alias=data.alias,
        notas=data.notas,
    )
    db.add(obj)
    await db.flush()  # para tener obj.id

    # 2) Vehiculo satelite
    veh = Vehiculo(
        objeto_servicio_id=obj.id,
        patente=data.patente.upper(),
        vin=data.vin,
        marca=data.marca,
        modelo=data.modelo,
        anio=data.anio,
        color=data.color,
        tipo_vehiculo=tipo,
        kilometraje_actual=data.kilometraje_actual,
        fecha_ultima_revision=data.fecha_ultima_revision,
    )
    db.add(veh)
    await db.flush()

    return _vehiculo_a_response(obj, veh)


async def listar_mis_vehiculos(db: AsyncSession, usuario: Usuario) -> list[dict]:
    """Lista los vehiculos activos del usuario."""
    stmt = (
        select(ObjetoServicio, Vehiculo)
        .join(Vehiculo, Vehiculo.objeto_servicio_id == ObjetoServicio.id)
        .where(
            ObjetoServicio.propietario_id == usuario.id,
            ObjetoServicio.tipo == TipoObjetoServicio.VEHICULO,
            ObjetoServicio.activo.is_(True),
        )
        .order_by(ObjetoServicio.created_at.desc())
    )
    rows = (await db.execute(stmt)).all()
    return [_vehiculo_a_response(obj, veh) for obj, veh in rows]


async def _obtener_objeto_propietario(
    db: AsyncSession,
    usuario: Usuario,
    objeto_id: UUID,
) -> tuple[ObjetoServicio, Vehiculo]:
    """Carga objeto+vehiculo validando permisos (propietario o admin)."""
    stmt = (
        select(ObjetoServicio, Vehiculo)
        .join(Vehiculo, Vehiculo.objeto_servicio_id == ObjetoServicio.id)
        .where(
            ObjetoServicio.id == objeto_id,
            ObjetoServicio.activo.is_(True),
        )
    )
    row = (await db.execute(stmt)).one_or_none()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehiculo no encontrado",
        )
    obj, veh = row
    if usuario.rol != RolUsuario.ADMIN and obj.propietario_id != usuario.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso sobre este vehiculo",
        )
    return obj, veh


async def obtener_mi_vehiculo(
    db: AsyncSession, usuario: Usuario, objeto_id: UUID
) -> dict:
    obj, veh = await _obtener_objeto_propietario(db, usuario, objeto_id)
    return _vehiculo_a_response(obj, veh)


async def actualizar_vehiculo(
    db: AsyncSession,
    usuario: Usuario,
    objeto_id: UUID,
    data: VehiculoUpdate,
) -> dict:
    obj, veh = await _obtener_objeto_propietario(db, usuario, objeto_id)

    # Actualizar campos del objeto_servicio
    if data.alias is not None:
        obj.alias = data.alias
    if data.notas is not None:
        obj.notas = data.notas

    # Actualizar campos del vehiculo
    if data.vin is not None:
        veh.vin = data.vin
    if data.marca is not None:
        veh.marca = data.marca
    if data.modelo is not None:
        veh.modelo = data.modelo
    if data.anio is not None:
        veh.anio = data.anio
    if data.color is not None:
        veh.color = data.color
    if data.tipo_vehiculo is not None:
        try:
            veh.tipo_vehiculo = TipoVehiculo(data.tipo_vehiculo)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"tipo_vehiculo invalido: {data.tipo_vehiculo}",
            )
    if data.kilometraje_actual is not None:
        veh.kilometraje_actual = data.kilometraje_actual
    if data.fecha_ultima_revision is not None:
        veh.fecha_ultima_revision = data.fecha_ultima_revision

    await db.flush()
    return _vehiculo_a_response(obj, veh)


async def eliminar_vehiculo(
    db: AsyncSession, usuario: Usuario, objeto_id: UUID
) -> None:
    """Soft delete: marca el objeto_servicio como inactivo."""
    obj, _ = await _obtener_objeto_propietario(db, usuario, objeto_id)
    obj.activo = False
    await db.flush()


# =========================================================
# Mecanica: Categorias (publico + admin)
# =========================================================
async def listar_categorias_mecanica(
    db: AsyncSession, solo_activas: bool = True
) -> list[MecanicaCategoriaServicio]:
    stmt = select(MecanicaCategoriaServicio).order_by(
        MecanicaCategoriaServicio.orden,
        MecanicaCategoriaServicio.nombre,
    )
    if solo_activas:
        stmt = stmt.where(MecanicaCategoriaServicio.activo.is_(True))
    return list((await db.execute(stmt)).scalars().all())


async def crear_categoria_mecanica(
    db: AsyncSession, data: MecanicaCategoriaCreate
) -> MecanicaCategoriaServicio:
    slug = data.slug or _slugify(data.nombre)
    # Validar slug unico
    existente = (
        await db.execute(
            select(MecanicaCategoriaServicio).where(
                MecanicaCategoriaServicio.slug == slug
            )
        )
    ).scalar_one_or_none()
    if existente is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ya existe una categoria con slug '{slug}'",
        )
    obj = MecanicaCategoriaServicio(
        nombre=data.nombre,
        slug=slug,
        descripcion=data.descripcion,
        icono=data.icono,
        color_hex=data.color_hex,
        orden=data.orden,
    )
    db.add(obj)
    await db.flush()
    return obj


async def actualizar_categoria_mecanica(
    db: AsyncSession, cat_id: UUID, data: MecanicaCategoriaUpdate
) -> MecanicaCategoriaServicio:
    obj = (
        await db.execute(
            select(MecanicaCategoriaServicio).where(
                MecanicaCategoriaServicio.id == cat_id
            )
        )
    ).scalar_one_or_none()
    if obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoria no encontrada",
        )
    if data.nombre is not None:
        obj.nombre = data.nombre
    if data.descripcion is not None:
        obj.descripcion = data.descripcion
    if data.icono is not None:
        obj.icono = data.icono
    if data.color_hex is not None:
        obj.color_hex = data.color_hex
    if data.orden is not None:
        obj.orden = data.orden
    if data.activo is not None:
        obj.activo = data.activo
    await db.flush()
    return obj


# =========================================================
# Mecanica: Repuestos (publico + admin)
# =========================================================
async def listar_repuestos(
    db: AsyncSession,
    busqueda: str | None = None,
    categoria_id: UUID | None = None,
    solo_activos: bool = True,
) -> list[MecanicaRepuesto]:
    stmt = select(MecanicaRepuesto)
    if solo_activos:
        stmt = stmt.where(MecanicaRepuesto.activo.is_(True))
    if categoria_id is not None:
        stmt = stmt.where(MecanicaRepuesto.categoria_id == categoria_id)
    if busqueda:
        like = f"%{busqueda}%"
        stmt = stmt.where(
            MecanicaRepuesto.nombre.ilike(like)
            | MecanicaRepuesto.codigo_oem.ilike(like)
            | MecanicaRepuesto.marca.ilike(like)
        )
    stmt = stmt.order_by(MecanicaRepuesto.nombre).limit(200)
    return list((await db.execute(stmt)).scalars().all())


async def crear_repuesto(
    db: AsyncSession, data: MecanicaRepuestoCreate
) -> MecanicaRepuesto:
    obj = MecanicaRepuesto(**data.model_dump())
    db.add(obj)
    await db.flush()
    return obj


async def actualizar_repuesto(
    db: AsyncSession, rep_id: UUID, data: MecanicaRepuestoUpdate
) -> MecanicaRepuesto:
    obj = (
        await db.execute(
            select(MecanicaRepuesto).where(MecanicaRepuesto.id == rep_id)
        )
    ).scalar_one_or_none()
    if obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Repuesto no encontrado",
        )
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    await db.flush()
    return obj
