"""
Servicio de cleanup automático de datos incompletos.

Detecta registros públicos (verificados) con datos faltantes que
romperían el render de la web o mostrarían cards rotas, y los
sanitiza (prestadores) o loguea (comercios) para revisión manual.

Uso:
- Programado: APScheduler cada 24h (ver worker.py).
- Manual: POST /admin/ops/cleanup (útil para admins).
- Dry-run: GET /admin/ops/cleanup/preview (no modifica nada).
"""
import logging
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.comercios.models import Comercio, EstadoComercio
from app.modules.prestadores.models import EstadoPrestador, Prestador

logger = logging.getLogger(__name__)


# ============================================================
# Detección
# ============================================================

async def detectar_prestadores_incompletos(
    db: AsyncSession,
) -> list[Prestador]:
    """
    Prestadores verificados con datos incompletos que romperían la web:
    - especialidades = NULL o vacío
    - categoria_id = NULL
    """
    stmt = select(Prestador).where(
        Prestador.estado == EstadoPrestador.VERIFICADO,
        Prestador.activo.is_(True),
    )
    prestadores = list((await db.execute(stmt)).scalars().all())

    incompletos = []
    for p in prestadores:
        if not p.categoria_id or not p.especialidades:
            incompletos.append(p)
    return incompletos


async def detectar_comercios_incompletos(
    db: AsyncSession,
) -> list[Comercio]:
    """
    Comercios verificados con datos incompletos que romperían la web:
    - categoria_id = NULL (rompe la URL /locales/{cat}/{slug})
    """
    stmt = select(Comercio).where(
        Comercio.estado == EstadoComercio.VERIFICADO,
        Comercio.activo.is_(True),
    )
    comercios = list((await db.execute(stmt)).scalars().all())

    return [c for c in comercios if not c.categoria_id]


# ============================================================
# Resolución
# ============================================================

def _detalle_prestador(p: Prestador) -> dict[str, Any]:
    return {
        "id": str(p.id),
        "slug": p.slug,
        "nombre": p.nombre,
        "falta_categoria": not bool(p.categoria_id),
        "falta_especialidades": not bool(p.especialidades),
    }


def _detalle_comercio(c: Comercio) -> dict[str, Any]:
    return {
        "id": str(c.id),
        "slug": c.slug,
        "nombre": c.nombre,
        "falta_categoria": not bool(c.categoria_id),
    }


async def ejecutar_cleanup(
    db: AsyncSession,
    *,
    dry_run: bool = False,
) -> dict[str, Any]:
    """
    Ejecuta el cleanup completo.

    Política:
    - Prestadores verificados con datos incompletos → pasar a BORRADOR
      (dejan de ser públicos, no rompen la web).
    - Comercios verificados con datos incompletos → solo loguear
      (no se tocan automáticamente, requieren revisión manual).

    Args:
        db: sesión de DB.
        dry_run: si True, no modifica nada, solo reporta lo que haría.

    Returns:
        Resumen con contadores + lista de registros afectados.
    """
    logger.info(f"ops.cleanup: iniciando (dry_run={dry_run})")

    prestadores = await detectar_prestadores_incompletos(db)
    comercios = await detectar_comercios_incompletos(db)

    prestadores_afectados = [_detalle_prestador(p) for p in prestadores]
    comercios_afectados = [_detalle_comercio(c) for c in comercios]

    if not dry_run:
        for p in prestadores:
            p.estado = EstadoPrestador.BORRADOR
            logger.warning(
                f"ops.cleanup: prestador {p.slug} → borrador "
                f"(falta_categoria={not p.categoria_id}, "
                f"falta_especialidades={not p.especialidades})"
            )
        await db.flush()

    resumen = {
        "dry_run": dry_run,
        "prestadores_detectados": len(prestadores),
        "prestadores_sanitizados": 0 if dry_run else len(prestadores),
        "prestadores_detalle": prestadores_afectados,
        "comercios_detectados": len(comercios),
        "comercios_detalle": comercios_afectados,
    }

    logger.info(
        f"ops.cleanup: completado. "
        f"prestadores={len(prestadores)} "
        f"comercios={len(comercios)} "
        f"dry_run={dry_run}"
    )
    return resumen
