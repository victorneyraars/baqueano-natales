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
