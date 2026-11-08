"""Endpoints de gestion de admins a prestadores (multi-tenant).

Solo el super_admin del ecosistema puede:
- Asignar admins a prestadores
- Revocar admins de prestadores
- Listar admins de un prestador
- Listar prestadores de un admin
"""

from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select, delete

from app.core.db import DbSession
from app.modules.auth.deps import SuperAdminUser, AdminUser, get_admin_prestadores_ids
from app.modules.auth.models import Usuario, RolUsuario
from app.modules.auth.models_admin_prestador import AdminPrestador
from app.modules.prestadores.models import Prestador

router = APIRouter(prefix="/admin/usuarios", tags=["admin-prestadores"])


class AsignarPrestadorRequest(BaseModel):
    prestador_id: UUID


class PrestadorDeAdminResponse(BaseModel):
    id: UUID
    slug: str
    nombre: str


class AdminDePrestadorResponse(BaseModel):
    id: UUID
    email: str | None
    nombre: str | None
    es_super_admin: bool


@router.post(
    "/{user_id}/prestadores",
    status_code=status.HTTP_201_CREATED,
    summary="Asignar admin a prestador (solo super admin)",
)
async def asignar_admin_a_prestador(
    user_id: UUID,
    data: AsignarPrestadorRequest,
    db: DbSession,
    _super: SuperAdminUser,
):
    result = await db.execute(select(Usuario).where(Usuario.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if user.rol != RolUsuario.ADMIN:
        raise HTTPException(status_code=400, detail="El usuario debe tener rol admin")

    result = await db.execute(select(Prestador).where(Prestador.id == data.prestador_id))
    prestador = result.scalar_one_or_none()
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador no encontrado")

    result = await db.execute(
        select(AdminPrestador).where(
            AdminPrestador.admin_id == user_id,
            AdminPrestador.prestador_id == data.prestador_id,
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Ya existe esta asignacion")

    nueva = AdminPrestador(admin_id=user_id, prestador_id=data.prestador_id)
    db.add(nueva)
    await db.commit()

    return {"ok": True, "mensaje": f"Admin {user.email} asignado a {prestador.nombre}"}


@router.delete(
    "/{user_id}/prestadores/{prestador_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Revocar admin de prestador (solo super admin)",
)
async def revocar_admin_de_prestador(
    user_id: UUID,
    prestador_id: UUID,
    db: DbSession,
    _super: SuperAdminUser,
):
    result = await db.execute(
        delete(AdminPrestador).where(
            AdminPrestador.admin_id == user_id,
            AdminPrestador.prestador_id == prestador_id,
        )
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Asignacion no encontrada")
    await db.commit()


@router.get(
    "/me/prestadores",
    response_model=list[PrestadorDeAdminResponse],
    summary="Listar prestadores del admin actual",
)
async def mis_prestadores(db: DbSession, user: AdminUser):
    prestador_ids = await get_admin_prestadores_ids(user, db)
    if prestador_ids is None:
        result = await db.execute(select(Prestador).order_by(Prestador.nombre))
    else:
        if not prestador_ids:
            return []
        result = await db.execute(
            select(Prestador).where(Prestador.id.in_(prestador_ids)).order_by(Prestador.nombre)
        )
    prestadores = result.scalars().all()
    return [PrestadorDeAdminResponse(id=p.id, slug=p.slug, nombre=p.nombre) for p in prestadores]


@router.get(
    "/{user_id}/prestadores",
    response_model=list[PrestadorDeAdminResponse],
    summary="Listar prestadores de un admin",
)
async def listar_prestadores_de_admin(
    user_id: UUID,
    db: DbSession,
    _admin: AdminUser,
):
    result = await db.execute(
        select(Prestador)
        .join(AdminPrestador, AdminPrestador.prestador_id == Prestador.id)
        .where(AdminPrestador.admin_id == user_id)
        .order_by(Prestador.nombre)
    )
    prestadores = result.scalars().all()
    return [PrestadorDeAdminResponse(id=p.id, slug=p.slug, nombre=p.nombre) for p in prestadores]


@router.get(
    "/prestadores/{prestador_id}/admins",
    response_model=list[AdminDePrestadorResponse],
    summary="Listar admins de un prestador",
)
async def listar_admins_de_prestador(
    prestador_id: UUID,
    db: DbSession,
    _admin: AdminUser,
):
    result = await db.execute(
        select(Usuario)
        .join(AdminPrestador, AdminPrestador.admin_id == Usuario.id)
        .where(AdminPrestador.prestador_id == prestador_id)
        .order_by(Usuario.email)
    )
    admins = result.scalars().all()
    return [
        AdminDePrestadorResponse(
            id=u.id, email=u.email, nombre=u.nombre, es_super_admin=u.es_super_admin
        )
        for u in admins
    ]
