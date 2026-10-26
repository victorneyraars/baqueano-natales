"""Servicio de publicacion en YouTube (Shorts).

Sube un video corto (max 60s, vertical 9:16) usando la YouTube Data API v3.
Requiere un OAuth token con scope `youtube.upload`.

Documentacion:
- https://developers.google.com/youtube/v3/docs/videos/insert
- Los Shorts son videos verticales <= 60s con #Shorts en titulo o descripcion.
"""

import logging
from typing import Any

import httpx

logger = logging.getLogger(__name__)

YOUTUBE_UPLOAD_URL = "https://www.googleapis.com/upload/youtube/v3/videos"


async def publicar_short(
    *,
    access_token: str,
    video_url: str,
    titulo: str,
    descripcion: str,
    tags: list[str] | None = None,
) -> dict[str, Any]:
    """Sube un video a YouTube Shorts.

    Args:
        access_token: Token OAuth valido con scope youtube.upload.
        video_url: URL publica del video (R2 o similar).
        titulo: Titulo del video (max 100 chars). Se agrega #Shorts.
        descripcion: Descripcion (max 5000 chars).
        tags: Tags opcionales.

    Returns:
        dict con `id` (videoId), `url_publica`, `status`.

    Raises:
        httpx.HTTPError si la API falla.
    """
    # Asegurar que #Shorts este en el titulo o descripcion
    if "#Shorts" not in titulo and "#Shorts" not in descripcion:
        titulo = f"{titulo[:85]} #Shorts"

    metadata = {
        "snippet": {
            "title": titulo[:100],
            "description": descripcion[:5000],
            "tags": tags or [],
            "categoryId": "22",  # People & Blogs
        },
        "status": {
            "privacyStatus": "public",
            "selfDeclaredMadeForKids": False,
        },
    }

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    # Descargar el video desde R2 y subirlo a YouTube (multipart)
    async with httpx.AsyncClient(timeout=120.0) as client:
        # 1. Descargar el video
        logger.info("YouTube: descargando video desde %s", video_url)
        video_resp = await client.get(video_url)
        video_resp.raise_for_status()
        video_bytes = video_resp.content
        logger.info("YouTube: video descargado (%d bytes)", len(video_bytes))

        # 2. Subir a YouTube con multipart
        files = {
            "metadata": (None, str(metadata), "application/json"),
            "video": ("video.mp4", video_bytes, "video/mp4"),
        }
        params = {"part": "snippet,status", "uploadType": "multipart"}

        upload_resp = await client.post(
            YOUTUBE_UPLOAD_URL,
            params=params,
            headers={"Authorization": f"Bearer {access_token}"},
            files=files,
        )

        if upload_resp.status_code >= 400:
            logger.error(
                "YouTube: error %s - %s",
                upload_resp.status_code,
                upload_resp.text[:500],
            )
            upload_resp.raise_for_status()

        data = upload_resp.json()
        video_id = data.get("id", "")
        logger.info("YouTube: video subido, id=%s", video_id)

        return {
            "id": video_id,
            "url_publica": f"https://youtube.com/shorts/{video_id}",
            "status": "publicado",
        }
