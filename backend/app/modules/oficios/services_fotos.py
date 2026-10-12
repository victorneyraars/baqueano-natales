"""Services de fotos de ordenes (M5.1).

Privacidad: las fotos NO se sirven por nginx. Todo pasa por el endpoint
autenticado GET /api/v1/ordenes/fotos/{id}/archivo/{variante}, que valida
ownership antes de devolver el archivo.
"""
import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import RolUsuario, Usuario
from app.modules.oficios.models import (
    MomentoFoto,
    OrdenFoto,
    OrdenTrabajo,
    TipoEventoHistorial,
)
from app.modules.prestadores.models import Prestador
from app.shared.storage import (
    FotoProcesada,
    LocalFotoStorage,
    StorageError,
)

logger = logging.getLogger(__name__)

# Rate limits (por hora)
MAX_FOTOS_POR_ORDEN_HORA = 30
MAX_FOTOS_POR_USUARIO_HORA = 100


_storage: LocalFotoStorage | None = None


def _get_storage() -> LocalFotoStorage:
    """Singleton lazy del storage (evita re-instanciar en cada request)."""
    global _storage
    if _storage is None:
        _storage = LocalFotoStorage()
    return _storage


# =========================================================
# Helpers
# =========================================================
def _rol_snapshot(usuario: Usuario) -> str:
    """Devuelve el rol del usuario como string ('cliente'|'prestador'|'admin')."""
    return usuario.rol.value if hasattr(usuario.rol, "value") else str(usuario.rol)


async def _check_rate_limit(
    db: AsyncSession, orden_id: UUID, usuario_id: UUID
) -> None:
    """Aplica rate limit por orden y por usuario (por hora)."""
    hace_1h = datetime.now(timezone.utc) - timedelta(hours=1)

    # Por orden
    n_orden = (
        await db.execute(
            select(func.count(OrdenFoto.id)).where(
                OrdenFoto.orden_id == orden_id,
                OrdenFoto.activo.is_(True),
                OrdenFoto.created_at >= hace_1h,
            )
        )
    ).scalar_one()
    if n_orden >= MAX_FOTOS_POR_ORDEN_HORA:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                f"Limite de {MAX_FOTOS_POR_ORDEN_HORA} fotos por hora "
                f"en esta orden alcanzado"
            ),
        )

    # Por usuario
    n_user = (
        await db.execute(
            select(func.count(OrdenFoto.id)).where(
                OrdenFoto.subido_por_id == usuario_id,
                OrdenFoto.activo.is_(True),
                OrdenFoto.created_at >= hace_1h,
            )
        )
    ).scalar_one()
    if n_user >= MAX_FOTOS_POR_USUARIO_HORA:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                f"Limite de {MAX_FOTOS_POR_USUARIO_HORA} fotos por hora "
                f"alcanzado"
            ),
        )


async def _validar_acceso_orden(
    db: AsyncSession, orden: OrdenTrabajo, usuario: Usuario
) -> None:
    """Valida que el usuario pueda ver/subir fotos a la orden."""
    if usuario.rol == RolUsuario.ADMIN:
        return
    if orden.cliente_id == usuario.id:
        return
    # Prestador dueno
    prestador = (
        await db.execute(
            select(Prestador).where(Prestador.id == orden.prestador_id)
        )
    ).scalar_one_or_none()
    if prestador is not None and prestador.usuario_id == usuario.id:
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="No tenes permiso sobre esta orden",
    )


async def _obtener_orden(
    db: AsyncSession, orden_id: UUID
) -> OrdenTrabajo:
    orden = (
        await db.execute(
            select(OrdenTrabajo).where(OrdenTrabajo.id == orden_id)
        )
    ).scalar_one_or_none()
    if orden is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Orden no encontrada",
        )
    return orden


def _foto_a_response(foto: OrdenFoto) -> dict:
    """Serializa una OrdenFoto para la API (con URLs de variantes)."""
    variantes_meta = foto.metadata_extra.get("variantes_meta", {}) if foto.metadata_extra else {}
    variantes_resp: dict = {}
    for nombre, storage_path in (foto.variantes or {}).items():
        meta = variantes_meta.get(nombre, {})
        variantes_resp[nombre] = {
            "ancho": meta.get("ancho", 0),
            "alto": meta.get("alto", 0),
            "tamano_bytes": meta.get("tamano_bytes", 0),
            "url": f"/api/v1/ordenes/fotos/{foto.id}/archivo/{nombre}",
        }
    return {
        "id": foto.id,
        "orden_id": foto.orden_id,
        "item_id": foto.item_id,
        "momento": foto.momento.value,
        "subido_por_id": foto.subido_por_id,
        "subido_por_rol": foto.subido_por_rol,
        "hash_sha256": foto.hash_sha256,
        "storage_backend": foto.storage_backend,
        "storage_key": foto.storage_key,
        "variantes": variantes_resp,
        "mime_type": foto.mime_type,
        "tamano_bytes": foto.tamano_bytes,
        "ancho": foto.ancho,
        "alto": foto.alto,
        "blurhash": foto.blurhash,
        "descripcion": foto.descripcion,
        "fecha_captura": foto.fecha_captura,
        "activo": foto.activo,
        "created_at": foto.created_at,
    }


