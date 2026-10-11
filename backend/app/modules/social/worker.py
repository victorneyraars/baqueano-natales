"""Worker de publicaciones sociales.

Scheduler in-process (APScheduler) que procesa la cola
`publicaciones_sociales`:

    while True:
        - traer hasta N publicaciones (estado=PENDIENTE, listo para procesar)
        - por cada una:
            * verificar cuenta activa
            * obtener token vigente (descifrado)
            * marcar PUBLICANDO
            * llamar a la Graph API
            * marcar PUBLICADO o FALLADO (con backoff)

El worker NUNCA debe crashear el scheduler: cualquier excepcion se
captura, se loggea, y se reintenta en el proximo ciclo.

Decisiones:
- AsyncIOScheduler: mismo event loop que FastAPI, sin threads.
- Sesion DB propia por ciclo: no depende de Depends() de FastAPI.
- Filtro de cuenta activa: si la cuenta se desactivo, se falla rapido
  (no se reintenta 5 veces contra un recurso invalido).
"""
import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db import AsyncSessionLocal
from app.modules.social import facebook_service, instagram_service, services
from app.modules.social.models import EstadoPublicacion, Red

logger = logging.getLogger(__name__)


# ------------------------------------------------------------------ singleton

_scheduler: AsyncIOScheduler | None = None


# ------------------------------------------------------------------ ciclo

async def procesar_cola(db: AsyncSession | None = None) -> dict:
    """Un ciclo del worker.

    Args:
        db: Si es None, abre una sesion propia (uso en produccion desde
            el scheduler). Si se pasa, la usa (tests + endpoint).

    Dise?ado para NUNCA lanzar: cualquier error se loggea y se reporta
    en el dict de stats.
    """
    if db is None:
        async with AsyncSessionLocal() as session:
            return await _procesar_cola_con_db(session)
    return await _procesar_cola_con_db(db)


async def _procesar_cola_con_db(db: AsyncSession) -> dict:
    """Implementacion del ciclo. Recibe una sesion ya abierta."""
    stats = {"procesadas": 0, "publicadas": 0, "falladas": 0, "saltadas": 0}

    try:
        pendientes = await services.obtener_publicaciones_pendientes(
            db, limit=10
        )
        if not pendientes:
            return stats

        logger.info("Worker: %d publicaciones pendientes", len(pendientes))

        for pub in pendientes:
            stats["procesadas"] += 1
            try:
                resultado = await _procesar_una(db, pub)
                stats[resultado] = stats.get(resultado, 0) + 1
            except Exception as e:
                logger.exception(
                    "Worker: error inesperado procesando pub=%s", pub.id
                )
                stats["falladas"] += 1

    except Exception as e:
        logger.exception("Worker: error en ciclo: %s", e)

    if stats["procesadas"] > 0:
        logger.info("Worker: ciclo %s", stats)
    return stats


