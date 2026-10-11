"""Integracion del modulo social con el vertical prestadores.

Cuando pasa algo relevante en prestadores (nuevo aprobado, servicio
agregado), este modulo arma el copy y encola publicaciones para que el
worker las publique en las redes configuradas.

Reglas:
- Respeta ConfigSocial: auto_publish + publicar_en_facebook/instagram.
- Best-effort: NUNCA rompe el flujo del caller. Cualquier error se
  loggea y se sigue.
- Instagram requiere imagen. Si no hay foto, no se encola para IG.
- Solo publica en la cuenta CENTRAL de Baqueano.
"""
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.modules.social import services as social_services
from app.modules.social.models import (
    CuentaSocial,
    PropietarioTipo,
    Red,
)
from app.modules.social.schemas import PublicacionSocialCreate

logger = logging.getLogger(__name__)


def _precio_clp(valor) -> str:
    try:
        s = f"{int(valor):,}".replace(",", ".")
    except (TypeError, ValueError):
        s = "0"
    return f"${s}"


def _url_absoluta(url: str | None) -> str | None:
    if not url:
        return None
    if url.startswith("http://") or url.startswith("https://"):
        return url
    base = settings.PUBLIC_API_URL.rstrip("/")
    return f"{base}/{url.lstrip('/')}"


async def _obtener_cuenta_central_facebook(
    db: AsyncSession,
) -> CuentaSocial | None:
    stmt = (
        select(CuentaSocial)
        .where(
            CuentaSocial.red == Red.FACEBOOK,
            CuentaSocial.propietario_tipo == PropietarioTipo.BAQUEANO,
            CuentaSocial.propietario_id.is_(None),
            CuentaSocial.activo.is_(True),
        )
        .limit(1)
    )
    return (await db.execute(stmt)).scalar_one_or_none()


async def _encolar_para_ambas_redes(
    db: AsyncSession,
    *,
    cuenta: CuentaSocial,
    recurso_tipo: str,
    recurso_id,
    mensaje: str,
    image_url: str | None,
    config,
) -> None:
    if config.publicar_en_facebook:
        try:
            contenido: dict = {"message": mensaje}
            if image_url:
                contenido["image_urls"] = [image_url]
            await social_services.encolar_publicacion(
                db,
                PublicacionSocialCreate(
                    cuenta_id=cuenta.id,
                    recurso_tipo=recurso_tipo,
                    recurso_id=recurso_id,
                    red=Red.FACEBOOK,
                    contenido=contenido,
                ),
            )
            logger.info(
                "Social: encolada publicacion FB para %s/%s",
                recurso_tipo, recurso_id,
            )
        except Exception as e:
            logger.warning("Social: fallo encolando FB: %s", e)

    if config.publicar_en_instagram and image_url:
        try:
            await social_services.encolar_publicacion(
                db,
                PublicacionSocialCreate(
                    cuenta_id=cuenta.id,
                    recurso_tipo=recurso_tipo,
                    recurso_id=recurso_id,
                    red=Red.INSTAGRAM,
                    contenido={
                        "message": mensaje,
                        "image_urls": [image_url],
                    },
                ),
            )
            logger.info(
                "Social: encolada publicacion IG para %s/%s",
                recurso_tipo, recurso_id,
            )
        except Exception as e:
            logger.warning("Social: fallo encolando IG: %s", e)


async def encolar_prestador_nuevo(db: AsyncSession, prestador) -> None:
    try:
        config = await social_services.obtener_config(db)
        if config is None or not config.auto_publish:
            return
        cuenta = await _obtener_cuenta_central_facebook(db)
        if cuenta is None:
            logger.info("Social: no hay cuenta central FB activa")
            return

        cat = prestador.categoria.nombre if prestador.categoria else ""
        web = settings.PUBLIC_WEB_URL.rstrip("/")
        lineas = [
            "Nuevo en Baqueano Natales!",
            "",
            prestador.nombre + (f" ({cat})" if cat else ""),
        ]
        if prestador.direccion:
            lineas.append(f"Direccion: {prestador.direccion}")
        if prestador.anios_experiencia:
            lineas.append(f"{prestador.anios_experiencia} anios de experiencia")
        lineas.append("")
        lineas.append(f"Contactalo en: {web}/prestadores/{prestador.slug}")
        mensaje = "\n".join(lineas)

        image_url = _url_absoluta(
            prestador.foto_portada_url or prestador.foto_url
        )

        await _encolar_para_ambas_redes(
            db,
            cuenta=cuenta,
            recurso_tipo="prestador",
            recurso_id=prestador.id,
            mensaje=mensaje,
            image_url=image_url,
            config=config,
        )
    except Exception as e:
        logger.warning("Social: error encolando prestador nuevo: %s", e)


async def encolar_servicio_nuevo(
    db: AsyncSession, prestador, servicio,
) -> None:
    try:
        config = await social_services.obtener_config(db)
        if config is None or not config.auto_publish:
            return
        cuenta = await _obtener_cuenta_central_facebook(db)
        if cuenta is None:
            return

        web = settings.PUBLIC_WEB_URL.rstrip("/")
        lineas = [f"{prestador.nombre} agrego:", "", servicio.nombre]
        if servicio.categoria_servicio:
            lineas.append(f"({servicio.categoria_servicio})")

        desde = servicio.precio_desde_clp
        hasta = servicio.precio_hasta_clp
        if desde is not None and hasta is not None and desde != hasta:
            lineas.append(f"{_precio_clp(desde)} - {_precio_clp(hasta)}")
        elif desde is not None:
            lineas.append(f"Desde {_precio_clp(desde)}")

        if servicio.descripcion:
            lineas.append("")
            lineas.append(servicio.descripcion)

        lineas.append("")
        lineas.append(f"Pedilo en: {web}/prestadores/{prestador.slug}")
        mensaje = "\n".join(lineas)

        image_url = _url_absoluta(prestador.foto_portada_url)

        await _encolar_para_ambas_redes(
            db,
            cuenta=cuenta,
            recurso_tipo="prestador_servicio",
            recurso_id=servicio.id,
            mensaje=mensaje,
            image_url=image_url,
            config=config,
        )
    except Exception as e:
        logger.warning("Social: error encolando servicio nuevo: %s", e)
