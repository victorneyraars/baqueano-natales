"""Integracion del modulo social con el modulo media.
Cuando se aprueba un media_asset (foto o video), este modulo encola
automaticamente las publicaciones en las redes configuradas.
Reglas:
- Best-effort: NUNCA rompe el flujo del caller.
- Fotos -> Facebook + Instagram + Google Business.
- Videos -> YouTube Shorts + Facebook (si tiene thumb).
- Solo publica en la cuenta CENTRAL de Baqueano.
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


async def _obtener_cuenta_central(db: AsyncSession) -> CuentaSocial | None:
    stmt = (
        select(CuentaSocial)
        .where(
            CuentaSocial.propietario_tipo == PropietarioTipo.BAQUEANO,
            CuentaSocial.propietario_id.is_(None),
            CuentaSocial.activo.is_(True),
        )
        .limit(1)
    )
    return (await db.execute(stmt)).scalar_one_or_none()


async def encolar_media_aprobada(db: AsyncSession, media_asset) -> None:
    """Encola publicaciones en redes para un media_asset aprobado.

    Args:
        db: Sesion de DB.
        media_asset: Objeto con atributos id, tipo, fase, url_publica,
            descripcion, entidad_id, entidad_tipo.
    """
    try:
        cuenta = await _obtener_cuenta_central(db)
        if cuenta is None:
            logger.info("Social: no hay cuenta central activa")
            return

        # Construir el mensaje base
        descripcion = media_asset.descripcion or ""
        fase_label = media_asset.fase.replace("_", " ").capitalize()
        mensaje_base = (
            f"🔧 Trabajo en Baqueano Natales\n"
            f"Fase: {fase_label}\n"
            f"{descripcion}\n\n"
            f"#SeAlquilaMarido #PuertoNatales #Mecanica"
        )

        if media_asset.tipo == "video" and media_asset.url_publica:
            # Encolar en YouTube Shorts
            try:
                await social_services.encolar_publicacion(
                    db,
                    PublicacionSocialCreate(
                        cuenta_id=cuenta.id,
                        recurso_tipo="media_asset",
                        recurso_id=media_asset.id,
                        red=Red.YOUTUBE,
                        contenido={
                            "message": mensaje_base,
                            "video_url": media_asset.url_publica,
                            "titulo": f"Trabajo en Baqueano: {fase_label}",
                        },
                    ),
                )
                logger.info(
                    "Social: encolada publicacion YT para %s", media_asset.id
                )
            except Exception as e:
                logger.warning("Social: fallo encolando YT: %s", e)

        elif media_asset.tipo == "foto" and media_asset.url_publica:
            # Encolar en Facebook, Instagram y Google Business
            for red in [Red.FACEBOOK, Red.INSTAGRAM, Red.GOOGLE_BUSINESS]:
                try:
                    contenido = {"message": mensaje_base}
                    if red != Red.GOOGLE_BUSINESS:
                        contenido["image_urls"] = [media_asset.url_publica]
                    await social_services.encolar_publicacion(
                        db,
                        PublicacionSocialCreate(
                            cuenta_id=cuenta.id,
                            recurso_tipo="media_asset",
                            recurso_id=media_asset.id,
                            red=red,
                            contenido=contenido,
                        ),
                    )
                    logger.info(
                        "Social: encolada publicacion %s para %s",
                        red, media_asset.id,
                    )
                except Exception as e:
                    logger.warning(
                        "Social: fallo encolando %s: %s", red, e
                    )

    except Exception as e:
        logger.warning("Social: error encolando media aprobada: %s", e)
