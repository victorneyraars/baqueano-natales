"""Integracion del modulo social con el vertical prestadores.

Cuando pasa algo relevante en prestadores (nuevo aprobado, servicio
agregado), este modulo arma el copy y encola publicaciones para que el
worker las publique en las redes configuradas.

Reglas:
- Respeta ConfigSocial (override por prestador -> global):
  auto_publish, destino (central/propio/ambos) y flags por red.
- Best-effort: NUNCA rompe el flujo del caller. Cualquier error se
  loggea y se sigue.
- Instagram requiere imagen. Si no hay foto, no se encola para IG.
"""
import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.modules.social import services as social_services
from app.modules.social.models import (
    CuentaSocial,
    DestinoPublicacion,
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


async def _resolver_config_prestador(
    db: AsyncSession,
    prestador_id: UUID | None,
):
    """Obtiene la config del prestador si existe, o la config global."""
    if prestador_id is not None:
        cfg_propia = await social_services.obtener_config(
            db,
            propietario_tipo=PropietarioTipo.PRESTADOR,
            propietario_id=prestador_id,
        )
        if cfg_propia is not None:
            return cfg_propia
    return await social_services.obtener_config(db)


async def _obtener_cuentas_destino(
    db: AsyncSession,
    *,
    red: Red,
    destino: DestinoPublicacion,
    prestador_id: UUID | None,
) -> list[CuentaSocial]:
    """Devuelve las cuentas activas a publicar para una red según DestinoPublicacion."""
    cuentas: list[CuentaSocial] = []

    if destino in (DestinoPublicacion.CENTRAL, DestinoPublicacion.AMBOS):
        stmt_central = (
            select(CuentaSocial)
            .where(
                CuentaSocial.red == red,
                CuentaSocial.propietario_tipo == PropietarioTipo.BAQUEANO,
                CuentaSocial.propietario_id.is_(None),
                CuentaSocial.activo.is_(True),
            )
            .limit(1)
        )
        central = (await db.execute(stmt_central)).scalar_one_or_none()
        if central is not None:
            cuentas.append(central)

    if (
        prestador_id is not None
        and destino in (DestinoPublicacion.PROPIO, DestinoPublicacion.AMBOS)
    ):
        stmt_propia = (
            select(CuentaSocial)
            .where(
                CuentaSocial.red == red,
                CuentaSocial.propietario_tipo == PropietarioTipo.PRESTADOR,
                CuentaSocial.propietario_id == prestador_id,
                CuentaSocial.activo.is_(True),
            )
            .limit(1)
        )
        propia = (await db.execute(stmt_propia)).scalar_one_or_none()
        if propia is not None:
            cuentas.append(propia)

    return cuentas


async def _encolar_para_redes_configuradas(
    db: AsyncSession,
    *,
    prestador_id: UUID | None,
    recurso_tipo: str,
    recurso_id,
    mensaje: str,
    image_url: str | None,
    config,
) -> int:
    encoladas = 0
    delay = 0
    destino = getattr(config, "destino", DestinoPublicacion.AMBOS)

    redes_activas: list[tuple[Red, bool]] = [
        (Red.FACEBOOK, bool(config.publicar_en_facebook)),
        (Red.INSTAGRAM, bool(config.publicar_en_instagram and image_url)),
        (Red.GOOGLE_BUSINESS, bool(config.publicar_en_google)),
    ]

    for red, habilitada in redes_activas:
        if not habilitada:
            continue
        cuentas = await _obtener_cuentas_destino(
            db,
            red=red,
            destino=destino,
            prestador_id=prestador_id,
        )
        if not cuentas:
            logger.info(
                "Social: sin cuentas activas para red=%s destino=%s prestador=%s",
                red.value,
                destino.value if hasattr(destino, "value") else destino,
                prestador_id,
            )
            continue

        for cuenta in cuentas:
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
                        red=red,
                        contenido=contenido,
                    ),
                    delay_segundos=delay,
                )
                delay += 60
                encoladas += 1
                logger.info(
                    "Social: encolada publicacion %s en cuenta=%s (%s) para %s/%s",
                    red.value,
                    cuenta.id,
                    cuenta.propietario_tipo.value,
                    recurso_tipo,
                    recurso_id,
                )
            except Exception as e:
                logger.warning(
                    "Social: fallo encolando %s en cuenta=%s: %s",
                    red.value,
                    cuenta.id,
                    e,
                )

    return encoladas


