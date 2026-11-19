"""Cliente Instagram Graph API (via Facebook).

Instagram Business se publica a traves de la pagina de Facebook que lo
administra. Reutilizamos el page token que ya tenemos.

Flujo de publicacion (2 pasos):
    1. POST /{ig-user-id}/media       -> crea "container" (descarga imagen)
    2. POST /{ig-user-id}/media_publish -> publica el container

Requisitos:
- Imagen publica accesible por Meta (URL https)
- Instagram Business o Creator
- Instagram vinculado a la pagina de Facebook
- El page token debe tener permiso instagram_content_publish

Estado del container: al crearlo, Meta lo procesa asincronicamente. Si
se publica muy rapido, puede fallar con "Media ID is not available".
Reintentamos con backoff corto (2-8s) antes de publicar.

Referencias:
- https://developers.facebook.com/docs/instagram-api/guides/content-publishing
"""
import asyncio
import logging

import httpx

from app.core.config import settings
from app.modules.social.facebook_service import (
    FacebookError,
    _graph_url,
    _parse_error,
)

logger = logging.getLogger(__name__)


async def publicar_post_en_instagram(
    ig_user_id: str,
    page_token: str,
    image_url: str,
    caption: str,
    *,
    max_reintentos: int = 3,
) -> tuple[str | None, FacebookError | None]:
    """Publica una imagen en Instagram Business.

    Args:
        ig_user_id: ID de la cuenta IG Business (via la pagina FB).
        page_token: page access token (mismo que usamos para FB).
        image_url: URL publica de la imagen (https, JPG).
        caption: texto del post (opcional, puede ser "").
        max_reintentos: intentos de publish si el container no esta listo.

    Devuelve `(ig_media_id, error)`. `ig_media_id` es el ID del post en IG.
    """
    if not ig_user_id or not page_token:
        return None, FacebookError(message="Faltan ig_user_id o page_token")
    if not image_url:
        return None, FacebookError(message="Instagram requiere image_url")

    # Paso 1: crear container
    creation_id, err = await _crear_container(
        ig_user_id, page_token, image_url, caption
    )
    if err or not creation_id:
        return None, err

    logger.info("IG: container creado id=%s, esperando procesamiento", creation_id)

    # Paso 2: publicar con reintentos cortos
    return await _publicar_container(
        ig_user_id, page_token, creation_id, max_reintentos
    )


async def _crear_container(
    ig_user_id: str, page_token: str, image_url: str, caption: str,
) -> tuple[str | None, FacebookError | None]:
    """POST /{ig-user-id}/media -> devuelve el creation_id."""
    payload = {
        "image_url": image_url,
        "access_token": page_token,
    }
    if caption:
        payload["caption"] = caption

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            resp = await client.post(
                _graph_url(f"{ig_user_id}/media"), data=payload
            )
        except httpx.HTTPError as e:
            return None, FacebookError(message=f"Error de red: {e}")

    if resp.status_code != 200:
        return None, _parse_error(resp)

    creation_id = resp.json().get("id")
    if not creation_id:
        return None, FacebookError(message="Respuesta sin creation_id")
    return creation_id, None


async def _publicar_container(
    ig_user_id: str, page_token: str, creation_id: str, max_reintentos: int,
) -> tuple[str | None, FacebookError | None]:
    """Espera a que el container este listo y ejecuta POST /{ig-user-id}/media_publish."""
    esperas = [2, 3, 5][:max(1, max_reintentos)]
    ultimo_err: FacebookError | None = None

    async with httpx.AsyncClient(timeout=30.0) as client:
        for i, espera in enumerate(esperas):
            await asyncio.sleep(espera)

            # Consultar estado del container antes de publicar
            try:
                st_resp = await client.get(
                    _graph_url(creation_id),
                    params={"fields": "status_code", "access_token": page_token},
                )
                if st_resp.status_code == 200:
                    status_code = (st_resp.json().get("status_code") or "").upper()
                    if status_code == "ERROR":
                        return None, FacebookError(
                            message=f"Container {creation_id} fallo en Meta (status_code=ERROR)"
                        )
                    if status_code and status_code != "FINISHED":
                        ultimo_err = FacebookError(
                            message=f"Container {creation_id} en estado {status_code}"
                        )
                        logger.info(
                            "IG: container %s en estado %s (intento %d/%d)",
                            creation_id, status_code, i + 1, len(esperas),
                        )
                        continue
            except httpx.HTTPError:
                pass

            try:
                resp = await client.post(
                    _graph_url(f"{ig_user_id}/media_publish"),
                    data={
                        "creation_id": creation_id,
                        "access_token": page_token,
                    },
                )
            except httpx.HTTPError as e:
                return None, FacebookError(message=f"Error de red: {e}")

            if resp.status_code in (200, 201):
                media_id = resp.json().get("id")
                if media_id:
                    return media_id, None
                return None, FacebookError(message="Respuesta sin media_id")

            err = _parse_error(resp)
            ultimo_err = err
            msg_low = (err.message or "").lower()
            if "not available" in msg_low or "not ready" in msg_low or "in progress" in msg_low:
                logger.info(
                    "IG: container %s no listo (intento %d/%d), reintentando",
                    creation_id, i + 1, len(esperas),
                )
                continue

            return None, err

    return None, ultimo_err or FacebookError(
        message=f"Container {creation_id} no estuvo listo tras {len(esperas)} intentos"
    )