async def _procesar_una(db, pub) -> str:
    """Procesa una publicacion. Devuelve:
    - "publicadas" si salio bien
    - "falladas" si hubo error (aplica backoff)
    - "saltadas" si no se puede procesar (cuenta inactiva, etc.)

    NO captura excepciones: lo hace `procesar_cola`.
    """
    # 1. Dispatch por red
    if pub.red not in (Red.FACEBOOK, Red.INSTAGRAM):
        await services.marcar_publicacion_fallada(
            db, pub, f"Red no soportada en este worker: {pub.red.value}"
        )
        return "falladas"

    # 2. Cuenta activa
    if not pub.cuenta or not pub.cuenta.activo:
        await services.marcar_publicacion_fallada(
            db, pub, "La cuenta social esta inactiva o no existe"
        )
        return "falladas"

    # 3. Token vigente
    token, err = await services.obtener_token_vigente_de_cuenta(
        db, pub.cuenta_id
    )
    if err or not token:
        await services.marcar_publicacion_fallada(db, pub, err or "sin token")
        return "falladas"

    # 4. Marcar PUBLICANDO (evita doble procesamiento)
    await services.marcar_publicacion_publicando(db, pub)

    # 5. Extraer contenido
    contenido = pub.contenido or {}
    mensaje = contenido.get("message") or contenido.get("mensaje") or ""
    image_urls = contenido.get("image_urls") or []
    image_url = (
        image_urls[0]
        if image_urls
        else contenido.get("image_url")
    )
    link = contenido.get("link")

    if not mensaje and not image_url:
        await services.marcar_publicacion_fallada(
            db, pub, "Publicacion sin mensaje ni image_url"
        )
        return "falladas"

    # 6. Publicar segun red
    if pub.red == Red.INSTAGRAM:
        external_id, fb_error = await _publicar_en_instagram(
            db, pub, token, mensaje, image_url
        )
    else:
        external_id, fb_error = await facebook_service.publicar_post_en_pagina(
            page_id=pub.cuenta.external_id,
            page_token=token,
            mensaje=mensaje,
            image_url=image_url,
            link=link,
        )

    if fb_error or not external_id:
        msg = fb_error.message if fb_error else "sin external_post_id"
        await services.marcar_publicacion_fallada(db, pub, msg)
        return "falladas"

    # 7. Exito
    await services.marcar_publicacion_publicada(db, pub, external_id)
    logger.info(
        "Worker: publicada pub=%s (%s) -> %s",
        pub.id, pub.red.value, external_id,
    )
    return "publicadas"


async def _publicar_en_instagram(
    db, pub, page_token: str, mensaje: str, image_url: str | None
):
    """Publica en Instagram Business via la cuenta Facebook.

    Instagram requiere imagen. Si no hay image_url, devuelve error claro.
    """
    if not image_url:
        return None, facebook_service.FacebookError(
            message="Instagram requiere image_url (no acepta solo texto)"
        )

    ig_user_id = await services.obtener_instagram_id_de_cuenta(
        db, pub.cuenta_id
    )
    if not ig_user_id:
        return None, facebook_service.FacebookError(
            message="La cuenta no tiene Instagram Business vinculado"
        )

    return await instagram_service.publicar_post_en_instagram(
        ig_user_id=ig_user_id,
        page_token=page_token,
        image_url=image_url,
        caption=mensaje,
    )


# ------------------------------------------------------------------ scheduler

def start_worker() -> None:
    """Arranca el scheduler. Llamado desde `main.py` lifespan.

    No hace nada si SOCIAL_WORKER_ENABLED=false.
    """
    global _scheduler

    if not settings.SOCIAL_WORKER_ENABLED:
        logger.info("Worker social: deshabilitado por config")
        return

    if _scheduler is not None and _scheduler.running:
        logger.warning("Worker social: ya estaba corriendo")
        return

    interval = settings.SOCIAL_WORKER_INTERVAL_SEC
    _scheduler = AsyncIOScheduler()
    _scheduler.add_job(
        procesar_cola,
        trigger="interval",
        seconds=interval,
        id="social_procesar_cola",
        max_instances=1,  # evita solapamiento si un ciclo tarda
        coalesce=True,    # si el server estuvo caido, no dispara N veces
        misfire_grace_time=30,
    )
    _scheduler.start()
    logger.info("Worker social: iniciado (intervalo=%ss)", interval)


def stop_worker() -> None:
    """Detiene el scheduler. Llamado desde `main.py` lifespan."""
    global _scheduler

    if _scheduler is not None and _scheduler.running:
        _scheduler.shutdown(wait=False)
        logger.info("Worker social: detenido")
    _scheduler = None


async def ejecutar_ciclo_manual(db: AsyncSession | None = None) -> dict:
    """Ejecuta un ciclo sin pasar por el scheduler.

    Util para:
    - Endpoint admin `POST /publicaciones/procesar-ahora`
    - Tests (pasan `db`)
    """
    return await procesar_cola(db=db)