# =========================================================
# API publica
# =========================================================
async def subir_foto(
    db: AsyncSession,
    usuario: Usuario,
    orden_id: UUID,
    content: bytes,
    momento: MomentoFoto,
    item_id: UUID | None = None,
    descripcion: str | None = None,
) -> dict:
    """Sube una foto a una orden con el pipeline completo."""
    orden = await _obtener_orden(db, orden_id)
    await _validar_acceso_orden(db, orden, usuario)
    await _check_rate_limit(db, orden_id, usuario.id)

    storage = _get_storage()
    try:
        procesada: FotoProcesada = await storage.save_foto(content)
    except StorageError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        ) from e

    # Dedup logico: si ya existe la misma foto (hash) activa en esta orden,
    # devolver la existente en vez de crear otra fila.
    existente = (
        await db.execute(
            select(OrdenFoto).where(
                OrdenFoto.orden_id == orden_id,
                OrdenFoto.hash_sha256 == procesada.hash_sha256,
                OrdenFoto.activo.is_(True),
            )
        )
    ).scalar_one_or_none()
    if existente is not None:
        logger.info(
            f"Foto duplicada en orden {orden_id}: hash="
            f"{procesada.hash_sha256[:12]}"
        )
        return _foto_a_response(existente)

    foto = OrdenFoto(
        orden_id=orden_id,
        item_id=item_id,
        momento=momento,
        subido_por_id=usuario.id,
        subido_por_rol=_rol_snapshot(usuario),
        hash_sha256=procesada.hash_sha256,
        storage_backend=procesada.storage_backend,
        storage_key=procesada.storage_key,
        variantes=procesada.variantes,
        mime_type=procesada.mime_type,
        tamano_bytes=procesada.tamano_bytes,
        ancho=procesada.ancho,
        alto=procesada.alto,
        blurhash=procesada.blurhash,
        descripcion=descripcion,
        metadata_extra={
            "variantes_meta": {
                nombre: {
                    "ancho": v.ancho,
                    "alto": v.alto,
                    "tamano_bytes": v.tamano_bytes,
                }
                for nombre, v in procesada.variantes_meta.items()
            },
        },
    )
    db.add(foto)
    await db.flush()

    # Registrar en historial (best-effort, no rompe si falla)
    try:
        from app.modules.oficios.services import _registrar_evento

        await _registrar_evento(
            db,
            orden_id=orden_id,
            tipo=TipoEventoHistorial.FOTO,
            usuario_id=usuario.id,
            contenido={
                "foto_id": str(foto.id),
                "momento": momento.value,
                "descripcion": descripcion,
            },
        )
    except Exception as e:
        logger.warning(f"No se pudo registrar evento de foto: {e}")

    await db.commit()
    await db.refresh(foto)
    return _foto_a_response(foto)


async def listar_fotos(
    db: AsyncSession,
    usuario: Usuario,
    orden_id: UUID,
    momento: MomentoFoto | None = None,
) -> list[dict]:
    """Lista las fotos activas de una orden."""
    orden = await _obtener_orden(db, orden_id)
    await _validar_acceso_orden(db, orden, usuario)

    stmt = select(OrdenFoto).where(
        OrdenFoto.orden_id == orden_id,
        OrdenFoto.activo.is_(True),
    )
    if momento is not None:
        stmt = stmt.where(OrdenFoto.momento == momento)
    stmt = stmt.order_by(OrdenFoto.created_at, OrdenFoto.id)

    fotos = (await db.execute(stmt)).scalars().all()
    return [_foto_a_response(f) for f in fotos]


async def obtener_foto_para_servir(
    db: AsyncSession,
    usuario: Usuario,
    foto_id: UUID,
) -> OrdenFoto:
    """Carga una foto validando ownership (para servir el archivo)."""
    foto = (
        await db.execute(
            select(OrdenFoto).where(
                OrdenFoto.id == foto_id,
                OrdenFoto.activo.is_(True),
            )
        )
    ).scalar_one_or_none()
    if foto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Foto no encontrada",
        )
    orden = await _obtener_orden(db, foto.orden_id)
    await _validar_acceso_orden(db, orden, usuario)
    return foto


async def leer_variante(
    foto: OrdenFoto, variante: str
) -> bytes:
    """Lee los bytes de una variante especifica."""
    storage = _get_storage()
    try:
        return await storage.read_variante(foto.storage_key, variante)
    except StorageError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        ) from e


async def eliminar_foto(
    db: AsyncSession,
    usuario: Usuario,
    foto_id: UUID,
) -> None:
    """Soft-delete de una foto. Solo el uploader, dueno del taller o admin."""
    foto = (
        await db.execute(
            select(OrdenFoto).where(
                OrdenFoto.id == foto_id,
                OrdenFoto.activo.is_(True),
            )
        )
    ).scalar_one_or_none()
    if foto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Foto no encontrada",
        )
    orden = await _obtener_orden(db, foto.orden_id)
    await _validar_acceso_orden(db, orden, usuario)

    # Cliente solo puede borrar las suyas; prestador dueno y admin, cualquiera
    es_admin = usuario.rol == RolUsuario.ADMIN
    es_uploader = foto.subido_por_id == usuario.id
    prestador = (
        await db.execute(
            select(Prestador).where(Prestador.id == orden.prestador_id)
        )
    ).scalar_one_or_none()
    es_prestador_dueno = prestador is not None and prestador.usuario_id == usuario.id

    if not (es_admin or es_uploader or es_prestador_dueno):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el autor, el dueno del taller o un admin pueden borrar",
        )

    foto.activo = False
    await db.commit()
    logger.info(f"Foto {foto_id} marcada inactiva por usuario {usuario.id}")
