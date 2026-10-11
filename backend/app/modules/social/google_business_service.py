"""Cliente de Google Business Profile API (v4).

Flujo de publicacion:
    POST https://mybusiness.googleapis.com/v4/{account_name}/locations/{location_id}/localPosts

Estado actual (Etapa 8): todo el codigo esta listo pero gateado por el
feature flag GOOGLE_BUSINESS_ENABLED. Cuando se apruebe la API de Google,
solo hay que cambiar el flag y cargar las credenciales OAuth.
"""
import logging

import httpx

from app.core.config import settings


logger = logging.getLogger(__name__)

_API_BASE = "https://mybusiness.googleapis.com"


class GoogleBusinessError:
    """Error de la API GBP. Similar a FacebookError."""

    def __init__(
        self,
        message: str,
        code: int | None = None,
        status: str | None = None,
        http_status: int | None = None,
    ):
        self.message = message
        self.code = code
        self.status = status
        self.http_status = http_status

    def to_dict(self) -> dict:
        return {
            "message": self.message,
            "code": self.code,
            "status": self.status,
            "http_status": self.http_status,
        }

    def __repr__(self) -> str:
        return f"GoogleBusinessError({self.message!r})"


def _url(path: str) -> str:
    v = settings.GOOGLE_BUSINESS_API_VERSION
    return f"{_API_BASE}/{v}/{path.lstrip('/')}"


def _parse_error(resp: httpx.Response) -> GoogleBusinessError:
    try:
        body = resp.json()
    except Exception:
        return GoogleBusinessError(
            message=(resp.text or f"HTTP {resp.status_code}")[:200],
            http_status=resp.status_code,
        )
    err = body.get("error") or {}
    return GoogleBusinessError(
        message=err.get("message", f"HTTP {resp.status_code}"),
        code=err.get("code"),
        status=err.get("status"),
        http_status=resp.status_code,
    )


async def publicar_post_en_gbp(
    account_name: str,
    location_id: str,
    access_token: str,
    mensaje: str,
    image_url: str | None = None,
) -> tuple[str | None, GoogleBusinessError | None]:
    """Publica un post en una ubicacion de Google Business Profile.

    Returns:
        (post_name, error). post_name es el nombre del post creado.

    Gating:
        Si GOOGLE_BUSINESS_ENABLED=false, devuelve error inmediato sin
        hacer llamada HTTP.
    """
    if not settings.GOOGLE_BUSINESS_ENABLED:
        return None, GoogleBusinessError(
            message="Google Business Profile deshabilitado (GOOGLE_BUSINESS_ENABLED=false)"
        )

    if not account_name or not location_id or not access_token:
        return None, GoogleBusinessError(
            message="Faltan account_name, location_id o access_token"
        )

    if not mensaje:
        return None, GoogleBusinessError(message="El post no tiene mensaje")

    body: dict = {
        "languageCode": "es",
        "summary": mensaje,
        "topicType": "STANDARD",
    }
    if image_url:
        body["media"] = [{"mediaFormat": "PHOTO", "sourceUrl": image_url}]

    url = _url(f"{account_name}/locations/{location_id}/localPosts")

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            resp = await client.post(
                url,
                json=body,
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                },
            )
        except httpx.HTTPError as e:
            return None, GoogleBusinessError(message=f"Error de red: {e}")

    if resp.status_code not in (200, 201):
        return None, _parse_error(resp)

    data = resp.json()
    post_name = data.get("name")
    if not post_name:
        return None, GoogleBusinessError(
            message=f"Respuesta sin name: {data!r}"[:200]
        )

    logger.info("GBP: post publicado %s", post_name)
    return post_name, None
