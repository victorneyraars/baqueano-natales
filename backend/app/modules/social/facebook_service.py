"""Cliente Facebook Graph API para el m?dulo social.

Dise?o:
- Sin SDK ? solo `httpx.AsyncClient` (f?cil de mockear en tests).
- Todos los m?todos son async y devuelven tuplas `(resultado, error)`.
  Nunca lanzan excepci?n al llamador por errores de Meta.
- Los errores se encapsulan en `FacebookError` con campos ?tiles para
  debugging (code, subcode, trace_id de Meta).

Flujo OAuth completo:
    1. `construir_url_autorizacion(state)` ? URL que el admin abre
    2. `intercambiar_codigo_por_token(code)` ? short-lived user token
    3. `extender_token(short_lived)` ? long-lived user token (60 d?as)
    4. `listar_paginas(user_token)` ? p?ginas del usuario con page tokens
    5. `verificar_token_pagina(page_id, page_token)` ? nombre o error
"""
from dataclasses import dataclass, field
from typing import Optional
from urllib.parse import urlencode

import httpx

from app.core.config import settings


# ------------------------------------------------------------------ modelos

@dataclass
class FacebookError:
    """Error de Graph API. Los campos vienen poblados si Meta los devolvi?."""
    message: str
    code: Optional[int] = None
    type: Optional[str] = None
    subcode: Optional[int] = None
    trace_id: Optional[str] = None
    http_status: Optional[int] = None

    def to_dict(self) -> dict:
        return {
            "message": self.message,
            "code": self.code,
            "type": self.type,
            "subcode": self.subcode,
            "trace_id": self.trace_id,
            "http_status": self.http_status,
        }


@dataclass
class PaginaFacebook:
    """P?gina devuelta por `/me/accounts`."""
    id: str
    name: str
    category: Optional[str] = None
    access_token: str = ""  # Page Access Token ? nunca exponer al frontend
    tasks: list[str] = field(default_factory=list)

    def to_public_dict(self) -> dict:
        """Versi?n sin el access_token, segura para respuestas HTTP."""
        return {
            "id": self.id,
            "name": self.name,
            "category": self.category,
            "tasks": self.tasks,
        }


# ------------------------------------------------------------------ internos

_GRAPH_BASE = "https://graph.facebook.com"


def _graph_url(path: str) -> str:
    v = settings.FACEBOOK_GRAPH_API_VERSION
    return f"{_GRAPH_BASE}/{v}/{path.lstrip('/')}"


def _parse_error(resp: httpx.Response) -> FacebookError:
    try:
        body = resp.json()
    except Exception:
        return FacebookError(
            message=(resp.text or f"HTTP {resp.status_code}")[:200],
            http_status=resp.status_code,
        )
    err = body.get("error") or {}
    return FacebookError(
        message=err.get("message", f"HTTP {resp.status_code}"),
        code=err.get("code"),
        type=err.get("type"),
        subcode=err.get("error_subcode"),
        trace_id=err.get("fbtrace_id"),
        http_status=resp.status_code,
    )


# ---------------------------------------------------------------- OAuth flow

def construir_url_autorizacion(state: str) -> str:
    """URL del di?logo OAuth para que el admin autorice la app."""
    if not settings.FACEBOOK_APP_ID:
        raise RuntimeError("FACEBOOK_APP_ID no configurado")
    params = {
        "client_id": settings.FACEBOOK_APP_ID,
        "redirect_uri": settings.FACEBOOK_OAUTH_REDIRECT_URI,
        "state": state,
        "scope": settings.FACEBOOK_OAUTH_SCOPES,
        "response_type": "code",
    }
    base = (
        f"https://www.facebook.com/{settings.FACEBOOK_GRAPH_API_VERSION}"
        "/dialog/oauth"
    )
    return f"{base}?{urlencode(params)}"


