"""
Servicios de administración.
Lógica de negocio para gestión de usuarios, roles y estadísticas.
"""
import logging
from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.admin.schemas import ListarUsuariosQuery
from app.modules.auth.models import RolUsuario, Usuario

logger = logging.getLogger(__name__)


# ---------------------------------------------------------
# Listado de usuarios
# ---------------------------------------------------------
def _build_usuarios_query(query: ListarUsuariosQuery):
    """Construye la query SQL con los filtros aplicados."""
    stmt = select(Usuario)

    if query.rol is not None:
        stmt = stmt.where(Usuario.rol == query.rol)

    if query.activo is not None:
        stmt = stmt.where(Usuario.activo.is_(query.activo))

    if query.verificado is not None:
        stmt = stmt.where(Usuario.verificado.is_(query.verificado))

    if query.search:
        pattern = f"%{query.search.strip()}%"
        stmt = stmt.where(
            or_(
                Usuario.email.ilike(pattern),
                Usuario.nombre.ilike(pattern),
                Usuario.apellido.ilike(pattern),
            )
        )

    return stmt


async def listar_usuarios(
    db: AsyncSession,
    query: ListarUsuariosQuery,
) -> tuple[list[Usuario], int]:
    """
    Lista usuarios con filtros y paginación.

    Returns:
        Tupla (lista de usuarios, total de usuarios que matchean el filtro).
    """
    # Query de conteo (sin paginación)
    count_stmt = select(func.count()).select_from(
        _build_usuarios_query(query).subquery()
    )
    total = (await db.execute(count_stmt)).scalar() or 0

    # Query paginada
    stmt = _build_usuarios_query(query)
    stmt = stmt.order_by(Usuario.created_at.desc())
    stmt = stmt.limit(query.limit).offset(query.offset)

    result = await db.execute(stmt)
    usuarios = list(result.scalars().all())

    return usuarios, total


async def get_usuario_by_id(
    db: AsyncSession,
    user_id: UUID,
) -> Usuario | None:
    """Busca un usuario por ID (incluye inactivos)."""
    result = await db.execute(select(Usuario).where(Usuario.id == user_id))
    return result.scalar_one_or_none()


# ---------------------------------------------------------
# Cambios de estado/rol
# ---------------------------------------------------------
async def cambiar_rol(
    db: AsyncSession,
    user: Usuario,
    nuevo_rol: RolUsuario,
    admin_actual: Usuario,
) -> Usuario:
    """
    Cambia el rol de un usuario.

    Validaciones:
    - No puede cambiar su propio rol (evita degradarse a sí mismo por error).
    - No puede quedar el sistema sin admins.

    Raises:
        ValueError: si la operación violaría alguna regla.
    """
    if user.id == admin_actual.id:
        raise ValueError("No puedes cambiar tu propio rol")

    # Si vamos a degradar a un admin, verificar que queden otros
    if user.rol == RolUsuario.ADMIN and nuevo_rol != RolUsuario.ADMIN:
        count_admins = await _count_admins_activos(db)
        if count_admins <= 1:
            raise ValueError(
                "No se puede degradar al último admin activo del sistema"
            )

    user.rol = nuevo_rol
    await db.flush()
    await db.refresh(user)
    logger.info(
        f"Rol cambiado: usuario={user.id} nuevo_rol={nuevo_rol.value} "
        f"(por admin={admin_actual.id})"
    )
    return user


async def verificar_usuario(
    db: AsyncSession,
    user: Usuario,
    verificado: bool,
    admin_actual: Usuario,
) -> Usuario:
    """Marca o desmarca un usuario como verificado."""
    user.verificado = verificado
    await db.flush()
    await db.refresh(user)
    logger.info(
        f"Verificación actualizada: usuario={user.id} verificado={verificado} "
        f"(por admin={admin_actual.id})"
    )
    return user


async def reactivar_usuario(
    db: AsyncSession,
    user: Usuario,
    admin_actual: Usuario,
) -> Usuario:
    """Reactiva un usuario previamente desactivado."""
    user.activo = True
    await db.flush()
    await db.refresh(user)
    logger.info(
        f"Usuario reactivado: {user.id} (por admin={admin_actual.id})"
    )
    return user


async def desactivar_usuario(
    db: AsyncSession,
    user: Usuario,
    admin_actual: Usuario,
) -> Usuario:
    """
    Desactiva un usuario (soft delete).

    Validaciones:
    - No puede desactivar su propia cuenta.
    - No puede dejar el sistema sin admins activos.
    """
    if user.id == admin_actual.id:
        raise ValueError("No puedes desactivar tu propia cuenta")

    if user.rol == RolUsuario.ADMIN:
        count_admins = await _count_admins_activos(db)
        if count_admins <= 1:
            raise ValueError(
                "No se puede desactivar al último admin activo"
            )

    user.activo = False
    await db.flush()
    await db.refresh(user)
    logger.warning(
        f"Usuario desactivado: {user.id} (por admin={admin_actual.id})"
    )
    return user


# ---------------------------------------------------------
# Estadísticas
# ---------------------------------------------------------
async def _count_admins_activos(db: AsyncSession) -> int:
    """Cuenta cuántos admins activos hay."""
    stmt = select(func.count()).select_from(Usuario).where(
        Usuario.rol == RolUsuario.ADMIN,
        Usuario.activo.is_(True),
    )
    return (await db.execute(stmt)).scalar() or 0


async def get_estadisticas(db: AsyncSession) -> dict:
    """Devuelve estadísticas globales de usuarios."""
    # Total
    total = (await db.execute(
        select(func.count()).select_from(Usuario)
    )).scalar() or 0

    # Activos / inactivos
    activos = (await db.execute(
        select(func.count()).select_from(Usuario).where(Usuario.activo.is_(True))
    )).scalar() or 0
    inactivos = total - activos

    # Verificados
    verificados = (await db.execute(
        select(func.count()).select_from(Usuario).where(
            Usuario.verificado.is_(True)
        )
    )).scalar() or 0

    # Por rol
    stmt = select(Usuario.rol, func.count()).group_by(Usuario.rol)
    result = await db.execute(stmt)
    por_rol = {rol.value: count for rol, count in result.all()}

    return {
        "total": total,
        "activos": activos,
        "inactivos": inactivos,
        "verificados": verificados,
        "por_rol": por_rol,
    }


async def obtener_onboarding_mode(db) -> str:
    from sqlalchemy import select
    from app.modules.admin.models import Configuracion
    cfg = (await db.execute(select(Configuracion).where(Configuracion.clave == 'onboarding_mode'))).scalar_one_or_none()
    return cfg.valor if cfg else 'open'

async def set_onboarding_mode(db, modo: str) -> str:
    from sqlalchemy import select
    from app.modules.admin.models import Configuracion
    cfg = (await db.execute(select(Configuracion).where(Configuracion.clave == 'onboarding_mode'))).scalar_one_or_none()
    if cfg:
        cfg.valor = modo
    else:
        cfg = Configuracion(clave='onboarding_mode', valor=modo)
        db.add(cfg)
    await db.commit()
    return modo
