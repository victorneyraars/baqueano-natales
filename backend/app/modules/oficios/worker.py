"""Worker de recordatorios automaticos (cron diario).

Scheduler in-process (APScheduler) que revisa la tabla `recordatorios`
y evalua las condiciones pendientes:

    Cada ciclo (default: cada 1 hora):
        - traer recordatorios activos + no enviados (hasta N)
        - por cada uno:
            * evaluar condicion (km/fecha/evento)
            * si se cumple: marcar enviado + (futuro) notificar al dueno
            * si no se cumple: dejar pendiente

El worker NUNCA debe crashear el scheduler: cualquier excepcion se
captura, se loggea, y se reintenta en el proximo ciclo.

Decisiones:
- AsyncIOScheduler: mismo event loop que FastAPI, sin threads.
- Sesion DB propia por ciclo: no depende de Depends() de FastAPI.
- Notificaciones: por ahora se marca enviado y se loggea. La
  integracion con push/FCM viene en M5.
"""
import logging
from datetime import date, datetime, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db import AsyncSessionLocal
from app.modules.oficios import services
from app.modules.oficios.models import (
    ObjetoServicio,
    Recordatorio,
    TipoObjetoServicio,
    TipoRecordatorio,
    Vehiculo,
)

logger = logging.getLogger(__name__)


# ------------------------------------------------------------------ singleton

_scheduler: AsyncIOScheduler | None = None


# ------------------------------------------------------------------ ciclo

async def procesar_recordatorios(db: AsyncSession | None = None) -> dict:
    """Un ciclo del worker.

    Args:
        db: Si es None, abre una sesion propia (uso en produccion desde
            el scheduler). Si se pasa, la usa (tests + endpoint manual).

    Disenado para NUNCA lanzar: cualquier error se loggea y se reporta
    en el dict de stats.
    """
    if db is None:
        async with AsyncSessionLocal() as session:
            return await _procesar_con_db(session)
    return await _procesar_con_db(db)


async def _procesar_con_db(db: AsyncSession) -> dict:
    """Implementacion del ciclo. Recibe una sesion ya abierta."""
    stats = {"evaluados": 0, "enviados": 0, "pendientes": 0, "errores": 0}

    try:
        pendientes = await services.buscar_recordatorios_pendientes(db, limit=200)
        if not pendientes:
            return stats

        logger.info("Worker recordatorios: %d pendientes", len(pendientes))

        for rec in pendientes:
            stats["evaluados"] += 1
            try:
                se_cumple = await _evaluar_condicion(db, rec)
                if se_cumple:
                    await services.marcar_recordatorio_enviado(db, rec.id)
                    await db.commit()
                    stats["enviados"] += 1
                    logger.info(
                        "Worker recordatorios: enviado id=%s tipo=%s",
                        rec.id, rec.tipo.value,
                    )
                    # TODO M5: enviar notificacion push/in-app al dueno
                else:
                    stats["pendientes"] += 1
            except Exception:
                logger.exception(
                    "Worker recordatorios: error procesando rec=%s", rec.id,
                )
                stats["errores"] += 1
                await db.rollback()

    except Exception as e:
        logger.exception("Worker recordatorios: error en ciclo: %s", e)

    if stats["evaluados"] > 0:
        logger.info("Worker recordatorios: ciclo %s", stats)
    return stats


async def _evaluar_condicion(db: AsyncSession, rec: Recordatorio) -> bool:
    """Devuelve True si el recordatorio debe enviarse ahora.

    Reglas:
    - KM: se cumple si Vehiculo.kilometraje_actual >= km_umbral.
      (Solo para objetos tipo VEHICULO)
    - FECHA: se cumple si hoy >= fecha de la condicion.
    - EVENTO: siempre se cumple (el evento lo dispara el sistema).
    """
    if rec.tipo == TipoRecordatorio.KM:
        # Solo vehiculos
        obj = (
            await db.execute(
                select(ObjetoServicio).where(ObjetoServicio.id == rec.objeto_servicio_id)
            )
        ).scalar_one_or_none()
        if obj is None or obj.tipo != TipoObjetoServicio.VEHICULO:
            # Objeto borrado o no es vehiculo: marcar como enviado para no
            # quedar en loop infinito
            logger.warning(
                "Worker recordatorios: rec=%s tipo KM pero objeto no es vehiculo",
                rec.id,
            )
            return True

        veh = (
            await db.execute(
                select(Vehiculo).where(Vehiculo.objeto_servicio_id == obj.id)
            )
        ).scalar_one_or_none()
        if veh is None:
            return True

        umbral = rec.condicion.get("km_umbral", 0)
        return veh.kilometraje_actual >= int(umbral)

    if rec.tipo == TipoRecordatorio.FECHA:
        fecha_str = rec.condicion.get("fecha")
        if not fecha_str:
            return False
        try:
            fecha_target = date.fromisoformat(fecha_str)
        except ValueError:
            logger.warning(
                "Worker recordatorios: rec=%s fecha invalida: %s",
                rec.id, fecha_str,
            )
            return False
        return date.today() >= fecha_target

    if rec.tipo == TipoRecordatorio.EVENTO:
        return True

    return False


# ------------------------------------------------------------------ scheduler

def start_worker() -> None:
    """Arranca el scheduler. Idempotente: si ya corre, no hace nada."""
    global _scheduler

    if not settings.RECORDATORIOS_WORKER_ENABLED:
        logger.info("Worker recordatorios: deshabilitado por config")
        return

    if _scheduler is not None:
        logger.info("Worker recordatorios: ya estaba corriendo")
        return

    _scheduler = AsyncIOScheduler()
    _scheduler.add_job(
        procesar_recordatorios,
        trigger="interval",
        seconds=settings.RECORDATORIOS_WORKER_INTERVAL_SEC,
        id="procesar_recordatorios",
        max_instances=1,
        coalesce=True,
    )
    _scheduler.start()
    logger.info(
        "Worker recordatorios: iniciado (intervalo=%ss)",
        settings.RECORDATORIOS_WORKER_INTERVAL_SEC,
    )


def stop_worker() -> None:
    """Detiene el scheduler. Idempotente."""
    global _scheduler

    if _scheduler is None:
        return

    try:
        _scheduler.shutdown(wait=False)
    except Exception:
        logger.exception("Worker recordatorios: error al detener")
    finally:
        _scheduler = None
        logger.info("Worker recordatorios: detenido")


async def ejecutar_ciclo_manual(db: AsyncSession | None = None) -> dict:
    """Ejecuta un ciclo ahora (para tests + endpoint admin)."""
    return await procesar_recordatorios(db)
