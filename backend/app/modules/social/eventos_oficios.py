"""Integracion del modulo social con el cierre de turnos/ordenes de oficios.

Cuando se completa un turno/orden con `auto_publicar_redes=True`, encola un
resumen publico (sin exponer patente ni datos del cliente) en las cuentas
activas configuradas, usando la cola existente (`publicaciones_sociales`) y
espaciado anti-spam.

Best-effort: NUNCA rompe el flujo de completar turno/orden.
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
        return ""
    return f"${s}"


def _url_absoluta(url: str | None) -> str | None:
    if not url:
        return None
    if url.startswith("http://") or url.startswith("https://"):
        return url
    base = (getattr(settings, "PUBLIC_API_URL", None) or "").rstrip("/")
    if not base:
        return None
    return f"{base}/{url.lstrip('/')}"


async def _obtener_cuenta_activa(
    db: AsyncSession,
    red: Red,
    propietario_tipo: PropietarioTipo,
    propietario_id=None,
) -> CuentaSocial | None:
    condiciones = [
        CuentaSocial.red == red,
        CuentaSocial.propietario_tipo == propietario_tipo,
        CuentaSocial.activo.is_(True),
    ]
    if propietario_id is None:
        condiciones.append(CuentaSocial.propietario_id.is_(None))
    else:
        condiciones.append(CuentaSocial.propietario_id == propietario_id)

    stmt = select(CuentaSocial).where(*condiciones).limit(1)
    return (await db.execute(stmt)).scalar_one_or_none()


def _construir_mensaje_orden(orden, prestador=None) -> str:
    nombre_taller = getattr(prestador, "nombre", None) or "Baqueano Natales"
    modalidad = (getattr(orden, "modalidad", None) or "domicilio").replace("_", " ").capitalize()
    lineas = [
        f"Trabajo completado en {nombre_taller}",
        f"Modalidad: {modalidad}",
    ]
    total = getattr(orden, "total_presupuesto", None)
    if total and float(total) > 0:
        lineas.append(f"Referencia: {_precio_clp(total)}")

    servicios = getattr(orden, "items", None) or []
    if servicios:
        nombres = [
            getattr(it, "descripcion", None)
            for it in servicios
            if getattr(it, "descripcion", None)
        ]
        if nombres:
            lineas.append("Servicios: " + ", ".join(nombres[:4]))

    web = (getattr(settings, "PUBLIC_WEB_URL", None) or "").rstrip("/")
    if web:
        lineas.append(f"Agenda en: {web}")

    lineas.append("")
    lineas.append("#BaqueanoNatales #PuertoNatales #Mecanica #Oficios")
    return "\n".join(lineas)


async def encolar_orden_completada(
    db: AsyncSession,
    orden,
    prestador=None,
) -> None:
    """Encola publicacion en cola social al completar una orden (best-effort)."""
    try:
        config = await social_services.obtener_config(db)
        if config is None or not config.auto_publish:
            logger.info(
                "Social: auto_publish desactivado para orden %s",
                getattr(orden, "id", ""),
            )
            return

        mensaje = _construir_mensaje_orden(orden, prestador)
        prestador_id = getattr(orden, "prestador_id", None)
        image_url = _url_absoluta(
            getattr(prestador, "foto_portada_url", None)
            or getattr(prestador, "foto_url", None)
        )

        redes_objetivo: list[tuple[Red, bool]] = [
            (Red.FACEBOOK, bool(getattr(config, "publicar_en_facebook", True))),
            (Red.INSTAGRAM, bool(getattr(config, "publicar_en_instagram", True)) and bool(image_url)),
            (Red.GOOGLE_BUSINESS, bool(getattr(config, "publicar_en_google", False))),
        ]

        delay_acumulado = 0
        for red, habilitada in redes_objetivo:
            if not habilitada:
                continue

            for prop_tipo, prop_id, prio in (
                (PropietarioTipo.BAQUEANO, None, 0),
                (PropietarioTipo.PRESTADOR, prestador_id, 10),
            ):
                if prop_tipo == PropietarioTipo.PRESTADOR and not prop_id:
                    continue
                cuenta = await _obtener_cuenta_activa(db, red, prop_tipo, prop_id)
                if cuenta is None:
                    continue
                try:
                    contenido: dict = {"message": mensaje}
                    if image_url:
                        contenido["image_urls"] = [image_url]
                    pub = PublicacionSocialCreate(
                        cuenta_id=cuenta.id,
                        recurso_tipo="orden_trabajo",
                        recurso_id=orden.id,
                        red=red,
                        contenido=contenido,
                    )
                    await social_services.encolar_publicacion(
                        db,
                        pub,
                        prioridad=prio,
                        delay_segundos=delay_acumulado,
                    )
                    delay_acumulado += 60
                    logger.info(
                        "Social: encolada orden %s en %s (%s, prio=%s)",
                        getattr(orden, "numero", orden.id),
                        red,
                        prop_tipo,
                        prio,
                    )
                except Exception as e:
                    logger.warning(
                        "Social: fallo encolando orden %s en %s/%s: %s",
                        getattr(orden, "numero", orden.id),
                        red,
                        prop_tipo,
                        e,
                    )
    except Exception as e:
        logger.warning("Social: error encolando orden completada: %s", e)
