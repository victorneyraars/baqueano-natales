"""Integracion del modulo social con el modulo media.

Cuando se aprueba un media_asset:
1. Encola publicacion en la cuenta CENTRAL de Baqueano (prioridad 0).
2. Encola publicacion en la cuenta del PRESTADOR dueno (prioridad 10, si existe).

Best-effort: NUNCA rompe el flujo del caller.
"""
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.social import services as social_services
from app.modules.social.models import (
    CuentaSocial,
    PropietarioTipo,
    Red,
)
from app.modules.social.schemas import PublicacionSocialCreate

logger = logging.getLogger(__name__)


async def _obtener_cuenta_central(
    db: AsyncSession, red: Red,
) -> CuentaSocial | None:
    """Obtiene la cuenta central de Baqueano para una red especifica."""
    stmt = (
        select(CuentaSocial)
        .where(
            CuentaSocial.red == red,
            CuentaSocial.propietario_tipo == PropietarioTipo.BAQUEANO,
            CuentaSocial.propietario_id.is_(None),
            CuentaSocial.activo.is_(True),
        )
        .limit(1)
    )
    return (await db.execute(stmt)).scalar_one_or_none()


async def _obtener_cuenta_prestador(
    db: AsyncSession, prestador_id, red: Red,
) -> CuentaSocial | None:
    """Obtiene la cuenta del prestador para una red especifica."""
    if not prestador_id:
        return None
    stmt = (
        select(CuentaSocial)
        .where(
            CuentaSocial.red == red,
            CuentaSocial.propietario_tipo == PropietarioTipo.PRESTADOR,
            CuentaSocial.propietario_id == prestador_id,
            CuentaSocial.activo.is_(True),
        )
        .limit(1)
    )
    return (await db.execute(stmt)).scalar_one_or_none()


def _construir_mensaje(media_asset) -> str:
    descripcion = media_asset.descripcion or ""
    fase_label = media_asset.fase.replace("_", " ").capitalize()
    return (
        f"Trabajo en Baqueano Natales\n"
        f"Fase: {fase_label}\n"
        f"{descripcion}\n\n"
        f"#SeAlquilaMarido #PuertoNatales #Mecanica"
    )


async def _encolar_para_red(
    db: AsyncSession,
    *,
    red: Red,
    media_asset,
    mensaje: str,
    prioridad: int,
) -> None:
    """Encola una publicacion para una red, en la cuenta correcta."""
    cuenta = await _obtener_cuenta_central(db, red)
    if cuenta is not None:
        try:
            contenido = {"message": mensaje}
            if media_asset.tipo == "foto" and media_asset.url_publica:
                contenido["image_urls"] = [media_asset.url_publica]
            elif media_asset.tipo == "video" and media_asset.url_publica:
                contenido["video_url"] = media_asset.url_publica

            pub = PublicacionSocialCreate(
                cuenta_id=cuenta.id,
                recurso_tipo="media_asset",
                recurso_id=media_asset.id,
                red=red,
                contenido=contenido,
            )
            await social_services.encolar_publicacion(
                db, pub, prioridad=prioridad,
            )
            logger.info(
                "Social: encolada %s en Baqueano (prioridad=%s)",
                red, prioridad,
            )
        except Exception as e:
            logger.warning("Social: fallo encolando Baqueano/%s: %s", red, e)

    # Cuenta del prestador (prioridad mas alta = se publica despues)
    cuenta_prest = await _obtener_cuenta_prestador(
        db, media_asset.prestador_id, red,
    )
    if cuenta_prest is not None:
        try:
            contenido = {"message": mensaje}
            if media_asset.tipo == "foto" and media_asset.url_publica:
                contenido["image_urls"] = [media_asset.url_publica]
            elif media_asset.tipo == "video" and media_asset.url_publica:
                contenido["video_url"] = media_asset.url_publica

            pub = PublicacionSocialCreate(
                cuenta_id=cuenta_prest.id,
                recurso_tipo="media_asset",
                recurso_id=media_asset.id,
                red=red,
                contenido=contenido,
            )
            await social_services.encolar_publicacion(
                db, pub, prioridad=prioridad + 10,
            )
            logger.info(
                "Social: encolada %s en Prestador (prioridad=%s)",
                red, prioridad + 10,
            )
        except Exception as e:
            logger.warning(
                "Social: fallo encolando Prestador/%s: %s", red, e
            )


async def encolar_media_aprobada(db: AsyncSession, media_asset) -> None:
    """Encola publicaciones para un media_asset aprobado."""
    try:
        config = await social_services.obtener_config(db)
        if config is None or not config.auto_publish:
            logger.info("Social: auto_publish desactivado")
            return

        mensaje = _construir_mensaje(media_asset)

        if media_asset.tipo == "video":
            await _encolar_para_red(
                db,
                red=Red.YOUTUBE,
                media_asset=media_asset,
                mensaje=mensaje,
                prioridad=0,
            )
        elif media_asset.tipo == "foto":
            for red in [Red.FACEBOOK, Red.INSTAGRAM, Red.GOOGLE_BUSINESS]:
                await _encolar_para_red(
                    db,
                    red=red,
                    media_asset=media_asset,
                    mensaje=mensaje,
                    prioridad=0,
                )

    except Exception as e:
        logger.warning("Social: error encolando media aprobada: %s", e)