async def intercambiar_codigo_por_token(
    code: str,
) -> tuple[Optional[str], Optional[FacebookError]]:
    """`code` ? short-lived user access token (v?lido 1-2 h)."""
    params = {
        "client_id": settings.FACEBOOK_APP_ID,
        "client_secret": settings.FACEBOOK_APP_SECRET,
        "redirect_uri": settings.FACEBOOK_OAUTH_REDIRECT_URI,
        "code": code,
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            resp = await client.get(
                _graph_url("oauth/access_token"), params=params
            )
        except httpx.HTTPError as e:
            return None, FacebookError(message=f"Error de red: {e}")

    if resp.status_code != 200:
        return None, _parse_error(resp)

    token = resp.json().get("access_token")
    if not token:
        return None, FacebookError(message="Respuesta sin access_token")
    return token, None


async def extender_token(
    short_lived: str,
) -> tuple[Optional[str], Optional[FacebookError]]:
    """short-lived ? long-lived user token (60 d?as)."""
    params = {
        "grant_type": "fb_exchange_token",
        "client_id": settings.FACEBOOK_APP_ID,
        "client_secret": settings.FACEBOOK_APP_SECRET,
        "fb_exchange_token": short_lived,
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            resp = await client.get(
                _graph_url("oauth/access_token"), params=params
            )
        except httpx.HTTPError as e:
            return None, FacebookError(message=f"Error de red: {e}")

    if resp.status_code != 200:
        return None, _parse_error(resp)

    token = resp.json().get("access_token")
    if not token:
        return None, FacebookError(message="Respuesta sin access_token")
    return token, None


async def listar_paginas(
    user_token: str,
) -> tuple[list[PaginaFacebook], Optional[FacebookError]]:
    """Devuelve las p?ginas del usuario con sus Page Access Tokens.

    Nota: al usar un long-lived user token, cada page token hereda el TTL
    (?60 d?as). Ese es el token que guardamos cifrado y usamos para publicar.
    """
    params = {
        "access_token": user_token,
        "fields": "id,name,category,tasks,access_token",
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            resp = await client.get(_graph_url("me/accounts"), params=params)
        except httpx.HTTPError as e:
            return [], FacebookError(message=f"Error de red: {e}")

    if resp.status_code != 200:
        return [], _parse_error(resp)

    data = resp.json().get("data", [])
    paginas = [
        PaginaFacebook(
            id=p["id"],
            name=p.get("name", "(sin nombre)"),
            category=p.get("category"),
            access_token=p.get("access_token", ""),
            tasks=p.get("tasks", []),
        )
        for p in data
    ]
    return paginas, None


# ---------------------------------------------------------------- verificaci?n

async def verificar_token_pagina(
    page_id: str, page_token: str,
) -> tuple[Optional[str], Optional[FacebookError]]:
    """Verifica que un Page Access Token siga vigente. Devuelve el nombre
    de la p?gina o el error."""
    params = {"fields": "name", "access_token": page_token}
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.get(_graph_url(page_id), params=params)
        except httpx.HTTPError as e:
            return None, FacebookError(message=f"Error de red: {e}")

    if resp.status_code != 200:
        return None, _parse_error(resp)
    return resp.json().get("name"), None


# ------------------------------------------------------------------ helpers

def buscar_pagina(
    paginas: list[PaginaFacebook], page_id: str,
) -> Optional[PaginaFacebook]:
    return next((p for p in paginas if p.id == page_id), None)

# ---------------------------------------------------------------- publicacion

async def publicar_post_en_pagina(
    page_id: str,
    page_token: str,
    mensaje: str,
    image_url: str | None = None,
    link: str | None = None,
) -> tuple[str | None, FacebookError | None]:
    """Publica un post en una pagina de Facebook.

    - Si `image_url` esta seteado: POST a /{page_id}/photos (Meta descarga
      la imagen desde la URL, que debe ser publicamente accesible).
    - Si no: POST a /{page_id}/feed (solo texto, opcionalmente con link).

    Devuelve `(external_post_id, error)`.
    `external_post_id` es el ID del post en Facebook (formato
    "{page_id}_{post_id}"), util para correlacionar.
    """
    if not page_id or not page_token:
        return None, FacebookError(message="Faltan page_id o page_token")

    if not mensaje and not image_url:
        return None, FacebookError(message="El post no tiene contenido")

    # Construir payload segun tipo
    if image_url:
        path = f"{page_id}/photos"
        payload: dict = {
            "url": image_url,
            "access_token": page_token,
        }
        if mensaje:
            payload["caption"] = mensaje
        if link:
            payload["link"] = link
    else:
        path = f"{page_id}/feed"
        payload = {
            "message": mensaje,
            "access_token": page_token,
        }
        if link:
            payload["link"] = link

    # POST a Graph API
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            resp = await client.post(_graph_url(path), data=payload)
        except httpx.HTTPError as e:
            return None, FacebookError(message=f"Error de red: {e}")

    if resp.status_code not in (200, 201):
        return None, _parse_error(resp)

    data = resp.json()
    # /photos devuelve {"id": "<photo_id>", "post_id": "<page>_<post>"}
    # /feed devuelve {"id": "<page>_<post>"}
    post_id = data.get("post_id") or data.get("id")
    if not post_id:
        return None, FacebookError(
            message=f"Respuesta sin id: {data!r}"[:200]
        )

    return post_id, None



# ---------------------------------------------------------------------------
# Gestion completa de Pagina: Posts, Comentarios, Mensajes, Insights y Webhook
# ---------------------------------------------------------------------------


async def listar_posts_pagina(
    page_id: str,
    page_token: str,
    limit: int = 20,
) -> tuple[list[dict], FacebookError | None]:
    """Lista los posts publicados en la pagina con estadisticas basicas."""
    params = {
        "fields": (
            "id,message,created_time,permalink_url,full_picture,is_published,"
            "shares,likes.summary(true),comments.summary(true)"
        ),
        "limit": limit,
        "access_token": page_token,
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.get(_graph_url(f"{page_id}/posts"), params=params)
        except httpx.HTTPError as e:
            return [], FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return [], _parse_error(resp)
    return resp.json().get("data", []), None


async def actualizar_post_pagina(
    post_id: str,
    page_token: str,
    mensaje: str,
) -> tuple[bool, FacebookError | None]:
    """Edita el texto de un post existente de la pagina."""
    payload = {"message": mensaje, "access_token": page_token}
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.post(_graph_url(post_id), data=payload)
        except httpx.HTTPError as e:
            return False, FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return False, _parse_error(resp)
    return bool(resp.json().get("success", True)), None


async def eliminar_post_pagina(
    post_id: str,
    page_token: str,
) -> tuple[bool, FacebookError | None]:
    """Elimina un post de la pagina."""
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.delete(
                _graph_url(post_id), params={"access_token": page_token}
            )
        except httpx.HTTPError as e:
            return False, FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return False, _parse_error(resp)
    return bool(resp.json().get("success", True)), None


async def listar_comentarios_post(
    object_id: str,
    page_token: str,
    limit: int = 50,
) -> tuple[list[dict], FacebookError | None]:
    """Lista comentarios de un post (o respuestas de un comentario)."""
    params = {
        "fields": "id,message,from,created_time,is_hidden,can_hide,can_remove,like_count,comment_count",
        "filter": "stream",
        "limit": limit,
        "access_token": page_token,
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.get(
                _graph_url(f"{object_id}/comments"), params=params
            )
        except httpx.HTTPError as e:
            return [], FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return [], _parse_error(resp)
    return resp.json().get("data", []), None


async def responder_comentario(
    object_id: str,
    page_token: str,
    mensaje: str,
) -> tuple[str | None, FacebookError | None]:
    """Publica un comentario en un post o responde a un comentario existente."""
    payload = {"message": mensaje, "access_token": page_token}
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.post(
                _graph_url(f"{object_id}/comments"), data=payload
            )
        except httpx.HTTPError as e:
            return None, FacebookError(message=f"Error de red: {e}")
    if resp.status_code not in (200, 201):
        return None, _parse_error(resp)
    return resp.json().get("id"), None


async def ocultar_comentario(
    comment_id: str,
    page_token: str,
    ocultar: bool = True,
) -> tuple[bool, FacebookError | None]:
    """Oculta o vuelve visible un comentario en la pagina."""
    payload = {"is_hidden": "true" if ocultar else "false", "access_token": page_token}
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.post(_graph_url(comment_id), data=payload)
        except httpx.HTTPError as e:
            return False, FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return False, _parse_error(resp)
    return bool(resp.json().get("success", True)), None


async def eliminar_comentario(
    comment_id: str,
    page_token: str,
) -> tuple[bool, FacebookError | None]:
    """Elimina un comentario."""
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.delete(
                _graph_url(comment_id), params={"access_token": page_token}
            )
        except httpx.HTTPError as e:
            return False, FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return False, _parse_error(resp)
    return bool(resp.json().get("success", True)), None


async def listar_conversaciones_pagina(
    page_id: str,
    page_token: str,
    platform: str = "messenger",
    limit: int = 25,
) -> tuple[list[dict], FacebookError | None]:
    """Lista conversaciones del Inbox de la pagina (messenger o instagram)."""
    params = {
        "platform": platform,
        "fields": "id,snippet,updated_time,unread_count,can_reply,participants",
        "limit": limit,
        "access_token": page_token,
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.get(
                _graph_url(f"{page_id}/conversations"), params=params
            )
        except httpx.HTTPError as e:
            return [], FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return [], _parse_error(resp)
    return resp.json().get("data", []), None


async def listar_mensajes_conversacion(
    conversation_id: str,
    page_token: str,
    limit: int = 50,
) -> tuple[list[dict], FacebookError | None]:
    """Obtiene los mensajes de una conversacion especifica."""
    params = {
        "fields": "id,message,from,to,created_time,attachments",
        "limit": limit,
        "access_token": page_token,
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.get(
                _graph_url(f"{conversation_id}/messages"), params=params
            )
        except httpx.HTTPError as e:
            return [], FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return [], _parse_error(resp)
    return resp.json().get("data", []), None


async def enviar_mensaje_pagina(
    page_id: str,
    page_token: str,
    recipient_id: str,
    texto: str,
) -> tuple[str | None, FacebookError | None]:
    """Envia un mensaje de respuesta desde la pagina a un usuario (PSID)."""
    payload = {
        "recipient": {"id": recipient_id},
        "messaging_type": "RESPONSE",
        "message": {"text": texto},
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.post(
                _graph_url(f"{page_id}/messages"),
                params={"access_token": page_token},
                json=payload,
            )
        except httpx.HTTPError as e:
            return None, FacebookError(message=f"Error de red: {e}")
    if resp.status_code not in (200, 201):
        return None, _parse_error(resp)
    return resp.json().get("message_id"), None


async def obtener_insights_pagina(
    page_id: str,
    page_token: str,
    period: str = "day",
) -> tuple[list[dict], FacebookError | None]:
    """Consulta metricas/insights de la pagina."""
    params = {
        "metric": "page_post_engagements,page_views_total,page_follows",
        "period": period,
        "access_token": page_token,
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.get(
                _graph_url(f"{page_id}/insights"), params=params
            )
        except httpx.HTTPError as e:
            return [], FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return [], _parse_error(resp)
    return resp.json().get("data", []), None


async def suscribir_webhooks_pagina(
    page_id: str,
    page_token: str,
    fields: str = "feed,messages,messaging_postbacks,message_reads",
) -> tuple[dict, FacebookError | None]:
    """Suscribe la pagina a webhooks; si falta pages_messaging, suscribe feed."""
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.post(
                _graph_url(f"{page_id}/subscribed_apps"),
                data={"subscribed_fields": fields, "access_token": page_token},
            )
        except httpx.HTTPError as e:
            return {"ok": False}, FacebookError(message=f"Error de red: {e}")

        if resp.status_code == 200:
            return {
                "ok": bool(resp.json().get("success", True)),
                "subscribed_fields": fields.split(","),
                "partial_messaging": False,
            }, None

        err = _parse_error(resp)
        if "pages_messaging" in (err.message or "") and fields != "feed":
            try:
                resp_fb = await client.post(
                    _graph_url(f"{page_id}/subscribed_apps"),
                    data={"subscribed_fields": "feed", "access_token": page_token},
                )
            except httpx.HTTPError as e:
                return {"ok": False}, FacebookError(message=f"Error de red: {e}")
            if resp_fb.status_code == 200:
                return {
                    "ok": bool(resp_fb.json().get("success", True)),
                    "subscribed_fields": ["feed"],
                    "partial_messaging": True,
                }, None
            return {"ok": False}, _parse_error(resp_fb)

        return {"ok": False}, err


async def obtener_configuracion_pagina(
    page_id: str,
    page_token: str,
    admin_token: str | None = None,
) -> tuple[dict, FacebookError | None]:
    """Obtiene detalles de la pagina, webhooks suscritos y permisos en Meta."""
    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp_page = await client.get(
                _graph_url(page_id),
                params={
                    "fields": (
                        "id,name,about,category,phone,emails,website,"
                        "link,fan_count,followers_count,is_published"
                    ),
                    "access_token": page_token,
                },
            )
        except httpx.HTTPError as e:
            return {}, FacebookError(message=f"Error de red: {e}")

        if resp_page.status_code != 200:
            return {}, _parse_error(resp_page)

        page_data = resp_page.json()
        subscribed_apps: list[dict] = []
        try:
            resp_subs = await client.get(
                _graph_url(f"{page_id}/subscribed_apps"),
                params={"access_token": page_token},
            )
            if resp_subs.status_code == 200:
                subscribed_apps = resp_subs.json().get("data", [])
        except httpx.HTTPError:
            subscribed_apps = []

        granted_permissions: list[str] = []
        declined_permissions: list[str] = []
        token_perm = admin_token or page_token
        try:
            resp_perm = await client.get(
                _graph_url("me/permissions"),
                params={"access_token": token_perm},
            )
            if resp_perm.status_code == 200:
                for item in resp_perm.json().get("data", []):
                    perm = item.get("permission")
                    st = item.get("status")
                    if perm and st == "granted":
                        granted_permissions.append(perm)
                    elif perm:
                        declined_permissions.append(perm)
        except httpx.HTTPError:
            pass

        return {
            "page": page_data,
            "subscribed_apps": subscribed_apps,
            "granted_permissions": sorted(granted_permissions),
            "declined_permissions": sorted(declined_permissions),
            "has_pages_messaging": "pages_messaging" in granted_permissions,
            "editable_fields": ["about", "phone", "website"],
        }, None


async def actualizar_configuracion_pagina(
    page_id: str,
    page_token: str,
    *,
    about: str | None = None,
    phone: str | None = None,
    website: str | None = None,
) -> tuple[bool, FacebookError | None]:
    """Actualiza campos editables de configuracion de la pagina en Graph API."""
    payload: dict[str, str] = {"access_token": page_token}
    if about is not None:
        payload["about"] = about
    if phone is not None:
        payload["phone"] = phone
    if website is not None:
        payload["website"] = website

    if len(payload) == 1:
        return True, None

    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            resp = await client.post(_graph_url(page_id), data=payload)
        except httpx.HTTPError as e:
            return False, FacebookError(message=f"Error de red: {e}")
    if resp.status_code != 200:
        return False, _parse_error(resp)
    return bool(resp.json().get("success", True)), None
