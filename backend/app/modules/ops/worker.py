"""
Worker de cleanup automático (cron diario).

Scheduler in-process (APScheduler) que corre el cleanup de datos
incompletos cada CLEANUP_WORKER_INTERVAL_SEC segundos (default 24h).

El worker NUNCA debe crashear el scheduler: cualquier excepción se
captura, se loggea, y se reintenta en el próximo ciclo.
"""
import logging
from datetime import datetime, timezone
from uuid import UUID

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.core.config import settings
from app.core.db import AsyncSessionLocal
from app.modules.ops import services_audit, services_cleanup

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None

# ID del "usuario" del sistema para audit log
SYSTEM_USER_ID = UUID("00000000-0000-0000-0000-000000000000")
SYSTEM_USER_EMAIL = "system@baqueanonatales.com"


# ============================================================
# Ciclo
# ============================================================

async def ejecutar_ciclo_cleanup() -> None:
    """
    Ejecuta un ciclo del cleanup:
    1. Detecta registros con datos incompletos.
    2. Sanitiza prestadores (borrador).
    3. Loguea comercios (solo reporte).
    4. Registra todo en ops_audit_log.
    """
    inicio = datetime.now(timezone.utc)
    logger.info("ops.cleanup.worker: ciclo iniciado")

    try:
        async with AsyncSessionLocal() as db:
            # 1. Ejecutar cleanup
            resultado = await services_cleanup.ejecutar_cleanup(
                db,
                dry_run=settings.CLEANUP_DRY_RUN,
            )
            await db.commit()

            # 2. Calcular duración
            fin = datetime.now(timezone.utc)
            duration_ms = int((fin - inicio).total_seconds() * 1000)

            # 3. Audit log
            await services_audit.registrar(
                db=None,  # sesión propia (post-cycle)
                user_id=SYSTEM_USER_ID,
                user_email=SYSTEM_USER_EMAIL,
                action="cleanup.run",
                status="success",
                target="prestadores+comercios",
                payload={"dry_run": resultado["dry_run"]},
                result=resultado,
                duration_ms=duration_ms,
            )

            logger.info(
                f"ops.cleanup.worker: ciclo OK. "
                f"prestadores={resultado['prestadores_detectados']} "
                f"comercios={resultado['comercios_detectados']} "
                f"({duration_ms}ms)"
            )

    except Exception as exc:
        logger.exception(f"ops.cleanup.worker: ciclo FALLÓ: {exc}")
        try:
            await services_audit.registrar(
                db=None,
                user_id=SYSTEM_USER_ID,
                user_email=SYSTEM_USER_EMAIL,
                action="cleanup.run",
                status="error",
                target="prestadores+comercios",
                error_message=str(exc)[:2000],
            )
        except Exception:
            pass  # no romper el scheduler


# ============================================================
# Lifecycle
# ============================================================

def start_worker() -> None:
    """Arranca el scheduler con el cron de cleanup."""
    global _scheduler
    if _scheduler is not None:
        logger.warning("ops.cleanup.worker: ya estaba corriendo")
        return

    if not settings.CLEANUP_WORKER_ENABLED:
        logger.info("ops.cleanup.worker: deshabilitado por config")
        return

    _scheduler = AsyncIOScheduler()
    _scheduler.add_job(
        ejecutar_ciclo_cleanup,
        "interval",
        seconds=settings.CLEANUP_WORKER_INTERVAL_SEC,
        id="ops_cleanup",
        max_instances=1,
        coalesce=True,
    )
    _scheduler.start()
    logger.info(
        f"ops.cleanup.worker: iniciado "
        f"(intervalo={settings.CLEANUP_WORKER_INTERVAL_SEC}s, "
        f"dry_run={settings.CLEANUP_DRY_RUN})"
    )


def stop_worker() -> None:
    """Detiene el scheduler."""
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
        logger.info("ops.cleanup.worker: detenido")