async def encolar_prestador_nuevo(db: AsyncSession, prestador) -> None:
    try:
        config = await _resolver_config_prestador(db, getattr(prestador, "id", None))
        if config is None or not config.auto_publish:
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

        await _encolar_para_redes_configuradas(
            db,
            prestador_id=prestador.id,
            recurso_tipo="prestador",
            recurso_id=prestador.id,
            mensaje=mensaje,
            image_url=image_url,
            config=config,
        )
    except Exception as e:
        logger.warning("Social: error encolando prestador nuevo: %s", e)


async def encolar_servicio_nuevo(
    db: AsyncSession,
    prestador,
    servicio,
    *,
    forzar: bool = False,
) -> int:
    try:
        config = await _resolver_config_prestador(db, getattr(prestador, "id", None))
        if config is None:
            return 0
        if not forzar and not config.auto_publish:
            return 0

        web = settings.PUBLIC_WEB_URL.rstrip("/")
        es_sealquilamarido = getattr(prestador, "slug", None) == "se-alquila-marido"

        desde = servicio.precio_desde_clp
        hasta = servicio.precio_hasta_clp
        texto_precio = None
        if desde is not None and hasta is not None and desde != hasta:
            texto_precio = f"{_precio_clp(desde)} - {_precio_clp(hasta)}"
        elif desde is not None:
            texto_precio = f"Desde {_precio_clp(desde)}"

        duracion = getattr(servicio, "duracion_estimada_min", None)
        garantia = getattr(servicio, "garantia_dias", None)
        detalles: list[str] = []
        if duracion is not None:
            try:
                m = int(duracion)
                if m > 0:
                    detalles.append(f"Duración estimada: {m} min")
            except (TypeError, ValueError):
                pass
        if garantia is not None:
            try:
                d = int(garantia)
                if d > 0:
                    detalles.append(f"Garantía: {d} días")
            except (TypeError, ValueError):
                pass

        if es_sealquilamarido:
            titulo = (servicio.nombre or "").strip().rstrip(".")
            primera_linea = (
                f"{titulo} — {texto_precio}" if texto_precio else titulo
            )
            lineas = [
                primera_linea,
                f"Puerto Natales · {prestador.nombre}",
                "",
                "• A domicilio en Puerto Natales (tú aportas aceite y filtro)",
                "• Bandeja de contención, apriete controlado y revisión de nivel",
                "• Retiro de aceite usado opcional (+$5.000)",
            ]
            if detalles:
                lineas.append(" · ".join(detalles))
            lineas.extend([
                "",
                "Solicítalo o revisa detalles aquí:",
                "https://sealquilamarido.com/mecanica",
            ])
        else:
            encabezado = (
                f"{prestador.nombre} — Servicio disponible"
                if forzar
                else f"{prestador.nombre} agregó:"
            )
            lineas = [encabezado, "", servicio.nombre]
            if servicio.categoria_servicio:
                lineas.append(f"({servicio.categoria_servicio})")
            if texto_precio:
                lineas.append(texto_precio)
            if detalles:
                lineas.append(" · ".join(detalles))
            if servicio.descripcion:
                lineas.append("")
                lineas.append(servicio.descripcion)
            lineas.append("")
            lineas.append(f"Pídelo en: {web}/prestadores/{prestador.slug}")

        mensaje = "\n".join(lineas)

        image_url = _url_absoluta(
            getattr(prestador, "foto_portada_url", None)
            or getattr(prestador, "foto_url", None)
        )

        return await _encolar_para_redes_configuradas(
            db,
            prestador_id=prestador.id,
            recurso_tipo="prestador_servicio",
            recurso_id=servicio.id,
            mensaje=mensaje,
            image_url=image_url,
            config=config,
        )
    except Exception as e:
        logger.warning("Social: error encolando servicio nuevo: %s", e)
        return 0
